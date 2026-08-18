extends Node
class_name BettaRigAdapter

const MODEL_CANDIDATES := [
	"res://assets/models/bluemesh_betta/scene.gltf",
	"res://assets/models/bluemesh_betta/scene.glb",
	"res://assets/models/bluemesh_betta/betta_splendens.gltf",
	"res://assets/models/bluemesh_betta/betta_splendens.glb",
]

@export var animation_speed := 1.0
@export var auto_play := true

var model_root: Node3D
var animation_player: AnimationPlayer
var animation_tree: AnimationTree

func attach_to(host: Node3D) -> bool:
	var scene := _load_first_model()
	if scene == null:
		return false

	model_root = scene.instantiate() as Node3D
	if model_root == null:
		push_warning("TankWall: imported betta root is not Node3D")
		return false

	host.add_child(model_root)
	model_root.owner = host.owner
	animation_player = _find_animation_player(model_root)
	animation_tree = _find_animation_tree(model_root)

	if animation_player:
		animation_player.speed_scale = animation_speed
		if auto_play:
			play_best_swim_animation()

	return true

func play_best_swim_animation() -> void:
	if animation_player == null:
		return
	var names := animation_player.get_animation_list()
	if names.is_empty():
		return
	var preferred := ["swim", "swimming", "idle", "loop", "default", "take 01", "take 001"]
	for want in preferred:
		for name in names:
			if want in String(name).to_lower():
				_play_loop(name)
				return
	_play_loop(names[0])

func _play_loop(name: StringName) -> void:
	var anim := animation_player.get_animation(name)
	if anim:
		anim.loop_mode = Animation.LOOP_LINEAR
	animation_player.play(name)

func set_animation_speed(value: float) -> void:
	animation_speed = value
	if animation_player:
		animation_player.speed_scale = value

func set_body_tint(color: Color) -> void:
	if model_root == null:
		return
	_apply_tint_recursive(model_root, color)

func _apply_tint_recursive(node: Node, color: Color) -> void:
	if node is MeshInstance3D and "eye" not in node.name.to_lower():
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh:
			for surface in mesh_instance.mesh.get_surface_count():
				var source := mesh_instance.get_active_material(surface)
				if source is BaseMaterial3D:
					var material := source.duplicate() as BaseMaterial3D
					# Albedo color multiplies the imported albedo texture, preserving the
					# original scales, normal map and PBR detail while changing hue.
					material.albedo_color = color
					mesh_instance.set_surface_override_material(surface, material)
	for child in node.get_children():
		_apply_tint_recursive(child, color)

func list_animation_names() -> PackedStringArray:
	if animation_player:
		return animation_player.get_animation_list()
	return PackedStringArray()

func _load_first_model() -> PackedScene:
	for path in MODEL_CANDIDATES:
		if ResourceLoader.exists(path):
			var resource := load(path)
			if resource is PackedScene:
				print("TankWall: using imported betta model: ", path)
				return resource
	return null

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found:
			return found
	return null

func _find_animation_tree(node: Node) -> AnimationTree:
	if node is AnimationTree:
		return node
	for child in node.get_children():
		var found := _find_animation_tree(child)
		if found:
			return found
	return null
