shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform sampler2D cloud : source_color, repeat_enable, filter_linear;
uniform sampler2D distortion : hint_normal, repeat_enable, filter_linear;
uniform float phase = 0.0;
uniform float strength = 0.0;
uniform bool rays = false;
void fragment() {
    vec2 flow = texture(distortion, UV*2.0+vec2(phase*0.025,0.0)).rg-0.5;
    vec4 pattern = texture(cloud, UV+flow*0.08+vec2(0.02,-0.025)*phase);
    float rim = pow(1.0-abs(dot(normalize(NORMAL),normalize(VIEW))),2.0);
    ALBEDO = mix(vec3(0.25,0.58,1.0),vec3(0.62,0.86,1.0),pattern.r);
    EMISSION = ALBEDO*0.25;
    ALPHA = strength * (rays ? pattern.r*0.5 : (0.06+rim*0.32)*pattern.r);
}
