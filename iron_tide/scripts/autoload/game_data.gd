extends Node
## 数据仓库：加载 data/ 下的所有 JSON，并对外提供按 id 查询的接口。
## 所有可以被 GM 面板 / 数据编译器修改的内容都集中在这里。

const DATA_DIR := "res://data/"

const REQUIRED_RA2_DOCUMENTS := ["ra2_allied.json", "ra2/warheads.json", "ra2/general.json", "ra2/economy.json", "ra2/units.json", "ra2/buildings.json", "ra2/factions.json", "ra2/weapons.json", "ra2/projectiles.json", "ra2/animations.json", "ra2/sound_specs.json", "ra2/sfx_index.json", "ra2/eva_specs.json", "ra2/eva_index.json"]

func missing_battle_resources() -> PackedStringArray:
	var missing := PackedStringArray()
	for document in REQUIRED_RA2_DOCUMENTS:
		if raw_docs.get(document, {}).is_empty():
			missing.append(DATA_DIR + document)
	var textures := ["ui/top-0", "ui/soviet/top-0"]
	for kind in ["ore", "gems"]:
		for variant in range(1, 4):
			textures.append("resources/%s-%d" % [kind, variant])
	for texture in textures:
		var path := "res://assets/ra2/%s.png" % texture
		if not ResourceLoader.exists(path):
			missing.append(path)
	return missing

var yr_production_rules: Dictionary = {}
var hollywood_cast: Dictionary = {}
var hollywood_yuri: Dictionary = {}
var yr_baseline: Dictionary = {}

var units: Array[Dictionary] = []
var buildings: Array[Dictionary] = []
var factions: Array[Dictionary] = []
var missions: Array[Dictionary] = []
var combat_matrix: Dictionary = {}
var combat_attack_types: Array = []
var combat_armor_types: Array = []
var combat_labels: Dictionary = {}
var meta_config: Dictionary = {}
var cards: Dictionary = {}
var skills: Array[Dictionary] = []        # 技能库（skills.json）
var skill_slots: Dictionary = {}           # { active: 4, passive: 1 }
var skill_defaults: Dictionary = {}        # 单位 id -> 默认技能配置
var skill_index: Dictionary = {}           # 技能 id -> Dictionary
var skill_unlock: Dictionary = {}          # 技能获取口径（base 通用 / gacha 抽取）
var skill_draw: Dictionary = {}            # 技能抽取规则（货币 / 价格 / 稀有度权重）
var endless_scaling: Dictionary = {}
var raw_docs: Dictionary = {}         # 文件名 -> 原始 JSON 文档（后台可视化编辑器直接读写）
var progression_tuning=preload("res://scripts/admin/progression_tuning.gd").new()

var unit_index: Dictionary = {}       # id -> Dictionary
var building_index: Dictionary = {}   # id -> Dictionary
var faction_index: Dictionary = {}    # id -> Dictionary
var mission_index: Dictionary = {}    # id -> Dictionary

var allied_capabilities: Dictionary = {}
var capability_weapon_cache: Dictionary = {}

func _ready() -> void:
	reload()

## 从磁盘重新读取全部配置（GM 面板热重载用）
func reload() -> void:
	capability_weapon_cache.clear()
	raw_docs.clear()
	units.clear(); buildings.clear(); factions.clear(); missions.clear()
	skills.clear(); skill_index.clear()
	unit_index.clear(); building_index.clear(); faction_index.clear(); mission_index.clear()

	hollywood_yuri = _load_json("hollywood_yuri.json")
	hollywood_cast = _load_json("hollywood_cast.json")
	hollywood_yuri.units.merge(hollywood_cast.units)
	hollywood_yuri.buildings.merge(hollywood_cast.buildings)
	hollywood_yuri.buildings.YAWEAP.builds = ["YTNK", "LTNK"]
	hollywood_yuri.buildings.YABRCK.builds = ["INIT", "YURI", "YENGINEER"]
	var unit_doc := _load_json("units.json")
	units = _as_dict_array(unit_doc.get("units", []))
	buildings = _as_dict_array(unit_doc.get("buildings", []))
	for u in units:
		unit_index[str(u.get("id", ""))] = u
	for b in buildings:
		building_index[str(b.get("id", ""))] = b
	building_index["CAOUTP"]={"id":"CAOUTP","name":"科技前哨站","role":"structure","cost":0,"build_time":1,"hp":2000,"armor":"structure","radius":72,"sight":550,"tags":["structure"],"foundation":"4x3","builds":[],"ra2":true}

	var fac := _load_json("factions.json")
	factions = _as_dict_array(fac.get("factions", []))
	for f in factions:
		faction_index[str(f.get("id", ""))] = f

	var cmb := _load_json("combat.json")
	combat_matrix = cmb.get("multipliers", {})
	combat_attack_types = cmb.get("attack_types", [])
	combat_armor_types = cmb.get("armor_types", [])
	combat_labels = cmb.get("labels", {})

	meta_config = _load_json("meta.json")

	var wv := _load_json("waves.json")
	missions = _as_dict_array(wv.get("missions", []))
	endless_scaling = wv.get("endless_scaling", {})
	for m in missions:
		mission_index[str(m.get("id", ""))] = m

	cards = _load_json("cards.json")

	var sk := _load_json("skills.json")
	skills = _as_dict_array(sk.get("skills", []))
	skill_slots = sk.get("slots", {})
	skill_defaults = sk.get("defaults", {})
	skill_unlock = sk.get("unlock", {})
	skill_draw = skill_unlock.get("draw", {})
	for s in skills:
		if s.has("rank_text"): s.desc=preload("res://scripts/rules/academy.gd").skill_description(s,0)
		skill_index[str(s.get("id", ""))] = s
	_load_ra2_allied()
	_load_ra2_rules()
	_load_yr_allied()
	_load_yr_pack("yr_strategic_fx.json")
	_load_yr_pack("hollywood_combat.json")
	var head_games := _load_json("head_games.json")
	hollywood_yuri.units.merge(head_games.units)
	hollywood_yuri.units["COW"]=preload("res://data/head_games_orders.json").data.cow
	hollywood_yuri.buildings.merge(head_games.buildings)
	hollywood_yuri.buildings.merge(preload("res://data/head_games_sites.json").data.powers)
	for id in head_games.warheads: ra2_warheads[str(id).to_lower()] = head_games.warheads[id]
	ra2_art.merge(raw_docs["hollywood_combat.json"].art)
	ra2_art.merge(_load_json("head_games_icons.json"))
	_load_yr_pack("yr_yuri.json")
	for id in ["YAGNTC","YAPPET"]:
		hollywood_yuri.buildings[id].superweapon=building_index[id].superweapon.duplicate(true)
	_apply_yr_baseline()
	# Fill missing death-only warheads without replacing existing combat catalogs.
	for id in _load_json("ra2/death.json").get("warheads", {}):
		if not ra2_warheads.has(str(id).to_lower()): ra2_warheads[str(id).to_lower()] = raw_docs["ra2/death.json"].warheads[id]
	_load_yr_pack("ra3_mirage.json")
	_load_yr_pack("ra3_expansion.json")
	_load_yr_pack("ra3_soviet.json")
	_load_yr_pack("ra3_reaper_sounds.json")
	_load_yr_pack("ra3_tank_sounds.json")
	_load_yr_pack("ra3_yuriko_sounds.json")
	# Deployment-only object: registered for placement and saves, outside the construction list.
	building_index["R3REAPERTURRET"]=raw_docs["ra3_soviet.json"].emplacement
	ra2_art["R3REAPERTURRET"]=ra2_art.R3REAPER
	for id in STOLEN_INFANTRY:
		ra2_prereq[id] = ["BARRACKS"]
	yr_production_rules = _load_json("yr_production.json").get("units", {})
	allied_capabilities = _load_json("ra2/allied_capabilities.json") if FileAccess.file_exists(DATA_DIR + "ra2/allied_capabilities.json") else {}
	for pair in [["weapons", ra2_weapons], ["warheads", ra2_warheads], ["projectiles", ra2_projectiles]]:
		for id in allied_capabilities.get(pair[0], {}):
			pair[1][str(id).to_lower()] = allied_capabilities[pair[0]][id]

	preload("res://scripts/rules/expansion_catalog.gd").install(self)
	progression_tuning.install(self)
	preload("res://scripts/rules/hollywood_heroes.gd").install_catalog(self)
	var yuriko := _load_json("yuriko.json")
	yuriko.unit.voice=raw_docs["ra3_yuriko_sounds.json"].voice
	unit_index["YURIKO"] = yuriko.unit
	ra2_art["YURIKO"] = {"cameo":"res://assets/ra3/yuriko/Portrait_Japan_Yuriko_01.png"}
	rebuild_static_combat_rules()

## Scoped YR additions. Prefixed combat/audio IDs preserve original RA2 definitions.
func _load_yr_allied() -> void:
	for filename in ["yr_allied.json", "yr_robot.json", "yr_fortress.json", "yr_soviet.json"]:
		_load_yr_pack(filename)
	ra2_art.DOG.cameo = "res://assets/ra2/cameo/ADOGICON.png"

func _load_yr_pack(filename: String) -> void:
	if not FileAccess.file_exists(DATA_DIR + filename):
		return
	var pack := _load_json(filename)
	for entry in _as_dict_array(pack.get("units", [])):
		var id := str(entry.get("id", ""))
		if id.is_empty() or unit_index.has(id):
			continue
		units.append(entry)
		unit_index[id] = entry
		ra2_ids.append(id)
		ra2_prereq[id] = pack.get("production_prerequisites", {}).get(id, entry.get("ra2_prereq", []))
		ra2_source_units[id] = pack.get("source_units", {}).get(id, {})
		ra2_art[id] = pack.get("art", {}).get(id, {})
	for entry in _as_dict_array(pack.get("buildings", [])):
		var id := str(entry.get("id", ""))
		if id.is_empty() or building_index.has(id):
			continue
		buildings.append(entry)
		building_index[id] = entry
		ra2_ids.append(id)
		ra2_prereq[id] = entry.get("ra2_prereq", [])
		ra2_source_buildings[id] = pack.get("source_buildings", {}).get(id, {})
		ra2_art[id] = pack.get("art", {}).get(id, {})
	for pair in [["weapons", ra2_weapons], ["warheads", ra2_warheads], ["projectiles", ra2_projectiles]]:
		for id in pack.get(pair[0], {}):
			if str(id).begins_with("YR_") or (filename in ["ra3_mirage.json", "ra3_expansion.json"] and str(id).begins_with("RA3_")):
				pair[1][str(id).to_lower()] = pack[pair[0]][id]
	var sounds: Dictionary = pack.get("sounds", {})
	for id in sounds.get("specs", {}):
		ra2_sound_specs[str(id).to_lower()] = sounds.specs[id]
	for id in sounds.get("entries", {}):
		ra2_sfx_files[str(id).to_lower()] = sounds.entries[id]

## Native baseline shared by both modes. Explicit progression still applies at spawn.
func _apply_yr_baseline() -> void:
	yr_baseline = _load_json("yr_baseline.json")
	for id in yr_baseline.get("entities", {}):
		var fields: Dictionary = yr_baseline.entities[id]
		var runtime: Dictionary = unit_index.get(id, building_index.get(id, {}))
		if runtime.is_empty(): continue
		for key in ["hp", "cost", "ra2_armor", "build_time_multiplier"]:
			runtime[key] = fields[key]
		# Native duration derives from Cost, BuildSpeed and per-type multiplier.
		runtime.erase("build_time")
		var source: Dictionary = ra2_source_units.get(id, ra2_source_buildings.get(id, {}))
		for key in ["hp", "cost", "adjacent"]: source[key] = fields[key]
		source["armor"] = fields.ra2_armor
	ra2_general["build"] = yr_baseline.get("build", ra2_build_rules()).duplicate(true)

## Only the legacy allied dog aliases ADOG. Do not alias the future Soviet DOG.
func catalog_sort_id(id: String) -> String:
	if id == "DOG" and str(unit_index.get(id, {}).get("faction", "")) == "allied":
		return "ADOG"
	return id

func catalog_sorted(ids: Array, category: String) -> Array:
	# Stable native roster order grouped by unlock/use; extension entries stay last.
	var order: Array = {
		"building": ["GAPOWR", "GAPILE", "GAREFN", "GAWEAP", "GAAIRC", "GAYARD", "GADEPT", "GATECH", "GAROBO", "GAOREP", "NAPOWR", "NAHAND", "NAREFN", "NAWEAP", "NARADR", "NAYARD", "NADEPT", "NATECH", "NANRCT", "NAINDP"],
		"defense": ["NAWALL", "NALASR", "NABNKR", "NAFLAK", "TESLA", "NAIRON", "NAMISL", "GAWALL", "GAPILL", "NASAM", "ATESLA", "GTGCAN", "GAGAP", "GASPYSAT", "GACSPH", "GAWEAT"],
		"unit": ["E1", "INIT", "GGI", "ADOG", "ENGINEER", "YENGINEER", "JUMPJET", "GHOST", "SPY", "YURI", "CLEG", "TANY", "SNIPE", "CCOMAND", "PTROOP", "CMIN", "MTNK", "LTNK", "FV", "YTNK", "ROBO", "SHAD", "TNKD", "SREF", "MGTK", "BFRT", "AMCV", "ORCA", "BEAG", "LCRF", "DEST", "DLPH", "AEGIS", "CARRIER", "E2", "SOV_DOG", "SENGINEER", "FLAKT", "SHK", "IVAN", "TERROR", "DESO", "BORIS", "CIVAN", "HARV", "HTNK", "HTK", "DRON", "V3", "APOC", "TTNK", "DTRUCK", "ZEP", "SCHP", "SMCV", "SAPC", "SUB", "HYD", "SQD", "DRED"]
	}.get(category, [])
	var result := ids.duplicate()
	result.sort_custom(func(a, b):
		var ai := order.find(catalog_sort_id(str(a)))
		var bi := order.find(catalog_sort_id(str(b)))
		if ai < 0: ai = 10000
		if bi < 0: bi = 10000
		return str(a) < str(b) if ai == bi else ai < bi)
	return result

# ------------------------------------------------------------------ 查询接口

# Sockets belong to the installed art, including when the actor definition came from a save.
func apply_hollywood_fx(definition: Dictionary) -> void:
	var pack: Dictionary = raw_docs["hollywood_combat.json"]
	var id: String = definition.get("id", "")
	if pack.unit_fx.has(id): definition.hollywood_fx = pack.unit_fx[id]
	if definition.get("hollywood_art", false) and definition.has("garrison_slots") and pack.fire_ports.has(id):
		definition.fire_ports = pack.fire_ports[id]

func get_unit(id: String) -> Dictionary:
	if not BattleRequest.skirmish and BattleRequest.mission_id=="yr_time_shift" and not unit_index.has(id) and not hollywood_yuri.units.has(id):
		var units01:Dictionary=preload("res://data/time_shift_assets.json").data.units
		if units01.has(id):return units01[id].duplicate(true)
	# Escape-only fallbacks neither change the production roster/hash nor mask
	# a future fully implemented Soviet/Yuri definition with the same original ID.
	if not BattleRequest.skirmish and hollywood_yuri.units.has(id): return hollywood_yuri.units[id].duplicate(true)
	if not unit_index.has(id):
		if hollywood_yuri.units.has(id): return hollywood_yuri.units[id].duplicate(true)
		if naval_support_units.has(id): return naval_support_units[id].duplicate(true)
		return preload("res://scripts/core/yr_death_rules.gd").data().get("crew_units", {}).get(id, {}).duplicate(true)
	var result := MatchRules.entity_data(BattleRequest.rules_mode, unit_index.get(id, {}), ra2_source_units.get(id, {}))
	if id == "CARRIER" and not result.is_empty():
		result = result.duplicate(true)
		result["weapon"] = spawned_weapon("HornetLauncher")
	return result

func spawned_weapon(id: String) -> Dictionary:
	var raw := ra2_weapon(id)
	return {"damage": float(raw.get("damage", 0)), "cooldown": float(raw.get("rof", 15)) / 15.0,
		"range": float(raw.get("range", 5)) * 55.0, "projectile_speed": float(raw.get("speed", 30)) * 22.0,
		"attack_type": "shell", "burst": int(raw.get("burst", 1)), "burst_delay": 0.12,
		"ra2_weapon_id": id, "report": str(raw.get("report", "")), "ra2_warhead": str(raw.get("warhead", "")),
		"ra2_projectile": str(raw.get("projectile", "")), "ra2_aa": false}

func get_building(id: String) -> Dictionary:
	if BattleRequest.mission_id=="yr_time_shift" and not BattleRequest.skirmish:
		var defs:Dictionary=preload("res://data/time_shift_assets.json").data.defs
		if defs.has(id) and (id.begins_with("CATIME") or id=="YAPPPT" or not building_index.has(id) and not hollywood_yuri.buildings.has(id)):return defs[id].duplicate(true)
	if (not BattleRequest.skirmish or not building_index.has(id)) and hollywood_yuri.buildings.has(id): return hollywood_yuri.buildings[id].duplicate(true)
	var result := MatchRules.entity_data(BattleRequest.rules_mode, building_index.get(id, {}), ra2_source_buildings.get(id, {}))
	if id == "NAFLAK" and BattleRequest.mission_id == "yr_hollywood" and not BattleRequest.skirmish:
		result = result.duplicate(true)
		result.cost = 20000
		result.power = 0
	if id == "GATECH" and not result.is_empty():
		# The two labs reference the same ForceShieldSpecial rules entry in rulesmd.
		var shield: Dictionary = building_index.get("NATECH", {}).get("superweapon", {})
		var native: Dictionary = allied_capabilities.get("buildings", {}).get(id, {})
		if not shield.is_empty() and native.get("SuperWeapon", "") == shield.id:
			result = result.duplicate()
			result.superweapon = shield.duplicate(true)
	return result

func get_entity(id: String) -> Dictionary:
	if unit_index.has(id) or hollywood_production_unit(id):
		return get_unit(id)
	if building_index.has(id):
		return get_building(id)
	return {}

func get_faction(id: String) -> Dictionary:
	return faction_index.get(id, {})

func get_mission(id: String) -> Dictionary:
	return mission_index.get(id, {})

func get_skill(id: String) -> Dictionary:
	if id=="ap_shock_pulse":
		var definition:Dictionary=skill_index.get(id,{}).duplicate(true)
		if not definition.is_empty():definition.radius=float(get_unit("E1").get("deployed_weapon",{}).get("range",definition.get("radius",0)))
		return definition
	return skill_index.get(id, {})

## 技能获取方式："base"（通用，人人可用）/ "gacha"（需抽取）
func skill_unlock_kind(id: String) -> String:
	var s := get_skill(id)
	if s.is_empty():
		return ""
	return str(s.get("unlock", skill_unlock.get("default", "gacha")))

## 是否为一开局就拥有的通用技能
func is_base_skill(id: String) -> bool:
	return skill_unlock_kind(id) == "base"

## 是否为需要抽取获得的技能
func is_gacha_skill(id: String) -> bool:
	return skill_unlock_kind(id) == "gacha"

## 技能稀有度（仅 gacha 技能有意义）
func skill_rarity(id: String) -> String:
	return str(get_skill(id).get("rarity", "common"))

func skill_unlock_label(kind: String) -> String:
	return str(skill_unlock.get("labels", {}).get(kind, kind))

## 按获取方式过滤技能（kind 为空则不过滤）
func skills_by_unlock(kind: String, type: String = "") -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for s in skills:
		if type != "" and str(s.get("type", "")) != type:
			continue
		if kind != "" and str(s.get("unlock", skill_unlock.get("default", "gacha"))) != kind:
			continue
		out.append(s)
	return out

## 技能抽卡规则（货币 / 价格 / 权重 / 是否启用）
func skill_draw_rules() -> Dictionary:
	return skill_draw

## 按类型取技能（"active" / "passive"）
func skills_of_type(t: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for s in skills:
		if str(s.get("type", "")) == t:
			out.append(s)
	return out

## 该 id 是建筑还是单位
func is_building(id: String) -> bool:
	return building_index.has(id)

## 攻击类型 -> 护甲类型 的克制倍率
func armor_multiplier(attack_type: String, armor_type: String) -> float:
	var row: Dictionary = combat_matrix.get(attack_type, {})
	return float(row.get(armor_type, 1.0))

func attack_label(t: String) -> String:
	return combat_labels.get("attack", {}).get(t, t)

func armor_label(a: String) -> String:
	return combat_labels.get("armor", {}).get(a, a)

## 某阵营 + 某建筑 能生产的所有单位（基础单位）
const STOLEN_INFANTRY := ["CCOMAND", "CIVAN", "PTROOP"]
const FieldCommission = preload("res://scripts/rules/field_commission.gd")

func units_from_building(faction: String, building_id: String) -> Array[Dictionary]:
	if building_id == "NEUTRALSTUDIO":
		var stars:Array[Dictionary]=[]
		for id in BattleRequest.combat_context.get("hollywood_roster",[]): stars.append(get_unit(id))
		return stars
	if building_id in ["YAWEAP","YABRCK"] and not BattleRequest.skirmish and BattleRequest.mission_id in ["yr_hollywood","yr_head_games"]:
		var native:Array[Dictionary]=[]
		var products: Array = hollywood_yuri.buildings[building_id].builds.duplicate()
		if BattleRequest.mission_id=="yr_head_games": products.append_array(HEAD_PRODUCTS[building_id])
		for id in products: native.append(get_unit(id))
		return native
	var out: Array[Dictionary] = []
	for u in units:
		var current := get_unit(str(u.get("id", "")))
		if not unit_in_production_catalog(str(current.get("id", ""))):
			continue
		var refinery_action: bool = building_id in ["GAREFN", "NAREFN"] and str(current.id) == ra2_source_buildings.get(building_id, {}).get("extra", {}).get("FreeUnit")
		var shared_barracks: bool = building_id in ["GAPILE", "NAHAND"] and current.id in STOLEN_INFANTRY
		if shared_barracks or (str(current.get("faction", "")) == faction and (str(current.get("built_at", "")) == building_id or refinery_action)):
			out.append(current)
	return out

func faction_unit_catalog(faction: String, include_extensions := BattleRequest.extensions_enabled()) -> Array:
	var ra2: Array = []
	var eng: Array = []
	for u in units:
		var s := str(u.get("id", ""))
		# The registered roster includes extension packs. Legacy Soviet prototypes stay hidden.
		if str(u.get("faction", "")) != faction or (u.faction == "soviet" and not is_ra2(s)):
			continue
		if not unit_in_production_catalog(s, include_extensions):
			continue
		if is_ra2(s):
			ra2.append(s)
		else:
			eng.append(s)
	return catalog_sorted(ra2, "unit") + eng

## Scenario actors remain spawnable/saveable but are not factory products.
func ai_product_allowed(id: String) -> bool:
	return not id.begins_with("R3")

func unit_in_production_catalog(id: String, include_extensions := BattleRequest.extensions_enabled()) -> bool:
	if id in FieldCommission.HIDDEN: return false
	if unit_index.get(id, {}).get("extension_only", false) and not include_extensions: return false
	if not unit_index.has(id):
		return false
	var rule: Dictionary = yr_production_rules.get(id, ra2_source_units.get(id, {}))
	return int(rule.get("tech_level", 0)) >= 0 and str(rule.get("extra", {}).get("Spawned", "no")).to_lower() != "yes"

func mission_production_tech() -> Dictionary:
	if BattleRequest.skirmish: return {}
	return get_mission(BattleRequest.mission_id).get("production_tech", {})

func mission_tech_block_reason(id: String) -> String:
	if BattleRequest.skirmish: return ""
	var rules := mission_production_tech()
	if rules.is_empty(): return ""
	var level: int = rules.overrides.get(id, yr_baseline.entities.get(id, {}).get("tech_level", 0))
	if level < 0 and rules.overrides.has(id): return "本关不能生产此项目"
	if level > int(rules.level): return "本关科技为 %d 级，该项目需要 %d 级" % [rules.level, level]
	return ""

## Only an unavailable prerequisite blocks the route. A captured facility still supplies it.
func mission_product_block_reason(id: String, owned: Array) -> String:
	if mission_production_tech().is_empty(): return ""
	var reason := mission_tech_block_reason(id)
	if not reason.is_empty(): return reason
	for token in ra2_missing_prereqs(id, owned):
		if not mission_tech_block_reason(str(token)).is_empty():
			return "本关禁止建造前置建筑：" + prereq_name(str(token))
	return ""

const HEAD_PRODUCTS := {"YABRCK":["BRUTE","VIRUS","YURIPR"],"YAWEAP":["MIND","TELE","CAOS","DISK"]}

func hollywood_production_unit(id: String) -> bool:
	if not BattleRequest.skirmish and BattleRequest.mission_id == "yr_head_games":
		return id in HEAD_PRODUCTS.YABRCK or id in HEAD_PRODUCTS.YAWEAP or id in ["INIT","YURI","YENGINEER","LTNK","YTNK"]
	return not BattleRequest.skirmish and BattleRequest.mission_id == "yr_hollywood" and id in ["INIT", "YURI", "YENGINEER", "LTNK", "YTNK"]

func unit_production_block_reason(id: String, battle_state: Dictionary = {}, owner_side: String = "ally") -> String:
	var mission_reason := mission_tech_block_reason(id)
	if not mission_reason.is_empty(): return mission_reason
	if id in preload("res://scripts/rules/hollywood_heroes.gd").IDS:
		return "" if id in BattleRequest.combat_context.get("hollywood_roster",[]) else "英雄尚未入册"
	if hollywood_production_unit(id): return ""
	var expedition_reason:=preload("res://scripts/expedition/rules.gd").block_reason(id,owner_side)
	if not expedition_reason.is_empty():return expedition_reason
	if preload("res://scripts/expedition/rules.gd").licensed_production(id, owner_side): return ""
	if id in FieldCommission.HIDDEN: return "心灵突击队暂未开放"
	if id in FieldCommission.PRODUCTS and FieldCommission.enabled() and not stolen_technology_unlocked(id, battle_state, owner_side):
		return FieldCommission.production_reason(id, battle_state, owner_side)
	if unit_index.get(id, {}).get("extension_only", false) and not BattleRequest.extensions_enabled(): return "仅 Iron Tide 扩展模式可生产"
	if not unit_index.has(id):
		return "未知单位，无法生产"
	if not unit_in_production_catalog(id):
		return "场景或附属单位，不能由工厂生产"
	var rule: Dictionary = yr_production_rules.get(id, ra2_source_units.get(id, {}))
	var extra: Dictionary = rule.get("extra", {})
	for pair in [["RequiresStolenAlliedTech", "盟军"], ["RequiresStolenSovietTech", "苏军"], ["RequiresStolenThirdTech", "尤里"]]:
		if str(extra.get(pair[0], "no")).to_lower() == "yes" and not bool(battle_state.get("stolen_" + owner_side + "_" + str(pair[0]), false)):
			return "需间谍渗透敌方%s作战实验室，窃取科技" % pair[1]
	return ""

## Preserve source stolen-tech requirements independently of the card objective route.
func stolen_technology_unlocked(id: String, battle_state: Dictionary, owner_side: String = "ally") -> bool:
	var rule: Dictionary = yr_production_rules.get(id, ra2_source_units.get(id, {}))
	var extra: Dictionary = rule.get("extra", {})
	var required := false
	for key in ["RequiresStolenAlliedTech", "RequiresStolenSovietTech", "RequiresStolenThirdTech"]:
		if str(extra.get(key, "no")).to_lower() != "yes": continue
		required = true
		if not bool(battle_state.get("stolen_" + owner_side + "_" + key, false)): return false
	return required

## Sidebar categories do not change the producer: factory-built aircraft share the air tab.
func unit_production_category(ud: Dictionary) -> String:
	var producer := get_building(str(ud.get("built_at", "")))
	var producer_tags: Array = producer.get("tags", [])
	var tags: Array = ud.get("tags", [])
	if producer_tags.has("factory") and tags.has("air"):
		return "air"
	for pair in [["barracks", "infantry"], ["factory", "vehicle"], ["airbase", "air"], ["shipyard", "naval"]]:
		if producer_tags.has(pair[0]):
			return pair[1]
	var role := str(ud.get("role", ""))
	if tags.has("naval") or tags.has("ship") or role in ["ship", "naval", "boat", "boats"]:
		return "naval"
	if role in ["infantry", "antitank"] or tags.has("infantry"):
		return "infantry"
	if tags.has("air"):
		return "air"
	return "vehicle"

func building_production_category(id: String) -> String:
	var source: Dictionary = ra2_source_buildings.get(id, {})
	if not str(source.get("build_cat", "")).is_empty():
		return "defense" if str(source.build_cat).to_lower() == "combat" else "building"
	return "defense" if get_building(id).get("tags", []).has("defense") else "building"

func building_production_block_reason(id: String) -> String:
	var mission_reason := mission_tech_block_reason(id)
	if not mission_reason.is_empty(): return mission_reason
	if id=="NEUTRALSTUDIO" and BattleRequest.combat_context.get("hollywood_roster",[]).is_empty(): return "尚未招募中立英雄"
	return "沙袋已移除建造目录" if id == "GASAND" else ""

func buildings_for_faction(faction: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not BattleRequest.combat_context.get("hollywood_roster",[]).is_empty(): out.append(get_building("NEUTRALSTUDIO"))
	for b in buildings:
		if str(b.get("faction", "")) == faction:
			out.append(get_building(str(b.get("id", ""))))
	return out

# ------------------------------------------------------------------ 工具

func _load_json(file_name: String) -> Dictionary:
	var path := DATA_DIR + file_name
	if not FileAccess.file_exists(path):
		push_warning("GameData: 缺失数据文件 " + path)
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_warning("GameData: 无法打开 " + path)
		return {}
	var text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("GameData: JSON 解析失败 " + path)
		return {}
	raw_docs[file_name] = parsed
	return parsed

func _as_dict_array(raw: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for item in raw:
		if typeof(item) == TYPE_DICTIONARY:
			out.append(item)
	return out

# ------------------------------------------------------------------ RA2 盟军阵营（Step C）

var ra2_loaded: bool = false
var ra2_art: Dictionary = {}
var ra2_prereq: Dictionary = {}
var ra2_ids: Array = []

## 加载 data/ra2_allied.json（增量合并，不覆盖既有 data/units.json）
func _load_ra2_allied() -> void:
	ra2_loaded = false
	ra2_art.clear()
	ra2_prereq.clear()
	ra2_ids.clear()
	var doc: Dictionary = _load_json("ra2_allied.json")
	if doc.is_empty():
		return
	for u in _as_dict_array(doc.get("units", [])):
		var uid := str(u.get("id", ""))
		if uid == "":
			continue
		if not unit_index.has(uid):
			units.append(u)
		unit_index[uid] = u
		ra2_ids.append(uid)
		if u.has("ra2_prereq"):
			ra2_prereq[uid] = u["ra2_prereq"]
	for b in _as_dict_array(doc.get("buildings", [])):
		var bid := str(b.get("id", ""))
		if bid == "":
			continue
		if not building_index.has(bid):
			buildings.append(b)
		building_index[bid] = b
		ra2_ids.append(bid)
		if b.has("ra2_prereq"):
			ra2_prereq[bid] = b["ra2_prereq"]
	var art_doc: Dictionary = doc.get("art", {})
	for k in art_doc.keys():
		ra2_art[str(k)] = art_doc[k]
	ra2_loaded = true

func is_ra2(id: String) -> bool:
	return ra2_ids.has(id)

func ra2_art_of(id: String) -> Dictionary:
	return ra2_art.get(id, {})

func ra2_cameo_path(id: String) -> String:
	return str((ra2_art.get(id, {}) as Dictionary).get("cameo", ""))

func ra2_sprite_path(id: String) -> String:
	var a: Dictionary = ra2_art.get(id, {})
	var v := str(a.get("vxl", ""))
	return v if v != "" else str(a.get("shp", ""))

## 科技树前置令牌：token（语义）与实体 id 两套口径并存
const RA2_TOKEN_TAGS := {
	"BARRACKS": "barracks", "TECH": "tech", "POWER": "power",
	"PROC": "refinery", "RADAR": "radar", "GACNST": "hq",
}
const RA2_TOKEN_IDS := {
	"STUDIO_POWER":["GAPOWR","NAPOWR","NANRCT","YAPOWR"],
	"BARRACKS": ["GAPILE"],
	"EXPEDITION_FACTORY": ["GAWEAP", "NAWEAP"],
	"TECH": ["GATECH", "NATECH", "YATECH"],
	"POWER": ["GAPOWR"],
	"PROC": ["GAREFN"],
	"RADAR": ["GAAIRC", "GASPYSAT"],
	"GACNST": ["GACNST"],
}

## 科技树前置判定：owned 为当前已拥有的建筑 id 列表
func ra2_prereq_ok(id: String, owned: Array, battle_state: Dictionary = {}, owner_side: String = "ally") -> bool:
	return ra2_missing_prereqs(id, owned, battle_state, owner_side).is_empty()

func production_prerequisites(id: String, battle_state: Dictionary = {}, owner_side: String = "ally") -> Array:
	if id == "GTGCAN" and not BattleRequest.skirmish and BattleRequest.mission_id == "yr_hollywood":
		return ["RADAR", "GACNST"]
	var result: Array = ra2_prereq.get(id, []).duplicate()
	if preload("res://scripts/expedition/rules.gd").has_training_permit(id, owner_side):
		for index in result.size():
			match str(result[index]):
				"GAPILE", "NAHAND": result[index] = "BARRACKS"
				"GAWEAP", "NAWEAP": result[index] = "EXPEDITION_FACTORY"
				"NARADR": result[index] = "RADAR"
	if id in FieldCommission.PRODUCTS and FieldCommission.enabled() and not stolen_technology_unlocked(id, battle_state, owner_side) and not result.has("TECH"):
		result.append("TECH")
	return result

## 列出尚未满足的前置令牌；空数组表示可建造（供 UI 置灰提示复用）
func ra2_missing_prereqs(id: String, owned: Array, battle_state: Dictionary = {}, owner_side: String = "ally") -> Array:
	var out: Array = []
	if not ra2_prereq.has(id):
		return out
	for pre in production_prerequisites(id, battle_state, owner_side):
		var token := str(pre).strip_edges().to_upper()
		if not token.is_empty() and not owned.any(func(bid): return supplies_prerequisite(str(bid), token)):
			out.append(token)
	return out

func supplies_prerequisite(building_id: String, token: String) -> bool:
	if building_id == token or RA2_TOKEN_IDS.get(token, []).has(building_id):
		return true
	# YR PrerequisiteTech enumerates laboratories. An industrial tech building is not a lab.
	if token == "TECH" or not RA2_TOKEN_TAGS.has(token):
		return false
	return building_index.get(building_id, {}).get("tags", []).has(RA2_TOKEN_TAGS[token])

## 与实际前置判定共用令牌，供侧栏、点击拒绝和生产停工说明使用。
func prereq_name(id: String) -> String:
	if id == "NANRCT": return "核子反应炉（高级反应堆）"
	var definition: Dictionary = unit_index.get(id, building_index.get(id, {}))
	return str(definition.get("name", id))

func ra2_missing_prereq_names(id: String, owned: Array, battle_state: Dictionary = {}, owner_side: String = "ally") -> String:
	var names := {"STUDIO_POWER":"供电建筑","EXPEDITION_FACTORY": "战车工厂", "BARRACKS": "兵营", "TECH": "作战实验室", "POWER": "发电厂",
		"PROC": "矿石精炼厂", "RADAR": "空指部", "GACNST": "建造厂"}
	if get_entity(id).get("faction") == "soviet":
		names.RADAR = "雷达设施"
		names.POWER = "供电建筑"
		names.PROC = "矿石精炼场"
	var missing := PackedStringArray()
	for token in ra2_missing_prereqs(id, owned, battle_state, owner_side):
		missing.append(str(names.get(str(token), prereq_name(str(token)))))
	return "、".join(missing)

func ra2_country_id(value: String) -> String:
	for country in ra2_countries:
		if country.get("side") in ["allied","soviet","yuri"] and (str(country.id).to_lower() == value.strip_edges().to_lower()
				or str(country.get("display", "")) == value.strip_edges()):
			return str(country.id)
	# Fall back to the default Allied opening for unknown legacy labels.
	return "Americans"

func ra2_country_side(value: String) -> String:
	var id := ra2_country_id(value)
	for country in ra2_countries:
		if country.id == id: return str(country.side)
	return "allied"

func _country_names(ids: Array) -> String:
	var names := PackedStringArray()
	for id in ids:
		var name := str(id)
		for country in ra2_countries:
			if str(country.id) == str(id):
				name = str(country.get("display", id))
				break
		names.append(name)
	return "、".join(names)

## Country eligibility comes from raw Owner / RequiredHouses / ForbiddenHouses.
## Country exclusives apply to both modes; progression does not change nationality.
func ra2_country_block_reason(id: String, country: String, foreign_producer := false) -> String:
	if id == "GTGCAN" and not BattleRequest.skirmish and BattleRequest.mission_id == "yr_hollywood":
		return "" if country == "Americans" else "本关只有美国可以建造巨炮"
	var source_id := id
	# The allied runtime catalog retains DOG as its legacy dog identifier.
	# Country eligibility must use the allied ADOG, not the Soviet DOG variant.
	if id == "DOG" and str(get_unit(id).get("faction", "")) == "allied":
		source_id = "ADOG"
	# The US uses AMRADR eligibility and paradrop support on the shared GAAIRC model.
	if id == "GAAIRC" and country == "Americans":
		source_id = "AMRADR"
	var source: Dictionary = ra2_source_units.get(source_id, ra2_source_buildings.get(source_id, {}))
	var extra: Dictionary = source.get("extra", {})
	var required: Array = []
	var forbidden: Array = []
	for item in str(extra.get("RequiredHouses", "")).split(",", false):
		required.append(item.strip_edges())
	for item in str(extra.get("ForbiddenHouses", "")).split(",", false):
		forbidden.append(item.strip_edges())
	if not required.is_empty() and not required.has(country):
		return "国家限制：仅限" + _country_names(required)
	if forbidden.has(country):
		return "国家限制：" + _country_names([country]) + "不可用"
	var owners: Array = source.get("owner", [])
	if id in STOLEN_INFANTRY:
		var yr := preload("res://scripts/core/yr_death_rules.gd").type_data(id)
		owners = Array(str(yr.get("owner", "")).split(",", false))
	if not foreign_producer and not owners.is_empty() and not owners.has(country):
		return "国家限制：仅限" + _country_names(owners)
	return ""

## 去重：RA2 加载后，引擎自带盟军生产建筑不再出现在建造栏
## （Step C 阶段2：引擎自创 allied_* 已整体删除，此表保留为空以兼容调用点）
const RA2_SUPERSEDE := []

func ra2_hide_engine(id: String) -> bool:
	return ra2_loaded and RA2_SUPERSEDE.has(id)

# ------------------------------------------------------------------ RA2 战斗规则（护甲类别 / 弹头 Verses）
# RA2 是规则唯一事实源：伤害 = 武器 damage × warhead.Verses[目标护甲类别]。
# 护甲共 11 类，弹头 Verses 未列出的护甲按 RA2 语义默认 100%。

const RA2_ARMOR_ORDER := ["none", "flak", "plate", "light", "medium", "heavy", "wood", "steel", "concrete", "special_1", "special_2"]
const RA2_ARMOR_LABELS := {
	"none": "无甲", "flak": "防空甲", "plate": "板甲", "light": "轻甲", "medium": "中甲",
	"heavy": "重甲", "wood": "木甲", "steel": "钢甲", "concrete": "混凝土", "special_1": "特殊甲一", "special_2": "特殊甲二",
}
# 引擎旧护甲词表 ↔ RA2 真实护甲类别（供引擎自带单位 / 旧克制表路径互通）
const ENGINE_TO_RA2_ARMOR := {
	"unarmored": "none", "light": "light", "medium": "medium", "heavy": "heavy",
	"structure": "concrete", "air": "none",
}
const RA2_TO_ENGINE_ARMOR := {
	"none": "unarmored", "flak": "light", "plate": "medium", "light": "light", "medium": "medium",
	"heavy": "heavy", "wood": "structure", "steel": "structure", "concrete": "structure",
	"special_1": "heavy", "special_2": "heavy",
}

var ra2_warheads: Dictionary = {}   # lower(id) -> { verses: {class: mult}, ... }

var ra2_general: Dictionary = {}   # rules.ini [General] 全局倍率（老兵升级等）
var ra2_economy: Dictionary = {}
var naval_support_units: Dictionary = {} # Carrier-owned Osprey and scenario Typhoon.
var ra2_source_units: Dictionary = {}
var ra2_source_buildings: Dictionary = {}
var ra2_countries: Array = []

func _load_ra2_rules() -> void:
	ra2_warheads.clear()
	var doc: Dictionary = _load_json("ra2/warheads.json")
	var wmap: Dictionary = doc.get("warheads", {})
	for k in wmap.keys():
		ra2_warheads[str(k).to_lower()] = wmap[k]
	# [General] 全局规则（VeteranRatio/Combat/Speed/Armor/ROF/Cap）
	ra2_general = _load_json("ra2/general.json")
	ra2_economy = _load_json("ra2/economy.json")
	ra2_source_units.clear()
	var unit_doc := _load_json("ra2/units.json")
	for kind in ["infantry", "vehicles", "aircraft"]:
		ra2_source_units.merge(unit_doc.get(kind, {}), true)
	ra2_source_buildings = _load_json("ra2/buildings.json").get("buildings", {})
	ra2_countries = _load_json("ra2/factions.json").get("countries", []).duplicate()
	ra2_countries.append({"id":"YuriCountry","display":"尤里","side":"yuri"})
	_load_ra2_fx()
	# Spawned aircraft is addressable by the carrier but absent from production catalogs.
	var hornet: Dictionary = ra2_source_units.get("HORNET", {})
	if not hornet.is_empty():
		unit_index["HORNET"] = {"id": "HORNET", "name": str(hornet.display_name), "faction": "allied",
			"role": "air", "tags": ["air"], "ra2": true, "hp": float(hornet.hp), "cost": float(hornet.cost),
			"armor": "air", "ra2_armor": str(hornet.armor), "speed": float(hornet.speed) * 15.0,
			"radius": 8.0, "sight": float(hornet.sight) * 55.0, "movement_zone": "fly",
			"move": {"rot": float(hornet.extra.get("ROT", 3)) * 21.09375, "turret": false},
			"weapon": spawned_weapon(str(hornet.primary)), "built_at": ""}

	naval_support_units.clear()
	var cargo: Dictionary = ra2_source_units["PDPLANE"]
	naval_support_units["PDPLANE"] = {"id":"PDPLANE", "name":"空降运输机", "faction":"allied", "role":"air", "tags":["air"], "ra2":true,
		"hp":float(cargo.hp), "armor":"air", "ra2_armor":cargo.armor, "speed":float(cargo.speed)*15.0, "radius":14.0, "sight":0.0, "cost":0, "built_at":"", "movement_zone":"fly"}
	for id in ["ASW", "SUB"]:
		var row: Dictionary = ra2_source_units[id]
		var aircraft: bool = id == "ASW"
		naval_support_units[id] = {"id": id, "name": "鱼鹰反潜机" if aircraft else "台风攻击潜艇",
			"faction": "allied" if aircraft else "soviet", "ra2": true,
			"hp": float(row.hp), "cost": float(row.cost), "ra2_armor": str(row.armor),
			"armor": "air" if aircraft else "heavy", "radius": 9.0 if aircraft else 26.0,
			"tags": ["air"] if aircraft else ["naval", "ship"], "role": "air" if aircraft else "naval",
			"movement_zone": "fly" if aircraft else "water", "sight": float(row.sight) * 55.0,
			"speed": float(row.speed) * 15.0, "move": {"rot": float(row.extra.ROT) * 21.09375},
			"weapon": spawned_weapon(str(row.primary)), "built_at": ""}
		naval_support_units[id].weapon["report"] = str(ra2_weapon(str(row.primary)).get("report", ""))
		if aircraft:
			naval_support_units[id]["immune_to_psionics"] = _ra2_flag(row.extra.get("ImmuneToPsionics"))
		else:
			naval_support_units[id]["elite_weapon"] = spawned_weapon("SubTorpedoE")
			naval_support_units[id].elite_weapon["report"] = "SubAttack"

## 老兵全局倍率（缺省回退先验值，保证旧数据也能跑）
func ra2_veteran_rules() -> Dictionary:
	var v: Dictionary = ra2_general.get("veteran", {})
	if v.is_empty():
		return { "ratio": 3.0, "combat": 1.1, "speed": 1.2, "sight": 0.0, "armor": 1.5, "rof": 0.6, "cap": 2 }
	return v

## 棱镜支援链全局规则（rules.ini [General] Prism* 系列，缺省回退原版值）。
## 返回 {type, modifier, max, delay, duration, height}。见 building.gd _prism_support_chain()。
func ra2_prism_rules() -> Dictionary:
	var p: Dictionary = ra2_general.get("prism", {})
	if p.is_empty():
		return { "type": "ATESLA", "modifier": 1.5, "max": 8, "delay": 60.0, "duration": 15.0, "height": 420.0 }
	return p

## 建造规则（rules.ini [General] BuildSpeed/BuildupTime/RefundPercent/MultipleFactory）
func resource_value(kind: String = "ore") -> float:
	if BattleRequest.extensions_enabled() and BattleRequest.native_ore_map().is_empty():
		return 1.0
	return float(ra2_economy.get("resources", {}).get(kind, {}).get("value", 50.0 if kind == "gems" else 25.0))

func ra2_build_rules() -> Dictionary:
	var b: Dictionary = ra2_general.get("build", {})
	if b.is_empty():
		return { "build_speed": 0.7, "buildup_time_minutes": 0.06, "refund_percent": 0.5,
			"multiple_factory": 0.8, "wall_build_speed": 3.0, "base_unit": "AMCV,SMCV" }
	return b

## RA2 生产时间：rules.ini BuildSpeed = 生产 1000 credits 所需分钟数。
## 数据里显式给出 build_time（秒）时优先使用；多工厂按 MultipleFactory 连乘折扣。
func ra2_build_time(d: Dictionary, factories: int = 1) -> float:
	var bt := float(d.get("build_time", 0.0))
	if not yr_baseline.get("entities", {}).has(str(d.get("id", ""))) and bt > 0.0:
		return bt
	var rules := ra2_build_rules()
	var cost := float(d.get("cost", 0.0))
	var mins := cost * float(rules.get("build_speed", 0.7)) / 1000.0
	if WallArt.is_wall(d): mins /= maxf(0.01, float(rules.get("wall_build_speed", 3.0)))
	var mul := float(rules.get("multiple_factory", 0.8))
	var n := maxi(factories, 1)
	for i in range(1, n):
		mins *= mul
	return maxf(1.0, mins * 60.0 * float(d.get("build_time_multiplier", 1.0)))

## 建筑放置后的 buildup 动画时长（秒）：BuildupTime 单位是分钟，引擎内 25 帧均分。
func ra2_buildup_seconds() -> float:
	return maxf(0.1, float(ra2_build_rules().get("buildup_time_minutes", 0.06)) * 60.0)

func ra2_refund(cost: int) -> int:
	return int(round(float(cost) * float(ra2_build_rules().get("refund_percent", 0.5))))

# ------------------------------------------------------------------ RA2 攻击特效数据
# 事实源：rules.ini 的 [Weapon] Anim=/Bright=/Report=、[Warhead] AnimList=/CellSpread=、
# [Projectile] Image=/Inviso=/Arcing=/Shadow=/ROT=，以及 art.ini 的动画参数（Rate=）。
var ra2_weapons: Dictionary = {}      # lower(id) -> weapon
var ra2_projectiles: Dictionary = {}  # lower(id) -> projectile
var ra2_animations: Dictionary = {}   # upper(image) -> art.ini 动画参数

func _load_ra2_fx() -> void:
	ra2_weapons.clear()
	ra2_projectiles.clear()
	ra2_animations.clear()
	var wd: Dictionary = _load_json("ra2/weapons.json").get("weapons", {})
	for k in wd.keys():
		ra2_weapons[str(k).to_lower()] = wd[k]
	var pd: Dictionary = _load_json("ra2/projectiles.json").get("projectiles", {})
	for k in pd.keys():
		ra2_projectiles[str(k).to_lower()] = pd[k]
	var ad: Dictionary = _load_json("ra2/animations.json").get("animations", {})
	for k in ad.keys():
		ra2_animations[str(k).to_upper()] = ad[k]
	_load_ra2_sfx()
	_load_ra2_eva()

# ------------------------------------------------------------------ RA2 音效数据
# 事实源：MIX 内 audio.idx(GABA)/audio.bag → assets/ra2/sfx/*.wav（IMA ADPCM 已解码为 PCM16）。
# sound_specs.json：[sound.ini] 的 [SoundList] 条目（Sounds=/Volume=/Range=/Loop=…）。
var ra2_sound_specs: Dictionary = {}   # lower(id) -> { sounds:[], volume, range, loop, priority }
var ra2_sfx_files: Dictionary = {}     # lower(sname) -> { file, sampleRate, channels, durMs }
var ra2_voice_overrides: Dictionary = {} # optional YR speech; never modifies unit rules

func _load_ra2_sfx() -> void:
	ra2_sound_specs.clear()
	ra2_sfx_files.clear()
	ra2_voice_overrides.clear()
	var sd: Dictionary = _load_json("ra2/sound_specs.json").get("specs", {})
	for k in sd.keys():
		ra2_sound_specs[str(k).to_lower()] = sd[k]
	var fd: Dictionary = _load_json("ra2/sfx_index.json").get("entries", {})
	for k in fd.keys():
		ra2_sfx_files[str(k).to_lower()] = fd[k]
	# Original YR mappings take precedence per event; older/local voices remain fallbacks.
	for pack_file in ["ra2/yr_voice_pack.json", "ra2/yr_unit_voices.json", "ra2/building_audio.json", "ra2/spy_plane_audio.json", "ra2/yr_weapon_audio.json", "ra2/menu_audio.json", "ra2/hollywood_audio.json", "ra2/head_games_audio.json", "ra2/time_shift_audio.json"]:
		if not FileAccess.file_exists("res://data/" + pack_file):
			continue
		var pack: Dictionary = _load_json(pack_file)
		for uid in pack.get("units", {}):
			var merged: Dictionary = ra2_voice_overrides.get(uid, {}).duplicate()
			merged.merge(pack.units[uid], true)
			ra2_voice_overrides[uid] = merged
		for k in pack.get("specs", {}):
			ra2_sound_specs[str(k).to_lower()] = pack.specs[k]
		for k in pack.get("entries", {}):
			ra2_sfx_files[str(k).to_lower()] = pack.entries[k]

# ------------------------------------------------------------------ RA2 EVA 语音
# 事实源：LANGUAGE.MIX > audio.mix 内 459 条 RIFF/IMA-ADPCM；名字取自 eva.ini 的
# Allied=(cevaNNN)/Russian=(csofNNN)。由 ra2pipe/eva_build.mjs 落地为
# assets/ra2/eva/*.wav + data/ra2/eva_index.json + data/ra2/eva_specs.json。
var ra2_eva_events: Dictionary = {}    # upper(EVA_XXX) -> { text, allied, russian, type, priority }
var ra2_eva_files: Dictionary = {}     # lower(cevaNNN) -> { file, sampleRate, channels, durMs }

func _load_ra2_eva() -> void:
	ra2_eva_events.clear()
	ra2_eva_files.clear()
	var ed: Dictionary = _load_json("ra2/eva_specs.json").get("events", {})
	for k in ed.keys():
		ra2_eva_events[str(k).to_upper()] = ed[k]
	var fd: Dictionary = _load_json("ra2/eva_index.json").get("entries", {})
	for k in fd.keys():
		ra2_eva_files[str(k).to_lower()] = fd[k]

## 事件名（如 "EVA_ConstructionComplete"）是否有 EVA 语音规格
func has_ra2_eva(event: String) -> bool:
	return ra2_eva_events.has(event.to_upper())

func ra2_eva_spec(event: String) -> Dictionary:
	return ra2_eva_events.get(event.to_upper(), {})

## 事件 → 阵营对应的声音 id（side == "soviet" 用 Russian，否则 Allied）
func ra2_eva_sound_id(event: String, side: String = "allied") -> String:
	var spec: Dictionary = ra2_eva_spec(event)
	var id := str(spec.get("russian", "")) if side.to_lower() == "soviet" else str(spec.get("allied", ""))
	if id.is_empty():
		id = str(spec.get("allied", spec.get("russian", "")))
	return id

func ra2_eva_file(id: String) -> Dictionary:
	return ra2_eva_files.get(id.to_lower(), {})

func ra2_eva_path(file_name: String) -> String:
	return "res://assets/ra2/eva/" + file_name

func ra2_eva_dur_ms(id: String) -> int:
	return int(ra2_eva_file(id).get("durMs", 1200))

# ------------------------------------------------------------------ 遭遇战（Skirmish）
func skirmish_default_config() -> Dictionary:
	return {"map_size": 3200, "starting_funds": 10000, "enemy_base": "allied", "difficulty": 1, "opponents": 1}

## 用配置（可选）生成一个“遭遇战”任务字典，结构兼容 waves.json 的 missions。
func make_skirmish_mission(cfg: Dictionary = {}) -> Dictionary:
	var c := skirmish_default_config()
	for k in cfg.keys():
		c[k] = cfg[k]
	var diff := clampi(int(c.get("difficulty", 1)), 0, DIFFICULTY_NAMES.size() - 1)
	var diff_name: String = DIFFICULTY_NAMES[diff]
	var eb := str(c.get("enemy_base", "allied"))
	var eb_name := str({"allied":"盟军", "soviet":"苏联", "yuri":"尤里"}.get(eb, "虫群巢穴"))
	var layouts := {"coast":"经典海岸", "crossings":"双桥争夺", "strait":"隔海登陆"}
	layouts.merge({"exp_plain":"钢铁平原","exp_fortress":"中央要塞"})
	for i in preload("res://scripts/world/skirmish_maps.gd").IDS.size():
		layouts[preload("res://scripts/world/skirmish_maps.gd").IDS[i]]=preload("res://scripts/world/skirmish_maps.gd").NAMES[i]
	var layout := str(c.get("map_layout", "coast"))
	if not layouts.has(layout): layout = "coast"
	var rows: Array = c.get("houses",[])
	if rows.size()>2:
		var groups := {}
		for row in rows: groups[row.team] = true
		eb_name = "%d 家 · %d 个结盟组" % [rows.size(),groups.size()]
	return {
		"id": "skirmish",
		"name": "遭遇战",
		"subtitle": "%s · %s · %s · 初始资金 %d" % [layouts[layout], eb_name, diff_name, int(c.get("starting_funds", 10000))],
		"brief": ("歼灭战：消灭全部建筑与单位获胜。" if c.get("victory_condition", "short") == "annihilation" else "短局：摧毁敌方基地建筑和基地车即可获胜，防御工事不计。") + "双方同时覆灭为平局；基地车按 J 展开。",
		"map_size": int(preload("res://scripts/world/native_maps.gd").size_for(layout)) if preload("res://scripts/world/native_maps.gd").has(layout) else int(c.get("map_size", 3200)),
		"map_layout": layout,
		"starting_funds": int(c.get("starting_funds", 10000)),
		"prepare_time": 12.0,
		"enemy_faction": "skirmish",
		"waves": [],
		"endless": false,
		"skirmish": true,
		"opening": str(c.get("opening", "prebuilt")),
		"victory_condition": str(c.get("victory_condition", "short")),
		"fog_of_war": c.get("fog_of_war", false) == true,
		"skirmish_enemy_base": eb,
		"skirmish_difficulty": diff,
		"skirmish_opponents": c.houses.filter(func(h):return h.team != c.houses[0].team).size() if not c.get("houses",[]).is_empty() else int(c.get("opponents",1)),
	}

## Explicit AI progression, never copied from the player's purchases or tiers.
const DIFFICULTY_NAMES := ["简单", "普通", "困难", "凶残", "凶残1", "凶残2", "凶残3"]
const AI_TRAINING := {4: {"logistics": 20, "unit": 12}, 5: {"logistics": 40, "unit": 32}, 6: {"logistics": 50, "unit": 37}}

func skirmish_training_text(difficulty: int) -> String:
	if not AI_TRAINING.has(difficulty): return ""
	var ranks: Dictionary = AI_TRAINING[difficulty]
	return "AI 战斗后勤 %d 级，兵种火力与装甲 %d 级" % [ranks.logistics, ranks.unit]

func skirmish_logistics(difficulty: int) -> Dictionary:
	var result := MatchRules.neutral_bonuses()
	if not AI_TRAINING.has(difficulty): return result
	var level: int = AI_TRAINING[difficulty].logistics
	for upgrade in MetaProgress.upgrades():
		var stat := str(upgrade.get("stat", ""))
		if stat in ["attack_bonus", "defense_bonus", "hp_bonus", "speed_bonus", "build_bonus", "deploy_bonus"]:
			result[stat] += float(upgrade.effect_per_level) * level
	return result

## Per-unit training is separate from logistics; no player purchases or cards are copied.
func skirmish_unit_upgrades(difficulty: int) -> Dictionary:
	var result := {"attack_bonus":1.0,"defense_bonus":1.0,"skill_bonus":1.0}
	if not AI_TRAINING.has(difficulty): return result
	var level: int = AI_TRAINING[difficulty].unit
	for track in MetaProgress.unit_upgrade_tracks():
		var stat := str(track.get("stat", ""))
		if result.has(stat):
			result[stat] += float(track.effect_per_level) * level
	return result

## 难度 → AI 调参（收入/生产节拍/进攻门槛）。
func skirmish_ai_tuning(difficulty: int) -> Dictionary:
	match clampi(difficulty, 0, 3):
		3: return {"income": 280.0, "train_interval": 2.0, "army_min": 7, "attack_delay": 32.0, "building_income": 14.0}
		0: return {"income": 130.0, "train_interval": 4.0, "army_min": 3, "attack_delay": 75.0, "building_income": 6.0}
		2: return {"income": 280.0, "train_interval": 2.5, "army_min": 6, "attack_delay": 38.0, "building_income": 14.0}
		_: return {"income": 190.0, "train_interval": 3.0, "army_min": 4, "attack_delay": 55.0, "building_income": 9.0}

func has_ra2_sound(id: String) -> bool:
	return ra2_sound_specs.has(id.to_lower())

## sound id（如 "GrizzlyTankAttack"）→ 规格条目
func ra2_sound_spec(id: String) -> Dictionary:
	return ra2_sound_specs.get(id.to_lower(), {})

## sound id → 该规格可用的 wav 文件名列表（assets/ra2/sfx/<file>）
func ra2_sound_files(id: String) -> Array:
	var out: Array = []
	var spec: Dictionary = ra2_sound_spec(id)
	for s in spec.get("sounds", []):
		var e: Dictionary = ra2_sfx_files.get(str(s).to_lower(), {})
		if not e.is_empty():
			out.append(str(e.get("file", "")))
	return out

func ra2_sfx_path(file_name: String) -> String:
	if file_name.begins_with("res://assets/ra3/"): return file_name
	return "res://assets/ra2/sfx/" + file_name

## Volume= 口径：0..1；若为 0..100 则归一
func ra2_sound_volume(id: String) -> float:
	var v := _num(ra2_sound_spec(id).get("volume", 1.0), 1.0)
	if v > 1.0:
		v = v / 100.0
	return clampf(v, 0.0, 2.0)

func ra2_sound_range_cells(id: String) -> float:
	return _num(ra2_sound_spec(id).get("range", 10.0), 10.0)

func ra2_weapon(id: String) -> Dictionary:
	return ra2_weapons.get(id.to_lower(), {})

func ra2_projectile(id: String) -> Dictionary:
	return ra2_projectiles.get(id.to_lower(), {})

func ra2_anim(id: String) -> Dictionary:
	return ra2_animations.get(id.to_upper(), {})

func ra2_muzzle_bright(weapon_id: String) -> bool:
	var w: Dictionary = ra2_weapon(weapon_id)
	return (w.get("bright", false) == true)

## 表现层：原版用【光束/激光/电弧】表现的武器（rules.ini 无 Anim=，靠 IsLaser= / IsRadBeam= /
## IsElectricBolt= 渲染）。本作给一份等价的程序化光束（Effects.spawn_beam）。仅影响绘制，
## 不改动 RA2 规则数据（data/ra2/weapons.json 保持原版）。
## 数据驱动：直接读 weapons.json 的 extra.* 标志，覆盖全部 27 把光束/激光/电弧武器。
## 返回 {kind, color, house, thickness, duration}，kind ∈ {"laser","rad","tesla"}；无标志返回 {}。
##   color = 光束基色；house = true 时调用方改用该单位/建筑阵营色（IsHouseColor=yes）。
func ra2_beam_spec(weapon_id: String) -> Dictionary:
	return weapon_combat_rule(weapon_id).get("beam", _EMPTY_STATIC_RULE)

static func _compile_ra2_beam_spec(w: Dictionary, e: Dictionary, flags: Dictionary) -> Dictionary:
	var is_laser: bool = flags.laser
	var is_rad: bool = flags.rad_beam
	var is_tesla: bool = flags.electric_bolt
	var is_rail := _ra2_flag(e.get("IsRailgun"))
	if not (is_laser or is_rad or is_tesla or is_rail):
		return {}
	var house := _ra2_flag(e.get("IsHouseColor"))
	var dur := 0.12
	if e.has("LaserDuration"):
		dur = clampf(_num(e.get("LaserDuration"), 15.0) / 60.0, 0.06, 0.6)
	var spec := {
		"kind": "laser", "color": Color(1.0, 0.38, 0.30), "house": house,
		"thickness": 2.6, "duration": dur,
	}
	if is_rail:
		spec["kind"] = "rail"
		spec["color"] = Color(0.8, 0.9, 1.0)
		spec["duration"] = 0.18
	elif is_tesla:
		spec["kind"] = "yr_bolt"
		spec["thickness"] = 1.5
		spec["color"] = Color8(80, 80, 252)  # PALETTE.PAL index 10
		if _ra2_flag(e.get("IsAlternateColor")):
			spec["color"] = Color8(252, 252, 84)  # index 5
		spec["duration"] = 17.0 / 15.0
	elif is_rad:
		spec["kind"] = "rad"
		spec["thickness"] = 2.4
		# ChronoBeam 弹头（NeutronRifle）= 超时空蓝 128,200,255；其余辐射束 = RadColor 0,255,0
		if str(w.get("warhead", "")).to_lower().trim_prefix("yr_cap_") == "chronobeam":
			spec["color"] = Color(128.0 / 255.0, 200.0 / 255.0, 1.0)
		else:
			spec["color"] = Color(0.35, 1.0, 0.25)
		spec["duration"] = 0.14
	else:  # IsLaser（棱镜 / 高能激光）
		spec["thickness"] = 4.2 if _ra2_flag(e.get("IsBigLaser")) else 2.6
		var inner = _ra2_rgb(e.get("LaserInnerColor"))
		if inner != null:
			spec["color"] = inner
		elif not house:
			spec["color"] = Color(1.0, 0.35, 0.30)
		else:
			spec["color"] = Color(0.92, 0.96, 1.0)                 # 房色激光占位，调用方替换
	spec.make_read_only()
	return spec

## rules.ini 布尔标志：yes / true / 1 视为真
static func _ra2_flag(v) -> bool:
	if v is bool: return v
	# Exported rules normally use these canonical strings; retain normalization for all other values.
	if v is String:
		if v == "yes" or v == "true" or v == "1": return true
		if v == "no" or v == "false" or v == "0" or v == "": return false
	if v == null:
		return false
	var s := str(v).strip_edges().to_lower()
	return s == "yes" or s == "true" or s == "1"

## rules.ini "R,G,B"（0-255）→ Color；非法返回 null
static func _ra2_rgb(v):
	if v == null:
		return null
	if v is Color:
		return v
	var parts := str(v).split(",")
	if parts.size() < 3:
		return null
	return Color(_num(parts[0], 0.0) / 255.0, _num(parts[1], 0.0) / 255.0, _num(parts[2], 0.0) / 255.0)

## 表现层兜底：rules.ini 中下列武器没有 Anim=（原版靠射击帧 / 激光 / 导弹弹体表现），
## 本作统一用 SHP 炮口火光表现，故给一份等价的 RA2 炮口动画。
## 仅影响绘制，不改动 RA2 规则数据（data/ra2/weapons.json 保持原版）。
const MUZZLE_FALLBACK := {
	# Local YR [Para].Anim; the older RA2 catalog has no Anim on this weapon.
	"para": ["MGUN-N", "MGUN-NE", "MGUN-E", "MGUN-SE", "MGUN-S", "MGUN-SW", "MGUN-W", "MGUN-NW"],
	"20mm": ["MGUN-N", "MGUN-NE", "MGUN-E", "MGUN-SE", "MGUN-S", "MGUN-SW", "MGUN-W", "MGUN-NW"],
	"mp5": ["PIFFPIFF"],
	"badteeth": ["PIFF"],
	"awp": ["PIFFPIFF"],
	"doublepistols": ["PIFFPIFF"],
}

## 武器 Anim= → 炮口火光动画名列表（8 项时按炮塔朝向取，1 项恒用）
func ra2_muzzle_anims(weapon_id: String) -> Array:
	var w: Dictionary = ra2_weapon(weapon_id)
	var a = w.get("anim", null)
	if a == null:
		return _muzzle_fallback(weapon_id)
	if typeof(a) == TYPE_ARRAY:
		return a
	var s := str(a).strip_edges()
	if s == "":
		return _muzzle_fallback(weapon_id)
	var out: Array = []
	for part in s.split(","):
		var t := part.strip_edges()
		if t != "":
			out.append(t)
	return out

## 无原版 Anim= 的武器 → 表现层炮口动画（见 MUZZLE_FALLBACK）
func _muzzle_fallback(weapon_id: String) -> Array:
	var key := weapon_id.to_lower().trim_prefix("yr_cap_").trim_prefix("yr_")
	# Keep the existing presentation fallback when these guns promote. Explicit
	# original Anim (e.g. VTMUZZLE) is resolved above and always takes precedence.
	if key in ["20mme", "mp5e", "awpe", "doublepistolse"]: key = key.trim_suffix("e")
	var f = MUZZLE_FALLBACK.get(key, null)
	return f if f != null else []

## 弹头 AnimList= → 命中动画名列表
# Derived from the final merged rules, never from an actor or a resolved weapon.
# GameData.reload() rebuilds these; fixture/tool edits to raw tables must do likewise.
const _EMPTY_STATIC_RULE: Dictionary = {}
var _projectile_combat_rules: Dictionary = {}
var _projectiles_blocking_ground: Dictionary = {}
var _warhead_combat_rules: Dictionary = {}
var _weapon_combat_rules: Dictionary = {}
var _unit_land_blocked: Dictionary = {}
var _unit_naval_targeting: Dictionary = {}
var _unit_warp_blocked: Dictionary = {}
var _unit_sonic_type_immune: Dictionary = {}

func rebuild_static_combat_rules() -> void:
	_projectile_combat_rules.clear()
	_projectiles_blocking_ground.clear()
	for id in ra2_projectiles:
		var row: Dictionary = ra2_projectiles[id]
		var e: Dictionary = row.get("extra", {})
		if str(e.get("AG", "yes")).to_lower() in ["no", "false", "0"]: _projectiles_blocking_ground[id] = true
		_projectile_combat_rules[id] = {
			"subject_to_walls": _ra2_flag(e.get("SubjectToWalls")),
			"shrapnel_weapon": str(e.get("ShrapnelWeapon", "")),
			"shrapnel_count": int(e.get("ShrapnelCount", 0)),
			"drop_accel": maxf(1.0, float(e.get("Acceleration", 1))),
		}
	_warhead_combat_rules.clear()
	for id in ra2_warheads:
		var row: Dictionary = ra2_warheads[id]
		if row.is_empty(): continue
		var e = row.get("extra")
		if not e is Dictionary: e = _EMPTY_STATIC_RULE
		var deform := float(str(e.get("Deform", "")).replace("%", "").strip_edges())
		_warhead_combat_rules[id] = {
			"mind_control": _ra2_flag(e.get("MindControl")), "temporal": _ra2_flag(e.get("Temporal")),
			"radiation": _ra2_flag(e.get("Radiation")),
			"blocks_friendly_damage": str(e.get("AffectsAllies", "")).to_lower() in ["no", "false", "0"],
			"causes_death_weapon": str(e.get("CausesDeathWeapon", "")).to_lower() in ["yes", "true", "1"],
			"rocker": str(e.get("Rocker", "")).to_lower() == "yes",
			"sparky": str(e.get("Sparky", "")).to_lower() == "yes",
			"bright": str(e.get("Bright", "")).to_lower() == "yes",
			"em_effect": str(e.get("EMEffect", "")).to_lower() == "yes",
			"wall": _ra2_flag(row.get("wall", e.get("Wall", false))),
			"wood": _ra2_flag(row.get("wood", e.get("Wood", false))),
			"wall_absolute_destroyer": _ra2_flag(e.get("WallAbsoluteDestroyer")),
			"deform_ratio": deform / 100.0 if deform > 1.0 else deform,
			"deform_threshold": float(str(e.get("DeformThreshhold", "")).strip_edges()),
			"impact_anims": _parse_impact_anims(row.get("anim_list")),
			"cell_spread": _combat_number(row.get("cell_spread"), 0.0),
			"percent_at_max": _combat_number(row.get("percent_at_max"), 1.0),
			"prone_damage": _combat_number(row.get("prone_damage"), 1.0),
		}
	_weapon_combat_rules.clear()
	for id in ra2_weapons:
		var row: Dictionary = ra2_weapons[id]
		var e: Dictionary = row.get("extra", {})
		var rule := {"sonic": _ra2_flag(e.get("IsSonic")), "rad_beam": _ra2_flag(e.get("IsRadBeam")),
			"laser": _ra2_flag(e.get("IsLaser")), "electric_bolt": _ra2_flag(e.get("IsElectricBolt"))}
		rule["beam"] = _compile_ra2_beam_spec(row, e, rule)
		_weapon_combat_rules[id] = rule
	_unit_land_blocked.clear()
	_unit_naval_targeting.clear()
	_unit_warp_blocked.clear()
	_unit_sonic_type_immune.clear()
	var overrides: Dictionary = allied_capabilities.get("units", {})
	for id in ra2_source_units:
		var e: Dictionary = ra2_source_units[id].get("extra", {})
		_unit_land_blocked[id] = int(e.get("LandTargeting", 0)) == 1
		_unit_naval_targeting[id] = int(e.get("NavalTargeting", 0))
		_unit_sonic_type_immune[id] = _ra2_flag(e.get("TypeImmune"))
		_unit_warp_blocked[id] = str(e.get("Warpable", "yes")).to_lower() in ["no", "false", "0"]
	for id in overrides:
		# AlliedAbilities.source replaces (not merges) the source row.
		_unit_warp_blocked[id] = str(overrides[id].get("Warpable", "yes")).to_lower() in ["no", "false", "0"]

func projectile_combat_rule(id: String) -> Dictionary:
	return _projectile_combat_rules.get(id.to_lower(), _EMPTY_STATIC_RULE)

func projectile_blocks_ground(id: String) -> bool:
	return _projectiles_blocking_ground.has(id.to_lower())

func warhead_combat_rule(id: String) -> Dictionary:
	return _warhead_combat_rules.get(id.to_lower(), _EMPTY_STATIC_RULE)

func warhead_blocks_friendly_damage(id: String) -> bool:
	return warhead_combat_rule(id).get("blocks_friendly_damage", false)

func weapon_combat_rule(id: String) -> Dictionary:
	return _weapon_combat_rules.get(id.to_lower(), _EMPTY_STATIC_RULE)

func weapon_is_sonic(id: String) -> bool:
	return weapon_combat_rule(id).get("sonic", false)

func unit_blocks_land_targeting(id: String) -> bool:
	return _unit_land_blocked.get(id, false)

func unit_naval_targeting(id: String) -> int:
	return _unit_naval_targeting.get(id, 0)

func unit_blocks_warp(id: String) -> bool:
	return _unit_warp_blocked.get(id, false)

func unit_sonic_type_immune(id: String) -> bool:
	return _unit_sonic_type_immune.get(id, false)

func ra2_impact_anims(warhead_id: String) -> Array:
	return warhead_combat_rule(warhead_id).get("impact_anims", [])

static func _parse_impact_anims(l) -> Array:
	if l == null:
		return []
	if typeof(l) == TYPE_ARRAY:
		return l
	var out: Array = []
	for part in str(l).split(","):
		var t := part.strip_edges()
		if t != "":
			out.append(t)
	return out

static func _combat_number(v, fallback: float) -> float:
	return fallback if v == null or str(v) == "" else float(v)

## 弹头 CellSpread（RA2 溅射半径，单位＝格）
func ra2_cell_spread(warhead_id: String) -> float:
	return warhead_combat_rule(warhead_id).get("cell_spread", 0.0)

## JSON 里可能为 null 的数值字段安全转 float（float(null) 在 Godot 会报错）
static func _num(v, def: float = 0.0) -> float:
	if v == null:
		return def
	return float(v)

func has_ra2_warhead(warhead_id: String) -> bool:
	return ra2_warheads.has(warhead_id.to_lower())

func ra2_warhead_verses(warhead_id: String) -> Dictionary:
	return ra2_warheads.get(warhead_id.to_lower(), {})

## 弹头对某护甲类别的倍率；返回 -1 表示无该弹头数据（调用方回退旧克制表）
func ra2_verse(warhead_id: String, armor_class: String) -> float:
	var w: Dictionary = ra2_warheads.get(warhead_id.to_lower(), {})
	if w.is_empty():
		return -1.0
	var verses: Dictionary = w.get("verses", {})
	return float(verses.get(armor_class, 1.0))

## 引擎旧护甲词表 / RA2 类别 -> 统一到 RA2 类别
func to_ra2_armor(a: String) -> String:
	if RA2_ARMOR_ORDER.has(a):
		return a
	return str(ENGINE_TO_RA2_ARMOR.get(a, "none"))

## RA2 类别 -> 引擎旧词表（"air" 保留，供旧路径/UI）
func to_engine_armor(a: String) -> String:
	if a == "air":
		return "air"
	if ENGINE_TO_RA2_ARMOR.has(a):
		return a
	return str(RA2_TO_ENGINE_ARMOR.get(a, "unarmored"))

func ra2_armor_label(a: String) -> String:
	return str(RA2_ARMOR_LABELS.get(a, a))
