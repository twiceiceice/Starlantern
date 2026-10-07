shader_type spatial;
render_mode cull_disabled;

void vertex() {
	float phase = TIME * 1.6 + MODEL_MATRIX[3].x * 0.27 + MODEL_MATRIX[3].z * 0.16;
	VERTEX.x += sin(phase) * VERTEX.y * VERTEX.y * 0.25;
	VERTEX.z += cos(phase * 0.8) * VERTEX.y * 0.12;
}

void fragment() {
	ALBEDO = pow(COLOR.rgb,vec3(1.7));
	ROUGHNESS = 0.95;
}
