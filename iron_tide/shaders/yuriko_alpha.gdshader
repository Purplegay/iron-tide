shader_type canvas_item;
render_mode unshaded, blend_mix;
#include "res://shaders/yuriko_particle.gdshaderinc"
void fragment() { COLOR = particle_sample(TEXTURE, UV); }
