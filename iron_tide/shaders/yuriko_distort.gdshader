shader_type canvas_item;
render_mode unshaded, blend_add;
#include "res://shaders/yuriko_particle.gdshaderinc"
void fragment() { COLOR = vec4(particle_sample(TEXTURE, UV).rgb, 1.0); }
