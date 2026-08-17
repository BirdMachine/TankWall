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
		fish.position = Vector3(-1.0 + i, 0.15 * i, 0)
		fish.set("swim_phase", i * 1.7)
		fish.set("lane", i)
		fish_nodes.append(fish)

func _load_user_settings() -> void:
	# Future Android settings activity writes JSON here.
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
