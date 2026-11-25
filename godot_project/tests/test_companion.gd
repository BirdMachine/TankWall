extends SceneTree

const State = preload("res://scripts/PetState.gd")
var failures := 0
const TEST_PATH := "user://companion-regression.json"
const INTEGRATION_PATH := "user://companion-integration.json"

func check(ok: bool, text: String) -> void:
	if not ok:
		failures += 1
		push_error(text)

func _initialize() -> void:
	call_deferred("_run")

func clean_path(path: String) -> void:
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)

func _run() -> void:
	clean_path(TEST_PATH)
	clean_path(INTEGRATION_PATH)
	var state = State.new()
	state.initialize(1000.0)
	state.pet_name = "Pebble"
	state.record_care("snack")
	state.record_care("play")
	state.record_care("refresh")
	state.look = 2
	check(state.save_to(TEST_PATH) == OK, "Save failed")
	var later = State.new()
	check(later.load_from(TEST_PATH, 1000.0 + 86400.0 * 365.0), "Long absence save failed to load")
	check(later.bond == state.bond and later.snacks == 1 and later.games == 1, "Absence must never remove progress")
	check(later.pet_name == "Pebble" and later.look == 2 and later.journal == state.journal, "Name, appearance or memories not restored")
	check(not later.resting, "Time away changed a chosen rest mode")
	check(later.save_to(TEST_PATH) == OK, "Backup save failed")
	var damaged := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	damaged.store_string("{interrupted")
	damaged.close()
	var recovered = State.new()
	check(recovered.load_from(TEST_PATH, 999999.0) and recovered.bond == state.bond, "Backup recovery lost companion")

	var main = load("res://scenes/Main.tscn").instantiate()
	main.companion_save_path = INTEGRATION_PATH
	root.add_child(main)
	await process_frame
	await process_frame
	var care = main.care
	var fish = care.fish()
	care.set_process(false)
	fish.set_physics_process(false)
	# Real controller, including boundary avoidance and compound pivots. A snack
	# must be reached and eaten, rather than awarded when the button is pressed.
	for side in [-1.0, 0.0, 1.0]:
		fish.position = (fish.swim_bounds_min + fish.swim_bounds_max) * 0.5
		fish.position.x = lerpf(fish.swim_bounds_min.x, fish.swim_bounds_max.x, (side + 1.0) * 0.5)
		fish.heading = Vector3(side if side != 0.0 else 1.0, 0, 0)
		fish.pivot.stage = "cruise"
		fish.pivot.bend = 0.0
		fish.departure_distance = 0.0
		fish.rng.seed = 42
		care.snack_cooldown = 0.0
		var before: int = care.state.snacks
		care.offer_snack()
		check(care.state.snacks == before, "Snack counted before contact")
		for frame in 1500:
			fish._physics_process(1.0 / 60.0)
			care._process(1.0 / 60.0)
			if care.pellets.is_empty():
				break
		check(care.state.snacks == before + 1, "Snack was unreachable at side " + str(side))
		check(care.pellets.is_empty(), "Pellet was not removed")
	var original_bond: int = care.state.bond
	care.toggle_rest()
	var original_position: Vector3 = fish.position
	for frame in 120:
		fish._physics_process(1.0 / 60.0)
	check(fish.position.is_equal_approx(original_position) and care.state.resting, "Rest must be calm and persistent")
	care.offer_snack()
	check(care.pellets.is_empty() and care.state.bond == original_bond, "Rest changed progress or spawned food")
	care.toggle_rest()
	care.begin_play()
	main.touch_held = true
	main._process(3.2)
	check(care.state.games == 1, "Following did not record a game")
	main._process(30.0)
	check(care.state.games == 1, "Held input repeatedly rewarded one game")
	care.begin_play()
	check(not fish.follow_active and not main.touch_held, "Ending play left a stuck steering target")
	care.refresh_water()
	care.refresh_water()
	check(care.state.refreshes == 1, "Refresh cooldown did not prevent duplicate events")
	care.rename_pet("  Mochi  ")
	care.choose_look(3)
	var reloaded = State.new()
	check(reloaded.load_from(INTEGRATION_PATH, Time.get_unix_time_from_system()), "Integrated save didn't load")
	check(reloaded.pet_name == "Mochi" and reloaded.look == 3 and reloaded.snacks == 3, "Care flow didn't persist")
	main.free()
	clean_path(TEST_PATH)
	clean_path(INTEGRATION_PATH)
	print("Companion: no absence penalty, saved identity/memories, backup recovery, 3 food approaches, rest, play and refresh; failures=", failures)
	quit(1 if failures else 0)
