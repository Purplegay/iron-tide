shader_type canvas_item;
render_mode unshaded;

varying vec4 particle_color;

void vertex() {
	float cell = min(floor(INSTANCE_CUSTOM.z * 4.0), 3.0);
	UV = (UV + vec2(mod(cell, 2.0), floor(cell / 2.0))) * 0.5;
	particle_color = COLOR;
}

void fragment() {
	// The retail atlas stores particle coverage in luminance on an opaque black field.
	float coverage = texture(TEXTURE, UV).r;
	vec3 ink = mix(particle_color.rgb * 0.64, vec3(0.94, 0.93, 1.0), coverage * coverage);
	COLOR = vec4(ink, smoothstep(0.04, 0.82, coverage) * particle_color.a);
}
