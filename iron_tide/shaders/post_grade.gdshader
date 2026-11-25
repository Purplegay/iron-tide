shader_type canvas_item;
// Iron Tide 战场后期（第 7 批）：统一光照感 + 色彩校正。只作用于世界层（layer 1），不影响 HUD。

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;

uniform float exposure_ev = 0.0;
uniform float saturation : hint_range(0.0, 2.0) = 1.16;
uniform float contrast : hint_range(0.5, 2.0) = 1.10;
uniform float lift : hint_range(-0.2, 0.2) = 0.030;
uniform float gamma_lift : hint_range(0.6, 1.2) = 0.90;
uniform float sun_strength : hint_range(0.0, 1.0) = 0.30;
uniform float vignette_strength : hint_range(0.0, 2.0) = 0.45;
uniform float grain : hint_range(0.0, 0.1) = 0.012;

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb * exp2(-exposure_ev / 2.2);

	// 饱和度
	float l = dot(c, vec3(0.2126, 0.7152, 0.0722));
	c = mix(vec3(l), c, saturation);

	// 对比 + 中间调提亮（避免整体发闷，拉开动态范围）
	c = (c - 0.5) * contrast + 0.5 + lift;
	c = pow(max(c, vec3(0.0)), vec3(gamma_lift));

	// 分色调：高光偏暖、暗部偏冷（模拟单一暖阳 + 冷环境光）
	float hi = smoothstep(0.40, 1.0, l);
	c += vec3(0.034, 0.020, -0.012) * hi;
	float lo = 1.0 - smoothstep(0.0, 0.42, l);
	c += vec3(-0.014, 0.002, 0.030) * lo;

	// 阳光方向渐变：左上亮、右下暗
	float g = clamp(1.0 - (SCREEN_UV.x * 0.55 + SCREEN_UV.y * 0.80), 0.0, 1.0);
	c += vec3(0.060, 0.056, 0.040) * g * sun_strength;

	// 暗角
	vec2 d = SCREEN_UV - vec2(0.5);
	float v = smoothstep(0.40, 0.98, length(d * vec2(1.02, 1.18)));
	c *= 1.0 - v * vignette_strength * 0.42;

	// 极轻颗粒，压掉渐变色带
	float n = fract(sin(dot(SCREEN_UV, vec2(12.9898, 78.233))) * 43758.5453);
	c += (n - 0.5) * grain;

	COLOR = vec4(clamp(c, vec3(0.0), vec3(1.0)), 1.0);
}
