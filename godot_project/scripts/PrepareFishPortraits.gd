extends SceneTree
## Render build-time portraits from actual models; source rigs are never altered.
var stage: Node3D
var viewport: SubViewport
var resident
var frame := 0
var index := -1
func _initialize() -> void:
	root.size = Vector2i(384, 240)
	call_deferred("start")
func start() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(384, 240)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	stage = Node3D.new()
	viewport.add_child(stage)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color.TRANSPARENT
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("b4d5e0")
	world.environment.ambient_light_energy = 0.6
	stage.add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-30, 35, 0)
	light.light_energy = 1.6
	stage.add_child(light)
	var camera := Camera3D.new()
	camera.position = Vector3(-0.85, 0.05, 5)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.0
	camera.current = true
	stage.add_child(camera)
	process_frame.connect(step)
func step() -> void:
	var next := frame / 45
	if next >= 3:
		quit()
		return
	if next != index:
		index = next
		if resident:
			stage.remove_child(resident)
			resident.queue_free()
		resident = load("res://scenes/Fish.tscn").instantiate()
		resident.model_variant = index
		stage.add_child(resident)
		resident.set_physics_process(false)
		resident.heading = Vector3.RIGHT
		resident._apply_swim_orientation(1)
		resident.rig_adapter.set_swim_motion(0.4, 0, 0, 1)
	if frame % 45 == 35:
		capture.call_deferred(index)
	frame += 1
func capture(which: int) -> void:
	await RenderingServer.frame_post_draw
	var target: String = preload("res://scripts/FishCatalogue.gd").item(which).portrait
	DirAccess.make_dir_recursive_absolute(target.get_base_dir())
	viewport.get_texture().get_image().save_png(target)
	print("Portrait prepared: ",target)
