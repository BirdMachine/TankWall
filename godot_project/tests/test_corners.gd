extends SceneTree
## Adversarial glass targets: all eight corners, all six face normals, and
## steep reversals. Exercise the actual controller and skin at 30/60/120 Hz.
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scenarios: Array[Vector3] = []
	for x in [-1, 1]:
		for y in [-1, 1]:
			for z in [-1, 1]:
				scenarios.append(Vector3(x, y, z))
	scenarios.append_array([Vector3.RIGHT, Vector3.LEFT, Vector3.UP,
		Vector3.DOWN, Vector3.FORWARD, Vector3.BACK])
	var cases := 0
	var most_clamp_distance := 0.0
	var fastest_roll_step := 0.0
	for fps in [30, 60, 120]:
		for corner in scenarios:
			var fish = load("res://scenes/Fish.tscn").instantiate()
			root.add_child(fish)
			fish.set_physics_process(false)
			fish.rng.seed = 42
			fish.set_swim_bounds(Vector3(-1.2, -1.8, -0.8), Vector3(1.2, 1.8, 0.8))
			var wall: Vector3 = corner * Vector3(1.2, 1.8, 0.8)
			fish.position = wall - corner.normalized() * 0.06
			fish.heading = corner.normalized()
			fish.speed = fish.sprint_speed
			fish.set_follow_target(wall)
			var escaped := false
			var pivots := 0
			var last_stage := "cruise"
			var max_vertical_bend := 0.0
			for frame in fps * 4:
				var before: Vector3 = fish.position
				var previous_rotation: Quaternion = fish.quaternion
				fish._physics_process(1.0 / fps)
				if frame > fps / 2:
					fastest_roll_step = maxf(fastest_roll_step, previous_rotation.angle_to(fish.quaternion) * fps)
				var expected: Vector3 = before + fish.heading * fish.speed / fps
				most_clamp_distance = maxf(most_clamp_distance, expected.distance_to(fish.position))
				check(fish.position.is_finite() and fish.quaternion.is_finite(), "Non-finite corner state")
				check(fish.position.is_equal_approx(fish._clamp_to_bounds(fish.position)), "Escaped head bounds")
				if fish.pivot.stage == "brake" and last_stage == "cruise":
					pivots += 1
				last_stage = fish.pivot.stage
				escaped = escaped or fish.position.distance_to(wall) > 0.20
				max_vertical_bend = maxf(max_vertical_bend, absf(fish.rig_adapter.swim_modifier.pivot_pitch_load))
			check(escaped, "Failed to leave corner/face " + str(corner) + " at " + str(fps))
			check(pivots <= 2, "Repeated pivot thrashing near glass")
			if absf(corner.y) > 0.5 and corner.x == 0 and corner.z == 0:
				check(max_vertical_bend > 0.2, "Vertical turn must bend vertically")
			fish.free()
			cases += 1
	check(most_clamp_distance < 0.00001, "Bounds clamp introduced an uncommanded displacement")
	check(fastest_roll_step < 15.0, "Abrupt body-frame flip through a steep turn")
	print("Corner regression: cases=", cases, " max clamp correction=", most_clamp_distance,
		" max rotation rate=", fastest_roll_step, " failures=", failures)
	quit(1 if failures else 0)
