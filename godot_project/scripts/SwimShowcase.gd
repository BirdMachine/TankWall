extends SceneTree
## Reproducible views of the actual runtime rig. Run with --fixed-fps 30.
## --write-movie /path/swim.avi --script res://scripts/SwimShowcase.gd

var fish: Node3D
var frame := 0
var output_dir := ""
var tank_mode := false
var pivot_mode := false
var overhead := false

func _initialize() -> void:
	call_deferred("_start")

func _start() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output_dir = arg.trim_prefix("--output=")
		if arg == "--overhead":
			overhead = true
		if arg == "--pivots":
			pivot_mode = true
		if arg == "--tank":
			tank_mode = true
	if tank_mode:
		root.size = Vector2i(540, 1200)
		var tank: Node3D = load("res://scenes/Main.tscn").instantiate()
		root.add_child(tank)
		tank.get_node("AeroHUD").hide()
		fish = tank.fish_nodes[0]
		fish.rng.seed = 42
		fish.retarget_time = 0.0
		process_frame.connect(_step)
		return
	root.size = Vector2i(900, 900)
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("08141e")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("a0cfdf")
	env.environment.ambient_light_energy = 0.65
	world.add_child(env)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(0, 0.5, 5.8)
	camera.look_at(Vector3(0, -0.2, 0))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 5.8 if pivot_mode else 3.6
	if pivot_mode:
		camera.position = Vector3(0, 2.2, 6.5)
		camera.look_at(Vector3(0, -0.2, 0))
		if overhead:
			camera.position = Vector3(0, 6.5, 0.1)
			camera.look_at(Vector3.ZERO)
	camera.current = true
	for location in [Vector3(1, 3, 4), Vector3(-3, 1, -2)]:
		var light := OmniLight3D.new()
		light.position = location
		light.light_energy = 2.5
		world.add_child(light)
	fish = load("res://scenes/Fish.tscn").instantiate()
	world.add_child(fish)
	fish.set_visual_scale(1.2)
	fish.set_physics_process(false)
	if pivot_mode:
		# Real controller, deterministic waypoints. No keyed root rotations.
		fish.set_swim_bounds(Vector3(-8, -8, -8), Vector3(8, 8, 8))
		fish.position = Vector3(-0.35, 0, 0)
		fish.heading = Vector3.RIGHT
		fish.quaternion = Quaternion.IDENTITY
		fish.speed = 0.20
		fish.sprint_speed = 0.25
		fish.set_follow_target(Vector3(5, 0, 0))
	if not fish.using_imported_model:
		push_error("Showcase requires the actual skinned betta")
		quit(1)
	process_frame.connect(_step)

func _step() -> void:
	frame += 1
	var t := frame / 30.0
	# First side profile, then an orbit showing volume and curved turns, then
	# a slow hover. This is a rig inspection, not a recorded locomotion claim.
	var yaw := 0.0
	var effort := 0.85
	var turn := 0.0
	if t > 4.0 and t <= 10.0:
		yaw = (t - 4.0) * TAU / 6.0
		turn = 1.0
	elif t > 10.0:
		effort = 0.12
	if pivot_mode:
		if frame == 54:
			fish.set_follow_target(Vector3(-5, 0, -0.15))
		if frame == 150:
			fish.set_follow_target(Vector3(5, 0, 0.25))
		fish._physics_process(1.0 / 30.0)
	elif not tank_mode:
		fish.rotation = Vector3(0, yaw, 0)
		fish.rig_adapter.set_swim_motion(effort, turn, 0.0, 1.0)
	if not output_dir.is_empty() and frame in [30, 54, 60, 66, 72, 78, 84, 90, 105, 150, 186, 198, 210, 225, 255, 280, 345]:
		_save_frame.call_deferred(frame)
	if frame >= (285 if pivot_mode else 420):
		quit()

func _save_frame(number: int) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output_dir.path_join("swim-%03d.png" % number))
