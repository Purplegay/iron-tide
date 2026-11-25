shader_type canvas_item;
render_mode unshaded, blend_add;
void fragment() {
    // Do not multiply already-composited 3D radiance by alpha a second time.
    COLOR = vec4(texture(TEXTURE,UV).rgb,1.0);
}
