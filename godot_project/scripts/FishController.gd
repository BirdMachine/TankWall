extends Node3D

const BettaRigAdapterScript = preload("res://scripts/BettaRigAdapter.gd")

@export var lane := 0
@export var cruise_speed := 0.78
@export var sprint_speed := 1.35
@export var acceleration := 0.72
@export var turn_rate := 1.05 # radians/sec; deliberately graceful rather than twitchy
@export var orientation_response := 7.5
@export var imported_model_scale := 0.75
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
	retarget_time -= delta
	var target := follow_target if follow_active else wander_target
	var to_target := target - position

	if not follow_active and (retarget_time <= 0.0 or to_target.length() < 0.5):
		_pick_wander_target()
		target = wander_target
		to_target = target - position

	if to_target.length_squared() > 0.0004:
		desired_heading = to_target.normalized()
		_turn_heading_toward(desired_heading, turn_rate * (1.45 if follow_active else 1.0), delta)

		# A fish cannot translate sideways toward a waypoint. It slows while a
		# destination is off its nose, rotates into the turn, then accelerates out.
		var distance := to_target.length()
		var alignment := clampf((heading.dot(desired_heading) + 1.0) * 0.5, 0.0, 1.0)
		var arrival := clampf((distance - 0.12) / 1.55, 0.22, 1.0)
		var turn_throttle := lerpf(0.32, 1.0, alignment)
		var requested_speed := (sprint_speed if follow_active else cruise_speed) * arrival * turn_throttle
		speed = move_toward(speed, requested_speed, acceleration * delta)
	else:
		speed = move_toward(speed, cruise_speed * 0.22, acceleration * delta)

	# Propulsion is always along the fish's nose. This is the key distinction
	# from the old prototype, which visually slid a flapping model through space.
	position += heading * speed * delta
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
	var up_reference := Vector3.UP
	if absf(heading.dot(up_reference)) > 0.94:
		up_reference = Vector3.FORWARD
	var side := heading.cross(up_reference).normalized()
	var dorsal := side.cross(heading).normalized()

	# Bank into turns. The error is measured before the next steering step so a
	# broad course correction produces a visible, Betta-like sweeping roll.
	var yaw_error := heading.cross(desired_heading).dot(Vector3.UP)
	var bank := clampf(-yaw_error * 0.78, -0.38, 0.38)
	var target_basis := Basis(heading, dorsal, side)
	target_basis = target_basis.rotated(heading, bank)

	var blend := 1.0 - exp(-orientation_response * delta)
	quaternion = quaternion.slerp(target_basis.get_rotation_quaternion(), blend).normalized()

func _update_animation_speed() -> void:
	if rig_adapter == null:
		return
	var ratio := clampf(speed / maxf(cruise_speed, 0.01), 0.0, 1.7)
	# The BlueMesh 6-second clip is already graceful. Keep its fin cadence slow
	# at cruise and only beat harder while chasing a finger.
	rig_adapter.set_animation_speed((0.58 + ratio * 0.34) * animation_rate)

func _pick_wander_target() -> void:
	wander_target = Vector3(
		rng.randf_range(swim_bounds_min.x, swim_bounds_max.x),
		rng.randf_range(swim_bounds_min.y, swim_bounds_max.y),
		rng.randf_range(swim_bounds_min.z, swim_bounds_max.z)
	)
	# Long destinations + a finite turn rate produce the large lazy arcs visible
	# in Betta 120Hz. A few shorter runs keep the motion from looking scripted.
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

func set_animation_rate(value: float) -> void:
	animation_rate = clampf(value, 0.35, 1.8)
