shader_type spatial;
render_mode unshaded, cull_disabled, world_vertex_coords, fog_disabled;
uniform vec3 light_ray = vec3(-0.81, -0.45, -0.38);
void vertex() {
    VERTEX -= light_ray * max(VERTEX.y, 0.0) / min(light_ray.y, -0.05);
    VERTEX.y = 0.0;
}
void fragment() {
    // Opaque mask unions overlapping triangles before a single 2D alpha blend.
    ALBEDO = vec3(1.0);
}
