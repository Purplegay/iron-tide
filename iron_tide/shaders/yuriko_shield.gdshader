shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never;
uniform sampler2D fractal : source_color, repeat_enable;
void fragment() {
	float noise = texture(fractal, UV + vec2(0.04, -0.09) * TIME).r;
	float rim = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 1.8);
	ALBEDO = vec3(0.24, 0.43, 1.0);
	ALPHA = clamp(0.08 + noise * 0.26 + rim * 0.63, 0.0, 1.0);
}
