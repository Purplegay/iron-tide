shader_type canvas_item;
uniform vec4 accent : source_color = vec4(0.7,0.6,1.0,1.0);
void fragment() {
	vec4 frame=texture(TEXTURE,UV);
	float value=max(frame.r,max(frame.g,frame.b));
	float magenta=smoothstep(0.02,0.25,min(frame.r,frame.b)-frame.g);
	float metallic=1.0-clamp((value-frame.g)/max(value,0.001),0.0,1.0);
	vec3 dyed=mix(accent.rgb,vec3(1.0),metallic*metallic)*value;
	COLOR=vec4(mix(frame.rgb,dyed,magenta),frame.a);
}
