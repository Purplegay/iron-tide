shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add;
uniform sampler2D particle_map : repeat_disable;
uniform vec3 particle_color=vec3(1.0);
void fragment() {
    // GpuParticle.fx: texture * animated ColorScale, then GammaToLinear,
    // ONE+ONE blending. Texture alpha is not an opaque quad coverage mask.
    vec3 energy=pow(max(texture(particle_map,UV).rgb*particle_color,vec3(0.0)),vec3(2.2));
    float coverage=clamp(max(energy.r,max(energy.g,energy.b)),0.0,1.0);
    ALBEDO=energy/max(coverage,0.0001);ALPHA=coverage;
}
