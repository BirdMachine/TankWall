extends SceneTree
const State = preload("res://scripts/PetState.gd")
const Style = preload("res://scripts/AquariumStyle.gd")
const Catalogue = preload("res://scripts/FishCatalogue.gd")
const PATH := "user://gallery-depth-test.json"
var failures := 0
func check(value: bool, text: String) -> void:
	if not value:
		failures += 1
		push_error(text)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var state = State.new()
	state.from_data({"version":1,"pet_name":"Pearl","bond":42,"snacks":8,
		"journal":["A quiet afternoon."],"style":{"lights":{"energy":2.1}}}, Time.get_unix_time_from_system())
	check(not state.style.lights.occlusion and not state.style.lights.shadows, "Older saves acquired extra rendering effects")
	check(state.style.lights.energy == 2.1, "New lighting fields changed an old preference")
	state.style.fish = Style.palette("Sea glass")
	state.save_to(PATH)
	var main = load("res://scenes/Main.tscn").instantiate()
	main.companion_save_path=PATH
	root.add_child(main)
	await process_frame
	await process_frame
	var hud = main.get_node("AeroHUD")
	hud._show_fish()
	var available := 0
	for i in 3:
		var card = hud.modal_body.find_child("model_%d" % i, true, false)
		check((card != null) == Catalogue.available(i), "Gallery offered a model that is not installed")
		if card:available += 1
	check(available >= 1, "Gallery has no selectable resident")
	var target := 1 if Catalogue.available(1) else 2
	hud.modal_body.find_child("model_%d" % target, true, false).pressed.emit()
	check(main.care.state.model_variant == target and main.fish_nodes[0].model_variant == target, "Gallery did not select the actual rig")
	check(main.care.state.style.fish == state.style.fish, "Changing shape discarded the palette")
	if target < 2 and preload("res://scripts/NativeFinCloth.gd").available():
		hud._show_motion()
		hud.modal_body.find_child("choice_cloth",true,false).pressed.emit()
		check(main.care.state.fin_backend=="cloth" and main.fish_nodes[0].rig_adapter.fin_backend=="cloth", "Fin mode control did not select native cloth")
	hud._show_depth()
	hud.modal_body.get_node("lights_occlusion").button_pressed=true
	hud.modal_body.get_node("lights_occlusion_strength").value=1.15
	hud.modal_body.get_node("lights_occlusion_radius").value=0.32
	hud.modal_body.get_node("lights_shadows").button_pressed=true
	hud.modal_body.get_node("lights_shadow_strength").value=0.65
	var environment: Environment=main.get_node("WorldEnvironment").environment
	var light: DirectionalLight3D=main.get_node("DirectionalLight3D")
	check(environment.ssao_enabled and is_equal_approx(environment.ssao_intensity,1.15) and is_equal_approx(environment.ssao_radius,0.32), "Occlusion controls did not reach the environment")
	check(light.shadow_enabled and is_equal_approx(light.shadow_opacity,0.65), "Shadow controls did not reach the actual light")
	main.care._process(0.5)
	var saved := FileAccess.get_file_as_string(PATH)
	var wallpaper = load("res://scenes/Main.tscn").instantiate()
	wallpaper.wallpaper_mode_override=true
	wallpaper.companion_save_path=PATH
	root.add_child(wallpaper)
	await process_frame
	check(wallpaper.get_node("WorldEnvironment").environment.ssao_enabled and wallpaper.get_node("DirectionalLight3D").shadow_enabled, "Wallpaper didn't load the depth preferences")
	check(wallpaper.care.state.fin_backend==main.care.state.fin_backend,"Wallpaper lost the selected fin backend")
	wallpaper.care._process(3600)
	wallpaper.care.save()
	check(FileAccess.get_file_as_string(PATH)==saved, "Wallpaper overwrote the new appearance save")
	wallpaper.free()
	main.care.toggle_rest()
	check(environment.ssao_enabled and light.shadow_enabled, "Rest lost the depth preferences")
	main.care.toggle_rest()
	main.choose_lighting("Moonlit")
	check(main.care.state.style.lights.occlusion and environment.ssao_enabled, "Lighting study did not apply occlusion")
	main.reset_lighting()
	check(not environment.ssao_enabled and not light.shadow_enabled, "Lighting reset left effects enabled")
	check(main.care.state.bond==42 and main.care.state.snacks==8 and main.care.state.journal==["A quiet afternoon."], "Appearance changes affected care progress")
	main.free()
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(PATH+suffix):DirAccess.remove_absolute(PATH+suffix)
	print("Gallery/depth: installed rigs, palette retention, real environment/light controls, shared wallpaper preferences and care preservation; failures=",failures)
	quit(1 if failures else 0)
