extends "res://tests/selection_regression.gd"
const Tactics = preload("res://scripts/world/skirmish_tactics.gd")

func _ready() -> void:
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not ProjectSettings.get_setting("application/config/use_custom_user_dir", false):
		get_tree().quit(2)
		return
	await get_tree().process_frame
	stage = SubViewport.new()
	stage.size = Vector2i(1600, 900)
	stage.world_2d = World2D.new()
	add_child(stage)
	for mode in [MatchRules.RA2, MatchRules.EXTENDED]: await exercise_mode(mode)
	var file := FileAccess.open(output_dir.path_join("result.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failed": failed, "evidence": {
		"project": ProjectSettings.globalize_path("res://"), "user_dir": OS.get_user_data_dir(),
		"engine": Engine.get_version_info().string,
		"driver": "Frozen real battle actors; direct AI decisions, real factory production callback and movement orders",
		"modes": ["ra2", "iron_tide"], "services": "none", "database": "none"
	}}, "  "))
	file.close()
	print("AI TACTICS checks=", checks.size(), " failed=", failed)
	get_tree().quit(0 if failed == 0 else 1)

func building(id: String, point: Vector2, owner := "enemy"):
	var b = battle._place_building(id, owner, point, true)
	b._buildup_play = -1.0; b.process_mode = Node.PROCESS_MODE_DISABLED
	return b

func unit(id: String, point: Vector2, owner := "enemy"):
	var u = battle.spawn_unit(id, "ally", point)
	if owner != "ally": AlliedAbilities.change_side(u, owner)
	u.order_stop(); u.process_mode = Node.PROCESS_MODE_DISABLED
	return u

func exercise_mode(mode: String) -> void:
	BattleRequest.configure_skirmish(mode, {"map_size": 4000, "starting_funds": 10000, "fog_of_war": false})
	screen = load("res://scenes/battle.tscn").instantiate()
	stage.add_child(screen); battle = screen.battle
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	for a in battle.units + battle.buildings: a.free()
	battle.units.clear(); battle.buildings.clear()
	for group in ["obstacles", "resource_nodes"]:
		for a in get_tree().get_nodes_in_group(group): a.free()
	battle.water_rects.clear(); battle.path_service.set_water([]); battle._refresh_pathing()
	GM.infinite_funds = false; GM.no_build_time = false
	var ai = battle.skirmish_ai
	ai._army.clear(); ai.difficulty = 1; ai.base_center = Vector2(1000, 1000); ai.rally = Vector2(1500, 1500)
	ai.tuning = GameData.skirmish_ai_tuning(1)
	var prefix := mode + ": "
	building("GACNST", Vector2(900, 900)); building("GAPOWR", Vector2(600, 900))
	building("GAREFN", Vector2(600, 1300)); var barracks = building("GAPILE", Vector2(1000, 1300))
	var factory = building("GAWEAP", Vector2(1300, 900))
	# Combat composition runs after the two-miner economic floor is supplied.
	unit("CMIN", Vector2(600, 1600)); unit("CMIN", Vector2(700, 1600))
	battle._refresh_pathing(); battle.enemy_funds = 10000; battle.enemy_struct_queue.clear()
	ai._build_unit_pool()
	for i in 4: unit("E1",Vector2(1300+i*30,1500))
	battle.enemy_funds = 350
	ai._try_train()
	check(barracks.production.is_empty() and factory.production.is_empty(),prefix+" infantry-heavy force saves limited funds for armour")
	var airfield = building("GAAIRC", Vector2(1500,1900))
	var lab = building("GATECH", Vector2(1800,1900))
	battle.enemy_funds = 12000
	var bomber = unit("ZEP",Vector2(1460,1100),"ally")
	bomber.logistics.air_lift=1.0
	ai._try_train()
	check(factory.production==["FV"] and barracks.production==["JUMPJET"],prefix+" visible Kirov takes both land orders ahead of first prism tank")
	for producer in [factory,barracks,airfield]:
		while not producer.production.is_empty():producer.cancel_at(0)
	battle.units.erase(bomber)
	bomber.free()
	var specialties := []
	for cycle in 5:
		ai._try_train()
		if cycle == 0: check(not factory.production.is_empty() and not barracks.production.is_empty(),prefix+" independent factory and barracks take paid orders in the same decision")
		for producer in [barracks,factory]:
			if not producer.production.is_empty():
				var ordered: String = producer.production[0]
				producer._process(180)
				if ordered in ["GHOST","JUMPJET","GGI","SNIPE"] and battle.units.any(func(u): return u.side=="enemy" and u.unit_id==ordered):
					specialties.append(ordered)
	check(specialties.has("JUMPJET") and specialties.count("JUMPJET") > specialties.count("GHOST") and battle.enemy_funds<12000,prefix+" barracks fields more rocketeers than SEALs alongside vehicle production",specialties)
	for b in [airfield,lab]:
		battle.buildings.erase(b)
		b.free()
	for b in [barracks,factory]:
		while not b.production.is_empty(): b.cancel_at(0)
	for u in battle.units.duplicate():
		if not u.is_harvester:
			battle.units.erase(u)
			u.free()
	ai._army.clear()
	battle.enemy_funds = 10000
	ai._unit_pool.assign(["MGTK", "MTNK"])
	var funds: float = battle.enemy_funds
	ai._try_train()
	check(factory.production == ["MTNK"] and battle.enemy_funds == funds, prefix + "locked random candidate cannot waste a production decision or duplicate charge")
	factory.cancel_at(0)
	ai._unit_pool.assign(["MTNK", "FV"])
	var baseline := Tactics.production(ai)
	check(baseline.get("uid") == "MTNK", prefix + "balanced no-contact composition starts with tank")
	ai.ai_state.preferred_recruit = "FV"
	ai._try_train()
	check(factory.production == ["FV"], prefix + "white egret commander's preference reaches the real factory queue")
	if not factory.production.is_empty():factory.cancel_at(0)
	ai.ai_state.erase("preferred_recruit")
	var flyer = unit("JUMPJET", Vector2(1700, 1500), "ally")
	check(Tactics.production(ai).get("uid") == "FV", prefix + "visible aircraft trigger legal anti-air production")
	ai._try_train()
	check(factory.production == ["FV"], prefix + "counter decision reaches actual factory queue")
	factory.cancel_at(0)
	flyer.hp = 0
	var infantry = unit("E1", Vector2(1700, 1500), "ally")
	ai._unit_pool.assign(["MTNK", "E1"])
	check(Tactics.production(ai).get("uid") == "E1", prefix + "visible infantry trigger efficient anti-infantry composition")
	infantry.hp = 0
	ai._unit_pool.assign(["MTNK", "FV"])
	for i in 5: unit("MTNK", Vector2(1800 + i * 60, 1000))
	check(Tactics.production(ai).get("uid") == "FV", prefix + "existing army prevents single-type spam")
	battle.enemy_funds = 1400
	factory.enqueue("CMIN")
	check(Tactics.production(ai).is_empty(), prefix + "miner commitment reserves treasury before new combat orders")
	factory.cancel_at(0)
	battle.enemy_funds = 0
	check(Tactics.production(ai).is_empty(), prefix + "no money creates no combat order")
	battle.enemy_funds = 10000
	ai._unit_pool.assign(["FV"])
	ai._try_train()
	var produced_before: int = ai.a_spawned
	var seconds := GameData.ra2_build_time(GameData.get_unit("FV"))
	for tick in 4: factory._process(seconds)
	var built: Array = battle.units.filter(func(u): return u.side == "enemy" and u.unit_id == "FV")
	check(built.size() == 1 and factory.production.is_empty() and ai.a_spawned == produced_before + 1,
		prefix + "counter production pays and creates exactly one real reinforcement")
	check(built.size() == 1 and ai._army.has(built[0]) and built[0].has_move_order and built[0].move_target == built[0].special.get("ai_assembly_point") and built[0].move_target.distance_to(ai.rally) <= 300.0,
		prefix + "produced counter joins assembly through real factory callback")
	# Only assembled combat troops can depart; leave a persistent home guard.
	for u in battle.units: u.free()
	battle.units.clear(); ai._army.clear()
	for i in 31:
		unit("MTNK", ai.rally + Vector2((i%8) * 35, (i/8)*35))
	var late = unit("MTNK", Vector2(2200, 1200))
	var enemy_ref = building("GAREFN", Vector2(3000, 3000), "ally")
	var enemy_hq = building("GACNST", Vector2(3400, 3000), "ally")
	check(Tactics.attack_position(ai, ai._army) == enemy_ref.position, prefix + "visible economy target outranks generic HQ march")
	var attacks: int = ai.a_attacks
	ai._launch_attack()
	check(ai.a_attacks == attacks + 1 and ai._army.size() == 10, prefix + "32 living deploy a wave leaving ten home guards")
	check(ai._army.all(func(u):return not u.attack_move and u.special.get(ai.Campaign.ROLE)=="guard"), prefix + "ten guards stay in their home role")
	var offensive: Array = battle.units.filter(func(u): return u.attack_move)
	var attack_goals := offensive.map(func(u): return u.move_target)
	check(offensive.size() == 22 and offensive.all(func(u): return u.move_target.distance_to(enemy_ref.position) < 600.0 and attack_slot_clear(u,u.move_target) and attack_goals.count(u.move_target)==1 and not u.hold_position), prefix + "attackers receive real attack-move toward chosen target", offensive.map(func(u): return {"goal":str(u.move_target),"blocked":battle.path_service.is_blocked(u.move_target),"hold":u.hold_position,"duplicate":attack_goals.count(u.move_target),"distance":u.move_target.distance_to(enemy_ref.position)}))
	check(not attack_slot_clear(offensive[0],enemy_ref.position),prefix + "building interior remains an invalid attack slot")
	var raider = unit("MTNK", Vector2(1050, 1100), "ally")
	attacks = ai.a_attacks
	ai._defend_base()
	ai._launch_attack()
	check(ai.a_attacks == attacks and ai._army[0].attack_move and not ai._army[0].hold_position and ai._army[0].move_target.distance_to(raider.position) < 160 and ai._army[0].move_target != ai._army[1].move_target, prefix + "base raid recalls reserve and suppresses new attack wave")
	check(offensive[0].move_target == attack_goals[0], prefix + "defense does not overwrite committed assault orders")
	raider.hp = 0
	late.order_stop(); ai._army.erase(late)
	ai._recruit_idle()
	check(ai._army.has(late) and ai.ai_state.get("campaign_due",false) and not late.has_move_order, prefix + "idle attacker rejoins offensive without retreating to rally")
	var miner = unit("CMIN", Vector2(1500, 1700)); var mcv = unit("AMCV", Vector2(1700, 1800))
	ai._recruit_idle()
	check(not ai._army.has(miner) and not ai._army.has(mcv), prefix + "economy and reconstruction assets never join attack teams")
	var converted = ai._army[0]
	AlliedAbilities.change_side(converted, "ally")
	ai._train_t = 1000; ai._attack_t = 1000
	ai._process(0.1)
	check(not ai._army.has(converted), prefix + "mind-controlled soldier removed from enemy army")
	var old_timer: float = ai._train_t
	battle.paused = true; ai._process(20.0)
	check(ai._train_t == old_timer, prefix + "pause prevents AI decisions and timer advance")
	battle.paused = false
	# Fog is genuine per-side knowledge; hidden army changes cannot guide production.
	if battle.fog == null:
		battle.fog = load("res://scripts/world/fog_of_war.gd").new()
		battle.add_child(battle.fog); battle.fog.setup(battle)
	battle.fog.rebuild()
	var hidden = unit("JUMPJET", Vector2(50, 3900), "ally")
	battle.fog.rebuild(); hidden.hp = 0
	var no_hidden := Tactics.production(ai)
	hidden.hp = hidden.max_hp
	check(not battle.actor_visible_to("enemy", hidden) and Tactics.production(ai).get("uid") == no_hidden.get("uid"), prefix + "unseen aircraft cannot influence production")
	check(Tactics.attack_position(ai, ai._army) != enemy_ref.position, prefix + "hidden refinery position cannot become attack objective")
	# Verify all difficulties retain an anti-air option and legal fallback roster.
	for diff in 3:
		ai.difficulty = diff; ai._build_unit_pool()
		check(ai._unit_pool.has("FV") and ai._unit_pool.has("GGI"), prefix + "difficulty keeps mixed ground and anti-air roles " + str(diff))
	screen.free(); Ra2Sfx.stop_all(); Music.stop(); Music.player.stream = null
	await get_tree().process_frame
	OS.delay_msec(150)

func attack_slot_clear(actor, goal: Vector2) -> bool:
	var nav = battle.path_service
	if not nav.is_blocked(goal): return true
	# Coarse blocked cells can contain the precise passages used by real movement.
	var route: PackedVector2Array = battle.path_for_unit(actor,goal)
	if route.size()<2 or route[-1].distance_to(goal)>Unit.ARRIVE_EPS: return false
	for i in range(1,route.size()):
		if not nav.passages.clear(nav,route[i-1],route[i],actor.radius+1.0,[]): return false
	return true
