shader_type canvas_item;
uniform vec4 house_color : source_color = vec4(.35,.65,1.0,1.0);
uniform sampler2D paint_mask : filter_linear_mipmap, repeat_disable;
uniform vec2 atlas_texel;
uniform bool online = true;
uniform bool broken = false;
uniform float pulse = 1.0;
varying vec4 vertex_tint;

void vertex() {
	vertex_tint=COLOR;
}

float lamp_at(vec2 uv) {
	vec4 paint=texture(paint_mask,uv);
	return paint.b*paint.a;
}

void fragment() {
	vec4 color=COLOR;
	// Gear, exhaust and selection use this CanvasItem too; only shade the atlas.
	if (distance(TEXTURE_PIXEL_SIZE,atlas_texel)<.000001) {
		vec3 mask=texture(paint_mask,UV).rgb;
		float shade=max(max(color.r,color.g),color.b);
		color.rgb=mix(color.rgb,house_color.rgb*(.18+.82*shade),mask.r);
		color.rgb*=mix(1.0,online ? pulse : .16,mask.b);
		if (online && !broken) {
			// Four local mask taps: no lights, particles or extra draw submissions.
			vec2 step_uv=atlas_texel*4.0;
			float light=lamp_at(UV+vec2(step_uv.x,0.0))+lamp_at(UV-vec2(step_uv.x,0.0));
			light+=lamp_at(UV+vec2(0.0,step_uv.y))+lamp_at(UV-vec2(0.0,step_uv.y));
			float halo=min(.38,light*.16*pulse)*vertex_tint.a;
			vec3 glow=vec3(.24,.68,1.0)*vertex_tint.rgb;
			float alpha=max(color.a,halo);
			color.rgb=(color.rgb*color.a+glow*halo*(1.0-color.a))/max(alpha,.00001);
			color.rgb+=glow*light*.10*pulse;
			color.a=alpha;
		}
		if (broken) color.rgb*=.55;
	}
	COLOR=color;
}
