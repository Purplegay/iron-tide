shader_type canvas_item;
render_mode unshaded, blend_add;
varying vec4 vertex_tint;
void vertex() { vertex_tint = COLOR; }
void fragment() {
	// FireScroll3 has one video frame. Native additive blend uses RGB, not alpha.
	COLOR = vec4(texture(TEXTURE, UV).rgb * vertex_tint.rgb, 1.0);
}
