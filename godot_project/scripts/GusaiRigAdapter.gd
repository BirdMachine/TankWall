extends Node
## Private model adapter; retain the source rig and its baked fin dynamics.
const Flesh = preload("res://shaders/GusaiFlesh.gdshader")
const Driver = preload("res://scripts/GusaiPoseDriver.gd")
const FinPhysics = preload("res://scripts/FinDynamics.gd")
const MODELS := ["res://assets/models/gusai_betta/split_tail_mobile.glb", "res://assets/models/gusai_betta/big_tail_mobile.glb"]
var variant := 0
var model_root: Node3D
var skeleton: Skeleton3D
var animation_player: AnimationPlayer
var materials: Array[ShaderMaterial] = []
var speed_ratio := 0.3
var animation_rate := 1.0
var yaw := 0.0
var pitch := 0.0
var target_yaw := 0.0
var target_pitch := 0.0
var triangle_count := 0
var root_bone := -1
var root_position := Vector3.ZERO
var root_rotation := Quaternion.IDENTITY
var head_pivot := Vector3(0, 0, 3.4)
var fin_physics = FinPhysics.new()
var native_cloth = preload("res://scripts/NativeFinCloth.gd").new()
var fin_backend := "water"
var live_fins := true
var fin_freedom := 2.2

static func available(index := 0) -> bool:
	return ResourceLoader.exists(MODELS[clampi(index, 0, 1)])

func attach_to(host: Node3D) -> bool:
	if not available(variant):
		return false
	model_root = load(MODELS[variant]).instantiate()
	host.add_child(model_root)
	skeleton = _find(model_root, "Skeleton3D")
	animation_player = _find(model_root, "AnimationPlayer")
	if skeleton == null or animation_player == null:
		return false
	var selected: StringName = animation_player.get_animation_list()[-1]
	for name in animation_player.get_animation_list():
		if name == "Anim_0":
			selected = name
	animation_player.get_animation(selected).loop_mode = Animation.LOOP_LINEAR
	animation_player.play(selected)
	animation_player.seek(0.0, true)
	animation_player.advance(0.0)
	skeleton.force_update_all_bone_transforms()
	root_bone = skeleton.find_bone("Spine")
	if root_bone >= 0:
		root_position = skeleton.get_bone_pose_position(root_bone)
		root_rotation = skeleton.get_bone_pose_rotation(root_bone)
	var head := skeleton.find_bone("Head")
	if head >= 0:
		head_pivot = model_root.global_transform.affine_inverse() * skeleton.global_transform * skeleton.get_bone_global_pose(head).origin
	_prepare_tree(model_root)
	fin_physics.configure(skeleton)
	var driver := Driver.new()
	driver.adapter = self
	skeleton.add_child(driver)
	native_cloth.configure(skeleton, fin_physics.rays)
	apply_visual_scale(host, 1.0)
	print("Gusai rig: variant=", variant, " bones=", skeleton.get_bone_count(), " triangles=", triangle_count, " head=", head_pivot)
	return not materials.is_empty()

func _find(node: Node, kind: String):
	if node.is_class(kind):
		return node
	for child in node.get_children():
		var found = _find(child, kind)
		if found != null:
			return found
	return null

func _prepare_tree(node: Node) -> void:
	if node is MeshInstance3D:
		if node.skin == null:
			node.hide()
		else:
			for surface in node.mesh.get_surface_count():
				var source: StandardMaterial3D = node.get_active_material(surface)
				if source.albedo_color.a < 0.01:
					node.hide()
					continue
				var material := ShaderMaterial.new()
				material.shader = Flesh
				material.set_shader_parameter("albedo_texture", source.albedo_texture)
				material.set_shader_parameter("normal_texture", source.normal_texture)
				material.set_shader_parameter("use_normal_map", source.normal_texture != null)
				var name_lower := str(node.name).to_lower()
				var eye := "eye" in name_lower
				var mouth := "mouth" in name_lower
				var body := "main" in name_lower and not mouth
				material.set_shader_parameter("normal_depth", 0.04 if eye else 0.12 if body else 0.08 if mouth else 0.22)
				material.set_shader_parameter("surface_roughness", 0.12 if eye else 0.25 if body else 0.30 if mouth else 0.42)
				material.set_shader_parameter("wet_style", 0.85 if eye else 0.65 if body else 0.4 if mouth else 0.18)
				material.set_shader_parameter("tint", source.albedo_color)
				material.set_meta("eye", eye)
				var local_pivot: Vector3 = node.global_transform.affine_inverse() * model_root.global_transform * head_pivot
				material.set_shader_parameter("head_pivot", local_pivot)
				node.set_surface_override_material(surface, material)
				materials.append(material)
				triangle_count += node.mesh.surface_get_array_index_len(surface) / 3
			node.custom_aabb = AABB(Vector3(-10, -10, -10), Vector3(20, 20, 20))
	for child in node.get_children():
		_prepare_tree(child)

func update_pose(delta := 0.0) -> void:
	# Godot's native skinning retains the source's non-unit bind transforms.
	# Strip clip locomotion at the root; the production controller owns travel.
	if root_bone >= 0:
		skeleton.set_bone_pose_position(root_bone, root_position)
		skeleton.set_bone_pose_rotation(root_bone, root_rotation)
	var use_cloth: bool = live_fins and fin_backend == "cloth" and native_cloth.available()
	native_cloth.update(use_cloth, fin_freedom, delta)
	fin_physics.enabled = live_fins and not use_cloth
	fin_physics.freedom = fin_freedom
	fin_physics.apply(delta)

func _process(delta: float) -> void:
	yaw = lerpf(yaw, target_yaw, 1.0 - exp(-9.0 * delta))
	pitch = lerpf(pitch, target_pitch, 1.0 - exp(-9.0 * delta))
	for material in materials:
		material.set_shader_parameter("bend_yaw", yaw)
		material.set_shader_parameter("bend_pitch", pitch)
	if animation_player:
		animation_player.speed_scale = animation_rate * lerpf(0.16, 1.15, clampf(speed_ratio, 0.0, 1.0))

func apply_visual_scale(host: Node3D, value: float) -> void:
	host.basis = Basis(Vector3.UP, PI * 0.5).scaled(Vector3.ONE * 0.20 * value)
	host.position = -(host.basis * head_pivot)

func set_swim_motion(speed: float, yaw_rate: float, pitch_rate: float, rate: float, pivot_bend := 0.0, pivot_pitch := 0.0) -> void:
	speed_ratio = speed
	animation_rate = rate
	target_yaw = clampf(yaw_rate * 0.055 + pivot_bend * 0.18, -0.35, 0.35)
	target_pitch = clampf(pitch_rate * 0.04 + pivot_pitch * 0.15, -0.30, 0.30)

func set_body_tint(colour: Color) -> void:
	for material in materials:
		if not material.get_meta("eye", false):
			material.set_shader_parameter("tint", colour)

func list_animation_names() -> PackedStringArray:
	return animation_player.get_animation_list() if animation_player else PackedStringArray()

func colour_materials() -> Array[ShaderMaterial]:
	var result: Array[ShaderMaterial] = []
	for material in materials:
		if not material.get_meta("eye", false):
			result.append(material)
	return result

func set_colour_style(style: Dictionary) -> void:
	for material in colour_materials():
		preload("res://scripts/AquariumStyle.gd").apply_material(material, style)
