extends "res://tests/special_mechanics_regression.gd"
const DamageTech = preload("res://scripts/rules/superweapon_damage.gd")
const TechView = preload("res://scripts/ui/technology_tree.gd")
const Soviet = preload("res://scripts/units/soviet_specials.gd")
const Death = preload("res://scripts/core/yr_death_combat.gd")

func _ready() -> void:
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2); return
	if "--cold" in OS.get_cmdline_user_args():
		await cold_load_ai()
		await cold_load()
		write_result("cold-result.json"); return
	MetaProgress.reset_save(); GM.god_mode = false; GM.one_shot_kill = false
	BattleRequest.configure_skirmish(MatchRules.EXTENDED, {})
	BattleRequest.combat_context = {"technologies":[DamageTech.LEVELS[19]]}
	check(DamageTech.multiplier("ally") == 1.0 and DamageTech.percent(-1) == 100 and DamageTech.percent(21) == 500, "invalid or non-contiguous research cannot exceed valid levels")
	var ui = TechView.new(); add_child(ui)
	var card: Dictionary = ui.cards[DamageTech.ID]
	check(card.desc.text.contains("凶残3 Lv.15（400%）") and card.desc.text.contains("友方 AI") and card.desc.text.contains("每道闪电伤害"), "technology card explains independent AI nuclear progression")
	check(not MetaProgress.research_technology(DamageTech.LEVELS[1]), "cannot skip required level")
	MetaProgress.currency.cores = 39; ui.refresh()
	check(card.button.disabled and not MetaProgress.research_technology(DamageTech.ID), "level one requires 40 cores")
	MetaProgress.currency.cores = 10000; ui.refresh()
	for level in range(1, 21):
		var before: float = MetaProgress.balance("cores")
		card.button.pressed.emit()
		check(MetaProgress.technology_owned(DamageTech.LEVELS[level-1]) and MetaProgress.balance("cores") == before - 40 * level, "real button purchases exact level and price " + str(level))
		check(card.title.text.contains("Lv.%d / 20" % level) and card.desc.text.contains("%d%%" % (100 + level * 20)), "card shows correct damage percent " + str(level))
		BattleRequest.configure_skirmish(MatchRules.EXTENDED, {}); BattleRequest.freeze_combat_context()
		check(is_equal_approx(DamageTech.multiplier("ally"), 1.0 + level * 0.2), "new match actual multiplier level " + str(level))
	check(card.button.disabled and card.button.text.contains("已满级") and MetaProgress.balance("cores") == 1600, "20 levels cost 8400 and stop at max")
	check(not MetaProgress.research_technology("superweapon_damage_21") and not MetaProgress.research_technology(DamageTech.LEVELS[19]), "max and repeated purchase cannot charge")
	check(not MetaProgress.set_technology_group_level(DamageTech.ID, 21) and not MetaProgress.set_technology_group_level(DamageTech.ID, -1), "selector rejects out of bounds")
	MetaProgress.load_save(); ui.refresh()
	check(card.levels.item_count == 21 and card.levels.get_selected_id() == 20, "all purchased levels and active selection reload")
	var baseline: Dictionary = {}
	for level in [0, 1, 10, 20]:
		MetaProgress.set_technology_group_level(DamageTech.ID, level)
		arena(MatchRules.EXTENDED)
		var sample := measure("ally")
		if level == 0: baseline = sample
		for key in ["storm_unit", "nuke_unit", "radiation"]:
			check(float(baseline[key]) > 0 and is_equal_approx(float(sample[key]), float(baseline[key]) * (1.0 + level * 0.2)), "actual damage %s at level %d" % [key, level], [sample[key], baseline[key]])
		# Native building damage floors AFTER scaling, armor and distance falloff.
		# Scaling already rounded baseline HP would incorrectly expect 1105 instead of 1107.
		for key in ["storm_building", "nuke_building"]:
			var expected := floorf(float(baseline[key + "_raw"]) * (1.0 + level * 0.2))
			check(sample[key] == expected, "scaled building damage retains native rounding %s at level %d" % [key, level], [sample[key], expected])
		for key in ["storm_recharge", "nuke_recharge", "flight", "radius", "left"]:
			check(sample[key] == baseline[key], "unchanged %s at level %d" % [key, level])
		await finish()
	for mode in [MatchRules.RA2, MatchRules.EXTENDED]:
		arena(mode)
		var side := "ally" if mode == MatchRules.RA2 else "enemy"
		var sample := measure(side)
		for key in ["storm_unit", "nuke_unit", "radiation"]:
			var scale := 1.2 if mode == MatchRules.EXTENDED else 1.0
			check(is_equal_approx(float(sample[key]), float(baseline[key]) * scale), mode + " mode-specific damage for " + side + " " + key)
		check(DamageTech.multiplier("ai2") == 1.0, "other AI house never inherits player technology")
		await finish()
	await check_ai_levels(baseline)
	await prepare_ai_save()
	await cold_load_ai()
	arena(MatchRules.EXTENDED)
	prepare_save()
	await finish()
	MetaProgress.set_technology_group_level(DamageTech.ID, 0)
	await cold_load()
	ui.free()
	write_result("result.json")

func check_ai_levels(baseline: Dictionary) -> void:
	for difficulty in 7:
		arena(MatchRules.EXTENDED)
		BattleRequest.skirmish_config.difficulty = difficulty
		BattleRequest.freeze_combat_context()
		var expected: float = [1.0, 1.2, 1.6, 2.0, 2.6, 3.4, 4.0][difficulty]
		BattleRequest.skirmish_config.difficulty = 0
		check(DamageTech.nuke_multiplier("enemy") == expected, "AI nuclear level is frozen independently of live difficulty " + str(difficulty))
		var sample := measure("enemy")
		for key in ["nuke_unit", "radiation", "storm_unit"]:
			check(is_equal_approx(float(sample[key]), float(baseline[key]) * expected), "AI actual %s difficulty %d" % [key, difficulty], [sample[key], baseline[key]])
		check(sample.nuke_building == floorf(float(baseline.nuke_building_raw) * expected), "AI nuclear building rounding " + str(difficulty))
		check(sample.storm_building == floorf(float(baseline.storm_building_raw) * expected), "AI storm building rounding " + str(difficulty))
		check(DamageTech.multiplier("enemy") == expected, "AI storm level stays frozen after lobby change " + str(difficulty))
		for key in ["storm_recharge", "nuke_recharge", "flight", "radius", "left"]:
			check(sample[key] == baseline[key], "AI preserves %s difficulty %d" % [key, difficulty])
		BattleRequest.combat_context.erase("ai_nuke_levels")
		check(DamageTech.nuke_multiplier("enemy") == 1.0 and DamageTech.multiplier("enemy") == 1.0, "battle without saved research retains native AI payload")
		await finish()
	var rows := [{"country":"美国","team":1,"seat":0}, {"country":"苏俄","team":2,"seat":1,"difficulty":6}, {"country":"苏俄","team":1,"seat":2,"difficulty":2}]
	BattleRequest.configure_skirmish(MatchRules.EXTENDED, {"houses":rows,"map_layout":"yr_crctbrd"})
	BattleRequest.freeze_combat_context()
	check(BattleRequest.friendly("ally", "ai2") and DamageTech.nuke_multiplier("ai2") == 1.6 and DamageTech.nuke_multiplier("enemy") == 4.0 and DamageTech.multiplier("ai2") == 1.6 and DamageTech.multiplier("enemy") == 4.0, "friendly and hostile AI use their own difficulty")
	check(DamageTech.nuke_multiplier("neutral") == 1.0 and DamageTech.nuke_multiplier("ai9") == 1.0 and DamageTech.multiplier("neutral") == 1.0 and DamageTech.multiplier("ai9") == 1.0, "unregistered owners never receive AI research")
	BattleRequest.configure_skirmish(MatchRules.RA2, {"difficulty":6})
	BattleRequest.freeze_combat_context()
	check(DamageTech.nuke_multiplier("enemy") == 1.0 and DamageTech.multiplier("enemy") == 1.0, "RA2 max difficulty preserves native superweapon damage")

func prepare_ai_save() -> void:
	arena(MatchRules.EXTENDED)
	if battle.fog != null: battle.fog.free(); battle.fog = null
	BattleRequest.skirmish_config.difficulty = 6
	BattleRequest.freeze_combat_context()
	var silo = add("NAMISL", "enemy", Vector2(700, 300))
	var weather = add("GAWEAT", "enemy", Vector2(300, 300))
	weather._sw_charge = weather.sw_recharge()
	check(weather.fire_superweapon(AIM), "AI launches boosted storm before save")
	var storm: Dictionary = LightningStorm.storms(battle)[0]
	check(storm.rules.damage == 1000.0, "AI storm freezes four times base damage at launch")
	AlliedAbilities.change_side(weather, "ally")
	check(storm.rules.damage == 1000.0, "capturing AI weather controller preserves launched damage")
	battle.buildings.erase(weather); weather.free()
	var unit = target_unit("ally")
	silo._sw_charge = silo.sw_recharge()
	check(silo.fire_superweapon(AIM), "AI launches boosted nuclear payload before save")
	AlliedAbilities.change_side(silo, "ally")
	battle.buildings.erase(silo); silo.free()
	battle.invalidate_building_membership()
	check(unit.hp == unit.max_hp and BattleSaves.save_slot(battle, "slot2").ok, "AI airborne payload saves after launcher capture and removal")
	await finish()

func cold_load_ai() -> void:
	BattleRequest.configure_skirmish(MatchRules.EXTENDED, {"difficulty":0})
	BattleRequest.freeze_combat_context()
	check(BattleSaves.prepare_load("slot2").ok, "AI snapshot reloads from disk")
	screen = load("res://scenes/battle.tscn").instantiate(); add_child(screen)
	screen.process_mode = Node.PROCESS_MODE_DISABLED; battle = screen.battle
	battle.paused = false; battle.ended = false; get_tree().paused = false
	var unit = battle.units.filter(func(u): return u.unit_id == "MTNK")[0]
	var launch: Dictionary = battle.allied_state.soviet_nukes[0]
	check(DamageTech.nuke_multiplier("enemy") == 4.0 and launch.damage_scale == 4.0, "AI saved level and airborne payload survive changed lobby difficulty")
	var storm: Dictionary = LightningStorm.storms(battle)[0]
	check(DamageTech.multiplier("enemy") == 4.0 and storm.rules.damage == 1000.0 and LightningStorm.source_of(storm) == null, "AI storm restores frozen damage without its launcher")
	var storm_before: float = unit.hp
	LightningStorm.strike(battle, storm, AIM)
	check(is_equal_approx(storm_before-unit.hp, Ra2Damage.target_damage(1000.0, "IonWH", unit, 0)), "restored AI storm deals four times damage exactly once")
	var before: float = unit.hp
	var payload: Dictionary = Soviet.Rules.data().weapons.NUKEPAYLOAD
	Soviet.tick_world(battle, launch.left + 0.01)
	check(is_equal_approx(before-unit.hp, Ra2Damage.target_damage(float(payload.damage)*4, payload.warhead, unit, 0)), "restored AI nuke deals 4x exactly once")
	check(battle.allied_state.rad_sites[0].superweapon_scale == 4.0, "restored AI fallout retains launch multiplier")
	await finish()

func target_unit(side := "enemy"):
	var unit = spawn("MTNK", side, AIM)
	unit.max_hp = 1000000; unit.hp = unit.max_hp
	return unit

func measure(side: String) -> Dictionary:
	if battle.fog != null: battle.fog.free(); battle.fog = null
	var weather = add("GAWEAT", side, Vector2(300, 300))
	var silo = add("NAMISL", side, Vector2(700, 300))
	# Keep the defender independent of the launcher's difficulty and AI shields.
	var target_side := "enemy" if side == "ally" else "ally"
	var unit = target_unit(target_side)
	var building = add("GAWEAP", target_side, AIM + Vector2(25, 0))
	building.max_hp = 1000000; building.hp = building.max_hp
	battle.power_low = false; battle.enemy_power.low = false
	weather._sw_charge = weather.sw_recharge(); silo._sw_charge = silo.sw_recharge()
	check(weather.fire_superweapon(AIM), "launch real storm " + side)
	var state: Dictionary = LightningStorm.storms(battle)[0]
	LightningStorm.strike(battle, state, AIM)
	var sample := {"storm_unit":unit.max_hp-unit.hp, "storm_building":building.max_hp-building.hp,
		"storm_recharge":weather.sw_recharge(), "nuke_recharge":silo.sw_recharge()}
	sample.storm_building_raw = Ra2Damage.target_damage(float(weather.superweapon.storm.damage), weather.superweapon.storm.warhead, building, 25)
	var payload: Dictionary = Soviet.Rules.data().weapons.NUKEPAYLOAD
	var distance: float = maxf(0.0, building.position.distance_to(AIM) - building.footprint_clearance(building.position.direction_to(AIM)))
	sample.nuke_building_raw = Ra2Damage.target_damage(float(payload.damage), payload.warhead, building, distance)
	unit.hp = unit.max_hp; building.hp = building.max_hp
	check(silo.fire_superweapon(AIM), "launch real nuke " + side)
	var launch: Dictionary = battle.allied_state.soviet_nukes[0]
	sample.flight = launch.left
	Soviet.tick_world(battle, launch.left + 0.01)
	sample.nuke_unit = unit.max_hp - unit.hp; sample.nuke_building = building.max_hp - building.hp
	var site: Dictionary = battle.allied_state.rad_sites[0]
	sample.radius = site.radius; sample.left = site.left
	unit.hp = unit.max_hp
	Soviet.tick_world(battle, float(Soviet.radiation_rules().interval))
	sample.radiation = unit.max_hp - unit.hp
	# Normal radiation at the same point never receives the superweapon coefficient.
	Soviet.add_radiation(battle, AIM, 2.0, 100, side)
	check(battle.allied_state.rad_sites.any(func(s): return float(s.get("superweapon_scale", 1.0)) == 1.0), "ordinary radiation remains unboosted")
	# Global warhead data remains immutable; ordinary explosions are not multiplied.
	unit.hp = unit.max_hp
	Death.queue_blast(battle, AIM, side, 100, "Nuke", "", false)
	check(is_equal_approx(unit.max_hp-unit.hp, Ra2Damage.target_damage(100, "Nuke", unit, 0)), "ordinary blast damage unchanged")
	return sample

func prepare_save() -> void:
	if battle.fog != null: battle.fog.free(); battle.fog = null
	var weather = add("GAWEAT", "ally", Vector2(300, 300))
	var silo = add("NAMISL", "ally", Vector2(700, 300))
	var unit = target_unit()
	battle.power_low = false; battle.enemy_power.low = false
	weather._sw_charge = weather.sw_recharge(); silo._sw_charge = silo.sw_recharge()
	check(weather.fire_superweapon(AIM) and silo.fire_superweapon(AIM), "both effects launch before save")
	AlliedAbilities.change_side(weather, "enemy")
	check(float(LightningStorm.storms(battle)[0].rules.damage) == float(weather.superweapon.storm.damage) * 5.0, "capturing launcher does not change launched storm")
	battle.buildings.erase(weather); weather.free()
	battle.buildings.erase(silo); silo.free()
	battle.invalidate_building_membership()
	check(BattleSaves.save_slot(battle, "slot1").ok, "source-free boosted storm and airborne nuke save")
	check(unit.hp == unit.max_hp, "save precedes both impacts")

func cold_load() -> void:
	check(MetaProgress.technology_owned(DamageTech.LEVELS[19]) and not MetaProgress.technology_active(DamageTech.ID), "profile keeps paid max level while disabled")
	check(BattleSaves.prepare_load("slot1").ok, "saved battle loads from disk")
	screen = load("res://scenes/battle.tscn").instantiate(); add_child(screen)
	screen.process_mode = Node.PROCESS_MODE_DISABLED; battle = screen.battle
	battle.paused = false; battle.ended = false; get_tree().paused = false
	var unit = battle.units.filter(func(u): return u.unit_id == "MTNK")[0]
	var state: Dictionary = LightningStorm.storms(battle)[0]
	var launch: Dictionary = battle.allied_state.soviet_nukes[0]
	check(DamageTech.multiplier("ally") == 5.0 and launch.damage_scale == 5.0 and LightningStorm.source_of(state) == null, "frozen effect survives missing launcher and disabled profile")
	var before: float = unit.hp
	LightningStorm.strike(battle, state, AIM)
	check(is_equal_approx(before-unit.hp, Ra2Damage.target_damage(float(GameData.get_building("GAWEAT").superweapon.storm.damage) * 5, "IonWH", unit, 0)), "restored storm deals 5x exactly once")
	before = unit.hp
	var payload: Dictionary = Soviet.Rules.data().weapons.NUKEPAYLOAD
	Soviet.tick_world(battle, launch.left + 0.01)
	check(is_equal_approx(before-unit.hp, Ra2Damage.target_damage(float(payload.damage)*5, payload.warhead, unit, 0)), "restored nuke deals 5x exactly once")
	var site: Dictionary = battle.allied_state.rad_sites[0]
	check(site.superweapon_scale == 5.0, "restored nuke creates boosted radiation")
	check(BattleSaves.save_slot(battle, "slot3").ok, "active boosted fallout saves to disk")
	var disk := BattleSaves.read_slot("slot3")
	check(disk.ok, "active fallout disk checksum validates")
	Snapshot.new().restore(battle, disk.snapshot)
	battle.paused = false; get_tree().paused = false
	unit = battle.units.filter(func(u): return u.unit_id == "MTNK")[0]
	site = battle.allied_state.rad_sites[0]
	var rules := Soviet.radiation_rules()
	var interval: float = rules.interval
	var radiation_level := Soviet.RadField.level_at(site, float(rules.duration)/Soviet.TPS, float(rules.level_delay)/Soviet.TPS, interval)
	var expected := floorf(ceilf(radiation_level) * float(rules.factor) * GameData.ra2_verse(rules.warhead, unit.ra2_armor) * 5.0)
	before = unit.hp; Soviet.tick_world(battle, interval)
	check(site.superweapon_scale == 5.0 and unit.hp == before - expected, "active fallout reload retains 5x without training clamp or double multiplication")
	# Legacy pending effects lacking multiplier fields retain their native payload.
	battle.allied_state.erase("rad_sites")
	battle.allied_state.soviet_nukes = [{"point":AIM,"side":"ally","left":0.1}]
	before = unit.hp; Soviet.tick_world(battle, 0.2)
	check(is_equal_approx(before-unit.hp, Ra2Damage.target_damage(float(payload.damage), payload.warhead, unit, 0)), "legacy airborne nuke does not gain new multiplier")
	await finish()

func write_result(name: String) -> void:
	FileAccess.open(output_dir.path_join(name), FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed}, "  "))
	get_tree().quit(0 if failed == 0 else 1)
