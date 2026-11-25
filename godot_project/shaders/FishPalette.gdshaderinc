// Preserve the source's UV detail and ray/scale shading. Warm source markings
// form the second colour region; this is a recolour, not a new texture pattern.
uniform bool palette_enabled = false;
uniform vec4 palette_base : source_color = vec4(0.1, 0.5, 0.9, 1.0);
uniform vec4 palette_details : source_color = vec4(0.9, 0.1, 0.3, 1.0);
uniform vec4 palette_shimmer : source_color = vec4(0.6, 0.9, 1.0, 1.0);
uniform float palette_markings = 1.0;
uniform float palette_saturation = 1.0;
uniform float palette_brightness = 1.0;
uniform float palette_shine = 0.6;
uniform float palette_shimmer_amount = 0.0;
vec3 fish_colour(vec3 source) {
	vec3 colour = source;
	if (palette_enabled) {
		float warm_mask = smoothstep(-0.04, 0.18, source.r - max(source.g, source.b));
		vec3 target = mix(palette_base.rgb, palette_details.rgb, warm_mask * palette_markings);
		float value = max(source.r, max(source.g, source.b));
		colour = target * (0.12 + 0.88 * sqrt(value));
	}
	float grey = dot(colour, vec3(0.2126, 0.7152, 0.0722));
	return max(mix(vec3(grey), colour, palette_saturation), vec3(0.0)) * palette_brightness;
}
float fish_roughness(float original) {
	return clamp(original * mix(1.9, 0.4, palette_shine), 0.06, 1.0);
}
vec3 fish_shimmer(float facing) {
	return palette_shimmer.rgb * palette_shimmer_amount * 0.22 * pow(1.0 - clamp(facing, 0.0, 1.0), 3.0);
}
