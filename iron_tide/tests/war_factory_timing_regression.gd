extends "res://tests/selection_regression.gd"

func exercise_mode(mode: String) -> void:
	for country in ["美国", "苏俄"]:
		var factory_id: String = "GAWEAP" if country == "美国" else "NAWEAP"
		var refinery_id := "GAREFN" if country == "美国" else "NAREFN"
		for building_id: String in [factory_id, refinery_id]:
			BattleRequest.configure_skirmish(mode, {"country": country, "starting_funds": 12000, "opening": "prebuilt"})
			screen = load("res://scenes/battle.tscn").instantiate()
			stage.add_child(screen)
			screen.process_mode = Node.PROCESS_MODE_DISABLED
			battle = screen.battle
			var barracks_id: String = "GAPILE" if country == "美国" else "NAHAND"
			if not barracks_id in battle.owned_building_ids():
				battle._place_building(barracks_id, "ally", battle.player_start() + Vector2(200, 0), true)
			for building in battle.buildings:
				building._buildup_play = -1.0
			battle.power_low = false
			battle.funds = 12000
			var label: String = mode + " " + building_id
			var data: Dictionary = GameData.get_building(building_id)
			check(is_equal_approx(screen.hud.production_seconds(data), 21.0), label + " 21s on production card")
			battle.request_structure(building_id)
			check(battle.struct_queue.size() == 1, label + " accepted by real queue")
			battle._tick_structure_queue(10.5)
			check(is_equal_approx(battle.funds, 11000.0), label + " half cost at halfway")
			battle._tick_structure_queue(10.4)
			check(battle.struct_queue.size() == 1 and not battle.struct_ready.has(building_id), label + " still building at 20.9s")
			battle._tick_structure_queue(0.1)
			check(battle.struct_queue.is_empty() and battle.struct_ready.get(building_id, 0) == 1, label + " ready at 21s")
			check(is_equal_approx(battle.funds, 10000.0), label + " paid exactly 2000")
			screen.free()
			await get_tree().process_frame
