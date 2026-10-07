shader_type spatial;
render_mode cull_disabled;

uniform vec4 tint : source_color = vec4(1.0);
uniform float grain = 0.0;
varying vec3 surface_position;

float hash(vec3 p) { return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453); }
float noise(vec3 p) {
	vec3 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
	return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z);
}
void vertex() { surface_position=VERTEX; }
void fragment() {
	vec3 p=surface_position;
	float broad=noise(p*2.2);
	float detail=noise(p*15.0);
	float wear=.86+broad*.20+detail*.055;
	if(grain>.5 && grain<1.5) {
		float wood=sin(p.y*42.0+noise(vec3(p.x*2.0,p.y*.6,p.z*2.0))*8.0);
		wear*=.92+wood*.05;
	}
	if(grain>1.5) { wear*=.96+noise(p*48.0)*.07; }
	ALBEDO=tint.rgb*COLOR.rgb*wear;
	ROUGHNESS=.91;
}
