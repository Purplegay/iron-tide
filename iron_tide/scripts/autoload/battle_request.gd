extends Node
## 场景间传递参数（关卡 id 等）。作为 autoload 必须是 Node 派生类。

var mission_id: String = "m01"
const Houses = preload("res://scripts/rules/skirmish_houses.gd")
var house_teams := {}

func refresh_houses() -> void:
	house_teams.clear()
	var rows: Array = skirmish_config.get("houses", [])
	if not skirmish or rows.size() <= 2 or not Houses.valid(rows,str(skirmish_config.get("map_layout","")),rules_mode==MatchRules.RA2): return
	for i in rows.size(): house_teams[Houses.id(i)] = rows[i].team

func friendly(a: String, b: String) -> bool:
	return a == b or (house_teams.has(a) and house_teams.get(b) == house_teams[a])

func is_house(side: String) -> bool:
	return side in ["ally","enemy"] or house_teams.has(side)

func is_ai_house(side: String) -> bool:
	return side == "enemy" or (side != "ally" and house_teams.has(side))

func foes_group(side: String) -> String:
	if not house_teams.is_empty(): return "opponents_of_" + side
	return "enemies" if side == "ally" else "allies"

func sync_house_groups(actor, active := true) -> void:
	for observer: String in house_teams:
		var key := foes_group(observer)
		var wanted := active and house_teams.has(actor.side) and not friendly(observer,actor.side)
		if wanted and not actor.is_in_group(key): actor.add_to_group(key)
		elif not wanted and actor.is_in_group(key): actor.remove_from_group(key)

var skirmish: bool = false
var skirmish_config: Dictionary = {}
var rules_mode: String = MatchRules.EXTENDED
var combat_context: Dictionary = {}

func extensions_enabled() -> bool:
	return rules_mode != MatchRules.RA2

func combat_bonuses() -> Dictionary:
	if not combat_context.is_empty(): return combat_context.bonuses
	return MetaProgress.stat_bonuses() if extensions_enabled() else MatchRules.neutral_bonuses()

func unit_bonus(id: String) -> Dictionary:
	return combat_context.get("unit_bonus", {}).get(id, MetaProgress.unit_stat_bonus(id))

func card_scale(id: String) -> float:
	# Redesigned cards keep the saved rank, not their retired value curves.
	if id in ["ps_grounding","ap_shock_pulse","ap_tesla_chain","ap_focus_fire"] and combat_context.has("card_ranks"):
		return MetaProgress.Academy.card_strength(int(combat_context.card_ranks.get(id,0)),GameData.get_skill(id))
	var overrides: Dictionary = combat_context.get("card_strength_overrides",{})
	if overrides.has(id): return float(overrides[id])
	if combat_context.has("card_ranks"):
		return MetaProgress.Academy.card_strength(int(combat_context.card_ranks.get(id, 0)))
	# A battle saved under the old ten-level rule retains its original modifiers.
	var level := int(combat_context.get("card_levels", {}).get(id, 1))
	return 1.0 + 0.05 * (clampi(level, 1, 10) - 1)

func unit_loadout(id: String) -> Dictionary:
	var loadouts:Dictionary=combat_context.get("loadouts",{})
	if loadouts.has(id): return UnitSkillLayout.normalize(id,loadouts[id] if combat_context.get("native_q_cards_removed",false) else UnitSkillLayout.without_legacy_primary(id,loadouts[id]))
	if GameData.building_index.has(id) and combat_context.has("loadouts"): return UnitSkillLayout.normalize(id,{})
	return MetaProgress.unit_effective_loadout(id)

func hero_loadout(id:String) -> Dictionary:
	# Old battles retain the base loadout frozen when that match started.
	if not combat_context.is_empty():
		if not combat_context.has("hero_loadouts"):return unit_loadout(id)
		var row:Dictionary=combat_context.hero_loadouts.get(id,{})
		return UnitSkillLayout.normalize(id,row if combat_context.get("native_q_cards_removed",false) else UnitSkillLayout.without_legacy_primary(id,row),true)
	return preload("res://scripts/rules/hero_loadouts.gd").effective(MetaProgress,id)

func has_unit_talent(id:String,talent:String,side:String) -> bool:
	if not extensions_enabled() or side!="ally":return false
	if not MetaProgress.talent_options(id).has(talent):return false
	if combat_context.has("unit_talents"):
		return talent in MetaProgress.selected_talents(id,combat_context.unit_talents)
	# Battles saved before talents existed retain the technology they started with.
	return id=="R3REAPER" and talent=="reaper_fire_control" and combat_context.get("technologies",[]).has(talent)

func talent_upgrade(id:String,talent:String,side:String) -> Dictionary:
	if not extensions_enabled() or side!="ally":return {}
	var rank:=MetaProgress.talent_rank(id,talent,combat_context.get("unit_talents",{}))
	if rank==0:return {}
	return MetaProgress.talent_options(id)[talent].ranks[rank-1]

func house_difficulty(side:String) -> int:
	var fallback:=clampi(int(skirmish_config.get("difficulty",1)),0,GameData.DIFFICULTY_NAMES.size()-1)
	var rows:Array=skirmish_config.get("houses",[])
	for i in range(1,rows.size()):
		if Houses.id(i)==side:return clampi(int(rows[i].get("difficulty",fallback)),0,GameData.DIFFICULTY_NAMES.size()-1)
	return fallback

func victory_difficulty() -> int:
	var rows:Array=skirmish_config.get("houses",[])
	var lowest:=GameData.DIFFICULTY_NAMES.size()
	for i in range(1,rows.size()):
		if rows[i].team!=rows[0].team: lowest=mini(lowest,house_difficulty(Houses.id(i)))
	return house_difficulty("enemy") if lowest==GameData.DIFFICULTY_NAMES.size() else lowest

func house_spawn(index:int) -> int:
	var rows:Array=skirmish_config.get("houses",[])
	if index>=rows.size():return index
	return int(rows[index].get("spawn",rows[index].get("seat",index)))

func brutal_house(side:String) -> bool:
	if combat_context.get("house_training",{}).has(side):
		return combat_context.house_training[side].difficulty==6
	return is_ai_house(side) and combat_context.get("brutal_three",false)

func enemy_logistics(side:="enemy") -> Dictionary:
	if combat_context.get("house_training",{}).has(side):return combat_context.house_training[side].logistics
	return combat_context.get("enemy_logistics", MatchRules.neutral_bonuses())

func enemy_unit_upgrades(side:="enemy") -> Dictionary:
	if combat_context.get("house_training",{}).has(side):return combat_context.house_training[side].unit
	return combat_context.get("enemy_unit_upgrades", {"attack_bonus":1.0,"defense_bonus":1.0,"skill_bonus":1.0})

func growth_attack_cap() -> float:
	# Missing on old saves deliberately means disabled, regardless of menu changes.
	return float(combat_context.get("growth_attack_cap", 0.0)) if extensions_enabled() else 0.0

func native_ore_map() -> String:
	return str(combat_context.get("native_ore_map", ""))

func freeze_combat_context() -> void:
	combat_context = {"native_training_version": 4, "hero_survival_ranks": MetaProgress.academy.get("hero_survival_ranks",{}).duplicate(), "hero_training": MetaProgress.academy.get("hero_training",{}).duplicate(true), "hero_escort_ranks": MetaProgress.academy.get("hero_escort_ranks",{}).duplicate(), "card_ranks": MetaProgress.academy.get("levels", {}).duplicate(), "bonuses": MetaProgress.stat_bonuses() if extensions_enabled() else MatchRules.neutral_bonuses(), "unit_bonus": {}, "loadouts": {},
		"unit_talents": MetaProgress.active_talents() if extensions_enabled() else {},
		"refinery_miner_disabled": extensions_enabled() and MetaProgress.technology_owned("refinery_miner") and not MetaProgress.effect_enabled("tech","refinery_miner"),
		"technologies": MetaProgress.unlocked_technologies.filter(MetaProgress.technology_active) if extensions_enabled() else []}
	if "production_recipes_2" in combat_context.technologies:
		var book := preload("res://scripts/rules/opening_order_plans.gd").current(MetaProgress.academy)
		var plan: Dictionary = book.plans[book.selected]
		combat_context.opening_orders = plan.orders.duplicate()
		combat_context.opening_plan_name = plan.name
	combat_context.hero_contracts={}
	for id in MetaProgress.academy.get("hero_contracts",{}):
		if extensions_enabled() and not MetaProgress.academy.hero_contracts[id].get("complete",false):combat_context.hero_contracts[id]=true
	combat_context.furnace_contract = extensions_enabled() and MetaProgress.academy.get("furnace_contract",false) and not MetaProgress.academy.get("furnace_complete",false)
	combat_context.hero_training_scale = MetaProgress.Academy.HERO_TRAINING_SCALE
	combat_context.auto_w_preferences=preload("res://scripts/units/auto_w.gd").preferences()
	combat_context.native_q_cards_removed=true
	combat_context.growth_attack_cap=0.0 # Legacy v0.25.81 contexts retain their original scheme.
	var difficulty := int(skirmish_config.get("difficulty", 1))
	combat_context.brutal_three = skirmish and difficulty == 6
	combat_context.final_damage_cap = {5: 3.5, 6: 2.25}.get(difficulty, 0.0) if skirmish and extensions_enabled() else 0.0
	combat_context.final_damage_threshold = 1.5 if combat_context.brutal_three else 2.0
	combat_context.hero_loadouts={}
	combat_context.commando_hero_unlocked={}
	combat_context.reinforcement_hero_unlocked={}
	for id in ["ORCA","TTNK","HARV"]:
		combat_context.reinforcement_hero_unlocked[id]=extensions_enabled() and MetaProgress.Academy.hero_build_count(MetaProgress,id)>=MetaProgress.Academy.hero_requirement(id)
	for id in MetaProgress.Academy.Commandos.IDS:
		combat_context.commando_hero_unlocked[id]=extensions_enabled() and MetaProgress.Academy.hero_build_count(MetaProgress,id)>=MetaProgress.Academy.hero_requirement(id)
	for id in MetaProgress.Academy.HEROES:
		combat_context.hero_loadouts[id]=preload("res://scripts/rules/hero_loadouts.gd").effective(MetaProgress,id)
	var layout := str(skirmish_config.get("map_layout", ""))
	if skirmish and preload("res://scripts/world/native_maps.gd").has(layout):
		combat_context.native_ore_map = layout
	combat_context.field_commission_version=2
	combat_context.bunker_talent_version=2
	combat_context.ai_nuke_levels=preload("res://scripts/rules/superweapon_damage.gd").new_match_ai_levels()
	# Freeze custom growth with the battle so restored and newly produced units agree.
	combat_context.enemy_logistics = GameData.skirmish_logistics(int(skirmish_config.get("difficulty", 1))) if skirmish else MatchRules.neutral_bonuses()
	combat_context.enemy_unit_upgrades = GameData.skirmish_unit_upgrades(int(skirmish_config.get("difficulty", 1))) if skirmish else GameData.skirmish_unit_upgrades(0)
	var rows:Array=skirmish_config.get("houses",[])
	if skirmish and rows.any(func(row):return row.has("difficulty")):
		combat_context.house_training={}
		for i in range(1,rows.size()):
			var level:=house_difficulty(Houses.id(i))
			if level>=5:combat_context.mixed_damage_caps=true
			combat_context.house_training[Houses.id(i)]={"difficulty":level,"logistics":GameData.skirmish_logistics(level),"unit":GameData.skirmish_unit_upgrades(level)}
	var overrides:Dictionary={}
	for id in combat_context.card_ranks:
		var card:=GameData.get_skill(id)
		if card.has("strength_by_rank"):
			overrides[id]=MetaProgress.Academy.card_strength(int(combat_context.card_ranks[id]),card)
	combat_context.card_strength_overrides=overrides
	combat_context.loadouts["NAFLAK"] = MetaProgress.unit_effective_loadout("NAFLAK")
	combat_context.loadouts["TESLA"] = MetaProgress.unit_effective_loadout("TESLA")
	for id in GameData.building_index:
		if preload("res://scripts/rules/skill_scope.gd").defense(id):combat_context.loadouts[id]=MetaProgress.unit_effective_loadout(id)
	for id in GameData.unit_index:
		combat_context.unit_bonus[id] = MetaProgress.unit_stat_bonus(id)
		combat_context.loadouts[id] = MetaProgress.unit_effective_loadout(id)

func configure_skirmish(mode: String, config: Dictionary) -> void:
	combat_context = {}
	rules_mode = MatchRules.normalize(mode)
	skirmish = true
	skirmish_config = config.duplicate(true)
	if skirmish_config.has("houses") and not Houses.valid(skirmish_config.houses,str(config.get("map_layout","coast")),rules_mode==MatchRules.RA2):
		skirmish_config.erase("houses")
	if skirmish_config.has("houses"):
		var colors := HouseColor.roster_color_ids(skirmish_config.houses)
		for i in range(1, skirmish_config.houses.size()): skirmish_config.houses[i].color = colors[i]
	skirmish_config.difficulty=house_difficulty("enemy")
	# Explicit country owns roster identity. Legacy faction-only requests keep
	# their former default country without overwriting a chosen Soviet nation.
	var enemy_country := str(config.get("enemy_country", ""))
	if enemy_country.is_empty():
		enemy_country = "苏俄" if config.get("enemy_base") == "soviet" else "虫群巢穴" if config.get("enemy_base") == "swarm" else "美国"
	if enemy_country == "虫群巢穴" and not extensions_enabled(): enemy_country = "美国"
	skirmish_config["enemy_country"] = enemy_country
	skirmish_config["enemy_base"] = "swarm" if enemy_country == "虫群巢穴" else GameData.ra2_country_side(enemy_country)
	skirmish_config["victory_condition"] = "annihilation" if config.get("victory_condition", "short") == "annihilation" else "short"
	skirmish_config["fog_of_war"] = typeof(config.get("fog_of_war", false)) == TYPE_BOOL and config.get("fog_of_war", false)
	var mcv_start := rules_mode == MatchRules.RA2 and str(config.get("opening", "prebuilt")) == "mcv"
	skirmish_config["opening"] = "mcv" if mcv_start else "prebuilt"
	if mcv_start:
		# 用户定制矿场造矿车：电厂 800 + 矿场 2000 + 矿车 1400 > 4000。
		skirmish_config["starting_funds"] = maxi(8000, int(config.get("starting_funds", GameData.skirmish_default_config().starting_funds)))

	refresh_houses()

func configure_mission(id: String, config: Dictionary) -> void:
	reset()
	mission_id = id
	skirmish_config = config.duplicate(true)

func reset() -> void:
	house_teams.clear()
	combat_context = {}
	mission_id = "m01"
	skirmish = false
	skirmish_config = {}
	rules_mode = MatchRules.EXTENDED
