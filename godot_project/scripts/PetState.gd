extends RefCounted
## An additive companion history. Time away never removes progress or comfort.

var pet_name := "Miso"
var adopted_at := 0.0
var last_seen := 0.0
var bond := 0
var snacks := 0
var games := 0
var refreshes := 0
var resting := false
var look := 0
var visits := 1
var journal: Array = []

func initialize(now: float) -> void:
	adopted_at = now
	last_seen = now
	remember("A little friendship begins.")

func remember(line: String) -> void:
	journal.push_front(line)
	journal = journal.slice(0, 8)

func level() -> int:
	return 1 + int(sqrt(float(bond) / 8.0))

func age_days(now: float) -> int:
	return maxi(0, int((now - adopted_at) / 86400.0))

func record_care(kind: String) -> void:
	match kind:
		"snack":
			snacks += 1
			bond += 3
			if snacks == 1:
				remember("Our first shared snack.")
		"play":
			games += 1
			bond += 2
			if games == 1:
				remember("Followed your finger for the first time.")
		"refresh":
			refreshes += 1
			bond += 1
			if refreshes == 1:
				remember("Made the water sparkle together.")

func to_data() -> Dictionary:
	return {"version": 1, "pet_name": pet_name, "adopted_at": adopted_at,
		"last_seen": last_seen, "bond": bond, "snacks": snacks, "games": games,
		"refreshes": refreshes, "resting": resting, "look": look,
		"visits": visits, "journal": journal}

func from_data(data: Dictionary, now: float) -> void:
	pet_name = str(data.get("pet_name", "Miso")).strip_edges().left(24)
	if pet_name.is_empty():
		pet_name = "Miso"
	adopted_at = clampf(float(data.get("adopted_at", now)), 0.0, now)
	last_seen = clampf(float(data.get("last_seen", now)), adopted_at, now)
	bond = maxi(0, int(data.get("bond", 0)))
	snacks = maxi(0, int(data.get("snacks", 0)))
	games = maxi(0, int(data.get("games", 0)))
	refreshes = maxi(0, int(data.get("refreshes", 0)))
	resting = bool(data.get("resting", false))
	look = clampi(int(data.get("look", 0)), 0, 3)
	visits = maxi(1, int(data.get("visits", 1)))
	var entries = data.get("journal", [])
	journal.clear()
	if entries is Array:
		for entry in entries.slice(0, 8):
			journal.append(str(entry).left(100))
	# Deliberately no offline decay, sickness, death, lost bond, or streaks.

func save_to(path: String) -> Error:
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(to_data()))
	file.close()
	# Keep the previous valid save as recovery if a later file is damaged.
	if FileAccess.file_exists(path):
		var prior := JSON.new()
		if prior.parse(FileAccess.get_file_as_string(path)) == OK and prior.data is Dictionary:
			DirAccess.copy_absolute(path, path + ".bak")
	return DirAccess.rename_absolute(temporary, path)

func load_from(path: String, now: float) -> bool:
	for candidate in [path, path + ".bak"]:
		if not FileAccess.file_exists(candidate):
			continue
		var json := JSON.new()
		if json.parse(FileAccess.get_file_as_string(candidate)) != OK:
			continue
		var parsed = json.data
		if parsed is Dictionary and int(parsed.get("version", 0)) == 1:
			from_data(parsed, now)
			return true
	initialize(now)
	return false
