extends CanvasLayer
## Quiet, touch-first controls. The fish remains the centre of the screen.
const GusaiAdapter = preload("res://scripts/GusaiRigAdapter.gd")
const Catalogue = preload("res://scripts/FishCatalogue.gd")
const Style = preload("res://scripts/AquariumStyle.gd")
const PAPER := Color("f1ede5")
const MUTED := Color("a4b9ba")
const ACCENT := Color("9ed5c3")
const GOLD := Color("cbb991")
const PANEL := Color("102329")
var care
var root: Control
var header_shade: ColorRect
var header: PanelContainer
var dock: PanelContainer
var modal: PanelContainer
var modal_body: VBoxContainer
var name_button: Button
var brand_label: Label
var status: Label
var friendship: Label
var note: Label
var rest_button: Button
var play_button: Button
var unit := 1.0
var status_clock := 0.0
var toast_clock := 0.0
var preview_page := false
var preview_camera: Camera3D
var page_key := ""

func _ready() -> void:
	call_deferred("_build")

func _build() -> void:
	if get_parent().wallpaper_mode:
		queue_free()
		return
	care = get_parent().care
	var theme := Theme.new()
	var font := ThemeDB.fallback_font.duplicate()
	if font is FontFile:
		font.multichannel_signed_distance_field = true
	theme.default_font = font
	theme.default_font_size = 18
	theme.set_color("font_color", "Label", PAPER)
	theme.set_color("font_color", "Button", PAPER)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_stylebox("normal", "Button", _box(Color("193139"), Color(0.6, 0.8, 0.76, 0.12), 13, 12))
	theme.set_stylebox("hover", "Button", _box(Color("223d43"), Color(0.6, 0.8, 0.76, 0.3), 13, 12))
	theme.set_stylebox("pressed", "Button", _box(Color("31534f"), ACCENT, 13, 12))
	theme.set_stylebox("focus", "Button", _box(Color.TRANSPARENT, GOLD, 13, 2))
	theme.set_stylebox("panel", "PopupPanel", _box(PANEL, Color("385b5e"), 16, 10))
	var rail := _box(Color("31454a"), Color.TRANSPARENT, 2, 0)
	rail.content_margin_top = 2
	rail.content_margin_bottom = 2
	theme.set_stylebox("slider", "HSlider", rail)
	var fill := rail.duplicate()
	fill.bg_color = ACCENT
	theme.set_stylebox("grabber_area", "HSlider", fill)
	theme.set_stylebox("grabber_area_highlight", "HSlider", fill)
	root = Control.new()
	root.theme = theme
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	header_shade = ColorRect.new()
	header_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shade := ShaderMaterial.new()
	shade.shader = preload("res://shaders/HeaderShade.gdshader")
	header_shade.material = shade
	root.add_child(header_shade)
	header = PanelContainer.new()
	header.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	root.add_child(header)
	var intro := _stack(header)
	intro.add_theme_constant_override("separation", 2)
	brand_label = _label(intro, "T A M O T A N K", 11, GOLD)
	name_button = _button(intro, "Miso", _show_name, 54)
	name_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_button.add_theme_font_size_override("font_size", 36)
	name_button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	name_button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	name_button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	name_button.clip_text = true
	name_button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	status = _label(intro, "A little company", 15, MUTED)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	friendship = _label(intro, "", 12, MUTED)
	friendship.hide()
	dock = _panel(root, false)
	var navigation := HBoxContainer.new()
	navigation.add_theme_constant_override("separation", 4)
	dock.add_child(navigation)
	for entry in [["Care", _show_care], ["Fish", _show_fish], ["World", _show_world], ["Journal", _show_memories]]:
		var button := _button(navigation, entry[0], entry[1], 50)
		button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		button.add_theme_font_size_override("font_size", 16)
	note = _label(root, "", 15, PAPER)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	note.hide()
	modal = _panel(root)
	modal.hide()
	modal.visibility_changed.connect(func():
		dock.visible = not modal.visible
		if not modal.visible:
			_end_preview())
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	modal.add_child(scroll)
	modal_body = _stack(scroll)
	modal_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	care.changed.connect(_refresh)
	care.message.connect(_message)
	get_viewport().size_changed.connect(_layout)
	_layout()
	_refresh()

func _process(delta: float) -> void:
	if preview_page and modal and modal.visible and care and care.fish():
		var fish = care.fish()
		var focus: Vector3 = fish.global_position - fish.heading
		var size := get_viewport().get_visible_rect().size
		var landscape := size.x > size.y
		var distance := 3.0 if landscape else 7.0
		preview_camera.fov = 50.0
		preview_camera.position = focus + Vector3(0, 0, distance)
		preview_camera.look_at(focus if landscape else focus - Vector3.UP)
		preview_camera.h_offset = tan(deg_to_rad(25)) * distance * size.x / size.y * 0.48 if landscape else 0.0
	if care and status:
		status_clock += delta
		if status_clock >= 1:
			status_clock = 0
			_refresh_status()
	if toast_clock > 0:
		toast_clock = maxf(0, toast_clock - delta)
		note.modulate.a = minf(1, toast_clock)
		note.visible = toast_clock > 0 and not modal.visible

func _layout() -> void:
	if root == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var factor := maxf(1, sqrt((viewport_size.x / viewport_size.y) / (540.0 / 1200.0)))
	root.scale = Vector2.ONE * factor
	var size := viewport_size / factor
	root.size = size
	if size.x > size.y:
		_place(header, Rect2(size.x * 0.035, size.y * 0.06, size.x * 0.26, size.y * 0.44))
		_place(dock, Rect2(size.x * 0.035, size.y * 0.79, size.x * 0.93, size.y * 0.17))
		_place(modal, Rect2(size.x * 0.52, size.y * 0.045, size.x * 0.455, size.y * 0.91))
		_place(note, Rect2(size.x * 0.06, size.y * 0.62, size.x * 0.88, size.y * 0.15))
	else:
		_place(header, Rect2(size.x * 0.07, size.y * 0.045, size.x * 0.86, size.y * 0.14))
		_place(dock, Rect2(size.x * 0.045, size.y * 0.905, size.x * 0.91, size.y * 0.055))
		_place(modal, Rect2(size.x * 0.045, size.y * 0.53, size.x * 0.91, size.y * 0.43))
		_place(note, Rect2(size.x * 0.08, size.y * 0.83, size.x * 0.84, size.y * 0.06))
	header.visible = not (preview_page and size.x > size.y)
	header_shade.visible = header.visible
	header_shade.position = Vector2.ZERO
	header_shade.size = Vector2(size.x * 0.37, size.y * 0.65) if size.x > size.y else Vector2(size.x, size.y * 0.23)
	header_shade.material.set_shader_parameter("landscape", size.x > size.y)

func _place(control: Control, rect: Rect2) -> void:
	control.position = rect.position
	control.size = rect.size

func _refresh() -> void:
	name_button.text = care.state.pet_name
	_refresh_status()
	friendship.text = "Friendship %02d" % care.state.level()
	if is_instance_valid(rest_button):
		rest_button.text = "Wake" if care.state.resting else "Rest"
	if is_instance_valid(play_button):
		play_button.text = "Wander" if get_parent().play_mode else "Follow"

func _message(text: String) -> void:
	note.text = text
	toast_clock = 5.0
	note.modulate.a = 1
	note.visible = not modal.visible

func _open_page(title: String, subtitle: String) -> void:
	get_parent()._clear_touch_target()
	_end_preview()
	page_key = title
	play_button = null
	rest_button = null
	for child in modal_body.get_children():
		modal_body.remove_child(child)
		child.queue_free()
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 12)
	modal_body.add_child(heading)
	var label := _label(heading, title, 26, PAPER)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var close := _button(heading, "Done", func(): modal.hide(), 44)
	close.size_flags_horizontal = Control.SIZE_SHRINK_END
	close.custom_minimum_size.x = 72
	var description := _label(modal_body, subtitle, 15, MUTED)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modal.show()
	note.hide()
	var scroll := modal.get_child(0) as ScrollContainer
	scroll.scroll_vertical = 0
	_begin_preview()

func _show_care() -> void:
	_open_page("Little rituals", "A visit, a little game, a quiet moment. Whenever you like.")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	modal_body.add_child(grid)
	_button(grid, "Snack", func(): modal.hide(); care.offer_snack(), 68)
	play_button = _button(grid, "Wander" if get_parent().play_mode else "Follow", func(): modal.hide(); care.begin_play(), 68)
	_button(grid, "Refresh", func(): modal.hide(); care.refresh_water(), 68)
	rest_button = _button(grid, "Wake" if care.state.resting else "Rest", func(): modal.hide(); care.toggle_rest(), 68)
	_label(modal_body, "The good moments stay. No need to keep up.", 14, MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _show_fish() -> void:
	_open_page("Your fish", "Choose a silhouette. Keep your favourite colours.")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	modal_body.add_child(grid)
	for i in 3:
		if not Catalogue.available(i):
			continue
		var entry := Catalogue.item(i)
		var selected: bool = care.state.model_variant == i
		var card := _button(grid, "", func():
			get_parent().set_model_variant(i)
			_show_fish(), 236)
		card.name = "model_%d" % i
		card.add_theme_stylebox_override("normal", _box(Color("1c353b") if selected else Color("162a30"), ACCENT if selected else Color("30484c"), 13, 10))
		var margin := MarginContainer.new()
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		for key in ["left", "top", "right", "bottom"]:
			margin.add_theme_constant_override("margin_" + key, 10)
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(margin)
		var stack := _stack(margin)
		stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var portrait := TextureRect.new()
		portrait.custom_minimum_size.y = 115
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if ResourceLoader.exists(entry.portrait):
			portrait.texture = load(entry.portrait)
		else:
			portrait.texture = preload("res://icon.svg")
		stack.add_child(portrait)
		_label(stack, entry.name, 18, PAPER)
		var detail := _label(stack, entry.detail, 12, MUTED)
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_label(stack, "Selected" if selected else "Choose", 12, ACCENT if selected else GOLD)
	_button(modal_body, "Colour & finish  ›", _show_looks)
	_button(modal_body, "Movement & personality  ›", _show_motion)

func _show_world() -> void:
	_open_page("Your world", "An open stage, or a little room with depth.")
	_section("Scene")
	_choices([["Showcase", "showcase"], ["Tank", "tank"]], care.state.view_mode, func(value): get_parent().set_view_mode(value))
	_colour_control("Backwall", "world", "backwall")
	_button(modal_body, "Lighting  ›", _show_lighting)
	_button(modal_body, "Depth & shadows  ›", _show_depth)
	if get_parent().wallpaper_bridge.supported():
		_button(modal_body, "Set as live wallpaper", func(): get_parent().wallpaper_bridge.show_picker())

func _show_motion() -> void:
	_open_page("Movement", "A little personality, with room to wander.")
	_section("Fin motion")
	var motion := CheckButton.new()
	motion.text = "Reactive fins"
	motion.button_pressed = care.state.live_fins
	motion.disabled = care.state.model_variant == 2 or not GusaiAdapter.available(care.state.model_variant)
	motion.custom_minimum_size.y = 48
	modal_body.add_child(motion)
	var freedom := _slider("Freedom", care.state.fin_freedom, 0.5, 2.2, 0.1, func(value): get_parent().set_fin_freedom(value))
	freedom.editable = not motion.disabled and motion.button_pressed
	motion.toggled.connect(func(value):
		get_parent().set_fin_motion(value)
		freedom.editable = not motion.disabled and value)
	if not motion.disabled and preload("res://scripts/NativeFinCloth.gd").available():
		_section("Fin feel")
		_choices([["Water", "water"], ["Cloth", "cloth"]], care.state.fin_backend, func(value): get_parent().set_fin_backend(value))
		_label(modal_body, "Cloth is an experimental alternative. Water keeps the familiar flow.", 13, MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_section("Personality")
	_choices([["Curious", "curious"], ["Calm", "calm"], ["Dreamy", "dreamy"]], care.state.personality, func(value): get_parent().set_personality(value))
	_button(modal_body, "‹  Your fish", _show_fish, 48)

func _show_looks() -> void:
	_open_page("Colour & finish", "Your palette, with the original scales and fin detail.")
	_page_tabs([["Colour", _show_looks], ["Finish", _show_finish]], "Colour")
	var enabled := CheckButton.new()
	enabled.text = "Custom palette"
	enabled.button_pressed = care.state.style.fish.enabled
	enabled.custom_minimum_size.y = 48
	modal_body.add_child(enabled)
	enabled.toggled.connect(func(value): get_parent().set_style_value("fish", "enabled", value))
	_colour_control("Base colour", "fish", "base", enabled)
	_colour_control("Markings", "fish", "details", enabled)
	_style_slider("Marking strength", "fish", "markings", 0, 1, 0.05)
	_section("Palettes")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	modal_body.add_child(grid)
	for palette_name in Style.PRESETS:
		_button(grid, palette_name, func(): get_parent().choose_palette(palette_name); _show_looks(), 48)
	_button(grid, "Surprise me", func(): get_parent().randomise_fish(); _show_looks(), 48)
	_button(modal_body, "Original colours", func(): get_parent().choose_palette("Original"); _show_looks(), 48)
	_button(modal_body, "‹  Your fish", _show_fish, 48)

func _show_finish() -> void:
	_open_page("Colour & finish", "A little sheen, or a softer, quieter finish.")
	_page_tabs([["Colour", _show_looks], ["Finish", _show_finish]], "Finish")
	_colour_control("Shimmer colour", "fish", "shimmer")
	_style_slider("Shimmer", "fish", "shimmer_amount", 0, 1, 0.05)
	_style_slider("Shine", "fish", "shine", 0, 1, 0.05)
	_style_slider("Saturation", "fish", "saturation", 0, 2, 0.05)
	_style_slider("Brightness", "fish", "brightness", 0.2, 1.8, 0.05)
	_button(modal_body, "‹  Your fish", _show_fish, 48)

func _show_lighting() -> void:
	_open_page("Lighting", "Shape the light around your little friend.")
	_page_tabs([["Light", _show_lighting], ["Depth", _show_depth]], "Light")
	_section("Lighting studies")
	var studies := HBoxContainer.new()
	studies.add_theme_constant_override("separation", 8)
	modal_body.add_child(studies)
	for preset_name in Style.LIGHT_PRESETS:
		var preset := _button(studies, preset_name, func(): get_parent().choose_lighting(preset_name); _show_lighting(), 46)
		preset.add_theme_font_size_override("font_size", 14)
	_colour_control("Main light", "lights", "key")
	_style_slider("Strength", "lights", "energy", 0, 4, 0.1)
	_style_slider("Direction", "lights", "yaw", -180, 180, 5, "°")
	_style_slider("Elevation", "lights", "elevation", -80, 80, 5, "°")
	_colour_control("Fill light", "lights", "fill")
	_style_slider("Fill strength", "lights", "fill_energy", 0, 3, 0.1)
	_colour_control("Ambient colour", "lights", "ambient_colour")
	_style_slider("Ambient strength", "lights", "ambient", 0, 1.5, 0.05)
	_button(modal_body, "Reset lighting", func(): get_parent().reset_lighting(); _show_lighting(), 48)
	_button(modal_body, "‹  Your world", _show_world, 48)

func _show_depth() -> void:
	_open_page("Lighting", "Gentle occlusion in creases, and shadows with depth.")
	_page_tabs([["Light", _show_lighting], ["Depth", _show_depth]], "Depth")
	_style_toggle("Ambient occlusion", "occlusion")
	_style_slider("Occlusion strength", "lights", "occlusion_strength", 0, 2, 0.05)
	_style_slider("Occlusion radius", "lights", "occlusion_radius", 0.02, 1, 0.02)
	_style_toggle("Cast shadows", "shadows")
	_style_slider("Shadow strength", "lights", "shadow_strength", 0, 1, 0.05)
	_label(modal_body, "Occlusion and shadows use extra rendering power. Switch them off for a lighter wallpaper.", 13, MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_button(modal_body, "‹  Your world", _show_world, 48)

func _page_tabs(entries: Array, current: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	modal_body.add_child(row)
	for entry in entries:
		var button := _button(row, entry[0], entry[1], 44)
		if entry[0] == current:
			button.add_theme_color_override("font_color", ACCENT)
			button.add_theme_stylebox_override("normal", _box(Color("29453f"), Color("527a6b"), 12, 8))

func _choices(entries: Array, current: String, action: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	modal_body.add_child(row)
	for entry in entries:
		var button := _button(row, entry[0], func(): action.call(entry[1]), 48)
		button.name = "choice_" + entry[1]
		button.toggle_mode = true
		button.button_pressed = entry[1] == current
		var group := row.get_meta("group", null) as ButtonGroup
		if group == null:
			group = ButtonGroup.new()
			row.set_meta("group", group)
		button.button_group = group

func _section(text: String) -> void:
	_label(modal_body, text.to_upper(), 11, GOLD)

func _colour_control(title: String, section: String, key: String, enable: CheckButton = null) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	modal_body.add_child(row)
	var title_label := _label(row, title, 16, PAPER)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var picker := ColorPickerButton.new()
	picker.name = section + "_" + key
	picker.color = Color.html(care.state.backwall if section == "world" else care.state.style[section][key])
	picker.edit_alpha = false
	picker.custom_minimum_size = Vector2(116, 48)
	picker.color_changed.connect(func(value):
		if section == "world":
			get_parent().set_backwall(value)
		else:
			if enable and not enable.button_pressed:
				enable.button_pressed = true
			get_parent().set_style_value(section, key, value.to_html()))
	row.add_child(picker)
	# Preserve a direct, stable lookup for integration checks and accessibility.
	picker.unique_name_in_owner = false
	picker.set_meta("style_control", section + "_" + key)
	picker.get_popup().about_to_popup.connect(func(): _fit_colour_picker(picker))

func _style_toggle(title: String, key: String) -> void:
	var control := CheckButton.new()
	control.name = "lights_" + key
	control.text = title
	control.custom_minimum_size.y = 48
	control.button_pressed = care.state.style.lights[key]
	control.toggled.connect(func(value): get_parent().set_style_value("lights", key, value))
	modal_body.add_child(control)

func _style_slider(title: String, section: String, key: String, low: float, high: float, step: float, suffix := "") -> void:
	var slider := _slider(title, care.state.style[section][key], low, high, step, func(value): get_parent().set_style_value(section, key, value), suffix)
	slider.name = section + "_" + key

func _slider(title: String, value: float, low: float, high: float, step: float, action: Callable, suffix := "") -> HSlider:
	var row := HBoxContainer.new()
	modal_body.add_child(row)
	var caption := _label(row, title, 15, MUTED)
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var reading := _label(row, "%.2f%s" % [value, suffix], 13, PAPER)
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.value = value
	slider.custom_minimum_size.y = 38
	slider.value_changed.connect(func(number):
		reading.text = "%.2f%s" % [number, suffix]
		action.call(number))
	modal_body.add_child(slider)
	return slider

func _panel(parent: Node, solid := true) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(PANEL if solid else Color(0.05, 0.10, 0.12, 0.94), Color(0.6, 0.8, 0.76, 0.22), 20, 16 if solid else 6))
	parent.add_child(panel)
	return panel

func _stack(parent: Node) -> VBoxContainer:
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 12)
	parent.add_child(stack)
	return stack

func _label(parent: Node, text: String, font_size: int, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, action: Callable, height := 54) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = height
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _show_name() -> void:
	_open_page("A name for a friend", "What shall we call this little one?")
	var field := LineEdit.new()
	field.text = care.state.pet_name
	field.max_length = 24
	field.custom_minimum_size.y = 64 * unit
	field.add_theme_font_size_override("font_size", roundi(23 * unit))
	modal_body.add_child(field)
	var accept := func():
		care.rename_pet(field.text)
		modal.hide()
	_button(modal_body, "That's your name", accept)
	field.text_submitted.connect(func(_text): accept.call())

func _show_memories() -> void:
	_open_page("Our little story", "The good moments stay. Visit whenever it feels nice.")
	var days: int = care.state.age_days(Time.get_unix_time_from_system())
	_label(modal_body, "Our first day together" if days == 0 else "Together for %d %s" % [days, "day" if days == 1 else "days"], 20, Color("e9d4a9"))
	for line in ["%d shared %s" % [care.state.snacks, "snack" if care.state.snacks == 1 else "snacks"],
		"%d little %s" % [care.state.games, "game" if care.state.games == 1 else "games"],
		"%d water %s" % [care.state.refreshes, "sparkle" if care.state.refreshes == 1 else "sparkles"]]:
		_label(modal_body, line, 18, Color("b8e4d9"))
	modal_body.add_child(HSeparator.new())
	for memory in care.state.journal:
		var line := _label(modal_body, str(memory), 17, Color("cfdfd0"))
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modal_body.add_child(HSeparator.new())
	var purchased: bool = care.fish() != null and care.fish().rig_adapter != null and care.fish().rig_adapter.get_script() == GusaiAdapter
	var credit_text := "Betta fish by Gusai · Fab\nAdapted for TamoTank.\nOriginal companion by BlueMesh · CC BY 4.0." if purchased else "Betta Splendens by BlueMesh · CC BY 4.0\nModified body, skin and swimming."
	var credit := _label(modal_body, credit_text, 13, Color("93bab8"))
	credit.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_button(modal_body, "Open-source notices", _show_notices, 48)
	_button(modal_body, "Model & licence", func(): OS.shell_open("https://www.fab.com/listings/8744393d-3db2-44c9-869f-93a74c164b78" if purchased else "https://sketchfab.com/3d-models/betta-splendens-f4eeb7f50ad24873842bd954ad27d23b"), 48)
	if purchased:
		_button(modal_body, "BlueMesh model & CC BY 4.0", func(): OS.shell_open("https://sketchfab.com/3d-models/betta-splendens-f4eeb7f50ad24873842bd954ad27d23b"), 48)

func _refresh_status() -> void:
	if care.state.resting:
		status.text = "Resting peacefully"
	elif not care.pellets.is_empty():
		status.text = "Investigating a tiny snack"
	elif get_parent().play_mode:
		status.text = "Following your finger"
	else:
		var fish = care.fish()
		status.text = fish.brain.state_label if fish and fish.brain else "Happy to see you"

func _begin_preview() -> void:
	# Keep the production camera immutable: bounds/input still use its rays,
	# including when orientation changes while a palette page is open.
	preview_camera = Camera3D.new()
	preview_camera.name = "CustomizationCamera"
	preview_camera.transform = get_parent().get_node("Camera3D").transform
	get_parent().add_child(preview_camera)
	preview_camera.make_current()
	preview_page = true
	_layout()

func _end_preview() -> void:
	if not preview_page:
		return
	get_parent().get_node("Camera3D").make_current()
	preview_camera.queue_free()
	preview_camera = null
	preview_page = false
	header.show()
	header_shade.show()

func _fit_colour_picker(picker: ColorPickerButton) -> void:
	var popup := picker.get_popup()
	# Embedded windows use the viewport's logical coordinates, not UI scaling.
	popup.content_scale_factor = minf(root.scale.x, get_viewport().get_visible_rect().size.y * 0.9 / 700.0)
	popup.reset_size()

func _box(fill: Color, border: Color, radius: int, margin: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(roundi(radius * unit))
	box.set_content_margin_all(margin * unit)
	return box

func _show_notices() -> void:
	_open_page("Open-source notices", "Libraries and artists that helped make this little world.")
	var text := FileAccess.get_file_as_string("res://licenses/BoneCloth.txt")
	_label(modal_body, text, 12, MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
