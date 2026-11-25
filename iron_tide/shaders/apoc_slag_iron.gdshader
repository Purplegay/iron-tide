shader_type spatial;
render_mode unshaded;
uniform sampler2D forged : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform int part = 0;
uniform float heat = 0.0;
varying vec3 point;
varying vec3 face;
void vertex(){
	point=VERTEX;
	face=NORMAL;
}
void fragment(){
	vec2 tile;
	vec2 quadrant;
	float hot_seam=0.0;
	if(part==0){
		vec3 p=point/vec3(0.14,0.034,0.058)+0.5;
		tile=abs(face.y)>0.5?p.xz:(abs(face.z)>0.5?p.xy:p.zy);
		quadrant=vec2(0.0);
	} else if(part==1){
		tile=UV;
		quadrant=vec2(0.0,0.5);
	} else if(face.y>0.90){
		float radius=part==2?0.025:0.041;
		tile=point.xz/(2.0*radius)+0.5;
		quadrant=vec2(0.5,0.0);
	} else {
		float angle=atan(point.z,point.x)/6.283185+0.5;
		float height=part==2?0.026:0.063;
		tile=vec2(angle,0.5-point.y/height);
		quadrant=vec2(0.5);
		float vent_distance=abs(fract((angle-0.313)/0.29+0.5)-0.5)*0.29;
		float vent=1.0-smoothstep(0.024,0.071,vent_distance);
		hot_seam=smoothstep(0.24,0.33,tile.y)*(1.0-smoothstep(0.64,0.75,tile.y))*(0.12+0.88*vent);
	}
	vec3 rust=texture(forged,quadrant+vec2(0.004)+clamp(tile,vec2(0.0),vec2(1.0))*0.492).rgb;
	if(part==1){
		// Neighboring links rub through oxide at the inside ends of each oval.
		float inside=1.0-smoothstep(0.014,0.020,length(point.xz));
		float ends=smoothstep(0.57,0.93,abs(point.x)/max(0.001,length(point.xz)));
		rust=mix(rust,vec3(0.57,0.58,0.56),0.67*inside*ends);
	}
	float light=clamp(dot(normalize(NORMAL),normalize(vec3(-0.35,0.7,0.62))),0.0,1.0);
	float rim=pow(1.0-abs(dot(normalize(NORMAL),VIEW)),3.0);
	float recess=1.0-smoothstep(0.06,0.45,dot(rust,vec3(0.30,0.59,0.11)));
	ALBEDO=rust*(0.76+0.47*light)+vec3(0.08,0.085,0.09)*rim
		+heat*hot_seam*recess*vec3(0.96,0.18,0.025);
}
