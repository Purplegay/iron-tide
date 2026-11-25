shader_type canvas_item;
render_mode unshaded, blend_add;
uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform float seconds;
uniform vec3 tint;
uniform vec4 uv_scroll;
uniform vec4 displace;
void fragment() {
	vec2 p = UV * displace.x;
	float angle = radians(displace.z);
	mat2 rot = mat2(vec2(cos(angle), sin(angle)), vec2(-sin(angle), cos(angle)));
	vec2 drift = vec2(displace.y * 0.01 * seconds, 0.0);
	vec2 offset = texture(noise_tex, rot * p + drift).rg + texture(noise_tex, transpose(rot) * p + drift).rg - 1.0;
	vec2 uv = UV * uv_scroll.zw + fract(uv_scroll.xy * seconds) + offset * displace.w;
	vec3 tex = texture(TEXTURE, fract(uv)).rgb;
	COLOR = vec4(tex * tint, 1.0);
}
