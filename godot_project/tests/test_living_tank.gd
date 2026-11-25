extends SceneTree
const State = preload("res://scripts/PetState.gd")
const Brain = preload("res://scripts/FishBrain.gd")
const PATH := "user://living-tank-test.json"
var failures := 0
func check(ok: bool, text: String) -> void:
	if not ok:
		failures += 1
		push_error(text)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(PATH + suffix):
			DirAccess.remove_absolute(PATH + suffix)
	var seed_value := 321
	for kind in ["curious", "calm", "dreamy"]:
		var brain := Brain.new()
		brain.configure(kind, seed_value)
		var labels := {}
		for i in 150:
			var choice: Dictionary = brain.choose_target(Vector3.ZERO, Vector3(-1, -2, -1), Vector3(1, 2, 1))
			check(choice.target.is_finite() and choice.target.is_equal_approx(choice.target.clamp(Vector3(-1, -2, -1), Vector3(1, 2, 1))), "Brain chose an unreachable point")
			labels[brain.state_label] = true
		check(labels.size() >= 3, "Personality didn't vary its behaviour")
		brain.notice(Vector3(0.2, 0.3, 0.4))
		var noticed := false
		for i in 30:
			brain.choose_target(Vector3.ZERO, Vector3(-1, -2, -1), Vector3(1, 2, 1))
			noticed = noticed or brain.state_label.contains("ripple")
		check(noticed, "Fish didn't investigate an interaction")
		brain._process(5.0)
		check(brain.interest_left == 0.0, "Interest never expired")
		brain.free()
	var state = State.new()
	state.initialize(1000.0)
	state.pet_name = "Pebble"
	state.view_mode = "tank"
	state.model_variant = 0
	state.backwall = "185b67ff"
	state.personality = "dreamy"
	state.record_care("snack")
	check(state.save_to(PATH) == OK, "Could not prepare shared companion")
	var before := FileAccess.get_file_as_string(PATH)
	var main = load("res://scenes/Main.tscn").instantiate()
	main.wallpaper_mode_override = true
	main.companion_save_path = PATH
	root.add_child(main)
	await process_frame
	await process_frame
	check(main.wallpaper_mode and main.care.read_only, "Wallpaper must be a read-only companion view")
	check(main.tank_room.visible and main.tank_room.get_child_count() >= 6, "Tank room didn't build")
	check(main.get_node_or_null("AeroHUD") == null, "Care UI leaked into wallpaper")
	main.care._process(3600.0)
	main.care.save()
	check(before == FileAccess.get_file_as_string(PATH), "Wallpaper overwrote foreground care progress")
	state.pet_name = "Mochi"
	state.look = 2
	state.view_mode = "showcase"
	state.personality = "calm"
	state.save_to(PATH)
	main.care.reload_from_disk()
	check(main.care.state.pet_name == "Mochi" and not main.tank_room.visible, "Wallpaper didn't pick up foreground settings")
	check(main.fish_nodes[0].brain.personality == "calm", "Personality wasn't applied to the resident")
	check(main.fish_nodes[0].cruise_speed < main.fish_speed, "Calm personality didn't change the actual swimming pace")
	check(main.care.state.bond == state.bond, "Shared progress changed during refresh")
	main.free()
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(PATH + suffix):
			DirAccess.remove_absolute(PATH + suffix)
	print("Living tank: 450 bounded behaviour choices, interaction interest, physical room, clean wallpaper view, read-only progress and foreground updates; failures=", failures)
	quit(1 if failures else 0)
