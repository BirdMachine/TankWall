extends SkeletonModifier3D
var adapter
func _process_modification() -> void:
	if adapter:
		adapter.update_pose()
