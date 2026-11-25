extends SceneTree
## Run with a real renderer: verify the normal post-animation modifier callback.
var fish
var frame := 0
var largest := 0.0
var variant := 0
func _initialize() -> void:call_deferred("start")
func start() -> void:
	if not preload("res://scripts/GusaiRigAdapter.gd").available():
		print("Native fin callback check skipped: private assets absent")
		quit()
		return
	var camera := Camera3D.new()
	camera.position.z = 5
	camera.current = true
	root.add_child(camera)
	spawn()
	process_frame.connect(step)
func spawn() -> void:
	fish = load("res://scenes/Fish.tscn").instantiate()
	fish.model_variant = variant
	root.add_child(fish)
	fish.set_physics_process(false)
func step() -> void:
	frame += 1
	fish.position.x = sin(frame * 0.035) * 0.3
	fish.rotation.y = sin(frame * 0.03) * 1.3
	var solver = fish.rig_adapter.fin_physics.solver
	largest = maxf(largest, solver.max_offset)
	if frame % 180 == 0:
		if not solver.initialized or largest < 0.01:
			push_error("Normal SkeletonModifier callback did not drive the fins")
			quit(1)
			return
		print("Rendered fin callback variant=", variant, " peak lag=", largest, " points=", solver.points.size())
		fish.free()
		variant += 1
		if variant == 2:
			quit()
		else:
			largest = 0.0
			spawn()
