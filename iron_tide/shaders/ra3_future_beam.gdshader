shader_type canvas_item;
render_mode blend_add;
uniform sampler2D first : repeat_enable;
uniform sampler2D second : repeat_enable;
uniform float second_v=1.0;
uniform float age=0.0;
uniform vec3 emissive=vec3(4.5);
void fragment() {
    vec4 a=texture(first,UV)*texture(second,vec2(UV.x,UV.y*second_v+age));
    COLOR=vec4(pow(max(a.rgb*emissive,vec3(0)),vec3(2.2)),a.a);
}
