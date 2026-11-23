extends SceneTree
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var fish = load("res://scenes/Fish.tscn").instantiate()
	root.add_child(fish)
	fish.set_physics_process(false)
	var adapter = fish.rig_adapter
	var modifier = adapter.swim_modifier
	modifier.active = false
	check(adapter.volume_skins.size() == 2, "Body and eyes must both use the volume skin")
	var driver = adapter.volume_skins[0]
	var arrays: Array = driver.instance.mesh.surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_CUSTOM0]
	var joints: PackedFloat32Array = arrays[Mesh.ARRAY_CUSTOM1]
	var opaque_vertices := {}
	for vertex in arrays[Mesh.ARRAY_INDEX]:
		opaque_vertices[vertex] = true
	var lookup := {}
	var pairs: Array[Vector2i] = []
	for i in points.size():
		lookup[points[i].snapped(Vector3.ONE * 0.0001)] = i
	for i in points.size():
		var p := points[i]
		if p.x < 0.08 or p.y < 0.6 or p.y > 2.2:
			continue
		if not opaque_vertices.has(i):
			continue
		var torso_weight := 0.0
		for influence in 4:
			if driver.bones[int(joints[i * 4 + influence])] in modifier.spine:
				torso_weight += weights[i * 4 + influence]
		if torso_weight < 0.95:
			continue
		var mirror := Vector3(-p.x, p.y, p.z).snapped(Vector3.ONE * 0.0001)
		if lookup.has(mirror):
			pairs.append(Vector2i(i, lookup[mirror]))
	check(pairs.size() > 20, "Thickness test needs actual opposing torso vertices")
	var rest_error := 0.0
	for i in points.size():
		var result: Vector3 = driver.skin_point(points[i], joints.slice(i * 4, i * 4 + 4), weights.slice(i * 4, i * 4 + 4))
		rest_error = maxf(rest_error, result.distance_to(points[i]))
	check(rest_error < 0.0001, "Rest pose changed shape or bind spaces are incorrect")
	var minimum_ratio := INF
	var maximum_ratio := 0.0
	var maximum_twist := 0.0
	for pose in [Vector2(1.8, 0.0), Vector2(-1.8, 0.0), Vector2(1.2, 0.9), Vector2(-1.2, -0.9)]:
		modifier.set_motion(0.1, pose.x * 0.5, 0.25, 1.0, pose.x, pose.y)
		for frame in 30:
			modifier.advance_swim(1.0 / 60.0)
		for pair in pairs:
			var deformed: Array[Vector3] = []
			for i in [pair.x, pair.y]:
				deformed.append(driver.skin_point(points[i], joints.slice(i * 4, i * 4 + 4), weights.slice(i * 4, i * 4 + 4)))
			var ratio: float = deformed[0].distance_to(deformed[1]) / points[pair.x].distance_to(points[pair.y])
			minimum_ratio = minf(minimum_ratio, ratio)
			maximum_ratio = maxf(maximum_ratio, ratio)
		var body: Transform3D = adapter.skeleton.get_bone_global_pose(modifier.spine[2])
		# Lateral axis acquiring a vertical component reveals local torsion;
		# root rotation alone cannot satisfy this since the root is fixed.
		maximum_twist = maxf(maximum_twist, absf(body.basis.x.normalized().z))
	check(minimum_ratio > 0.85, "Actual torso cross-section collapsed during compound bending")
	check(maximum_ratio < 1.20, "Actual torso cross-section inflated excessively")
	check(maximum_twist > 0.12, "Torso remains constrained to one lateral bend plane")
	print("Volume regression: pairs=", pairs.size(), " rest error=", rest_error,
		" thickness ratio=", minimum_ratio, "..", maximum_ratio, " local torsion=", maximum_twist, " failures=", failures)
	fish.free()
	quit(1 if failures else 0)
