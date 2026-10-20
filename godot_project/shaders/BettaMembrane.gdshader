shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float fin_clock = 0.0;
uniform float flow_speed = 0.5;
uniform float turn_drag = 0.0;

void vertex() {
	// Fine membrane waves between the original ray bones. Skinning supplies
	// the broad folds; this adds compliant free margins rather than a new
	// rigid fin transform. Mask is zero at the fleshy attachment.
	float mask = COLOR.r * COLOR.r;
	float rest_y = COLOR.b * 6.5 - 0.5;
	float rest_z = COLOR.g * 5.8 - 4.2;
	float deploy = clamp(0.87 - flow_speed * 0.28 - abs(turn_drag) * 0.18
		+ 0.20 * sin(fin_clock * 1.6 + COLOR.a * 2.0), 0.25, 1.0);
	float anchor_z = -0.38 * clamp(rest_y - 0.4, 0.0, 3.0);
	if (COLOR.a < 0.3) {
		anchor_z = -1.25;
	} else {
		anchor_z += rest_z > anchor_z ? 0.28 : -0.28;
	}
	// Long fins narrow by folding out of their rest plane. Rotating the radial
	// offset preserves its length, unlike scaling the sheet smaller. A varying
	// fold angle produces rounded lobes, rooted at the flesh.
	float fold_theta = 0.0;
	if (COLOR.a < 0.9) {
		float radial = rest_z - anchor_z;
		float curvature = (1.0 - deploy) * (0.43 + 0.08 * sin(rest_y * 0.6 - fin_clock * 0.7 + COLOR.a * 2.0));
		float fold_side = sin(fin_clock * 0.9 + COLOR.a * 3.0);
		if (curvature > 0.001) {
			fold_theta = radial * curvature;
			VERTEX.x += mask * fold_side * (1.0 - cos(fold_theta)) / curvature;
			VERTEX.z += mask * (sin(fold_theta) / curvature - radial);
		}
		fold_theta *= mask * fold_side;
		NORMAL = mat3(vec3(cos(fold_theta), 0.0, -sin(fold_theta)),
			vec3(0.0, 1.0, 0.0), vec3(sin(fold_theta), 0.0, cos(fold_theta))) * NORMAL;
	}
	float phase = fin_clock * 5.2 - VERTEX.y * 2.0 + VERTEX.z * 2.8 + COLOR.g * 1.8;
	float ripple = fin_clock * 8.3 - VERTEX.y * 4.4 - VERTEX.z * 4.0;
	float amplitude = 0.15 + 0.09 * clamp(flow_speed, 0.0, 1.5);
	float offset = amplitude * mask * (sin(phase) + 0.36 * sin(ripple));
	VERTEX.x += offset + turn_drag * 0.16 * mask;
	VERTEX.y += mask * 0.055 * sin(phase - 0.8);
	// Approximate shear Jacobian so lighting follows billows, not the flat
	// undeformed sheet. Bone skinning and standard surface lighting remain.
	float dy = amplitude * mask * (-2.0 * cos(phase) - 1.584 * cos(ripple));
	float dz = amplitude * mask * (2.8 * cos(phase) - 1.44 * cos(ripple));
	NORMAL = normalize(vec3(NORMAL.x, NORMAL.y - dy * NORMAL.x, NORMAL.z - dz * NORMAL.x));
}

void fragment() {
	vec4 tex = texture(albedo_texture, UV);
	ALBEDO = tex.rgb * tint.rgb;
	ALPHA = tex.a;
	METALLIC = 0.12;
	ROUGHNESS = 0.46;
}
