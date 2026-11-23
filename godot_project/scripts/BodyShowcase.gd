extends SceneTree
## Explicit rig inspection: fixed root, moving camera and controlled loads.
## First two cases remove the fins so body depth and deformation are visible.
var fish: Node3D
var camera: Camera3D
var title: Label
var frame := 0
var current_case := -1
var label := "BODY REWORK"
const TITLES := ["Torso only · oblique curl", "Torso only · overhead curl",
	"Whole fish · compound bend", "Whole fish · quiet swim"]

func _initialize() -> void:
	call_deferred("_start")

func _start() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--label="):
			label = arg.trim_prefix("--label=")
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
	camera = Camera3D.new()
	world.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.current = true
	for location in [Vector3(1, 3, 4), Vector3(-3, 1, -2)]:
		var light := OmniLight3D.new()
		light.position = location
		light.light_energy = 2.5
		world.add_child(light)
	fish = load("res://scenes/Fish.tscn").instantiate()
	world.add_child(fish)
	if not fish.using_imported_model:
		quit(1)
		return
	fish.set_physics_process(false)
	fish.quaternion = Quaternion.IDENTITY
	fish.position = Vector3.ZERO
	fish.rig_adapter.swim_modifier.active = false
	fish.rig_adapter.set_process(false)
	var canvas := CanvasLayer.new()
	root.add_child(canvas)
	title = Label.new()
	title.position = Vector2(20, 20)
	title.add_theme_font_size_override("font_size", 22)
	canvas.add_child(title)
	var foot := Label.new()
	foot.text = "RIG INSPECTION · fixed root, controlled loads\nOriginal mesh proportions · no body inflation"
	foot.position = Vector2(20, 640)
	foot.add_theme_font_size_override("font_size", 18)
	canvas.add_child(foot)
	process_frame.connect(_step)

func _step() -> void:
	var index := frame / 150
	if index >= TITLES.size():
		quit()
		return
	if index != current_case:
		current_case = index
		for mesh in fish.rig_adapter.model_root.find_children("*", "MeshInstance3D", true, false):
			if String(mesh.name).to_lower() == "body_0":
				var material = mesh.mesh.surface_get_material(1)
				# Hide the membrane without changing its skin/driver or body mesh.
				material.set_shader_parameter("review_visibility", 0.0 if index < 2 else 1.0)
		camera.size = 1.6 if index < 2 else 3.0
		camera.position = Vector3(0.7, 0.9, 3.0)
		if index == 1:
			camera.position = Vector3(-0.30, 3.0, 0.01)
		camera.look_at(Vector3(-0.30, 0.0, 0.0))
		title.text = label + "\n" + TITLES[index]
	var t := float(frame % 150) / 30.0
	var bend := 1.65 * sin(t * TAU / 5.0)
	if index == 3:
		fish.rig_adapter.set_swim_motion(0.32, 0.0, 0.0, 1.0)
	else:
		fish.rig_adapter.set_swim_motion(0.10, bend * 0.6, bend * 0.25, 1.0, bend)
	fish.rig_adapter.swim_modifier.advance_swim(1.0 / 30.0)
	fish.rig_adapter._process(1.0 / 30.0)
	frame += 1
