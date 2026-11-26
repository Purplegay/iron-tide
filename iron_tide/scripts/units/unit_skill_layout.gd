class_name UnitSkillLayout
extends RefCounted
## Display slots are stable; saved Ability arrays retain their objects and cooldowns.
const PRIMARY := {"R3MIRAGE": "allied_ra3_field", "GGI": "ggi_guard", "ENGINEER": "allied_engineer", "SENGINEER": "allied_engineer", "SPY": "allied_infiltrate",
	"GHOST": "", "TANY": "", "CCOMAND": "", "PTROOP": "", "CLEG": "allied_chrono", "DRON":"drone_auto_hunt"}
const SPECIAL := {"E1": "allied_deploy", "GGI": "ggi_deploy", "SPY": "allied_disguise",
	"CCOMAND": "allied_chrono", "PTROOP": "allied_release", "MGTK": "allied_mirage", "FV": "allied_unload"}

static func primary_id(id: String) -> String:
	if id in preload("res://scripts/units/ra3_soviet.gd").LABELS:return "allied_soviet_"+id.to_lower()
	if id == Ra3Expansion.FUTURE: return Ra3Expansion.BEAM
	if id == Ra3Expansion.HARBINGER: return Ra3Expansion.TOGGLE
	if PRIMARY.has(id): return PRIMARY[id]
	var configured:=str(GameData.skill_defaults.get(id, {}).get("primary", ""))
	return "" if GameData.is_gacha_skill(configured) else configured

static func without_legacy_primary(id:String,row:Dictionary) -> Dictionary:
	var primary:=str(GameData.skill_defaults.get(id,{}).get("primary",""))
	var result:=row.duplicate(true)
	if GameData.is_gacha_skill(primary):
		result.active=result.get("active",[]).filter(func(s):return str(s)!=primary)
	return result

static func migrate_card_primaries(meta) -> bool:
	if meta.academy.get("native_q_cards_removed",false):return false
	for id in meta.unit_loadouts:
		meta.unit_loadouts[id]=without_legacy_primary(id,meta.unit_loadouts[id])
	var heroes:Dictionary=meta.academy.get("hero_loadouts",{})
	for id in heroes:heroes[id]=without_legacy_primary(id,heroes[id])
	meta.academy.native_q_cards_removed=true
	return true

static func compatible(id: String, skill: String, hero := false) -> bool:
	if skill.is_empty():return true
	if GameData.get_skill(skill).get("hero_only", false) and not hero: return false
	return preload("res://scripts/rules/skill_scope.gd").compatible(id,GameData.get_skill(skill))

static func equippable(id: String, skill: String, hero := false) -> bool:
	if skill.is_empty():return true
	if skill == "ap_deploy" or skill == primary_id(id):return false
	var card:=GameData.get_skill(skill)
	if card.get("type", "") != "active" or (card.get("hero_only",false) and not hero):return false
	return preload("res://scripts/rules/skill_scope.gd").compatible(id,card)

static func normalize(id: String, loadout: Dictionary, hero := false) -> Dictionary:
	var active := ""
	for skill in loadout.get("active", []):
		if equippable(id, str(skill), hero):
			active = str(skill)
			break
	var passive := str(loadout.get("passive", ""))
	if not compatible(id, passive, hero) or GameData.get_skill(passive).get("type", "") != "passive": passive = ""
	return {"active": [active], "passive": passive}

static func find(unit, id: String) -> int:
	if id.is_empty(): return -1
	for i in unit.skills.size():
		if unit.skills[i].id == id: return i
	return -1

static func special_id(unit) -> String:
	if SPECIAL.has(unit.unit_id): return SPECIAL[unit.unit_id]
	if unit.is_harvester: return "miner_auto_harvest"
	if not unit.deploy_building_id().is_empty() or unit.logistics.capacity > 0 or unit.logistics.ammo_max > 0 or unit.data.get("deployer", false):
		return "allied_special"
	if find(unit, "ap_deploy") >= 0: return "ap_deploy"
	return ""

static func index(unit, slot: int) -> int:
	if unit.unit_id == "YURIKO": return find(unit,"yuriko_burst") if slot == 0 else -1
	match slot:
		0: return find(unit, primary_id(unit.unit_id))
		1:
			if not BattleRequest.extensions_enabled(): return -1
			if unit.skills.is_empty():return -1
			# Q identity and hero ownership are invariant within this synchronous lookup.
			var primary:=primary_id(unit.unit_id)
			var hero:bool=unit.special.has("academy_hero")
			for i in unit.skills.size():
				var id:String=unit.skills[i].id
				if id.is_empty() or id=="ap_deploy" or id==primary:continue
				var card:=GameData.get_skill(id)
				if card.get("type","")!="active" or (card.get("hero_only",false) and not hero):continue
				if preload("res://scripts/rules/skill_scope.gd").compatible(unit.unit_id,card):return i
		2: return find(unit, special_id(unit))
	return -1

static func info(unit, slot: int) -> Dictionary:
	if slot==2 and unit.unit_id=="MTNK" and unit.YRTalents.enabled(unit,unit.YRTalents.REVERSE):
		return {"id":unit.YRTalents.REVERSE,"name":"掩护倒车","desc":MetaProgress.talent_options("MTNK").grizzly_reverse.desc,"glyph":"move","ready":unit.YRTalents.reverse_ready(unit),"cooldown":unit.YRTalents.REVERSE_COOLDOWN,"cd_left":unit.special.get("reverse_cd",0.0)}
	var split=preload("res://scripts/units/ra3_reaper_split.gd")
	if slot==1 and split.unlocked(unit):
		return {"id":split.ID,"name":split.LABEL,"desc":split.HINT,"glyph":"attack","ready":split.engaged(unit)}
	var i := index(unit, slot)
	if i >= 0: return unit.ability_info(i)
	return {"name": ["固有技能（空）", "装配主动（空）", "特殊操作（空）"][slot],
		"desc": "该单位暂无此操作。" if slot != 1 else "在养成的单位改造界面装配一个主动技能；仅扩展模式启用。", "ready": false}

static func ensure(unit) -> void:
	# Old snapshots contain the injected Q Ability. Keep it only if this match
	# explicitly equipped that card in W; retain the real W object and cooldown.
	var old_primary:=str(GameData.skill_defaults.get(unit.unit_id,{}).get("primary",""))
	if unit.side=="ally" and GameData.is_gacha_skill(old_primary):
		var equipped:=BattleRequest.hero_loadout(unit.unit_id) if unit.special.has("academy_hero") else BattleRequest.unit_loadout(unit.unit_id)
		if old_primary not in equipped.get("active",[]):
			unit.skills=unit.skills.filter(func(a):return a.id!=old_primary)
	var primary := primary_id(unit.unit_id)
	if primary=="drone_auto_hunt" and preload("res://scripts/units/expansion_2_drone.gd").enabled(unit) and find(unit,primary)<0:
		var toggle:=Ability.new()
		toggle.setup({"id":primary,"name":"自动跳宿","desc":"按Q开启／关闭自动跳宿。","effect":primary,"cooldown":0})
		unit.skills.append(toggle)
	if BattleRequest.extensions_enabled() and not primary.is_empty() and find(unit, primary) < 0:
		var definition := GameData.get_skill(primary)
		if not definition.is_empty():
			var ability := Ability.new()
			ability.setup(definition)
			unit.skills.append(ability)
	if special_id(unit) == "allied_special" and find(unit, "allied_special") < 0:
		var title := "展开基地" if not unit.deploy_building_id().is_empty() else "卸下乘员" if unit.logistics.capacity > 0 else "返回机场" if unit.logistics.ammo_max > 0 else "切换模式"
		if unit.unit_id == "DESO": title = "部署辐射／收起"
		if unit.unit_id == "SCHP": title = "部署火炮／收炮起飞"
		var ability := Ability.new()
		ability.setup({"id": "allied_special", "name": title, "desc": title + "，与单位的 D 指令一致。", "effect": "allied_special"})
		unit.skills.append(ability)
	# Legacy deployment remains available in E where there is no native replacement.
	if BattleRequest.extensions_enabled() and special_id(unit).is_empty() and "ap_deploy" in GameData.skill_defaults.get(unit.unit_id, {}).get("active", []):
		var ability := Ability.new()
		ability.setup(GameData.get_skill("ap_deploy"))
		unit.skills.append(ability)
	unit._has_active_skills = not unit.skills.is_empty()
