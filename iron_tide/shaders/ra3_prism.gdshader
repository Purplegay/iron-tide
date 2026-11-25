shader_type canvas_item;
render_mode unshaded, blend_add;
uniform sampler2D secondary : source_color, repeat_enable, filter_linear;
uniform float age = 0.0;
uniform float opacity = 1.0;
vec2 laser_uv(vec2 uv, vec2 size) {
    // SAGE Laser.fx sampler: AddressU=Clamp, AddressV=Wrap. Clamp to texel
    // centres so the repeating sampler cannot blend the opposite U edge.
    float half_texel = 0.5 / size.x;
    return vec2(clamp(uv.x, half_texel, 1.0-half_texel), uv.y);
}
void fragment() {
    vec4 one = texture(TEXTURE, laser_uv(UV + vec2(0.2,0.3)*age, vec2(textureSize(TEXTURE,0))));
    vec4 two = texture(secondary, laser_uv(UV - vec2(0.2,0.3)*age, vec2(textureSize(secondary,0))));
    // Installed Uprising Laser.fxo: RGBA product, RGB emissive=4, alpha
    // times CPU opacity, SRCALPHA+ONE. Its compiled path has no gamma pow.
    // Opposing U scroll gradually removes the overlap; no invented edge/tail.
    COLOR = vec4(one.rgb*two.rgb*4.0, one.a*two.a*opacity);
}
