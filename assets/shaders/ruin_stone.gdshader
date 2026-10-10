shader_type spatial;
render_mode cull_disabled;

uniform vec4 tint : source_color = vec4(.49,.55,.53,1.0);
uniform float moss = .45;
varying vec3 local_point;
varying vec3 local_normal;

float hash(vec3 p) { return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453); }
float noise(vec3 p) {
	vec3 i=floor(p),f=fract(p); f=f*f*(3.0-2.0*f);
	return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z);
}
void vertex() { local_point=VERTEX; local_normal=NORMAL; }
void fragment() {
	float broad=noise(local_point*1.65);
	float grain=noise(local_point*19.0);
	float damp=smoothstep(.43,.73,broad)*(.28+.72*max(0.0,local_normal.y))*moss;
	vec3 rock=tint.rgb*COLOR.rgb*(.82+.22*broad+.07*grain);
	ALBEDO=mix(rock,vec3(.20,.29,.18)*(.76+grain*.26),damp);
	ROUGHNESS=.96;
}
