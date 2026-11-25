shader_type canvas_item;
render_mode unshaded, blend_disabled;

uniform sampler2D battlefield : hint_screen_texture, repeat_disable, filter_nearest;
uniform vec2 sample_dir;
uniform int intensity;

void fragment() {
	// gamemd 75EDF0, radial/sine tables 75F020 and offset table 75F140.
	float radius = floor(length(floor(abs(UV))));
	float index = abs(trunc(12.0 * sin((radius + float(intensity)) * 0.125) + 0.49));
	float offset = step(2.0, index) + step(7.0, index) + step(10.0, index);
	vec2 native_per_pixel = max(vec2(abs(dFdx(UV.x)), abs(dFdy(UV.y))), vec2(0.0001));
	vec3 src = texture(battlefield, SCREEN_UV + sample_dir * offset * SCREEN_PIXEL_SIZE / native_per_pixel).rgb;
	// Original RGB565 unpack, amplify green and blue, then repack.
	vec3 levels = vec3(31.0, 63.0, 31.0);
	vec3 stride = vec3(8.0, 4.0, 8.0);
	vec3 rgb = floor(src * levels + 0.5) * stride;
	rgb.gb += floor(rgb.gb * (110.0 + 8.0 * index) / 256.0);
	COLOR = vec4(floor(min(rgb, vec3(255.0)) / stride) / levels, 1.0);
}
