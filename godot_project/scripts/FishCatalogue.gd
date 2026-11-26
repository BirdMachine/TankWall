extends RefCounted
## Stable saved model indexes; optional purchased assets are never required by CI.
const Gusai = preload("res://scripts/GusaiRigAdapter.gd")
const ITEMS := [
	{"name": "Split tail", "detail": "Long, ribbon-like fins", "portrait": "res://assets/models/gusai_betta/portraits/split.png"},
	{"name": "Fan tail", "detail": "A broad, flowing silhouette", "portrait": "res://assets/models/gusai_betta/portraits/fan.png"},
	{"name": "Classic", "detail": "Our first little companion", "portrait": "res://assets/portraits/classic.png"}]
static func available(index: int) -> bool:
	return index == 2 or (index >= 0 and index < 2 and Gusai.available(index))
static func item(index: int) -> Dictionary:
	return ITEMS[clampi(index, 0, 2)]
