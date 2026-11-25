extends MultiMeshInstance3D
var clock := 0.0
var starts: Array[Vector3] = []
func _ready() -> void:
	var bubble := SphereMesh.new()
	bubble.radius = 0.015
	bubble.height = 0.03
	bubble.radial_segments = 8
	bubble.rings = 4
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = bubble
	multimesh.instance_count = 18
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("b4f5e3")
	material_override = material
	for i in multimesh.instance_count:
		var at := Vector3(randf_range(-0.55, 0.55), randf_range(-0.35, 0.25), randf_range(-0.25, 0.25))
		starts.append(at)
		multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, at))
func _process(delta: float) -> void:
	clock += delta
	for i in starts.size():
		var scale_value := maxf(0.0, 1.0 - clock * 0.4)
		var at := starts[i] + Vector3(sin(clock * 2.0 + i) * 0.035, clock * (0.12 + i * 0.005), 0)
		multimesh.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * scale_value), at))
	if clock > 2.5:
		queue_free()
