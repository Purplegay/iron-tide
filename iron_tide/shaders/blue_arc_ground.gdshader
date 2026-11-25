shader_type canvas_item;
render_mode unshaded;

// All distances below are relative to the current ground radius. The ground
// ellipse and upright volume share an origin even when the camera rotates.
uniform sampler2D scene : hint_screen_texture, repeat_disable, filter_linear;
uniform float strength = 0.0;
uniform float swirl_angle = 0.0;
uniform float squash = 0.5;
uniform float rise = 0.0;
uniform float flame = 0.0;
uniform bool separate_heat = false;
uniform bool air_only = false;
varying float diameter_px;

void vertex() {
	diameter_px = length((CANVAS_MATRIX * MODEL_MATRIX)[0].xy) / TEXTURE_PIXEL_SIZE.x;
}

// Reconstruct the two sides of the circular burner. Each tongue starts on
// its own point on the ground and tapers vertically in screen space.
vec2 flames(vec2 p, float side) {
	float ring_radius = 0.83;
	float edge = 1.0 - smoothstep(ring_radius-0.035,ring_radius,abs(p.x));
	float z = side * sqrt(max(0.0,ring_radius*ring_radius - p.x*p.x));
	float a = atan(z,p.x + 0.00001);
	float y = z*squash - p.y;
	float u = a*19.0 + swirl_angle*1.8 + 1.1*sin(5.0*a - swirl_angle*1.7)
		+ max(0.0,y)*4.5*sin(a*7.0+swirl_angle*3.0);
	float tongue = pow(0.5 + 0.5*sin(u),1.8);
	float h = (0.07 + 0.23*tongue + 0.05*sin(a*3.0+swirl_angle))*(0.35+0.65*flame);
	float lip = exp(-abs(y)*72.0);
	float body = smoothstep(-0.035,0.012,y)*(1.0-smoothstep(0.0,max(0.025,h),y));
	float flicker = 0.72 + 0.28*sin(9.0*a + swirl_angle*3.2 - y*13.0);
	return vec2(body*flicker,lip*(0.72+0.28*tongue))*edge*flame;
}

void fragment() {
	vec2 p = vec2(UV.x*2.0-1.0, (UV.y*2.0-1.0)*(squash+rise*0.5)-rise*0.5);
	vec2 ground = vec2(p.x,p.y/squash);
	float radius = length(ground);
	float band = smoothstep(0.08,0.48,radius)*(1.0-smoothstep(0.72,0.98,radius));
	vec4 field = texture(TEXTURE,clamp(ground*0.5+0.5,vec2(0.0),vec2(1.0)));
	vec2 n = field.rg*2.0-1.0;
	vec2 shift = (n*0.035 - vec2(-n.y,n.x)*(0.12+0.024*cos(swirl_angle-radius*5.0))) * band * field.a;
	shift.y *= squash;

	// Rolling heat above the floor: broad at the base, narrower at the crest.
	float height = clamp(-p.y/max(0.001,rise),0.0,1.0);
	float width = mix(0.76,0.30,height);
	float envelope = (1.0-smoothstep(width*0.52,width,abs(p.x)))
		* smoothstep(-0.03,0.11,-p.y)*(1.0-smoothstep(rise*0.78,rise+0.001,-p.y));
	float twist = swirl_angle*2.8 + height*8.5 + p.x*3.0;
	vec2 heat_shift = vec2(sin(twist)*0.105, -0.045+cos(twist)*0.035)*envelope;
	if (!separate_heat) { shift += heat_shift; }
	if (separate_heat) { envelope = 0.0; }
	vec2 f = min(vec2(1.0),flames(p,-1.0)*0.78 + flames(p,1.0));
	float coverage = max(max(band,envelope)*strength,max(f.x,f.y));
	if (air_only) {
		shift = heat_shift;
		coverage = envelope*strength;
		f = vec2(0.0);
	}
	if (coverage < 0.002) { discard; }
	vec2 offset = shift * strength * diameter_px * SCREEN_PIXEL_SIZE;
	vec3 base = texture(scene,clamp(SCREEN_UV+offset,vec2(0.0),vec2(1.0))).rgb;
	vec3 lit = mix(base,vec3(0.08,0.34,1.0),min(0.87,f.x));
	lit = mix(lit,vec3(0.38,0.88,1.0),min(0.92,0.45*f.x*f.x+0.8*f.y));
	COLOR = vec4(lit,smoothstep(0.002,0.06,coverage));
}
