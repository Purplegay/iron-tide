shader_type canvas_item;
render_mode unshaded;

// OutlineDrawType.SELECTED adapter. Sample only this animation frame, never
// neighbouring atlas frames. The ordinary actor is drawn over these silhouettes.
uniform vec4 source_region;
uniform sampler2D silhouette_texture : filter_linear, repeat_disable;
uniform vec2 texel_size;
uniform vec2 logical_size;
uniform float border = 1.5;
uniform float opacity = 1.0;
uniform vec4 outline_color : source_color = vec4(0.55, 1.0, 0.64, 1.0);
varying float inherited_alpha;

void vertex() {
	inherited_alpha = COLOR.a;
}

float coverage(vec2 p) {
	if (p.x < 0.0 || p.y < 0.0 || p.x >= logical_size.x || p.y >= logical_size.y) return 0.0;
	vec2 uv = source_region.xy + (p / logical_size) * source_region.zw;
	vec2 low = source_region.xy + texel_size * 0.5;
	vec2 high = source_region.xy + source_region.zw - texel_size * 0.5;
	return smoothstep(0.15, 0.6, texture(silhouette_texture, clamp(uv, low, high)).a);
}

void fragment() {
	vec2 p = UV * (logical_size + vec2(border * 2.0)) - vec2(border);
	float expanded = 0.0;
	for (int i = 0; i < 8; i++) {
		float angle = float(i) * 0.78539816339;
		expanded = max(expanded, coverage(p + vec2(cos(angle), sin(angle)) * border));
	}
	// Parent body covers the union interior, including hull/turret intersections.
	COLOR = vec4(outline_color.rgb, expanded * (1.0 - coverage(p)) * opacity * outline_color.a * inherited_alpha);
}
