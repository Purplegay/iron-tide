shader_type spatial;
render_mode cull_disabled;
uniform sampler2D diffuse_map : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D surface_map : filter_linear_mipmap_anisotropic;
uniform vec4 house_color : source_color = vec4(0.34, 0.66, 1.0, 1.0);
uniform bool is_tread = false;
uniform float tread_offset = 0.0;
void fragment() {
    vec2 uv = UV + vec2(is_tread ? tread_offset : 0.0, 0.0);
    vec3 base = texture(diffuse_map, uv).rgb;
    vec3 surface = texture(surface_map, uv).rgb;
    ALBEDO = base * mix(vec3(1.0), house_color.rgb * 1.35, surface.b);
    NORMAL_MAP = texture(normal_map, uv).rgb;
    NORMAL_MAP_DEPTH = 0.65;
    ROUGHNESS = mix(0.8, 0.38, surface.r);
    METALLIC = surface.r * (1.0 - surface.b) * 0.45;
    SPECULAR = 0.4;
    EMISSION = base * surface.g * 0.18;
}
