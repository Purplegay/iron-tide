uniform sampler2D detail_noise : repeat_enable, filter_linear;
uniform vec4 misc = vec4(0.0);
uniform float seed_offset = 0.0;
uniform float frame = 0.0;
uniform float columns = 1.0;
uniform float frames = 1.0;
uniform float animation_speed = 1.0;
varying vec4 tint;
void vertex() { tint = COLOR; }
vec2 atlas_cell(float f, vec2 uv) {
	float index = floor(mod(f, frames));
	return (vec2(mod(index, columns), floor(index / columns)) + uv) / columns;
}
vec4 particle_sample(sampler2D image, vec2 uv) {
	vec2 offset = vec2(0.0);
	if (misc.w > 0.0) {
		float angle = radians(misc.z);
		mat2 rot = mat2(vec2(cos(angle), sin(angle)), vec2(-sin(angle), cos(angle)));
		vec2 coord = uv * misc.x + seed_offset;
		vec2 drift = vec2(misc.y * frame / (30.0 * max(animation_speed, 0.001)), 0.0);
		vec2 normal = texture(detail_noise, rot * coord + drift).rg + texture(detail_noise, transpose(rot) * coord + drift).rg;
		offset = (2.0 * normal - 2.0) * misc.w;
	}
	vec4 current = texture(image, clamp(atlas_cell(frame, uv) + offset, vec2(0.0), vec2(1.0)));
	vec4 next_cell = texture(image, clamp(atlas_cell(frame + 1.0, uv) + offset, vec2(0.0), vec2(1.0)));
	return mix(current, next_cell, fract(frame)) * tint;
}
