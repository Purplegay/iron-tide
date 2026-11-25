shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add;
// EA Uprising FXLightning / fxprotoncollider, DefaultW3D and MuzzleFlash paths.
// Separate from Future Tank's shield. OpacityOverride scrolls the proton mask;
// it is not a uniform alpha fade. World positions are converted back to SAGE.
uniform sampler2D diffuse_map : repeat_enable;
uniform sampler2D noise_map : repeat_enable;
uniform sampler2D mask_map : repeat_disable;
uniform int kind = 0;
uniform vec4 coord = vec4(0.0,0.0,1.0,1.0);
uniform vec4 coord2 = vec4(1.0,1.0,0.0,0.0);
uniform vec3 tint = vec3(1.0);
uniform float emissive = 1.0;
uniform float noise_scale = 0.0;
uniform float amplitude = 0.0;
uniform float divergence = 0.0;
uniform float speed = 0.0;
uniform float age = 0.0;
uniform float opacity = 1.0;
uniform float edge_fade = 0.0;
uniform bool multi = false;
uniform bool unique_world = false;
uniform float world_scale = 0.0;
uniform float world_strength = 1.0;
uniform bool mask_uv2 = false;
uniform bool secondary_enabled = true;
uniform vec3 source_origin = vec3(0.0);
varying vec3 sage_position;
varying float native_edge;
void vertex() {
    vec3 p = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
    sage_position = vec3(p.x,-p.z,p.y) + source_origin;
    vec3 world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);
    float viewing_angle=abs(dot(normalize(INV_VIEW_MATRIX[3].xyz-p),world_normal));
    native_edge=edge_fade>0.0 ? smoothstep(0.0,edge_fade,viewing_angle) : 1.0;
}
void fragment() {
    vec3 energy;
    if (kind == 2) {
        vec4 a = texture(diffuse_map,UV*coord.zw + fract(coord.xy*age));
        vec4 b = secondary_enabled ? texture(noise_map,UV2*coord2.xy + fract(coord2.zw*age)) : vec4(1.0);
        energy = a.rgb*b.rgb*tint*emissive*COLOR.rgb*opacity;
    } else if (kind == 3) {
        float angle = age*speed;
        mat2 rotation = mat2(vec2(cos(angle),-sin(angle)),vec2(sin(angle),cos(angle)));
        vec2 uv = rotation*(UV-vec2(0.5))+vec2(0.5);
        vec4 a = texture(diffuse_map,uv);
        vec4 b = texture(diffuse_map,multi ? transpose(rotation)*(UV-vec2(0.5))+vec2(0.5) : uv);
        energy = pow(max(a.rgb*b.rgb,vec3(0.0)),vec3(2.2))*tint*COLOR.rgb*opacity;
    } else {
        vec2 noise_uv = UV*noise_scale;
        if (unique_world) {
            if (kind == 1) noise_uv = sage_position.xy*world_scale*0.01*world_strength;
            else noise_uv.y += (sage_position.x+sage_position.y)*world_scale*0.1;
        }
        float angle = radians(divergence);
        mat2 rotation = mat2(vec2(cos(angle),-sin(angle)),vec2(sin(angle),cos(angle)));
        vec2 drift = vec2(speed*age*0.01,0.0);
        vec2 displacement = (texture(noise_map,rotation*noise_uv+drift).xy
            +texture(noise_map,transpose(rotation)*noise_uv+drift).xy-1.0)*amplitude;
        vec2 offset = fract(coord.xy*age);
        vec2 base = UV*coord.zw+offset;
        vec4 a = texture(diffuse_map,base+displacement);
        if (multi) a *= texture(diffuse_map,UV*coord.zw*coord.zw-offset+displacement);
        energy = pow(max(a.rgb,vec3(0.0)),vec3(2.2))*tint*emissive*COLOR.rgb*COLOR.a*2.0;
        if (kind == 1) energy *= texture(mask_map,(mask_uv2 ? UV2 : base)-vec2(opacity*3.0-1.0)).rgb;
        // Native FXLightning multiplies RGB by vertex alpha once. Its squared
        // output alpha is ignored by ONE+ONE blending, not another RGB factor.
        else energy *= opacity*native_edge;
    }
    if (kind == 2 && edge_fade > 0.0) energy *= native_edge;
    float alpha = clamp(max(energy.r,max(energy.g,energy.b)),0.0,1.0);
    ALBEDO = energy/max(alpha,0.0001);
    ALPHA = alpha;
}
