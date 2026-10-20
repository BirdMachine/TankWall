extends SceneTree
## Measure the real controller's reversal and skin, rather than spinning a model.
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	for config in [[30, -0.1], [60, -0.1], [120, -0.1], [60, 0.1], [60, 0.0]]:
		var fps: int = config[0]
		var fish = load("res://scenes/Fish.tscn").instantiate()
		root.add_child(fish)
		fish.set_physics_process(false)
		fish.set_swim_bounds(Vector3(-10, -10, -10), Vector3(10, 10, 10))
		fish.position = Vector3.ZERO
		fish.heading = Vector3.RIGHT
		fish.quaternion = Quaternion.IDENTITY
		fish.speed = fish.cruise_speed * 0.65
		fish.set_follow_target(Vector3(-5, 0, config[1]))
		var adapter = fish.rig_adapter
		var modifier = adapter.swim_modifier
		modifier.active = false
		var skeleton: Skeleton3D = adapter.skeleton
		var max_excursion := 0.0
		var max_bend := 0.0
		var max_segment_angle := 0.0
		var time_to_reverse := -1.0
		var curl_before_yaw := false
		for frame in fps * 3:
			fish._physics_process(1.0 / fps)
			modifier.advance_swim(1.0 / fps)
			max_bend = maxf(max_bend, absf(fish.pivot.bend))
			var head_pose := skeleton.get_bone_global_pose(modifier.spine[0])
			check((skeleton.global_transform * head_pose.origin).distance_to(fish.global_position) < 0.01, "Rendered head must stay at the controller pivot")
			var head := head_pose.basis
			var tail := skeleton.get_bone_global_pose(modifier.spine[-1]).basis
			max_segment_angle = maxf(max_segment_angle, head.x.angle_to(tail.x))
			if fish.pivot.stage == "curl" and absf(fish.pivot.bend) > 0.7:
				curl_before_yaw = curl_before_yaw or fish.heading.dot(Vector3.RIGHT) > 0.99
			if time_to_reverse < 0.0:
				max_excursion = maxf(max_excursion, fish.position.length())
				if fish.heading.dot(Vector3.LEFT) > 0.95:
					time_to_reverse = float(frame + 1) / fps
		check(time_to_reverse > 0.0 and time_to_reverse < 1.7, "Sharp reversal took too long")
		check(max_excursion < 0.30, "Reversal still travels a broad arc")
		check(curl_before_yaw, "Body must load curvature before the head pivots")
		check(max_segment_angle > 1.3, "Actual body skin must form a substantial curve")
		check(fish.pivot.stage == "cruise" and absf(fish.pivot.bend) < 0.01, "Pivot did not release")
		print("Pivot ", fps, "Hz: reversal=", time_to_reverse, "s head excursion=", max_excursion, " peak body angle=", max_segment_angle, " curl=", max_bend)
		fish.free()
	quit(1 if failures else 0)
