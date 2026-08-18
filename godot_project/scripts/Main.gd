extends Node3D

@export var fish_scene: PackedScene
@export_range(1, 3) var fish_count := 1
@export var background_mode := "solid" # solid, image, video, gif_frames
@export var solid_background := Color(0.02, 0.05, 0.09, 1.0)
@export var background_file := "" # user-selected file copied into user://backgrounds

var fish_nodes: Array[Node3D] = []

func _ready() -> void:
	RenderingServer.set_default_clear_color(solid_background)
	_spawn_fish()
	_load_user_settings()

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
	var world_target = _screen_to_tank(screen_pos)
	if world_target == null:
		return
	for fish in fish_nodes:
		if fish.has_method("set_follow_target"):
			fish.set_follow_target(world_target, active)

func _clear_touch_target() -> void:
	for fish in fish_nodes:
		if fish.has_method("clear_follow_target"):
			fish.clear_follow_target()

func _screen_to_tank(screen_pos: Vector2):
	var camera := $Camera3D as Camera3D
	var ray_origin := camera.project_ray_origin(screen_pos)
	var ray_direction := camera.project_ray_normal(screen_pos)
	# Intersect touches with the middle of the tank. The fish still retains its
	# own depth, but steering toward this point gives Betta-style follow behavior.
	var tank_plane := Plane(Vector3(0, 0, 1), 0.0)
	return tank_plane.intersects_ray(ray_origin, ray_direction)

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
