extends CanvasLayer
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

func _ready() -> void:
	call_deferred("_build")

func _build() -> void:
	care = get_parent().care
	# Author in logical portrait units; _layout scales the entire UI on rotation.
	unit = 1.0
	var theme := Theme.new()
	var font := ThemeDB.fallback_font.duplicate()
	if font is FontFile:
		font.multichannel_signed_distance_field = true
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
	backdrop.add_child(colour)
	var environment: Environment = get_parent().get_node("WorldEnvironment").environment
	environment.background_mode = Environment.BG_CANVAS
	environment.background_canvas_max_layer = -1

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
	_button(grid, "Looks", _show_looks)
	_label(actions, "Always safe. Always your little friend.", 12, Color("93bab8"))

	modal = _panel(root)
	modal.visible = false
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
	if water:
		sparkles = maxf(0.0, sparkles - delta * 0.25)
		water.set_shader_parameter("sparkle", sparkles)

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

func _place(control: Control, rect: Rect2) -> void:
	control.position = rect.position
	control.size = rect.size

func _refresh() -> void:
	name_button.text = care.state.pet_name + "  ›"
	status.text = "Resting peacefully" if care.state.resting else "Feeling curious · happy to see you"
	var moments: int = care.state.snacks + care.state.games + care.state.refreshes
	friendship.text = "Friendship %02d  ·  %d little %s" % [care.state.level(), moments, "moment" if moments == 1 else "moments"]
	rest_button.text = "Wake" if care.state.resting else "Rest"
	play_button.text = "Wander" if get_parent().play_mode else "Play"
	water.set_shader_parameter("resting", 1.0 if care.state.resting else 0.0)

func _message(text: String) -> void:
	note.text = text

func _open_page(title: String, subtitle: String) -> void:
	get_parent()._clear_touch_target()
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
	_label(modal_body, "Together for %d %s" % [days, "day" if days == 1 else "days"], 20, Color("e9d4a9"))
	for line in ["%d shared snacks" % care.state.snacks, "%d little games" % care.state.games, "%d water sparkles" % care.state.refreshes]:
		_label(modal_body, line, 18, Color("b8e4d9"))
	modal_body.add_child(HSeparator.new())
	for memory in care.state.journal:
		var line := _label(modal_body, str(memory), 17, Color("cfdfd0"))
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modal_body.add_child(HSeparator.new())
	var credit := _label(modal_body, "Betta Splendens by BlueMesh · CC BY 4.0\nModified body, skin and swimming.", 13, Color("93bab8"))
	credit.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_button(modal_body, "Model & licence", func(): OS.shell_open("https://sketchfab.com/3d-models/betta-splendens-f4eeb7f50ad24873842bd954ad27d23b"), 48)

func _show_looks() -> void:
	_open_page("A little colour", "Soft colour tints for your companion.")
	for i in 4:
		var names := ["Natural", "Moon blue", "Rose quartz", "Sea glass"]
		_button(modal_body, names[i], func(): care.choose_look(i))
	_label(modal_body, "TamoTank · companion preview 0.8", 13, Color("93bab8"))

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
