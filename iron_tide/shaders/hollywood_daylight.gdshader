shader_type canvas_item;
// Terrain carries map lighting and actors carry their palette shading.
// Preserve the battle's temporary exposure response to bright weapon flashes.
uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_nearest;
uniform float exposure_ev = 0.0;
uniform vec3 map_light = vec3(1.0);

void fragment() {
	COLOR = vec4(texture(screen_tex, SCREEN_UV).rgb * map_light * exp2(-exposure_ev / 2.2), 1.0);
}
