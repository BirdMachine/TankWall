shader_type spatial;
render_mode cull_disabled;
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap_anisotropic;
uniform bool use_normal_map = false;
uniform vec4 tint : source_color = vec4(1.0);
uniform float normal_depth = 0.16;
uniform float surface_roughness = 0.28;
uniform float wet_style = 0.6;
uniform float bend_yaw = 0.0;
uniform float bend_pitch = 0.0;
uniform vec3 head_pivot = vec3(0.0, 0.0, 3.4);
vec3 bend_rotate(vec3 value, vec3 axis, float angle) {
	return value * cos(angle) + cross(axis, value) * sin(angle) + axis * dot(axis, value) * (1.0 - cos(angle));
}
void vertex() {
	// Bend the animated, normalized fish as a tube: each cross-section rotates
	// with its centreline, preserving thickness through a turn in either plane.
	float curvature = length(vec2(bend_yaw, bend_pitch));
	if (curvature > 0.0001) {
		vec3 relative = VERTEX - head_pivot;
		float distance = -relative.z;
		float angle = curvature * distance;
		vec3 lateral = vec3(bend_yaw, bend_pitch, 0.0) / curvature;
		vec3 axis = vec3(bend_pitch, -bend_yaw, 0.0) / curvature;
		vec3 centre = head_pivot + lateral * (1.0 - cos(angle)) / curvature + vec3(0.0, 0.0, -sin(angle) / curvature);
		VERTEX = centre + bend_rotate(vec3(relative.xy, 0.0), axis, angle);
		NORMAL = bend_rotate(NORMAL, axis, angle);
		TANGENT = bend_rotate(TANGENT, axis, angle);
		BINORMAL = bend_rotate(BINORMAL, axis, angle);
	}
}
void fragment() {
	ALBEDO = texture(albedo_texture, UV).rgb * tint.rgb;
	ROUGHNESS = surface_roughness;
	METALLIC = 0.06;
	SPECULAR = 0.55;
	CLEARCOAT = wet_style;
	if (use_normal_map) {
		NORMAL_MAP = texture(normal_texture, UV).rgb;
		NORMAL_MAP_DEPTH = normal_depth;
	}
}
