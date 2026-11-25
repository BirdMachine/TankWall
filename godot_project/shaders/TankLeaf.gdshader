shader_type spatial;
render_mode cull_disabled;
void vertex() {
	VERTEX.x += sin(TIME * 0.7 + VERTEX.y * 1.7) * 0.035 * VERTEX.y;
}
void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.5;
	SPECULAR = 0.35;
}
