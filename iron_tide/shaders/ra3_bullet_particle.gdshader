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
	// CommonParticle.fxh video-texture interpolation; native additive RGB path.
	vec4 texel = mix(texture(TEXTURE,cell(frame,UV)),texture(TEXTURE,cell(frame+1.0,UV)),fract(frame));
	COLOR = vec4(texel.rgb*vertex_tint.rgb,1.0);
}
