extends Node3D

const BettaRigAdapterScript = preload("res://scripts/BettaRigAdapter.gd")

@export var lane := 0
@export var cruise_speed := 0.72
@export var sprint_speed := 1.15
@export var acceleration := 1.35
@export var turn_response := 2.35
@export var imported_model_scale := 0.75
@export var swim_bounds_min := Vector3(-2.35, -1.65, -0.85)
@export var swim_bounds_max := Vector3(2.35, 1.55, 0.85)

var rig_adapter
var using_imported_model := false
var velocity := Vector3.ZERO
var wander_target := Vector3.ZERO
var retarget_time := 0.0
var follow_active := false
var follow_target := Vector3.ZERO
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.seed = Time.get_ticks_usec() + get_instance_id() * 7919
	_try_imported_betta()
	velocity = Vector3(0.35 + lane * 0.06, 0.05, 0.02)
	_pick_wander_target()

func _try_imported_betta() -> void:
	var host := Node3D.new()
	host.name = "ImportedBetta"
	add_child(host)

	rig_adapter = BettaRigAdapterScript.new()
	add_child(rig_adapter)
	using_imported_model = rig_adapter.attach_to(host)

	if using_imported_model:
		host.scale = Vector3.ONE * imported_model_scale
		_set_placeholder_visible(false)
		print("TankWall: rigged betta active. Animations: ", rig_adapter.list_animation_names())
	else:
		host.queue_free()
		rig_adapter.queue_free()
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

	if not follow_active and (retarget_time <= 0.0 or to_target.length() < 0.42):
		_pick_wander_target()
		target = wander_target
		to_target = target - position

	if to_target.length_squared() > 0.0001:
		var distance := to_target.length()
		var speed_factor := clampf(distance / 1.25, 0.34, 1.0)
		var requested_speed := (sprint_speed if follow_active else cruise_speed) * speed_factor
		var desired_velocity := to_target.normalized() * requested_speed
		velocity = velocity.move_toward(desired_velocity, acceleration * delta)

	position += velocity * delta
	_apply_swim_orientation(delta)
	_update_animation_speed()

func _apply_swim_orientation(delta: float) -> void:
	if velocity.length_squared() < 0.0002:
		return

	# The fish mesh is modeled nose-first along local +X. Drive yaw/pitch from
	# actual velocity instead of sliding a sideways model around the scene.
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	var desired_yaw := atan2(-velocity.z, velocity.x)
	var desired_pitch := atan2(velocity.y, maxf(horizontal_speed, 0.001))
	var blend := 1.0 - exp(-turn_response * delta)
	var yaw_error := wrapf(desired_yaw - rotation.y, -PI, PI)

	rotation.y = lerp_angle(rotation.y, desired_yaw, blend)
	rotation.z = lerp_angle(rotation.z, desired_pitch * 0.72, blend * 0.8)
	# Gentle banking makes tight course changes read as swimming rather than
	# sprite-like rotation. It settles back to level on a straight run.
	var desired_bank := clampf(-yaw_error * 0.42, -0.34, 0.34)
	rotation.x = lerp_angle(rotation.x, desired_bank, blend * 0.65)

func _update_animation_speed() -> void:
	if rig_adapter == null:
		return
	var ratio := clampf(velocity.length() / maxf(cruise_speed, 0.01), 0.35, 1.65)
	rig_adapter.set_animation_speed(0.72 + ratio * 0.42)

func _pick_wander_target() -> void:
	# Broad 3D targets create the slow looping arcs and apparent depth changes
	# visible in Betta 120Hz instead of a predictable sine/orbit path.
	wander_target = Vector3(
		rng.randf_range(swim_bounds_min.x, swim_bounds_max.x),
		rng.randf_range(swim_bounds_min.y, swim_bounds_max.y),
		rng.randf_range(swim_bounds_min.z, swim_bounds_max.z)
	)
	# Favor long, lazy runs but occasionally ask for a closer corrective turn.
	if rng.randf() < 0.24:
		wander_target = position + Vector3(
			rng.randf_range(-1.25, 1.25),
			rng.randf_range(-0.9, 0.9),
			rng.randf_range(-0.55, 0.55)
		)
		wander_target.x = clampf(wander_target.x, swim_bounds_min.x, swim_bounds_max.x)
		wander_target.y = clampf(wander_target.y, swim_bounds_min.y, swim_bounds_max.y)
		wander_target.z = clampf(wander_target.z, swim_bounds_min.z, swim_bounds_max.z)
	retarget_time = rng.randf_range(2.3, 5.8)

func set_follow_target(world_target: Vector3, active := true) -> void:
	follow_target = world_target
	follow_active = active

func clear_follow_target() -> void:
	follow_active = false
	retarget_time = 0.0
