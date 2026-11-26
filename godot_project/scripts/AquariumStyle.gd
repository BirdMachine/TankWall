extends RefCounted
## Render preferences only: changing a palette never changes care or locomotion.
const FISH := {"enabled": false, "base": "288ddfff", "details": "ed395dff",
	"shimmer": "9fe9ffff", "shimmer_amount": 0.0, "markings": 1.0,
	"saturation": 1.0, "brightness": 1.0, "shine": 0.6}
const LIGHTS := {"key": "ffffffff", "energy": 1.6, "yaw": 45.0, "elevation": 30.0,
	"fill": "99cfffff", "fill_energy": 0.0, "ambient": 0.6, "ambient_colour": "8cbfd9ff",
	"occlusion": false, "occlusion_strength": 0.75, "occlusion_radius": 0.24,
	"shadows": false, "shadow_strength": 0.7}
const RANGES := {"fish": {"shimmer_amount": Vector2(0, 1), "markings": Vector2(0, 1),
	"saturation": Vector2(0, 2), "brightness": Vector2(0.2, 1.8), "shine": Vector2(0, 1)},
	"lights": {"energy": Vector2(0, 4), "yaw": Vector2(-180, 180),
	"elevation": Vector2(-80, 80), "fill_energy": Vector2(0, 3), "ambient": Vector2(0, 1.5), "occlusion_strength": Vector2(0, 2),
	"occlusion_radius": Vector2(0.02, 1), "shadow_strength": Vector2(0, 1)}}
const PRESETS := {
	"Moon jelly": ["668dffff", "cceeffff", "bedbffff"],
	"Rose quartz": ["f48aabff", "ac4acfff", "ffd6edff"],
	"Sea glass": ["33cfb5ff", "c9f2a0ff", "baffeeff"],
	"Ember": ["ffae38ff", "cf285bff", "ffe6a6ff"],
	"Electric orchid": ["a457e8ff", "30dcf5ff", "f1bcffff"]}

const LIGHT_PRESETS := {
	"Soft studio": {"key": "fff3e2ff", "energy": 1.5, "fill": "b8e8edff", "fill_energy": 0.35,
		"ambient": 0.45, "ambient_colour": "adcdd6ff", "occlusion": true},
	"Moonlit": {"key": "b6d9ffff", "energy": 1.25, "fill": "b49ae4ff", "fill_energy": 0.35,
		"ambient": 0.24, "ambient_colour": "7e9dcfff", "occlusion": true},
	"Warm dusk": {"key": "ffd5a0ff", "energy": 1.3, "fill": "e8a6c3ff", "fill_energy": 0.3,
		"ambient": 0.32, "ambient_colour": "beafc2ff", "occlusion": true}}

static func lighting(name: String) -> Dictionary:
	var result := LIGHTS.duplicate()
	if name in LIGHT_PRESETS:
		result.merge(LIGHT_PRESETS[name], true)
	return result

static func defaults() -> Dictionary:
	return {"fish": FISH.duplicate(), "lights": LIGHTS.duplicate()}

static func sanitize(value: Variant) -> Dictionary:
	var result := defaults()
	if not value is Dictionary:
		return result
	for section in result:
		var values = value.get(section, {})
		if not values is Dictionary:
			continue
		for key in result[section]:
			var candidate = values.get(key, result[section][key])
			var fallback = result[section][key]
			if fallback is String:
				if candidate is String and Color.html_is_valid(candidate):
					result[section][key] = Color.html(candidate).to_html(false) + "ff"
			elif fallback is bool:
				if candidate is bool:
					result[section][key] = candidate
			elif candidate is float or candidate is int:
				if is_finite(float(candidate)):
					var bounds: Vector2 = RANGES[section][key]
					result[section][key] = clampf(float(candidate), bounds.x, bounds.y)
	return result

static func palette(name: String) -> Dictionary:
	var result := FISH.duplicate()
	if name in PRESETS:
		var colours: Array = PRESETS[name]
		result.merge({"enabled": true, "base": colours[0], "details": colours[1],
			"shimmer": colours[2], "shimmer_amount": 0.28}, true)
	return result

static func apply_material(material: ShaderMaterial, fish: Dictionary) -> void:
	material.set_shader_parameter("palette_enabled", fish.enabled)
	for key in ["base", "details", "shimmer"]:
		material.set_shader_parameter("palette_" + key, Color.html(fish[key]))
	for key in ["markings", "saturation", "brightness", "shine", "shimmer_amount"]:
		material.set_shader_parameter("palette_" + key, fish[key])
