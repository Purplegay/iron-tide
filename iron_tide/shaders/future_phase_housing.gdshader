shader_type spatial;
render_mode unshaded;
uniform sampler2D panels : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform bool nozzle=false;
varying vec3 point;
varying vec3 face;
void vertex(){
	point=VERTEX;
	face=NORMAL;
}
void fragment(){
	vec2 mapped;
	if(nozzle){
		if(face.y>0.9) {
			mapped=vec2(0.75,0.25)+point.xz*(0.246/0.060);
		} else {
			float around=atan(point.z,point.x)/6.283185+0.5;
			mapped=vec2(0.006+0.488*around,0.50+0.49*clamp(point.y/0.108+0.5,0.0,1.0));
		}
	} else {
		vec3 p=point/vec3(0.12,0.085,0.30)+0.5;
		vec2 tile=abs(face.y)>0.5?p.xz:(abs(face.x)>0.5?p.zy:p.xy);
		mapped=0.007+0.486*tile+(abs(face.z)>0.5?vec2(0.5):vec2(0.0));
	}
	float light=max(dot(normalize(NORMAL),normalize(vec3(-0.35,0.72,0.65))),0.0);
	ALBEDO=texture(panels,mapped).rgb*vec3(0.90,0.95,1.0)*(0.83+0.31*light);
}
