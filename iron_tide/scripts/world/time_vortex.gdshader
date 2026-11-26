shader_type canvas_item;
render_mode unshaded;
uniform sampler2D scene : hint_screen_texture, repeat_disable, filter_linear;
uniform float progress = 0.0;
void fragment() {
 vec2 aspect = vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0);
 vec2 center = vec2(0.46, 0.48);
 vec2 offset = (SCREEN_UV - center) * aspect;
 float radius = length(offset);
 float strength = sin(progress * 3.14159265);
 float twist = strength * 5.5 * exp(-radius * radius * 6.0);
 vec2 warped = mat2(vec2(cos(twist), sin(twist)), vec2(-sin(twist), cos(twist))) * offset;
 vec3 field = texture(scene, clamp(center + warped / aspect, vec2(0.001), vec2(0.999))).rgb;
 float arc = pow(0.5 + 0.5 * cos(3.0 * atan(offset.y, offset.x + 0.00001) + 18.0 * radius - 7.0 * progress), 8.0);
 field += vec3(0.12, 0.45, 0.75) * arc * strength * exp(-radius * 3.0);
 COLOR = vec4(mix(field, vec3(0.78, 0.91, 1.0), pow(strength, 24.0)), 1.0);
}
