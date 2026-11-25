extends SceneTree
## A repeatable recording of the production scene, materials and lighting.
var main
var fish
var frame := 0
var current_case := -1
var title: Label
var subtitle: Label
const CASES := ["Original colours", "Moon jelly", "Rose quartz", "Sea glass", "Ember", "Electric orchid"]
func _initialize() -> void:
	root.content_scale_size = Vector2i(540, 900)
	root.size = Vector2i(540, 900)
	call_deferred("start")
func start() -> void:
	main = load("res://scenes/Main.tscn").instantiate()
	main.wallpaper_mode_override = true
	main.companion_save_path = "user://colour-showcase-unsaved.json"
	root.add_child(main)
	main.care.set_process(false)
	main.care.state.resting = false
	var camera: Camera3D = main.get_node("Camera3D")
	camera.position = Vector3(0, 0.35, 7)
	camera.look_at(Vector3(0, 0.35, 0))
	var canvas := CanvasLayer.new()
	root.add_child(canvas)
	title = Label.new()
	title.position = Vector2(26, 42)
	title.add_theme_font_size_override("font_size", 31)
	canvas.add_child(title)
	subtitle = Label.new()
	subtitle.position = Vector2(26, 106)
	subtitle.size = Vector2(488, 100)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.modulate = Color("c2e4e0")
	canvas.add_child(subtitle)
	var footer := Label.new()
	footer.text = "T A M O T A N K   /   0.12\nFish colours, shimmer & lighting"
	footer.position = Vector2(26, 802)
	footer.add_theme_font_size_override("font_size", 18)
	canvas.add_child(footer)
	process_frame.connect(step)
func step() -> void:
	var index := frame / 150
	if index >= CASES.size():
		quit()
		return
	if index != current_case:
		current_case = index
		main.care.state.style = preload("res://scripts/AquariumStyle.gd").defaults()
		main.care.state.style.fish = preload("res://scripts/AquariumStyle.gd").palette(CASES[index])
		main.care.state.model_variant = 0 if index < 3 else 1
		main.care.state.look = 0
		main.fish_model_variant = main.care.state.model_variant
		if index > 0:
			main._spawn_fish()
		fish = main.fish_nodes[0]
		fish.set_physics_process(false)
		fish.position = Vector3(0.75, 0.35, 0)
		fish.rig_adapter.speed_ratio = 0.45
		fish.heading = Vector3.RIGHT
		fish._apply_swim_orientation(1.0)
		main.care.state.backwall = ["14313eff", "122440ff", "301932ff", "123a36ff", "321c26ff", "231738ff"][index]
		if index == 5:
			main.care.state.style.lights.merge({"key": "b3dfffff", "energy": 1.5,
				"fill": "ff66bbff", "fill_energy": 1.1, "yaw": -35.0}, true)
		main.apply_fish_colours()
		main.apply_lighting()
		main.apply_companion_view()
		title.text = CASES[index]
		subtitle.text = ("Original palette and neutral light." if index == 0 else "Two-colour palette · subtle shimmer" if index < 5 else "Cool main light · pink fill light") + "\n" + ("Flowing split tail" if index < 3 else "Broad fan tail")
	var phase := float(frame % 150) / 30.0
	fish.heading = Vector3(1, sin(phase) * 0.035, sin(phase * 0.8) * 0.18).normalized()
	fish._apply_swim_orientation(1.0 / 30.0)
	fish.rig_adapter.set_swim_motion(0.45, sin(phase * 1.2) * 0.6, 0.0, 1.0)
	if frame % 150 == 90:
		capture.call_deferred(index)
	frame += 1
func capture(index: int) -> void:
	await RenderingServer.frame_post_draw
	var directory := OS.get_environment("TAMOTANK_PREVIEW_DIR")
	if directory.is_empty():
		directory = ProjectSettings.globalize_path("user://")
	root.get_texture().get_image().save_png(directory.path_join("colour-case-%d.png" % index))
