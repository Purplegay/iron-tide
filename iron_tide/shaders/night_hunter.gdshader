shader_type canvas_item;
#include "res://shaders/mechanical_glow.gdshaderinc"
uniform float breath = 0.25;
uniform bool drone = false;
uniform bool ice_paint = false;
uniform vec4 house_color : source_color = vec4(0.341176,0.658824,1.0,1.0);
uniform vec2 body_texel = vec2(0.0009765625,0.0006510416667);
uniform vec2 gun_texel = vec2(0.0);
uniform float metal_finish : hint_range(0.0,1.0) = 1.0;
uniform float exhaust_phase = 0.0;
uniform bool lamps_online = true;
uniform vec4 exhaust_uv = vec4(0.0,0.923076923,0.375,0.076923077);
varying vec4 vertex_tint;

void vertex() { vertex_tint=COLOR; }

vec3 polished_steel(vec3 rgb, float mask) {
	float peak=max(max(rgb.r,rgb.g),rgb.b);
	vec3 hue=rgb/max(peak,0.001);
	float warm=smoothstep(0.08,0.28,hue.r-hue.b);
	vec3 lifted=pow(max(rgb,vec3(0.0)),vec3(0.8))*1.22;
	float reflection=smoothstep(0.14,0.48,peak)*0.14;
	vec3 finish=min(lifted+vec3(0.82,0.91,1.0)*reflection,vec3(0.95));
	return mix(rgb,finish,mask*(1.0-warm)*metal_finish);
}

void fragment() {
	vec4 color=COLOR;
	if (abs(vertex_tint.r-0.731)<0.0001 && abs(vertex_tint.b-0.997)<0.0001) {
		vec2 local=(UV-exhaust_uv.xy)/exhaust_uv.zw;
		float wave=sin(local.x*18.0-exhaust_phase*15.0);
		vec2 flow=vec2(local.x,local.y+wave*.035*local.x);
		color=texture(TEXTURE,exhaust_uv.xy+clamp(flow,vec2(0.001),vec2(0.999))*exhaust_uv.zw)*vec4(1.0,1.0,1.0,vertex_tint.a);
		float heat=max(max(color.r,color.g),color.b);
		color.rgb=heat*1.6*vec3(1.0,mix(0.85,0.32,local.x),mix(0.45,0.05,local.x));
		color.a=min(1.0,color.a*(1.05+0.35*wave));
	}
	// Only shade the authored body atlas. Never combine neighboring frames.
	else if (abs(TEXTURE_PIXEL_SIZE.x-body_texel.x)<0.000001 && abs(TEXTURE_PIXEL_SIZE.y-body_texel.y)<0.000001) {
		vec3 rgb=color.rgb;
		vec3 emission=mechanical_emission(vec4(rgb,1.),drone);
		float lamp=max(max(emission.r,emission.g),emission.b);
		if (ice_paint) {
			float gray=dot(rgb,vec3(0.2126,0.7152,0.0722));
			color.rgb=mix(rgb,gray*vec3(0.55,1.08,1.30),0.72*(1.0-lamp));
		}
		// Authored red armor carries the owner color. Neutral metal, gold trim,
		// emissive lamps, the separate cannon and exhaust keep their own shading.
		float peak=max(max(rgb.r,rgb.g),rgb.b);
		vec3 hue=rgb/max(peak,0.001);
		float team_mask=smoothstep(0.3,0.5,hue.r-hue.g)*(1.0-smoothstep(.06,.18,abs(hue.g-hue.b)));
		team_mask*=smoothstep(0.06,0.16,peak)*(1.0-lamp);
		if (!drone) color.rgb=polished_steel(color.rgb,(1.0-lamp)*(1.0-team_mask));
		color.rgb=mix(color.rgb,house_color.rgb*(0.12+peak*0.90),team_mask);
		color.rgb*=mix(1.0,lamps_online ? 0.28+breath*1.1 : .035,lamp);
		vec2 halo_step=TEXTURE_PIXEL_SIZE*4.;
		color=mechanical_halo(
			texture(TEXTURE,UV+vec2(halo_step.x,0.)),texture(TEXTURE,UV-vec2(halo_step.x,0.)),
			texture(TEXTURE,UV+vec2(0.,halo_step.y)),texture(TEXTURE,UV-vec2(0.,halo_step.y)),
			color,lamps_online ? .55+breath*.75 : 0.,vertex_tint.a,drone);
	}
	else if (!drone && abs(TEXTURE_PIXEL_SIZE.x-gun_texel.x)<0.000001 && abs(TEXTURE_PIXEL_SIZE.y-gun_texel.y)<0.000001) {
		color.rgb=polished_steel(color.rgb,1.0);
	}
	COLOR=color;
}
