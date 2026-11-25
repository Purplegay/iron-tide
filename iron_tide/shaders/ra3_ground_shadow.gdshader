shader_type canvas_item;
render_mode unshaded;
uniform float softness = 0.8;
uniform float opacity = 0.36;
void fragment() {
    vec2 d = TEXTURE_PIXEL_SIZE * softness;
    float a = texture(TEXTURE, UV).a * 0.4;
    a += texture(TEXTURE, UV + vec2(d.x, 0.0)).a * 0.15;
    a += texture(TEXTURE, UV - vec2(d.x, 0.0)).a * 0.15;
    a += texture(TEXTURE, UV + vec2(0.0, d.y)).a * 0.15;
    a += texture(TEXTURE, UV - vec2(0.0, d.y)).a * 0.15;
    COLOR = vec4(0.025, 0.035, 0.045, a * opacity);
}
