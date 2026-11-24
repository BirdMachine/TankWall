shader_type spatial;
render_mode cull_back;
#include "res://shaders/BettaDualQuaternion.gdshaderinc"

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap;
uniform sampler2D surface_texture : filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(1.0);
uniform bool use_normal_map = false;
uniform bool use_surface_map = false;
uniform float normal_depth = 1.0;
uniform float surface_roughness = 0.46;
uniform float surface_metallic = 0.12;
uniform float wet_style = 1.0;

void vertex() {
	skin_volume(VERTEX, NORMAL, TANGENT, BINORMAL, CUSTOM1, CUSTOM0);
}

void fragment() {
	ALBEDO = texture(albedo_texture, UV).rgb * tint.rgb;
	ROUGHNESS = surface_roughness;
	METALLIC = surface_metallic;
	if (use_surface_map) {
		vec3 surface = texture(surface_texture, UV).rgb;
		ROUGHNESS *= surface.g;
		METALLIC *= surface.b;
	}
	// Retain scale colour/texture while softening the coarse surface response.
	float polished = mix(0.26, clamp(ROUGHNESS * 0.65, 0.16, 0.40), 0.35);
	ROUGHNESS = mix(ROUGHNESS, polished, wet_style);
	CLEARCOAT = wet_style * 0.55;
	if (use_normal_map) {
		NORMAL_MAP = texture(normal_texture, UV).rgb;
		NORMAL_MAP_DEPTH = normal_depth;
	}
}
