extends Node3D

const BettaRigAdapterScript = preload("res://scripts/BettaRigAdapter.gd")

@export var swim_phase := 0.0
@export var lane := 0
@export var swim_speed := 0.35
@export var swim_width := 2.2
@export var bob_height := 0.18
@export var imported_model_scale := 0.75

var rig_adapter
var using_imported_model := false

func _ready() -> void:
	_try_imported_betta()

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

func _process(delta: float) -> void:
	swim_phase += delta * swim_speed
	var t := swim_phase * TAU
	position.x = sin(t) * swim_width * (0.85 + lane * 0.06)
	position.y = sin(t * 1.7 + lane) * bob_height
	position.z = cos(t * 0.7 + lane) * 0.45

	# Whole-fish locomotion stays procedural even when the imported model supplies
	# the local skeletal/fin animation. This gives TankWall independent control
	# over pathing, personality and Tasker/KWGT-driven behavior later.
	rotation.y = -cos(t) * 0.45
	rotation.z = sin(t * 2.0) * 0.05

	if not using_imported_model:
		var tail := get_node_or_null("Tail")
		if tail:
			tail.rotation.y = sin(t * 6.0) * 0.55
