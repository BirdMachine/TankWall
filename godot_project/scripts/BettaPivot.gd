extends RefCounted
## A short manoeuvre, separate from the cruising tailbeat. The head changes
## course while the posterior body stores curvature, then the fan catches up.

var stage := "cruise"
var clock := 0.0
var cooldown := 0.0
var start_heading := Vector3.RIGHT
var goal := Vector3.RIGHT
var axis := Vector3.UP
var angle := 0.0
var duration := 0.65
var bend := 0.0
var heading := Vector3.RIGHT
var turn_sign := 1.0

func active() -> bool:
	return stage != "cruise"

func begin(from: Vector3, toward: Vector3, rate: float) -> void:
	start_heading = from.normalized()
	goal = toward.normalized()
	angle = start_heading.angle_to(goal)
	axis = start_heading.cross(goal)
	if axis.length_squared() < 0.00001:
		axis = Vector3.UP.slide(start_heading)
		if axis.length_squared() < 0.00001:
			axis = Vector3.FORWARD
	axis = axis.normalized()
	turn_sign = 1.0 if axis.y >= 0.0 else -1.0
	duration = clampf(angle / maxf(rate * 4.4, 1.0), 0.30, 0.80)
	heading = start_heading
	stage = "brake"
	clock = 0.0
	bend = 0.0

func advance(delta: float, speed: float, cruise_speed: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)
	if not active():
		return
	clock += delta
	match stage:
		"brake":
			if speed < cruise_speed * 0.13 or clock >= 0.38:
				stage = "curl"
				clock = 0.0
		"curl":
			bend = turn_sign * 1.80 * smoothstep(0.0, 0.16, clock)
			if clock >= 0.16:
				stage = "pivot"
				clock = 0.0
		"pivot":
			var u := clampf(clock / duration, 0.0, 1.0)
			heading = start_heading.rotated(axis, angle * smoothstep(0.0, 1.0, u)).normalized()
			bend = turn_sign * 1.80 * (1.0 - 0.72 * smoothstep(0.40, 1.0, u))
			if u >= 1.0:
				stage = "release"
				clock = 0.0
		"release":
			bend = turn_sign * 0.504 * (1.0 - smoothstep(0.0, 0.36, clock))
			if clock >= 0.36:
				stage = "cruise"
				bend = 0.0
				cooldown = 1.1
