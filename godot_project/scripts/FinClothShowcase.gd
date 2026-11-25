extends SceneTree
## Same production rig/controller, once with recorded fins and once with physics.
const DT := 1.0 / 60.0
var residents: Array = []
var cameras: Array[Camera3D] = []
var label: Label
var frame := 0
var variant := 0
var current_case := -1
func _initialize() -> void:
	root.content_scale_size = Vector2i(720, 1200)
	root.size = Vector2i(720, 1200)
	call_deferred("start")
func start() -> void:
	var canvas := Control.new()
	root.add_child(canvas)
	var background := ColorRect.new()
	background.color = Color("081b25")
	background.size = Vector2(720, 1200)
	canvas.add_child(background)
	for panel in 2:
		var container := SubViewportContainer.new()
		container.position = Vector2(0, 70 + panel * 540)
		container.size = Vector2(720, 520)
		canvas.add_child(container)
		var viewport := SubViewport.new()
		viewport.size = Vector2i(720, 520)
		viewport.own_world_3d = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		container.add_child(viewport)
		var world := Node3D.new()
		viewport.add_child(world)
		var environment := WorldEnvironment.new()
		environment.environment = Environment.new()
		environment.environment.background_mode = Environment.BG_COLOR
		environment.environment.background_color = Color("12313e")
		environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.environment.ambient_light_color = Color("b9d3df")
		environment.environment.ambient_light_energy = 0.65
		world.add_child(environment)
		var light := DirectionalLight3D.new()
		light.rotation_degrees = Vector3(-30, -30, 0)
		light.light_energy = 1.3
		world.add_child(light)
		var camera := Camera3D.new()
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 3.7
		camera.current = true
		world.add_child(camera)
		cameras.append(camera)
		var caption := Label.new()
		caption.text = "RECORDED FINS · v0.9" if panel == 0 else "LIVE FIN PHYSICS · prototype"
		caption.position = Vector2(24, 76 + panel * 540)
		caption.add_theme_font_size_override("font_size", 22)
		canvas.add_child(caption)
		residents.append({"world": world, "fish": null})
	label = Label.new()
	label.position = Vector2(24, 15)
	label.add_theme_font_size_override("font_size", 25)
	canvas.add_child(label)
	process_frame.connect(step)
func setup_case(index: int) -> void:
	variant = index / 2
	for panel in 2:
		var item: Dictionary = residents[panel]
		if item.fish:item.fish.free()
		var fish = load("res://scenes/Fish.tscn").instantiate()
		fish.model_variant = variant
		item.world.add_child(fish)
		fish.set_physics_process(false)
		fish.rng.seed = 42
		fish.next_pause = 1000.0
		fish.set_swim_bounds(Vector3(-1.3, -1.5, -0.7), Vector3(1.3, 1.5, 0.7))
		fish.position = Vector3(0.0, 0, 0)
		fish.speed = 0.4
		fish.heading = Vector3.RIGHT
		fish.rig_adapter.set_process(false)
		fish.rig_adapter.live_fins = panel == 1
		for child in fish.rig_adapter.skeleton.get_children():
			if child is SkeletonModifier3D:child.active = false
		fish.rig_adapter.animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		fish.set_follow_target(Vector3(-1.25, 0, -0.2) if index % 2 == 0 else Vector3(0, 1.4, 0))
		item.fish = fish
	label.text = ("SPLIT TAIL" if variant == 0 else "BROAD TAIL") + (" · reversal + settling" if index % 2 == 0 else " · vertical turn") + " · ½ speed"
func step() -> void:
	var index := frame / 360
	if index >= 4:
		quit()
		return
	if index != current_case:
		current_case = index
		setup_case(index)
	for panel in 2:
		var fish = residents[panel].fish
		if frame % 360 == 180:fish.clear_follow_target()
		fish._physics_process(DT)
		var adapter = fish.rig_adapter
		adapter.skeleton.reset_bone_poses()
		adapter.animation_player.advance(DT)
		adapter._process(DT)
		adapter.update_pose(DT)
		var focus: Vector3 = fish.position - fish.heading * 0.72
		cameras[panel].position = focus + Vector3(0.2, 0.3, 5)
		cameras[panel].look_at(focus)
	frame += 1
