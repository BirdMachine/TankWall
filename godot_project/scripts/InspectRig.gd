extends SceneTree

func _initialize() -> void:
	var model: Node = load("res://assets/models/bluemesh_betta/scene.gltf").instantiate()
	root.add_child(model)
	_dump(model)
	quit()

func _dump(node: Node) -> void:
	if node is Node3D:
		print(node.name, " ", node.transform)
	if node is Skeleton3D:
		for i in node.get_bone_count():
			print("BONE ", i, " ", node.get_bone_name(i), " parent=", node.get_bone_parent(i), " rest=", node.get_bone_global_rest(i))
	for child in node.get_children():
		_dump(child)
