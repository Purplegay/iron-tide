extends "res://tests/base_recovery_regression.gd"

func _ready() -> void:
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not ProjectSettings.get_setting("application/config/use_custom_user_dir", false):
		get_tree().quit(2)
		return
	await get_tree().process_frame
	await lobby_options()
	for size in [2400, 3200, 4000]:
		await opening(size)
	BattleRequest.configure_skirmish(MatchRules.EXTENDED, {"opening": "mcv", "starting_funds": 4000})
	check(BattleRequest.skirmish_config.opening == "prebuilt" and BattleRequest.skirmish_config.starting_funds == 4000,
		"extension rejects MCV option without changing original starting funds")
	BattleRequest.configure_skirmish(MatchRules.RA2, {"opening": "invalid", "starting_funds": 4000})
	check(BattleRequest.skirmish_config.opening == "prebuilt", "unknown opening falls back to existing base")
	var f := FileAccess.open(output_dir.path_join("result.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks": checks, "failed": failed}, "  "))
	f.close()
	get_tree().quit(0 if failed == 0 else 1)

func lobby_options() -> void:
	BattleRequest.configure_skirmish(MatchRules.RA2, {"opening": "mcv", "starting_funds": 4000})
	check(BattleRequest.skirmish_config.starting_funds == 8000, "MCV opening enforces explicit minimum economic budget")
	# Lobby preferences now own restoration independently of the active match.
	check(preload("res://scripts/ui/lobby_preferences.gd").write({"rules_mode": "ra2", "opening": "mcv", "starting_funds": 8000}) == OK, "isolated remembered MCV fixture saved")
	var lobby = load("res://scenes/lobby.tscn").instantiate()
	add_child(lobby)
	check(lobby._opening_opt.selected == 1 and lobby._funds_opt.is_item_disabled(0), "lobby restores opening and blocks insufficient funds option")
	lobby._funds_opt.select(0)
	lobby._on_opening_selected(1)
	check(lobby._funds_opt.selected == 1 and lobby._opening_opt.tooltip_text.contains("8000"),
		"selecting MCV automatically upgrades budget with visible explanation")
	lobby._on_mode_selected(1)
	check(lobby._opening_opt.selected == 0 and lobby._opening_opt.is_item_disabled(1) and not lobby._funds_opt.is_item_disabled(0),
		"extension switch restores prebuilt option and 4000 budget")
	lobby._on_mode_selected(0)
	check(not lobby._opening_opt.is_item_disabled(1), "RA2 switch restores MCV option")
	lobby._opening_opt.select(1)
	lobby._on_opening_selected(1)
	for size in [Vector2i(1280, 720), Vector2i(1600, 900)]:
		get_window().size = size
		await get_tree().process_frame
		await get_tree().process_frame
		for control in [lobby._opening_opt, lobby._funds_opt, lobby._country_opt]:
			check(Rect2(Vector2.ZERO, Vector2(size)).encloses(control.get_global_rect()), "lobby controls fit " + str(size))
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(output_dir.path_join("lobby-" + str(size.x) + ".png"))
	lobby.free()
	await get_tree().process_frame

func opening(size: int) -> void:
	prefix = str(size) + ": "
	BattleRequest.configure_skirmish(MatchRules.RA2, {"opening": "mcv", "map_size": size, "starting_funds": 8000, "difficulty": 1})
	screen = load("res://scenes/battle.tscn").instantiate()
	add_child(screen)
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	battle = screen.battle
	await get_tree().process_frame
	# Generated civilian sites are map scenery; neither faction starts with a base.
	check(battle.mcv_opening() and battle.buildings.filter(func(b): return b.side in ["ally", "enemy"]).is_empty() and battle.units.size() == 2, prefix + "real map starts with two MCVs and no faction buildings")
	check(battle.funds == 8000.0 and battle.enemy_funds == 8000.0, prefix + "sides receive equal funds without paying for initial MCV")
	var ally
	for unit in battle.units:
		check(unit.unit_id == "AMCV" and not unit.has_move_order, prefix + unit.side + " starts stationary without gifts or miners")
		check(battle.construction_deploy_check(unit).ok, prefix + unit.side + " spawn footprint is valid on actual generated map",
			battle.construction_deploy_check(unit))
		if unit.side == "ally":
			ally = unit
	check(battle.selected_units == [ally], prefix + "player MCV starts selected")
	battle._check_end()
	check(not battle.ended, prefix + "zero initial buildings does not end match")
	screen.hud._cmd("deploy")
	check(battle.owned_building_ids().has("GACNST"), prefix + "actual command deploys starting MCV")
	var ai = battle.skirmish_ai
	ai._process(6.0)
	check(battle.owned_building_ids("enemy").has("GACNST"), prefix + "AI deploys starting MCV")
	for id in ["GAPOWR", "GAREFN"]:
		battle.request_structure(id)
		var before: float = battle.funds
		for tick in 500:
			battle._update_power()
			battle._tick_structure_queue(1.0)
			if int(battle.struct_ready.get(id, 0)) > 0:
				break
		check(int(battle.struct_ready.get(id, 0)) == 1 and is_equal_approx(before - battle.funds, float(GameData.get_building(id).cost)),
			prefix + id + " player production is paid exactly")
		var pos := placement(id, "ally")
		check(pos != Vector2.INF, prefix + id + " generated map has reachable construction footprint")
		if pos == Vector2.INF:
			await finish()
			return
		battle.request_structure(id)
		battle._try_place_building(pos)
		battle.buildings.back()._process(10.0)
		battle._update_power()
	var refinery
	for building in battle.buildings:
		if building.side == "ally" and building.is_refinery():
			refinery = building
	check(refinery != null and refinery.enqueue("CMIN"), prefix + "player refinery can make first miner without factory")
	var before_miner: float = battle.funds
	for tick in 200:
		refinery._process(1.0)
		if refinery.production.is_empty():
			break
	check(is_equal_approx(before_miner - battle.funds, 1400.0), prefix + "player pays actual first miner price")
	var first_miner
	for tick in 1500:
		ai._process(1.0)
		battle._update_power()
		battle._tick_structure_queue(1.0)
		for building in battle.buildings.duplicate():
			if is_instance_valid(building) and building.side == "enemy":
				building._process(1.0)
		for unit in battle.units:
			if unit.side == "enemy" and unit.is_harvester:
				first_miner = unit
		if first_miner != null:
			break
	var owned: Array = battle.owned_building_ids("enemy")
	check(first_miner != null and owned.has("GAPOWR") and owned.has("GAREFN"), prefix + "AI builds power refinery and receives its construction gift miner", owned)
	check(is_equal_approx(battle.enemy_funds, 5200.0), prefix + "AI pays exactly 2800 for power and refinery; gift miner is not charged", battle.enemy_funds)
	check(not owned.has("GAWEAP") and not owned.has("GAPILE"), prefix + "AI does not divert first miner funds into army")
	if first_miner != null:
		# Freeze AI/production and run actual miner round trip against untouched map ore.
		var money_before: float = battle.enemy_funds
		screen.process_mode = Node.PROCESS_MODE_ALWAYS
		for actor in battle.get_children():
			actor.process_mode = Node.PROCESS_MODE_DISABLED
		battle.set_process(false)
		battle.enemy_root.process_mode = Node.PROCESS_MODE_ALWAYS
		for actor in battle.enemy_root.get_children():
			actor.process_mode = Node.PROCESS_MODE_DISABLED
		first_miner.process_mode = Node.PROCESS_MODE_ALWAYS
		for tick in 7200:
			await get_tree().physics_frame
			if battle.enemy_funds > money_before:
				break
		check(battle.enemy_funds > money_before, prefix + "AI first miner completes actual ore collection return and deposit", {"funds": battle.enemy_funds, "state": first_miner.harvest_state})
		first_miner.process_mode = Node.PROCESS_MODE_DISABLED
		screen.process_mode = Node.PROCESS_MODE_DISABLED
	battle._check_end()
	check(not battle.ended, prefix + "both built bases remain active")
	if DisplayServer.get_name() != "headless":
		for building in battle.buildings:
			if building._buildup_play >= 0.0:
				building._process(10.0)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(output_dir.path_join("opening-" + str(size) + ".png"))
	await finish()

func placement(id: String, side: String) -> Vector2:
	for anchor in battle.buildings:
		if anchor.side != side:
			continue
		for distance in [160.0, 200.0, 240.0, 280.0, 320.0]:
			for direction in 32:
				var p: Vector2 = battle.snap_build_pos(anchor.global_position + Vector2.RIGHT.rotated(TAU * direction / 32.0) * distance)
				if battle.build_spot_ok(p, GameData.get_building(id), true, side).ok:
					return p
	return Vector2.INF
