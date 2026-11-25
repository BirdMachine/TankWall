extends RefCounted
## Small animated cloth proxy, in world metres. No renderer or mesh ownership.
## Chains preserve ray length; cross-links resist membrane stretch but allow folds.
const STEP := 1.0 / 120.0
var points := PackedVector3Array()
var velocities := PackedVector3Array()
var goals := PackedVector3Array()
var chains: Array = []
var links: Array = []
var pinned := PackedByteArray()
var fractions := PackedFloat32Array()
var accumulator := 0.0
var initialized := false
var enabled := true
var resets := 0
var max_offset := 0.0
var body_start := Vector3.ZERO
var body_end := Vector3.ZERO
var body_radius := 0.0

func configure(layout: Array, cross_links: Array) -> void:
	chains = layout
	links = cross_links
	initialized = false
	accumulator = 0.0

func reset(targets: PackedVector3Array) -> void:
	goals = targets.duplicate()
	points = targets.duplicate()
	velocities.resize(points.size())
	velocities.fill(Vector3.ZERO)
	pinned.resize(points.size())
	pinned.fill(0)
	fractions.resize(points.size())
	for chain in chains:
		for j in chain.size():
			fractions[chain[j]] = float(j) / maxf(1.0, chain.size() - 1)
		pinned[chain[0]] = 1
	accumulator = 0.0
	initialized = true
	resets += 1

func advance(delta: float, targets: PackedVector3Array, capsule_a: Vector3, capsule_b: Vector3, radius: float) -> void:
	if targets.is_empty():
		return
	if not enabled:
		initialized = false
		return
	if not initialized or targets.size() != points.size() or delta > 0.15 or goals[0].distance_to(targets[0]) > 1.25:
		reset(targets)
		return
	goals = targets.duplicate()
	body_start = capsule_a
	body_end = capsule_b
	body_radius = radius
	accumulator += maxf(0.0, delta)
	var count := mini(12, int((accumulator + 0.0000001) / STEP))
	for unused in count:
		_substep()
	accumulator -= count * STEP
	max_offset = 0.0
	for i in points.size():
		max_offset = maxf(max_offset, points[i].distance_to(goals[i]))

func _substep() -> void:
	var previous := points.duplicate()
	for i in points.size():
		if pinned[i]:
			points[i] = goals[i]
			continue
		var frequency := lerpf(12.0, 5.0, fractions[i])
		velocities[i] += (goals[i] - points[i]) * frequency * frequency * STEP
		# Water drag damps world-space velocity, giving real travel/turn inertia.
		velocities[i] *= exp(-4.8 * STEP)
		points[i] += velocities[i].limit_length(2.8) * STEP
	for iteration in 5:
		for chain in chains:
			for j in range(1, chain.size()):
				var a: int = chain[j - 1]
				var b: int = chain[j]
				_distance(a, b, goals[a].distance_to(goals[b]), 1.0)
				var reference := (goals[b] - goals[a]).normalized()
				var direction := (points[b] - points[a]).normalized()
				var angle := reference.angle_to(direction)
				var limit := lerpf(0.10, 0.72, fractions[b])
				if j == 1:
					limit = minf(limit, 0.22)
				if angle > limit:
					var length := goals[a].distance_to(goals[b])
					points[b] = points[a] + reference.slerp(direction, limit / angle) * length
		for pair in links:
			var a: int = pair.x
			var b: int = pair.y
			var maximum := goals[a].distance_to(goals[b]) * 1.06
			if points[a].distance_to(points[b]) > maximum:
				_distance(a, b, maximum, 0.45)
		for chain in chains:
			for j in range(2, chain.size()):
				_collide(chain[j])
	# Finish from fixed roots outward; rendered ray lengths remain exact.
	for chain in chains:
		points[chain[0]] = goals[chain[0]]
		for j in range(1, chain.size()):
			var a: int = chain[j - 1]
			var b: int = chain[j]
			var direction := (points[b] - points[a]).normalized()
			if direction.is_zero_approx():
				direction = (goals[b] - goals[a]).normalized()
			points[b] = points[a] + direction * goals[a].distance_to(goals[b])
	for i in points.size():
		velocities[i] = ((points[i] - previous[i]) / STEP).limit_length(2.8) if not pinned[i] else Vector3.ZERO

func _distance(a: int, b: int, length: float, strength: float) -> void:
	var displacement := points[b] - points[a]
	var distance := displacement.length()
	if distance < 0.000001:
		return
	var wa := 0.0 if pinned[a] else 1.0
	var wb := 0.0 if pinned[b] else 1.0
	if wa + wb == 0.0:
		return
	var correction := displacement * ((distance - length) / distance) * strength / (wa + wb)
	points[a] += correction * wa
	points[b] -= correction * wb

func _collide(index: int) -> void:
	if body_radius <= 0.0:
		return
	var axis := body_end - body_start
	var t := clampf((points[index] - body_start).dot(axis) / maxf(axis.length_squared(), 0.000001), 0.0, 1.0)
	var nearest := body_start + axis * t
	var radial := points[index] - nearest
	if radial.length() < body_radius:
		if radial.is_zero_approx():
			radial = goals[index] - nearest
		if radial.is_zero_approx():
			radial = Vector3.RIGHT
		points[index] = nearest + radial.normalized() * body_radius
