shader_type canvas_item;

// =====================================================================
// RA2 房色重映射（house color remap）
// ---------------------------------------------------------------------
// 原理：RA2 的「房色阶」（调色板 16..31 号）是「基准色 × lv」构成的过原点直线
//   （lv ∈ {0.127, …, 1.0}，共 16 级）。ra2pipe/art_build.mjs 的 remapPalette() 已在构建期
//   把这条房色阶整体烘焙成盟军蓝 #57a8ff，所以运行时只需把「色相 = 盟军蓝」的像素
//   换成「目标色 × 同一 lv」。
//
// 判据（关键 1）：用「**归一化方向**（色相）匹配」而不是「绝对残差」——
//   房色阶每级都是 base 的整体缩放，方向恒定；绝对残差在低亮度下会趋近 0，
//   会把深灰（r≈g≈b）误判成房色。实测：中性灰与盟军蓝方向夹角 ≈ 22°（sim≈0.927），
//   真房色 sim≈1.000，两者之间余量很大。
//
// 取值来源（关键 2）：只用 `COLOR`，**不要**再乘 `texture(TEXTURE, UV)`。
//   实测（Godot 4.7.2 / Compatibility）canvas_item 片元的 `COLOR` 输入已经等于
//   「顶点色 × 贴图采样」：贴图图元（顶点色=白）→ COLOR=贴图色；无贴图图元
//   （draw_rect/draw_circle/draw_line，采样到画布默认白纹理）→ COLOR=顶点色。
//   于是对两类图元统一处理，既不会把无贴图图元刷成白色，也不会把贴图色平方变暗。
//   （诊断见 iron_tide/CHANGELOG_house_color.md）
//
// 注意：Godot 导入 SHP 索引 PNG 后会展开成 RGBA、丢失调色板索引，
//   因此只能按颜色判定，不能按索引号重映射。
// =====================================================================

uniform vec3 base_color : source_color = vec3(0.3411764706, 0.6588235294, 1.0);   // 盟军蓝 #57a8ff（素材烘焙色）
uniform vec3 target_color : source_color = vec3(0.3411764706, 0.6588235294, 1.0); // 目标阵营色
uniform float cos_tol : hint_range(0.9, 1.0) = 0.995;    // 方向匹配阈值（cos 夹角；0.995≈5.7°）
uniform float min_len : hint_range(0.0, 1.0) = 0.10;     // 亮度下限（近黑不改，方向不可靠）
uniform float strength : hint_range(0.0, 1.0) = 1.0;     // 混合强度（1 = 完全重映射）

uniform bool psi_lift = false;
uniform bool fracture_ink = false;
uniform bool temporal_active = false;
uniform float temporal_progress : hint_range(0.0, 1.0) = 0.0;
uniform float temporal_phase = 0.0;
uniform float c4_flash : hint_range(0.0, 1.0) = 0.0;
uniform float sapper_flash : hint_range(0.0, 1.0) = 0.0;
uniform int paint_mode = 0;
uniform bool hollywood_paint = false;
uniform int unit_skin = 0;
uniform float crystal_growth = 0.0;
uniform float signature_charge = 0.0;
uniform float armor_flash = 0.0;
varying vec2 skin_local;
varying vec4 draw_tint;
varying float sprite_tint;

void vertex() {
	draw_tint = COLOR;
	skin_local = VERTEX;
	// Colored UI primitives/text and shadows retain their ordinary appearance.
	sprite_tint = step(0.999, min(COLOR.r, min(COLOR.g, COLOR.b)));
}

// The retail Purple HSV sets an upper bound. Roll off the bright painted
// surfaces in Hollywood daylight, keeping dark markings distinct.
vec3 house_paint(float level) {
	if (!hollywood_paint) {
		return target_color * level;
	}
	float shade = clamp(level, 0.0, 1.0);
	float highlight = smoothstep(0.30, 1.0, shade);
	float peak = max(target_color.r, max(target_color.g, target_color.b));
	vec3 pigment = mix(target_color, vec3(peak), 0.27 * highlight);
	return pigment * shade * (1.0 - 0.18 * highlight);
}

void fragment() {
	vec4 src = COLOR;
	if (src.a <= 0.0) {
		COLOR = src;
	} else {
		vec3 rgb = src.rgb;
		float bb = max(dot(base_color, base_color), 0.0001);
		vec3 bn = base_color * inversesqrt(bb);
		float len = length(rgb);
		float lv = dot(rgb, base_color) / bb;
		float sim = -1.0;
		if (len > min_len) {
			sim = dot(rgb / len, bn);
		}
		// TNKD turbine draw uses a reserved vertex tint for its fixed blue exhaust.
		bool fixed_exhaust=distance(draw_tint.rgb,vec3(0.73,0.98,1.0))<0.01;
		if ((paint_mode >= 6 && paint_mode <= 10) && textureSize(TEXTURE, 0).x > 8) {
			// City sheets retain the original red ramp; ordinary hospital/shop sheets bake it blue.
			vec3 texel = texture(TEXTURE, UV).rgb;
			if (paint_mode >= 8 && length(texel) > min_len && dot(normalize(texel), bn) >= cos_tol) {
				rgb = house_paint(dot(texel, base_color) / bb) * draw_tint.rgb;
			} else if (paint_mode <= 8 && texel.r > 0.0 && texel.g == 0.0 && texel.b == 0.0) {
				rgb = house_paint(texel.r * 255.0 / 252.0) * draw_tint.rgb;
			} else if (paint_mode == 8 && texel.r >= 0.09 && texel.r >= texel.g && texel.g > texel.b && texel.r - texel.g < 0.075 && texel.g - texel.b < 0.12) {
				// Keep the brown panels visible beneath a light house-color wash.
				rgb = mix(texel, house_paint(texel.r), 0.20) * draw_tint.rgb;
			} else if ((paint_mode == 7 || paint_mode == 10) && texel.r >= 0.25 && texel.r - texel.b >= 0.06 && abs(texel.r - texel.g) <= 0.04) {
				// Hospital limestone palette, including its shaded face. Keep the red cross and glazing.
				rgb = mix(texel, house_paint(texel.r), 0.20) * draw_tint.rgb;
			}
		} else if (paint_mode == 4 && sprite_tint > 0.5 && textureSize(TEXTURE, 0).x > 8) {
			rgb = vec3(dot(rgb, vec3(0.299, 0.587, 0.114)));
		} else if (paint_mode >= 1 && paint_mode <= 3 && textureSize(TEXTURE, 0).x > 8) {
			// Match the unlit atlas pixel. The dive tint changes hue before fragment COLOR is read.
			vec3 texel = texture(TEXTURE, UV).rgb;
			float shade = dot(texel, base_color) / bb;
			bool band = length(texel) > min_len && dot(normalize(texel), bn) >= cos_tol;
			if (paint_mode == 2) {
				// SQDG has no house ramp. ANIM.PAL 175 and 180 paint the red tentacle markings.
				band = distance(texel, vec3(204,48,68)/255.0) < 0.012 || distance(texel, vec3(204,44,40)/255.0) < 0.012;
				shade = texel.r;
			}
			if (band) {
				// Voxel hulls keep the baked ramp shading. SQD artwork uses a lifted ramp.
				float value = paint_mode == 3 ? shade : 0.25 + 0.75 * shade;
				rgb = house_paint(value) * max(draw_tint.r, max(draw_tint.g, draw_tint.b));
			}
		} else if (paint_mode == 0 && !fixed_exhaust && sim >= cos_tol && lv > 0.0 && (unit_skin < 6 || textureSize(TEXTURE,0).x > 8)) {
			vec3 paint = textureSize(TEXTURE, 0).x > 8 ? house_paint(lv) : target_color * lv;
			rgb = mix(rgb, paint, strength);
		}
		if (unit_skin >= 2 && sprite_tint > 0.5 && textureSize(TEXTURE,0).x > 8 && sim < cos_tol && len > 0.12) {
			float light = dot(rgb,vec3(0.299,0.587,0.114));
			if (unit_skin == 10 || unit_skin == 11) {
				// Hero exoframes retain the stock pixel-lighting and house ramp.
				vec3 low = unit_skin == 10 ? vec3(0.10,0.17,0.23) : vec3(0.075,0.09,0.12);
				vec3 high = unit_skin == 10 ? vec3(0.72,0.84,0.89) : vec3(0.40,0.45,0.50);
				rgb=mix(rgb,mix(low,high,smoothstep(0.06,0.65,light)),0.82);
			} else if (unit_skin == 4) {
				// Use the original voxel lighting so plate edges stay attached through turns.
				vec3 glaze = mix(vec3(0.045,0.105,0.24),vec3(0.14,0.36,0.63),smoothstep(0.08,0.33,light));
				glaze = mix(glaze,vec3(0.91,0.95,0.95),smoothstep(0.22,0.39,light));
				rgb = mix(rgb,glaze,0.88);
				vec2 p = skin_local;
				vec2 grid = vec2(p.x * 0.14 + p.y * 0.08,p.y * 0.23);
				vec2 tile = fract(grid);
				float facets = fract(dot(floor(grid),vec2(0.37,0.61)) + step(1.0,tile.x+tile.y)*0.42);
				float shine = smoothstep(0.32,0.74,light + facets*0.31);
				vec3 ice = mix(vec3(0.055,0.38,0.56),vec3(0.62,0.99,1.0),shine);
				ice += vec3(0.13,0.18,0.20)*(1.0-smoothstep(0.0,0.09,abs(tile.x+tile.y-1.0)))*shine;
				rgb = mix(rgb,ice,crystal_growth);
			} else if (unit_skin == 5) {
				vec3 steel = mix(vec3(0.055,0.065,0.08),vec3(0.30,0.25,0.24),smoothstep(0.1,0.55,light));
				vec3 copper = mix(vec3(0.64,0.21,0.055),vec3(1.0,0.70,0.32),smoothstep(0.40,0.64,light));
				rgb = mix(rgb,mix(steel,copper,smoothstep(0.28,0.44,light)),0.92);
				float band = 1.0-smoothstep(0.0,5.0,abs(skin_local.x+skin_local.y*0.45-mix(-34.0,34.0,1.0-armor_flash)));
				rgb = mix(rgb,vec3(0.83,0.94,1.0),band*sin(armor_flash*3.14159)*0.9);
			} else if (unit_skin >= 6 && unit_skin <= 9) {
				vec3 shade, mid, edge;
				if (unit_skin == 6) {
					shade=vec3(0.055,0.07,0.10); mid=vec3(0.23,0.25,0.29); edge=vec3(0.91,0.71,0.37);
				} else if (unit_skin == 7) {
					shade=vec3(0.06,0.10,0.13); mid=vec3(0.23,0.37,0.40); edge=vec3(0.82,0.85,0.76);
				} else if (unit_skin == 8) {
					shade=vec3(0.13,0.12,0.085); mid=vec3(0.93,0.68,0.065); edge=vec3(1.0,0.94,0.39);
				} else {
					shade=vec3(0.085,0.14,0.22); mid=vec3(0.49,0.59,0.66); edge=vec3(0.94,0.96,0.92);
				}
				vec3 finish=mix(shade,mid,smoothstep(0.04,0.34,light));
				rgb=mix(rgb,mix(finish,edge,smoothstep(0.32,0.70,light)),0.91);
				if (unit_skin == 8) {
					// Keep continuous baked voxel relief (including tread recesses).
					float relief=clamp(light*1.45,0.0,1.0);
					vec3 graphite=vec3(0.11,0.13,0.14)*(0.42+light*2.6);
					vec3 enamel=mix(vec3(0.46,0.29,0.06),vec3(1.0,0.91,0.27),relief);
					rgb=mix(graphite,enamel,smoothstep(0.09,0.30,light));
					rgb+=vec3(0.18,0.21,0.25)*smoothstep(0.50,0.9,light);
				}
				if (unit_skin == 8 && signature_charge > 0.0) {
					// A soft capacitive sheen follows the baked plate highlights.
					float edge_light=smoothstep(0.20,0.64,light)*signature_charge;
					rgb=mix(rgb,vec3(1.0,0.96,0.54),edge_light*0.38);
				} else if (unit_skin == 6 && signature_charge > 0.0) {
					float facets=fract(skin_local.x*0.062+abs(fract(skin_local.y*0.091)-0.5));
					float glint=(1.0-smoothstep(0.0,0.085,abs(facets-0.5)))*smoothstep(0.14,0.58,light);
					rgb=mix(rgb,vec3(0.98,0.74,0.36),glint*signature_charge*0.67);
				}
			} else if (unit_skin == 3) {
				// Lift the shaded metal without flattening the baked voxel and SHP lighting.
				float mid = smoothstep(0.06, 0.45, light);
				vec3 steel = mix(vec3(0.12, 0.22, 0.29), vec3(0.52, 0.68, 0.72), mid);
				steel = mix(steel, vec3(0.88, 0.94, 0.93), smoothstep(0.4, 0.85, light));
				float stripe = fract((skin_local.x + skin_local.y * 0.7) / 24.0);
				float reflector = smoothstep(0.78, 0.83, stripe) * (1.0 - smoothstep(0.93, 0.98, stripe));
				vec3 amber = mix(vec3(0.52, 0.28, 0.065), vec3(1.0, 0.82, 0.38), mid);
				rgb = mix(rgb, mix(steel, amber, reflector), 0.86);
			} else {
				vec2 p = skin_local;
				float stripe = sin(p.x * 0.38 + p.y * 0.22 + 1.6 * sin(p.y * 0.47));
				vec3 pattern = mix(vec3(0.47,0.60,0.66),vec3(0.91,0.94,0.92),step(-0.15,stripe));
				rgb = mix(rgb, pattern * (0.3 + dot(rgb,vec3(0.299,0.587,0.114))),0.74);
			}
		}
		// The two dedicated ghost draw commands carry cyan ink in their vertex tint.
		if (fracture_ink && abs(draw_tint.g - 0.96) < 0.003 && draw_tint.b > 0.99
				&& (abs(draw_tint.r - 0.45) < 0.003 || abs(draw_tint.r - 0.82) < 0.003)) {
			float relief = dot(texture(TEXTURE,UV).rgb,vec3(0.299,0.587,0.114));
			rgb = mix(draw_tint.rgb * 0.55,vec3(0.94,1.0,1.0),smoothstep(0.18,0.72,relief));
		}
		float alpha = src.a;
		if (temporal_active && sprite_tint > 0.5 && textureSize(TEXTURE, 0).x > 8 && len > 0.12) {
			float light = dot(rgb, vec3(0.299, 0.587, 0.114));
			float band = 0.5 + 0.5 * sin(UV.y / TEXTURE_PIXEL_SIZE.y * 0.65 + temporal_phase);
			vec3 frozen = vec3(0.502, 0.784, 1.0) * (0.4 + light * 0.75 + band * 0.12);
			rgb = mix(rgb, frozen, 0.85);
			alpha *= 1.0 - temporal_progress * 0.9;
		}
		if (c4_flash > 0.0 && sprite_tint > 0.5 && textureSize(TEXTURE, 0).x > 8 && len > 0.12) {
			float light = dot(rgb, vec3(0.299, 0.587, 0.114));
			rgb = mix(rgb, vec3(0.45 + light * 0.7, light * 0.12, light * 0.07), c4_flash * 0.85);
		}
		// Extra light on textured vehicle art only; leave black shadows and UI alone.
		if (sapper_flash > 0.0 && textureSize(TEXTURE, 0).x > 8 && length(draw_tint.rgb) > 0.12) {
			rgb = min(rgb * (1.0 + sapper_flash), vec3(1.0));
		}
		if (psi_lift) {
			vec2 step_uv = TEXTURE_PIXEL_SIZE * 2.0;
	vec2 slope = vec2(texture(TEXTURE, UV + vec2(step_uv.x,0.0)).a - texture(TEXTURE, UV - vec2(step_uv.x,0.0)).a,
		texture(TEXTURE, UV + vec2(0.0,step_uv.y)).a - texture(TEXTURE, UV - vec2(0.0,step_uv.y)).a);
	float rim = pow(clamp(length(slope),0.0,1.0),4.0);
			rgb += vec3(2.0,2.0,10.0)*rim*0.65;
		}
		COLOR = vec4(rgb, alpha);
	}
}
