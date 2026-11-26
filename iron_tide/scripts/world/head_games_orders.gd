extends RefCounted

const DATA = preload("res://data/head_games_orders.json")
const Garrison = preload("res://scripts/units/civilian_orders.gd")
const CELL := 55.0

static func location(pair:Array) -> Vector2:
	return Vector2(pair[0],pair[1])*CELL

static func nearest(world,id:String,point:Vector2,wing:int=-2):
	var best = null
	var distance := INF
	for b in world.buildings:
		if not world.actor_alive(b) or b.building_id!=id: continue
		if wing!=-2 and (b.side!="enemy" or int(b.special.get("head_games_wing",-1))!=wing): continue
		var d:float=b.position.distance_squared_to(point)
		if d<distance:
			distance=d
			best=b
	return best

static func gate_for(world,plant,street:Vector2) -> Vector2:
	var axis:Vector2=plant.position.direction_to(street)
	var gate:Vector2=plant.position+axis*(plant.footprint_clearance(axis)+28.0)
	return world.path_service.nearest_reachable(gate,street,false,12)

static func prepare(world) -> void:
	var state:Dictionary=world.allied_state
	if state.has("s07_routes"):return
	var routes := []
	for r in DATA.data.routes:
		var source:Array=r.source
		var house=nearest(world,source[0],Vector2(source[1],source[2])*CELL)
		var plants=world.buildings.filter(func(b):return world.actor_alive(b) and b.special.get("head_grinder")==r.area)
		var plant=null if plants.is_empty() else plants[0]
		routes.append({"house":house,"plant":plant,"next":60.0,"resident":null})
	state.s07_routes=routes
	for row in DATA.data.garrison:
		var id:String= {59:"NABNKR",61:"NATBNK",62:"YAPOWR"}[int(row.target)]
		var sites=world.buildings.filter(func(b):return world.actor_alive(b) and b.side=="enemy" and b.building_id==id and b.special.get("head_games_wing",-1)==row.wing)
		if sites.is_empty():continue
		if not row.at.is_empty():
			var origin:=location(row.at)
			sites.sort_custom(func(a,b):return a.position.distance_squared_to(origin)<b.position.distance_squared_to(origin))
		for i in int(row.count):
			var site=sites[i%sites.size()] if row.at.is_empty() else sites[0]
			var point:Vector2=site.position+Vector2.RIGHT.rotated(i*2.4)*(site.radius+70)
			var unit=world.spawn_unit(row.unit,"enemy",point)
			if unit==null:continue
			world.HeadGames.assign_wing(unit,int(row.wing))
			unit.order_guard()
			if i<Garrison.slots(site) or row.at.is_empty(): unit.special.s07_enter=site

static func tick(world,now:float) -> void:
	prepare(world)
	var state:Dictionary=world.allied_state
	for i in state.s07_routes.size():
		var route:Dictionary=state.s07_routes[i]
		var r:Dictionary=DATA.data.routes[i]
		var plant=route.plant
		var u=route.resident
		if not world.actor_alive(plant) or plant.side!="enemy":
			if world.actor_alive(u):u.order_stop();route.resident=null
			continue
		if not world.actor_alive(u):
			if not world.actor_alive(route.house) or now<float(route.next): continue
			if r.area=="sw" and not state.has("head_deployed") or r.area=="ne" and not (state.has("head_seen_ne") or state.has("head_deployed")):continue
			var origin:=location(r.origin)
			var spawn:Vector2=world.path_service.nearest_reachable(origin,plant.position+Vector2(0,160),false,12)
			if not spawn.is_finite():continue
			u=world.spawn_unit(r.unit,"neutral",spawn)
			if u==null:continue
			u.set_fire_stance("none")
			route.resident=u
			route.next=now+60
		if not route.has("gate"):route.gate=gate_for(world,plant,u.position)
		var gate:Vector2=route.gate
		if not gate.is_finite():continue
		if u.position.distance_to(gate)<35:
			plant.play_special()
			world.credit_side("enemy",100)
			AlliedAbilities.consume(u)
			route.resident=null
		elif not u.has_move_order:u.order_move(gate,false,null,world.path_for_unit(u,gate))
	for u in world.units:
		if not world.actor_alive(u) or not u.special.has("s07_enter"):continue
		var site=u.special.s07_enter
		if not world.actor_alive(site) or u.side!=site.side or u.embarked_in!=null or site.special.get("occupants",[]).size()>=Garrison.slots(site):
			u.special.erase("s07_enter")
		elif not u.special.has("action") and Garrison.can_enter(u,site):u.order_interaction("allied_garrison",site,false)
	advance_production(world)
	if now>=float(state.get("s07_ai_due",125)):
		state.s07_ai_due=now+125
		for wing in [-1,0,1]: dispatch(world,wing)
	for b in world.buildings:
		if not world.actor_alive(b) or b.side!="enemy" or not b.special.has("s07_launcher") or not b.sw_ready():continue
		for target in world.buildings+world.units:
			if not world.actor_alive(target) or target.side!="ally" or not world.actor_visible_to("enemy",target):continue
			if b.sw_type()=="GeneticConverter" and not AlliedAbilities.infantry(target):continue
			if b.fire_superweapon(target.position):break

static func dispatch(world,wing:int) -> void:
	var yard=nearest(world,{-1:"YACNST",0:"NACNST",1:"GACNST"}[wing],Vector2.ZERO,wing)
	var jobs:Dictionary=world.allied_state.get_or_add("s07_ai_jobs",{})
	if yard==null or jobs.has(wing):return
	var counts := {}
	for actor in world.units+world.buildings:
		if world.actor_alive(actor) and actor.side=="ally":
			var id:String=actor.unit_id if actor is Unit else actor.building_id
			counts[id]=int(counts.get(id,0))+1
	var difficulty:=int(BattleRequest.skirmish_config.get("difficulty",1))
	var choices := []
	var weights := PackedFloat32Array()
	for rule in DATA.data.rules:
		if rule.wing!=wing or rule.difficulty[difficulty]==0 or rule.team.is_empty():continue
		var value:int=int(world.funds_for("enemy")) if rule.condition==4 else int(counts.get(rule.entity,0))
		var allowed:bool=value<=rule.count if rule.op==1 else value>=rule.count if rule.op==3 else value>rule.count
		if allowed:
			choices.append(rule)
			weights.append(rule.weight)
	if choices.is_empty():return
	var rng:=RandomNumberGenerator.new()
	rng.randomize()
	var index:=rng.rand_weighted(weights)
	var chosen:Dictionary=choices[index]
	var composition:Dictionary=chosen.team.duplicate()
	if composition.has("ADOG"):
		composition["DOG"]=composition.ADOG
		composition.erase("ADOG")
	jobs[wing]={"remaining":composition,"members":[],"guard":chosen.guard}
	world.allied_state["s07_ai_last_%d"%wing]=chosen.id

static func advance_production(world) -> void:
	var jobs:Dictionary=world.allied_state.get("s07_ai_jobs",{})
	for wing in jobs.keys():
		var job:Dictionary=jobs[wing]
		if world.allied_state.has("head_games_freed_%d"%wing) or world.allied_state.has("s07_no_yard_%d"%wing):
			jobs.erase(wing)
			continue
		var pending:=false
		for b in world.buildings:
			if not world.actor_alive(b) or b.side!="enemy" or int(b.special.get("head_games_wing",-1))!=wing:continue
			if b.special.has("s07_building_unit"):
				if b.production.has(b.special.s07_building_unit):pending=true;continue
				b.special.erase("s07_building_unit")
			if not b.production.is_empty():continue
			for id in job.remaining.keys():
				if not b.buildable.has(id) or not b.enqueue(id):continue
				b.special.s07_building_unit=id
				job.remaining[id]-=1
				if job.remaining[id]<=0:job.remaining.erase(id)
				pending=true
				break
		if pending:continue
		# If a factory is lost or a product unavailable, dispatch the surviving partial team.
		for u in job.members:
			if not world.actor_alive(u) or u.side!="enemy":continue
			if job.guard:u.order_guard()
			else:
				var goal:Vector2=world._player_target()
				u.order_move(goal,true,null,world.path_for_unit(u,goal))
		jobs.erase(wing)

static func produced(world,unit,factory) -> void:
	if factory.special.get("s07_building_unit")!=unit.unit_id:return
	factory.special.erase("s07_building_unit")
	var wing:int=factory.special.get("head_games_wing",-1)
	var job:Dictionary=world.allied_state.get("s07_ai_jobs",{}).get(wing,{})
	if not job.is_empty() and unit.side=="enemy":
		job.members.append(unit)
		unit.order_guard()
