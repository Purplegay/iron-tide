shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform sampler2D fractal : repeat_enable;
uniform sampler2D displacement : repeat_enable;
uniform sampler2D falloff : repeat_disable;
uniform vec3 tint;
uniform vec4 uv_scroll;
uniform float noise_scale;
uniform float amplitude;
uniform float divergence;
uniform float speed;
uniform float emissive;
uniform float age;
uniform float opacity;
void fragment() {
	float a=radians(divergence);
	mat2 turn=mat2(vec2(cos(a),sin(a)),vec2(-sin(a),cos(a)));
	vec2 drift=vec2(speed*age*.01,0.0);
	vec2 n=UV*noise_scale;
	vec2 delta=(texture(displacement,turn*n+drift).rg+texture(displacement,transpose(turn)*n+drift).rg-1.0)*amplitude;
	vec2 scroll=uv_scroll.xy*age;
	vec3 diffuse=texture(fractal,UV+scroll+delta).rgb*texture(fractal,UV*uv_scroll.zw-scroll+delta).rgb;
	float edge=texture(falloff,vec2(1.0-abs(dot(normalize(NORMAL),normalize(VIEW))),1.0)).r;
	vec3 energy=pow(diffuse,vec3(2.2))*tint*COLOR.rgb*COLOR.a*(emissive*edge*opacity);
	float coverage=clamp(max(energy.r,max(energy.g,energy.b)),0.0,1.0);
	ALBEDO=energy/max(coverage,0.0001);
	ALPHA=coverage;
}
