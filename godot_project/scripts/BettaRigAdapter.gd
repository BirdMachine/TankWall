extends Node
class_name BettaRigAdapter

const SwimModifier = preload("res://scripts/BettaSwimModifier.gd")
const SurfaceBuilder = preload("res://scripts/BettaSurfaceBuilder.gd")

const MODEL_CANDIDATES := [
	"res://assets/models/bluemesh_betta/scene.gltf",
	"res://assets/models/bluemesh_betta/scene.glb",
	"res://assets/models/bluemesh_betta/betta_splendens.gltf",
	"res://assets/models/bluemesh_betta/betta_splendens.glb",
]

var model_root: Node3D
var animation_player: AnimationPlayer
var animation_tree: AnimationTree
var skeleton: Skeleton3D
var swim_modifier: SkeletonModifier3D
var membrane_materials: Array[ShaderMaterial] = []
var fin_clock := 0.0

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
	# The source clip contains model translation/rotation and is not an in-place
	# swim. Let only the controller steer and only the modifier deform this rig.
	if animation_player:
		animation_player.stop()
		animation_player.active = false
	if animation_tree:
		animation_tree.active = false
	skeleton = _find_skeleton(model_root)
	if skeleton == null:
		model_root.queue_free()
		return false
	skeleton.reset_bone_poses()
	# glTF embeds a Sketchfab axis conversion, a translated helper Cube and an
	# inverse-scaled armature. Normalize using the actual skeleton transform,
	# rather than applying the artist's axes to the already converted scene.
	var skeleton_in_model := model_root.global_transform.affine_inverse() * skeleton.global_transform
	# Level the rest-pose body (its tail slopes down ~20 degrees in source).
	model_root.transform = Transform3D(Basis(Vector3.RIGHT, 0.30), Vector3(0, -2.0, 0.7)) * skeleton_in_model.affine_inverse()
	_clean_source_helpers(model_root)
	swim_modifier = SwimModifier.new()
	if not swim_modifier.configure(skeleton):
		swim_modifier.free()
		swim_modifier = null
		model_root.queue_free()
		return false
	skeleton.add_child(swim_modifier)
	membrane_materials = SurfaceBuilder.prepare(model_root, skeleton, swim_modifier)

	return true

func _process(delta: float) -> void:
	fin_clock += minf(delta, 0.1)
	for material in membrane_materials:
		material.set_shader_parameter("fin_clock", fin_clock)

func set_swim_motion(speed_ratio: float, yaw_rate: float, pitch_rate: float, rate: float, pivot_bend := 0.0) -> void:
	if swim_modifier:
		swim_modifier.set_motion(speed_ratio, yaw_rate, pitch_rate, rate, pivot_bend)
	for material in membrane_materials:
		material.set_shader_parameter("flow_speed", speed_ratio)
		material.set_shader_parameter("turn_drag", clampf(yaw_rate, -2.0, 2.0))

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found:
			return found
	return null

func _clean_source_helpers(node: Node) -> void:
	if node is MeshInstance3D and node.name == "Cube_0":
		node.visible = false
	if node is Light3D:
		node.visible = false
	for child in node.get_children():
		_clean_source_helpers(child)

func set_body_tint(color: Color) -> void:
	if model_root == null:
		return
	_apply_tint_recursive(model_root, color)
	for material in membrane_materials:
		material.set_shader_parameter("tint", color)

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
