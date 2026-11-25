shader_type canvas_item;

// Paint only the occupied sprite pixels. Keep their highlight and panel relief.
void fragment() {
	vec4 body = texture(TEXTURE, UV);
	float steel = dot(body.rgb, vec3(0.30, 0.59, 0.11));
	COLOR = vec4(mix(vec3(0.48, 0.70, 0.86), vec3(1.0), steel), COLOR.a);
}
