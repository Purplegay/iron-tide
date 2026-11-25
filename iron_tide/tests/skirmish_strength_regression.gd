extends "res://tests/special_mechanics_regression.gd"
const Micro = preload("res://scripts/world/skirmish_micro.gd")
const Economy = preload("res://scripts/world/skirmish_economy.gd")

func _ready() -> void:
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not ProjectSettings.get_setting("application/config/use_custom_user_dir", false): get_tree().quit(2); return
	await get_tree().process_frame
	for mode in [MatchRules.RA2, MatchRules.EXTENDED]:
		arena(mode); micro(); await finish()
		arena(mode); await soviet_micro(); await finish()
		arena(mode); economy(); await finish()
		arena(mode); remote_expansion(); await finish()
		arena(mode); await rescue(); await finish()
	var f := FileAccess.open(output_dir.path_join("result.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks": checks, "failed": failed, "services": "none", "database": "none", "user_dir": OS.get_user_data_dir()}, "  ")); f.close()
	Ra2Sfx.stop_all(); Music.stop(); Music.player.stream = null
	await get_tree().process_frame
	print("SKIRMISH_STRENGTH checks=", checks.size(), " failed=", failed)
	get_tree().quit(0 if failed == 0 else 1)

func micro() -> void:
	var structure = battle._place_building("GAPOWR", "ally", Vector2(1550, 1050), true)
	var gunner = spawn("GGI", "enemy", structure.position + Vector2(105, 0))
	check(Micro.value(gunner, structure, gunner.weapon) > 0.0, prefix + "deployment scores a visible structure as a ground target")
	battle.units.erase(gunner); gunner.free()
	battle.buildings.erase(structure); structure.free()
	battle._refresh_pathing()
	var ai = battle.skirmish_ai
	ai.difficulty = 2
	var gi = spawn("E1", "enemy", Vector2(1100, 1000))
	var victim = spawn("E1", "ally", Vector2(1300, 1000))
	var player = spawn("E1", "ally", Vector2(1100, 1050))
	var destination := Vector2(1900, 1000)
	gi.order_move(destination, true)
	var messages: Array = []
	var listener := func(text: String, _color: Color): messages.append(text)
	Events.battle_message.connect(listener)
	Micro.tick(ai, 0.5)
	check(gi.is_deployed() and gi.move_speed == 0 and gi.attack_target == victim, prefix + "GI deploys via real weapon and stance")
	Events.battle_message.disconnect(listener)
	check(messages.is_empty(), prefix + "AI deployment does not spam player order messages")
	check(not player.is_deployed(), prefix + "player units untouched")
	var hp: float = victim.hp
	gi.aim_dir = gi.position.direction_to(victim.position); gi._cd_timer = 0.0
	check(gi._try_fire_ready() and victim.hp < hp, prefix + "deployed AI fires actual damaging weapon")
	var mission: Dictionary = gi.special.ai_deploy_mission.duplicate(true)
	Micro.tick(ai, 0.5)
	check(gi.special.ai_deploy_mission == mission, prefix + "repeated contact preserves interrupted mission")
	for u in [victim, player]: u.hp = 0
	Micro.tick(ai, 0.5)
	check(gi.is_deployed(), prefix + "short contact loss does not oscillate stance")
	Micro.tick(ai, 1.5)
	check(not gi.is_deployed() and gi.has_move_order and gi.move_target == destination and gi.attack_move, prefix + "no contact stands and resumes original attack march")
	var ggi = spawn("GGI", "enemy", Vector2(1100, 1300))
	var tank = spawn("MTNK", "ally", Vector2(1350, 1300))
	ggi.order_move(destination, true)
	Micro.tick(ai, 0.5)
	check(ggi.is_deployed() and ggi.attack_target == tank and ggi.attack_range > 300, prefix + "GGI deploys anti-armor missile")
	tank.position = ggi.position + Vector2(10, 0)
	Micro.tick(ai, 0.5)
	check(not ggi.is_deployed(), prefix + "GGI switches back inside missile dead zone")
	tank.hp = 0
	var infantry = spawn("E1", "ally", ggi.position + Vector2(180, 0))
	Micro.tick(ai, 0.5)
	check(not ggi.is_deployed(), prefix + "GGI keeps effective rifle against infantry")
	infantry.hp = 0
	var flyer = spawn("JUMPJET", "ally", ggi.position + Vector2(240, 0))
	Micro.tick(ai, 0.5)
	check(ggi.is_deployed() and ggi.can_hit_air and ggi.attack_target == flyer, prefix + "GGI deploys against aircraft despite rifle being ground-only")
	var snap := Snapshot.new().capture(battle)
	check(BattleSaves.validate(snap).is_empty(), prefix + "deployment mission and micro timer are valid save data", BattleSaves.validate(snap))
	Micro.release(ggi)
	check(not ggi.is_deployed() and not ggi.special.has("ai_deploy_mission"), prefix + "new strategic mission releases deployed stance")
	ggi.fire_stance = "none"; Micro.tick(ai, 0.5)
	check(not ggi.is_deployed(), prefix + "cease fire not overridden")
	ggi.fire_stance = "free"; battle.paused = true
	var state: Dictionary = battle.allied_state.duplicate(true)
	Micro.tick(ai, 10)
	check(not ggi.is_deployed() and battle.allied_state == state, prefix + "paused micro does nothing")
	battle.paused = false
	if battle.fog == null:
		battle.fog = load("res://scripts/world/fog_of_war.gd").new(); battle.add_child(battle.fog); battle.fog.setup(battle)
	battle.fog.visible_cells.enemy.fill(0)
	Micro.tick(ai, 0.5)
	check(not ggi.is_deployed(), prefix + "hidden enemy does not trigger deployment")
	battle.fog.free(); battle.fog = null
	add("GAPOWR", "enemy", Vector2(300, 300))
	ai._train_t = 1000; ai._attack_t = 1000
	ai._process(0.5)
	check(ggi.is_deployed(), prefix + "actual AI process invokes deployment decision")
	Snapshot.new().restore(battle, snap)
	get_tree().paused = false; battle.paused = false; battle.ended = false
	var restored = battle.units.filter(func(u): return u.unit_id == "GGI" and u.side == "enemy")[0]
	check(restored.is_deployed() and restored.special.has("ai_deploy_mission"), prefix + "load preserves deployed mission")
	for u in battle.units:
		if u.side == "ally": u.hp = 0
	Micro.tick(ai, 2.1)
	check(not restored.is_deployed() and restored.has_move_order and restored.move_target == destination,
		prefix + "loaded deployed infantry resumes mission after contact ends")

func soviet_micro() -> void:
	var ai = battle.skirmish_ai
	ai.enemy_base = "soviet"
	var deso = spawn("DESO","enemy",Vector2(1200,1100))
	var destination := Vector2(1540,1420)
	deso.order_move(destination)
	var first = spawn("E1","ally",deso.position+Vector2(250,0))
	var second = spawn("E1","ally",first.position+Vector2(0,18))
	var friend = spawn("E2","enemy",first.position)
	Micro.tick(ai,0.5)
	check(not deso.is_deployed() and deso.move_target==destination,prefix+"Desolator avoids irradiating friendly infantry")
	friend.hp = 0
	Micro.tick(ai,0.5)
	check(not deso.is_deployed() and deso.special.has("ai_rad_approach") and deso.move_target!=destination,prefix+"approaches reachable irradiation site")
	deso.position = deso.move_target
	Micro.tick(ai,0.5)
	deso._physics_process(0.1)
	check(deso.is_deployed() and not battle.allied_state.get("rad_sites",[]).is_empty(),prefix+"deploy order creates real radiation")
	var initial: float = first.hp
	deso.SovietSpecials.tick_world(battle,1.1)
	check(first.hp<initial and deso.hp==deso.max_hp,prefix+"field damages enemies and spares immune Desolator")
	first.hp=0
	second.hp=0
	Micro.tick(ai,0.5)
	check(not deso.is_deployed() and deso.move_target==destination,prefix+"Desolator resumes previous march")
	var chopper=spawn("SCHP","enemy",Vector2(800,2000))
	chopper.order_move(destination)
	var building=add("GAPOWR","ally",chopper.position+Vector2(530,0))
	battle.path_service.set_water([Rect2(chopper.position-Vector2(60,60),Vector2(120,120))])
	Micro.tick(ai,0.5)
	check(not chopper.is_deployed() and not chopper.special.has("ai_deploy_mission"),prefix+"siege chopper rejects water without losing its orders")
	battle.path_service.set_water([])
	Micro.tick(ai,0.5)
	check(chopper.is_deployed() and chopper.attack_target==building and not chopper.logistics.can_start_volley(),prefix+"chopper lands to shell a building beyond machine gun range")
	var saved := Snapshot.new().capture(battle)
	check(BattleSaves.validate(saved).is_empty(),prefix+"save accepts chopper during landing")
	Snapshot.new().restore(battle,saved)
	get_tree().paused=false
	battle.paused=false
	battle.ended=false
	ai = battle.skirmish_ai
	chopper = battle.units.filter(func(u):return u.unit_id=="SCHP")[0]
	chopper.disable_mode = CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
	await get_tree().physics_frame
	check(chopper.is_deployed() and chopper.special.has("siege_progress") and chopper.special.ai_deploy_mission.point==destination,prefix+"loaded chopper retains transition and interrupted mission")
	var transition_ticks := ceili((float(chopper.logistics.SiegeChopper.duration()) + float(chopper.flight.height/chopper.flight.climb) + 2.0) * 30.0)
	for i in transition_ticks: chopper._physics_process(1.0/30)
	check(chopper.logistics.can_start_volley() and chopper._active_weapon().name=="160mm" and battle.projectiles_root.get_children().any(func(shot):return shot.shooter()==chopper),prefix+"after landing and unfolding it fires real siege shells")
	var threat=spawn("MTNK","ally",chopper.position+Vector2(110,0))
	Micro.tick(ai,0.5)
	check(not chopper.is_deployed() and chopper.has_move_order and chopper.move_target==destination,prefix+"ground threat causes pack-up and original movement resumes")
	for i in transition_ticks: chopper._physics_process(1.0/30)
	check(chopper.logistics.air_lift>0.95 and chopper._active_weapon().name=="BlackHawkCannon",prefix+"chopper takes off and returns to airborne weapon")
	threat.hp=0

func ore(point: Vector2):
	var node = preload("res://scripts/world/resource_node.gd").new()
	node.position = point; node.amount = 6000; node.max_amount = 6000
	battle.add_child(node)
	return node

func economy() -> void:
	var ai = battle.skirmish_ai
	ai.difficulty = 1; ai.base_center = Vector2(600, 600); ai.rally = Vector2(1000, 900)
	add("GACNST", "enemy", Vector2(600, 600))
	add("GAPOWR", "enemy", Vector2(350, 600))
	var first = add("GAREFN", "enemy", Vector2(600, 950))
	var factory = add("GAWEAP", "enemy", Vector2(950, 600))
	battle._refresh_pathing(); battle.enemy_funds = 10000
	var a = spawn("CMIN", "enemy", Vector2(800, 1200))
	var b = spawn("CMIN", "enemy", Vector2(900, 1200))
	var node = ore(Vector2(1400, 1050))
	check(Economy.desired_miners(ai) == 2, prefix + "single refinery uses two miners")
	var location := Economy.placement(ai)
	check(location != Vector2.INF and battle.build_spot_ok(location, GameData.get_building("GAREFN"), true, "enemy").ok,
		prefix + "expansion chooses real legal ore-side footprint", str(location))
	check(location.distance_to(node.position) < first.position.distance_to(node.position), prefix + "expansion is closer to known ore")
	var danger = spawn("MTNK", "ally", location)
	var safer := Economy.placement(ai)
	check(safer == Vector2.INF or safer.distance_to(danger.position) >= 450, prefix + "visible enemy blocks exposed refinery locations")
	danger.hp = 0
	check(Economy.expand(ai) and battle.enemy_struct_queue[0].id == "GAREFN", prefix + "expansion uses actual paid structure queue")
	var before: float = battle.enemy_funds
	battle._tick_structure_queue(GameData.ra2_build_time(GameData.get_building("GAREFN")) * 4)
	check(battle.enemy_struct_ready.has("GAREFN") and before - battle.enemy_funds == float(GameData.get_building("GAREFN").cost), prefix + "refinery costs real money before placement")
	ai._try_build()
	check(Economy.refineries(ai).size() == 2 and battle.enemy_struct_ready.is_empty(), prefix + "AI places ready expansion")
	check(Economy.desired_miners(ai) == 4 and not Economy.expand(ai), prefix + "normal caps at two refineries and four miners")
	for refinery in Economy.refineries(ai): refinery._buildup_play = -1; refinery.under_construction = false
	var real: int = Economy.miners(ai, false)
	ai._replace_miners()
	check(Economy.miners(ai) == 4, prefix + "all producer queues counted toward four-miner target", {"real": real, "total": Economy.miners(ai)})
	ai._replace_miners()
	check(Economy.miners(ai) == 4, prefix + "replacement does not duplicate outstanding orders")
	var paid := 0
	for producer in battle.buildings: paid += producer.production.count("CMIN")
	check(paid == 1, prefix + "pending refinery gift occupies one miner slot before spawning", paid)
	for producer in Economy.refineries(ai): producer._tick_construction_free_unit(1.0)
	check(Economy.miners(ai) == 4 and Economy.miners(ai, false) == real + 1, prefix + "actual refinery gift replaces pending slot without overshooting")
	real = Economy.miners(ai, false)
	for producer in battle.buildings:
		while not producer.production.is_empty(): producer.cancel_at(0)
	ai.difficulty = 0
	check(Economy.desired_miners(ai) == 2 and not Economy.expand(ai), prefix + "easy keeps modest economy")
	ai.difficulty = 2
	add("GAREFN", "enemy", Vector2(1800, 1800))
	check(Economy.desired_miners(ai) == 6 and not Economy.expand(ai), prefix + "hard caps three ports and six miners")
	battle.enemy_funds = 100
	ai._replace_miners()
	check(Economy.miners(ai) == real, prefix + "insufficient funds creates no speculative miner debt")
	battle.enemy_funds = 1000; ai._unit_pool.assign(["MTNK"])
	ai._try_train()
	check(factory.production.is_empty() and battle.enemy_funds == 1000, prefix + "combat production cannot consume savings for missing miners")
	a.order_stop(); a.auto_harvest_enabled = false
	Economy.manage(ai)
	check(a.auto_harvest_enabled and a.harvest_state == "to_node" and is_instance_valid(a.resource_node), prefix + "idle enemy miner resumes actual reachable collection")
	b.harvest_state = "unloading"; b._unload_timer = 0.4
	Economy.manage(ai)
	check(b.harvest_state == "unloading" and b._unload_timer == 0.4, prefix + "active unloading never restarted")
	var owned = spawn("CMIN", "ally", Vector2(1600, 1800)); owned.order_stop(); owned.auto_harvest_enabled = false
	Economy.manage(ai)
	check(not owned.auto_harvest_enabled, prefix + "player auto-harvest preference preserved")
	if battle.fog == null:
		battle.fog = load("res://scripts/world/fog_of_war.gd").new(); battle.add_child(battle.fog); battle.fog.setup(battle)
	battle.fog.explored_cells.enemy.fill(0)
	check(Economy.known_ore(ai).is_empty() and Economy.placement(ai) == Vector2.INF, prefix + "undiscovered ore cannot guide expansion")

func remote_expansion() -> void:
	var ai = battle.skirmish_ai
	ai.base_center = Vector2(400,400)
	add("GACNST","enemy",ai.base_center)
	add("GAPOWR","enemy",Vector2(150,450))
	var first = add("GAREFN","enemy",Vector2(500,680))
	add("GAWEAP","enemy",Vector2(720,420))
	add("GAPILE","enemy",Vector2(270,720))
	add("GAAIRC","enemy",Vector2(500,180))
	add("GATECH","enemy",Vector2(760,180))
	spawn("CMIN","enemy",Vector2(580,780))
	spawn("CMIN","enemy",Vector2(680,760))
	var field = ore(Vector2(2190,2160))
	battle.enemy_funds=100000
	battle._refresh_pathing()
	check(Economy.placement(ai)==Vector2.INF,prefix+"remote ore starts outside refinery placement reach")
	var extensions:=0
	for decision in 24:
		for b in battle.buildings:
			if battle.actor_alive(b) and b._buildup_play>=0:b._process(10)
		battle._update_power()
		ai._try_build()
		if battle.allied_state.has("ai_ore_outpost"):extensions+=1
		battle._tick_structure_queue(180)
		if Economy.refineries(ai).size()>=2:break
	var ports:=Economy.refineries(ai)
	check(extensions>0 and ports.size()==2 and ports.back().position.distance_to(field.position)<first.position.distance_to(field.position),prefix+"paid power extensions bring second refinery towards remote ore",[extensions,ports.size()])

func rescue() -> void:
	var ai = battle.skirmish_ai
	ai.difficulty = 1
	var refinery = add("GAREFN", "enemy", Vector2(600, 600))
	add("GAWEAP", "enemy", Vector2(900, 600))
	ore(Vector2(1000, 1000))
	battle.enemy_funds = 0
	var ally_money: float = battle.funds
	Economy.relief(ai, 44)
	check(battle.enemy_funds == 0, prefix + "no immediate rescue injection")
	battle.paused = true; Economy.relief(ai, 100)
	check(battle.enemy_funds == 0, prefix + "pause freezes rescue countdown")
	battle.paused = false; Economy.relief(ai, 1)
	var cost: float = GameData.get_unit("CMIN").cost
	check(battle.enemy_funds == cost and battle.funds == ally_money, prefix + "45s grants only one miner shortfall to enemy")
	ai._replace_miners()
	check(Economy.miners(ai) == 1 and battle.enemy_funds == cost, prefix + "grant queues normal replacement without instant spawn")
	var snapshot := Snapshot.new().capture(battle)
	check(BattleSaves.validate(snapshot).is_empty(), prefix + "relief budget validates in save")
	battle.allied_state.ai_relief_total = 0
	Snapshot.new().restore(battle, snapshot)
	check(float(battle.allied_state.ai_relief_total) == cost, prefix + "load preserves consumed rescue cap")
	get_tree().paused = false; battle.paused = false; battle.ended = false
	# Restored actors replace original references; use the real producer.
	for producer in battle.buildings:
		if not producer.production.has("CMIN"): continue
		producer._buildup_play = -1; producer.under_construction = false
		for i in 4: producer._process(GameData.ra2_build_time(GameData.get_unit("CMIN")))
	check(Economy.miners(ai, false) == 1 and is_zero_approx(battle.enemy_funds), prefix + "subsidized miner fully pays and exits actual factory")
	Economy.relief(ai, 100)
	check(battle.enemy_funds == 0, prefix + "working miner receives no ongoing subsidy")
	for unit in battle.units:
		if unit.side == "enemy" and unit.is_harvester: unit.hp = 0
	Economy.relief(ai, 100)
	check(battle.enemy_funds == 0, prefix + "normal rescue cannot refill after cap exhausted")
	ai.difficulty = 2; Economy.relief(ai, 45)
	check(battle.enemy_funds == cost, prefix + "hard allows second and final miner budget")
	battle.enemy_funds = 0; Economy.relief(ai, 100)
	check(battle.enemy_funds == 0, prefix + "hard cap cannot be farmed")
	ai.difficulty = 0; battle.allied_state.ai_relief_total = 0; Economy.relief(ai, 100)
	check(battle.enemy_funds == 0, prefix + "easy never receives relief")
	ai.difficulty = 1; ai.enemy_base = "swarm"; Economy.relief(ai, 100)
	check(battle.enemy_funds == 0, prefix + "swarm keeps separate existing economy")
	ai.enemy_base = "allied"
	var current_ref = Economy.refineries(ai)[0]
	current_ref.special.construction_free_unit = "CMIN"
	Economy.relief(ai, 100)
	check(battle.enemy_funds == 0, prefix + "pending free refinery miner prevents unnecessary subsidy")
	current_ref.special.construction_free_unit = ""
	current_ref.under_construction = true
	Economy.relief(ai, 100)
	check(battle.enemy_funds == 0, prefix + "no operational refinery receives no relief")
	current_ref.under_construction = false
	# Partial replacement already paid must receive only its unpaid shortfall.
	battle.enemy_funds = cost * 0.25
	check(current_ref.enqueue("CMIN"), prefix + "partial funded recovery queues normally")
	current_ref._process(GameData.ra2_build_time(GameData.get_unit("CMIN")))
	Economy.relief(ai, 45)
	check(is_equal_approx(battle.enemy_funds, cost * 0.75), prefix + "queued partly paid miner receives only missing amount")
