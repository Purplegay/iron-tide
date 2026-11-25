shader_type canvas_item;
// GPUParticleDistortion.fx normal/alpha pass + PostFX_Distortion.fx maxOffset.
// The 2D battlefield has no matching SAGE depth, so soft intersections remain
// unavailable. Do not replace the native normal field with an invented circle.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float opacity = 1.0;
uniform float angle = 0.0;
void fragment() {
    mat2 rotation=mat2(vec2(cos(angle),sin(angle)),vec2(-sin(angle),cos(angle)));
    vec2 uv=transpose(rotation)*(UV-vec2(0.5))+vec2(0.5);
    vec4 texel=texture(TEXTURE,uv);
    vec3 normal=normalize(texel.rgb*2.0-1.0);
    vec2 view_normal=rotation*normal.xy;
    float coverage=clamp(opacity*texel.a,0.0,1.0);
    // Blending the encoded normal into the neutral distortion buffer applies
    // coverage to the offset once. A second screen alpha blend would fade twice.
    vec2 offset=view_normal*coverage*0.08;
    COLOR=vec4(texture(screen_texture,SCREEN_UV+offset).rgb,1.0);
}
