shader_type spatial;
render_mode unshaded, cull_disabled;
// Uprising Objects.fxh: formation rim is proportional to (1 - N.V)^2.5.
void fragment() {
	float rim = pow(1.0-clamp(dot(normalize(NORMAL),normalize(VIEW)),0.0,1.0),2.5);
	ALBEDO = vec3(clamp(0.10+3.0*rim,0.0,1.0));
}
