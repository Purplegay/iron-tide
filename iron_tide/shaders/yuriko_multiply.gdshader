shader_type canvas_item;
render_mode unshaded, blend_mul;
#include "res://shaders/yuriko_particle.gdshaderinc"
void fragment() { COLOR = vec4(1.0 - clamp(particle_sample(TEXTURE, UV).rgb, vec3(0.0), vec3(1.0)), 1.0); }
