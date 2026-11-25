shader_type canvas_item;
render_mode unshaded;
uniform sampler2D detail_map : repeat_enable, filter_linear;
uniform vec4 displacement;
uniform float seconds;
uniform float columns=1.0;
uniform float frames=1.0;
uniform float frame=0.0;
varying vec4 tint;
void vertex(){tint=COLOR;}
vec2 cell(float n,vec2 uv) {
	n=floor(mod(n,frames));
	return (vec2(mod(n,columns),floor(n/columns))+uv)/columns;
}
void fragment(){
	float a=radians(displacement.z);
	mat2 rot=mat2(vec2(cos(a),sin(a)),vec2(-sin(a),cos(a)));
	vec2 p=UV*displacement.x;
	vec2 drift=vec2(seconds*displacement.y,0);
	vec2 noise=texture(detail_map,rot*p+drift).rg+texture(detail_map,transpose(rot)*p+drift).rg;
	vec2 offset=(noise*2.0-2.0)*displacement.w;
	COLOR=tint*mix(texture(TEXTURE,cell(frame,UV)+offset),texture(TEXTURE,cell(frame+1.0,UV)+offset),fract(frame));
}
