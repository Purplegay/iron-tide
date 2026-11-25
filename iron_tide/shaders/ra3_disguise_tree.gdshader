shader_type spatial;
render_mode cull_disabled;
uniform sampler2D diffuse_map : source_color, filter_linear_mipmap;
// Original TreeSway material: Amp1=.4, Freq1=4, Phase1=.8.
// Height-weighting is the Godot adapter; SAGE vertex program is not executed.
void vertex() {
    VERTEX.x += sin(TIME * 4.0 + VERTEX.y * 0.8) * 0.4 * clamp(VERTEX.y / 45.454887, 0.0, 1.0);
}
void fragment() {
    vec4 color = texture(diffuse_map, UV);
    ALBEDO = color.rgb;
    ALPHA = color.a;
    ALPHA_SCISSOR_THRESHOLD = 0.5;
    ROUGHNESS = 1.0;
}
