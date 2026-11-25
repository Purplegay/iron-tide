shader_type canvas_item;
render_mode blend_add;
// Native FXShield/FXLightning use ONE + ONE. The offscreen RGB already contains
// their opacity curves; viewport alpha is coverage, not a second opacity factor.
void fragment() {
    COLOR = vec4(texture(TEXTURE, UV).rgb, 1.0);
}
