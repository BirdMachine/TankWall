extends RefCounted
## Post-animation fin modifier. Original positions, scales and bind poses stay intact.
const Solver = preload("res://scripts/FinClothSolver.gd")
const ROOT_NAMES := ["Up fore flag", "Up back flag", "Down fore flag", "Down back flag", "Up tail", "Down tail"]
var solver = Solver.new()
var skeleton: Skeleton3D
var rays: Array = []
var layout: Array = []
var tip_directions := PackedVector3Array()
var enabled := true
var neck := -1
var tail := -1
var modified_bones := 0

func configure(target: Skeleton3D) -> void:
	skeleton = target
	neck = skeleton.find_bone("Neck")
	tail = skeleton.find_bone("end")
	var count := 0
	for name in ROOT_NAMES:
		var root := skeleton.find_bone(name)
		if root < 0:
			for i in skeleton.get_bone_count():
				if skeleton.get_bone_name(i).begins_with(name) and skeleton.get_bone_parent(i) == tail:
					root = i
					break
		if root < 0:
			continue
		var ray: Array[int] = [root]
		var children := skeleton.get_bone_children(root)
		while children.size() == 1:
			ray.append(children[0])
			children = skeleton.get_bone_children(children[0])
		rays.append(ray)
		var last: int = ray[-1]
		var rest := skeleton.get_bone_global_rest(last)
		var previous := skeleton.get_bone_global_rest(skeleton.get_bone_parent(last))
		var extension := (rest.origin - previous.origin) * 0.75
		if ray.size() == 1:
			extension = extension.normalized() * 2.5
		tip_directions.append(rest.basis.inverse() * extension)
		var indices: Array[int] = []
		for j in ray.size() + 1:
			indices.append(count)
			count += 1
		layout.append(indices)
	var links: Array[Vector2i] = []
	# Neighbouring rays of each membrane, not unrelated fins.
	for pair in [[0, 1], [2, 3], [4, 5]]:
		if pair[1] >= layout.size():
			continue
		var a: Array = layout[pair[0]]
		var b: Array = layout[pair[1]]
		for j in range(1, mini(a.size(), b.size())):
			var u := float(j) / (mini(a.size(), b.size()) - 1)
			links.append(Vector2i(a[roundi(u * (a.size() - 1))], b[roundi(u * (b.size() - 1))]))
	solver.configure(layout, links)
	modified_bones = count - rays.size()

func apply(delta: float) -> void:
	solver.enabled = enabled
	if not enabled or rays.is_empty():
		solver.initialized = false
		return
	var targets := PackedVector3Array()
	var directions := PackedVector3Array()
	var rotations: Array[Quaternion] = []
	var transform := skeleton.global_transform
	for r in rays.size():
		var ray: Array = rays[r]
		for j in ray.size():
			var bone: int = ray[j]
			var pose := skeleton.get_bone_global_pose(bone)
			var endpoint: Vector3
			if j + 1 < ray.size():
				endpoint = skeleton.get_bone_global_pose(ray[j + 1]).origin
			else:
				endpoint = pose.origin + pose.basis * tip_directions[r]
			targets.append(transform * pose.origin)
			directions.append(pose.basis.inverse() * (endpoint - pose.origin))
			rotations.append(skeleton.get_bone_pose_rotation(bone))
			if j == ray.size() - 1:
				targets.append(transform * endpoint)
	var scale := transform.basis.get_scale().abs().x
	var a := transform * skeleton.get_bone_global_pose(neck).origin if neck >= 0 else Vector3.ZERO
	var b := transform * skeleton.get_bone_global_pose(tail).origin if tail >= 0 else Vector3.ZERO
	solver.advance(delta, targets, a, b, 0.62 * scale)
	var entry := 0
	for r in rays.size():
		var ray: Array = rays[r]
		for j in ray.size():
			var bone: int = ray[j]
			var current := skeleton.get_bone_global_pose(bone)
			var desired: Vector3 = solver.points[layout[r][j + 1]] - solver.points[layout[r][j]]
			var local: Vector3 = current.basis.inverse() * (transform.basis.inverse() * desired)
			if local.length_squared() > 0.00000001 and directions[entry].length_squared() > 0.00000001:
				var swing := Quaternion(directions[entry].normalized(), local.normalized())
				skeleton.set_bone_pose_rotation(bone, (rotations[entry] * swing).normalized())
			entry += 1
