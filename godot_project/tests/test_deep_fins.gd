extends SceneTree
const Solver = preload("res://scripts/FinClothSolver.gd")
var failures := 0
func _initialize() -> void:call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func targets_at(time: float) -> PackedVector3Array:
	var targets := PackedVector3Array()
	var orientation := Basis(Vector3.UP, smoothstep(0.5, 1.7, time) * 2.7)
	var travel := Vector3(minf(time, 2.0) * 0.26, 0, 0)
	for ray in 2:
		for j in 6:targets.append(orientation * Vector3(0, ray * 0.15, -j * 0.12) + travel)
	return targets
func simulate(freedom: float, fps: int) -> Dictionary:
	var solver = Solver.new()
	solver.freedom = freedom
	solver.configure([[0, 1, 2, 3, 4, 5], [6, 7, 8, 9, 10, 11]], [Vector2i(2, 8), Vector2i(5, 11)])
	var peak := 0.0
	for frame in fps * 12:
		var goals := targets_at(float(frame) / fps)
		solver.advance(1.0 / fps, goals, Vector3.ZERO, Vector3.ZERO, 0.0)
		peak = maxf(peak, solver.max_offset)
		for chain in solver.chains:
			check(solver.points[chain[0]].is_equal_approx(goals[chain[0]]), "Detached fin root")
			for j in range(1, chain.size()):
				var index: int = chain[j]
				check(solver.points[index].is_finite(), "Non-finite deep fold")
				check(absf(solver.points[index].distance_to(solver.points[chain[j - 1]]) - 0.12) < 0.00001, "Deep fold stretched a ray")
				check(solver.points[index].distance_to(goals[index]) < j * 0.24 + 0.0001, "Deformation escaped its geometric reach")
	check(solver.max_offset < 0.005, "Soft fins did not settle after the turn")
	# Adjusting freedom must affect an existing running solver, not just reset.
	solver.freedom = 1.0
	solver.advance(1.0 / fps, targets_at(12.0), Vector3.ZERO, Vector3.ZERO, 0.0)
	check(solver.deep_fraction == 0.0, "Live freedom change was not applied")
	return {"peak": peak, "final": solver.points.duplicate()}
func run() -> void:
	var baseline := simulate(1.0, 60)
	var deep := simulate(2.2, 60)
	check(deep.peak > baseline.peak * 1.5, "Requested deformation increase is not measurable")
	for fps in [30, 120]:
		var result := simulate(2.2, fps)
		check(absf(result.peak - deep.peak) < 0.06, "Deep-fold peak changed excessively with frame rate")
		for i in result.final.size():check(result.final[i].distance_to(deep.final[i]) < 0.005, "Deep-fold settling depends on frame rate")
	simulate(0.5, 60)
	print("Deep fins: peak v0.10=", baseline.peak, " peak v0.11=", deep.peak, " ratio=", deep.peak / baseline.peak, " failures=", failures)
	quit(1 if failures else 0)
