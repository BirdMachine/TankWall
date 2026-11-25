extends "res://scripts/FinClothShowcase.gd"
## Live physics in both panels: 0.10's restrained profile vs deeper deformation.
func start() -> void:
	super.start()
	for control in root.get_child(0).get_children():
		if control is Label:
			if control.text.begins_with("RECORDED"):
				control.text = "v0.10 · RESTRAINED LIVE FINS"
			elif control.text.begins_with("LIVE FIN"):
				control.text = "v0.11 · DEEPER LIVE FOLDS"
func setup_case(index: int) -> void:
	super.setup_case(index)
	for panel in 2:
		residents[panel].fish.rig_adapter.live_fins = true
		residents[panel].fish.rig_adapter.fin_freedom = 1.0 if panel == 0 else 2.2
func step() -> void:
	super.step()
	if frame >= 1440:
		return
	var phase := frame % 360
	if phase >= 120:
		var target := Vector3(0, -1.3, 0.25) if phase < 240 else Vector3(0, 1.3, -0.25)
		for item in residents:item.fish.set_follow_target(target)
