extends RefCounted
## Separate opaque flesh from compliant membranes. Source positions, UVs, skin
## bindings and texture attribution remain intact; COLOR stores membrane data.

const MembraneShader = preload("res://shaders/BettaMembrane.gdshader")

static func prepare(node: Node, skeleton: Skeleton3D, modifier: SkeletonModifier3D) -> Array[ShaderMaterial]:
	var materials: Array[ShaderMaterial] = []
	_prepare_recursive(node, skeleton, modifier, materials)
	return materials

static func _prepare_recursive(node: Node, skeleton: Skeleton3D, modifier: SkeletonModifier3D, materials: Array[ShaderMaterial]) -> void:
	if node is MeshInstance3D and node.mesh:
		var name_lower := String(node.name).to_lower()
		if "eyes" in name_lower:
			# The source uses alpha blending even on opaque eyeballs. Both eyes
			# must be depth tested against opaque flesh, not sorted over the head.
			for surface in node.mesh.get_surface_count():
				var source = node.get_active_material(surface)
				if source is StandardMaterial3D:
					var eye := source.duplicate() as StandardMaterial3D
					eye.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
					eye.cull_mode = BaseMaterial3D.CULL_BACK
					eye.metallic = 0.05
					eye.roughness = 0.24
					node.set_surface_override_material(surface, eye)
		elif name_lower == "body_0":
			_split_body(node, skeleton, modifier, materials)
	for child in node.get_children():
		_prepare_recursive(child, skeleton, modifier, materials)

static func _split_body(instance: MeshInstance3D, skeleton: Skeleton3D, modifier: SkeletonModifier3D, materials: Array[ShaderMaterial]) -> void:
	var mesh := instance.mesh
	var result := ArrayMesh.new()
	var skin: Skin = instance.skin
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		# glTF's redundant UV3/UV4 become float custom attributes. They are not
		# used here, and must not be rebuilt as default RGBA8 byte attributes.
		for attribute in [Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM1, Mesh.ARRAY_CUSTOM2, Mesh.ARRAY_CUSTOM3]:
			arrays[attribute] = null
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var source = instance.get_active_material(surface)
		if bones.is_empty() or not source is StandardMaterial3D:
			continue
		var colors := PackedColorArray()
		var fin_weights := PackedFloat32Array()
		for v in vertices.size():
			var membership := 0.0
			var strongest := 0.0
			var kind := ""
			for influence in 4:
				var bind := bones[v * 4 + influence]
				var bone := skin.get_bind_bone(bind)
				if bone < 0:
					bone = skeleton.find_bone(skin.get_bind_name(bind))
				if bone >= 0 and modifier.fin_kind[bone] not in ["", "gill"]:
					membership += weights[v * 4 + influence]
					if weights[v * 4 + influence] > strongest:
						strongest = weights[v * 4 + influence]
						kind = modifier.fin_kind[bone]
			var p := vertices[v]
			# Distance from the fleshy centreline makes attachments immobile;
			# soft free margins move most, even within one weighted bone sector.
			var center_z := -0.38 * clampf(p.y - 0.4, 0.0, 3.0)
			var away := maxf(absf(p.z - center_z) - 0.32, p.y - 2.85)
			var soft := membership * smoothstep(0.08, 1.15, away)
			var kind_id := float({"caudal": 0.2, "dorsal": 0.4, "anal": 0.6, "pelvic": 0.8, "pectoral": 1.0}.get(kind, 0.0))
			colors.append(Color(soft, clampf((p.z + 4.2) / 5.8, 0.0, 1.0), clampf((p.y + 0.5) / 6.5, 0.0, 1.0), kind_id))
			fin_weights.append(membership)
		arrays[Mesh.ARRAY_COLOR] = colors
		var opaque_indices := PackedInt32Array()
		var fin_indices := PackedInt32Array()
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for triangle in range(0, indices.size(), 3):
			var a := indices[triangle]
			var b := indices[triangle + 1]
			var c := indices[triangle + 2]
			if (fin_weights[a] + fin_weights[b] + fin_weights[c]) / 3.0 > 0.3:
				fin_indices.append_array(PackedInt32Array([a, b, c]))
			else:
				opaque_indices.append_array(PackedInt32Array([a, b, c]))
		if not opaque_indices.is_empty():
			arrays[Mesh.ARRAY_INDEX] = opaque_indices
			result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			var flesh := source.duplicate() as StandardMaterial3D
			flesh.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
			flesh.cull_mode = BaseMaterial3D.CULL_BACK
			result.surface_set_material(result.get_surface_count() - 1, flesh)
		if not fin_indices.is_empty():
			arrays[Mesh.ARRAY_INDEX] = fin_indices
			result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			var membrane := ShaderMaterial.new()
			membrane.shader = MembraneShader
			membrane.set_shader_parameter("albedo_texture", source.albedo_texture)
			membrane.set_shader_parameter("tint", Color.WHITE)
			result.surface_set_material(result.get_surface_count() - 1, membrane)
			materials.append(membrane)
	if result.get_surface_count() > 0:
		instance.mesh = result
		instance.custom_aabb = mesh.get_aabb().grow(1.2)
