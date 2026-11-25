extends Node
## Exercise actual autoloads, battle scene, units, queue and settlement in both modes.

var checks: Array = []
var failed := 0
var output_dir := ""
var last_result: Dictionary = {}

func check(ok: bool, label: String, details = null) -> void:
	checks.append({"name": label, "passed": ok, "details": details})
	if not ok:
		failed += 1
		print("FAIL ", label, " ", details)

func _ready() -> void:
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not ProjectSettings.get_setting("application/config/use_custom_user_dir", false):
		push_error("Use the isolated validation runner.")
		get_tree().quit(2)
		return
	await get_tree().process_frame
	Events.battle_ended.connect(func(result): last_result = result)
	# Real, deliberately non-neutral progression exercises the isolation boundary.
	MetaProgress.current_tier = "t4"
	for u in MetaProgress.upgrades():
		MetaProgress.upgrade_levels[str(u.id)] = 3
	var tracks := {}
	for t in MetaProgress.unit_upgrade_tracks():
		tracks[str(t.id)] = 3
	MetaProgress.unit_levels["MTNK"] = tracks
	MetaProgress.unit_loadouts["MTNK"] = {"active": ["ap_smoke", "ap_overdrive"], "passive": ""}
	check(float(MetaProgress.stat_bonuses().hp_bonus) > 1.3, "test fixture has real progression buffs")
	var catalog_before := JSON.stringify(GameData.building_index)
	for id in ["GAPOWR", "MTNK", "E1", "GAREFN", "GAWEAP"]:
		var cameo := GameData.ra2_cameo_path(id)
		check(not cameo.is_empty() and ResourceLoader.exists(cameo), "recovered production icon is connected: " + id, cameo)
	for mode in [MatchRules.RA2, MatchRules.EXTENDED, MatchRules.RA2]:
		await exercise_mode(mode)
	check(JSON.stringify(GameData.building_index) == catalog_before, "mode switches leave shared catalog unchanged")
	BattleRequest.configure_skirmish(MatchRules.RA2, {"enemy_base": "swarm"})
	check(BattleRequest.skirmish_config.enemy_base == "allied", "RA2 rejects extension enemy selection")
	BattleRequest.configure_mission("m01", {})
	check(BattleRequest.extensions_enabled() and not BattleRequest.skirmish, "wave campaign always uses extension rules")
	BattleRequest.rules_mode = MatchRules.RA2
	check(preload("res://scripts/ui/lobby_preferences.gd").write({"rules_mode": "ra2"}) == OK, "isolated RA2 lobby preferences saved")
	var lobby = load("res://scenes/lobby.tscn").instantiate()
	add_child(lobby)
	check(lobby._mode_opt.selected == 0 and lobby._enemy_opt.is_item_disabled(1), "lobby restores RA2 choice and disables swarm")
	lobby._on_mode_selected(1)
	check(not lobby._enemy_opt.is_item_disabled(1), "lobby re-enables extension enemy option")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(output_dir.path_join("lobby-modes.png"))
	lobby.free()
	BattleRequest.reset()
	var f := FileAccess.open(output_dir.path_join("result.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks": checks, "failed": failed, "evidence": {
		"project": ProjectSettings.globalize_path("res://"), "user_dir": OS.get_user_data_dir(),
		"engine": Engine.get_version_info().string, "modes": ["ra2", "iron_tide", "ra2"]
	}}, "  "))
	f.close()
	print("RULES checks=", checks.size(), " failed=", failed)
	get_tree().quit(0 if failed == 0 else 1)

func exercise_mode(mode: String) -> void:
	var ra2 := mode == MatchRules.RA2
	var prefix := mode + ": "
	BattleRequest.configure_skirmish(mode, {
		"map_size": 2400, "starting_funds": 8000, "enemy_base": "allied",
		"difficulty": 0, "country": "法国"
	})
	var screen = load("res://scenes/battle.tscn").instantiate()
	add_child(screen)
	var b = screen.battle
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	var expected_funds := 8000.0 if ra2 else 8000.0 * (1.0 + float(MetaProgress.stat_bonuses().deploy_bonus))
	check(is_equal_approx(b.funds, expected_funds), prefix + "starting funds follow selected rules", b.funds)
	var cannon_count := 0
	var plant
	for building in b.buildings:
		if building.side == "ally" and building.building_id == "GTGCAN":
			cannon_count += 1
		if building.side == "ally" and building.building_id == "GAPOWR":
			plant = building
	check(cannon_count == (0 if ra2 else 1), prefix + "country giveaway restricted to extension", cannon_count)
	var expected_hp := 750.0 if ra2 else 750.0 * float(MetaProgress.stat_bonuses().hp_bonus)
	check(is_equal_approx(plant.max_hp, expected_hp), prefix + "actual building uses mode health", plant.max_hp)
	check(is_equal_approx(plant.build_speed, 1.0 if ra2 else float(MetaProgress.stat_bonuses().build_bonus)), prefix + "building production buff isolated")
	var tank = b.spawn_unit("MTNK", "ally", Vector2(1000, 1700))
	var base_hp := float(GameData.get_unit("MTNK").hp)
	check(is_equal_approx(tank.max_hp, base_hp if ra2 else base_hp * float(MetaProgress.stat_bonuses().hp_bonus)), prefix + "unit global health buff isolated")
	check(is_equal_approx(tank.bonuses.attack_bonus, 1.0) if ra2 else tank.bonuses.attack_bonus > 1.3, prefix + "unit attack upgrades isolated")
	check(tank.skills.is_empty() if ra2 else tank.skills.size() == 2, prefix + "actual skill loadout isolated", tank.skills.size())
	check(tank._deploy_atk == 1.0 if ra2 else tank._deploy_atk > 1.0, prefix + "custom deployment multiplier isolated")
	var d := GameData.get_building("GAPOWR")
	check(is_equal_approx(GameData.ra2_build_time(d), 33.6), prefix + "both modes share native production baseline", GameData.ra2_build_time(d))
	var catalog := GameData.buildings_for_faction("allied")
	for item in catalog:
		if item.id == "GAPOWR":
			check(item.hp == d.hp, prefix + "UI catalog agrees with runtime")
	b.request_structure("GAPOWR")
	check(is_equal_approx(float(b.struct_queue[0].time), 33.6), prefix + "real queue uses mode timing")
	var before_queue: float = b.funds
	b.power_low = false
	var normal_rate: float = b.structure_work_rate("ally", "GAPOWR")
	# Convert authored work time to current production-clock seconds.
	# A half-time step is exact; cancellation must return only what was paid.
	b._tick_structure_queue(float(b.struct_queue[0].time) * 0.5 / normal_rate)
	check(is_equal_approx(before_queue - b.funds, 400.0), prefix + "real queue charges half cost at half time", before_queue - b.funds)
	b.cancel_structure("GAPOWR")
	check(is_equal_approx(before_queue, b.funds), prefix + "cancel returns paid funds")
	b.request_structure("GAPOWR")
	b._tick_structure_queue(float(b.struct_queue[0].time) + 0.3)
	check(is_equal_approx(before_queue - b.funds, 800.0), prefix + "long final frame never overcharges structure", before_queue - b.funds)
	b.cancel_structure("GAPOWR")
	var barracks
	for building in b.buildings:
		if building.side == "ally" and building.building_id == "GAPILE":
			barracks = building
	barracks._buildup_play = -1.0
	barracks.production.clear()
	barracks.progress = 0.0
	barracks.trickle = 0.0
	b.funds = 10000.0
	check(barracks.enqueue("E1"), prefix + "actual barracks accepts infantry")
	var unit_time: float = GameData.ra2_build_time(GameData.get_unit("E1")) / barracks.build_speed
	var units_before: int = b.units.size()
	barracks._process(unit_time + 0.3)
	check(is_equal_approx(10000.0 - b.funds, 200.0) and b.units.size() == units_before + 1,
		prefix + "long final frame charges exactly one unit and spawns once", 10000.0 - b.funds)
	barracks.enqueue("E1")
	barracks._buildup_play = 0.0
	var before_animation: float = b.funds
	barracks._process(0.2)
	check(is_equal_approx(before_animation, b.funds) and barracks.progress == 0.0,
		prefix + "factory cannot produce while buildup animation runs")
	barracks.cancel_queue()
	barracks._buildup_play = -1.0
	b.funds = 50.0
	barracks.enqueue("E1")
	barracks._process(unit_time * 0.5)
	check(is_equal_approx(b.funds, 0.0) and is_equal_approx(barracks.progress, unit_time * 0.25),
		prefix + "partial funds advance only paid production")
	barracks._process(unit_time)
	check(barracks.production.size() == 1 and is_equal_approx(barracks.progress, unit_time * 0.25),
		prefix + "empty funds stall production without free unit")
	barracks.cancel_at(0)
	check(is_equal_approx(b.funds, 50.0), prefix + "partial unit cancellation refunds only paid amount")
	b.funds = 1000.0
	b.request_structure("GAPOWR")
	plant.power = -10000.0
	b._update_power()
	check(b.side_power_low("ally"), prefix + "real power fixture is in shortage")
	var slow: float = b.power_build_factor()
	b._tick_structure_queue(float(b.struct_queue[0].time) * 0.5 / normal_rate)
	check(is_equal_approx(1000.0 - b.funds, 400.0 * slow),
		prefix + "low power scales structure payment with progress", slow)
	b.cancel_structure("GAPOWR")
	check(is_equal_approx(b.funds, 1000.0), prefix + "low power cancellation preserves funds")
	var before_save := JSON.stringify(MetaProgress.to_dict())
	var before_battles := int(MetaProgress.stats.get("battles", 0))
	b.end_battle(true)
	check(str(last_result.get("rules_mode", "")) == mode, prefix + "settlement identifies rules")
	if ra2:
		check(JSON.stringify(MetaProgress.to_dict()) == before_save and last_result.rewards.is_empty(), prefix + "settlement leaves progression unchanged")
	else:
		check(int(MetaProgress.stats.get("battles", 0)) == before_battles + 1 and float(last_result.rewards.credits) > 0, prefix + "extension settlement still awards progression")
	screen.free()
	await get_tree().process_frame
