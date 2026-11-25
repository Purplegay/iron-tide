shader_type canvas_item;
render_mode unshaded;
// Sprite art has baked lighting. Preserve the shaded interior and brighten silhouette pixels.
void fragment() {
	vec4 texel = texture(TEXTURE, UV);
	vec2 px = TEXTURE_PIXEL_SIZE;
	float near_alpha = min(min(texture(TEXTURE, UV+vec2(px.x,0.)).a, texture(TEXTURE, UV-vec2(px.x,0.)).a),
	                       min(texture(TEXTURE, UV+vec2(0.,px.y)).a, texture(TEXTURE, UV-vec2(0.,px.y)).a));
	float shade = dot(COLOR.rgb, vec3(0.25,0.55,0.20));
	float green = clamp(0.23+0.79*shade+0.48*(texel.a-near_alpha),0.0,1.0);
	COLOR = vec4(0.035*green,green,0.075+0.18*green,COLOR.a*0.74);
}
