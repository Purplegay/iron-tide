extends "res://tests/base_recovery_regression.gd"

func _ready() -> void:
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not ProjectSettings.get_setting("application/config/use_custom_user_dir", false):
		get_tree().quit(2)
		return
	await get_tree().process_frame
	check(GameData.ra2_economy.resources.ore.value == 25 and GameData.ra2_economy.resources.gems.value == 50, "exported ore/gem prices match local rules.ini")
	check(GameData.ra2_economy.storage.CMIN == 20 and GameData.ra2_economy.storage.HARV == 40, "exported storage matches local rules.ini")
	for mode in [MatchRules.RA2, MatchRules.EXTENDED]:
		for side in ["ally", "enemy"]:
			await exercise_resources(mode, side)
			await exercise_war_miner(mode, side)
			await exercise_factories(mode, side)
	await exercise_maps()
	var file := FileAccess.open(output_dir.path_join("result.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failed": failed}, "  "))
	file.close()
	print("ECONOMY_DETAIL checks=", checks.size(), " failed=", failed)
	get_tree().quit(0 if failed == 0 else 1)

func building_for(side: String, id: String):
	for building in battle.buildings:
		if building.side == side and building.building_id == id:
			return building
	return null

func add_factory(side: String, id: String, pos: Vector2):
	var factory = battle._place_building(id, side, pos, true)
	factory._buildup_play = -1.0
	return factory

func exercise_war_miner(mode: String, side: String) -> void:
	start(mode)
	var classic := mode == MatchRules.RA2
	var label := mode + " " + side + " HARV: "
	var home = add_factory(side,"NAREFN", Vector2(1100,1300))
	var miner = battle.spawn_unit("HARV", side, Vector2(1400,1300))
	miner.process_mode = Node.PROCESS_MODE_ALWAYS
	miner.set_physics_process(false)
	await get_tree().physics_frame
	miner.order_stop()
	miner.home_base = home
	miner._home_tick = 1000
	check(miner.cargo_cap == 40 and is_equal_approx(miner.harvest_rate, 0.88 if classic else 22.0), label + "native cargo scale and map extraction rate")
	for kind in ["ore","gems"]:
		var field := ResourceNode.new()
		field.resource_kind = kind
		field.amount = 2000
		field.max_amount = 2000
		battle.add_child(field)
		field.position = miner.position + Vector2(20,0)
		miner.hull_angle = 0
		miner.resource_node = field
		miner.harvest_state = "harvesting"
		var quantity := 20.0 if classic else 500.0
		miner._process_harvester((quantity if kind == "ore" else 2.0 * quantity) / miner.harvest_rate)
		check(is_equal_approx(2000.0 - field.amount, quantity), label + kind + " deducts only what fits")
		if kind == "ore": check(is_equal_approx(miner.cargo_value(), 500.0), label + "half cargo earns 500")
	var mixed := 1500.0 if classic else 1000.0
	check(miner.cargo == 40 and miner.cargo_gems == 20 and miner.harvest_state == "to_base", label + "mixed load returns when full")
	check(miner.cargo_value() == mixed and screen.hud._cargo_caption(miner).ends_with("$%d" % int(mixed)), label + "HUD and full cargo value agree")
	miner.cargo_gems = 0
	check(miner.cargo_value() == 1000, label + "all ore is 1000 base")
	miner.cargo_gems = 40
	check(miner.cargo_value() == (2000.0 if classic else 1000.0), label + "gem valuation follows mode")
	miner.cargo_gems = 20
	miner._lock_dock()
	miner.position = miner._dock_pt
	miner.harvest_state = "unloading"
	miner._unload_timer = 0.5
	var money: float = battle.funds_for(side)
	var other := "enemy" if side == "ally" else "ally"
	var opposing_funds: float = battle.funds_for(other)
	var saved := BattleSaves.save_slot(battle,"slot1")
	var slot := BattleSaves.read_slot("slot1")
	check(saved.ok and slot.ok,label + "in-transit cargo round trips through save")
	if saved.ok and slot.ok:
		BattleSaves.Snapshot.new().restore(battle,slot.snapshot)
		get_tree().paused = false
		battle.paused = false
		miner = battle.units.filter(func(u): return u.unit_id == "HARV" and u.side == side)[0]
		miner.process_mode = Node.PROCESS_MODE_ALWAYS
		miner.set_physics_process(false)
		await get_tree().physics_frame
		check(miner.cargo == 40 and miner.cargo_gems == 20 and miner.cargo_value() == mixed,label + "saved native bales priced once on load")
	miner._process_harvester(0.49)
	check(battle.funds_for(side) == money,label + "no premature deposit")
	miner._process_harvester(0.01)
	check(miner.cargo == 0 and miner.cargo_gems == 0 and is_equal_approx(battle.funds_for(side)-money,mixed) and battle.funds_for(other)==opposing_funds,label + "exact one-shot deposit to owner")
	var purifier = add_factory(side,"GAOREP",Vector2(1600,1300))
	battle.power_low = false
	battle.enemy_power.low = false
	check(purifier.is_operational(), label + "purifier online")
	miner.cargo = 40
	money = battle.funds_for(side)
	miner._unload_cargo(40)
	check(battle.funds_for(side) - money == 1250 and miner.cargo == 0,label + "full ordinary load with purifier pays 1250")
	await finish()

func exercise_resources(mode: String, side: String) -> void:
	start(mode)
	prefix += side + ": "
	var classic := mode == MatchRules.RA2
	var miner = battle.spawn_unit("CMIN", side, Vector2(1200, 1200))
	check(miner.cargo_cap == (20.0 if classic else 500.0), prefix + "mode-specific capacity")
	check(is_equal_approx(miner.harvest_rate, 0.88 if classic else 22.0), prefix + "mode-specific collection adapter")
	var ore = preload("res://scripts/world/resource_node.gd").new()
	ore.position = Vector2(1240, 1200)
	ore.amount = 100.0
	ore.max_amount = 100.0
	battle.add_child(ore)
	var gems = preload("res://scripts/world/resource_node.gd").new()
	gems.resource_kind = "gems"
	gems.position = Vector2(1240, 1240)
	gems.amount = 100.0
	gems.max_amount = 100.0
	battle.add_child(gems)
	miner.process_mode = Node.PROCESS_MODE_ALWAYS
	miner.set_process(false)
	miner.set_physics_process(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	miner.harvest_rate = 10.0 # Controlled extraction fixture; runtime rate checked above.
	miner.resource_node = ore
	miner.harvest_state = "harvesting"
	miner._process_harvester(0.5)
	check(is_equal_approx(miner.cargo, 5.0) and is_equal_approx(ore.amount, 95.0), prefix + "ore extraction conserves physical quantity")
	miner.resource_node = gems
	# Mixed-resource accounting starts after the chassis has faced the new patch.
	miner.hull_angle = (gems.position - miner.position).angle()
	miner._process_harvester(0.5)
	var value := 375.0 if classic else 10.0
	check(is_equal_approx(miner.cargo, 10.0) and is_equal_approx(miner.cargo_gems, 5.0) and is_equal_approx(gems.amount, 95.0), prefix + "mixed cargo tracks gems separately")
	check(is_equal_approx(miner.cargo_value(), value), prefix + "mixed cargo value uses both prices")
	check(screen.hud._cargo_caption(miner).contains("$%d" % int(value)), prefix + "HUD shows cargo credit value")
	if side == "ally" and DisplayServer.get_name() != "headless":
		battle.select_unit(miner, false)
		battle._emit_selection()
		battle.camera.position = miner.position
		battle.camera.reset_smoothing()
		battle.camera.force_update_scroll()
		for i in 4:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(output_dir.path_join(mode + "-mixed-resources.png"))
	if classic:
		gems.amount = 0.1
		check(miner._node_ok(gems) and not gems.is_empty(), prefix + "tiny finite gem remainder remains harvestable")
		miner._process_harvester(0.1)
		check(is_zero_approx(gems.amount) and is_equal_approx(miner.cargo_gems, 5.1), prefix + "gem tail is not lost below percentage threshold")
		value = 380.0
	var stored: float = ore.amount
	battle.paused = true
	ore._process(10.0)
	check(ore.amount == stored, prefix + "pause cannot regenerate ore")
	battle.paused = false
	ore._process(-10.0)
	check(ore.amount == stored, prefix + "negative resource timestep is inert")
	gems._process(1000.0)
	check(gems.amount == (0.0 if classic else 95.0), prefix + "gems do not regenerate")
	var home = building_for(side, "GAREFN")
	miner.home_base = home
	miner.harvest_state = "unloading"
	miner._unload_timer = miner.unload_time
	miner._unload_work = 0.0
	var money: float = battle.funds_for(side)
	miner._process_harvester(0.2)
	var credited: float = battle.funds_for(side) - money
	check(credited == 0.0 and miner.cargo > 0.0, prefix + "both modes retain the whole load before one-second transfer")
	check(is_equal_approx(credited + miner.cargo_value(), value), prefix + "partial unload conserves cargo plus credits")
	var held: float = miner.cargo_value()
	home.under_construction = true
	miner._process_harvester(1.0)
	check(is_equal_approx(miner.cargo_value(), held) and is_equal_approx(battle.funds_for(side) - money, credited), prefix + "unavailable refinery preserves unpaid cargo")
	home.under_construction = false
	var replacement = add_factory(side, "GAREFN", Vector2(1900, 1200))
	miner.home_base = home
	miner.harvest_state = "unloading"
	miner._unload_timer = miner.unload_time
	home.under_construction = true
	miner._process_harvester(1.0)
	check(miner.home_base == replacement and miner.harvest_state == "to_base" and is_equal_approx(miner.cargo_value(), held), prefix + "replacement refinery requires travel and new docking before any payment")
	home.under_construction = false
	miner.home_base = home
	miner.harvest_state = "unloading"
	miner._unload_work = 0.0
	miner._unload_timer = miner.unload_time
	miner._process_harvester(20.0)
	check(miner.cargo == 0.0 and miner.cargo_gems == 0.0 and miner.harvest_state == "to_node", prefix + "remaining mixed load finishes and resumes collection")
	check(is_equal_approx(battle.funds_for(side) - money, value), prefix + "partial plus resumed unload credits exact value once")
	miner._unload_cargo(100.0)
	check(is_equal_approx(battle.funds_for(side) - money, value), prefix + "empty unload cannot duplicate credits")
	miner.cargo = 10.0
	miner.cargo_gems = 10.0
	gems.amount = 0.0
	ore.position = Vector2(1800, 1200)
	# Complete the previous unload exit before preparing a separate depleted-node fixture.
	miner._harvest_exit = Vector2.INF
	stored = ore.amount
	miner.resource_node = gems
	miner.harvest_state = "harvesting"
	miner._process_harvester(0.1)
	check(ore.amount == stored and miner.harvest_state == "to_node", prefix + "replacing depleted resource requires travel before extraction")
	miner._die()
	check(miner.cargo == 0.0 and miner.cargo_gems == 0.0 and is_equal_approx(battle.funds_for(side) - money, value), prefix + "destroyed miner loses load without payout")
	await finish()

func exercise_factories(mode: String, side: String) -> void:
	start(mode)
	prefix += side + ": "
	var classic := mode == MatchRules.RA2
	var factory = building_for(side, "GAPILE")
	var price := float(GameData.get_unit("E1").cost)
	var duration: float = GameData.ra2_build_time(GameData.get_unit("E1")) / factory.build_speed
	var money: float = battle.funds_for(side)
	check(factory.enqueue("E1"), prefix + "real barracks accepts production")
	factory._process((duration * 0.2) / BattleClock.production_scale(GameData.get_unit("E1")))
	check(is_equal_approx(factory.queue_progress(), 0.2) and is_equal_approx(factory.production_paid, price * 0.2), prefix + "initial single-factory progress and payment")
	var extra = add_factory(side, "GAPILE", Vector2(1750, 1700))
	var factor := 1.25 if classic else 1.0
	check(is_equal_approx(battle.factory_speed_factor(side, "E1"), factor), prefix + "two eligible factories apply mode-specific multiplier")
	check(is_equal_approx(factory.queue_progress(), 0.2), prefix + "new factory does not jump or rescale accumulated progress")
	factory._process((duration * 0.1) / BattleClock.production_scale(GameData.get_unit("E1")))
	var fraction := 0.2 + 0.1 * factor
	check(is_equal_approx(factory.queue_progress(), fraction) and is_equal_approx(factory.production_paid, price * fraction), prefix + "accelerated work and spending advance together")
	var third = add_factory(side, "GAPILE", Vector2(1750, 1950))
	check(is_equal_approx(battle.factory_speed_factor(side, "E1"), 1.5625 if classic else 1.0), prefix + "three factories use cumulative 0.8 duration multiplier")
	third.under_construction = true
	check(is_equal_approx(battle.factory_speed_factor(side, "E1"), factor), prefix + "unfinished factory gives no bonus")
	third.under_construction = false
	third._buildup_play = 0.0
	check(is_equal_approx(battle.factory_speed_factor(side, "E1"), factor), prefix + "deploying factory gives no bonus")
	third._buildup_play = -1.0
	third.hp = 0.0
	var original_power: float = extra.power
	extra.powered = true
	extra.power = -10000.0
	battle._update_power()
	check(battle.side_power_low(side) and battle.factory_speed_factor(side, "E1") == 1.0, prefix + "powered-off factory gives no acceleration")
	check(factory.production_work_rate("E1") < BattleClock.production_scale(GameData.get_unit("E1")), prefix + "low power still slows production")
	extra.power = original_power
	extra.powered = false
	battle._update_power()
	extra._die()
	check(is_equal_approx(battle.factory_speed_factor(side, "E1"), 1.0) and is_equal_approx(factory.queue_progress(), fraction), prefix + "destroyed factories remove only future speed bonus")
	check(not screen.hud._queue_caption(factory).contains("多厂加速"), prefix + "HUD removes lost factory bonus")
	var paid: float = factory.production_paid
	check(factory.cancel_at(0) and is_equal_approx(battle.funds_for(side), money), prefix + "speed changes preserve exact cancellation refund")
	check(paid > 0.0, prefix + "refund exercised paid work")
	extra = add_factory(side, "GAPILE", Vector2(1950, 1700))
	check(factory.enqueue("E1"), prefix + "second queue accepts production")
	check(screen.hud._queue_caption(factory).contains("多厂加速") == classic, prefix + "HUD reports actual mode-specific acceleration")
	factory._process((duration * 0.1) / BattleClock.production_scale(GameData.get_unit("E1")))
	var elapsed: float = factory.progress
	paid = factory.production_paid
	battle.spend_side(side, battle.funds_for(side))
	factory._process((duration) / BattleClock.production_scale(GameData.get_unit("E1")))
	check(factory.progress == elapsed and factory.production_paid == paid and factory.production.size() == 1, prefix + "multi-factory production pauses without funds")
	battle.credit_side(side, 8000.0)
	money = battle.funds_for(side)
	var population: int = battle.units.size()
	factory._process((duration * 10.0) / BattleClock.production_scale(GameData.get_unit("E1")))
	check(factory.production.is_empty() and battle.units.size() == population + 1, prefix + "large accelerated timestep creates exactly one unit")
	check(is_equal_approx(money - battle.funds_for(side), price - paid), prefix + "accelerated completion charges only unpaid balance")
	var refinery = building_for(side, "GAREFN")
	add_factory(side, "GAREFN", Vector2(1950, 1950))
	check(is_equal_approx(refinery.production_work_rate("CMIN"), BattleClock.production_scale(GameData.get_unit("CMIN")) * refinery._power_build_factor()), prefix + "custom refinery miner skill never gains factory bonus")
	add_factory(side, "GACNST", Vector2(1350, 1950))
	battle.request_structure("GAPOWR", side)
	var jobs: Array = battle.struct_queue if side == "ally" else battle.enemy_struct_queue
	var job: Dictionary = jobs[0]
	var seconds := float(job.time)
	battle._tick_structure_queue(seconds * 0.1 / BattleClock.production_scale(GameData.get_building("GAPOWR")))
	check(is_equal_approx(float(job.elapsed) / seconds, 0.1 * factor), prefix + "multiple construction yards accelerate structure work")
	check(is_equal_approx(float(job.paid), float(job.cost) * 0.1 * factor), prefix + "structure acceleration preserves payment fraction")
	await finish()

func exercise_maps() -> void:
	for map_size in [1800, 2400, 3200]:
		for mode in [MatchRules.RA2, MatchRules.EXTENDED]:
			BattleRequest.configure_skirmish(mode, {"map_size": map_size, "starting_funds": 8000})
			screen = load("res://scenes/battle.tscn").instantiate()
			add_child(screen)
			screen.process_mode = Node.PROCESS_MODE_DISABLED
			battle = screen.battle
			var gems := 0
			var valid := true
			for node in get_tree().get_nodes_in_group("resource_nodes"):
				if node.resource_kind == "gems":
					gems += 1
					valid = valid and not battle.in_water_world(node.global_position) and node.regen_rate == 0.0
			check(gems >= 3 if mode == MatchRules.RA2 else gems == 0, "%s/%d: central gems available only in RA2" % [mode, map_size], gems)
			check(valid, "%s/%d: generated gems are on land and finite" % [mode, map_size])
			await finish()
