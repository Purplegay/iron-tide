shader_type canvas_item;
render_mode unshaded, blend_disabled;

uniform sampler2D scene : hint_screen_texture, repeat_disable, filter_nearest;
uniform float intensity = 100.0;

void fragment() {
	// WaveClass pixel phase: sqrt((x-y)^2+y^2) + intensity, relative to the wave origin.
	vec2 p = floor(UV);
	vec2 radial = vec2(p.x - p.y, p.y);
	float ripple = sin((floor(length(radial)) + intensity) * 0.1) * 12.0;
	float band = min(abs(trunc(ripple + 0.49)), 9.0);
	// Convert the native small framebuffer displacement to the current zoom and resolution.
	float zoom = 1.0 / max(abs(dFdy(UV.y)), 0.0001);
	vec2 shift = vec2(sign(ripple), -1.0) * band * (zoom / 3.0) * SCREEN_PIXEL_SIZE;
	vec3 sample_color = texture(scene, SCREEN_UV + shift).rgb;
	// 7601FB: multiply red and blue by separate gains; green is untouched.
	float gain = 110.0 + band * 8.0;
	COLOR = vec4(min(sample_color * vec3(1.0 + floor(gain * 0.5) / 256.0, 1.0, 1.0 + gain / 64.0), vec3(1.0)), 1.0);
}
