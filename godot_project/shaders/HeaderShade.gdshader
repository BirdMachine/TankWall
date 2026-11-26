shader_type canvas_item;
render_mode unshaded;
uniform vec4 ink : source_color = vec4(0.035, 0.075, 0.09, 1.0);
uniform bool landscape = false;
void fragment() {
	float fade = 1.0 - smoothstep(0.60, 1.0, UV.y);
	if (landscape) {
		fade *= 1.0 - smoothstep(0.74, 1.0, UV.x);
	}
	COLOR = vec4(ink.rgb, fade * 0.97);
}
