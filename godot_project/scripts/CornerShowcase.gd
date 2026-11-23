extends SceneTree
## Deterministic review footage from the production controller and skinned rig.
## Four cases, six seconds each; fixed 30 fps, half-speed simulation.
## godot --fixed-fps 30 --write-movie /path/review.avi --script res://scripts/CornerShowcase.gd
var fish: Node3D
var world: Node3D
var camera: Camera3D
var title: Label
var status: Label
var bounds_wire: MeshInstance3D
var frame := 0
var case_index := -1
var version_label := "NIGHTFLIGHT"
const STEP := 1.0 / 60.0
const TITLES := ["180° reversal · side view", "Glass corner · oblique view",
	"Ceiling turn · vertical body bend", "180° reversal · overhead view"]

func _initialize() -> void:
	# Set the viewport before movie recording starts, avoiding portrait padding.
	root.content_scale_size = Vector2i(720, 720)
	root.size = Vector2i(720, 720)
	call_deferred("_start")

func _start() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--label="):
			version_label = arg.trim_prefix("--label=")
	world = Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("08141e")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("a0cfdf")
	env.environment.ambient_light_energy = 0.65
	world.add_child(env)
	camera = Camera3D.new()
	world.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 4.4
	camera.current = true
	for location in [Vector3(1, 3, 4), Vector3(-3, 1, -2)]:
		var light := OmniLight3D.new()
		light.position = location
		light.light_energy = 2.5
		world.add_child(light)
	var wire := ImmediateMesh.new()
	var ink := StandardMaterial3D.new()
	ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ink.albedo_color = Color("214454")
	wire.surface_begin(Mesh.PRIMITIVE_LINES, ink)
	for x in [-1, 1]:
		for y in [-1, 1]:
			wire.surface_add_vertex(Vector3(x * 1.5, y * 1.5, -0.8))
			wire.surface_add_vertex(Vector3(x * 1.5, y * 1.5, 0.8))
	for y in [-1, 1]:
		for z in [-1, 1]:
			wire.surface_add_vertex(Vector3(-1.5, y * 1.5, z * 0.8))
			wire.surface_add_vertex(Vector3(1.5, y * 1.5, z * 0.8))
	for z in [-1, 1]:
		for x in [-1, 1]:
			wire.surface_add_vertex(Vector3(x * 1.5, -1.5, z * 0.8))
			wire.surface_add_vertex(Vector3(x * 1.5, 1.5, z * 0.8))
	wire.surface_end()
	bounds_wire = MeshInstance3D.new()
	bounds_wire.mesh = wire
	world.add_child(bounds_wire)
	var canvas := CanvasLayer.new()
	root.add_child(canvas)
	title = Label.new()
	title.position = Vector2(24, 20)
	title.add_theme_font_size_override("font_size", 23)
	canvas.add_child(title)
	status = Label.new()
	status.position = Vector2(24, 630)
	status.add_theme_font_size_override("font_size", 19)
	canvas.add_child(status)
	process_frame.connect(_step)

func _reset_case(index: int) -> void:
	if fish:
		fish.free()
	fish = load("res://scenes/Fish.tscn").instantiate()
	world.add_child(fish)
	if not fish.using_imported_model:
		push_error("Review requires the actual imported skin")
		quit(1)
	fish.set_physics_process(false)
	fish.rig_adapter.swim_modifier.active = false
	fish.rig_adapter.set_process(false)
	fish.rng.seed = 42
	fish.next_pause = 100.0
	fish.set_visual_scale(1.15)
	fish.set_swim_bounds(Vector3(-1.5, -1.5, -0.8), Vector3(1.5, 1.5, 0.8))
	fish.heading = Vector3.RIGHT
	fish.quaternion = Quaternion.IDENTITY
	fish.position = Vector3(0.4, 0.0, 0.0)
	fish.speed = 0.50
	fish.set_follow_target(Vector3(-1.4, 0, -0.08))
	camera.position = Vector3(0, 0.45, 6)
	camera.size = 4.4
	camera.look_at(Vector3(0, 0.0, 0))
	bounds_wire.visible = index in [1, 2]
	if index == 1:
		fish.position = Vector3(1.44, 1.0, 0.74)
		fish.heading = Vector3(1, 0.15, 1).normalized()
		fish.speed = 1.35
		fish.set_follow_target(Vector3(1.5, 1.5, 0.8))
		camera.size = 5.4
		camera.position = Vector3(0.65, 3.9, 6)
		camera.look_at(Vector3(0.65, 0.6, 0))
	elif index == 2:
		fish.position = Vector3(0, 1.44, 0)
		fish.heading = Vector3.UP
		fish.basis = Basis(Vector3.UP, Vector3.FORWARD, Vector3.LEFT)
		fish.speed = 0.50
		fish.set_follow_target(Vector3(0, -1.4, 0))
		camera.position = Vector3(0, 1.05, 6)
		camera.look_at(Vector3(0, 0.6, 0))
	elif index == 3:
		camera.position = Vector3(0, 6, 0.01)
		camera.look_at(Vector3.ZERO)
	title.text = version_label + "\n" + TITLES[index]

func _step() -> void:
	var next_case := frame / 180
	if next_case >= TITLES.size():
		quit()
		return
	if next_case != case_index:
		case_index = next_case
		_reset_case(case_index)
	fish._physics_process(STEP)
	fish.rig_adapter.swim_modifier.advance_swim(STEP)
	fish.rig_adapter._process(STEP)
	status.text = "Actual controller + skinned mesh · ½ speed\n" + fish.pivot.stage.capitalize()
	frame += 1
