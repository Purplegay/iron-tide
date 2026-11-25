shader_type canvas_item;
#include "res://shaders/mechanical_glow.gdshaderinc"
uniform vec4 house_color : source_color = vec4(.35,.65,1.0,1.0);
uniform vec2 atlas_texel;
uniform bool online = true;
uniform bool supplying = false;
uniform float phase = 0.0;
varying vec4 vertex_tint;
void vertex() { vertex_tint=COLOR; }

void fragment() {
	vec4 color=COLOR;
	if (distance(TEXTURE_PIXEL_SIZE,atlas_texel)<.000001) {
		vec3 rgb=color.rgb;
		float peak=max(max(rgb.r,rgb.g),rgb.b);
		vec3 hue=rgb/max(.001,peak);
		// Red armor is owner paint; copper, ceramic and reactor glass stay distinct.
		float paint=smoothstep(.12,.25,hue.r-hue.g)*(1.0-smoothstep(.04,.16,hue.g-hue.b));
		paint*=smoothstep(.08,.22,peak);
		color.rgb=mix(rgb,house_color.rgb*(.12+peak*.88),paint);
		vec3 emission=mechanical_emission(vec4(rgb,1.),false);
		float lamp=max(max(emission.r,emission.g),emission.b);
		float pulse=online ? (.8+.2*sin(phase*2.4))*(supplying ? 1.3 : 1.0) : .035;
		color.rgb*=mix(1.0,pulse,lamp);
		if (!online) color.rgb*=.62;
		vec2 halo_step=TEXTURE_PIXEL_SIZE*4.;
		color=mechanical_halo(
			texture(TEXTURE,UV+vec2(halo_step.x,0.)),texture(TEXTURE,UV-vec2(halo_step.x,0.)),
			texture(TEXTURE,UV+vec2(0.,halo_step.y)),texture(TEXTURE,UV-vec2(0.,halo_step.y)),
			color,online ? pulse*(supplying ? 1.6 : .8) : 0.,vertex_tint.a,false);
	}
	COLOR=color;
}
