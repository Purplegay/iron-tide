extends "res://tests/allied_abilities_regression.gd"

func exercise_mode(mode: String) -> void:
	setup_logistics_scene(mode, "美国")
	for group in ["obstacles", "resource_nodes"]:
		for node in get_tree().get_nodes_in_group(group): node.free()
	for node in battle.units + battle.buildings: node.free()
	battle.units.clear(); battle.buildings.clear()
	battle.water_rects = []; battle.path_service.set_water([])
	if battle.fog != null: battle.fog.free(); battle.fog = null
	for thief in ["ally", "enemy"]:
		for money in [0.0, 1.0, 8000.0, 12345.5]:
			var victim := "enemy" if thief == "ally" else "ally"
			var target = battle._place_building("GAREFN", victim, Vector2(2107, 2109), true)
			target.process_mode = Node.PROCESS_MODE_ALWAYS
			target.set_process(false); target._buildup_play = -1.0
			var spy = actor("SPY", thief, target.position + Vector2(180, 0))
			spy.position = AlliedAbilities.approach(spy, target)
			battle.funds = 20000.0 if thief == "ally" else money
			battle.enemy_funds = money if thief == "ally" else 20000.0
			var initial_ally: float = battle.funds
			var initial_enemy: float = battle.enemy_funds
			var events: Array = []
			var observe := func(_amount):
				events.append([battle.funds, battle.enemy_funds])
				spy._physics_process(0.1) # Synchronous consumer must not settle twice.
			Events.funds_changed.connect(observe)
			check(AlliedAbilities.use(spy, "allied_infiltrate", target), mode + thief + ": refinery accepts spy")
			await get_tree().physics_frame
			for tick in 300:
				spy._physics_process(1.0 / 60.0)
				if spy._dead: break
			Events.funds_changed.disconnect(observe)
			var expected_ally: float = initial_ally + money * 0.5 * (1.0 if thief == "ally" else -1.0)
			var expected_enemy: float = initial_enemy + money * 0.5 * (-1.0 if thief == "ally" else 1.0)
			check(spy._dead and is_equal_approx(battle.funds, expected_ally) and is_equal_approx(battle.enemy_funds, expected_enemy),
				mode + thief + ": correct actual two-sided transfer " + str(money), [initial_ally, initial_enemy, battle.funds, battle.enemy_funds, events])
			check(is_equal_approx(battle.funds + battle.enemy_funds, initial_ally + initial_enemy), mode + thief + ": funds conserved")
			check(events.is_empty() if money == 0.0 else events.size() == 1, mode + thief + ": one player HUD update")
			check(events.all(func(row): return is_equal_approx(row[0], expected_ally) and is_equal_approx(row[1], expected_enemy)), mode + thief + ": HUD sees both balances committed together")
			var receipt: Dictionary = battle.allied_state.get("last_spy_transfer", {})
			check(receipt.get("thief") == thief and receipt.get("victim") == victim and receipt.get("amount") == money * 0.5, mode + thief + ": diagnostic receipt identifies beneficiary and victim")
			remove_actor(spy); battle.buildings.erase(target); target.free()
	screen.free()
	await get_tree().process_frame
