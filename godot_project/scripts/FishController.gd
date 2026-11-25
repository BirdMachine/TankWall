extends Node3D

const PivotMotion = preload("res://scripts/BettaPivot.gd")

const BettaRigAdapterScript = preload("res://scripts/BettaRigAdapter.gd")

@export var lane := 0
@export var cruise_speed := 0.78
@export var sprint_speed := 1.35
@export var acceleration := 0.72
@export var turn_rate := 1.05 # cruising yaw; sharp reversals use the short pivot gait
@export var orientation_response := 7.5
@export var imported_model_scale := 0.28
@export var swim_bounds_min := Vector3(-2.6, -1.8, -2.4)
@export var swim_bounds_max := Vector3(2.6, 1.8, 2.4)

var rig_adapter
var model_host: Node3D
var using_imported_model := false
var heading := Vector3.RIGHT
var desired_heading := Vector3.RIGHT
var speed := 0.42
var wander_target := Vector3.ZERO
var retarget_time := 0.0
var follow_active := false
var follow_target := Vector3.ZERO
var animation_rate := 1.0
var visual_scale := 1.0
var rng := RandomNumberGenerator.new()
var yaw_rate := 0.0
var pitch_rate := 0.0
var gait_time := 0.0
var pause_time := 0.0
var next_pause := 4.0
var thrust_effort := 0.6
var pivot = PivotMotion.new()
var departure_distance := 0.0
var transported_dorsal := Vector3.UP
var resting := false

func _ready() -> void:
	rng.seed = Time.get_ticks_usec() + get_instance_id() * 7919
	_try_imported_betta()
	heading = Vector3(1.0, 0.08, 0.04).normalized()
	desired_heading = heading
	_pick_wander_target()

func _try_imported_betta() -> void:
	model_host = Node3D.new()
	model_host.name = "ImportedBetta"
	add_child(model_host)

	# BlueMesh's source asset is authored nose-first along local -Y, with +Z as
	# dorsal/up. TankWall locomotion uses +X as forward and +Y as up. This basis
	# maps the artist's axes into ours without mirroring the mesh:
	#   source -Y -> TankWall +X (nose/forward)
	#   source +Z -> TankWall +Y (dorsal/up)
	#   source -X -> TankWall +Z (right/side)
	model_host.basis = Basis(
		Vector3(0, 0, -1),
		Vector3(-1, 0, 0),
		Vector3(0, 1, 0)
	)

	rig_adapter = BettaRigAdapterScript.new()
	add_child(rig_adapter)
	using_imported_model = rig_adapter.attach_to(model_host)

	if using_imported_model:
		_apply_visual_scale()
		_set_placeholder_visible(false)
		print("TankWall: rigged betta active. Animations: ", rig_adapter.list_animation_names())
	else:
		model_host.queue_free()
		rig_adapter.queue_free()
		model_host = null
		rig_adapter = null
		_set_placeholder_visible(true)

func _set_placeholder_visible(value: bool) -> void:
	for child_name in ["Body", "Tail", "DorsalFin", "VentralFin", "LeftFin", "RightFin", "LeftEye", "RightEye"]:
		var node := get_node_or_null(child_name)
		if node is VisualInstance3D:
			node.visible = value

func _physics_process(delta: float) -> void:
	if resting:
		# Calm hovering is a chosen mode, never exhaustion or a care penalty.
		speed = move_toward(speed, 0.0, delta * 1.5)
		thrust_effort = lerpf(thrust_effort, 0.025, minf(delta * 3.0, 1.0))
		yaw_rate = lerpf(yaw_rate, 0.0, minf(delta * 4.0, 1.0))
		pitch_rate = lerpf(pitch_rate, 0.0, minf(delta * 4.0, 1.0))
		var level_heading := Vector3(heading.x, 0, heading.z)
		if level_heading.length_squared() < 0.0001:
			level_heading = Vector3.RIGHT
		heading = heading.slerp(level_heading.normalized(), minf(delta * 0.8, 1.0)).normalized()
		_apply_swim_orientation(delta)
		_update_animation_speed()
		return
	retarget_time -= delta
	gait_time += delta
	next_pause -= delta
	if next_pause <= 0.0 and not follow_active:
		pause_time = rng.randf_range(0.65, 1.5)
		next_pause = rng.randf_range(4.0, 8.0)
	pause_time = maxf(0.0, pause_time - delta)
	var previous_heading := heading
	var previous_speed := speed
	var target := follow_target if follow_active else wander_target
	# Keep the exit course long enough to clear the glass. Otherwise a held
	# corner target immediately asks for a second reversal before the tail has
	# followed the first, creating a visible back-and-forth twitch.
	if departure_distance > 0.0:
		target = position + pivot.goal * 2.0
	var to_target := target - position

	if not follow_active and (retarget_time <= 0.0 or to_target.length() < 0.5):
		_pick_wander_target()
		target = wander_target
		to_target = target - position

	if to_target.length_squared() > 0.0004:
		desired_heading = to_target.normalized()
		# Predict the nose's position before reaching the boundary. A gradual
		# inward field produces an arc instead of a clamp-and-flap at the wall.
		var ahead := position + heading * maxf(0.9, speed * 1.5)
		var avoidance := Vector3.ZERO
		for axis in 3:
			var margin := minf(1.0, (swim_bounds_max[axis] - swim_bounds_min[axis]) * 0.28)
			avoidance[axis] = 1.0 - smoothstep(swim_bounds_min[axis], swim_bounds_min[axis] + margin, ahead[axis])
			avoidance[axis] -= smoothstep(swim_bounds_max[axis] - margin, swim_bounds_max[axis], ahead[axis])
		desired_heading = (desired_heading + avoidance * 2.4).normalized()
		if departure_distance > 0.0:
			desired_heading = pivot.goal
		# Commit a reversal before translating around a broad waypoint arc.
		# Hold its destination during the manoeuvre so avoidance cannot reverse
		# steering every frame. Small corrections retain the cruising gait.
		if not pivot.active() and pivot.cooldown <= 0.0 and (follow_active or pause_time <= 0.0):
			# A floor/ceiling or diagonal corner needs the same short manoeuvre
			# as a horizontal wall. Use the full 3D error, including steep turns.
			if heading.angle_to(desired_heading) > 1.25:
				pivot.begin(heading, desired_heading, turn_rate)
				if _forward_clearance(heading) < 0.4:
					departure_distance = minf(0.40, (swim_bounds_max - swim_bounds_min).length() * 0.12)
		if not pivot.active():
			var pause_gain := 0.2 if pause_time > 0.0 and not follow_active else 1.0
			_turn_heading_toward(desired_heading, turn_rate * pause_gain * (1.2 if follow_active else 1.0), delta)

		# A fish cannot translate sideways toward a waypoint. It slows while a
		# destination is off its nose, rotates into the turn, then accelerates out.
		var distance := to_target.length()
		var alignment := clampf((heading.dot(desired_heading) + 1.0) * 0.5, 0.0, 1.0)
		var arrival := clampf((distance - 0.12) / 1.55, 0.22, 1.0)
		var turn_throttle := lerpf(0.10, 1.0, pow(alignment, 1.5))
		# Reference footage alternates short strokes, coasting and stationary
		# inspection. Vary thrust rather than towing the fish at constant speed.
		var glide := 0.42 + 0.58 * smoothstep(-0.15, 0.50, sin(gait_time * 2.1 + lane))
		var requested_speed := (sprint_speed if follow_active else cruise_speed * glide) * arrival * turn_throttle
		if pause_time > 0.0 and not follow_active:
			requested_speed = cruise_speed * 0.025
		if pivot.active():
			# Brake hard before curling; retain a small forward drift. The exit
			# stroke starts only after the nose has completed the reversal.
			requested_speed = cruise_speed * (0.48 if pivot.stage == "release" else 0.035)
			var braking := maxf(acceleration * 3.5, cruise_speed * 3.0)
			speed = move_toward(speed, requested_speed, (acceleration if pivot.stage == "release" else braking) * delta)
		else:
			speed = move_toward(speed, requested_speed, acceleration * delta)
	else:
		speed = move_toward(speed, cruise_speed * 0.22, acceleration * delta)

	pivot.advance(delta, speed, cruise_speed)
	if pivot.active():
		heading = pivot.heading
		desired_heading = pivot.goal
	# Reserve room for the nose before contact, including during a committed
	# pivot. The bounds describe the head pivot, not a mesh collision hull.
	# A follow target on the glass must not tow the fish through it or force
	# the position clamp to manufacture a sideways step.
	var clearance := _forward_clearance(heading)
	var braking := maxf(acceleration * 3.5, cruise_speed * 3.0)
	var safe_speed := sqrt(2.0 * braking * maxf(0.0, clearance - 0.025))
	speed = minf(speed, minf(safe_speed, clearance / maxf(delta, 0.0001)))

	# Propulsion is always along the fish's nose. This is the key distinction
	# from the old prototype, which visually slid a flapping model through space.
	position += heading * speed * delta
	if not pivot.active():
		departure_distance = maxf(0.0, departure_distance - speed * delta)
	var turn_axis := previous_heading.cross(heading)
	var angular_step := previous_heading.angle_to(heading) / maxf(delta, 0.0001)
	yaw_rate = lerpf(yaw_rate, turn_axis.normalized().y * angular_step, 1.0 - exp(-8.0 * delta))
	pitch_rate = lerpf(pitch_rate, (heading.y - previous_heading.y) / maxf(delta, 0.0001), 1.0 - exp(-6.0 * delta))
	var push := maxf(0.0, (speed - previous_speed) / maxf(delta, 0.0001))
	var effort_target := clampf(speed / maxf(cruise_speed, 0.01) * 0.48 + push * 0.8 + absf(yaw_rate) * 0.22, 0.02, 1.6)
	thrust_effort = lerpf(thrust_effort, effort_target, 1.0 - exp(-6.0 * delta))
	_keep_inside_bounds()
	_apply_swim_orientation(delta)
	_update_animation_speed()

func _turn_heading_toward(target_dir: Vector3, radians_per_second: float, delta: float) -> void:
	if target_dir.length_squared() < 0.0001:
		return
	var angle := heading.angle_to(target_dir)
	if angle < 0.0005:
		heading = target_dir
		return
	var weight := minf(1.0, radians_per_second * delta / angle)
	heading = heading.slerp(target_dir, weight).normalized()

func _apply_swim_orientation(delta: float) -> void:
	if heading.length_squared() < 0.0002:
		return

	# Construct a stable body frame where local +X is the nose and +Y is dorsal.
	# Parallel transport the dorsal direction through a steep turn. Switching
	# reference axes at a fixed pitch threshold caused a sudden 90-degree roll.
	var up_reference := transported_dorsal.slide(heading)
	if up_reference.length_squared() < 0.0001:
		up_reference = Vector3.FORWARD.slide(heading)
	up_reference = up_reference.normalized()
	var upright := Vector3.UP.slide(heading)
	if upright.length_squared() > 0.06:
		upright = upright.normalized()
		# Recover dorsal-up gradually after a dive; do not flip a transported
		# frame instantaneously when its dorsal vector points downward.
		up_reference = up_reference.slerp(upright, 1.0 - exp(-1.8 * delta)).normalized()
	transported_dorsal = up_reference
	var side := heading.cross(up_reference).normalized()
	var dorsal := side.cross(heading).normalized()

	# Bank into turns. The error is measured before the next steering step so a
	# broad course correction produces a visible, Betta-like sweeping roll.
	# Actual turn motion retains a bank throughout a committed pivot; desired
	# heading error disappears as soon as the turn has been completed.
	var bank := clampf(-yaw_rate * 0.075, -0.20, 0.20)
	var target_basis := Basis(heading, dorsal, side)
	target_basis = target_basis.rotated(heading, bank)

	var blend := 1.0 - exp(-(24.0 if pivot.active() else orientation_response) * delta)
	quaternion = quaternion.slerp(target_basis.get_rotation_quaternion(), blend).normalized()

func _update_animation_speed() -> void:
	if rig_adapter == null:
		return
	var ratio := thrust_effort
	# Cadence and body flex respond to speed; sustained curvature responds to
	# actual angular velocity rather than oscillating the entire model root.
	# Project the stored C bend onto the rendered fish's local turn plane.
	# A vertical pivot flexes vertically instead of reusing a horizontal curl.
	var bend_axis: Vector3 = pivot.axis * absf(pivot.bend)
	rig_adapter.set_swim_motion(ratio, yaw_rate, pitch_rate, animation_rate,
		bend_axis.dot(basis.y), bend_axis.dot(basis.z))

func _forward_clearance(direction: Vector3) -> float:
	var distance := INF
	for axis in 3:
		if absf(direction[axis]) < 0.00001:
			continue
		var wall: float = swim_bounds_max[axis] if direction[axis] > 0.0 else swim_bounds_min[axis]
		distance = minf(distance, maxf(0.0, (wall - position[axis]) / direction[axis]))
	return distance

func _pick_wander_target() -> void:
	wander_target = Vector3(
		rng.randf_range(swim_bounds_min.x, swim_bounds_max.x),
		rng.randf_range(swim_bounds_min.y, swim_bounds_max.y),
		rng.randf_range(swim_bounds_min.z, swim_bounds_max.z)
	)
	# Mix leisurely cruises with shorter inspections; the pivot gait handles
	# destinations behind the head without an aircraft-like U-turn.
	if rng.randf() < 0.18:
		wander_target = position + Vector3(
			rng.randf_range(-1.6, 1.6),
			rng.randf_range(-1.0, 1.0),
			rng.randf_range(-1.2, 1.2)
		)
		wander_target = _clamp_to_bounds(wander_target)
	retarget_time = rng.randf_range(4.0, 8.5)

func _keep_inside_bounds() -> void:
	var clamped := _clamp_to_bounds(position)
	if clamped != position:
		position = clamped
		retarget_time = 0.0

func _clamp_to_bounds(value: Vector3) -> Vector3:
	return Vector3(
		clampf(value.x, swim_bounds_min.x, swim_bounds_max.x),
		clampf(value.y, swim_bounds_min.y, swim_bounds_max.y),
		clampf(value.z, swim_bounds_min.z, swim_bounds_max.z)
	)

func set_follow_target(world_target: Vector3, active := true) -> void:
	follow_target = _clamp_to_bounds(world_target)
	follow_active = active

func clear_follow_target() -> void:
	follow_active = false
	retarget_time = 0.0

func set_swim_bounds(minimum: Vector3, maximum: Vector3) -> void:
	swim_bounds_min = minimum
	swim_bounds_max = maximum
	position = _clamp_to_bounds(position)
	retarget_time = 0.0

func set_cruise_speed(value: float) -> void:
	cruise_speed = clampf(value, 0.25, 1.8)
	sprint_speed = maxf(cruise_speed * 1.65, cruise_speed + 0.25)

func set_turn_rate(value: float) -> void:
	turn_rate = clampf(value, 0.35, 2.6)

func set_visual_scale(value: float) -> void:
	visual_scale = clampf(value, 0.45, 1.7)
	_apply_visual_scale()

func _apply_visual_scale() -> void:
	if model_host:
		model_host.scale = Vector3.ONE * imported_model_scale * visual_scale
		# Position denotes the head/pectoral pivot. The source was previously
		# centred on the torso, making every reversal orbit a remote centre.
		model_host.position = Vector3(-2.0, -0.7, 0.0) * imported_model_scale * visual_scale

func set_animation_rate(value: float) -> void:
	animation_rate = clampf(value, 0.35, 1.8)

func set_body_tint(color: Color) -> void:
	if rig_adapter:
		rig_adapter.set_body_tint(color)
