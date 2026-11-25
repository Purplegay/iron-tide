extends "res://tests/ground_control_regression.gd"

func exercise(mode:String) -> void:
	for difficulty in [3,4]:
		for soviet in [false,true]:
			BattleRequest.configure_skirmish(mode,{"map_size":2400,"difficulty":difficulty,"enemy_country":"苏俄" if soviet else "美国"})
			screen=load("res://scenes/battle.tscn").instantiate()
			add_child(screen)
			screen.process_mode=Node.PROCESS_MODE_DISABLED
			battle=screen.battle
			for actor in battle.units+battle.buildings:actor.free()
			battle.units.clear();battle.buildings.clear()
			for group in ["obstacles","resource_nodes"]:
				for node in get_tree().get_nodes_in_group(group):node.free()
			battle.water_rects.clear();battle.path_service.set_water([])
			var hq=battle._place_building("NACNST" if soviet else "GACNST","enemy",Vector2(700,900),true)
			var power=battle._place_building("NAPOWR" if soviet else "GAPOWR","enemy",Vector2(700,600),true)
			var barracks=battle._place_building("NAHAND" if soviet else "GAPILE","enemy",Vector2(1300,1300),true)
			for building in [hq,power,barracks]:building._buildup_play=-1
			battle._refresh_pathing()
			battle.enemy_funds=100000
			var ai=battle.skirmish_ai
			var uid:String="E2" if soviet else "E1"
			# Isolate procurement throughput from composition, mining and exit traffic.
			ai._unit_pool.assign([uid])
			ai._army.clear()
			ai._rng.seed=77
			GM.no_build_time=false
			var idle:=0.0
			var produced:=0
			var wait:=0.0
			var max_queue:=0
			for frame in 600:
				wait-=0.1
				if wait<=0:
					ai._try_train()
					wait=float(ai.tuning.train_interval)*ai._rng.randf_range(0.75,1.25)
				ai._refill_idle_lines(0.1)
				max_queue=maxi(max_queue,barracks.production.size())
				if barracks.production.is_empty():idle+=0.1
				barracks._process(0.1)
				for unit in battle.units.duplicate():
					if unit.unit_id==uid:produced+=1
					battle.units.erase(unit)
					ai._army.erase(unit)
					unit.free()
				if frame%100==0:await get_tree().process_frame
			var tag:=mode+str(difficulty)+uid
			metrics.append({"scenario":tag,"seconds":60,"produced":produced,"idle_seconds":idle,"max_queue":max_queue,"production_factor":battle.ai_build_factor("enemy")})
			check(produced>0,tag+" real factory produces")
			check(max_queue==2,tag+" funds-backed two-order buffer")
			check(idle<3.0,tag+" no long idle gaps with funded unblocked production",idle)
			# No speculative credit, paused-line restart or queue overflow.
			while not barracks.production.is_empty():barracks.cancel_at(0)
			battle.enemy_funds=float(GameData.get_unit(uid).cost)*1.5
			ai._try_train()
			check(barracks.production.size()==1,tag+" commits only affordable orders")
			while not barracks.production.is_empty():barracks.cancel_at(0)
			battle.enemy_funds=100000
			barracks.exit_blocked=true
			ai._refill_t=0
			ai._refill_idle_lines(0.3)
			check(barracks.production.is_empty(),tag+" blocked exit never accumulates orders")
			barracks.exit_blocked=false
			ai.difficulty=2
			ai._refill_t=0
			ai._refill_idle_lines(0.3)
			check(barracks.production.is_empty(),tag+" lower difficulties keep original cadence")
			if difficulty == 3:
				check_mix(ai, soviet, mode)
				check_barracks_pick(ai, barracks, soviet, mode)
				if not soviet: await check_fortress(ai, barracks, mode)
			await finish()

func check_mix(ai, soviet: bool, mode: String) -> void:
	var ids := ["IVAN","APOC","HTK","TTNK","ZEP","HTNK"] if soviet else ["GHOST","SREF","MGTK","FV","JUMPJET","MTNK"]
	var target = battle.spawn_unit("MTNK","ally",Vector2(1500,1000))
	for uid: String in ids:
		var data := GameData.get_unit(uid)
		var scale := 0.35 if uid in ["GHOST","IVAN"] else (1.0 if uid in ["HTNK","MTNK"] else 1.5)
		for count in [0, 3]:
			var base: float = ai.Tactics.MIX.get(uid,1.0) + 0.5*(ai.Tactics.tech_tier(uid)-1)
			if data.get("role") == "air" and count == 0: base += 2.0
			var before: float = (base + 1.5*ai.Tactics.counter_score(data,[target]))/(1.0+count*0.65)
			check(is_equal_approx(ai.Tactics.production_score(uid,data,[target],count),before*scale),mode+" final procurement weight "+uid+" x"+str(scale)+" count="+str(count))
	battle.units.erase(target)
	target.free()

func check_fortress(ai, barracks, mode: String) -> void:
	const Crew = preload("res://scripts/world/skirmish_fortress_crew.gd")
	ai._build_unit_pool()
	battle.enemy_funds = 100000
	var at := Vector2(1450,1500)
	var fort = battle.spawn_unit("BFRT","enemy",at)
	activate(fort)
	var crew := []
	for i in 4:
		var gi = battle.spawn_unit("E1","enemy",at + Vector2.RIGHT.rotated(i*TAU/5)*30)
		activate(gi)
		crew.append(gi)
	battle.spawn_unit("E1","ally",at)
	check(Crew.needs_riflemen(battle, "enemy"),mode+" allied passenger cannot fill fifth enemy seat")
	ai._try_train()
	check(barracks.production == ["E1"] and not Crew.needs_riflemen(battle,"enemy"),mode+" barracks orders fifth GI and counts the pending order")
	for tick in 300:
		if barracks.production.is_empty(): break
		barracks._process(0.1)
	for u in battle.units:
		if u.side == "enemy" and u.unit_id == "E1" and not crew.has(u):
			activate(u)
			u.position = at + Vector2.LEFT*30
			crew.append(u)
	check(crew.size()==5,mode+" fifth passenger completes normal paid production")
	var extra = battle.spawn_unit("E1","enemy",at+Vector2.RIGHT*85)
	activate(extra)
	crew[0].set_deployed(true,false)
	ai.Operations.tick(ai)
	ai.Operations.tick(ai)
	for u in crew: u.logistics.tick(0.05)
	check(fort.logistics.passengers.size()==5 and crew.all(func(u):return u.embarked_in==fort and not u.special.has("ai_transport_reserved")),mode+" actual fortress boards five GIs including deployed GI")
	check(extra.embarked_in==null and extra.logistics.boarding==null and not extra.special.has("ai_transport_reserved"),mode+" full fortress never claims sixth GI")
	var second = battle.spawn_unit("BFRT","enemy",extra.position+Vector2.DOWN*20)
	var third = battle.spawn_unit("BFRT","enemy",extra.position+Vector2.UP*20)
	activate(second)
	activate(third)
	battle.frame_pacing.tier = 3
	for i in 17: battle.spawn_unit("MTNK","enemy",at+Vector2(i*26,-150)).ai_order("guard")
	# Saturate a fresh real dispatch frame before the two vehicles request the same GI.
	await get_tree().process_frame
	for u in battle.units:
		if u.side == "enemy" and u.unit_id == "MTNK": u.ai_order("guard")
	ai.Operations.unit_decision(ai,second,[])
	ai.Operations.unit_decision(ai,third,[])
	check(extra.special.get("ai_carrier")==second and extra.logistics.boarding==null,mode+" exactly one fortress reserves a GI during dispatch overflow")
	var old_frame := Engine.get_process_frames()
	while old_frame == Engine.get_process_frames(): await get_tree().process_frame
	battle.ai_dispatch.pump(battle)
	extra.logistics.tick(0.05)
	check(extra.embarked_in==second and third.logistics.passengers.is_empty(),mode+" delayed boarding uses real seat after admission")

func check_barracks_pick(ai, barracks, soviet: bool, mode: String) -> void:
	var basic := "E2" if soviet else "E1"
	var specialist := "IVAN" if soviet else "GHOST"
	var radar = battle._place_building("NARADR" if soviet else "GAAIRC","enemy",Vector2(550,1050),true)
	var power = battle._place_building("NAPOWR" if soviet else "GAPOWR","enemy",Vector2(700,1150),true)
	radar._buildup_play = -1
	power._buildup_play = -1
	ai._unit_pool.assign([specialist,basic])
	check(barracks.can_queue(specialist),mode+" specialist available at real barracks "+specialist)
	ai._try_train()
	check(barracks.production == [basic],mode+" first barracks order favors "+basic+" over "+specialist,barracks.production.duplicate())
	while not barracks.production.is_empty(): barracks.cancel_at(0)
	ai._unit_pool.assign([specialist])
	ai._try_train()
	check(barracks.production == [specialist],mode+" specialist remains a legal production order "+specialist)
	while not barracks.production.is_empty(): barracks.cancel_at(0)
