shader_type canvas_item;
uniform float resting = 0.0;
uniform float sparkle = 0.0;
void fragment() {
	vec2 uv = UV;
	vec3 deep = mix(vec3(0.012, 0.055, 0.11), vec3(0.008, 0.012, 0.045), resting);
	vec3 aqua = mix(vec3(0.045, 0.25, 0.28), vec3(0.025, 0.05, 0.13), resting);
	float glow = exp(-length((uv - vec2(0.55, 0.30)) * vec2(1.3, 1.0)) * 2.5);
	vec3 water = mix(deep, aqua, glow);
	float rays = pow(max(0.0, sin(uv.x * 15.0 + uv.y * 4.0 + TIME * 0.08)), 16.0);
	water += vec3(0.04, 0.13, 0.12) * rays * (1.0 - uv.y) * (1.0 - resting);
	for (int i = 0; i < 13; i++) {
		float fi = float(i);
		vec2 p = vec2(fract(sin(fi * 12.98) * 43758.5), 1.0 - fract(TIME * (0.008 + fi * 0.0004) + fi * 0.071));
		float radius = 0.002 + mod(fi, 3.0) * 0.001;
		float dot_glow = exp(-length((uv - p) * vec2(0.5, 1.0)) / radius * 2.0);
		water += vec3(0.2, 0.6, 0.6) * dot_glow * (0.4 + sparkle);
	}
	COLOR = vec4(water, 1.0);
}
