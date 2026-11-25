shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
// FXMIRAGEDISGUISE DefaultW3D material: two UV sets, Modulate2X,
// additive, vertex RGB mask, house color and independent ScaleMove maps.
uniform sampler2D diffuse_map : repeat_enable, filter_linear;
uniform vec4 house_color : source_color = vec4(1.0);
uniform float phase = 0.0;
uniform float strength = 0.0;
varying vec3 tint;
void vertex() {
    vec3 normal = normalize(MODEL_NORMAL_MATRIX*NORMAL);
    vec3 eye = normalize(CAMERA_POSITION_WORLD-(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz);
    tint = COLOR.rgb * mix(house_color.rgb,vec3(1.0),0.25)
        * smoothstep(0.0,1.0,abs(dot(normal,eye))) * strength;
}
void fragment() {
    vec3 a = pow(texture(diffuse_map,UV+phase*vec2(0.1,0.23)).rgb,vec3(2.2));
    vec3 b = pow(texture(diffuse_map,UV2*vec2(1.0,2.0)+phase*vec2(0.0,0.4)).rgb,vec3(2.2));
    ALBEDO = a*b*2.0*tint;
    ALPHA = 1.0;
}
