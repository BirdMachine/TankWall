extends SceneTree
const Native = preload("res://scripts/NativeFinCloth.gd")
const Gusai = preload("res://scripts/GusaiRigAdapter.gd")
var failures := 0
var checks := 0
var changed := 0
var smoke_ok := false
class PoseSnapshot extends SkeletonModifier3D:
	var target: Skeleton3D
	var poses: Array[Transform3D] = []
	func _process_modification() -> void:
		poses.clear()
		for i in target.get_bone_count():poses.append(target.get_bone_pose(i))
func check(ok:bool, text:String) -> void:
	if not ok:
		failures+=1
		if failures<5:push_error(text)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	if not Native.available():
		push_error("Build the pinned native extension before running its tests")
		quit(1)
		return
	var probe=preload("res://tests/NativeFinSmoke.gd").new()
	probe.completed.connect(func(ok): smoke_ok=ok)
	root.add_child(probe)
	for i in 160:await process_frame
	check(smoke_ok,"Synthetic native fin simulation did not complete")
	for variant in 2:
		if not Gusai.available(variant):continue
		var fish=load("res://scenes/Fish.tscn").instantiate()
		fish.model_variant=variant
		root.add_child(fish)
		fish.set_physics_process(false)
		fish.rig_adapter.fin_backend="cloth"
		var adapter=fish.rig_adapter
		var skeleton:Skeleton3D=adapter.skeleton
		var snapshot:=PoseSnapshot.new()
		snapshot.target=skeleton
		skeleton.add_child(snapshot)
		for child in skeleton.get_children():
			if child.get_script()==preload("res://scripts/GusaiPoseDriver.gd"):
				skeleton.move_child(snapshot,child.get_index()+1)
				break
		var fins:Dictionary={}
		for ray in adapter.fin_physics.rays:
			for bone in ray:fins[bone]=true
		var marker=adapter.native_cloth.simulators[-1]
		marker.modification_processed.connect(func():
			if snapshot.poses.size()!=skeleton.get_bone_count():return
			var body_ok:=true
			var lengths_ok:=true
			var finite:=true
			var rotated:=false
			for bone in skeleton.get_bone_count():
				var pose:Transform3D=skeleton.get_bone_pose(bone)
				finite=finite and skeleton.get_bone_global_pose(bone).is_finite()
				if bone not in fins:body_ok=body_ok and pose.is_equal_approx(snapshot.poses[bone])
				var same_channels:=pose.origin.distance_to(snapshot.poses[bone].origin)<0.001 and pose.basis.get_scale().is_equal_approx(snapshot.poses[bone].basis.get_scale())
				lengths_ok=lengths_ok and same_channels
				if bone in fins:rotated=rotated or pose.basis.get_rotation_quaternion().angle_to(snapshot.poses[bone].basis.get_rotation_quaternion())>0.001
			check(body_ok,"Native cloth changed a body/head channel")
			check(lengths_ok,"Native cloth changed authored translation/scale beyond float-roundtrip tolerance")
			check(finite,"Native cloth produced a non-finite pose")
			checks+=1
			if rotated:changed+=1)
		for frame in 180:
			fish.position.x=sin(frame*0.035)*0.4
			fish.rotation.y=sin(frame*0.03)*0.8
			await process_frame
		check(adapter.native_cloth.enabled,"Selected native backend did not activate")
		adapter.live_fins=false
		await process_frame
		await process_frame
		check(not adapter.native_cloth.enabled,"Disabling live fins left native simulation active")
		fish.free()
	if Gusai.available():check(checks>100 and changed>10,"Native fin modifier did not produce inertial motion on the purchased rigs")
	print("Native fin cloth: synthetic ABI smoke, both available rigs, body/position/scale preservation, finite motion and disable; checks=",checks," changed=",changed," failures=",failures)
	quit(1 if failures else 0)
