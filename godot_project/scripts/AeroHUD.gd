extends CanvasLayer

func _ready() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var panel := PanelContainer.new()
	panel.position = Vector2(28, 72)
	panel.size = Vector2(520, 430)
	root.add_child(panel)

	var glass := StyleBoxFlat.new()
	glass.bg_color = Color(0.02, 0.12, 0.18, 0.88)
	glass.border_color = Color(0.28, 0.92, 1.0, 0.95)
	glass.set_border_width_all(2)
	glass.corner_radius_top_left = 18
	glass.corner_radius_top_right = 18
	glass.corner_radius_bottom_left = 18
	glass.corner_radius_bottom_right = 18
	glass.shadow_color = Color(0, 0.7, 1, 0.3)
	glass.shadow_size = 10
	panel.add_theme_stylebox_override("panel", glass)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10)
	panel.add_child(stack)

	var title := Label.new()
	title.text = "◈ TANKWALL // AQUA AMP"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.75, 1.0, 0.95))
	stack.add_child(title)

	var lcd := Label.new()
	lcd.text = "FISH 01   ● ONLINE   120HZ READY\nMODEL: BETTA / PREVIEW CORE"
	lcd.add_theme_font_size_override("font_size", 16)
	lcd.add_theme_color_override("font_color", Color(0.35, 1.0, 0.55))
	stack.add_child(lcd)

	var divider := HSeparator.new()
	stack.add_child(divider)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	stack.add_child(tabs)
	for name in ["FISH", "SKIN", "BG", "FX"]:
		var b := Button.new()
		b.text = name
		b.custom_minimum_size = Vector2(112, 42)
		_style_button(b)
		tabs.add_child(b)

	_add_meter(stack, "SWIM", 72)
	_add_meter(stack, "FLOW", 88)
	_add_meter(stack, "GLOW", 64)

	var footer := Label.new()
	footer.text = "◀  ◉  ▶    [ 1 FISH ]    TOUCH: FOLLOW"
	footer.add_theme_font_size_override("font_size", 15)
	footer.add_theme_color_override("font_color", Color(0.65, 0.9, 1.0))
	stack.add_child(footer)

func _style_button(button: Button) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.03, 0.36, 0.52, 0.95)
	box.border_color = Color(0.45, 1.0, 0.95, 0.95)
	box.set_border_width_all(1)
	box.corner_radius_top_left = 8
	box.corner_radius_top_right = 8
	box.corner_radius_bottom_left = 8
	box.corner_radius_bottom_right = 8
	button.add_theme_stylebox_override("normal", box)
	button.add_theme_color_override("font_color", Color.WHITE)

func _add_meter(parent: VBoxContainer, label_text: String, value: float) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(70, 26)
	label.add_theme_color_override("font_color", Color(0.75, 0.95, 1.0))
	row.add_child(label)
	var meter := ProgressBar.new()
	meter.value = value
	meter.custom_minimum_size = Vector2(360, 26)
	meter.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.01, 0.06, 0.10, 0.95)
	bg.border_color = Color(0.2, 0.65, 0.9)
	bg.set_border_width_all(1)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.18, 0.95, 0.8, 0.95)
	fill.corner_radius_top_left = 5
	fill.corner_radius_top_right = 5
	fill.corner_radius_bottom_left = 5
	fill.corner_radius_bottom_right = 5
	meter.add_theme_stylebox_override("background", bg)
	meter.add_theme_stylebox_override("fill", fill)
	row.add_child(meter)
