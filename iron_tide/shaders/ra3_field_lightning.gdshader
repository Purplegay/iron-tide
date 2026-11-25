shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
// Uprising FXLightning.fxo VS13536/PS12320, material MultiTexture=false,
// MultiplyBlend=false and UniqueWorldCoord=false. Radiance is composited ONE+ONE.
uniform sampler2D cloud : repeat_enable, filter_linear;
uniform sampler2D distortion : repeat_enable, filter_linear;
uniform float phase = 0.0;
uniform float strength = 0.0;
uniform vec4 coord_offset = vec4(0.0, 0.0, 5.0, 1.0);
uniform float edge_fade = 3.0;
uniform float hdr_multiplier = 2.0;
uniform float displace_amp = 1.0;
uniform float displace_speed = 1.0;
uniform float displace_scalar = 1.0;
uniform float divergence = 0.785398163;
varying vec3 vertex_tint;
varying float vertex_edge;
vec3 native_framebuffer_color(vec3 color) {
    if (!OUTPUT_IS_SRGB) { return color; }
    // Compatibility converts ALBEDO with a cubic sRGB approximation, then
    // applies a different inverse at output. That round trip crushes this
    // effect's dim gradient. Compensate ONLY this native ONE+ONE material.
    // Target is the original FXO's raw RGB (SRGBWRITEENABLE=false).
    vec3 target = pow((max(color,vec3(0.0))+vec3(0.055))/1.055,vec3(2.4));
    vec3 value = max(color,vec3(0.04));
    for (int i=0; i<3; i++) {
        vec3 linear = value*(value*(value*0.305306011+0.682171111)+0.012522878);
        vec3 derivative = value*(value*0.915918033+1.364342222)+0.012522878;
        value = max(value-(linear-target)/derivative,vec3(0.0));
    }
    return mix(value,vec3(0.0),lessThanEqual(color,vec3(0.0)));
}
void vertex() {
    vec3 world_normal = mat3(MODEL_MATRIX) * NORMAL;
    vec3 eye = normalize(CAMERA_POSITION_WORLD-(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz);
    float edge = smoothstep(0.0,edge_fade,abs(dot(world_normal,eye)));
    // Native VS writes tint and edge alpha separately. Multiplying before
    // rasterization changes the gradient between the sparse shell rings.
    vertex_tint = COLOR.rgb * strength;
    vertex_edge = edge * COLOR.a;
}
void fragment() {
    vec2 p = UV * displace_scalar;
    float c = cos(divergence), s = sin(divergence);
    vec2 drift = vec2(phase*displace_speed*0.01,0.0);
    vec2 a = vec2(p.x*c+p.y*s,p.y*c-p.x*s)+drift;
    vec2 b = vec2(p.x*c-p.y*s,p.y*c+p.x*s)+drift;
    vec2 noise = texture(distortion,a).rg+texture(distortion,b).rg-vec2(1.0);
    // Native VS: r=(UV*offset.zw)*offset.xy-timeOffset;
    // t1.xy=UV*r+timeOffset. This material has zero xy, so its base UV is
    // zero and the two displacement samples drive the cloud lookup entirely.
    vec2 time_offset = fract(phase*coord_offset.xy);
    vec2 r = UV*coord_offset.zw*coord_offset.xy-time_offset;
    vec2 uv = UV*r+time_offset+noise*displace_amp;
    vec3 pattern = pow(max(texture(cloud,uv).rgb,vec3(0.0)),vec3(2.2));
    ALBEDO = native_framebuffer_color(pattern*vertex_tint*vertex_edge*hdr_multiplier*2.0);
    ALPHA = 1.0;
}
