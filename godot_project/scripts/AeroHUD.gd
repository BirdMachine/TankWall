extends CanvasLayer

var panel: PanelContainer
var toggle_button: Button
var pages := {}
var tab_buttons := {}
var ui_scale := 1.0

func _ready() -> void:
	ui_scale = _physical_ui_scale()
	_build_ui()
	_show_page("FISH")

func _physical_ui_scale() -> float:
	# project.godot is authored around a portrait 1080x2400 logical viewport.
	# With aspect=expand, a landscape phone may expose ~5600x2400 logical pixels
	# while physically being ~1500x660. Compensate so fonts/touch targets retain
	# their intended *physical* size instead of becoming microscopic.
	var logical := get_viewport().get_visible_rect().size
	var physical_i := DisplayServer.window_get_size()
	var physical := Vector2(maxi(physical_i.x, 1), maxi(physical_i.y, 1))
	var sx := logical.x / physical.x
	var sy := logical.y / physical.y
	return clampf((sx + sy) * 0.5, 0.8, 4.5)

func _u(value: float) -> float:
	return value * ui_scale

func _font(value: float) -> int:
	return roundi(_u(value))

func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	panel = PanelContainer.new()
	panel.anchor_left = 0.018
	panel.anchor_right = 0.982
	panel.anchor_top = 0.045
	panel.anchor_bottom = 0.94
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(panel)

	var glass := StyleBoxFlat.new()
	glass.bg_color = Color(0.015, 0.105, 0.16, 0.965)
	glass.border_color = Color(0.25, 0.92, 1.0, 1.0)
	glass.set_border_width_all(roundi(_u(3)))
	glass.set_content_margin_all(_u(18))
	glass.corner_radius_top_left = roundi(_u(18))
	glass.corner_radius_top_right = roundi(_u(18))
	glass.corner_radius_bottom_left = roundi(_u(18))
	glass.corner_radius_bottom_right = roundi(_u(18))
	glass.shadow_color = Color(0.0, 0.65, 1.0, 0.34)
	glass.shadow_size = roundi(_u(11))
	panel.add_theme_stylebox_override("panel", glass)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", roundi(_u(9)))
	panel.add_child(stack)

	var title_row := HBoxContainer.new()
	stack.add_child(title_row)
	var title := Label.new()
	title.text = "◈ TANKWALL // AQUA AMP"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", _font(42))
	title.add_theme_color_override("font_color", Color(0.77, 1.0, 0.96))
	title_row.add_child(title)

	var lcd := Label.new()
	lcd.text = "FISH 01  ● ONLINE   //   BLUEMESH SKELETAL CORE   //   TOUCH + DRAG = FOLLOW"
	lcd.add_theme_font_size_override("font_size", _font(23))
	lcd.add_theme_color_override("font_color", Color(0.35, 1.0, 0.56))
	stack.add_child(lcd)

	stack.add_child(HSeparator.new())

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", roundi(_u(8)))
	stack.add_child(tabs)
	for name in ["FISH", "SKIN", "BG", "FX"]:
		var b := Button.new()
		b.text = name
		b.custom_minimum_size = Vector2(0, _u(72))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", _font(28))
		_style_button(b)
		b.pressed.connect(_show_page.bind(name))
		tabs.add_child(b)
		tab_buttons[name] = b

	var page_host := VBoxContainer.new()
	page_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page_host.add_theme_constant_override("separation", roundi(_u(8)))
	stack.add_child(page_host)

	pages["FISH"] = _build_fish_page(page_host)
	pages["SKIN"] = _build_skin_page(page_host)
	pages["BG"] = _build_bg_page(page_host)
	pages["FX"] = _build_fx_page(page_host)

	var footer := Label.new()
	footer.text = "AQUA AMP v0.2     ◀  ◉  ▶      [ 1 FISH ]      UI: × HIDE / ≡ SHOW"
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_font_size_override("font_size", _font(22))
	footer.add_theme_color_override("font_color", Color(0.62, 0.9, 1.0))
	stack.add_child(footer)

	# Big persistent full-screen toggle.
	toggle_button = Button.new()
	toggle_button.text = "×"
	toggle_button.anchor_left = 0.835
	toggle_button.anchor_right = 0.985
	toggle_button.anchor_top = 0.012
	toggle_button.anchor_bottom = 0.135
	toggle_button.mouse_filter = Control.MOUSE_FILTER_STOP
	toggle_button.add_theme_font_size_override("font_size", _font(42))
	_style_button(toggle_button)
	toggle_button.pressed.connect(_toggle_panel)
	root.add_child(toggle_button)

func _build_fish_page(parent: VBoxContainer) -> VBoxContainer:
	var page := _new_page(parent)
	_add_stepper(page, "SWIM SPEED", 0.25, 1.8, 0.10, 0.78, func(v): _main().set_fish_speed(v), "%.2f")
	_add_stepper(page, "TURN RATE", 0.35, 2.6, 0.10, 1.05, func(v): _main().set_fish_turn_rate(v), "%.2f")
	_add_stepper(page, "FISH SIZE", 0.45, 1.7, 0.10, 1.00, func(v): _main().set_fish_size(v), "%.2f")
	return page

func _build_skin_page(parent: VBoxContainer) -> VBoxContainer:
	var page := _new_page(parent)
	_add_stepper(page, "FIN RATE", 0.35, 1.8, 0.10, 1.00, func(v): _main().set_fish_animation_rate(v), "%.2f")
	_add_preset_row(page, "BODY TINT", [
		["NATURAL", func(): _main().set_fish_tint(Color.WHITE)],
		["AQUA", func(): _main().set_fish_tint(Color(0.45, 1.0, 0.95))],
		["COBALT", func(): _main().set_fish_tint(Color(0.45, 0.62, 1.0))],
		["VIOLET", func(): _main().set_fish_tint(Color(0.82, 0.50, 1.0))],
		["ROSE", func(): _main().set_fish_tint(Color(1.0, 0.52, 0.68))],
	])
	_add_preset_row(page, "FIN MOTION", [
		["CALM", func(): _main().set_fish_animation_rate(0.65)],
		["NATURAL", func(): _main().set_fish_animation_rate(1.0)],
		["LIVELY", func(): _main().set_fish_animation_rate(1.35)],
	])
	return page

func _build_bg_page(parent: VBoxContainer) -> VBoxContainer:
	var page := _new_page(parent)
	_add_preset_row(page, "SOLID BACKGROUND", [
		["DEEP", func(): _main().set_background_color(Color(0.008, 0.025, 0.055))],
		["AQUA", func(): _main().set_background_color(Color(0.01, 0.16, 0.22))],
		["COBALT", func(): _main().set_background_color(Color(0.018, 0.045, 0.16))],
		["BLACK", func(): _main().set_background_color(Color.BLACK)],
	])
	_add_status_row(page, "IMAGE / GIF / VIDEO", "COMING WITH PICKER")
	return page

func _build_fx_page(parent: VBoxContainer) -> VBoxContainer:
	var page := _new_page(parent)
	_add_stepper(page, "LIGHT", 0.1, 6.0, 0.25, 2.2, func(v): _main().set_light_energy(v), "%.2f")
	_add_stepper(page, "DEPTH", 0.4, 3.2, 0.20, 2.45, func(v): _main().set_depth_range(v), "%.2f")
	_add_status_row(page, "CAUSTICS / BUBBLES", "NEXT PASS")
	return page

func _new_page(parent: VBoxContainer) -> VBoxContainer:
	var page := VBoxContainer.new()
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", roundi(_u(10)))
	parent.add_child(page)
	return page

func _add_stepper(parent: VBoxContainer, label_text: String, minimum: float, maximum: float, step: float, initial: float, callback: Callable, format: String) -> void:
	var state := {"value": initial}
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", roundi(_u(12)))
	parent.add_child(row)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(_u(250), _u(74))
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", _font(29))
	label.add_theme_color_override("font_color", Color(0.78, 0.96, 1.0))
	row.add_child(label)

	var minus := Button.new()
	minus.text = "−"
	minus.custom_minimum_size = Vector2(_u(92), _u(74))
	minus.add_theme_font_size_override("font_size", _font(38))
	_style_button(minus)
	row.add_child(minus)

	var value_label := Label.new()
	value_label.text = format % initial
	value_label.custom_minimum_size = Vector2(_u(170), _u(74))
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.add_theme_font_size_override("font_size", _font(34))
	value_label.add_theme_color_override("font_color", Color(0.36, 1.0, 0.58))
	row.add_child(value_label)

	var plus := Button.new()
	plus.text = "+"
	plus.custom_minimum_size = Vector2(_u(92), _u(74))
	plus.add_theme_font_size_override("font_size", _font(38))
	_style_button(plus)
	row.add_child(plus)

	var filler := Control.new()
	filler.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(filler)

	minus.pressed.connect(func():
		state["value"] = clampf(float(state["value"]) - step, minimum, maximum)
		value_label.text = format % float(state["value"])
		callback.call(float(state["value"]))
	)
	plus.pressed.connect(func():
		state["value"] = clampf(float(state["value"]) + step, minimum, maximum)
		value_label.text = format % float(state["value"])
		callback.call(float(state["value"]))
	)

func _add_preset_row(parent: VBoxContainer, label_text: String, presets: Array) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", roundi(_u(8)))
	parent.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(_u(250), _u(72))
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", _font(27))
	label.add_theme_color_override("font_color", Color(0.78, 0.96, 1.0))
	row.add_child(label)
	for item in presets:
		var b := Button.new()
		b.text = str(item[0])
		b.custom_minimum_size = Vector2(0, _u(72))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", _font(25))
		_style_button(b)
		var action: Callable = item[1]
		b.pressed.connect(action)
		row.add_child(b)

func _add_status_row(parent: VBoxContainer, label_text: String, status: String) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.custom_minimum_size = Vector2(0, _u(66))
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", _font(27))
	label.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
	row.add_child(label)
	var state := Label.new()
	state.text = status
	state.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	state.add_theme_font_size_override("font_size", _font(25))
	state.add_theme_color_override("font_color", Color(0.36, 1.0, 0.58))
	row.add_child(state)

func _show_page(name: String) -> void:
	for page_name in pages:
		pages[page_name].visible = page_name == name
	for tab_name in tab_buttons:
		var b: Button = tab_buttons[tab_name]
		b.text = "[ %s ]" % tab_name if tab_name == name else tab_name

func _toggle_panel() -> void:
	panel.visible = not panel.visible
	toggle_button.text = "×" if panel.visible else "≡"

func _main():
	return get_parent()

func _style_button(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.025, 0.34, 0.51, 0.98)
	normal.border_color = Color(0.42, 1.0, 0.95, 1.0)
	normal.set_border_width_all(roundi(_u(2)))
	normal.corner_radius_top_left = roundi(_u(8))
	normal.corner_radius_top_right = roundi(_u(8))
	normal.corner_radius_bottom_left = roundi(_u(8))
	normal.corner_radius_bottom_right = roundi(_u(8))

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.03, 0.48, 0.64, 1.0)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.12, 0.74, 0.72, 1.0)

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color(0.01, 0.08, 0.12))
