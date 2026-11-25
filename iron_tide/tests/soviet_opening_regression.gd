extends "res://tests/mcv_opening_regression.gd"

func start_soviet(country: String, opponent: String, opening: String) -> void:
	BattleRequest.configure_skirmish(MatchRules.RA2, {"country":country, "enemy_base":opponent, "map_size":3200, "starting_funds":12000, "opening":opening})
	screen = load("res://scenes/battle.tscn").instantiate()
	add_child(screen)
	battle = screen.battle
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	for b in battle.buildings: b._process(10.0)

func actor(id: String, side: String):
	for a in battle.units + battle.buildings:
		if battle.actor_alive(a) and a.side == side and a.data.id == id: return a
	return null

func _ready() -> void:
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not ProjectSettings.get_setting("application/config/use_custom_user_dir", false):
		get_tree().quit(2)
		return
	await get_tree().process_frame
	var checkpoint := OS.get_environment("IRON_TIDE_PRE_SOVIET_SAVE")
	if not checkpoint.is_empty(): check(BattleSaves.read_path(checkpoint).ok, "pre-Soviet match loads across roster upgrade")
	start_soviet("苏俄", "allied", "mcv")
	var mcv = actor("SMCV", "ally")
	check(mcv != null and actor("AMCV", "enemy") != null, "opposing MCV identities")
	check(mcv != null and mcv.deploy() and actor("NACNST", "ally") != null, "deploy Soviet yard")
	battle.request_structure("NAPOWR")
	battle._tick_structure_queue(120)
	check(battle.struct_ready.has("NAPOWR"), "deployed yard completes paid power plant")
	await finish()
	start_soviet("苏俄", "allied", "prebuilt")
	var infantry = actor("NAHAND", "ally")
	var miner = actor("HARV", "ally")
	var refinery = actor("NAREFN", "ally")
	check(infantry != null and refinery != null and miner != null and actor("CMIN", "enemy") != null, "prebuilt owners and miners")
	screen.hud.prod_tab = "building"
	screen.hud._refresh_production()
	check(not screen.hud.deck_tabs_btns.has("air") and not screen.hud.deck_tabs_btns.has("naval"), "empty Soviet air and navy tabs hidden")
	var buildings: Array = screen.hud._building_catalog()
	var units: Array = screen.hud._unit_catalog()
	check(buildings.has("NAWEAP") and not buildings.has("GAWEAP") and units.has("E2") and units.has("HTNK") and not units.has("E1"), "player production deck")
	battle.request_structure("GAWEAP")
	check(battle.struct_queue.is_empty(), "foreign construction rejected")
	var funds_before: float = battle.funds
	battle.request_structure("NAWEAP")
	battle._tick_structure_queue(120.0)
	check(battle.struct_ready.has("NAWEAP") and funds_before - battle.funds == 2000, "pay for Soviet factory")
	var site := placement("NAWEAP", "ally")
	if site != Vector2.INF:
		battle.request_structure("NAWEAP")
		battle._try_place_building(site)
	var factory = actor("NAWEAP", "ally")
	check(factory != null and not battle.struct_ready.has("NAWEAP"), "deploy completed factory through regular placement")
	if factory != null: factory._process(10.0)
	for pair in [[infantry,"E2"],[factory,"HTNK"]]:
		var producer = pair[0]
		if producer == null: continue
		check(producer.enqueue(pair[1]), "queue " + pair[1])
		var before: float = battle.funds
		producer._process(120.0)
		check(actor(pair[1], "ally") != null and is_equal_approx(before-battle.funds, GameData.get_unit(pair[1]).cost), "paid factory exit " + pair[1])
	if miner != null:
		check(miner.cargo_cap == 40 and miner.weapon.damage == 30, "armed native 40-bale miner")
		miner.cargo = miner.cargo_cap
		var value: float = miner.cargo_value()
		var money: float = battle.funds
		miner.home_base = refinery
		miner._lock_dock()
		miner.position = miner._dock_pt
		miner.harvest_state = "unloading"
		miner._unload_timer = 1.0
		miner._process_harvester(1.0)
		check(miner.cargo == 0 and is_equal_approx(battle.funds-money,value), "whole load to Soviet treasury")
	# Observe a complete automatic collection and road return on the actual opening map.
	var active = actor("HARV", "ally")
	if active != null:
		var initial_funds: float = battle.funds
		var collected := false
		active.process_mode = Node.PROCESS_MODE_ALWAYS
		active.set_physics_process(false)
		for tick in 7200:
			await get_tree().physics_frame
			active._physics_process(1.0 / 60.0)
			if active.cargo > 0: collected = true
			if battle.funds > initial_funds: break
		check(collected and battle.funds > initial_funds, "miner drives to ore, extracts and delivers unassisted", [active.harvest_state, active.cargo, str(active.position)])
	if active != null:
		var target = battle.spawn_unit("E1", "enemy", active.position + Vector2(85, 0))
		target.order_stop()
		active.set_fire_stance("defend")
		active._refresh_target()
		if is_instance_valid(active.attack_target):
			active.turret_angle = active.position.direction_to(active.attack_target.position).angle()
		check(active.attack_target == target and active._try_fire_ready(), "armed miner can fire at a nearby hostile")
	var elite: Dictionary = GameData.get_unit("HTNK").elite_weapon
	check(elite.damage == GameData.ra2_weapon(elite.ra2_weapon_id).damage and elite.damage == 90, "elite Rhino uses scoped YR weapon catalog")
	var saved: Dictionary = BattleSaves.save_slot(battle, "slot1")
	check(saved.ok and BattleSaves.read_slot("slot1").ok, "Soviet match save and read")
	destroy_buildings("enemy")
	battle._check_end()
	check(battle.ended and battle.has_base_assets("ally"), "short game ends on loss of Allied base")
	await finish()
	start_soviet("美国", "soviet", "prebuilt")
	var ai = battle.skirmish_ai
	check(actor("GACNST","ally") != null and actor("NACNST","enemy") != null and ai._unit_pool.has("HTNK"), "Soviet AI vs Allied player")
	var sentry = actor("NALASR", "enemy")
	check(sentry != null and sentry._turret_art.origins.size() == 32 and not sentry._turret_art.art.is_empty(), "Soviet sentry loads native 32-facing LASER turret")
	var war_factory = actor("NAWEAP", "enemy")
	if war_factory != null:
		battle.enemy_funds = 20000
		battle.spawn_unit("HARV","enemy",ai.rally)
		battle.spawn_unit("HARV","enemy",ai.rally + Vector2(50,0))
		ai.difficulty = 0
		ai._try_train()
		var orders: Array = []
		for b in battle.buildings:
			if b.side == "enemy": orders.append_array(b.production)
		check(orders.any(func(id): return id in ["E2", "HTNK", "FLAKT", "HTK"]), "AI orders from its paid production queue")
	else: check(false, "AI starting factory present")
	await finish()
	var result := FileAccess.open(output_dir.path_join("result.json"), FileAccess.WRITE)
	result.store_string(JSON.stringify({"checks":checks, "failed":failed}, "  "))
	result.close()
	get_tree().quit(0 if failed == 0 else 1)
