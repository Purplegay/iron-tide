shader_type canvas_item;

uniform bool sold_out = false;

void fragment() {
	float grey = dot(COLOR.rgb, vec3(0.299, 0.587, 0.114));
	COLOR.rgb = sold_out ? vec3(grey * 0.68) : mix(vec3(grey), COLOR.rgb, 0.25) * vec3(0.82, 0.65, 0.62);
}
