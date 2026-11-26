extends Node3D
## Only the emulator export enables this synthetic native-ABI smoke probe.
var skeleton: Skeleton3D
var cloth
var frames:=0
var largest:=0.0
var clock:=0.0
signal completed(success: bool)
func _ready() -> void:
	if not ClassDB.class_exists("BoneClothSimulator3D"):
		push_error("Native fin runtime unavailable")
		completed.emit(false)
		queue_free()
		return
	skeleton=Skeleton3D.new()
	add_child(skeleton)
	for i in 4:
		skeleton.add_bone("ray_%d"%i)
		if i>0:skeleton.set_bone_parent(i,i-1)
		skeleton.set_bone_rest(i,Transform3D(Basis.IDENTITY,Vector3(0,0.25,0) if i>0 else Vector3.ZERO))
	skeleton.reset_bone_poses()
	cloth=ClassDB.instantiate("BoneClothSimulator3D")
	skeleton.add_child(cloth)
	cloth.chain_count=1
	cloth.set_root_bone_name(0,"ray_0")
	cloth.set_end_bone_name(0,"ray_3")
	cloth.set("gravity/value",0)
	cloth.set("stiffness/value",0.08)
	cloth.set("drag/value",0.2)
	cloth.modification_processed.connect(_on_modified)
func _process(delta:float) -> void:
	clock+=delta
	if skeleton:skeleton.position.x=sin(clock*3.0)*0.15
func _on_modified() -> void:
	frames+=1
	for i in 4:
		if not skeleton.get_bone_global_pose(i).is_finite():
			push_error("Native fin runtime produced a non-finite pose")
			completed.emit(false)
			queue_free()
			return
	largest=maxf(largest,skeleton.get_bone_pose_rotation(2).get_angle())
	if frames==120:
		if largest<0.001:push_error("Native fin runtime did not react to motion")
		else:print("TamoTank: native fin runtime passed; finite inertial simulation")
		completed.emit(largest>=0.001)
		queue_free()
