extends RefCounted
## The source mesh, UVs and weights remain intact. Only the interpolation of
## rigid bone transforms changes. No inflation or animated scaling is applied.
const FleshShader = preload("res://shaders/BettaFlesh.gdshader")
const CUSTOM_FLAGS = (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) | (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)

var instance: MeshInstance3D
var source_skin: Skin
var skeleton: Skeleton3D
var bones := PackedInt32Array()
var materials: Array[ShaderMaterial] = []
var transforms: Array[Transform3D] = []
var real_parts := PackedVector4Array()
var dual_parts := PackedVector4Array()

static func encode(arrays: Array) -> void:
	var joints: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var encoded := PackedFloat32Array()
	for joint in joints:
		encoded.append(float(joint))
	arrays[Mesh.ARRAY_CUSTOM0] = arrays[Mesh.ARRAY_WEIGHTS]
	arrays[Mesh.ARRAY_CUSTOM1] = encoded
	arrays[Mesh.ARRAY_BONES] = null
	arrays[Mesh.ARRAY_WEIGHTS] = null

static func flesh_material(source: StandardMaterial3D) -> ShaderMaterial:
	var result := ShaderMaterial.new()
	result.shader = FleshShader
	result.set_shader_parameter("albedo_texture", source.albedo_texture)
	result.set_shader_parameter("normal_texture", source.normal_texture)
	result.set_shader_parameter("surface_texture", source.metallic_texture)
	result.set_shader_parameter("use_surface_map", source.metallic_texture != null)
	result.set_shader_parameter("use_normal_map", source.normal_enabled and source.normal_texture != null)
	result.set_shader_parameter("normal_depth", source.normal_scale)
	result.set_shader_parameter("surface_roughness", source.roughness)
	result.set_shader_parameter("surface_metallic", source.metallic)
	result.set_shader_parameter("tint", source.albedo_color)
	return result

func attach(mesh: MeshInstance3D, rig: Skeleton3D) -> bool:
	instance = mesh
	skeleton = rig
	source_skin = mesh.skin
	if source_skin == null or source_skin.get_bind_count() != 53:
		push_error("Volume skin requires the inspected 53-bind BlueMesh asset")
		return false
	for i in source_skin.get_bind_count():
		var bone := source_skin.get_bind_bone(i)
		if bone < 0:
			bone = skeleton.find_bone(source_skin.get_bind_name(i))
		bones.append(bone)
	for surface in instance.mesh.get_surface_count():
		var material = instance.get_active_material(surface)
		if material is ShaderMaterial:
			materials.append(material)
	# Arrays no longer contain Godot skin channels; avoid a second skin pass.
	instance.skin = null
	instance.skeleton = NodePath("")
	update_pose()
	return true

func update_pose() -> void:
	transforms.clear()
	real_parts.clear()
	dual_parts.clear()
	var mesh_from_skeleton := instance.global_transform.affine_inverse() * skeleton.global_transform
	for i in bones.size():
		var transform := mesh_from_skeleton * skeleton.get_bone_global_pose(bones[i]) * source_skin.get_bind_pose(i)
		transforms.append(transform)
		var rotation := transform.basis.orthonormalized().get_rotation_quaternion()
		var translation := transform.origin
		var dual := (Quaternion(translation.x, translation.y, translation.z, 0.0) * rotation) * 0.5
		real_parts.append(Vector4(rotation.x, rotation.y, rotation.z, rotation.w))
		dual_parts.append(Vector4(dual.x, dual.y, dual.z, dual.w))
	for material in materials:
		material.set_shader_parameter("skin_real", real_parts)
		material.set_shader_parameter("skin_dual", dual_parts)

func skin_point(point: Vector3, joints: PackedFloat32Array, weights: PackedFloat32Array) -> Vector3:
	# CPU equivalent used to check actual mesh cross-sections in regression tests.
	var reference := real_parts[int(joints[0])]
	var r := Vector4.ZERO
	var d := Vector4.ZERO
	for i in 4:
		var joint := int(joints[i])
		var weight := weights[i] * (-1.0 if reference.dot(real_parts[joint]) < 0.0 else 1.0)
		r += real_parts[joint] * weight
		d += dual_parts[joint] * weight
	var magnitude := maxf(r.length(), 0.00001)
	r /= magnitude
	d /= magnitude
	d -= r * r.dot(d)
	var translation := 2.0 * (r.w * Vector3(d.x, d.y, d.z) - d.w * Vector3(r.x, r.y, r.z)
		+ Vector3(r.x, r.y, r.z).cross(Vector3(d.x, d.y, d.z)))
	return Quaternion(r.x, r.y, r.z, r.w) * point + translation
