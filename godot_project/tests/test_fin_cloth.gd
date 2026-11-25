extends SceneTree
const Solver = preload("res://scripts/FinClothSolver.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func target_at(time: float) -> PackedVector3Array:
	var points := PackedVector3Array()
	var angle := smoothstep(0.8, 1.8, time) * 2.0
	var frame := Basis(Vector3.UP, angle)
	for ray in 2:
		for j in 5:
			points.append(frame * Vector3(ray * 0.14, j * 0.10, 0) + Vector3(minf(time, 2.0) * 0.22, 0, 0))
	return points
func simulate(fps: int) -> PackedVector3Array:
	var solver = Solver.new()
	solver.configure([[0, 1, 2, 3, 4], [5, 6, 7, 8, 9]], [Vector2i(2, 7), Vector2i(4, 9)])
	var largest := 0.0
	for frame in fps * 8:
		var targets := target_at(float(frame) / fps)
		solver.advance(1.0 / fps, targets, Vector3.ZERO, Vector3.ZERO, 0.0)
		largest = maxf(largest, solver.max_offset)
		check(solver.points[0].is_equal_approx(targets[0]) and solver.points[5].is_equal_approx(targets[5]), "Fin roots moved")
		for i in solver.points.size():
			check(solver.points[i].is_finite(), "Non-finite cloth position")
		for chain in solver.chains:
			for j in range(1, chain.size()):
				check(absf(solver.points[chain[j]].distance_to(solver.points[chain[j - 1]]) - 0.10) < 0.00001, "Fin ray stretched")
	check(largest > 0.005, "Live cloth has no inertial response")
	check(solver.max_offset < 0.008, "Cloth did not settle after travel stopped")
	var final: PackedVector3Array = solver.points.duplicate()
	var resets: int = solver.resets
	var moved := target_at(8)
	for i in moved.size():moved[i] += Vector3(5, 0, 0)
	solver.advance(1.0 / fps, moved, Vector3.ZERO, Vector3.ZERO, 0.0)
	check(solver.resets == resets + 1 and solver.points == moved, "Teleport must reset inertia")
	solver.enabled = false
	solver.advance(1.0 / fps, moved, Vector3.ZERO, Vector3.ZERO, 0.0)
	check(not solver.initialized, "Disabled cloth retained momentum")
	solver.enabled = true
	solver.advance(2.0, moved, Vector3.ZERO, Vector3.ZERO, 0.0)
	check(solver.points == moved, "Resume must not integrate a long hidden interval")
	return final
func run() -> void:
	var reference := simulate(120)
	for fps in [30, 60]:
		var result := simulate(fps)
		for i in result.size():check(result[i].distance_to(reference[i]) < 0.004, "Cloth frame-rate drift at " + str(fps))
	print("Fin cloth: root attachment, ray lengths, inertia, settling, 30/60/120 Hz, toggle/teleport/resume; failures=", failures)
	quit(1 if failures else 0)
