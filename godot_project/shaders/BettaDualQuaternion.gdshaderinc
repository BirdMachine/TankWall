// Rigid-transform blending keeps a curved cross-section from being averaged
// into a flattened plane. Bone data is uploaded after the swim modifier runs.
uniform vec4 skin_real[53];
uniform vec4 skin_dual[53];

vec3 quat_rotate(vec4 q, vec3 v) {
	return v + 2.0 * cross(q.xyz, cross(q.xyz, v) + q.w * v);
}

void skin_volume(inout vec3 p, inout vec3 n, inout vec3 t, inout vec3 b,
	vec4 joints, vec4 weights) {
	vec4 reference = skin_real[int(joints.x)];
	vec4 real_q = vec4(0.0);
	vec4 dual_q = vec4(0.0);
	for (int i = 0; i < 4; i++) {
		int bone = int(joints[i]);
		float weight = weights[i] * (dot(reference, skin_real[bone]) < 0.0 ? -1.0 : 1.0);
		real_q += skin_real[bone] * weight;
		dual_q += skin_dual[bone] * weight;
	}
	float magnitude = max(length(real_q), 0.00001);
	real_q /= magnitude;
	dual_q /= magnitude;
	dual_q -= real_q * dot(real_q, dual_q);
	vec3 translation = 2.0 * (real_q.w * dual_q.xyz - dual_q.w * real_q.xyz
		+ cross(real_q.xyz, dual_q.xyz));
	p = quat_rotate(real_q, p) + translation;
	n = quat_rotate(real_q, n);
	t = quat_rotate(real_q, t);
	b = quat_rotate(real_q, b);
}
