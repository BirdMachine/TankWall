extends Node3D

@export var swim_phase := 0.0
@export var lane := 0
@export var swim_speed := 0.35
@export var swim_width := 2.2
@export var bob_height := 0.18

func _process(delta: float) -> void:
	swim_phase += delta * swim_speed
	var t := swim_phase * TAU
	position.x = sin(t) * swim_width * (0.85 + lane * 0.06)
	position.y = sin(t * 1.7 + lane) * bob_height
	position.z = cos(t * 0.7 + lane) * 0.45
	rotation.y = -cos(t) * 0.45
	rotation.z = sin(t * 2.0) * 0.05
	var tail := get_node_or_null("Tail")
	if tail:
		tail.rotation.y = sin(t * 6.0) * 0.55
