extends "res://tests/special_mechanics_regression.gd"
const Ops = preload("res://scripts/world/skirmish_operations.gd")

func _ready() -> void:
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not ProjectSettings.get_setting("application/config/use_custom_user_dir", false): get_tree().quit(2); return
	await get_tree().process_frame
	for mode in [MatchRules.RA2, MatchRules.EXTENDED]:
		for level in 5:
			BattleRequest.configure_skirmish(mode, {"map_size":2400, "starting_funds":6000, "difficulty":level})
			screen=load("res://scenes/battle.tscn").instantiate()
			add_child(screen)
			battle=screen.battle
			screen.process_mode=Node.PROCESS_MODE_DISABLED
			check(battle.skirmish_ai.difficulty==level and is_equal_approx(battle.enemy_funds,battle.funds*[1,2,3,6,6.6][level]),mode+" real opening funds "+str(level))
			var ai=battle.skirmish_ai
			ai._train_t=1000
			ai._attack_t=1000
			var opening:float=ai.funds
			var subsidy:float=[0,0,750,1000,1000][level]
			ai._process(9.5)
			check(ai.funds==opening,mode+" no early subsidy "+str(level))
			battle.paused=true
			ai._process(20)
			battle.paused=false
			check(ai.funds==opening,mode+" paused subsidy clock "+str(level))
			ai._process(20.75)
			check(ai.funds==opening+3*subsidy,mode+" consecutive ten second payouts "+str(level))
			if level>=3:
				var snapshot=BattleSaves.Snapshot.new().capture(battle)
				BattleSaves.Snapshot.new().restore(battle,snapshot)
				battle.paused=false
				get_tree().paused=false
				battle.skirmish_ai._process(9.75)
				check(battle.enemy_funds==opening+4*subsidy,mode+" save preserves remaining subsidy time")
			await finish()
		arena(mode)
		check_tanya_limit(mode)
		await finish()
		arena(mode)
		await decisions()
		await finish()
		for soviet in [false,true]:
			for difficulty in 5:
				arena(mode)
				check_defense_and_lab(soviet,difficulty)
				await finish()
		arena(mode)
		await interrupted_sortie("ORCA" if mode == MatchRules.RA2 else "BEAG")
		await finish()
		arena(mode)
		await transport_order()
		await finish()
		arena(mode)
		naval_orders()
		await finish()
	var f := FileAccess.open(output_dir.path_join("result.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks": checks, "failed": failed}, "  ")); f.close()
	Ra2Sfx.stop_all(); Music.stop(); Music.player.stream = null
	OS.delay_msec(150)
	await get_tree().process_frame
	print("SKIRMISH_OPERATIONS checks=", checks.size(), " failed=", failed)
	get_tree().quit(0 if failed == 0 else 1)

func check_tanya_limit(mode: String) -> void:
	var first = add("GAPILE","ally", Vector2(800,800))
	var second = add("GAPILE","ally", Vector2(1200,800))
	var computer = add("GAPILE","enemy", Vector2(1700,800))
	add("GATECH","enemy", Vector2(800,1200))
	add("GATECH","ally", Vector2(1700,1200))
	battle.enemy_funds = 20000
	battle.funds = 20000
	var ai = battle.skirmish_ai
	ai._unit_pool.assign(["TANY"])
	ai._try_train()
	check(computer.production.count("TANY")==0 and not computer.can_queue("TANY"),mode+" AI procurement excludes unique heroes")
	for producer in [first,second]:
		while not producer.production.is_empty(): producer.cancel_at(0)
	check(first.enqueue_many("TANY",5)==1, mode+" batch reserves exactly one Tanya")
	check(not second.can_queue("TANY") and not second.enqueue("TANY"), mode+" second player barracks sees first reservation")
	check(not computer.enqueue("TANY"), mode+" direct computer queue also rejects the unique hero")
	while not first.production.is_empty(): first.cancel_at(0)
	while not second.production.is_empty(): second.cancel_at(0)
	check(second.enqueue("TANY"), mode+" cancelled training releases slot")
	second._process(180)
	var heroes = battle.units.filter(func(u): return battle.actor_alive(u) and u.side=="ally" and u.unit_id=="TANY")
	check(heroes.size()==1 and not first.can_queue("TANY"), mode+" deployed player Tanya occupies slot")
	if heroes.size()!=1: return
	first.production.append("TANY") # A queue saved before the limit was enforced.
	var wallet:float=battle.funds
	first._process(180)
	check(first.production.has("TANY") and first.production_paid==0.0 and wallet==battle.funds, mode+" old duplicate order waits without charging")
	heroes[0].receive_hit(100000)
	first._process(180)
	heroes=battle.units.filter(func(u):return battle.actor_alive(u) and u.side=="ally" and u.unit_id=="TANY")
	check(first.production.is_empty() and heroes.size()==1, mode+" loss permits one replacement from saved queue")

func check_defense_and_lab(soviet:bool, difficulty:int) -> void:
	var ai=battle.skirmish_ai
	ai.enemy_base="soviet" if soviet else "allied"
	battle._countries.enemy="Russians" if soviet else "Americans"
	ai.difficulty=difficulty
	ai._build_unit_pool()
	var faction:String=ai.enemy_base
	var aa:="NAFLAK" if soviet else "NASAM"
	var tower:="TESLA" if soviet else "ATESLA"
	var radar:="NARADR" if soviet else "GAAIRC"
	var lab:="NATECH" if soviet else "GATECH"
	var tech:="APOC" if soviet else "SREF"
	var factory
	for row in [["GACNST",Vector2(1200,1200)],["GAPOWR",Vector2(950,1200)],["GAPOWR",Vector2(1100,950)],["GAREFN",Vector2(1450,1200)],["GAPILE",Vector2(1550,1450)],["GAWEAP",Vector2(1200,1500)]]:
		var b=add(battle.roster_id(row[0],"enemy"),"enemy",row[1])
		if row[0]=="GAWEAP": factory=b
	for i in 2: spawn(battle.roster_id("CMIN","enemy"),"enemy",Vector2(1700+i*60,1250))
	var air=spawn("ZEP","ally",Vector2(1200,1020))
	air.logistics.air_lift=1
	battle.enemy_funds=14000
	battle.enemy_power.low=false
	battle.request_structure(radar,"enemy")
	ai._try_build()
	check(battle.enemy_struct_queue.any(func(j):return j.id==radar) and battle.enemy_struct_queue.any(func(j):return j.id==aa), faction+" queues AA while radar is in production",battle.enemy_struct_queue.duplicate(true))
	check(not factory.can_queue(tech),faction+" lab required for T3 vehicle")
	for cycle in 12:
		var assets:Array=battle.owned_building_ids("enemy")
		if assets.count(aa)>=4 and assets.has(tower) and assets.has(lab): break
		battle._tick_structure_queue(180)
		ai._try_build()
	var owned:Array=battle.owned_building_ids("enemy")
	check(owned.count(aa)==4 and owned.has(tower) and owned.has(lab),faction+" pays for and places planned AA guns, advanced defense and lab",owned)
	var guns:Array=battle.buildings.filter(func(b): return b.side=="enemy" and b.building_id==aa)
	if not guns.is_empty():
		var gun=guns[0]
		gun._process(10)
		air.position=gun.position+Vector2(75,0)
		gun._acquire_target()
		check(gun.attack_target==air,faction+" completed AA acquires airborne Kirov",owned)
	air.hp=0 # With the air raid over, procurement returns to its T3 priority.
	for i in (3 if difficulty==0 else 1): spawn("HTNK" if soviet else "MTNK","enemy",Vector2(1720+i*45,1490))
	battle.enemy_funds=9000
	ai._try_train()
	check(factory.production.has(tech),faction+" real war factory orders first unlocked T3 vehicle",factory.production)
	factory._process(180)
	check(battle.units.any(func(u):return u.side=="enemy" and u.unit_id==tech),faction+" T3 vehicle leaves factory")
	var policy = preload("res://scripts/world/skirmish_tactics.gd")
	check(policy.tech_tier("HTNK" if soviet else "MTNK") == 1 and policy.tech_tier("V3" if soviet else "ORCA") == 2 and policy.tech_tier(tech) == 3, faction+" T1 T2 T3 follow runtime prerequisites")
	check(ai._unit_pool.has("SENGINEER" if soviet else "ENGINEER") and ai._unit_pool.has("SCHP" if soviet else "ORCA") and not ai._unit_pool.any(func(id):return id.begins_with("R3")),faction+" catalog includes specialists and air; RA3 excluded")
	check(is_equal_approx(battle.ai_build_factor("enemy"),[1.0,1.0,1.25,1.5][mini(difficulty,3)]) and battle.ai_build_factor("ally")==1.0,faction+" production multiplier "+str(difficulty))
	var forbidden := "R3APOC" if soviet else "R3MIRAGE"
	check(not factory.can_queue(forbidden) and factory.queue_block_reason(forbidden).contains("RA3") and not factory.enqueue(forbidden),faction+" real AI order rejects RA3")
	var troop_id := "HTNK" if soviet else "MTNK"
	var unit_rate:float=factory.production_work_rate(troop_id)
	var structure_rate:float=battle.structure_work_rate("enemy",lab)
	ai.difficulty=0
	var factor:float=[1.0,1.0,1.25,1.5][mini(difficulty,3)]
	check(is_equal_approx(unit_rate,factor*factory.production_work_rate(troop_id)) and is_equal_approx(structure_rate,factor*battle.structure_work_rate("enemy",lab)),faction+" difficulty affects both real queue clocks")
	ai.difficulty=difficulty
	var factory_id:String = factory.building_id
	var old_pos:Vector2 = factory.position
	if difficulty in [1,3]:
		battle.enemy_funds=100
		check(policy.additional_factory(battle,"enemy",difficulty,battle.owned_building_ids("enemy")).is_empty(),faction+" cannot buy extra lines with an unfunded army")
		battle.enemy_funds=100000
		var barracks_id:String=battle.roster_id("GAPILE","enemy")
		var cap:=3 if difficulty==3 else 2
		for turn in 20:
			ai._try_build()
			battle._tick_structure_queue(180)
			for line in battle.buildings:
				if battle.actor_alive(line): line._process(GameData.ra2_buildup_seconds()+1.0)
			battle._update_power()
			var current:Array=battle.owned_building_ids("enemy")
			if current.count(factory_id)==cap and current.count(barracks_id)==cap:break
		var current:Array=battle.owned_building_ids("enemy")
		check(current.count(factory_id)==cap and current.count(barracks_id)==cap,faction+" duel pays and places both production lines up to difficulty cap",current)
		ai._try_train()
		for id in [factory_id,barracks_id]:
			var operating:Array=battle.buildings.filter(func(b):return battle.actor_alive(b) and b.side=="enemy" and b.building_id==id and not b.production.is_empty())
			check(operating.size()==cap,faction+" all duel lines accept concurrent orders "+id, [battle.enemy_funds,battle.buildings.filter(func(b):return b.side=="enemy" and b.building_id==id).map(func(b):return [b.production,b.is_operational(),b.exit_blocked,b._buildup_play,b.position])])
	# Test recovery after losing every vehicle line, including any expansion.
	for line in battle.buildings.duplicate():
		if battle.actor_alive(line) and line.side=="enemy" and line.building_id==factory_id:
			line.hp=0
			line._die()
	battle._refresh_pathing()
	battle.enemy_struct_queue.clear()
	battle.enemy_struct_ready.clear()
	battle.enemy_funds=400
	ai._try_build()
	check(battle.enemy_struct_queue.any(func(job):return job.id==factory_id),faction+" lost war factory starts rebuilding on installments")
	battle.enemy_funds=20000
	battle._tick_structure_queue(180.0)
	ai._try_build()
	check(battle.owned_building_ids("enemy").has(factory_id),faction+" replacement war factory placed",old_pos)
	air.hp=0
	var jet_id := "ZEP" if soviet else "ORCA"
	var got_plane := false
	for turn in 12:
		for producer in battle.buildings:
			if battle.actor_alive(producer) and producer.side=="enemy" and producer._buildup_play >= 0.0: producer._process(10)
		ai._try_train()
		for producer in battle.buildings:
			if battle.actor_alive(producer) and producer.side=="enemy" and not producer.production.is_empty():
				producer._process(180.0)
		if battle.units.any(func(u):return battle.actor_alive(u) and u.side=="enemy" and (u.unit_id==jet_id or (soviet and u.unit_id=="SCHP"))):
			got_plane=true
			break
	check(got_plane,faction+" builds and delivers aircraft without a visible enemy")
	add(factory_id,"enemy",Vector2(1900,1700))
	var factories=battle.buildings.filter(func(b):return battle.actor_alive(b) and b.side=="enemy" and b.building_id==factory_id)
	for line in factories:
		while not line.production.is_empty():line.cancel_at(0)
	battle.enemy_funds=20000
	ai._try_train()
	check(factories.size()==2 and factories.all(func(line):return not line.production.is_empty()),faction+" both war factories place independent orders")

func decisions() -> void:
	var ai = battle.skirmish_ai
	ai.difficulty = 2
	var refinery = add("GAREFN", "ally", Vector2(1800, 1400))
	var lab = add("GATECH", "ally", Vector2(2000, 1000))
	var power = add("GAPOWR", "enemy", Vector2(300, 300))
	var airport = add("GAAIRC", "enemy", Vector2(500, 400))
	var depot = add("GADEPT", "enemy", Vector2(600, 700))
	var weather = add("GAWEAT", "enemy", Vector2(800, 300))
	var plane = spawn("ORCA", "enemy", Vector2(500, 400))
	plane.logistics.assign_producer(airport)
	var own_plane = spawn("ORCA", "ally", Vector2(400, 1500))
	own_plane.logistics.air_state = "parked"
	var spy_unit = spawn("SPY", "enemy", Vector2(900, 1000))
	var disguise = spawn("E1", "ally", Vector2(1800, 1000))
	var tank = spawn("MTNK", "enemy", Vector2(900, 700))
	tank.hp = tank.max_hp * 0.2
	battle.power_low = false; battle.enemy_power.low = false
	battle.enemy_funds = 10000
	weather._sw_charge = weather.sw_recharge()
	var money: float = battle.enemy_funds
	Ops.tick(ai)
	check(plane.attack_ordered and plane.attack_target != null and plane.logistics.air_state == "flying", prefix + "AI plane receives a real sortie order")
	check(not own_plane.attack_ordered and own_plane.logistics.air_state == "parked", prefix + "player plane never auto relaunched by enemy AI")
	check(spy_unit.special.get("action") == "allied_infiltrate" and spy_unit.special.get("target") == lab and spy_unit.special.has("disguise"), prefix + "spy disguises and prioritizes un-stolen lab")
	check(tank.repairing and tank.repair_depot == depot, prefix + "wounded vehicle receives normal depot repair order")
	check(weather._sw_charge == 0 and LightningStorm.storms(battle).size() == 1, prefix + "AI launches charged weather at visible valuable target")
	check(battle.enemy_funds == money, prefix + "decision adds no money and bypasses no repair charges")
	var previous = plane.attack_target
	Ops.tick(ai)
	check(plane.attack_target == previous and LightningStorm.storms(battle).size() == 1, prefix + "flying aircraft and launched storm not repeatedly restarted")
	# No real producer means no artificial unit creation, even with enough funds.
	check(not Ops.enqueue(ai, "CARRIER"), prefix + "missing shipyard blocks paid naval production")
	check(not Ops.enqueue(ai, "missing_unit"), prefix + "unknown roster entry never produces")
	check(not Ops.has_build_spot(ai, "GAYARD"), prefix + "no legal shore prevents committing shipyard production")
	var cost: float = GameData.get_unit("ORCA").cost
	battle.enemy_funds = cost - 1
	check(not Ops.enqueue(ai, "ORCA"), prefix + "specialist production honors treasury")
	battle.enemy_funds = 10000
	var before: float = battle.enemy_funds
	check(Ops.enqueue(ai, "ORCA") and airport.production == ["ORCA"], prefix + "specialist uses real airport queue")
	var seconds := GameData.ra2_build_time(GameData.get_unit("ORCA"))
	for i in 4: airport._process(seconds)
	var built: Array = battle.units.filter(func(u): return u.side == "enemy" and u.unit_id == "ORCA" and u != plane)
	check(built.size() == 1 and battle.enemy_funds == before - cost and not ai._army.has(built[0]), prefix + "specialist pays once and avoids ground attack army")
	battle.paused = true
	spy_unit.order_stop()
	Ops.tick(ai)
	check(not spy_unit.special.has("action"), prefix + "pause freezes special decisions")
	battle.paused = false
	# End the previous storm: its impact legally provides sight for a follow-up sortie.
	battle.allied_state.erase("lightning_storms")
	for u in battle.units:
		if u.side == "enemy": u.position = Vector2(100, 100)
	for b in battle.buildings:
		if b.side == "enemy": b.position = Vector2(100, 100)
	battle.fog = preload("res://scripts/world/fog_of_war.gd").new(); battle.add_child(battle.fog); battle.fog.setup(battle)
	plane.order_stop(); plane.logistics.air_state = "parked"; plane.logistics.ammo = plane.logistics.ammo_max
	Ops.tick(ai)
	check(Ops.targets(ai).is_empty(),prefix+"no live contact after storm intelligence expires")
	check(not plane.attack_ordered and not spy_unit.special.has("action"), prefix + "unseen enemy positions never create sortie or spy order")
	battle.fog.free(); battle.fog = null

func interrupted_sortie(id: String) -> void:
	var field = add("GAAIRC", "enemy", Vector2(500, 500))
	var plane = battle.spawn_unit(id, "enemy", field.position, field)
	plane.process_mode = Node.PROCESS_MODE_ALWAYS
	plane.set_physics_process(false)
	var target = add("GAPOWR", "ally", Vector2(1400, 500))
	await get_tree().physics_frame
	Ops.tick(battle.skirmish_ai)
	check(plane.attack_target == target and plane.logistics.air_state == "flying", id + " real AI launches full aircraft")
	plane.set_physics_process(true)
	for tick in 300:
		await get_tree().physics_frame
		if plane.logistics.air_lift>0.95 and plane.position.distance_to(field.position)>80: break
	check(plane.logistics.air_lift > 0.95 and plane.position.distance_to(field.position) > 80 and plane.logistics.ammo == plane.logistics.ammo_max, id + " airborne en route before first shot")
	battle.buildings.erase(target)
	target.free()
	for tick in 2: await get_tree().physics_frame
	check(plane.logistics.air_state == "returning" and plane.logistics.air_lift > 0.95, id + " lost target triggers return even with ammunition")
	for tick in 1600:
		await get_tree().physics_frame
		if plane.logistics.air_state == "parked": break
	check(plane.logistics.air_state == "parked" and plane.position.distance_to(plane.logistics.dock_destination()) < 1 and plane.logistics.air_lift == 0, id + " lands on reserved pad")
	Ops.tick(battle.skirmish_ai)
	check(plane.logistics.air_state == "parked", id + " no target keeps plane on pad")
	target = add("GAPOWR", "ally", Vector2(1400, 500))
	Ops.tick(battle.skirmish_ai)
	check(plane.attack_ordered and plane.attack_target == target and plane.logistics.air_state == "flying", id + " separate decision launches from pad again")

	# Shape produced by old saves: flying state, on the ground, no outstanding order.
	plane.order_stop()
	plane.position = Vector2(800, 740)
	plane.logistics.air_lift = 0
	battle.buildings.erase(field)
	field.free()
	for tick in 300: await get_tree().physics_frame
	check(plane.logistics.air_state == "returning" and plane.logistics.air_lift > 0.95 and not is_instance_valid(plane.logistics.home), id + " stranded aircraft climbs and waits when base lost")
	var replacement = add("GAAIRC", "enemy", Vector2(450, 850))
	for tick in 1600:
		await get_tree().physics_frame
		if plane.logistics.air_state == "parked": break
	check(plane.logistics.air_state == "parked" and plane.logistics.home == replacement and plane.position.distance_to(plane.logistics.dock_destination()) < 1, id + " replacement airport recovers airborne aircraft")

func transport_order() -> void:
	var ai = battle.skirmish_ai
	ai.difficulty = 2
	var target = add("GAWEAP", "ally", Vector2(1800, 1400))
	var carrier = spawn("SHAD", "enemy", Vector2(800, 1000))
	carrier.logistics.air_lift = 0.0
	var a = spawn("GHOST", "enemy", Vector2(810, 1000))
	var b = spawn("GHOST", "enemy", Vector2(790, 1000))
	Ops.transport(ai, carrier, [target])
	check(a.logistics.boarding == carrier and b.logistics.boarding == carrier, prefix + "transport reserves two actual commandos")
	a.logistics.tick(0.1); b.logistics.tick(0.1)
	check(carrier.logistics.passengers.size() == 2, prefix + "real boarding adds both passengers")
	Ops.transport(ai, carrier, [target])
	check(carrier.special.get("ai_transport_phase") == "fly" and carrier.has_move_order, prefix + "loaded helicopter chooses clear assault landing")
	if not carrier.special.has("ai_drop"): return
	check(carrier.logistics.landing_clear(battle, carrier.special.ai_drop, 50), prefix + "drop is outside building and water")
	carrier.position = carrier.special.ai_drop
	Ops.transport(ai, carrier, [target])
	check(carrier.logistics.unloading and carrier.special.ai_transport_phase == "unload", prefix + "arrival requests actual unloading")
	carrier.logistics.air_lift = 0
	carrier.logistics.unload_one(); carrier.logistics.unload_one()
	Ops.transport(ai, carrier, [target])
	check(carrier.logistics.passengers.is_empty() and carrier.special.ai_transport_phase == "return", prefix + "unloaded helicopter returns for next team")
	Ops.tick(ai)
	check(a.attack_ordered and b.attack_ordered and not a.special.has("ai_transport_reserved"), prefix + "released commandos attack visible building for C4")
	var codec := Snapshot.new()
	var saved := codec.capture(battle)
	check(codec.error.is_empty() and BattleSaves.validate(saved).is_empty(), prefix + "transport phase and references persist", BattleSaves.validate(saved))

func naval_orders() -> void:
	battle.water_rects = [Rect2(300, 1500, 1600, 700)]
	battle.path_service.set_water(battle.water_rects); battle._refresh_pathing()
	var ship = spawn("DEST", "enemy", Vector2(600, 1850))
	var threat = spawn("DEST", "ally", Vector2(1000, 1850))
	var inland = add("GAWEAP", "ally", Vector2(1800, 300))
	var ai = battle.skirmish_ai
	check(Ops.preferred(ai, ship, [inland]) == null, prefix + "naval force rejects unreachable inland target")
	check(Ops.preferred(ai, ship, [inland, threat]) == threat, prefix + "naval force chooses reachable visible ship")
	Ops.tick(ai)
	check(ship.attack_target == threat and ship.attack_ordered, prefix + "naval choice becomes actual attack order")
	battle.water_rects.append(Rect2(1600,200,600,400))
	battle.path_service.set_water(battle.water_rects)
	battle._refresh_pathing()
	var lake_ship = spawn("DEST","ally",Vector2(1900,400))
	check(Ops.preferred(ai,ship,[lake_ship]) == null,prefix+"separate inland lake cannot be chased through land")
	var coast = add("GAREFN","ally",Vector2(1700,1330))
	ship.order_stop()
	Ops.naval_orders(ai,ship,[coast])
	var approach: Vector2 = ship.move_target
	check(ship.has_move_order and battle.on_water(approach) and approach.distance_to(coast.position) <= ship.attack_range, prefix+"coastal bombardment approach stays in navigable water")
	ship.position = approach
	Ops.naval_orders(ai,ship,[coast])
	check(ship.attack_ordered and ship.attack_target == coast, prefix+"ship targets coastal structure from firing position")
