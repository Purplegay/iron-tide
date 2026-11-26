shader_type canvas_item;
render_mode unshaded;

// 0：无信号，1：原片预览，2：百合子头像。
uniform int screen_type = 0;
uniform vec2 snow_offset = vec2(0.0);

float inside_rect(vec2 p, vec2 a, vec2 b) {
	vec2 under = step(a, p);
	vec2 over = step(p, b);
	return under.x * under.y * over.x * over.y;
}

void fragment() {
	vec2 uv = UV;
	if (screen_type == 2) {
		vec4 art = texture(TEXTURE, uv);
		float r = length(uv - vec2(0.5));
		float mask = 1.0 - smoothstep(0.47, 0.50, r);
		float ring = smoothstep(0.445, 0.478, r);
		COLOR = vec4(mix(art.rgb, vec3(0.47, 0.55, 0.63), ring), mask * mix(art.a, 1.0, ring));
	} else {
		vec2 pixel = uv * vec2(304.0, 171.0);
		vec2 edge = min(pixel, vec2(304.0, 171.0) - pixel);
		float radius = length(max(vec2(7.0) - edge, vec2(0.0)));
		float mask = 1.0 - smoothstep(6.6, 7.3, radius);
		vec3 rgb;
		if (screen_type == 0) {
			// 同一张样稿雪花，错开各卡片的采样位置。
			vec2 read_at = (pixel + snow_offset) / vec2(342.0, 203.0);
			rgb = texture(TEXTURE, read_at).rgb;
			float r = length((uv - vec2(0.5)) * 2.0);
			rgb = mix(rgb, vec3(0.14, 0.18, 0.22), mix(0.08, 0.34, min(r / 0.68, 1.0)));
			rgb = mix(rgb, vec3(0.031, 0.039, 0.059), smoothstep(0.32, 0.47, r) * smoothstep(0.68, 1.12, r) * 0.91);
			rgb = mix(rgb, vec3(0.067, 0.078, 0.102), step(3.0, mod(pixel.y, 4.0)) * 0.28);
		} else {
			float ratio = (TEXTURE_PIXEL_SIZE.y / TEXTURE_PIXEL_SIZE.x) / (304.0 / 171.0);
			vec2 crop = vec2(min(1.0, 1.0 / ratio), min(1.0, ratio));
			rgb = texture(TEXTURE, (uv - 0.5) * crop + 0.5).rgb;
			float shade = uv.y < 0.5 ? (1.0 - 2.0 * uv.y) * 0.18 : (2.0 * uv.y - 1.0) * 0.4;
			rgb = mix(rgb, vec3(0.067, 0.063, 0.094), shade);
		}
		float corners = max(inside_rect(edge, vec2(10.5, 12.0), vec2(11.5, 24.0)),
			inside_rect(edge, vec2(11.0, 11.5), vec2(23.0, 12.5)));
		COLOR = vec4(mix(rgb, vec3(0.949, 0.929, 0.941), corners * 0.49), mask);
	}
}
