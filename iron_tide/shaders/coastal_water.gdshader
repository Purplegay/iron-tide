shader_type canvas_item;
render_mode unshaded;

uniform vec2 half_size;
uniform sampler2D sand : source_color, repeat_enable, filter_linear_mipmap;
varying vec2 local_point;
varying vec2 map_point;

void vertex() {
	local_point = VERTEX;
	map_point = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}
void fragment() {
	vec2 p = map_point;
	float corner = min(7.0, min(half_size.x, half_size.y)*0.15);
	vec2 edge = abs(local_point) - half_size + corner;
	float inland = length(max(edge, vec2(0.0))) + min(max(edge.x,edge.y),0.0) - corner;
	// Keep the visual waterline close to the navigable edge, even at small ports.
	float shore = inland + 2.8*sin(p.x*0.069 + p.y*0.047) + 1.3*sin(p.y*0.11-p.x*0.043);
	float coast = 23.0 + 6.0*sin(p.x*0.031 + p.y*0.043);
	float alpha = 1.0 - smoothstep(7.0, coast, shore);
	float depth = smoothstep(0.0, min(88.0, min(half_size.x, half_size.y)*0.85), -shore);
	vec3 bed = texture(sand, p/145.0).rgb;
	vec3 beach = bed * mix(vec3(0.58,0.66,0.64), vec3(1.03,1.00,0.90), smoothstep(0.0,20.0,shore));

	float t = TIME;
	float swell = sin(dot(p,vec2(0.035,0.052)) - t*0.85);
	float warp = sin(dot(p,vec2(-0.024,0.013)) + 1.1*swell);
	float ripple = sin(dot(p,vec2(0.138,-0.071)) + 2.1*swell + 1.3*warp + t*1.15);
	float cross_wave = sin(dot(p,vec2(0.068,0.183)) + 1.7*ripple - t*1.37);
	float face = 0.55*ripple + 0.45*cross_wave;
	vec3 shallow = mix(bed*vec3(0.42,0.80,0.78), vec3(0.15,0.51,0.51), 0.56);
	vec3 water = mix(shallow, vec3(0.075,0.27,0.36), depth);
	float glint = smoothstep(0.85,1.0,face) * smoothstep(-0.4,0.9,warp);
	water += vec3(0.009,0.018,0.022)*face + vec3(0.055,0.078,0.082)*glint;
	// Discontinuous small breakers and light paths on the shallow bed.
	float caustic = pow(max(0.0, 1.0-abs(ripple + cross_wave)), 9.0);
	water += vec3(0.045,0.067,0.045)*caustic*(1.0-depth);
	float foam = (1.0-smoothstep(0.5,3.0,abs(shore+3.0+2.0*swell))) * smoothstep(-0.48,0.76,face+0.28*swell);
	water = mix(water,vec3(0.74,0.84,0.78),foam*0.38);
	COLOR = vec4(mix(water,beach,smoothstep(-6.0,2.0,shore)),alpha);
}
