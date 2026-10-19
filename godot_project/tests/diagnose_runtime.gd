extends SceneTree

var calls := 0
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var fish: Node3D = load("res://scenes/Fish.tscn").instantiate()
	root.add_child(fish)
	fish.rig_adapter.swim_modifier.modification_processed.connect(func(): calls += 1)
	for i in 180:
		await process_frame
		if i % 30 == 0:
			print("RUNTIME frame=", i, " modifier calls=", calls, " phase=", fish.rig_adapter.swim_modifier.phase)
	if calls < 170 or fish.rig_adapter.fin_clock <= 0.0:
		push_error("Animation must advance in the real scene without manual bone stepping")
		quit(1)
		return
	quit()
