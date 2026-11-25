extends Node

signal changed
signal message(text: String)
signal delight

const State = preload("res://scripts/PetState.gd")
const SAVE_PATH := "user://companion.json"
const LOOKS := [Color.WHITE, Color(0.65, 0.82, 1.0), Color(1.0, 0.63, 0.82), Color(0.6, 1.0, 0.88)]
var state = State.new()
var save_path := SAVE_PATH
var pellets: Array = []
var snack_cooldown := 0.0
var play_cooldown := 0.0
var refresh_cooldown := 0.0
var save_clock := 0.0
var play_time := 0.0
var play_rewarded := false
var last_save_error := OK
var read_only := false
var reload_clock := 0.0
var loaded_text := ""
var preference_save_clock := -1.0

func _ready() -> void:
	var now := Time.get_unix_time_from_system()
	state.load_from(save_path, now)
	loaded_text = FileAccess.get_file_as_string(save_path) if FileAccess.file_exists(save_path) else ""
	if not read_only and now - state.last_seen > 900.0:
		state.visits += 1
	state.last_seen = now
	_apply_appearance()
	_apply_rest()
	save()

func _process(delta: float) -> void:
	if read_only:
		reload_clock += delta
		if reload_clock >= 2.0:
			reload_clock = 0.0
			reload_from_disk()
		return
	if preference_save_clock >= 0.0:
		preference_save_clock -= delta
		if preference_save_clock < 0.0:
			save()
	snack_cooldown = maxf(0.0, snack_cooldown - delta)
	play_cooldown = maxf(0.0, play_cooldown - delta)
	refresh_cooldown = maxf(0.0, refresh_cooldown - delta)
	save_clock += delta
	if save_clock > 30.0:
		save_clock = 0.0
		save()
	_update_pellets(delta)

func fish() -> Node3D:
	var main = get_parent()
	return main.fish_nodes[0] if not main.fish_nodes.is_empty() else null

func offer_snack() -> void:
	if snack_cooldown > 0.0 or not pellets.is_empty():
		message.emit("A tiny nibble is on its way.")
		return
	if state.resting:
		message.emit("Resting peacefully. Tap Wake for a visit.")
		return
	var pet := fish()
	if pet == null:
		return
	# Place a snack near the nose's depth and safely inside the reachable tank.
	var centre: Vector3 = (pet.swim_bounds_min + pet.swim_bounds_max) * 0.5
	var target: Vector3 = pet.position.lerp(centre, 0.5) + pet.heading * 0.2 + Vector3(0, 0.18, 0)
	target = pet._clamp_to_bounds(target)
	var pellet := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.043
	sphere.height = 0.086
	pellet.mesh = sphere
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.76, 0.36)
	material.emission_enabled = true
	material.emission = Color(0.8, 0.3, 0.04)
	pellet.material_override = material
	get_parent().add_child(pellet)
	pellet.position = target
	pellets.append({"node": pellet, "age": 0.0})
	pet.set_follow_target(target)
	snack_cooldown = 4.0
	message.emit("A little golden snack, just for %s." % state.pet_name)

func _update_pellets(delta: float) -> void:
	var pet := fish()
	if pet == null:
		return
	for i in range(pellets.size() - 1, -1, -1):
		var item: Dictionary = pellets[i]
		item.age += delta
		var pellet: Node3D = item.node
		pellet.position.y = maxf(pet.swim_bounds_min.y + 0.15, pellet.position.y - delta * 0.025)
		pet.set_follow_target(pellet.position)
		var eaten := pet.position.distance_to(pellet.position) < 0.28
		if eaten or item.age > 24.0:
			pellet.queue_free()
			pellets.remove_at(i)
			pet.clear_follow_target()
			if eaten:
				state.record_care("snack")
				_finish("Nibble! A lovely little moment together.")
			else:
				message.emit("That snack drifted away. We can try another.")

func refresh_water() -> void:
	if refresh_cooldown > 0.0:
		message.emit("Still sparkling beautifully.")
		return
	refresh_cooldown = 12.0
	state.record_care("refresh")
	_finish("Fresh sparkles. Same happy little fish.")

func begin_play() -> void:
	if state.resting:
		message.emit("Resting peacefully. Tap Wake for a visit.")
		return
	get_parent()._clear_touch_target()
	get_parent().play_mode = not get_parent().play_mode
	play_time = 0.0
	play_rewarded = false
	changed.emit()
	message.emit("Touch and hold the water. %s will follow." % state.pet_name if get_parent().play_mode else "Back to a gentle wander.")

func follow_for(delta: float) -> void:
	if state.resting or play_cooldown > 0.0 or play_rewarded:
		return
	play_time += delta
	if play_time > 3.0:
		play_rewarded = true
		play_cooldown = 12.0
		state.record_care("play")
		_finish("A little game of follow-the-finger.")

func toggle_rest() -> void:
	get_parent()._clear_touch_target()
	state.resting = not state.resting
	get_parent().play_mode = false
	if not pellets.is_empty():
		for pellet in pellets:
			pellet.node.queue_free()
		pellets.clear()
	_apply_rest()
	_finish("A soft, peaceful rest." if state.resting else "A slow stretch. Hello again!")

func rename_pet(value: String) -> void:
	var cleaned := value.strip_edges().replace("\n", " ").left(24)
	if cleaned.is_empty():
		return
	state.pet_name = cleaned
	_finish("Hello, %s." % cleaned)

func choose_look(index: int) -> void:
	state.look = clampi(index, 0, LOOKS.size() - 1)
	_apply_appearance()
	_finish("A little change of colour.")

func _apply_appearance() -> void:
	get_parent().set_fish_tint(LOOKS[state.look])
	get_parent().apply_fish_colours()

func _apply_rest() -> void:
	var pet := fish()
	if pet:
		pet.resting = state.resting
		pet.clear_follow_target()
		# Release a turning curl instead of freezing the body mid-manoeuvre.
		pet.pivot.stage = "cruise"
		pet.pivot.bend = 0.0
		pet.departure_distance = 0.0
	if get_parent().has_method("apply_companion_view"):
		get_parent().apply_companion_view()
	get_parent().apply_lighting()

func _finish(text: String) -> void:
	save()
	changed.emit()
	message.emit(text)
	delight.emit()

func queue_preferences_save() -> void:
	# Preview at frame rate; coalesce slider/colour drags into one disk write.
	preference_save_clock = 0.35

func save() -> void:
	if read_only:
		return
	preference_save_clock = -1.0
	state.last_seen = Time.get_unix_time_from_system()
	last_save_error = state.save_to(save_path)
	if last_save_error != OK:
		message.emit("Couldn't save this visit yet. Please keep the app open.")

func reload_from_disk() -> void:
	if not read_only or not FileAccess.file_exists(save_path):
		return
	var content := FileAccess.get_file_as_string(save_path)
	if content == loaded_text:
		return
	var prior := state.to_data()
	if not state.load_from(save_path, Time.get_unix_time_from_system()):
		return
	loaded_text = content
	print("TamoTank: wallpaper preferences refreshed")
	if prior.model_variant != state.model_variant:
		get_parent().fish_model_variant = state.model_variant
		get_parent()._spawn_fish()
	if prior.look != state.look or prior.style.fish != state.style.fish:
		_apply_appearance()
	if prior.resting != state.resting:
		_apply_rest()
	if prior.personality != state.personality:
		get_parent().configure_brains()
	if prior.live_fins != state.live_fins or prior.fin_freedom != state.fin_freedom:
		get_parent().apply_fin_motion()
	get_parent().apply_companion_view()
	get_parent().apply_lighting()
	changed.emit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		save()
