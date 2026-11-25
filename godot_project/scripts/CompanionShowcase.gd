extends SceneTree
## Review the production care flow, using an isolated, disposable companion.
var main
var frame := 0
var snapshot := false
var landscape := false
var output_dir := "user://"
var tank_view := false
var broad_tail := false
const PATH := "user://companion-showcase.json"

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		snapshot = snapshot or arg == "--snapshot"
		landscape = landscape or arg == "--landscape"
		tank_view = tank_view or arg == "--tank"
		broad_tail = broad_tail or arg == "--broad"
		if arg.begins_with("--output-dir="):
			output_dir = arg.trim_prefix("--output-dir=").path_join("")
	root.content_scale_size = Vector2i(540, 1200)
	root.size = Vector2i(1200, 700) if landscape else Vector2i(540, 1200)
	call_deferred("_start")

func _start() -> void:
	for suffix in ["", ".bak"]:
		if FileAccess.file_exists(PATH + suffix):
			DirAccess.remove_absolute(PATH + suffix)
	main = load("res://scenes/Main.tscn").instantiate()
	main.companion_save_path = PATH
	root.add_child(main)
	if broad_tail:
		main.set_model_variant(1)
	if tank_view:
		main.set_view_mode("tank")
	main.fish_nodes[0].rng.seed = 321
	process_frame.connect(_step)

func _step() -> void:
	frame += 1
	var care = main.care
	var hud = main.get_node("AeroHUD")
	if frame == 30:
		care.rename_pet("Miso")
	if frame == 60:
		care.offer_snack()
	if frame == 120:
		_capture("companion-tank-broad.png" if tank_view and broad_tail else "companion-tank.png" if tank_view else "companion-landscape.png" if landscape else "companion-portrait.png")
	if snapshot and frame == 125:
		quit()
	if frame == 300:
		care.refresh_water()
	if frame == 390:
		care.begin_play()
	if frame >= 400 and frame < 550:
		var size := root.get_visible_rect().size
		main._set_touch_target(Vector2(size.x * (0.5 + 0.18 * sin(frame * 0.02)), size.y * 0.43), true)
	if frame == 555:
		main._clear_touch_target()
		care.begin_play()
	if frame == 610:
		hud._show_memories()
	if frame == 640:
		_capture("companion-memories.png")
	if frame == 730:
		hud.modal.hide()
		hud._show_looks()
	if frame == 790:
		care.choose_look(2)
	if frame == 850:
		hud.modal.hide()
		care.toggle_rest()
	if frame == 915:
		_capture("companion-rest.png")
	if frame == 990:
		care.toggle_rest()
	if frame >= 1080:
		quit()

func _capture(filename: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output_dir.path_join(filename))
	var hud = main.get_node("AeroHUD")
	print("Companion layout: viewport=", root.get_visible_rect().size,
		" header=", hud.header.get_global_rect(), " dock=", hud.dock.get_global_rect())
