shader_type canvas_item;
render_mode unshaded;

uniform float age;
uniform float strength;
uniform vec2 origin;

float hash(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

float noise2(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(cell), hash(cell + vec2(1.0, 0.0)), f.x),
		mix(hash(cell + vec2(0.0, 1.0)), hash(cell + vec2(1.0)), f.x), f.y);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	vec2 seed = origin * 0.013;
	vec2 drift = vec2(-0.11, 0.065) * age;
	float curl = noise2(p * 3.4 + seed + drift);
	float mist = noise2(p * 7.0 + 2.5 * curl + seed - drift);
	float wisps = pow(1.0 - abs(2.0 * mist - 1.0), 4.0);
	float falloff = 1.0 - smoothstep(0.12, 1.0, r + 0.13 * (curl - 0.5));
	float edge = (1.0 - smoothstep(0.87, 1.0, r)) * falloff;
	// A short wave leaves the emitter on each dose, then breaks up into the haze.
	float front = age * 0.77;
	float band = (r - front + 0.045 * (mist - 0.5)) * 13.0;
	float wave = exp(-band * band);
	float core = exp(-8.0 * r) * (0.72 + 0.28 * sin(age * 4.0));
	vec2 grid = p * 13.0 + seed;
	vec2 cell = floor(grid);
	float spot = hash(cell + 4.0);
	vec2 speck = vec2(0.22 + spot * 0.56, 0.2 + 0.6 * fract(hash(cell) + age * 0.17));
	float motes = (1.0 - smoothstep(0.018, 0.080, distance(fract(grid), speck)))
		* smoothstep(0.74, 0.95, spot) * pow(0.5 + 0.5 * sin(4.0 * age + spot * 57.0), 2.0);
	float light = clamp(0.18 * curl + 0.36 * wisps + 0.55 * wave + core + motes, 0.0, 1.0);
	vec3 tint = mix(vec3(0.045, 0.52, 0.045), vec3(0.79, 1.0, 0.19), light);
	float alpha = edge * (0.12 + 0.27 * mist + 0.22 * wisps + 0.26 * wave + core * 0.47 + motes * 0.85);
	COLOR = vec4(tint, clamp(alpha, 0.0, 0.88) * strength);
}
