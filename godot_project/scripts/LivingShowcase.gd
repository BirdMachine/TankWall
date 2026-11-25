extends SceneTree
## Production scene/controller review. The clean view previews wallpaper layout;
## actual Android service validation is performed separately.
const SAVE := "user://living-showcase.json"
var main
var frame := 0
func _initialize() -> void:
	root.content_scale_size = Vector2i(540, 1200)
	root.size = Vector2i(540, 1200)
	call_deferred("start")
func start() -> void:
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(SAVE + suffix):
			DirAccess.remove_absolute(SAVE + suffix)
	main = load("res://scenes/Main.tscn").instantiate()
	main.companion_save_path = SAVE
	root.add_child(main)
	main.fish_nodes[0].rng.seed = 321
	main.fish_nodes[0].brain.configure("curious", 321)
	process_frame.connect(step)
func step() -> void:
	frame += 1
	var hud = main.get_node("AeroHUD")
	match frame:
		45: main.care.offer_snack()
		180: hud._show_world()
		240:
			hud.modal.hide()
			main.set_view_mode("tank")
		330: main.care.refresh_water()
		390: main.care.begin_play()
		510:
			main._clear_touch_target()
			main.care.begin_play()
			if preload("res://scripts/GusaiRigAdapter.gd").available(1):
				main.set_model_variant(1)
			main.set_personality("calm")
		660:
			hud.hide()
			main.wallpaper_mode = true
			main._configure_swim_bounds()
		780: main.set_view_mode("showcase")
		870: main.care.toggle_rest()
		990:
			main.care.toggle_rest()
			main.set_view_mode("tank")
		1080:
			main.wallpaper_mode = false
			main._configure_swim_bounds()
			hud.show()
		1200: quit()
	if frame >= 400 and frame < 500:
		main._set_touch_target(Vector2(270.0 + sin(frame * 0.025) * 70.0, 560), true)
