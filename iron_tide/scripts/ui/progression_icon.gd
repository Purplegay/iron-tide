extends RefCounted
## Native vector silhouettes for training, research and card upgrades.
const PATHS := {
	"school_diary":"M5 3H20V21H5Q3 21 3 19V5Q3 3 5 3ZM7 3V20M12 3V12L15 10L18 12V3M10 16H17",
	"school_fragment":"M4 3H15L12 7L15 9L9 14L12 15L6 21H4ZM7 6H10M7 9H9M18 8L21 10V21H11L16 16L14 14L19 11Z",
	"yuriko_cola":"M8 2H15V5L14 7V9L17 13V21H6V13L9 9V7L8 5ZM7 14H16M7 18H16",
	"yuriko_uniform":"M8 3L12 5L16 3L21 7L18 12L16 11V21H8V11L6 12L3 7ZM8 3L12 10L16 3M12 10V20",
	"yuriko_ticket":"M3 6H21V10Q17 12 21 14V18H3V14Q7 12 3 10ZM15 7V10M15 13V17",
	"banner":"M5 22V3M5 4Q9 1 13 4T21 4L19 9L21 13Q17 16 13 13T5 13",
	"compass":"M12 2A10 10 0 1 0 12 22A10 10 0 1 0 12 2ZM17 7L14 14L7 17L10 10Z",
	"folder":"M2 18V5H9L12 8H20V11M3 19L6 11H22L19 19Z",
	"handbook":"M12 6Q7 3 2 5V19Q7 17 12 20Q17 17 22 19V5Q17 3 12 6V20",
	"fort":"M3 21V5H7V9H10V5H14V9H17V5H21V21ZM9 21V16Q12 12 15 16V21",
	"research_tree":"M9 2H15V8H9ZM12 8V12M5 16V12H19V16M2 16H8V22H2ZM16 16H22V22H16Z",
	"roller":"M3 3H17V9H3ZM17 6H21V13H11V16M9 16H13V22H9Z",
	"sliders":"M3 7H7M12 7H21M7 4H12V10H7ZM3 17H14M19 17H21M14 14H19V20H14Z",
	"console":"M2 4H22V20H2ZM5 8L9 12L5 16M12 16H18",
	"exit_door":"M12 3H3V21H12M9 12H22M16 6L22 12L16 18",
	"crew_list":"M2 12H12V19H2ZM3 12L6 8H10L12 12M14 3H22V16H14ZM16 6H20M16 9H20M16 12H18M6 21H9",
	"mirror_turrets":"M2 16H10V20H2ZM4 16V11H8V16M6 11L2 7M14 16H22V20H14ZM16 16V11H20V16M18 11L22 7M9 4L12 7L15 4",
	"ore_press":"M2 3H17V6H12V10H7V6H2ZM4 11H14L12 14H6ZM5 18H14V21H5ZM15 14L19 11L22 15L18 18Z",
	"heat_gauge":"M2 16L15 4L18 7L5 20ZM10 17H12V21H10ZM15 14H17V21H15ZM20 10H22V21H20Z",
	"expedition_map":"M3 19V5L9 3L16 6L21 4V18L15 21L9 18ZM7 14L11 10L15 13L18 9",
	"draw_cards":"M3 5L12 2L16 6M6 19L2 8M8 7H21V22H8ZM14 10L17 14L14 18L11 14Z",
	"unit_training":"M2 18H18L21 14H6ZM6 13V9H14L17 13M12 9V6H21M3 5L6 2L9 5",
	"army_exclusion":"M12 3A9 9 0 1 0 12 21A9 9 0 1 0 12 3ZM7 12H17",
	"lock":"M5 10H19V21H5ZM8 10V6A4 4 0 0 1 16 6V10M12 14V17",
	"vehicle":"M3 13H21V19H3ZM5 13V9H15L17 13M10 9V5H17M15 6H23M6 16H8M11 16H13M16 16H18",
	"air":"M12 2L14 10L22 15V17L14 14V19L17 21H7L10 19V14L2 17V15L10 10Z",
	"infantry":"M8 7A4 4 0 1 0 16 7A4 4 0 1 0 8 7M5 21V15L9 12H15L19 15V21M9 15V21M15 15V21",
	"defense":"M3 21V9H7V5H11V9H15V5H19V9H21V21ZM8 21V15H16V21",
	"electric":"M14 2L4 14H11L9 22L21 9H14Z",
	"hightech":"M12 2L21 7V17L12 22L3 17V7ZM12 6L17 12L12 18L7 12ZM3 7L7 12M21 17L17 12",
	"naval":"M2 15H22L18 21H6ZM6 15V9H17V15M10 9V3H14V9",
	"antiair":"M3 21L12 12L21 21M12 12V4M6 8L12 2L18 8M2 12H7M17 12H22",
	"explosive":"M7 9A8 8 0 1 0 18 11L19 7L14 4L10 7ZM16 4L18 1M20 5H23",
	"heavy":"M2 14H22V21H2ZM5 14V9H19V14M8 9V2M16 9V2M6 18H10M14 18H18",
	"tactics":"M3 3H21V21H3ZM6 17L10 10L14 14L19 6",
	"smoke":"M5 19Q0 18 3 13Q0 7 7 7Q9 0 15 5Q23 3 21 11Q26 17 20 19ZM7 22H17",
	"exclusive":"M12 2L15 8L22 9L17 14L18 21L12 18L6 21L7 14L2 9L9 8Z",
	"reverse":"M20 5L11 12L20 19M12 5L3 12L12 19",
	"hourglass":"M5 3H19L17 8L12 12L17 16L19 21H5L7 16L12 12L7 8Z",
	"reload":"M20 8A9 9 0 1 0 21 15M20 2V8H14M12 6V12L16 14",
	"fracture":"M2 7H9L7 12H12L9 17H2ZM13 4H22V15H14L17 10H12Z",
	"sample":"M4 17V12H7V17ZM10 17V8H13V17ZM16 17V4H19V17Z",
	"rad_growth":"M12 10A2 2 0 1 0 12 14A2 2 0 1 0 12 10M7 7Q2 12 7 17M17 7Q22 12 17 17M4 3Q-4 12 4 21M20 3Q28 12 20 21",
	"sight":"M3 12Q12 1 21 12Q12 23 3 12ZM12 9A3 3 0 1 0 12.1 9",
	"attack":"M4 19L16 7L18 9L6 21ZM13 5L21 3L19 11Z",
	"escort":"M12 4L16 6V10L12 14L8 10V6ZM8 20V17L12 15L16 17V20M2 17V14L5 12L7 13M17 13L19 12L22 14V17",
	"guard":"M12 3L20 6V12Q19 18 12 21Q5 18 4 12V6Z",
	"heart":"M12 20L4 12Q0 3 8 4L12 8L16 4Q24 3 20 12Z",
	"speed":"M3 7L10 12L3 17M11 7L18 12L11 17",
	"build":"M3 19H21V10L15 13V8L9 11V5H5Z",
	"coin":"M12 3L21 8V16L12 21L3 16V8ZM12 7V17",
	"supply_crate":"M2 8L12 3L22 8V17L12 22L2 17ZM2 8L12 13L22 8M12 13V22M7 5.5L17 10.5V14",
	"queue":"M3 6H14M3 11H17M3 16H20",
	"split":"M12 20V12L5 6M12 12L19 6M4 10V5H9M15 5H20V10",
	"focus":"M4 9V4H9M15 4H20V9M20 15V20H15M9 20H4V15M9 12H15M12 9V15",
	"spark":"M14 2L5 13H11L9 22L20 10H14Z",
	"heal":"M9 3H15V9H21V15H15V21H9V15H3V9H9Z",
	"rank":"M3 15L12 5L21 15M5 20L12 12L19 20",
	"dual_pistols":"M2 6H10V10H6V17H3V9H2ZM14 6H22V9H21V17H18V10H14ZM10 20L12 17L14 20",
	"triple_charge":"M2 10H7V18H2ZM10 7H15V15H10ZM18 10H23V18H18ZM4 10V6M12 7V3M20 10V6",
	"breach_rhythm":"M2 13H6L9 5L13 20L16 10H22M17 4L21 6L17 8",
	"red_coordinates":"M3 4H21V20H3ZM7 12H17M12 7V17M9 9L15 15M15 9L9 15",
	"red_corridor":"M3 5L21 19M4 18L8 8M10 21L14 11M16 23L20 13",
	"receipt_stamp":"M4 3H20V21H4ZM8 7H16M8 11H16M8 15H12M14 16L16 18L21 12",
	"falcon_missiles":"M5 4L9 10L7 12L2 8M19 4L15 10L17 12L22 8M12 5V14M9 11L12 15L15 11M8 19H10M14 19H16M12 17V21",
	"air_rearm":"M8 9H16V20H8ZM8 13H16M12 9V20M2 14L5 17V11M22 14L19 17V11M5 7Q12 0 19 7M15 6L19 7L18 3",
	"copper_coil":"M5 20H19M7 20V8M17 20V8M5 8H19M6 12H18M6 16H18M8 4L10 7L12 2L14 7L16 4",
	"tri_pole_court":"M10 3H14V7H10ZM2 18H6V22H2ZM18 18H22V22H18ZM10 7L5 18M14 7L19 18M6 20H18M13 9L10 14H14L11 18",
	"charge_dispatch":"M11 2L7 10H12L10 15L17 7H12L15 2ZM10 15L5 19M12 15L19 19M2 18H6V22H2ZM18 18H22V22H18Z",
}
const HERO_GLYPHS := {
	"yinpian_contract":"crew_list","laocheng_contract":"ore_press","ap_convoy_crew":"crew_list","ps_convoy_mirror":"mirror_turrets","ap_convoy_press":"ore_press","ps_convoy_heat":"heat_gauge",
	"peregrine_contract":"air", "ap_peregrine_hunt":"falcon_missiles", "ps_peregrine_rearm":"air_rearm",
	"leizhu_contract":"copper_coil", "ap_leizhu_court":"tri_pole_court", "ps_leizhu_charge":"charge_dispatch",
	"watch_contract":"escort", "ap_watch_posts":"defense", "ps_watch_succession":"rank",
	"north_contract":"focus", "ap_north_twin":"split", "ps_north_echo":"reload",
	"spine_contract":"heavy", "ap_spine_crown":"guard", "ps_spine_scrap":"build",
	"tanya_contract":"dual_pistols", "ap_tanya_breach":"triple_charge", "ps_tanya_rhythm":"breach_rhythm",
	"boris_contract":"red_coordinates", "ap_boris_corridor":"red_corridor", "ps_boris_receipt":"receipt_stamp",
}
static var shimmer: ShaderMaterial

static func shine(icon: CanvasItem) -> void:
	if shimmer==null:
		var shader:=Shader.new()
		shader.code="shader_type canvas_item; void fragment(){vec4 c=texture(TEXTURE,UV);float band=max(0.,1.-abs(fract(TIME*.32)*2.-UV.x-UV.y)*7.);float gold=smoothstep(.4,.8,c.r)*smoothstep(.2,.6,c.g);COLOR=vec4(c.rgb+vec3(.38,.29,.13)*band*gold,c.a);}"
		shimmer=ShaderMaterial.new()
		shimmer.shader=shader
	icon.material=shimmer

static var cache := {}
static func texture(id: String) -> Texture2D:
	if cache.has(id): return cache[id]
	if id in ["furnace_contract","ap_furnace_bastion","ps_furnace_flak"] or HERO_GLYPHS.has(id):
		var core: String = {"furnace_contract":"M21 18H42L39 41H18Z M23 25H35 M22 30H32 M21 35H29","ap_furnace_bastion":"M32 13L44 20V29Q42 39 32 45Q22 39 20 29V20Z M32 21V36 M26 28H38","ps_furnace_flak":"M16 38H28V42H16Z M36 38H48V42H36Z M21 36L28 21 M41 36L47 21 M29 16L32 12L35 16L32 20Z"}.get(id,"")
		var core_svg:='<path d="%s" fill="none" stroke="#fff0a5" stroke-width="3"/>'%core
		if HERO_GLYPHS.has(id):
			core_svg='<path transform="translate(19 15) scale(1.08)" d="%s" fill="none" stroke="#fff0a5" stroke-width="2.5" stroke-linejoin="round"/>'%PATHS[HERO_GLYPHS[id]]
		var dragon := '<path d="M31 58Q11 57 7 44Q3 35 10 27Q6 39 14 42L11 34L16 37Q11 27 15 21L11 24L8 19L11 14L8 10L15 12L20 5L19 13L25 12L22 17L17 19Q12 27 20 37Q26 46 15 47Q20 53 31 53Z" fill="url(#gold)" stroke="#754215" stroke-width="1"/><circle cx="16" cy="15" r="1.4" fill="#fff9c6"/>'
		var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64"><defs><linearGradient id="gold" x2="0.45" y2="1"><stop stop-color="#fffac2"/><stop offset=".4" stop-color="#ffd15a"/><stop offset=".7" stop-color="#bc7026"/><stop offset="1" stop-color="#ffe29a"/></linearGradient></defs><rect x="2" y="2" width="60" height="60" rx="12" fill="#261b19" stroke="#bb8334" stroke-width="2"/>%s%s<g transform="translate(64 0) scale(-1 1)">%s</g><path d="M32 1L34 5L38 6L34 8L32 12L30 8L26 6L30 5Z" fill="#fffadd"/></svg>' % [core_svg,dragon,dragon]
		var badge:=Image.new()
		if badge.load_svg_from_string(svg)!=OK:return null
		cache[id]=ImageTexture.create_from_image(badge)
		return cache[id]
	var glyph: String = id if PATHS.has(id) else "spark"
	for pair in [["hero_command","sight"],["split","split"],["fire_control","focus"],["optics","sight"],["armor","guard"],["def","guard"],["atk","attack"],["hp","heart"],["speed","speed"],["build","build"],["income","coin"],["cap","queue"],["queue","queue"],["repair","heal"],["miner","coin"],["hero_escort","escort"],["hero_survival","guard"],["hero","rank"],["heal","heal"],["flank","speed"],["focus","focus"],["bayonet","attack"],["evade","speed"]]:
		if id.contains(pair[0]):
			glyph = pair[1]
			break
	var exclusive_glyphs := {"auto_w":"focus","ps_chrono_commission":"rank","ps_chrono_sabotage":"hourglass","reaper_split_fire":"split","ap_tesla_chain":"split","ap_decoy":"split","ps_phase":"spark","ap_twin":"focus","ps_limiter":"speed","ap_buoy":"sight","ps_contact":"queue","ap_slope":"guard","ps_barrage":"attack"}
	glyph=exclusive_glyphs.get(id,glyph)
	if id == "joint_ra2_production": glyph = "build"
	if id == "superweapon_damage_1": glyph = "explosive"
	glyph={"grizzly_reverse":"reverse","chrono_bookmark":"hourglass","rhino_split":"fracture","deso_expansion":"rad_growth","tesla_reserve":"spark","ap_shock_pulse":"rad_growth","ps_grounding":"focus","ps_aftercurrent":"speed"}.get(id,glyph)
	glyph={"ap_escort_water":"guard","ap_gun_ballast":"reload","ps_low_observation":"sight","hover_sighting":"focus","ps_sea_air_crossfire":"split","intercept_ranging":"focus","ps_depth_pressure":"guard","wake_fork":"split"}.get(id,glyph)
	glyph={"ps_impact_calibration":"focus","ps_convoy_repair":"heal"}.get(id,glyph)
	glyph={"ps_shore_reserve":"smoke","ps_evacuation_escort":"escort"}.get(id,glyph)
	glyph={"ps_last_calibration":"focus","ps_burning_payload":"explosive","full_sortie":"attack","escort_magazine":"guard","ap_overload_seal":"spark","ap_tractor_warhead":"explosive"}.get(id,glyph)
	var effect_glyph:String=glyph
	effect_glyph={"ap_bilge_repair":"heal","ps_anchor_reload":"reload","ap_wing_guard":"guard","ps_cruise_scout":"sight","ap_smoke":"smoke","ap_overdrive":"speed","ap_focus_fire":"reload","ps_armor_plating":"guard","ps_hollow_point":"attack"}.get(id,effect_glyph)
	var card:=GameData.get_skill(id)
	var scope:String=str(card.get("scope_icon",""))
	if PATHS.has(scope):glyph=scope
	var hash_id := id.hash()
	var color := Color.from_hsv(float(hash_id % 360)/360.0,0.58,1).to_html(false)
	color={"lock":"ffd166","expedition_map":"8ae7ab","draw_cards":"d6a3ff","unit_training":"ffca74"}.get(id,color)
	color={"vehicle":"ffbe76","air":"77caff","infantry":"91e891","defense":"a8bacf","electric":"ffe467","hightech":"7ff5ed","naval":"73b8ff","antiair":"c4e87b","explosive":"ff9275","heavy":"cf9aff"}.get(scope,color)
	if card.has("rarity"):color=preload("res://scripts/rules/skill_scope.gd").rarity_color(card).to_html(false)
	var ticks := ""
	for i in 6:
		if (hash_id >> i) & 1: ticks += '<rect x="%d" y="25" width="2" height="2" fill="#%s"/>' % [3+4*i,color]
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="28" height="28"><rect x="1" y="1" width="26" height="26" rx="5" fill="#172130" stroke="#%s"/><path transform="translate(2 1)" d="%s" fill="none" stroke="#%s" stroke-width="2" stroke-linejoin="round"/>%s</svg>' % [color,PATHS[glyph],color,ticks]
	if preload("res://scripts/rules/skill_scope.gd").exclusive(card):
		svg=svg.replace("</svg>",'<path transform="translate(16 0) scale(.48)" d="%s" fill="#ffd166" stroke="#30220d" stroke-width="2"/></svg>' % PATHS.exclusive)
	if not scope.is_empty():
		# Context is the large silhouette; the effect remains a small lower badge.
		svg=svg.replace("</svg>",'<rect x="17" y="17" width="11" height="11" rx="3" fill="#172130"/><path transform="translate(18 18) scale(.36)" d="%s" fill="none" stroke="#ffffff" stroke-width="2.5"/></svg>' % PATHS[effect_glyph])
		var categories:Array=card.get("allowed_categories",[]).filter(func(kind):return kind!=scope)
		if not categories.is_empty() and PATHS.has(categories[0]):
			svg=svg.replace("</svg>",'<rect x="17" y="0" width="11" height="11" rx="3" fill="#172130"/><path transform="translate(18 1) scale(.36)" d="%s" fill="none" stroke="#a8e5ff" stroke-width="2.5"/></svg>' % PATHS[categories[0]])
	var image := Image.new()
	if image.load_svg_from_string(svg) != OK: return null
	var result := ImageTexture.create_from_image(image)
	cache[id] = result
	return result
