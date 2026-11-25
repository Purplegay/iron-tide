shader_type canvas_item;
render_mode unshaded;

// Native flare maps store luminance on black. Treat that channel as coverage
// so their soft edges also composite correctly on bright terrain.
varying vec4 tint;
void vertex() {
	tint = COLOR;
}
void fragment() {
	vec4 sample_color = texture(TEXTURE, UV);
	COLOR = vec4(tint.rgb, tint.a * sample_color.a * max(sample_color.r, max(sample_color.g, sample_color.b)));
}
