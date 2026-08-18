extends CanvasLayer

var panel: PanelContainer
var toggle_button: Button

func _ready() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	panel = PanelContainer.new()
	panel.anchor_left = 0.04
	panel.anchor_right = 0.96
	panel.anchor_top = 0.08
	panel.anchor_bottom = 0.52
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(panel)

	var glass := StyleBoxFlat.new()
	glass.bg_color = Color(0.02, 0.12, 0.18, 0.93)
	glass.border_color = Color(0.28, 0.92, 1.0, 0.98)
	glass.set_border_width_all(4)
	glass.set_content_margin_all(28)
	glass.corner_radius_top_left = 28
	glass.corner_radius_top_right = 28
	glass.corner_radius_bottom_left = 28
	glass.corner_radius_bottom_right = 28
	glass.shadow_color = Color(0, 0.7, 1, 0.38)
	glass.shadow_size = 16
	panel.add_theme_stylebox_override("panel", glass)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 22)
	panel.add_child(stack)

	var title := Label.new()
	title.text = "◈ TANKWALL // AQUA AMP"
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color(0.75, 1.0, 0.95))
	stack.add_child(title)

	var lcd := Label.new()
	lcd.text = "FISH 01   ● ONLINE   120HZ TARGET\nMODEL: BLUEMESH BETTA / SKELETAL SWIM"
	lcd.add_theme_font_size_override("font_size", 28)
	lcd.add_theme_color_override("font_color", Color(0.35, 1.0, 0.55))
	stack.add_child(lcd)

	stack.add_child(HSeparator.new())

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 12)
	stack.add_child(tabs)
	for name in ["FISH", "SKIN", "BG", "FX"]:
		var b := Button.new()
		b.text = name
		b.custom_minimum_size = Vector2(0, 92)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 30)
		_style_button(b)
		tabs.add_child(b)

	_add_meter(stack, "SWIM", 78)
	_add_meter(stack, "FLOW", 92)
	_add_meter(stack, "GLOW", 64)

	var footer := Label.new()
	footer.text = "◀   ◉   ▶     [ 1 FISH ]     TOUCH + DRAG: FOLLOW"
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_font_size_override("font_size", 25)
	footer.add_theme_color_override("font_color", Color(0.65, 0.9, 1.0))
	stack.add_child(footer)

	# Always-accessible show/hide control: hide the whole console and TankWall
	# becomes a clean full-screen tank like Betta 120Hz.
	toggle_button = Button.new()
	toggle_button.text = "×"
	toggle_button.anchor_left = 0.83
	toggle_button.anchor_right = 0.97
	toggle_button.anchor_top = 0.018
	toggle_button.anchor_bottom = 0.075
	toggle_button.mouse_filter = Control.MOUSE_FILTER_STOP
	toggle_button.add_theme_font_size_override("font_size", 42)
	_style_button(toggle_button)
	toggle_button.pressed.connect(_toggle_panel)
	root.add_child(toggle_button)

func _toggle_panel() -> void:
	panel.visible = not panel.visible
	toggle_button.text = "×" if panel.visible else "≡"

func _style_button(button: Button) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.03, 0.36, 0.52, 0.97)
	box.border_color = Color(0.45, 1.0, 0.95, 0.98)
	box.set_border_width_all(2)
	box.corner_radius_top_left = 12
	box.corner_radius_top_right = 12
	box.corner_radius_bottom_left = 12
	box.corner_radius_bottom_right = 12
	button.add_theme_stylebox_override("normal", box)
	button.add_theme_color_override("font_color", Color.WHITE)

func _add_meter(parent: VBoxContainer, label_text: String, value: float) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	parent.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(145, 62)
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color(0.75, 0.95, 1.0))
	row.add_child(label)
	var meter := ProgressBar.new()
	meter.value = value
	meter.custom_minimum_size = Vector2(0, 62)
	meter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meter.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.01, 0.06, 0.10, 0.95)
	bg.border_color = Color(0.2, 0.65, 0.9)
	bg.set_border_width_all(2)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.18, 0.95, 0.8, 0.95)
	fill.corner_radius_top_left = 9
	fill.corner_radius_top_right = 9
	fill.corner_radius_bottom_left = 9
	fill.corner_radius_bottom_right = 9
	meter.add_theme_stylebox_override("background", bg)
	meter.add_theme_stylebox_override("fill", fill)
	row.add_child(meter)
