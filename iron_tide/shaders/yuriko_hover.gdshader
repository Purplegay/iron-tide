shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;

uniform vec4 tint : source_color = vec4(0.51, 0.51, 0.98, 1.0);
uniform float age = 0.0;
uniform bool rising = false;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float breath = 0.9 + 0.1 * cos(age * 2.0 * PI / 3.0);
	float glow;
	float alpha;
	if (rising) {
		float height = 1.0 - UV.y;
		float turn = height * 5.5 - age * (2.0 * PI / 2.4);
		float radius = mix(0.58, 0.20, height);
		float taper = sin(height * PI);
		// The back of each turn fades, so the spiral reads without outlining a cone.
		float front = 0.5 + 0.5 * cos(turn);
		float offset = (p.x - radius * sin(turn)) / (0.08 + 0.10 * taper);
		float halo = exp(-0.55 * offset * offset);
		float core = exp(-4.0 * offset * offset);
		float echo = (p.x + radius * sin(turn)) / 0.15;
		float wake = exp(-echo * echo) * (1.0 - front);
		glow = 0.18 + 0.55 * core;
		alpha = taper * breath * (front * (0.60 * halo + 0.72 * core) + 0.42 * wake);
	} else {
		float radius = length(p);
		float phase = fract(age / 2.4);
		float wave = (radius - mix(0.20, 0.90, phase)) / 0.15;
		float ripple = exp(-wave * wave) * sin(PI * phase);
		float pool = exp(-3.8 * radius * radius);
		float edge = 1.0 - smoothstep(0.70, 1.0, radius);
		glow = 0.32 + 0.30 * ripple;
		alpha = (0.55 * pool + 0.38 * ripple) * edge * breath;
	}
	ALBEDO = mix(tint.rgb, vec3(0.88, 0.91, 1.0), glow);
	ALPHA = min(1.0, alpha);
}
