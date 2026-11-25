shader_type canvas_item;
render_mode unshaded;

uniform sampler2D grass : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D soil : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D gravel : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D grass_normal : repeat_enable, filter_linear_mipmap;
uniform sampler2D soil_normal : repeat_enable, filter_linear_mipmap;
uniform sampler2D gravel_normal : repeat_enable, filter_linear_mipmap;
varying vec2 ground_position;

float hash_cell(vec2 cell) {
	vec3 h = fract(vec3(cell.xyx) * 0.1031);
	h += dot(h, h.yzx + 33.33);
	return fract((h.x + h.y) * h.z);
}
float field(vec2 p) {
	vec2 c = floor(p);
	vec2 f = fract(p);
	f = f*f*(3.0-2.0*f);
	return mix(mix(hash_cell(c), hash_cell(c + vec2(1,0)), f.x),
		mix(hash_cell(c + vec2(0,1)), hash_cell(c + vec2(1,1)), f.x), f.y);
}
void vertex() {
	ground_position = VERTEX;
}
void fragment() {
	vec2 p = ground_position;
	float broad = field(p / 510.0 + vec2(5.4, 9.6));
	float detail = field(p / 105.0);
	float cover = 0.72*broad + 0.28*detail;
	float bare = smoothstep(0.42, 0.73, cover);
	float rocky = bare * smoothstep(0.49, 0.74, field(p / 270.0 + 12.3) + 0.13*(detail - 0.5));
	vec3 weights = vec3(1.0 - bare, bare - rocky, rocky);

	vec2 g = p / 192.0;
	vec2 s = p / 236.0 + vec2(0.27, 0.61);
	vec2 r = p / 152.0 + vec2(0.73, 0.16);
	vec3 albedo = weights.x*texture(grass,g).rgb + weights.y*texture(soil,s).rgb + weights.z*texture(gravel,r).rgb;
	vec3 n = normalize(2.0*(weights.x*texture(grass_normal,g).rgb + weights.y*texture(soil_normal,s).rgb + weights.z*texture(gravel_normal,r).rgb) - 1.0);
	float relief = clamp(dot(n,normalize(vec3(-0.49,-0.42,0.76))) - 0.76, -0.38, 0.25);
	COLOR = vec4(albedo * (1.08 + relief*0.72 + 0.10*(detail-0.5)), 1.0);
}
