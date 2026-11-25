extends "res://tests/production_reason_regression.gd"

const COUNTRIES := ["美国", "韩国", "法国", "德国", "英国"]
const IDS := ["Americans", "Alliance", "French", "Germans", "British"]
const EXCLUSIVE := {"SNIPE": "英国", "TNKD": "德国", "BEAG": "韩国", "GTGCAN": "法国"}

func allowed(_mode: String, country: String, id: String) -> bool:
	if id == "ORCA":
		return country != "韩国"
	return not EXCLUSIVE.has(id) or EXCLUSIVE[id] == country

func exercise_mode(mode: String) -> void:
	for index in COUNTRIES.size():
		var country: String = COUNTRIES[index]
		var enemy: String = COUNTRIES[(index + 1) % COUNTRIES.size()]
		BattleRequest.configure_skirmish(mode, {"map_size": 5000, "starting_funds": 20000,
			"country": country, "enemy_country": IDS[(index + 1) % IDS.size()]})
		screen = load("res://scenes/battle.tscn").instantiate()
		stage.add_child(screen)
		battle = screen.battle
		screen.process_mode = Node.PROCESS_MODE_DISABLED
		check(battle._countries.enemy == IDS[(index + 1) % IDS.size()], mode + country + ": opponent identity survives setup")
		for id in ["SNIPE", "TNKD", "BEAG", "ORCA"]:
			check(battle.skirmish_ai._unit_pool.has(id) == allowed(mode, enemy, id), mode + enemy + ": AI country roster " + id)
		if mode == MatchRules.EXTENDED and country == "韩国":
			check(battle.units.any(func(u): return u.side == "ally" and u.unit_id == "BEAG") and not battle.units.any(func(u): return u.side == "ally" and u.unit_id == "ORCA"), "Korean opening provides Black Eagle")
		GM.infinite_funds = false
		GM.infinite_power = false
		GM.no_build_time = false
		Events.battle_message.connect(record_message)
		for side in ["ally", "enemy"]:
			var owner: String = country if side == "ally" else enemy
			var label := "%s %s %s: " % [mode, country, side]
			var producers := {}
			for i in 3:
				var id: String = ["GAPILE", "GAWEAP", "GAAIRC"][i]
				var building = battle._place_building(id, side, Vector2(2000 + 350 * i, 2200 if side == "ally" else 3400), true)
				building._buildup_play = -1.0
				producers[id] = building
			battle._update_power()
			for id in ["SNIPE", "TNKD", "BEAG", "ORCA", "MTNK", "DOG", "ENGINEER"]:
				var producer = producers[GameData.get_unit(id).built_at]
				var expected := allowed(mode, owner, id)
				var reason: String = producer.queue_block_reason(id)
				check(reason.is_empty() == expected, label + id + " availability matches independent country matrix", reason)
				check(producer.can_queue(id) == expected, label + id + " AI availability agrees")
				var funds: float = battle.funds_for(side)
				check(producer.enqueue(id) == expected, label + id + " actual enqueue enforces owner country")
				if not expected:
					check("国家" in reason, label + id + " rejected with country reason")
					check(producer.production.is_empty() and battle.funds_for(side) == funds, label + id + " rejected order preserves queue and money")
					# Exercise execution guard as well, without trusting admission alone.
					if producer.production.is_empty():
						producer.production.append(id)
				producer._process(1.0)
				check((producer.progress > 0.0 and battle.funds_for(side) < funds) if expected
					else (producer.progress == 0.0 and battle.funds_for(side) == funds),
					label + id + " execution only charges permitted production")
				producer.cancel_at(0)
				check(is_equal_approx(battle.funds_for(side), funds), label + id + " cancellation preserves exact treasury")
				if expected:
					var actors: Array = battle.units.duplicate()
					producer.enqueue(id)
					var duration: float = GameData.ra2_build_time(GameData.get_unit(id))
					for tick in 4:
						producer._process(duration)
					var spawned: Array = battle.units.filter(func(actor): return not actors.has(actor))
					check(spawned.size() == 1 and spawned[0].unit_id == id and spawned[0].side == side
						and producer.production.is_empty(), label + id + " permitted production creates one real unit")
					check(is_equal_approx(funds - battle.funds_for(side), float(GameData.get_unit(id).cost)),
						label + id + " full production charges exactly once")
					for actor in spawned:
						battle.units.erase(actor)
						actor.free()
				if side == "ally":
					var state: Dictionary = screen.hud._unit_state(id)
					check(state.ok == expected and (expected or "国家" in state.reason), label + id + " HUD matches production authority")
			var expected_cannon := allowed(mode, owner, "GTGCAN")
			var jobs: Array = battle.struct_queue if side == "ally" else battle.enemy_struct_queue
			jobs.clear()
			var funds: float = battle.funds_for(side)
			battle.request_structure("GTGCAN", side)
			check((not jobs.is_empty()) == expected_cannon, label + "grand cannon request enforces owner country")
			if not expected_cannon:
				jobs.append({"id": "GTGCAN", "cost": 2000.0, "time": 40.0, "elapsed": 0.0, "paid": 0.0})
			battle._tick_structure_jobs(1.0, jobs, {}, side)
			check((battle.funds_for(side) < funds) if expected_cannon else battle.funds_for(side) == funds,
				label + "grand cannon execution only charges permitted country")
			if side == "ally":
				var state: Dictionary = screen.hud._build_state("GTGCAN")
				check(state.ok == expected_cannon, label + "grand cannon HUD matches authority")
				check(screen.hud._build_state("GAAIRC").ok, label + "shared airport remains available including USA")
			jobs.clear()
		screen.hud.select_prod_tab("vehicle")
		await refresh_reasons()
		var expected_tank := allowed(mode, country, "TNKD")
		check(screen.hud._prod_buttons["TNKD"].disabled == not expected_tank,
			mode + country + ": actual sidebar disables wrong-country tank")
		if not expected_tank:
			check("德国" in screen.hud._prod_buttons["TNKD"].tooltip_text, mode + country + ": tooltip names required country")
			messages.clear()
			screen.hud._explain_disabled_cameo("TNKD")
			check("德国" in last_message() and not "资金不足" in last_message(), mode + country + ": disabled card activation explains country")
		# Editing the next-battle request must not change the active battle's country.
		BattleRequest.skirmish_config["country"] = "德国" if country != "德国" else "美国"
		check(screen.hud._unit_state("TNKD").ok == expected_tank, mode + country + ": active country is captured at battle setup")
		Events.battle_message.disconnect(record_message)
		screen.free()
		await get_tree().process_frame

	await exercise_soviets(mode)

func exercise_soviets(mode: String) -> void:
	var countries := ["苏俄", "古巴", "伊拉克", "利比亚"]
	var identities := ["Russians", "Confederation", "Arabs", "Africans"]
	var exclusives := {"TTNK": "苏俄", "TERROR": "古巴", "DESO": "伊拉克", "DTRUCK": "利比亚"}
	for index in countries.size():
		var country: String = countries[index]
		var enemy: String = countries[(index + 1) % countries.size()]
		BattleRequest.configure_skirmish(mode, {"map_size": 5000, "starting_funds": 20000,
			"country": country, "enemy_country": enemy, "enemy_base": "allied"})
		screen = load("res://scenes/battle.tscn").instantiate()
		stage.add_child(screen)
		battle = screen.battle
		screen.process_mode = Node.PROCESS_MODE_DISABLED
		check(battle._countries.enemy == identities[(index + 1) % identities.size()] and battle.skirmish_ai.enemy_base == "soviet" and battle.roster_faction("enemy") == "soviet", mode + enemy + ": chosen country overrides stale faction, retains Soviet identity")
		check(battle.owned_building_ids("enemy").has("NACNST"), mode + enemy + ": actual Soviet base spawns")
		for side in ["ally", "enemy"]:
			var owner: String = country if side == "ally" else enemy
			var producers := {}
			for i in 4:
				var id: String = ["NAHAND", "NAWEAP", "NARADR", "NATECH"][i]
				var building = battle._place_building(id, side, Vector2(2000 + 350 * i, 2200 if side == "ally" else 3400), true)
				building._buildup_play = -1.0
				producers[id] = building
			battle._update_power()
			for id in ["TTNK", "TERROR", "DESO", "DTRUCK", "HTNK", "E2"]:
				var expected: bool = not exclusives.has(id) or exclusives[id] == owner
				var producer = producers[GameData.get_unit(id).built_at]
				var label: String = mode + owner + side + id
				check(producer.can_queue(id) == expected, label + ": country production gate")
				var funds: float = battle.funds_for(side)
				check(producer.enqueue(id) == expected, label + ": actual queue admission")
				if not expected: producer.production.append(id)
				producer._process(1.0)
				check((producer.progress > 0.0 and battle.funds_for(side) < funds) if expected else (producer.progress == 0.0 and battle.funds_for(side) == funds), label + ": execution charges permitted country only")
				producer.cancel_at(0)
				if side == "enemy":
					check(battle.skirmish_ai._unit_pool.has(id) == expected, label + ": AI candidates match country")
				else:
					check(screen.hud._unit_state(id).ok == expected, label + ": player HUD matches country")
		screen.free()
		await get_tree().process_frame
