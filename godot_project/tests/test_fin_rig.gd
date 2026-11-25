extends SceneTree
## Optional private fixture: test actual artist bones without redistributing them.
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	if not preload("res://scripts/GusaiRigAdapter.gd").available():
		print("Private fin rig: skipped (purchased assets not installed)")
		quit()
		return
	for variant in 2:
		var fish = load("res://scenes/Fish.tscn").instantiate()
		fish.model_variant = variant
		root.add_child(fish)
		fish.set_physics_process(false)
		var adapter = fish.rig_adapter
		adapter.set_process(false)
		var skeleton: Skeleton3D = adapter.skeleton
		for child in skeleton.get_children():
			if child is SkeletonModifier3D:child.active = false
		adapter.animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		var fin_ids: Array = []
		for ray in adapter.fin_physics.rays:fin_ids.append_array(ray)
		check(adapter.fin_physics.rays.size() == 6, "Missing fin rays")
		var biggest := 0.0
		var cost := 0
		for frame in 480:
			var time := float(frame) / 60.0
			fish.position = Vector3(minf(time, 3.0) * 0.2, 0, 0)
			fish.rotation.y = smoothstep(1.0, 2.0, time) * 2.1
			skeleton.reset_bone_poses()
			adapter.animation_player.advance(1.0 / 60.0)
			# Strip clip travel exactly as the production modifier does.
			skeleton.set_bone_pose_position(adapter.root_bone, adapter.root_position)
			skeleton.set_bone_pose_rotation(adapter.root_bone, adapter.root_rotation)
			var before: Array = []
			for i in skeleton.get_bone_count():before.append(skeleton.get_bone_pose(i))
			var start := Time.get_ticks_usec()
			adapter.fin_physics.apply(1.0 / 60.0)
			cost += Time.get_ticks_usec() - start
			biggest = maxf(biggest, adapter.fin_physics.solver.max_offset)
			for i in skeleton.get_bone_count():
				var after := skeleton.get_bone_pose(i)
				check(after.origin.is_equal_approx(before[i].origin), "A fin changed bone translation")
				check(after.basis.get_scale().is_equal_approx(before[i].basis.get_scale()), "A fin changed bone scale")
				check(after.basis.is_finite(), "Non-finite fin transform")
				if i not in fin_ids:check(after.is_equal_approx(before[i]), "Cloth changed a body/eye/mouth bone")
		check(biggest > 0.01 and biggest < 1.0, "Fin response absent or unbounded")
		adapter.fin_physics.enabled = false
		skeleton.reset_bone_poses()
		adapter.animation_player.advance(1.0 / 60.0)
		var original: Array = []
		for i in skeleton.get_bone_count():original.append(skeleton.get_bone_pose(i))
		adapter.fin_physics.apply(1.0 / 60.0)
		for i in skeleton.get_bone_count():check(skeleton.get_bone_pose(i).is_equal_approx(original[i]), "Disabled cloth changed the source pose")
		print("Private fins variant=", variant, " rays=", adapter.fin_physics.rays.size(), " peak lag=", biggest, " mean CPU usec=", cost / 480.0)
		fish.free()
	print("Private fin rig: failures=", failures)
	quit(1 if failures else 0)
