shader_type spatial;
render_mode unshaded, cull_disabled, skip_vertex_transform, depth_draw_never;
uniform sampler2D plume : source_color, filter_linear_mipmap, repeat_disable;
uniform float thrust = 0.0;
uniform float phase = 0.0;
uniform float bend = 0.0;

void vertex(){
	// Keep the emitting edge fixed to the X-1 socket while the cross-section faces the camera.
	vec3 axis=-MODELVIEW_MATRIX[0].xyz;
	// Local +Z is the flank toward the previous aft heading on a positive hull turn.
	float yaw=bend*UV.x;
	vec3 side=MODELVIEW_MATRIX[2].xyz;
	vec3 tangent=cos(yaw)*axis+sin(yaw)*side;
	vec3 across=normalize(vec3(-tangent.y,tangent.x,0.0)+vec3(0.0,0.00001,0.0));
	float span=length(axis);
	float length_scale=(0.12+0.55*thrust)*(1.0+0.035*sin(phase*5.0));
	float width=(0.070+0.13*thrust)*span;
	// Circular arc from the socket. Use a series near zero for a stable straight jet.
	float along=abs(yaw)<0.01 ? 1.0-yaw*yaw/6.0 : sin(yaw)/yaw;
	float lateral=abs(yaw)<0.01 ? yaw*0.5 : (1.0-cos(yaw))/yaw;
	VERTEX=MODELVIEW_MATRIX[3].xyz+UV.x*length_scale*(along*axis+lateral*side)+(UV.y-0.5)*width*across;
}
void fragment(){
	float x=UV.x;
	float drift=x*17.0-phase*8.0;
	float eddy=sin(drift)+0.4*sin(x*27.0-phase*13.0+UV.y*4.0);
	float downstream=smoothstep(0.0,0.28,x);
	vec2 uv=vec2(0.014+x*0.97,0.5+(UV.y-0.5)*0.66);
	uv.x+=0.029*eddy*downstream;
	uv.y+=0.030*eddy*downstream;
	vec4 jet=texture(plume,clamp(uv,vec2(0.0),vec2(1.0)));
	float crest=0.5+0.5*cos(drift+(UV.y-0.5)*3.0);
	ALBEDO=jet.rgb*(0.90+0.24*crest);
	ALPHA=jet.a*thrust*(0.65+0.35*crest)*smoothstep(0.0,0.025,x)*(1.0-smoothstep(0.82,1.0,x));
}
