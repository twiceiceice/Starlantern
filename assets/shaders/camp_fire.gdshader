shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

void fragment() {
	float h = 1.0 - UV.y;
	float sway = sin(TIME * 3.4 + h * 7.0) * .05 + sin(TIME * 5.2 - h * 9.0) * .03;
	float x = abs(UV.x - .5 - sway * h);
	float tongues = .035 * sin(UV.x * 29.0 + TIME * 4.0) + .02 * sin(UV.x * 53.0 - TIME * 5.0);
	float width = .35 * pow(max(0.0, 1.0 - h), 1.55) + tongues * h;
	float mask = (1.0 - smoothstep(width - .03, width + .01, x)) * smoothstep(0.0, .1, h) * (1.0 - smoothstep(.80, .98, h));
	ALBEDO = mix(vec3(1.0,.76,.24),vec3(.83,.17,.035),h);
	EMISSION = ALBEDO * .65;
	ALPHA = mask * .80;
}
