extends RefCounted

const DATA = preload("res://data/head_games_orders.json")
const DRIVERS = preload("res://data/maps/head_games_drivers.json").data
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
	for trigger in DRIVERS.opening.values():
		for team in trigger.teams:
			if int(team.target)==0:continue
			for entry in team.members:
				place_garrison(world, {"target":team.target,"wing":team.wing,"at":team.at,"count":int(entry[0]),"unit":entry[1]})

static func place_garrison(world,row:Dictionary) -> void:
		var id:String= {59:"NABNKR",61:"NATBNK",62:"YAPOWR"}[int(row.target)]
		var sites=world.buildings.filter(func(b):return world.actor_alive(b) and b.side=="enemy" and b.building_id==id and b.special.get("head_games_wing",-1)==row.wing)
		if sites.is_empty():return
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

# 0AA45A2C / 0AA466CC: retire civilian teams and release surviving residents.
# Keep them non-combatants; the retail destination is a civilian house, not Player.
static func free_grinder_residents(world,area:String) -> void:
	for u in world.units:
		if not world.actor_alive(u) or u.side!="neutral" or u.special.get("s07_resident_area","")!=area:continue
		u.order_stop()
		u.set_fire_stance("none")
		u.special.s07_resident_freed=true
		u.special.s07_native_house="Civilian House" # Original action 36 to house 12; remains neutral in combat.
		if u._seq.has("Cheer"):
			u.special.cheer_elapsed=0.0
		u.queue_redraw()
	for i in world.allied_state.get("s07_routes",[]).size():
		if DATA.data.routes[i].area!=area:continue
		var route:Dictionary=world.allied_state.s07_routes[i]
		route.resident=null

static func tick(world,now:float) -> void:
	prepare(world)
	var state:Dictionary=world.allied_state
	var disabled:Dictionary=state.get_or_add("s07_route_disabled",{})
	for i in state.s07_routes.size():
		if world.actor_alive(state.s07_routes[i].house):continue
		for id in DRIVERS.routes[i].sourceDeath.disable:disabled[id]=true
	for i in state.s07_routes.size():
		var spec:Dictionary=DRIVERS.routes[i]
		var route:Dictionary=state.s07_routes[i]
		var r:Dictionary=DATA.data.routes[i]
		if state.has("head_grinder_lost_"+str(r.area)):continue
		var plant=route.plant
		var u=route.resident
		if not world.actor_alive(plant) or plant.side!="enemy":
			if world.actor_alive(u):u.order_stop();route.resident=null
			continue
		if not world.actor_alive(u):
			if disabled.has(spec.id) or not world.actor_alive(route.house) or now<float(route.next):continue
			var started:bool=state.has("head_deployed") and now>=float(state.head_deployed)+float(DRIVERS.start.delay) and DRIVERS.start.enable.has(spec.id)
			if not started and not (i==5 and state.has("head_seen_ne")):continue
			var origin:=location(r.origin)
			var spawn:Vector2=world.path_service.nearest_reachable(origin,plant.position+Vector2(0,160),false,12)
			if not spawn.is_finite():continue
			u=world.spawn_unit(r.unit,"neutral",spawn)
			if u==null:continue
			u.set_fire_stance("none")
			u.special.s07_resident_area=r.area
			u.special.s07_native_house="German1 House" if r.area=="sw" else "German2 House"
			route.resident=u
			route.next=now+floorf(float(spec.delay)*float(randi_range(50,150))/100.0)
		if not route.has("gate"):route.gate=gate_for(world,plant,u.position)
		var gate:Vector2=route.gate
		if not gate.is_finite():continue
		if u.position.distance_to(gate)<35:
			plant.play_special()
			world.credit_side(world.economy_owner(plant),100)
			AlliedAbilities.consume(u)
			route.resident=null
		elif not u.has_move_order:u.order_move(gate,false,null,world.path_for_unit(u,gate))
	for u in world.units:
		if not world.actor_alive(u) or not u.special.has("s07_enter"):continue
		var site=u.special.s07_enter
		if not world.actor_alive(site) or u.side!=site.side or u.embarked_in!=null or site.special.get("occupants",[]).size()>=Garrison.slots(site):
			u.special.erase("s07_enter")
		elif not u.special.has("action") and Garrison.can_enter(u,site):u.order_interaction("allied_garrison",site,false)
	settle_feedback(world)
	advance_assaults(world,now)
	advance_defense(world,now)
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
	if world.allied_state.has("head_games_freed_%d"%wing) or world.allied_state.has("s07_no_yard_%d"%wing):return
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
		var spec:Dictionary=DRIVERS.production.get(rule.id,{})
		if spec.is_empty() or not spec.enabled or int(spec.wing)!=wing or rule.difficulty[difficulty]==0:continue
		if not production_plan_ready(world,wing,spec):continue
		var allowed:bool=credit_allowed(rule.id,world.funds_for("ally")) if rule.condition==4 else force_allowed(rule.id,counts)
		var weight:float=world.allied_state.get("s07_retail_weights",{}).get(rule.id,rule.weight)
		if allowed and weight>0.0:
			choices.append(rule)
			weights.append(weight)
	if choices.is_empty():return
	var rng:=RandomNumberGenerator.new()
	rng.randomize()
	var index:=rng.rand_weighted(weights)
	var chosen:Dictionary=choices[index]
	var composition:=production_members(DRIVERS.production[chosen.id])
	jobs[wing]={"remaining":composition,"members":[],"guard":chosen.guard,"rule":chosen.id}
	world.allied_state["s07_ai_last_%d"%wing]=chosen.id

static func production_members(spec:Dictionary) -> Dictionary:
	var members:Dictionary={}
	for id in spec.members:
		var unit:String="DOG" if id=="ADOG" else id
		members[unit]=int(members.get(unit,0))+int(spec.members[id])
	return members

static func force_allowed(id:String,counts:Dictionary) -> bool:
	var row:Dictionary=DRIVERS.forceCount.get(id,{})
	return not row.is_empty() and retail_compare(row,float(counts.get(row.entity,0)))

static func credit_allowed(id:String,balance:float) -> bool:
	return retail_compare(DRIVERS.credit.get(id,{}),balance)

static func retail_compare(row:Dictionary,balance:float) -> bool:
	if row.is_empty():return false
	match int(row.op):
		0:return balance<float(row.threshold)
		1:return balance<=float(row.threshold)
		2:return balance==float(row.threshold)
		3:return balance>=float(row.threshold)
		4:return balance>float(row.threshold)
		5:return balance!=float(row.threshold)
	return false

static func production_sites(world,wing:int) -> Array:
	var sites:Array=[]
	for b in world.buildings:
		if world.actor_alive(b) and not b.under_construction and b.side=="enemy" and int(b.special.get("head_games_wing",-1))==wing:sites.append(b.building_id)
	return sites

static func production_budget(world,spec:Dictionary) -> float:
	var total:=0.0
	var members:=production_members(spec)
	for id in members:
		var data:=GameData.get_unit(id)
		if data.is_empty():return INF
		total+=world.production_price(data,"enemy")*float(members[id])
	return total

static func production_plan_ready(world,wing:int,spec:Dictionary) -> bool:
	if spec.is_empty() or not spec.enabled or int(spec.wing)!=wing:return false
	var members:=production_members(spec)
	if members.is_empty() or world.funds_for(world.HeadEconomy.account(wing))<production_budget(world,spec):return false
	return members.keys().all(func(id):return has_factory_for(world,wing,id))

static func has_factory_for(world,wing:int,id:String) -> bool:
	for b in world.buildings:
		if world.actor_alive(b) and b.side=="enemy" and int(b.special.get("head_games_wing",-1))==wing and b.buildable.has(id) and b.is_operational() and b.queue_block_reason(id).is_empty():return true
	return false

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
			if not b.production.is_empty() or not b.is_operational():continue
			for id in job.remaining.keys():
				if not b.buildable.has(id) or not b.enqueue(id):continue
				b.special.s07_building_unit=id
				job.remaining[id]-=1
				if job.remaining[id]<=0:job.remaining.erase(id)
				pending=true
				break
		if pending:continue
		# If a factory is lost or a product unavailable, dispatch the surviving partial team.
		var feedback_id:String=job.get("rule","")
		var ticket:Dictionary={"id":feedback_id,"members":job.members.duplicate(),"success":false}
		if DRIVERS.weightFeedback.rules.has(feedback_id) and not job.members.is_empty():
			world.allied_state.get_or_add("s07_feedback",[]).append(ticket)
		for u in job.members:
			if not world.actor_alive(u) or u.side!="enemy":continue
			if DRIVERS.weightFeedback.rules.has(feedback_id):u.special.s07_feedback_pending=true
			if DRIVERS.ai.has(job.get("rule","")):start_defense(world,u,job.rule)
			elif DRIVERS.assaults.has(job.get("rule","")):start_assault(world,u,job.rule)
			elif job.guard:u.order_guard()
			else:
				var goal:Vector2=world._player_target()
				u.order_move(goal,true,null,world.path_for_unit(u,goal))
		jobs.erase(wing)

static func start_assault(world,u,id:String) -> void:
	u.special.s07_assault={"id":id,"step":0,"origin":u.position}
	advance_assault(world,u,float(world.allied_state.get("head_media_clock",0)))

static func advance_assaults(world,now:float) -> void:
	for u in world.units:
		if not world.actor_alive(u) or not u.special.has("s07_assault"):continue
		if u.side!="enemy":u.special.erase("s07_assault");continue
		advance_assault(world,u,now)

static func advance_assault(world,u,now:float) -> void:
	var state:Dictionary=u.special.s07_assault
	var script:Array=DRIVERS.assaults[state.id]
	if state.has("route_until"):
		if now<float(state.route_until) and u.has_move_order:return
		state.erase("route_until")
		state.step=int(state.step)+1
	if u.attack_ordered and world.actor_alive(u.attack_target) and u.attack_target.side=="ally":return
	for _i in script.size():
		if int(state.step)>=script.size():u.special.erase("s07_assault");return
		var row:Array=script[int(state.step)]
		var op:=int(row[0])
		if op in [0,46]:
			var target=assault_target(world,u,row)
			if target!=null:u.order_target(target,false,false);return
			if world.has_surviving_assets("ally") and op==0 and int(row[1])==1:
				var goal:Vector2=world._player_target()
				if not u.has_move_order and u.position.distance_to(goal)>60.0:u.order_move(goal,true,null,world.path_for_unit(u,goal))
				return
		elif op in [16,53,54]:
			var raw:Vector2=location(row[1]) if op==16 else state.origin
			var goal:Vector2=world.path_service.nearest_reachable(raw,u.position,false,10)
			if goal.is_finite() and u.position.distance_to(goal)>60.0:
				u.order_move(goal,op==16,null,world.path_for_unit(u,goal))
				state.route_until=now+120.0
				return
		elif op==49:
			if u.special.has("s07_feedback_pending"):
				for ticket in world.allied_state.get("s07_feedback",[]):
					if ticket.members.has(u):ticket.success=true;break
		elif op==11:
			u.order_guard()
			u.special.erase("s07_assault")
			return
		state.step=int(state.step)+1

static func adjusted_weight(id:String,current:float,success:bool) -> float:
	var bounds:Array=DRIVERS.weightFeedback.rules[id]
	return clampf(current+float(DRIVERS.weightFeedback.success if success else DRIVERS.weightFeedback.failure),float(bounds[1]),float(bounds[2]))

static func settle_feedback(world) -> void:
	var jobs:Array=world.allied_state.get("s07_feedback",[])
	if jobs.is_empty():return
	var weights:Dictionary=world.allied_state.get_or_add("s07_retail_weights",{})
	for job in jobs.duplicate():
		var active:=false
		for u in job.members:
			if not is_instance_valid(u):continue
			if world.actor_alive(u) and u.side=="enemy" and u.special.has("s07_assault"):active=true
		if active:continue
		var id:String=job.id
		weights[id]=adjusted_weight(id,float(weights.get(id,DRIVERS.weightFeedback.rules[id][0])),bool(job.success))
		for u in job.members:
			if is_instance_valid(u):u.special.erase("s07_feedback_pending")
		jobs.erase(job)

static func assault_target(world,u,row:Array):
	var best=null
	var distance:=INF
	for target in world.units+world.buildings:
		if not world.actor_alive(target) or target.side!="ally" or not u.attack_domain_valid(target):continue
		if target is Unit and target.embarked_in!=null:continue
		if int(row[0])==46:
			if not target is Building or target.building_id!=row[1]:continue
		else:
			match int(row[1]):
				2:if not target is Building:continue
				3:if not target is Unit or not target.is_harvester:continue
				4:if not target is Unit or not AlliedAbilities.infantry(target):continue
				5:if not target is Unit or target.is_air or AlliedAbilities.infantry(target):continue
				6:if not target is Building or target.buildable.is_empty():continue
				7:if not target is Building or (not target.data.get("tags",[]).has("defense") and target.data.get("weapon",{}).is_empty()):continue
				8:if not target is Unit or not (target.attack_ordered or target.attack_move):continue
				9:if not target is Building or target.power<=0:continue
		var d:float=u.position.distance_squared_to(target.position)
		if d<distance:best=target;distance=d
	return best

static func start_defense(world,u,id:String) -> void:
	u.special.s07_defense={"id":id,"step":1}
	advance_defender(world,u,float(world.allied_state.get("head_media_clock",0)))

static func advance_defense(world,now:float) -> void:
	for u in world.units:
		if not world.actor_alive(u) or not u.special.has("s07_defense"):continue
		if u.side!="enemy":u.special.erase("s07_defense");continue
		advance_defender(world,u,now)

static func advance_defender(world,u,now:float) -> void:
	var state:Dictionary=u.special.s07_defense
	var script:Array=DRIVERS.ai[state.id]
	if state.has("goal"):
		var goal:Vector2=state.goal
		if u.has_move_order:return
		if u.position.distance_to(goal)>80.0:
			u.order_move(goal,false,null,world.path_for_unit(u,goal));return
		state.erase("goal")
		state.step=int(state.step)+1
	if state.has("until"):
		if now<float(state.until):return
		state.erase("until")
		state.step=int(state.step)+1
	for _i in script.size():
		if int(state.step)>=script.size():u.special.erase("s07_defense");return
		var row:Array=script[int(state.step)]
		match int(row[0]):
			3:
				var raw:=location(row[1])
				var point:Vector2=world.path_service.nearest_reachable(raw,u.position,false,8)
				if not point.is_finite():return
				state.goal=point
				u.order_move(point,false,null,world.path_for_unit(u,point));return
			5:
				u.order_guard()
				state.until=now+float(row[1]);return
			6:state.step=int(row[1])-1
			_:state.step=int(state.step)+1

static func produced(world,unit,factory) -> void:
	if factory.special.get("s07_building_unit")!=unit.unit_id:return
	factory.special.erase("s07_building_unit")
	var wing:int=factory.special.get("head_games_wing",-1)
	var job:Dictionary=world.allied_state.get("s07_ai_jobs",{}).get(wing,{})
	if not job.is_empty() and unit.side=="enemy":
		job.members.append(unit)
		unit.order_guard()
