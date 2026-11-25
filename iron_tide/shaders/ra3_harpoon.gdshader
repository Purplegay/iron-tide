shader_type canvas_item;
render_mode unshaded, blend_add;
uniform sampler2D cloud_map : repeat_enable, filter_linear;
uniform sampler2D beam_map : repeat_enable, filter_linear;
uniform vec3 emissive;
uniform vec2 tile = vec2(1.0);
uniform vec2 scroll = vec2(0.0);
uniform float age = 0.0;
void fragment() {
	vec2 uv=vec2(UV.y,UV.x);
	vec4 beam=texture(beam_map,vec2(uv.x,uv.y*tile.x+age*scroll.x));
	vec4 noise=texture(cloud_map,vec2(uv.x,uv.y*tile.y+age*scroll.y));
	COLOR=vec4(beam.rgb*noise.rgb*emissive,beam.a*noise.a);
}
