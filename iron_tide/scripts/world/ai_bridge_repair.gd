extends RefCounted
const Tactics = preload("res://scripts/world/skirmish_tactics.gd")

static func reachable(world, from: Vector2, hut) -> bool:
	var start:Vector2=world.path_service.nearest_reachable(from,from,false,4)
	if not world.path_service.line_walkable(from,start,world.path_service.passages.terrain):return false
	var edges:Array[Vector2]=[]
	# Test the bank around the hut, not its blocked foundation or the far bank.
	for index in 8:
		var direction := Vector2.from_angle(index * TAU / 8.0)
		var edge: Vector2 = hut.position + direction * (hut.footprint_clearance(direction)+22.0)
		edges.append(edge)
		if world.path_service.same_zone(start,edge): return true
	# Infantry can traverse physical gaps which disappear on the foundation grid.
	for edge in edges:
		var route:PackedVector2Array=world.path_service.passages.route(world.path_service,from,edge,8.0,[])
		if route.size()>=2 and route[-1].distance_to(edge)<1.0:return true
	return false

static func tick(ai, damaged_only := false) -> void:
	var world = ai.battle
	if world.paused or world.ended or world.get_tree().paused or ai.enemy_base == "swarm": return
	preload("res://scripts/world/ai_emergency_engineer.gd").clean(world,ai.house_id)
	var waiting: Dictionary = world.allied_state.get("ai_dispatch_waiting",{})
	var assigned := []
	for unit in world.units:
		if not world.actor_alive(unit) or not BattleRequest.friendly(unit.side,ai.house_id): continue
		var job: Dictionary = waiting.get(unit,{}).get("jobs",{}).get("interaction",{})
		var action: String = unit.special.get("action",job.get("action",""))
		var target = unit.special.get("target",job.get("target"))
		if action == "allied_bridge" and world.actor_alive(target): assigned.append(target.special.get("bridge_span"))
	var sites := []
	var threats: Array = load("res://scripts/world/skirmish_operations.gd").targets(ai)
	for hut in world.buildings:
		if not world.actor_alive(hut) or hut.building_id != "CABHUT" or not hut.special.has("bridge_span"): continue
		if hut.special.get("bridge_repaired",false) or assigned.has(hut.special.bridge_span) or not world.actor_visible_to(ai.house_id,hut): continue
		if damaged_only:
			var damage: Dictionary = world.allied_state.get("bridge_section_health",{})
			var collapsed := false
			for section: Rect2 in damage:
				if hut.special.bridge_span.encloses(section) and float(damage[section])<=0.0: collapsed=true; break
			if not collapsed: continue
		var safe := true
		for threat in threats:
			if not threat.weapon.is_empty() and threat.position.distance_to(hut.position) < maxf(330.0,threat.attack_range+110.0): safe=false; break
		if safe: sites.append(hut)
	if sites.is_empty(): return
	var nearest = null
	var worker = null
	var distance := INF
	for unit in world.units:
		if not world.actor_alive(unit) or unit.side != ai.house_id or unit.unit_id not in ["ENGINEER","SENGINEER"] or unit.embarked_in != null: continue
		if unit.special.has("action") or waiting.get(unit,{}).get("jobs",{}).has("interaction"): continue
		for hut in sites:
			var reach: float = unit.position.distance_squared_to(hut.position)
			if reach >= distance or not reachable(world,unit.position,hut) or not AlliedAbilities.can_order(unit,hut,"allied_bridge"): continue
			distance=reach; nearest=hut; worker=unit
	if worker != null:
		worker.special.erase("ai_mid_engineer")
		if world.ai_dispatch.defer_job(world,worker,"interaction",{"action":"allied_bridge","target":nearest}): return
		if AlliedAbilities.use(worker,"allied_bridge",nearest): ai._army.erase(worker)
		return
	# One paid replacement at a time; engineers busy with oil are not stolen.
	if ai.ai_state.has(preload("res://scripts/world/ai_emergency_engineer.gd").KEY): return
	var id := "SENGINEER" if ai.enemy_base == "soviet" else "ENGINEER"
	for line in world.buildings:
		if world.actor_alive(line) and line.side == ai.house_id and line.production.has(id): return
	var reserve: float = preload("res://scripts/world/skirmish_economy.gd").reserve(ai) + float(ai.ai_state.get("reserve",0))
	if ai.funds-Tactics.committed(world,ai.house_id)-reserve < world.production_price(GameData.get_unit(id),ai.house_id): return
	for line in world.buildings:
		if not world.actor_alive(line) or line.side != ai.house_id or not line.is_operational() or line.production_paused() or not line.production.is_empty() or id not in line.buildable: continue
		var exit_point: Vector2 = ProductionExit.origin(line,GameData.get_unit(id))
		for hut in sites:
			if exit_point.is_finite() and reachable(world,exit_point,hut):
				if preload("res://scripts/world/ai_emergency_engineer.gd").enqueue(world,line,id,hut): return
