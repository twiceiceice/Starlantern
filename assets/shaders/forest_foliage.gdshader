shader_type spatial;
render_mode cull_disabled;
uniform vec4 tint : source_color = vec4(.31,.40,.31,1.0);
varying float leaf_shade;
void vertex() {
	vec3 world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	float tip=clamp(VERTEX.y*.22,0.0,1.0);
	VERTEX.x+=sin(TIME*.85+world.x*.31+world.z*.2)*.065*tip;
	VERTEX.z+=cos(TIME*.67+world.z*.35)*.035*tip;
	leaf_shade=.87+.13*sin(VERTEX.x*5.7+VERTEX.z*4.1);
}
void fragment() {
	ALBEDO=tint.rgb*COLOR.rgb*leaf_shade;
	ROUGHNESS=.98;
}
