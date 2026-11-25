shader_type canvas_item;
// ObjectsPsyonic uses a fourth-power Fresnel term with RGB (2,2,10).
// The battlefield atlas supplies alpha coverage in place of tangent-space normals.
void fragment() {
	vec4 base = COLOR;
	vec2 step_uv = TEXTURE_PIXEL_SIZE * 2.0;
	vec2 slope = vec2(texture(TEXTURE, UV + vec2(step_uv.x,0.0)).a - texture(TEXTURE, UV - vec2(step_uv.x,0.0)).a,
		texture(TEXTURE, UV + vec2(0.0,step_uv.y)).a - texture(TEXTURE, UV - vec2(0.0,step_uv.y)).a);
	float rim = pow(clamp(length(slope),0.0,1.0),4.0);
	COLOR = vec4(base.rgb + vec3(2.0,2.0,10.0)*rim*0.65,base.a);
}
