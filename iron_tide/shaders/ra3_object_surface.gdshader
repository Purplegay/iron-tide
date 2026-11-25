shader_type spatial;
render_mode ambient_light_disabled, specular_disabled, cull_disabled;

// ObjectsAllied / ObjectsAlliedTread / ObjectsSoviet, high path. Lights are in Godot map axes.
uniform sampler2D diffuse_map : filter_linear_mipmap_anisotropic;
uniform sampler2D normal_map : filter_linear_mipmap_anisotropic;
uniform sampler2D surface_map : filter_linear_mipmap_anisotropic;
uniform samplerCube environment_map : filter_linear;
uniform vec4 house_color = vec4(1.0);
uniform vec4 custom_body : source_color = vec4(0.0);
uniform vec4 custom_weapon : source_color = vec4(0.0);
uniform bool alpha_test;
uniform bool is_tread;
uniform float tread_offset;
uniform mat3 world_to_map;
uniform vec3 ambient_light;
uniform vec3 light_directions[3];
uniform vec3 light_colors[3];
uniform int muzzle_light_count;
uniform vec4 muzzle_positions_ranges[2];
uniform vec3 muzzle_colors[2];

varying vec3 shadowable_light;
varying vec3 sun_view;
uniform float occluded_light = 0.5;
void fragment() {
	vec2 uv = UV + vec2(is_tread ? tread_offset : 0.0, 0.0);
	vec4 paint = texture(diffuse_map, uv);
	if (alpha_test && paint.a * COLOR.a < 96.0 / 255.0) { discard; }
	vec3 masks = texture(surface_map, uv).rgb;
	vec3 tint = mix(vec3(1.0), house_color.rgb * 2.0, masks.b);
	vec4 dye = mix(custom_body, custom_weapon, UV2.x);
	paint.rgb = mix(paint.rgb, dye.rgb * dot(paint.rgb, vec3(0.299,0.587,0.114)) * 1.7, dye.a * (1.0-masks.b) * 0.78);
	vec3 base = pow(max(paint.rgb * tint, vec3(0.0)), vec3(2.2));
	vec3 bump = texture(normal_map, uv).xyz * 2.0 - 1.0;
	bump.xy *= 1.5;
	vec3 n = normalize(mat3(TANGENT, BINORMAL, NORMAL) * bump);
	mat3 view_to_map = world_to_map * mat3(INV_VIEW_MATRIX);
	vec3 map_n = normalize(view_to_map * n);
	vec3 light_sum = ambient_light * 0.1 * COLOR.rgb;
	for (int i = 1; i < 3; i++) {
		light_sum += light_colors[i] * max(dot(map_n, light_directions[i]), 0.0);
	}
	// The skinned hull and gun meshes share the muzzle bones' model space.
	for (int i = 0; i < muzzle_light_count; i++) {
		vec4 light = muzzle_positions_ranges[i];
		vec3 delta = (VIEW_MATRIX * MODEL_MATRIX * vec4(light.xyz, 1.0)).xyz - VERTEX;
		float distance_to_light = length(delta);
		float attenuation = clamp(1.0 - distance_to_light / light.w, 0.0, 1.0);
		float facing = max(dot(n, delta / max(0.0001, distance_to_light)), 0.0);
		light_sum += muzzle_colors[i] * (attenuation * attenuation * facing);
	}
	vec3 sun = light_directions[0];
	vec3 axis = normalize(cross(sun, vec3(1.0, 0.0, 0.0)));
	vec3 ray = view_to_map * reflect(-VIEW, n);
	vec3 light_space = vec3(dot(ray, axis), dot(ray, cross(sun, axis)), dot(ray, sun));
	vec3 reflection = texture(environment_map, light_space).rgb * masks.r * light_colors[0];
	vec3 key = base * light_colors[0] * max(dot(map_n, sun), 0.0) + reflection;
	vec3 indirect = base * light_sum + key * occluded_light;
	vec3 full = base * light_sum + key;
	if (OUTPUT_IS_SRGB) {
		indirect = pow(max(indirect, vec3(0.0)), vec3(1.0 / 2.2));
		full = pow(max(full, vec3(0.0)), vec3(1.0 / 2.2));
	}
	sun_view = transpose(view_to_map) * sun;
	shadowable_light = full - indirect;
	EMISSION = indirect;
	ALBEDO = vec3(1.0);
}

void light() {
	if (LIGHT_IS_DIRECTIONAL && dot(LIGHT, sun_view) > 0.995) {
		DIFFUSE_LIGHT += shadowable_light * ATTENUATION;
	}
}
