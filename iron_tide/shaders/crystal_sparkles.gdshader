shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, skip_vertex_transform;

uniform float phase = 0.0;

uniform vec3 rim[5];
uniform vec3 tip;
uniform vec3 base;
varying vec2 screen_rim[5];
varying vec2 screen_tip;
varying vec2 screen_base;

float edge_distance(vec2 p, vec2 a, vec2 b) {
	vec2 edge = b-a;
	float t = clamp(dot(p-a,edge)/max(dot(edge,edge),0.000001),0.0,1.0);
	return length(p-a-t*edge);
}

void vertex() {
	// Face the camera, retaining the hull mount's scale and depth.
	vec3 center = MODELVIEW_MATRIX[3].xyz;
	float scale = length(MODEL_MATRIX[0].xyz);
	mat3 rotation = mat3(MODELVIEW_MATRIX) / scale;
	screen_tip = (rotation * tip).xy;
	screen_base = (rotation * base).xy;
	for (int i=0; i<5; i++) {
		screen_rim[i] = (rotation * rim[i]).xy;
	}
	VERTEX = center + vec3(VERTEX.xy * scale, 0.0);
}

void fragment() {
	vec2 p = UV - 0.5;
	p.y = -p.y;
	float t = TIME + phase;
	float pulse = 0.5 + 0.5 * sin(t * 2.7);
	float glow = exp(-dot(p,p) * 120.0) * (0.16 + 0.12 * pulse);
	float glint = pow(max(0.0, sin(t * 2.7)), 8.0);
	vec2 a = abs(p);
	float star = max(exp(-a.x*280.0-a.y*15.0), exp(-a.y*300.0-a.x*22.0)) * glint;
	vec3 light = vec3(0.12,0.82,1.0) * glow + vec3(0.9,1.0,1.0) * star;
	float opacity = glow + star;

	// Follow the projected facet edges so the light stays on the jewel at any mount pitch.
	float nearest = 1.0;
	for (int i=0; i<5; i++) {
		vec2 v = screen_rim[i];
		nearest = min(nearest,edge_distance(p,v,screen_rim[(i+1)%5]));
		nearest = min(nearest,edge_distance(p,v,screen_tip));
		nearest = min(nearest,edge_distance(p,v,screen_base));
	}
	float rim_light = 0.75 * exp(-nearest*115.0);
	float halo = 0.52 * exp(-nearest*nearest*265.0);
	float fade = 1.0-smoothstep(0.12,0.18,nearest);
	light += fade * (vec3(0.68,0.97,1.0)*rim_light + vec3(0.12,0.62,1.0)*halo);
	opacity += fade * (rim_light+halo);

	for (int i=0; i<5; i++) {
		float id = float(i);
		float age = fract(t * (0.47 + id * 0.023) + id * 0.618);
		float angle = id * 2.4 + age * 0.75;
		vec2 pos = vec2(cos(angle)*(0.07+0.25*age), 0.01+0.32*age+sin(angle)*0.06);
		vec2 d = p - pos;
		float life = sin(age*3.14159);
		float width = (0.018+0.007*cos(angle+t*3.0))*life + 0.001;
		float edge = abs(d.x)/width + abs(d.y)/(0.038*life+0.001);
		float shard = (1.0-smoothstep(0.72,1.1,edge))*life;
		vec3 facet = mix(vec3(0.27,0.70,1.0), vec3(0.9,1.0,1.0), step(d.x,0.0));
		light += facet*shard;
		opacity += shard;
	}
	ALBEDO = light / max(0.001,opacity);
	ALPHA = min(opacity,1.0);
}
