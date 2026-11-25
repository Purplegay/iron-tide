extends "res://tests/selection_regression.gd"

func exercise_mode(mode: String) -> void:
	BattleRequest.configure_skirmish(mode, {"map_size": 3200, "starting_funds": 10000})
	screen = load("res://scenes/battle.tscn").instantiate()
	stage.add_child(screen)
	battle = screen.battle
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	GM.infinite_funds = false
	GM.infinite_power = false
	GM.no_build_time = false
	var ai = battle.skirmish_ai
	ai._train_t = 1000.0
	ai._attack_t = 1000.0
	var initial: float = battle.enemy_funds
	ai._process(10.0)
	check(battle.enemy_funds == initial, mode + ": allied AI receives no passive money")
	var miners: Array = battle.units.filter(func(u): return u.side == "enemy" and u.is_harvester)
	check(miners.size() == 1, mode + ": enemy starts with a real miner")
	var ally_before: float = battle.funds
	miners[0]._deposit(300.0)
	check(battle.enemy_funds == initial + 300.0 and battle.funds == ally_before,
		mode + ": enemy cargo credits only enemy treasury")
	var first_refinery = find_building("GAREFN", "enemy")
	first_refinery._buildup_play = -1.0
	var extra_refinery = battle._place_building("GAREFN", "enemy", Vector2(2500, 2200), true)
	extra_refinery._buildup_play = -1.0
	# Easy still targets two miners; normal/hard expansion targets are covered
	# by skirmish_strength_regression with real paid refinery placement.
	var original_difficulty: int = ai.difficulty
	ai.difficulty = 0
	extra_refinery.enqueue("CMIN")
	ai._replace_miners()
	check(first_refinery.production.is_empty() and extra_refinery.production.size() == 1,
		mode + ": miner replacement counts orders at all refineries before queuing")
	extra_refinery.cancel_at(0)
	ai._replace_miners()
	check(first_refinery.production.size() == 1 and extra_refinery.production.is_empty(),
		mode + ": miner replacement queues only the missing miner")
	first_refinery.cancel_at(0)
	ai.difficulty = original_difficulty
	battle.buildings.erase(extra_refinery)
	extra_refinery.free()
	battle._refresh_pathing()
	for side in ["ally", "enemy"]:
		var factory = find_building("GAWEAP", side)
		if factory == null:
			factory = battle._place_building("GAWEAP", side, Vector2(1800, 1800), true)
		factory._buildup_play = -1.0
		factory.production.clear()
		factory.progress = 0.0
		factory.production_paid = 0.0
		battle._update_power()
		var cost: float = GameData.get_unit("MTNK").cost
		var seconds: float = GameData.ra2_build_time(GameData.get_unit("MTNK"))
		set_money(side, cost * 0.25)
		var other_before: float = battle.funds_for("enemy" if side == "ally" else "ally")
		check(factory.enqueue("MTNK"), mode + side + ": real factory accepts train order")
		factory._process(seconds)
		check(is_equal_approx(factory.production_paid, cost * 0.25) and factory.production.size() == 1,
			mode + side + ": only affordable production progress is consumed")
		var previous: float = factory.progress
		factory._process(seconds)
		check(factory.progress == previous, mode + side + ": no money pauses production")
		factory.cancel_at(0)
		check(is_equal_approx(battle.funds_for(side), cost * 0.25) and factory.production_paid == 0.0,
			mode + side + ": cancellation refunds exactly paid amount once")
		factory.cancel_at(0)
		check(is_equal_approx(battle.funds_for(side), cost * 0.25)
			and battle.funds_for("enemy" if side == "ally" else "ally") == other_before,
			mode + side + ": no duplicate or cross-side refund")
		set_money(side, cost)
		factory.enqueue("MTNK")
		var before: int = battle.units.size()
		for tick in 4:
			factory._process(seconds)
		check(battle.units.size() == before + 1 and factory.production.is_empty()
			and is_zero_approx(battle.funds_for(side)), mode + side + ": full payment produces exactly one unit at actual exit")
		check(not factory.enqueue("MGTK"), mode + side + ": missing tech prevents advanced unit queue")
	var enemy_factory = find_building("GAWEAP", "enemy")
	# Satisfy the economy floor before asserting independent military payment.
	battle.spawn_unit("CMIN", "enemy", Vector2(2300, 2300))
	ai._unit_pool.assign(["MTNK"])
	battle.enemy_funds = 2000.0
	var unit_count: int = battle.units.size()
	ai._try_train()
	check(battle.units.size() == unit_count and enemy_factory.production.size() == 1
		and battle.enemy_funds == 2000.0, mode + ": AI queues production without instant spawn or upfront duplicate charge")
	enemy_factory.cancel_at(0)
	enemy_factory.under_construction = true
	ai._try_train()
	check(enemy_factory.production.is_empty(), mode + ": unfinished factory cannot train")
	enemy_factory.under_construction = false
	var enemy_power = find_building("GAPOWR", "enemy")
	var old_power: float = enemy_power.power
	enemy_power.power = -10000.0
	battle._update_power()
	check(battle.side_power_low("enemy") and battle.power_build_factor("enemy") < 1.0,
		mode + ": enemy has its own power shortage")
	enemy_power.power = old_power
	battle._update_power()
	battle.enemy_funds = 800.0
	battle.request_structure("GAPOWR", "enemy")
	var build_time: float = GameData.ra2_build_time(GameData.get_building("GAPOWR"))
	battle._tick_structure_queue(build_time * 3.0)
	check(int(battle.enemy_struct_ready.get("GAPOWR", 0)) == 1 and is_zero_approx(battle.enemy_funds),
		mode + ": enemy uses paid timed structure queue")
	var before_buildings: int = battle.buildings.size()
	ai._try_build()
	check(battle.buildings.size() == before_buildings + 1 and battle.enemy_struct_ready.is_empty(),
		mode + ": AI places paid structure at legal base footprint")
	var hq = find_building("GACNST", "enemy")
	hq.hp = 0.0
	battle.request_structure("GAPOWR", "enemy")
	check(battle.enemy_struct_queue.is_empty() and not battle.owned_building_ids("enemy").has("GACNST"),
		mode + ": lost construction yard is not fabricated by prerequisite lookup")
	screen.free()
	Ra2Sfx.stop_all(); Music.stop(); Music.player.stream = null
	await get_tree().process_frame
	OS.delay_msec(150)

func find_building(id: String, side: String):
	for b in battle.buildings:
		if is_instance_valid(b) and b.side == side and b.building_id == id:
			return b
	return null

func set_money(side: String, amount: float) -> void:
	if side == "ally":
		battle.funds = amount
	else:
		battle.enemy_funds = amount
