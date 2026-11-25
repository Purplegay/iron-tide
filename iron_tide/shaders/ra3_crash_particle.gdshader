shader_type canvas_item;
render_mode unshaded, blend_add;
uniform float frame = 0.0;
uniform float columns = 1.0;
uniform float frames = 1.0;
varying vec4 vertex_tint;
void vertex() { vertex_tint = COLOR; }
vec2 cell(float f, vec2 uv) {
	f = floor(mod(f, frames));
	return (vec2(mod(f, columns), floor(f / columns)) + uv) / columns;
}
void fragment() {
	vec3 rgb = mix(texture(TEXTURE, cell(frame, UV)).rgb, texture(TEXTURE, cell(frame + 1.0, UV)).rgb, fract(frame));
	COLOR = vec4(rgb * vertex_tint.rgb, vertex_tint.a);
}
