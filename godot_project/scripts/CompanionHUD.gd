extends CanvasLayer
const GusaiAdapter = preload("res://scripts/GusaiRigAdapter.gd")
## Touch-first care, with the resident fish left visible between the cards.

var care
var root: Control
var header: PanelContainer
var dock: PanelContainer
var modal: PanelContainer
var name_button: Button
var status: Label
var friendship: Label
var note: Label
var rest_button: Button
var play_button: Button
var modal_body: VBoxContainer
var water: ShaderMaterial
var controls: Array = []
var unit := 1.0
var sparkles := 0.0
var action_grid: GridContainer
var status_clock := 0.0
var preview_page := false
var preview_camera_transform := Transform3D.IDENTITY
var preview_camera_fov := 40.0
var preview_camera_offset := 0.0

func _ready() -> void:
	call_deferred("_build")

func _build() -> void:
	if get_parent().wallpaper_mode:
		queue_free()
		return
	care = get_parent().care
	# Author in logical portrait units; _layout scales the entire UI on rotation.
	unit = 1.0
	var theme := Theme.new()
	var font := ThemeDB.fallback_font.duplicate()
	if font is FontFile:
		font.multichannel_signed_distance_field = true
	theme.set_stylebox("panel", "PopupPanel", _box(Color("0b222b"), Color("397079"), 15, 8))
	theme.default_font = font
	theme.default_font_size = roundi(18 * unit)
	theme.set_color("font_color", "Label", Color("d7f6ef"))
	theme.set_color("font_color", "Button", Color("e2fff7"))
	theme.set_stylebox("normal", "Button", _box(Color("16464e"), Color("397079"), 15, 12))
	theme.set_stylebox("hover", "Button", _box(Color("205d63"), Color("8de6d4"), 15, 12))
	theme.set_stylebox("pressed", "Button", _box(Color("346b6b"), Color("b3ffdd"), 15, 12))
	theme.set_stylebox("focus", "Button", _box(Color(0, 0, 0, 0), Color("eac29f"), 15, 2))
	root = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = theme
	add_child(root)

	var backdrop := CanvasLayer.new()
	backdrop.layer = -1
	get_parent().add_child(backdrop)
	var colour := ColorRect.new()
	colour.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	colour.mouse_filter = Control.MOUSE_FILTER_IGNORE
	water = ShaderMaterial.new()
	water.shader = preload("res://shaders/CompanionWater.gdshader")
	colour.material = water
	colour.visible = false
	backdrop.add_child(colour)
	var environment: Environment = get_parent().get_node("WorldEnvironment").environment
	environment.background_mode = Environment.BG_COLOR

	header = _panel(root)
	var intro := _stack(header)
	_label(intro, "T A M O T A N K", 12, Color("a3d1cd"))
	name_button = _button(intro, "Miso", _show_name, 0)
	name_button.add_theme_font_size_override("font_size", roundi(36 * unit))
	name_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_button.clip_text = true
	name_button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	status = _label(intro, "Happy to see you", 17, Color("a9e5d2"))
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	friendship = _label(intro, "", 13, Color("a3c6c7"))
	friendship.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	dock = _panel(root)
	var actions := _stack(dock)
	note = _label(actions, "A little companion. Care at your pace.", 17, Color("e6e4cd"))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size.y = 52 * unit
	var grid := GridContainer.new()
	action_grid = grid
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", roundi(8 * unit))
	grid.add_theme_constant_override("v_separation", roundi(8 * unit))
	actions.add_child(grid)
	_button(grid, "Snack", func(): care.offer_snack())
	play_button = _button(grid, "Play", func(): care.begin_play())
	_button(grid, "Sparkle", func(): care.refresh_water())
	rest_button = _button(grid, "Rest", func(): care.toggle_rest())
	_button(grid, "Memories", _show_memories)
	_button(grid, "World", _show_world)
	_label(actions, "Always safe. Always your little friend.", 12, Color("93bab8"))

	modal = _panel(root)
	modal.add_theme_stylebox_override("panel", _box(Color("0b222b"), Color("397079"), 23, 18))
	modal.visible = false
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
	care.delight.connect(func(): sparkles = 1.0)
	get_viewport().size_changed.connect(_layout)
	_layout()
	_refresh()

func _process(delta: float) -> void:
	if preview_page and modal and modal.visible and care and care.fish():
		# Frame the moving resident above the controls without changing its swim.
		var fish = care.fish()
		var focus: Vector3 = fish.global_position - fish.heading * 1.0
		var viewport_size := get_viewport().get_visible_rect().size
		var landscape := viewport_size.x > viewport_size.y
		var camera: Camera3D = get_parent().get_node("Camera3D")
		camera.fov = 50.0
		var distance := 3.0 if landscape else 7.0
		camera.position = focus + Vector3(0, 0, distance)
		camera.look_at(focus if landscape else focus - Vector3.UP)
		camera.h_offset = tan(deg_to_rad(25)) * distance * viewport_size.x / viewport_size.y * 0.48 if landscape else 0.0
	if water:
		sparkles = maxf(0.0, sparkles - delta * 0.25)
		water.set_shader_parameter("sparkle", sparkles)
	if care and status:
		status_clock += delta
		if status_clock >= 1.0:
			status_clock = 0.0
			_refresh_status()

func _layout() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var scale_factor := maxf(1.0, sqrt((viewport_size.x / viewport_size.y) / (540.0 / 1200.0)))
	root.scale = Vector2.ONE * scale_factor
	var size := viewport_size / scale_factor
	root.size = size
	if size.x > size.y:
		action_grid.columns = 2
		_place(header, Rect2(size.x * 0.025, size.y * 0.06, size.x * 0.27, size.y * 0.32))
		_place(dock, Rect2(size.x * 0.72, size.y * 0.10, size.x * 0.255, size.y * 0.80))
		_place(modal, Rect2(size.x * 0.31, size.y * 0.06, size.x * 0.39, size.y * 0.88))
	else:
		action_grid.columns = 3
		_place(header, Rect2(size.x * 0.045, size.y * 0.035, size.x * 0.91, size.y * 0.165))
		_place(dock, Rect2(size.x * 0.045, size.y * 0.725, size.x * 0.91, size.y * 0.235))
		_place(modal, Rect2(size.x * 0.045, size.y * 0.22, size.x * 0.91, size.y * 0.74))

	if preview_page:
		if size.x <= size.y:
			_place(modal, Rect2(size.x * 0.045, size.y * 0.54, size.x * 0.91, size.y * 0.42))
		else:
			_place(modal, Rect2(size.x * 0.52, size.y * 0.05, size.x * 0.455, size.y * 0.90))
	header.visible = not (preview_page and size.x > size.y)

func _place(control: Control, rect: Rect2) -> void:
	control.position = rect.position
	control.size = rect.size

func _refresh() -> void:
	name_button.text = care.state.pet_name + "  ›"
	_refresh_status()
	var moments: int = care.state.snacks + care.state.games + care.state.refreshes
	friendship.text = "Friendship %02d  ·  %d little %s" % [care.state.level(), moments, "moment" if moments == 1 else "moments"]
	rest_button.text = "Wake" if care.state.resting else "Rest"
	play_button.text = "Wander" if get_parent().play_mode else "Play"
	water.set_shader_parameter("resting", 1.0 if care.state.resting else 0.0)

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

func _message(text: String) -> void:
	note.text = text

func _open_page(title: String, subtitle: String) -> void:
	get_parent()._clear_touch_target()
	_end_preview()
	_layout()
	var scroll := modal.get_child(0) as ScrollContainer
	scroll.scroll_vertical = 0
	for child in modal_body.get_children():
		modal_body.remove_child(child)
		child.queue_free()
	_label(modal_body, title, 27, Color("f5e4c7"))
	var description := _label(modal_body, subtitle, 16, Color("accfca"))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_button(modal_body, "Back to the water", func(): modal.hide(), 50)
	modal.show()

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
	_button(modal_body, "Model & licence", func(): OS.shell_open("https://www.fab.com/listings/8744393d-3db2-44c9-869f-93a74c164b78" if purchased else "https://sketchfab.com/3d-models/betta-splendens-f4eeb7f50ad24873842bd954ad27d23b"), 48)
	if purchased:
		_button(modal_body, "BlueMesh model & CC BY 4.0", func(): OS.shell_open("https://sketchfab.com/3d-models/betta-splendens-f4eeb7f50ad24873842bd954ad27d23b"), 48)

func _show_world() -> void:
	_open_page("Your little world", "A quiet backwall, or a room with depth.")
	if get_parent().wallpaper_bridge.supported():
		_button(modal_body, "Set live wallpaper", func(): get_parent().wallpaper_bridge.show_picker())
	var modes := HBoxContainer.new()
	modal_body.add_child(modes)
	_button(modes, "Showcase", func(): get_parent().set_view_mode("showcase"))
	_button(modes, "Tank", func(): get_parent().set_view_mode("tank"))
	_label(modal_body, "Backwall colour", 16, Color("accfca"))
	var picker := ColorPickerButton.new()
	picker.color = Color.html(care.state.backwall)
	picker.edit_alpha = false
	picker.custom_minimum_size.y = 52
	picker.color_changed.connect(func(value): get_parent().set_backwall(value))
	modal_body.add_child(picker)
	picker.get_popup().about_to_popup.connect(func(): _fit_colour_picker(picker))
	_button(modal_body, "Fish colours & shimmer", _show_looks, 52)
	_button(modal_body, "Lights & atmosphere", _show_lighting, 52)
	_label(modal_body, "Your fish", 19, Color("e9d4a9"))
	var motion := CheckButton.new()
	motion.text = "Reactive fins"
	motion.button_pressed = care.state.live_fins
	motion.disabled = care.state.model_variant == 2 or not preload("res://scripts/GusaiRigAdapter.gd").available(care.state.model_variant)
	motion.custom_minimum_size.y = 50
	modal_body.add_child(motion)
	_label(modal_body, "Fin freedom", 16, Color("accfca"))
	var freedom := HSlider.new()
	freedom.min_value = 0.5
	freedom.max_value = 2.2
	freedom.step = 0.1
	freedom.value = care.state.fin_freedom
	freedom.editable = not motion.disabled and motion.button_pressed
	freedom.custom_minimum_size.y = 38
	freedom.value_changed.connect(func(value): get_parent().set_fin_freedom(value))
	modal_body.add_child(freedom)
	motion.toggled.connect(func(value):
		get_parent().set_fin_motion(value)
		freedom.editable = not motion.disabled and value)
	var options := ["Flowing split tail", "Broad fan tail", "Original companion"]
	for i in 3:
		var button := _button(modal_body, options[i], func():
			get_parent().set_model_variant(i)
			motion.disabled = i == 2
			freedom.editable = not motion.disabled and motion.button_pressed, 50)
		if i < 2 and not preload("res://scripts/GusaiRigAdapter.gd").available(i):
			button.disabled = true
	_label(modal_body, "A little personality", 19, Color("e9d4a9"))
	var kinds := HBoxContainer.new()
	modal_body.add_child(kinds)
	for kind in ["curious", "calm", "dreamy"]:
		_button(kinds, kind.capitalize(), func(): get_parent().set_personality(kind), 48)

func _show_looks() -> void:
	_open_page("Fish colours", "Make a palette. The scales and fin detail stay.")
	_begin_preview()
	var enabled := CheckButton.new()
	enabled.text = "Custom palette"
	enabled.button_pressed = care.state.style.fish.enabled
	enabled.custom_minimum_size.y = 50
	modal_body.add_child(enabled)
	enabled.toggled.connect(func(value): get_parent().set_style_value("fish", "enabled", value))
	_colour_control("Base colour", "fish", "base", enabled)
	_colour_control("Markings colour", "fish", "details", enabled)
	_style_slider("Markings", "fish", "markings", 0, 1, 0.05)
	_colour_control("Shimmer colour", "fish", "shimmer")
	_style_slider("Shimmer", "fish", "shimmer_amount", 0, 1, 0.05)
	_style_slider("Shine", "fish", "shine", 0, 1, 0.05)
	_style_slider("Saturation", "fish", "saturation", 0, 2, 0.05)
	_style_slider("Brightness", "fish", "brightness", 0.2, 1.8, 0.05)
	_label(modal_body, "Ready-made palettes", 19, Color("e9d4a9"))
	for palette_name in preload("res://scripts/AquariumStyle.gd").PRESETS:
		_button(modal_body, palette_name, func():
			get_parent().choose_palette(palette_name)
			_show_looks(), 50)
	_button(modal_body, "Surprise me", func():
		get_parent().randomise_fish()
		_show_looks(), 50)
	_button(modal_body, "Original colours", func():
		get_parent().choose_palette("Original")
		_show_looks(), 50)
	_button(modal_body, "Lights & atmosphere ›", _show_lighting, 50)

func _show_lighting() -> void:
	_open_page("Lights & atmosphere", "Paint the light around your little friend.")
	_begin_preview()
	_colour_control("Main light colour", "lights", "key")
	_style_slider("Main light strength", "lights", "energy", 0, 4, 0.1)
	_style_slider("Light direction", "lights", "yaw", -180, 180, 5)
	_style_slider("Light elevation", "lights", "elevation", -80, 80, 5)
	_colour_control("Fill light colour", "lights", "fill")
	_style_slider("Fill light strength", "lights", "fill_energy", 0, 3, 0.1)
	_style_slider("Ambient light", "lights", "ambient", 0, 1.5, 0.05)
	_label(modal_body, "Backwall colour", 16, Color("accfca"))
	var backwall := ColorPickerButton.new()
	backwall.edit_alpha = false
	backwall.color = Color.html(care.state.backwall)
	backwall.custom_minimum_size.y = 52
	backwall.color_changed.connect(func(value): get_parent().set_backwall(value))
	modal_body.add_child(backwall)
	backwall.get_popup().about_to_popup.connect(func(): _fit_colour_picker(backwall))
	_button(modal_body, "Reset lighting", func():
		get_parent().reset_lighting()
		_show_lighting(), 50)
	_button(modal_body, "Fish colours ›", _show_looks, 50)

func _begin_preview() -> void:
	var camera: Camera3D = get_parent().get_node("Camera3D")
	preview_camera_transform = camera.transform
	preview_camera_fov = camera.fov
	preview_camera_offset = camera.h_offset
	preview_page = true
	_layout()

func _end_preview() -> void:
	if not preview_page:
		return
	var camera: Camera3D = get_parent().get_node("Camera3D")
	camera.transform = preview_camera_transform
	camera.fov = preview_camera_fov
	camera.h_offset = preview_camera_offset
	preview_page = false
	header.show()

func _colour_control(title: String, section: String, key: String, enable: CheckButton = null) -> void:
	_label(modal_body, title, 16, Color("accfca"))
	var picker := ColorPickerButton.new()
	picker.name = section + "_" + key
	picker.color = Color.html(care.state.style[section][key])
	picker.edit_alpha = false
	picker.custom_minimum_size.y = 52
	picker.color_changed.connect(func(value):
		if enable and not enable.button_pressed:
			enable.button_pressed = true
		get_parent().set_style_value(section, key, value.to_html()))
	modal_body.add_child(picker)
	picker.get_popup().about_to_popup.connect(func(): _fit_colour_picker(picker))

func _fit_colour_picker(picker: ColorPickerButton) -> void:
	var popup := picker.get_popup()
	# Embedded windows use the viewport's logical coordinates, not UI scaling.
	popup.content_scale_factor = minf(root.scale.x, get_viewport().get_visible_rect().size.y * 0.9 / 700.0)
	popup.reset_size()

func _style_slider(title: String, section: String, key: String, low: float, high: float, increment: float) -> void:
	var caption := _label(modal_body, "", 16, Color("accfca"))
	var slider := HSlider.new()
	slider.name = section + "_" + key
	slider.min_value = low
	slider.max_value = high
	slider.step = increment
	slider.value = care.state.style[section][key]
	slider.custom_minimum_size.y = 44
	caption.text = "%s · %.2f" % [title, slider.value]
	slider.value_changed.connect(func(value):
		caption.text = "%s · %.2f" % [title, value]
		get_parent().set_style_value(section, key, value))
	modal_body.add_child(slider)

func _panel(parent: Node) -> PanelContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _box(Color(0.025, 0.10, 0.13, 0.90), Color(0.35, 0.66, 0.65, 0.5), 23, 18))
	parent.add_child(card)
	return card

func _stack(parent: Node) -> VBoxContainer:
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", roundi(8 * unit))
	parent.add_child(stack)
	return stack

func _label(parent: Node, text: String, font_size: int, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", roundi(font_size * unit))
	label.add_theme_color_override("font_color", colour)
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, action: Callable, height := 62) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = height * unit
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _box(fill: Color, border: Color, radius: int, margin: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(roundi(radius * unit))
	box.set_content_margin_all(margin * unit)
	return box
