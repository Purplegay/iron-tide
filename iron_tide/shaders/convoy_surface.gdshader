shader_type canvas_item;
uniform vec4 house_color : source_color = vec4(.25,.54,.9,1.);
uniform vec2 atlas_texel;
uniform float optic_power=1.0;
uniform float barrel_heat=0.0;
void fragment(){
	vec4 c=COLOR;
	if(distance(TEXTURE_PIXEL_SIZE,atlas_texel)<.000001){
		float peak=max(.001,max(c.r,max(c.g,c.b)));
		vec3 hue=c.rgb/peak;
		float paint=smoothstep(.48,.72,hue.r-hue.g)*(1.-smoothstep(.035,.13,abs(hue.g-hue.b)));
		float cyan=smoothstep(.28,.44,hue.g-hue.r)*smoothstep(.75,.91,hue.b)*smoothstep(.56,.87,peak);
		float amber=smoothstep(.22,.35,hue.r-hue.b)*smoothstep(.51,.65,hue.g)*smoothstep(.68,.91,peak);
		c.rgb=mix(c.rgb,house_color.rgb*(.13+.88*peak),paint);
		c.rgb+=cyan*vec3(.14,.48,.60)*(optic_power-.55);
		c.rgb+=amber*vec3(.36,.15,.025)*(barrel_heat+max(0.,optic_power-.75));
	}
	COLOR=c;
}
