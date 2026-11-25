shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D plates : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform bool bearing = false;
uniform bool signal_on = false;
varying vec3 local_point;
varying vec3 face;
void vertex(){
	local_point=VERTEX;
	face=NORMAL;
}
void fragment(){
	vec2 uv=UV;
	if (bearing) {
		if (face.y>0.8) {
			uv=vec2(0.75,0.25)+local_point.xz*(0.245/0.087);
		} else {
			float angle=atan(local_point.z,local_point.x);
			uv=vec2(0.005+(angle/6.283185+0.5)*0.49,0.75-local_point.y*7.5);
		}
	}
	vec3 paint=texture(plates,uv).rgb;
	float light=clamp(dot(normalize(NORMAL),normalize(vec3(-0.35,0.72,0.62))),0.0,1.0);
	ALBEDO=paint*(0.77+0.36*light);
	if(signal_on){
		// Illuminate edge-on views too. Preserve enamel detail across the wide faces.
		float enamel=dot(paint,vec3(0.30,0.59,0.11));
		float heat=clamp(0.25+enamel*0.62+0.22*local_point.x/0.15,0.0,1.0);
		vec3 ember=mix(vec3(1.0,0.19,0.025),vec3(1.0,0.83,0.40),heat);
		ALBEDO=ember;
		EMISSION=ember*0.42;
	}
}
