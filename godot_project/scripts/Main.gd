extends Node3D

@export var fish_scene: PackedScene
@export_range(1, 3) var fish_count := 1
@export var background_mode := "solid" # solid, image, video, gif_frames
@export var solid_background := Color(0.02, 0.05, 0.09, 1.0)
@export var background_file := "" # user-selected file copied into user://backgrounds
@export var depth_range := 2.45

var fish_nodes: Array[Node3D] = []
var fish_speed := 0.78
var fish_turn_rate := 1.05
var fish_visual_scale := 1.0
var fish_animation_rate := 1.0
var fish_tint := Color.WHITE

func _ready() -> void:
	RenderingServer.set_default_clear_color(solid_background)
	_spawn_fish()
	_load_user_settings()
	get_viewport().size_changed.connect(_on_viewport_size_changed)

func _spawn_fish() -> void:
	for node in fish_nodes:
		node.queue_free()
	fish_nodes.clear()
	var count := clampi(fish_count, 1, 3)
	for i in count:
		var fish := fish_scene.instantiate() as Node3D
		add_child(fish)
		fish.position = Vector3(-0.65 + i * 0.65, 0.15 * i, 0)
		fish.set("lane", i)
		fish_nodes.append(fish)
		_apply_fish_settings(fish)
	_configure_swim_bounds()

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
	for screen_point in [
		Vector2(0, 0),
		Vector2(rect.size.x, 0),
		Vector2(0, rect.size.y),
		Vector2(rect.size.x, rect.size.y),
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

func _unhandled_input(event: InputEvent) -> void:
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
	# Preserve the fish's current depth while steering toward the touched x/y.
	# This avoids every touch collapsing the animal onto the z=0 plane.
	for fish in fish_nodes:
		var z := fish.position.z
		var world_target = _screen_to_plane(screen_pos, z)
		if world_target != null and fish.has_method("set_follow_target"):
			fish.set_follow_target(world_target, active)

func _clear_touch_target() -> void:
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
		_spawn_fish()
