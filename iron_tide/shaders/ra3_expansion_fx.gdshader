shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add;
// Uprising fxshield / FXLightning texture-coordinate paths. Scene-depth outlines
// cannot be reproduced inside an isolated 3D viewport over the 2D battlefield.
uniform sampler2D diffuse_map : repeat_enable;
uniform sampler2D noise_map : repeat_enable;
uniform sampler2D mask_map : repeat_enable;
uniform sampler2D fade_map : repeat_disable;
uniform vec4 coord = vec4(0.1,0.1,1.5,1.5);
uniform vec3 tint = vec3(0.647482,0.631373,1.0);
uniform float emissive = 15.0;
uniform float noise_scale = 0.2;
uniform float amplitude = 5.0;
uniform float divergence = 45.0;
uniform float speed = 5.0;
uniform float age = 0.0;
uniform float opacity = 1.0;
uniform bool shield = true;
void fragment() {
    float angle = radians(divergence);
    mat2 turn = mat2(vec2(cos(angle),sin(angle)),vec2(-sin(angle),cos(angle)));
    vec2 drift = vec2(speed*age*0.01,0.0);
    vec2 displacement = (texture(noise_map,turn*(UV*noise_scale)+drift).xy
        +texture(noise_map,transpose(turn)*(UV*noise_scale)+drift).xy-1.0)*amplitude;
    vec2 offset = fract(coord.xy*age);
    vec4 texel = texture(diffuse_map,UV*coord.zw+offset+displacement);
    if (shield) {
        texel *= texture(diffuse_map,UV*coord.zw*coord.zw-offset+displacement);
        texel *= texture(fade_map,vec2(1.0-abs(dot(normalize(NORMAL),normalize(VIEW))),1.0)).r;
    } else {
        texel *= texture(mask_map,UV);
    }
    vec3 energy = texel.rgb*tint*emissive*2.0;
    ALBEDO = energy;
    ALPHA = clamp(max(energy.r,max(energy.g,energy.b)),0.0,1.0)*opacity;
}
