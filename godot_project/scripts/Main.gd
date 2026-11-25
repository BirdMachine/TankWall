extends Node3D

@export var fish_scene: PackedScene
@export_range(1, 3) var fish_count := 1
@export var background_mode := "solid" # solid, image, video, gif_frames
@export var solid_background := Color(0.02, 0.05, 0.09, 1.0)
@export var background_file := "" # user-selected file copied into user://backgrounds
@export var depth_range := 1.25

var fish_nodes: Array[Node3D] = []
var fish_speed := 0.78
var fish_turn_rate := 1.05
var fish_visual_scale := 1.0
var fish_animation_rate := 1.0
var fish_tint := Color.WHITE
var care
var play_mode := false
var touch_held := false
var companion_save_path := "user://companion.json"
var fish_model_variant := 0
var wallpaper_mode := false
var wallpaper_mode_override := false # repeatable desktop/service-state testing
var wallpaper_bridge
var tank_room: Node3D
var room_layout_key := ""

func _ready() -> void:
	RenderingServer.set_default_clear_color(solid_background)
	_load_user_settings()
	fish_count = 1
	wallpaper_bridge = preload("res://scripts/WallpaperBridge.gd").new()
	add_child(wallpaper_bridge)
	wallpaper_mode = wallpaper_mode_override or wallpaper_bridge.wallpaper
	Engine.max_fps = 60 if wallpaper_mode else 120
	care = preload("res://scripts/PetCompanion.gd").new()
	care.name = "Companion"
	care.save_path = companion_save_path
	care.read_only = wallpaper_mode
	add_child(care)
	care.delight.connect(_celebrate)
	fish_model_variant = care.state.model_variant
	_spawn_fish()
	care._apply_rest()
	tank_room = preload("res://scripts/TankRoom.gd").new()
	add_child(tank_room)
	apply_companion_view()
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	print("TamoTank: ", "wallpaper" if wallpaper_mode else "companion", " ready; view=", care.state.view_mode)
	if wallpaper_mode and not DisplayServer.get_name() == "headless":
		RenderingServer.frame_post_draw.connect(func(): print("TamoTank: wallpaper frame drawn; viewport=", get_viewport().get_visible_rect().size), CONNECT_ONE_SHOT)

func _celebrate() -> void:
	if wallpaper_mode or fish_nodes.is_empty():
		return
	var bubbles := preload("res://scripts/WaterSparkles.gd").new()
	add_child(bubbles)
	bubbles.position = fish_nodes[0].position

func _process(delta: float) -> void:
	if play_mode and touch_held and care:
		care.follow_for(delta)

func _spawn_fish() -> void:
	for node in fish_nodes:
		node.queue_free()
	fish_nodes.clear()
	var count := clampi(fish_count, 1, 3)
	for i in count:
		var fish := fish_scene.instantiate() as Node3D
		fish.model_variant = fish_model_variant
		add_child(fish)
		fish.position = Vector3(-(count - 1) * 0.35 + i * 0.7, 0.15 * i, 0)
		fish.set("lane", i)
		fish_nodes.append(fish)
		_apply_fish_settings(fish)
	_configure_swim_bounds()
	configure_brains()
	apply_fin_motion()
	if care:
		care._apply_appearance()
		care._apply_rest()

func configure_brains() -> void:
	if care == null:
		return
	for fish in fish_nodes:
		if fish.brain == null:
			fish.brain = preload("res://scripts/FishBrain.gd").new()
			fish.add_child(fish.brain)
		fish.brain.configure(care.state.personality, int(care.state.adopted_at * 1000.0))
		var calmness := 0.80 if care.state.personality == "calm" else 0.68 if care.state.personality == "dreamy" else 1.0
		fish.set_cruise_speed(fish_speed * calmness)
		fish.set_animation_rate(fish_animation_rate * lerpf(0.75, 1.0, calmness))
		fish.retarget_time = 0.0

func _apply_fish_settings(fish: Node3D) -> void:
	if fish.has_method("set_cruise_speed"):
		fish.set_cruise_speed(fish_speed)
	if fish.has_method("set_turn_rate"):
		fish.set_turn_rate(fish_turn_rate)
	if fish.has_method("set_visual_scale"):
		fish.set_visual_scale(fish_visual_scale)
	if fish.has_method("set_animation_rate"):
		fish.set_animation_rate(fish_animation_rate)
	if fish.has_method("set_body_tint"):
		fish.set_body_tint(fish_tint)

func _on_viewport_size_changed() -> void:
	call_deferred("_configure_swim_bounds")

func _configure_swim_bounds() -> void:
	if fish_nodes.is_empty():
		return
	var rect := get_viewport().get_visible_rect()
	var points: Array[Vector3] = []
	var top := rect.size.y * 0.18
	var bottom := rect.size.y * 0.72
	var left := 0.0
	var right := rect.size.x
	if rect.size.x > rect.size.y:
		top = rect.size.y * 0.06
		bottom = rect.size.y * 0.94
		left = rect.size.x * 0.31
		right = rect.size.x * 0.70
	if wallpaper_mode:
		top = 0
		bottom = rect.size.y
		left = 0
		right = rect.size.x
	for screen_point in [
		Vector2(left, top),
		Vector2(right, top),
		Vector2(left, bottom),
		Vector2(right, bottom),
	]:
		var p = _screen_to_plane(screen_point, 0.0)
		if p != null:
			points.append(p)
	if points.size() < 4:
		return

	var min_x := points[0].x
	var max_x := points[0].x
	var min_y := points[0].y
	var max_y := points[0].y
	for p in points:
		min_x = minf(min_x, p.x)
		max_x = maxf(max_x, p.x)
		min_y = minf(min_y, p.y)
		max_y = maxf(max_y, p.y)

	# Keep the fish's center slightly inside the screen while allowing fins to
	# disappear beyond the edge, as in Betta 120Hz. This automatically expands
	# in landscape instead of trapping the fish in a narrow portrait-sized box.
	var margin_x := maxf(0.42, (max_x - min_x) * 0.055)
	var margin_y := maxf(0.36, (max_y - min_y) * 0.07)
	var bounds_min := Vector3(min_x + margin_x, min_y + margin_y, -depth_range)
	var bounds_max := Vector3(max_x - margin_x, max_y - margin_y, depth_range)
	for fish in fish_nodes:
		if fish.has_method("set_swim_bounds"):
			fish.set_swim_bounds(bounds_min, bounds_max)
	_refresh_tank_room()

func apply_companion_view() -> void:
	if care == null:
		return
	var colour := Color.html(care.state.backwall)
	if care.state.resting:
		colour = colour.darkened(0.60)
	solid_background = colour
	var environment: Environment = $WorldEnvironment.environment
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = colour
	RenderingServer.set_default_clear_color(colour)
	_refresh_tank_room()

func _refresh_tank_room() -> void:
	if tank_room == null or care == null or fish_nodes.is_empty():
		return
	tank_room.visible = care.state.view_mode == "tank"
	if not tank_room.visible:
		return
	var pet = fish_nodes[0]
	var key := str(pet.swim_bounds_min) + str(pet.swim_bounds_max) + solid_background.to_html()
	if key != room_layout_key:
		room_layout_key = key
		tank_room.build(pet.swim_bounds_min, pet.swim_bounds_max, solid_background)

func set_view_mode(mode: String) -> void:
	care.state.view_mode = "tank" if mode == "tank" else "showcase"
	apply_companion_view()
	care._finish("A little room with a view." if mode == "tank" else "Just your fish and a quiet backwall.")

func set_backwall(colour: Color) -> void:
	care.state.backwall = colour.to_html()
	apply_companion_view()
	care.save()

func set_model_variant(index: int) -> void:
	care.state.model_variant = clampi(index, 0, 2)
	fish_model_variant = care.state.model_variant
	_spawn_fish()
	care._finish("A lovely new silhouette.")

func set_personality(kind: String) -> void:
	care.state.personality = kind
	configure_brains()
	care._finish("A little %s soul." % kind)

func apply_fin_motion() -> void:
	if care == null:
		return
	for fish in fish_nodes:
		if fish.rig_adapter and fish.rig_adapter.get("fin_physics") != null:
			fish.rig_adapter.live_fins = care.state.live_fins
			fish.rig_adapter.fin_freedom = care.state.fin_freedom

func set_fin_motion(enabled: bool) -> void:
	care.state.live_fins = enabled
	apply_fin_motion()
	care.save()
	care.changed.emit()

func set_fin_freedom(value: float) -> void:
	care.state.fin_freedom = clampf(value, 0.5, 2.2)
	apply_fin_motion()
	care.save()
	care.changed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if not play_mode:
		if (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
			for fish in fish_nodes:
				var point = _screen_to_plane(event.position, fish.position.z)
				if point != null and fish.brain and not fish.resting:
					fish.brain.notice(point)
					fish.retarget_time = minf(fish.retarget_time, 0.6)
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_set_touch_target(event.position, true)
		else:
			_clear_touch_target()
	elif event is InputEventScreenDrag:
		_set_touch_target(event.position, true)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_set_touch_target(event.position, true)
			else:
				_clear_touch_target()
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_set_touch_target(event.position, true)

func _set_touch_target(screen_pos: Vector2, active: bool) -> void:
	touch_held = active
	if care and not care.pellets.is_empty():
		return
	# Preserve the fish's current depth while steering toward the touched x/y.
	# This avoids every touch collapsing the animal onto the z=0 plane.
	for fish in fish_nodes:
		var z := fish.position.z
		var world_target = _screen_to_plane(screen_pos, z)
		if world_target != null and fish.has_method("set_follow_target"):
			fish.set_follow_target(world_target, active)

func _clear_touch_target() -> void:
	touch_held = false
	for fish in fish_nodes:
		if fish.has_method("clear_follow_target"):
			fish.clear_follow_target()

func _screen_to_plane(screen_pos: Vector2, z_value: float):
	var camera := $Camera3D as Camera3D
	var ray_origin := camera.project_ray_origin(screen_pos)
	var ray_direction := camera.project_ray_normal(screen_pos)
	var tank_plane := Plane(Vector3(0, 0, 1), z_value)
	return tank_plane.intersects_ray(ray_origin, ray_direction)

# --- Live settings API -----------------------------------------------------
# These methods are intentionally small and stable. The HUD uses them now;
# later the Android BroadcastReceiver/Tasker/KWGT bridge can call the same API.

func set_fish_speed(value: float) -> void:
	fish_speed = clampf(value, 0.25, 1.8)
	for fish in fish_nodes:
		if fish.has_method("set_cruise_speed"):
			fish.set_cruise_speed(fish_speed)

func set_fish_turn_rate(value: float) -> void:
	fish_turn_rate = clampf(value, 0.35, 2.6)
	for fish in fish_nodes:
		if fish.has_method("set_turn_rate"):
			fish.set_turn_rate(fish_turn_rate)

func set_fish_size(value: float) -> void:
	fish_visual_scale = clampf(value, 0.45, 1.7)
	for fish in fish_nodes:
		if fish.has_method("set_visual_scale"):
			fish.set_visual_scale(fish_visual_scale)

func set_fish_animation_rate(value: float) -> void:
	fish_animation_rate = clampf(value, 0.35, 1.8)
	for fish in fish_nodes:
		if fish.has_method("set_animation_rate"):
			fish.set_animation_rate(fish_animation_rate)

func set_fish_tint(value: Color) -> void:
	fish_tint = value
	for fish in fish_nodes:
		if fish.has_method("set_body_tint"):
			fish.set_body_tint(fish_tint)

func set_depth_range(value: float) -> void:
	depth_range = clampf(value, 0.4, 3.2)
	_configure_swim_bounds()

func set_background_color(value: Color) -> void:
	solid_background = value
	RenderingServer.set_default_clear_color(value)

func set_light_energy(value: float) -> void:
	var light := $DirectionalLight3D as DirectionalLight3D
	light.light_energy = clampf(value, 0.1, 6.0)

func _load_user_settings() -> void:
	var path := "user://settings.json"
	if not FileAccess.file_exists(path):
		return
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	if typeof(parsed) == TYPE_DICTIONARY:
		fish_count = int(parsed.get("fish_count", fish_count))
		background_mode = str(parsed.get("background_mode", background_mode))
		background_file = str(parsed.get("background_file", background_file))
