shader_type spatial;
render_mode unshaded;
uniform sampler2D atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform float ice = 0.0;
uniform float contact = 0.0;
uniform vec4 house_color : source_color = vec4(0.341176, 0.658824, 1.0, 1.0);
varying vec3 point;
varying vec3 face;
void vertex(){
	point=VERTEX;
	face=NORMAL;
}
void fragment(){
	vec2 atlas_uv;
	bool glass=face.y>0.95;
	if (glass) {
		atlas_uv=vec2(0.75,0.25)+point.zx*(0.245/0.056);
	} else if (face.y< -0.95) {
		atlas_uv=vec2(0.75,0.75)+point.zx*(0.244/0.072);
	} else {
		float axial=clamp(point.y/0.188+0.5,0.0,1.0);
		float around=atan(point.z,point.x)/6.283185+0.5;
		atlas_uv=vec2(0.008+axial*0.484,0.25+clamp(point.x/0.07,-1.0,1.0)*0.24);
		if(axial<0.27) atlas_uv=vec2(0.012+around*0.476,0.51+axial*1.74);
	}
	vec3 base=texture(atlas,atlas_uv).rgb;
	float facing=max(dot(normalize(NORMAL),normalize(vec3(-0.35,0.65,0.72))),0.0);
	if(!glass) base*=mix(vec3(0.84,0.90,0.96),vec3(0.49,0.90,0.98),ice);
	// The central armour sleeve carries IFF paint. Keep the glass, rear cap,
	// collars and atlas relief intact; ownership never enters this material.
	float axial=clamp(point.y/0.188+0.5,0.0,1.0);
	float sleeve=smoothstep(0.28,0.33,axial)*(1.0-smoothstep(0.78,0.83,axial));
	if(!glass && face.y>=-0.95) {
		float relief=dot(base,vec3(0.299,0.587,0.114));
		base=mix(base,house_color.rgb*(0.35+0.95*relief),sleeve*0.90);
	}
	ALBEDO=base*(0.72+0.40*facing);
	if(glass){
		float fresnel=pow(1.0-abs(dot(normalize(NORMAL),VIEW)),2.0);
		ALBEDO+=vec3(0.05,0.18,0.20)*fresnel;
	}
	// An illuminated collar reads from the rear as well as from the lens face.
	float collar=1.0-smoothstep(0.001,0.008,abs(point.y-0.069));
	float lit=contact*(glass ? 1.0 : collar);
	ALBEDO=mix(ALBEDO,vec3(0.36,1.0,0.96),lit*0.88);
	EMISSION=vec3(0.15,0.88,0.95)*lit;
}
