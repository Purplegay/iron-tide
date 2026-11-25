extends "res://tests/base_recovery_regression.gd"

const Parallel = preload("res://scripts/buildings/parallel_production.gd")

func _ready() -> void:
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2); return
	await get_tree().process_frame
	GM.infinite_funds = false
	GM.no_build_time = false
	GM.unlock_production_tech = true
	for mode in [MatchRules.RA2, MatchRules.EXTENDED]:
		for soviet in [false, true]:
			start(mode)
			prefix += "Soviet: " if soviet else "Allied: "
			exercise_sale(soviet)
			await finish()
	var file := FileAccess.open(output_dir.path_join("result.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failed":failed}, "  "))
	file.close()
	Ra2Sfx.stop_all(); Music.stop(); Music.player.stream = null
	get_tree().quit(0 if failed == 0 else 1)

func ensure_building(id: String):
	for b in battle.buildings:
		if b.side == "ally" and b.building_id == id and not b.is_dead(): return b
	var b = battle._place_building(id, "ally", Vector2(500 + battle.buildings.size() * 90, 1400), true)
	b._buildup_play = -1.0
	b.process_mode = Node.PROCESS_MODE_DISABLED
	return b

func exercise_sale(soviet: bool) -> void:
	battle._countries.ally = "Russians" if soviet else "Americans"
	battle.funds = 50000
	if BattleRequest.extensions_enabled():
		BattleRequest.combat_context.get_or_add("technologies", []).append("joint_ra2_production")
	for id in (["NACNST","NAPOWR","NAREFN","NAHAND","NARADR","NATECH"] if soviet else ["GACNST","GAPOWR","GAREFN","GAPILE","GAAIRC","GATECH"]):
		ensure_building(id)
	var factory_id := "NAWEAP" if soviet else "GAWEAP"
	var depot_id := "NADEPT" if soviet else "GADEPT"
	var tank := "HTNK" if soviet else "MTNK"
	var aircraft := "ZEP" if soviet else "SHAD"
	var factory = ensure_building(factory_id)
	battle._update_power()
	check(factory.enqueue(tank) and factory.enqueue(aircraft), prefix + "real factory queues tank and aircraft")
	factory._process(0.5)
	var paid: float = factory.total_production_paid()
	check(paid > 0, prefix + "factory begins installment payments")
	if BattleRequest.extensions_enabled():
		check(factory.queue_elapsed(tank) > 0 and factory.queue_elapsed(aircraft) > 0, prefix + "both parallel lanes are active")
	battle.request_structure(depot_id)
	battle._tick_structure_queue(0.5)
	var job: Dictionary = battle.current_structure_job("building")
	check(not job.is_empty() and str(job.get("id", "")) == depot_id and float(job.get("paid", 0)) > 0, prefix + "dependent depot begins real paid construction")
	if job.is_empty(): return
	var elapsed: float = job.elapsed
	var structure_paid: float = job.paid
	var cash: float = battle.funds
	check(battle.apply_building_action("sell", factory), prefix + "actual sale succeeds")
	check(is_equal_approx(battle.funds, cash + GameData.ra2_refund(int(factory.data.cost)) + paid), prefix + "sale refunds factory and all paid unit lanes exactly once")
	cash = battle.funds
	var count: int = battle.units.size()
	factory._process(1000)
	check(battle.funds == cash and battle.units.size() == count and factory.production.is_empty() and not factory.special.has(Parallel.KEY), prefix + "sold factory cannot charge or spawn units")
	check(not battle.apply_building_action("sell", factory) and battle.funds == cash, prefix + "repeat sale cannot double refund")
	battle._tick_structure_queue(1)
	check(battle.funds == cash and job.paid == structure_paid and job.elapsed == elapsed, prefix + "selling required factory immediately stops dependent construction charges")
	screen.hud.select_prod_tab("building")
	screen.hud._update_structure_status()
	check(screen.hud._structure_status.text.contains("缺少前置"), prefix + "sidebar explains missing prerequisite instead of building")
	screen.hud._update_production_live()
	check(screen.hud._prod_wipes[depot_id].phase == "blocked", prefix + "construction icon shows blocked clock")
	check(screen.hud._prod_status_labels[depot_id].text.contains("缺少前置"), prefix + "construction card explains stop")
	var replacement = ensure_building(factory_id)
	battle._tick_structure_queue(0.5)
	check(job.paid > structure_paid and job.elapsed > elapsed, prefix + "replacement factory resumes preserved construction")
	structure_paid = job.paid
	check(battle.apply_building_action("sell", replacement), prefix + "replacement can be sold")
	cash = battle.funds
	check(BattleSaves.save_slot(battle, "slot1").ok, prefix + "blocked paid job saves")
	var saved: Dictionary = BattleSaves.read_slot("slot1")
	check(saved.ok, prefix + "blocked job save validates")
	if saved.ok:
		preload("res://scripts/save/battle_snapshot.gd").new().restore(battle, saved.snapshot)
		screen.hud._toggle_pause()
		job = battle.current_structure_job("building")
		elapsed = job.elapsed
		battle._tick_structure_queue(1000)
		check(battle.funds == cash and job.paid == structure_paid and job.elapsed == elapsed, prefix + "restored blocked job cannot resume charges without factory")
	battle.cancel_structure(depot_id)
	check(is_equal_approx(battle.funds, cash + structure_paid) and battle.struct_queue.is_empty(), prefix + "cancel blocked job refunds only paid installments")
	cash = battle.funds
	battle.cancel_structure(depot_id)
	check(battle.funds == cash, prefix + "repeat cancellation never refunds twice")
	exercise_remaining_factory(factory_id, depot_id, tank, soviet)

func exercise_remaining_factory(factory_id: String, depot_id: String, tank: String, soviet: bool) -> void:
	var first = ensure_building(factory_id)
	var other = battle._place_building(factory_id, "ally", Vector2(1700, 1800), true)
	other._buildup_play = -1.0
	other.process_mode = Node.PROCESS_MODE_DISABLED
	check(first.enqueue(tank) and other.enqueue(tank), prefix + "two independent factories accept orders")
	first._process(0.25); other._process(0.25)
	battle.request_structure(depot_id)
	battle._tick_structure_queue(0.25)
	var job: Dictionary = battle.current_structure_job("building")
	var paid: float = job.paid
	var survivor_paid: float = other.total_production_paid()
	check(battle.apply_building_action("sell", first), prefix + "one of two factories sells")
	other._process(0.25)
	battle._tick_structure_queue(0.25)
	check(job.paid > paid and other.total_production_paid() > survivor_paid, prefix + "remaining factory and valid dependent construction continue")
	check(battle.apply_building_action("sell", other), prefix + "last remaining factory sells")
	paid = job.paid
	var cash: float = battle.funds
	battle._tick_structure_queue(1000)
	check(battle.funds == cash and job.paid == paid, prefix + "last factory loss stops dependent spending even at large timestep")
	battle.cancel_structure(depot_id)
	var plant := "NAPOWR" if soviet else "GAPOWR"
	battle.request_structure(plant)
	battle._tick_structure_queue(0.25)
	job = battle.current_structure_job("building")
	check(not job.is_empty() and job.paid > 0, prefix + "unrelated power plant still builds without factory")
	if job.is_empty(): return
	for b in battle.buildings.duplicate():
		if b.side == "ally" and b.building_id == ("NACNST" if soviet else "GACNST"):
			check(battle.apply_building_action("sell", b), prefix + "construction yard sells")
	cash = battle.funds
	paid = job.paid
	battle._tick_structure_queue(1000)
	check(battle.funds == cash and job.paid == paid, prefix + "last construction yard loss still prevents charges")
	check(battle.structure_production_block_reason(plant).contains("建造厂"), prefix + "missing construction yard is explicit")
