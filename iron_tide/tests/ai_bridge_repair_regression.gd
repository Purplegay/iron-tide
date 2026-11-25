extends "res://tests/ground_control_regression.gd"
const Bridges = preload("res://scripts/world/bridge_damage.gd")
const Repair = preload("res://scripts/world/ai_bridge_repair.gd")
const Native = preload("res://scripts/world/native_maps.gd")
const Ops = preload("res://scripts/world/skirmish_operations.gd")

func exercise(mode: String) -> void:
	for layout in ["yr_isleland","river_delta"]:
		for faction in ["allied","soviet"]:
			prefix=mode+"/"+layout+"/"+faction+": "
			BattleRequest.configure_skirmish(mode,{"map_layout":layout,"enemy_base":faction,"fog_of_war":false,"starting_funds":20000})
			screen=load("res://scenes/battle.tscn").instantiate()
			add_child(screen)
			screen.process_mode=Node.PROCESS_MODE_DISABLED
			battle=screen.battle
			for unit in battle.units: unit.free()
			battle.units.clear()
			var ai = battle.skirmish_ai
			var huts: Array = battle.buildings.filter(func(b):return b.building_id=="CABHUT")
			check(not huts.is_empty() and huts.all(func(h):return h.special.has("bridge_span")),prefix+"native/authored huts linked to bridge spans")
			for h in huts: preload("res://scripts/world/civilian_sites.gd").repair(h)
			var hut = null
			for candidate in huts:
				if candidate.special.get("bridge_repaired",false) and Bridges.sections(battle,candidate.special.bridge_span).size()>5: hut=candidate; break
			check(hut!=null,prefix+"intact bridge fixture")
			if hut==null: await finish(); continue
			var span: Rect2=hut.special.bridge_span
			var parts: Array=Bridges.sections(battle,span)
			var middle: Rect2=parts[parts.size()/2]
			Bridges.hit(battle,middle.get_center(),Bridges.strength())
			check(not hut.special.bridge_repaired,prefix+"damage makes linked hut repairable")
			check(not Repair.reachable(battle,middle.get_center(),hut),prefix+"missing bridge cell is not a usable engineer route")
			var near: Vector2=battle.path_service.nearest_reachable(hut.position,hut.position,false,6)
			check(not battle.path_service.is_blocked(near) and Repair.reachable(battle,near,hut),prefix+"engineer bank reachable",near)
			var id := "SENGINEER" if faction=="soviet" else "ENGINEER"
			var engineer=battle.spawn_unit(id,"enemy",near)
			activate(engineer)
			var threat=battle.spawn_unit("MTNK","ally",near+Vector2(100,0))
			activate(threat)
			Repair.tick(ai)
			check(not engineer.special.has("action"),prefix+"visible hostile guards prevent repair suicide")
			battle.units.erase(threat); threat.free()
			battle.paused=true
			Repair.tick(ai)
			check(not engineer.special.has("action"),prefix+"paused AI does not issue repair")
			battle.paused=false
			# Defer through the actual dispatcher, then let oil decisions compete.
			battle.ai_dispatch._begin(battle)
			battle.ai_dispatch.admitted.clear()
			battle.ai_dispatch.limit=battle.ai_dispatch.admitted.size()
			Repair.tick(ai)
			var pending: Dictionary=battle.allied_state.get("ai_dispatch_waiting",{}).get(engineer,{}).get("jobs",{}).get("interaction",{})
			check(pending.get("action")=="allied_bridge",prefix+"repair survives exhausted dispatch budget")
			Ops.claim_oil(ai)
			check(pending.get("action")=="allied_bridge" and not engineer.special.has("action"),prefix+"oil capture does not steal pending repair worker")
			await get_tree().process_frame
			battle.ai_dispatch.frame=-1
			battle.ai_dispatch.pump(battle)
			check(engineer.special.get("action")=="allied_bridge",prefix+"dispatcher delivers normal repair interaction")
			var assigned=engineer.special.get("target")
			var second=battle.spawn_unit(id,"enemy",near+Vector2(0,35))
			activate(second)
			Repair.tick(ai)
			var duplicate=second.special.get("target")
			check(not is_instance_valid(duplicate) or duplicate.special.get("bridge_span")!=span,prefix+"same crossing is not assigned twice through either bank")
			battle.units.erase(second); second.free()
			for step_index in 900:
				if not battle.actor_alive(engineer): break
				engineer._physics_process(1.0/30.0)
				if step_index%30==0: await get_tree().process_frame
			check(not battle.actor_alive(engineer),prefix+"engineer walks into hut and is consumed",[engineer.position if is_instance_valid(engineer) else null,str(assigned.position) if is_instance_valid(assigned) else "none",str(near),engineer.special.get("action") if is_instance_valid(engineer) else null])
			check(Bridges.health(battle,middle)==Bridges.strength() and not battle.path_service.broken_bridge_decks.has(middle),prefix+"repair restores bridge health and navigation")
			check(not battle.ground.broken_bridges.has(middle),prefix+"repair removes drawing gap")
			check(huts.filter(func(h):return h.special.bridge_span==span).all(func(h):return h.special.bridge_repaired),prefix+"both banks become intact together")
			if Native.has(layout):
				preload("res://scripts/world/civilian_sites.gd").break_bridge(hut)
				check(battle.path_service.broken_bridge_decks==[middle],prefix+"linked native hut demolition creates one local gap")
				preload("res://scripts/world/civilian_sites.gd").repair(hut)
			await procurement(ai,hut,middle,id,layout)
			# Older retail snapshots had huts but no bridge association.
			for h in huts: h.special.erase("bridge_span"); h.special.erase("bridge_repaired")
			if Native.has(layout):
				Bridges.restore(battle)
				check(huts.all(func(h):return h.special.has("bridge_span")),prefix+"old save repair huts rebound on restore")
			await finish()

func procurement(ai, hut, middle: Rect2, id: String, layout: String) -> void:
	var bid: String=battle.roster_id("GAPILE","enemy")
	var point: Vector2=hut.position+Vector2(260,-200)
	if Native.has(layout): point=Native.find_base_site(battle,point,bid)
	else:
		point=Vector2.INF
		for ring in range(3,10):
			for index in 16:
				var candidate: Vector2=hut.position+Vector2.RIGHT.rotated(TAU*index/16.0)*ring*90.0
				if battle._skirmish_spot_ok(candidate,150) and Repair.reachable(battle,candidate,hut): point=candidate; break
			if point.is_finite(): break
	check(point.is_finite(),prefix+"reachable bank has barracks site")
	if not point.is_finite(): return
	var producer=Building.new()
	producer.setup(GameData.get_building(bid),"enemy",point,battle,true)
	battle.add_child(producer); battle.buildings.append(producer)
	producer._buildup_play=-1.0
	battle._update_power(); battle._refresh_pathing()
	battle.enemy_funds=20000
	for line in battle.buildings:
		while not line.production.is_empty(): line.cancel_at(0)
	Bridges.hit(battle,middle.get_center(),Bridges.strength())
	var linked: Array=battle.buildings.filter(func(b):return b.special.get("bridge_span")==hut.special.bridge_span)
	for h in linked: h.special.echo_cloaked=true
	Repair.tick(ai)
	check(Ops.count(ai,id)==0,prefix+"hidden bridge does not trigger engineer purchase")
	for h in linked: h.special.erase("echo_cloaked")
	battle.enemy_funds=0
	Repair.tick(ai)
	check(Ops.count(ai,id)==0,prefix+"no free engineer when funds are exhausted")
	battle.enemy_funds=20000
	Repair.tick(ai); Repair.tick(ai)
	check(Ops.count(ai,id)==1,prefix+"two decisions queue exactly one faction engineer",[producer.queue_block_reason(id),str(ProductionExit.origin(producer,GameData.get_unit(id))),battle.path_service.zone_at(ProductionExit.origin(producer,GameData.get_unit(id))),str(hut.position),Repair.reachable(battle,ProductionExit.origin(producer,GameData.get_unit(id)),hut)])
	var lines: Array=battle.buildings.filter(func(b):return b.production.has(id))
	if lines.is_empty(): return
	var wallet: float=battle.enemy_funds
	lines[0]._process(180)
	var workers: Array=battle.units.filter(func(u):return battle.actor_alive(u) and u.side=="enemy" and u.unit_id==id)
	check(workers.size()==1 and battle.enemy_funds<wallet,prefix+"normal barracks production pays and creates engineer")
	if workers.is_empty(): return
	Ops.tick(ai)
	check(workers[0].special.get("action")=="allied_bridge",prefix+"newly produced engineer receives repair mission")
