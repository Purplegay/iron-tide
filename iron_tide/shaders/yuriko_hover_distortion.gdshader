shader_type canvas_item;
render_mode unshaded;
uniform sampler2D terrain : hint_screen_texture, repeat_disable, filter_linear;
uniform sampler2D normal_map : repeat_enable, filter_linear;
uniform sampler2D haze : repeat_disable, filter_linear;
uniform float clock = 0.0;
void fragment() {
	vec2 p = UV*2.0-1.0;
	float mask = clamp(1.0-dot(p,p),0.0,1.0);
	vec2 warp=vec2(0.0);
	for(int i=0;i<3;i++){
		float phase=fract(clock*(1.50+0.15*float(i))+float(i)/3.0);
		vec2 pos=p-vec2(cos(float(i)*2.1),sin(float(i)*2.1))*(0.18+phase*0.3);
		vec2 uv=pos*(0.7-0.2*phase)+0.5;
		float opacity=texture(haze,clamp(uv,vec2(0.0),vec2(1.0))).a*(1.0-abs(phase*2.0-1.0));
		warp+=(texture(normal_map,uv).rg*2.0-1.0)*opacity;
	}
	COLOR=vec4(texture(terrain,SCREEN_UV+warp*mask*SCREEN_PIXEL_SIZE*2.0).rgb,mask*0.65);
}
