extends Node
var plugin
var wallpaper := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not Engine.has_singleton("LiveWallpaper"):
		return
	plugin = Engine.get_singleton("LiveWallpaper")
	wallpaper = plugin.IsLiveWallpaper()
	if wallpaper:
		plugin.VisibilityChanged.connect(_on_visibility)
		plugin.TrimMemory.connect(_on_trim)

func supported() -> bool:
	return plugin != null

func show_picker() -> bool:
	if plugin == null:
		return false
	return plugin.startWallpaperService() != 0

func _on_visibility(visible_now: bool) -> void:
	print("TamoTank wallpaper visible=", visible_now)
	# Never leave the fish simulation or GPU drawing behind another app.
	get_tree().paused = not visible_now
	if visible_now and get_parent().care:
		get_parent().care.reload_from_disk()

func _on_trim(level: int) -> void:
	if level >= 10:
		Engine.max_fps = 30
