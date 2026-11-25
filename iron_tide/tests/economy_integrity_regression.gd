extends "res://tests/base_recovery_regression.gd"

func _ready() -> void:
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not ProjectSettings.get_setting("application/config/use_custom_user_dir", false):
		get_tree().quit(2)
		return
	await get_tree().process_frame
	for mode in [MatchRules.RA2, MatchRules.EXTENDED]:
		start(mode)
		for side in ["ally", "enemy"]:
			var miner = battle.spawn_unit("CMIN", side, Vector2(1200, 1200))
			var ore = preload("res://scripts/world/resource_node.gd").new()
			ore.position = Vector2(1230, 1200)
			battle.add_child(ore)
			ore.amount = 1000.0
			await get_tree().physics_frame
			miner.process_mode = Node.PROCESS_MODE_ALWAYS
			miner.set_physics_process(false)
			miner.set_process(false)
			await get_tree().physics_frame
			miner.resource_node = ore
			miner.has_move_order = false
			miner.harvest_state = "harvesting"
			miner.cargo = miner.cargo_cap - 1.0
			var before: float = ore.amount
			miner._process_harvester(2.0)
			check(is_equal_approx(before - ore.amount, 1.0), prefix + side + " near-full cargo takes only available capacity", before - ore.amount)
			check(is_equal_approx(miner.cargo, miner.cargo_cap), prefix + side + " fills cargo exactly")
			check(miner.harvest_state == "to_base", prefix + side + " full cargo returns to refinery")
			before = ore.amount
			check(ore.extract(-10.0) == 0.0 and ore.amount == before, prefix + side + " negative extraction cannot create ore")
			miner.harvest_state = "harvesting"
			miner.cargo = 0.0
			miner._process_harvester(-1.0)
			check(miner.cargo == 0.0 and ore.amount == before, prefix + side + " negative elapsed time cannot change cargo or deposit")
			miner.free()
			ore.free()
			var factory
			for building in battle.buildings:
				if building.side == side and building.building_id == "GAPILE":
					factory = building
			check(factory != null, prefix + side + " real production building exists")
			if factory != null:
				factory._buildup_play = -1.0
				var balance: float = battle.funds_for(side)
				check(factory.enqueue("E1"), prefix + side + " queue accepts infantry")
				var price: float = GameData.get_unit("E1").cost
				var duration: float = GameData.ra2_build_time(GameData.get_unit("E1")) / factory.build_speed
				factory._process(duration * 0.3)
				var paid: float = factory.production_paid
				check(paid > 0.0 and paid < price and is_equal_approx(balance - battle.funds_for(side), paid), prefix + side + " partial progress pays exactly accrued cost")
				var elapsed: float = factory.progress
				battle.spend_side(side, battle.funds_for(side))
				factory._process(duration)
				check(factory.progress == elapsed and factory.production_paid == paid and factory.production.size() == 1, prefix + side + " insufficient funds never finishes or drops queue")
				check(factory.cancel_at(0) and is_equal_approx(battle.funds_for(side), paid), prefix + side + " cancellation refunds only amount actually paid")
				check(not factory.cancel_at(0) and is_equal_approx(battle.funds_for(side), paid), prefix + side + " repeated cancellation cannot mint money")
				battle.credit_side(side, 8000.0)
				balance = battle.funds_for(side)
				factory.enqueue("E1")
				var count: int = battle.units.size()
				factory._process(duration * 4.0)
				check(battle.units.size() == count + 1 and factory.production.is_empty(), prefix + side + " large final timestep produces exactly one unit")
				check(is_equal_approx(balance - battle.funds_for(side), price), prefix + side + " large final timestep never overcharges")
		await finish()
	var f := FileAccess.open(output_dir.path_join("result.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks": checks, "failed": failed}, "  "))
	f.close()
	Ra2Sfx.stop_all(); Music.stop(); Music.player.stream = null
	await get_tree().process_frame
	OS.delay_msec(150)
	get_tree().quit(0 if failed == 0 else 1)
