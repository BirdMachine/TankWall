extends SceneTree
## Integration regression checks against the imported 53-joint skin.

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _run() -> void:
	var fish: Node3D = load("res://scenes/Fish.tscn").instantiate()
	root.add_child(fish)
	fish.set_physics_process(false)
	check(fish.using_imported_model, "Actual skinned fish must load; a placeholder is not a passing test")
	if not fish.using_imported_model:
		quit(1)
		return
	var adapter = fish.rig_adapter
	var modifier = adapter.swim_modifier
	var skeleton: Skeleton3D = adapter.skeleton
	modifier.active = false
	check(not adapter.animation_player.active, "Baked root motion must be disabled")
	check(skeleton.get_bone_count() == 53, "Unexpected rig; update the bone mapping deliberately")
	var body := skeleton.find_bone("Bone.004_Armature")
	var tip := skeleton.find_bone("Bone.043_Armature")
	var lateral_min := INF
	var lateral_max := -INF
	var tail_min := INF
	var tail_max := -INF
	modifier.set_motion(0.9, 0.0, 0.0, 1.0)
	for frame in 240:
		modifier.advance_swim(1.0 / 120.0)
		var body_position := skeleton.get_bone_global_pose(body).origin
		var tail_position := skeleton.get_bone_global_pose(tip).origin
		lateral_min = minf(lateral_min, body_position.x)
		lateral_max = maxf(lateral_max, body_position.x)
		tail_min = minf(tail_min, tail_position.x)
		tail_max = maxf(tail_max, tail_position.x)
	check(lateral_max - lateral_min > 0.05, "Torso must bend, not just the tail")
	check(tail_max - tail_min > lateral_max - lateral_min, "Stroke amplitude must grow toward tail")
	# The head frame and torso frames must differ within a stroke. Rigid root
	# rotation alone cannot satisfy this check.
	var head_basis := skeleton.get_bone_global_pose(skeleton.find_bone("Bone_Armature")).basis
	var tail_basis := skeleton.get_bone_global_pose(body).basis
	check(absf(head_basis.x.angle_to(tail_basis.x)) > 0.015, "Body segments must have different orientations")
	# No animated scale/translation changes: preserve each segment's length.
	for i in skeleton.get_bone_count():
		check(skeleton.get_bone_pose_position(i).is_equal_approx(skeleton.get_bone_rest(i).origin), "Bone translation changed")
		check(skeleton.get_bone_pose_scale(i).is_equal_approx(skeleton.get_bone_rest(i).basis.get_scale()), "Bone scale changed")
	# Reset before each timing run. A 30/60/120 Hz renderer should converge to
	# the same fin shape, and long paused frames must remain finite.
	var results: Array[float] = []
	for fps in [30, 60, 120]:
		modifier.phase = 0.0
		modifier.elapsed = 0.0
		modifier.angles.fill(0.0)
		modifier.angular_velocities.fill(0.0)
		modifier.previous_spine.fill(0.0)
		modifier.set_motion(0.85, 0.8, 0.3, 1.0)
		for frame in fps * 3:
			modifier.advance_swim(1.0 / fps)
		results.append(modifier.angles[tip])
	check(absf(results[0] - results[2]) < 0.08, "Fin integration diverges with frame rate")
	modifier.advance_swim(5.0)
	for angle in modifier.angles:
		check(is_finite(angle) and absf(angle) <= 0.65, "Fin springs became unstable after a pause")
	# Exercise the real locomotion in a small portrait-shaped tank. This catches
	# NaNs on reversal, swimming backwards, and extended wall pinning.
	fish.rng.seed = 42
	fish.set_swim_bounds(Vector3(-1.2, -1.8, -0.8), Vector3(1.2, 1.8, 0.8))
	fish.position = Vector3.ZERO
	var pinned := 0
	var minimum_heading_dot := 1.0
	for frame in 1800:
		var before: Vector3 = fish.position
		fish._physics_process(1.0 / 60.0)
		check(fish.position.is_finite() and fish.quaternion.is_finite(), "Locomotion became non-finite")
		var travel: Vector3 = fish.position - before
		if travel.length() < 0.0005:
			pinned += 1
		else:
			minimum_heading_dot = minf(minimum_heading_dot, travel.normalized().dot(fish.heading))
	check(pinned < 30, "Fish stays pinned at a wall")
	check(minimum_heading_dot > 0.0, "Fish translates backwards against its own heading")
	print("Locomotion: pinned frames=", pinned, "/1800 minimum forward alignment=", minimum_heading_dot)
	print("Swim regression: torso sweep=", lateral_max - lateral_min, " tail sweep=", tail_max - tail_min, " fin 30/60/120=", results, " failures=", failures)
	fish.queue_free()
	quit(1 if failures else 0)
