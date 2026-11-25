extends SceneTree
const State = preload("res://scripts/PetState.gd")
const Style = preload("res://scripts/AquariumStyle.gd")
const PATH := "user://customization-test.json"
var failures := 0
func check(ok: bool, text: String) -> void:
	if not ok:
		failures += 1
		push_error(text)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var old = State.new()
	old.from_data({"version": 1, "pet_name": "Pebble", "bond": 42, "look": 2,
		"snacks": 8, "journal": ["A good day."], "adopted_at": 1000}, 900000.0)
	check(old.bond == 42 and old.snacks == 8 and old.look == 2, "Old care/look changed during style migration")
	check(old.style == Style.defaults(), "Old save did not retain natural colours and original lighting")
	var invalid := Style.sanitize({"fish": {"base": "no-colour", "brightness": INF,
		"shine": -40, "saturation": 90, "details": "abc8", "enabled": "false"},
		"lights": {"energy": -20, "yaw": NAN, "fill_energy": 900}})
	check(invalid.fish.base == Style.FISH.base and invalid.fish.brightness == 1.0, "Malformed colour/non-finite value accepted")
	check(invalid.fish.shine == 0 and invalid.fish.saturation == 2 and not invalid.fish.enabled, "Malformed shader range/boolean accepted")
	check(Color.html(invalid.fish.details).a == 1.0 and invalid.lights.energy == 0 and invalid.lights.fill_energy == 3, "Colour opacity/light bounds not enforced")
	old.style.fish = Style.palette("Sea glass")
	old.style.lights.merge({"key": "ffba72ff", "energy": 2.3, "fill": "946affff", "fill_energy": 1.2, "ambient": 0.4}, true)
	check(old.save_to(PATH) == OK, "Could not prepare style fixture")
	var saved := FileAccess.get_file_as_string(PATH)
	var main = load("res://scenes/Main.tscn").instantiate()
	main.wallpaper_mode_override = true
	main.companion_save_path = PATH
	root.add_child(main)
	await process_frame
	await process_frame
	var fish = main.fish_nodes[0]
	var fish_id: int = fish.get_instance_id()
	var light: DirectionalLight3D = main.get_node("DirectionalLight3D")
	check(light.light_color.is_equal_approx(Color("ffba72")) and is_equal_approx(light.light_energy, 2.3), "Saved key light not applied")
	check(main.fill_light.visible and is_equal_approx(main.fill_light.light_energy, 1.2), "Saved fill light not applied")
	check(FileAccess.get_file_as_string(PATH) == saved, "Wallpaper wrote during style load")
	fish.pivot.bend = 0.19
	old.style.fish = Style.palette("Ember")
	old.style.lights.yaw = -65.0
	old.save_to(PATH)
	var updated := FileAccess.get_file_as_string(PATH)
	main.care.reload_from_disk()
	check(main.fish_nodes[0].get_instance_id() == fish_id and is_equal_approx(fish.pivot.bend, 0.19), "Colour refresh reset the resident's motion")
	check(light.rotation_degrees.is_equal_approx(Vector3(-30, -65, 0)), "Saved light direction did not refresh")
	for material in fish.rig_adapter.colour_materials():
		check(material.get_shader_parameter("palette_enabled") == true, "Body/fin did not receive palette")
		check(material.get_shader_parameter("palette_base").is_equal_approx(Color.html(old.style.fish.base)), "Body/fin colour not refreshed")
	main.care.state.resting = true
	main.care._apply_rest()
	check(is_equal_approx(light.light_energy, 0.46) and is_equal_approx(main.fill_light.light_energy, 0.24), "Rest did not dim configured lights")
	main.care.state.resting = false
	main.care._apply_rest()
	check(is_equal_approx(light.light_energy, 2.3) and is_equal_approx(main.fill_light.light_energy, 1.2), "Wake lost configured lighting")
	main.care._process(7200.0)
	main.care.save()
	check(FileAccess.get_file_as_string(PATH) == updated and main.care.state.bond == 42, "Wallpaper colour changes overwrote care")
	main.free()
	# All available rigs, including the public fallback, share the same controls.
	for variant in 3:
		var resident = load("res://scenes/Fish.tscn").instantiate()
		resident.model_variant = variant
		root.add_child(resident)
		resident.rig_adapter.set_colour_style(Style.palette("Rose quartz"))
		var materials: Array = resident.rig_adapter.colour_materials()
		check(not materials.is_empty(), "Rig has no customisable surfaces")
		for material in materials:
			check(material.get_shader_parameter("palette_enabled") == true, "A fin/body surface lost customization")
		if resident.rig_adapter.get("materials") != null:
			for material in resident.rig_adapter.materials:
				if material.get_meta("eye", false):
					check(not material.get_shader_parameter("palette_enabled"), "Fish recolour changed the eyes")
		resident.free()
	# Exercise real foreground controls, delayed writes, and round-trip loading.
	main = load("res://scenes/Main.tscn").instantiate()
	main.companion_save_path = PATH
	root.add_child(main)
	await process_frame
	await process_frame
	var hud = main.get_node("AeroHUD")
	hud._show_looks()
	var picker = hud.modal_body.get_node("fish_base")
	picker.color_changed.emit(Color("55aaff"))
	check(main.care.state.style.fish.base == "55aaffff", "Colour picker didn't reach live fish")
	main.set_style_value("fish", "brightness", 1.2)
	main.care._process(0.5)
	var loaded = State.new()
	check(loaded.load_from(PATH, Time.get_unix_time_from_system()) and loaded.style.fish.brightness == 1.2, "Debounced colour change did not persist")
	hud._show_lighting()
	hud.modal_body.get_node("lights_energy").value = 3.1
	check(is_equal_approx(main.get_node("DirectionalLight3D").light_energy, 3.1), "Light slider didn't update rendering")
	main.choose_palette("Original")
	main.reset_lighting()
	check(main.care.state.style == Style.defaults() and main.care.state.look == 0, "Reset did not restore original fish/lights")
	check(main.care.state.snacks == 8 and main.care.state.journal == ["A good day."], "Appearance controls changed care history")
	main.free()
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(PATH + suffix):
			DirAccess.remove_absolute(PATH + suffix)
	print("Customisation: migration, validation, all rig surfaces, live UI, persistence, rest/wake and read-only wallpaper; failures=", failures)
	quit(1 if failures else 0)
