shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add;
// Uprising FXShield.fx additive branch. Flat-ground intersections are resolved
// analytically; 2D actor sprites cannot provide the original 3D scene depth.
uniform sampler2D diffuse_map : repeat_enable;
uniform sampler2D noise_map : repeat_enable;
uniform sampler2D fade_map : repeat_disable;
uniform vec4 coord=vec4(0.0,0.0,1.0,1.0);
uniform vec3 tint=vec3(1.0);
uniform float emissive=1.0;
uniform float noise_scale=0.0;
uniform float amplitude=0.0;
uniform float divergence=0.0;
uniform float speed=0.0;
uniform float edge_fade=1.0;
uniform float age=0.0;
uniform float opacity=1.0;
uniform float intersection=0.0;
uniform bool multi=false;
uniform bool lut=false;
uniform bool override_key=false;
varying float native_falloff;
varying vec3 world_point;
void vertex() {
    vec3 world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
    world_point=world_position;
    vec3 world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);
    float view_angle=abs(dot(normalize(INV_VIEW_MATRIX[3].xyz-world_position),world_normal));
    native_falloff=lut ? clamp(1.0-view_angle,0.0,1.0) : (edge_fade>=0.0 ? smoothstep(0.0,max(edge_fade,0.0001),view_angle) : 1.0-smoothstep(0.0,-edge_fade,view_angle));
}
void fragment() {
    float angle=radians(divergence);
    mat2 rotate=mat2(vec2(cos(angle),-sin(angle)),vec2(sin(angle),cos(angle)));
    vec2 drift=vec2(speed*age*0.01,0.0);
    vec2 displacement=(texture(noise_map,rotate*(UV*noise_scale)+drift).xy
        +texture(noise_map,transpose(rotate)*(UV*noise_scale)+drift).xy-1.0)*amplitude;
    vec2 offset=fract(coord.xy*age);
    vec4 texel=texture(diffuse_map,UV*coord.zw+offset+displacement);
    if(multi) texel*=texture(diffuse_map,UV*coord.zw*coord.zw-offset+displacement);
    // FXShield computes the viewing angle at vertices, then samples the LUT
    // from the interpolant. Recomputing it per pixel changes the shell profile.
    float falloff=lut ? texture(fade_map,vec2(native_falloff,1.0)).r : native_falloff;
    vec3 native_color=COLOR.rgb*tint*(override_key ? 1.0 : opacity);
    // FXShield OUTLINE_SCALE=5 and scalar outlineDiffuse (HLSL takes red).
    // The original depth difference is exact for a horizontal ground plane.
    float depth_delta=world_point.y/max(abs(INV_VIEW_MATRIX[2].y),0.0001);
    float outline_blend=clamp(depth_delta/5.0,0.0,1.0);
    float outline=intersection>0.0 ? texture(fade_map,vec2(1.0-outline_blend,1.0)).r*native_color.r*intersection : 0.0;
    vec3 energy=(native_color*emissive*2.0+vec3(outline))*pow(max(texel.rgb,vec3(0)),vec3(2.2))*falloff;
    float a=clamp(max(energy.r,max(energy.g,energy.b)),0.0,1.0);
    ALBEDO=energy/max(a,0.0001);ALPHA=a;
}
