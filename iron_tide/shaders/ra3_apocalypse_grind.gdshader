shader_type canvas_item;
render_mode unshaded, blend_add;
uniform float age;
uniform float duration;
uniform float life;
uniform int burst_count;
uniform float trail_life;
uniform vec4 start_color : source_color;
uniform vec4 end_color : source_color;
uniform float heading;
uniform float variation;

// Sov_Apoc_TB_Grind.xml: cylinder radius 5 at x=-30, Ortho velocity,
// damping 0.5..1, gravity -1, spark width 0.5..1 in SAGE coordinates.
float random_value(float seed) {
	return fract(sin(mod(seed, 731.0) * 12.9898 + variation) * 43758.5453);
}
vec2 project_point(vec3 p) {
	return vec2(p.x, p.z * 0.5 - p.y * 0.8660254) * 1.5;
}
vec2 rotate_ground(vec2 p) {
	float c = cos(heading), s = sin(heading);
	return vec2(c*p.x - s*p.y, s*p.x + c*p.y);
}
vec3 at_time(vec3 origin, vec3 velocity, float drag, float t) {
	float travel = (1.0 - pow(drag,t)) / (1.0-drag);
	return origin + travel * velocity + vec3(0.0,-0.5*t*t,0.0);
}
void vertex() {
	float burst = floor(age) - float(INSTANCE_ID / burst_count);
	float t = age - burst;
	if (burst < 0.0 || burst >= duration || t >= life) {
		VERTEX = vec2(0.0);
	} else {
		float seed = (burst * float(burst_count) + float(INSTANCE_ID % burst_count)) * 8.0;
		float a = random_value(seed) * TAU;
		vec2 disk = 5.0 * sqrt(random_value(seed+1.0)) * vec2(cos(a),sin(a));
		vec3 origin = vec3(0.0);
		origin.xz = rotate_ground(disk - vec2(30.0,0.0));
		vec3 v = vec3(0.0);
		v.xz = rotate_ground(10.0 * (vec2(random_value(seed+2.0),random_value(seed+3.0)) - 0.5));
		v.y = mix(5.0,30.0,random_value(seed+4.0));
		float drag = mix(0.5,0.9999,random_value(seed+5.0));
		vec2 head = project_point(at_time(origin,v,drag,t));
		vec2 tail = project_point(at_time(origin,v,drag,max(0.0,t-trail_life)));
		vec2 diff = head-tail;
		vec2 normal = vec2(-diff.y,diff.x) / max(0.001,length(diff));
		VERTEX = mix(tail,head,UV.x) + normal*(UV.y-0.5)*mix(0.75,1.5,random_value(seed+6.0));
		COLOR *= mix(start_color,end_color,t/life);
	}
}
