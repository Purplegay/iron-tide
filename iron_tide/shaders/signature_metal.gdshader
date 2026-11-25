shader_type spatial;
render_mode unshaded;
uniform vec4 enamel : source_color;
uniform float lamp = 0.0;
void fragment() {
	vec3 n = normalize(NORMAL);
	float relief = clamp(dot(n, normalize(vec3(-0.45, 0.75, 0.5))), 0.0, 1.0);
	float rim = pow(1.0 - abs(dot(n, VIEW)), 3.0);
	ALBEDO = enamel.rgb * mix(0.38 + 0.68 * relief, 1.18, lamp) + vec3(0.16, 0.22, 0.25) * rim;
}
