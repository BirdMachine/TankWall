extends Node3D
## A physical backwall, floor, glass edges, stones and gently moving leaves.
var room_colour := Color("16404b")
var rng := RandomNumberGenerator.new()

func build(low: Vector3, high: Vector3, colour: Color) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	rng.seed = 1138
	room_colour = colour
	var width := high.x - low.x + 0.9
	var height := high.y - low.y + 0.9
	var depth := high.z - low.z + 0.65
	var centre := (low + high) * 0.5
	var floor_y := low.y - 0.34
	var back := low.z - 0.32
	var wall := _material(colour, 0.8)
	_box(Vector3(width, height, 0.06), Vector3(centre.x, floor_y + height * 0.5, back), wall)
	var sand := _material(Color("687c76"), 0.92)
	_box(Vector3(width, 0.09, depth), Vector3(centre.x, floor_y, centre.z), sand)
	var rim := _material(Color("6aaca8"), 0.26)
	for side in [-1, 1]:
		var x: float = centre.x + side * width * 0.5
		_box(Vector3(0.018, height, 0.018), Vector3(x, floor_y + height * 0.5, back), rim)
		_box(Vector3(0.018, 0.018, depth), Vector3(x, floor_y + 0.07, centre.z), rim)
	var stone_material := _material(Color("adb3a0"), 0.75)
	var pebble := SphereMesh.new()
	pebble.radius = 0.09
	pebble.height = 0.12
	pebble.radial_segments = 10
	pebble.rings = 5
	var stones := MultiMeshInstance3D.new()
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = pebble
	batch.instance_count = 36
	for i in batch.instance_count:
		var at := Vector3(rng.randf_range(centre.x - width * 0.46, centre.x + width * 0.46), floor_y + 0.045, rng.randf_range(back + 0.12, high.z))
		batch.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(rng.randf_range(0.7, 1.8), rng.randf_range(0.5, 0.9), rng.randf_range(0.7, 1.5))), at))
	stones.multimesh = batch
	stones.material_override = stone_material
	add_child(stones)
	for side in [-1, 1]:
		var plant := _plant()
		plant.position = Vector3(centre.x + side * width * 0.36, floor_y + 0.06, back + 0.20)
		add_child(plant)

func _plant() -> MeshInstance3D:
	var mesh := ArrayMesh.new()
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colours := PackedColorArray()
	var indices := PackedInt32Array()
	for leaf in 11:
		var angle := rng.randf_range(-PI, PI)
		var height := rng.randf_range(0.65, 1.65)
		var bend := rng.randf_range(-0.45, 0.45)
		var start := vertices.size()
		for step in 9:
			var u := step / 8.0
			var width := sin(PI * u) * 0.055 + 0.004
			for side in [-1, 1]:
				var p := Vector3(bend * u * u + side * width, height * u, sin(u * PI) * 0.08)
				vertices.append(p.rotated(Vector3.UP, angle))
				normals.append(Vector3.FORWARD.rotated(Vector3.UP, angle))
				colours.append(Color("72a989").lerp(Color("214b48"), 1.0 - u))
		for step in 8:
			var a := start + step * 2
			indices.append_array(PackedInt32Array([a, a + 2, a + 1, a + 1, a + 2, a + 3]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colours
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/TankLeaf.gdshader")
	instance.material_override = material
	return instance

func _box(size: Vector3, at: Vector3, material: Material) -> void:
	var instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	instance.mesh = box
	instance.position = at
	instance.material_override = material
	add_child(instance)

func _material(colour: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = roughness
	return material
