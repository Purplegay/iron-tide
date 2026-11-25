// Four local taps keep lights attached to the same baked pose and direction.
// No secondary viewport, light nodes, particles or full-screen bloom pass.
vec3 mechanical_emission(vec4 pixel, bool red_lamps) {
	float warm=smoothstep(.80,.96,pixel.r)*smoothstep(.18,.29,pixel.g)*(1.0-smoothstep(.22,.40,pixel.b));
	float cold=smoothstep(.76,.95,pixel.b)*smoothstep(.5,.68,pixel.g)*(1.0-smoothstep(.35,.5,pixel.r));
	return pixel.a*(warm*(red_lamps ? vec3(1.,.18,.05) : vec3(1.,.57,.15))+cold*vec3(.18,.65,1.));
}
// Sample built-in TEXTURE in fragment(); forwarding its sampler through a
// function argument fails the headless shader compiler's custom-sampler lookup.
vec4 mechanical_halo(vec4 sample_right, vec4 sample_left, vec4 sample_down, vec4 sample_up, vec4 color, float strength, float opacity, bool red_lamps) {
	vec3 glow=mechanical_emission(sample_right,red_lamps)
		+mechanical_emission(sample_left,red_lamps)
		+mechanical_emission(sample_down,red_lamps)
		+mechanical_emission(sample_up,red_lamps);
	float energy=max(max(glow.r,glow.g),glow.b);
	float outer=min(.45,energy*.19*strength)*opacity;
	float alpha=max(color.a,outer);
	color.rgb+=glow*.14*strength;
	color.rgb=(color.rgb*color.a+glow/max(.001,energy)*outer*(1.-color.a))/max(.001,alpha);
	color.a=alpha;
	return color;
}
