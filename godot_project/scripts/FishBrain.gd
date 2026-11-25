extends Node
## A small local behaviour selector: preferences and curiosity, never care debt.
var personality := "curious"
var favourite := Vector3(-0.55, -0.2, -0.45)
var state_label := "Exploring the water"
var interest := Vector3.ZERO
var interest_left := 0.0
var rng := RandomNumberGenerator.new()
var choices := 0

func configure(kind: String, seed_value: int) -> void:
	personality = kind
	rng.seed = seed_value
	favourite = Vector3(rng.randf_range(-0.65, 0.65), rng.randf_range(-0.45, 0.35), -0.55)

func _process(delta: float) -> void:
	interest_left = maxf(0.0, interest_left - delta)

func notice(point: Vector3) -> void:
	interest = point
	interest_left = 4.0

func choose_target(position_now: Vector3, low: Vector3, high: Vector3) -> Dictionary:
	choices += 1
	var centre := (low + high) * 0.5
	var half := (high - low) * 0.5
	var roll := rng.randf()
	var target := centre
	var wait := rng.randf_range(4.0, 7.0)
	var pause := 0.0
	if interest_left > 0.0 and roll < (0.85 if personality == "curious" else 0.45):
		target = interest
		state_label = "Investigating a little ripple"
	elif roll < 0.23:
		target = centre + favourite * half
		state_label = "Visiting a favourite corner"
	elif roll < 0.42:
		target = centre + Vector3(rng.randf_range(-0.5, 0.5), 0.15, 0.75) * half
		state_label = "Coming over to say hello"
	elif roll < (0.65 if personality == "dreamy" else 0.52):
		target = position_now.lerp(centre, 0.65) + Vector3(0.25, 0.3, 0)
		pause = rng.randf_range(1.5, 3.2)
		wait = pause + 2.0
		state_label = "Enjoying a gentle drift"
	else:
		target = centre + Vector3(rng.randf_range(-0.8, 0.8), rng.randf_range(-0.75, 0.8), rng.randf_range(-0.7, 0.65)) * half
		state_label = "Exploring the water"
	if personality == "calm":
		wait *= 1.35
	return {"target": target.clamp(low, high), "wait": wait, "pause": pause}
