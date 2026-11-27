extends RefCounted
const DATA = preload("res://data/maps/time_shift_global_ai.json")

const RetailTeams = preload("res://scripts/world/retail_team_planner.gd")

# Existing phase-four Yuri adapter. Retail SOV01 has no action 74 for the
# Allied/Soviet houses; presence, IQ and a buildable unit cannot start their AI.
const RETURN_ADAPTER_HOUSE := "YuriCountry"

const ACCOUNT_PREFIX := "s01_house/"

static func native_house(actor) -> String:
	if actor.side=="ally":return "Russians"
	if actor.side=="neutral":return "Neutral"
	return str(actor.special.get("time_shift_native_house","YuriCountry" if actor.faction=="yuri" else ""))

static func initialize_accounts(world) -> void:
	var accounts:Dictionary=world.allied_state.get_or_add("s01_ai_accounts",{})
	for house in DATA.data.houses:
		var spec:Dictionary=DATA.data.houses[house]
		if not spec.player and not spec.passive and int(spec.side)>0:accounts.get_or_add(ACCOUNT_PREFIX+house,float(spec.credits))

static func economy_owner(world,actor) -> String:
	if actor.side!="enemy" or int(world.allied_state.get("time_shift",{}).get("phase",-1))!=4:return actor.side
	initialize_accounts(world)
	var key:=ACCOUNT_PREFIX+native_house(actor)
	return key if world.allied_state.s01_ai_accounts.has(key) else actor.side

static func production_sites(world,house:String) -> Array:
	var sites:Array=[]
	for site in world.buildings:
		if world.actor_alive(site) and site.side=="enemy" and not site.under_construction and native_house(site)==house:sites.append(site.building_id)
	return sites

static func factory(world,id:String,house:String="YuriCountry"):
	for b in world.buildings:
		if world.actor_alive(b) and b.side=="enemy" and native_house(b)==house and b.is_operational() and b.buildable.has(id) and b.queue_block_reason(id).is_empty():return b
	return null

static func members_of(force:Dictionary) -> Array:
	var team:Array=[]
	for key in force:
		if not str(key).is_valid_int():continue
		var entry:PackedStringArray=str(force[key]).split(",")
		var product := RetailTeams.product(entry[1])
		for i in int(entry[0]):team.append(product)
	return team

static func recruitable(world,u,id:String,house:String="YuriCountry") -> bool:
	return world.actor_alive(u) and u.side=="enemy" and native_house(u)==house and u.unit_id==id and not u.special.has("s01_flyby") and u.embarked_in==null and not u.has_move_order and not u.attack_ordered and not u.special.has("action") and not u.special.has("shift_global_job") and not u.special.has("shift_island_route") and not u.special.has("shift_reactor_fixer") and not u.special.has("shift_mixed_primary") and not u.special.has("shift_plant")

static func formation_cost(world,jobs:Array,recruit:bool,house:String,available:Array) -> float:
	if jobs.is_empty():return INF
	var bill:=0.0
	for id in jobs:
		var pick:=available.find_custom(func(u):return recruitable(world,u,id,house)) if recruit else -1
		if pick>=0:
			available.remove_at(pick)
			continue
		var maker=factory(world,id,house)
		if maker==null:return INF
		bill+=world.production_price(GameData.get_unit(id),maker.side)
	return bill

static func can_form(world,jobs:Array,recruit:bool,house:String="YuriCountry") -> bool:
	return formation_cost(world,jobs,recruit,house,world.units.duplicate() if recruit else [])<=world.funds_for(ACCOUNT_PREFIX+house)

static func can_form_pair(world,row:Dictionary,house:String) -> bool:
	var available:Array=world.units.duplicate()
	var primary:=formation_cost(world,members_of(row.force),row.team.get("recruiter")=="yes",house,available)
	var secondary:=formation_cost(world,members_of(row.secondary_force),row.secondary.get("recruiter")=="yes",house,available)
	return primary+secondary<=world.funds_for(ACCOUNT_PREFIX+house)

static func start_group(state:Dictionary,force:Dictionary,team:Dictionary,script:Dictionary,house:String="YuriCountry",rule_id:String="") -> void:
	var list:=members_of(force)
	if list.is_empty():return
	state.serial=int(state.get("serial",0))+1
	var commands:Array=[]
	for key in script:
		if str(key).is_valid_int():commands.append(str(script[key]).split(","))
	state.get_or_add("groups",[]).append({"id":state.serial,"house":house,"rule":rule_id,"wanted":list,"recruit":team.get("recruiter")=="yes","units":[],"commands":commands})

static func produced(world,u,producer) -> void:
	var pending:Dictionary=producer.special.get("shift_global_order",{})
	if pending.get("product")!=u.unit_id:return
	producer.special.erase("shift_global_order")
	var ai:Dictionary=world.allied_state.get("time_shift",{}).get("global_ai",{})
	for group in ai.get("groups",[]):
		if group.id!=pending.id or group.get("factory")!=producer:continue
		var house:String=group.get("house","YuriCountry")
		if u.side!="enemy" or producer.side!="enemy" or native_house(producer)!=house or group.wanted.is_empty() or group.wanted[0]!=u.unit_id:return
		u.special.time_shift_native_house=house
		u.order_guard()
		u.special.shift_global_job=group.id
		group.units.append(u)
		group.wanted.pop_front()
		group.erase("factory")
		return

static func advance(world,group:Dictionary) -> bool:
	var house:String=group.get("house","YuriCountry")
	if group.has("factory"):
		var b=group.factory
		if world.actor_alive(b):
			var pending:Dictionary=b.special.get("shift_global_order",{})
			if pending.get("id")==group.id:
				if b.side=="enemy" and native_house(b)==house and not group.wanted.is_empty() and pending.get("product")==group.wanted[0] and b.production.has(group.wanted[0]):return false
				b.special.erase("shift_global_order")
		group.erase("factory")
	if not group.wanted.is_empty():
		var id:String=group.wanted[0]
		if group.recruit:
			for u in world.units:
				if not recruitable(world,u,id,house):continue
				u.special.shift_global_job=group.id
				group.units.append(u)
				group.wanted.pop_front()
				return false
		var maker=factory(world,id,house)
		if maker!=null:
			if maker.production.is_empty() and maker.enqueue(id):
				maker.special.shift_global_order={"id":group.id,"product":id}
				group.factory=maker
			return false
	# If the producer disappears, dispatch the surviving members rather than deadlock.
	var live:Array=group.units.filter(func(u):return world.actor_alive(u) and u.side=="enemy" and native_house(u)==house)
	var anchor:Vector2=live[0].position if not live.is_empty() else Vector2.ZERO
	for u in live:
		u.special.shift_global_house=house
		u.special.shift_global_rally=anchor
		u.special.shift_global_script=group.commands
		u.special.shift_global_step=0
	return true

static func command_tick(world) -> void:
	for u in world.units:
		if not world.actor_alive(u) or not u.special.has("shift_global_script"):continue
		if u.side!="enemy":
			u.special.erase("shift_global_script");u.special.erase("shift_global_job");continue
		if u.embarked_in!=null or u.special.has("action"):continue
		if float(u.special.get("shift_global_guard_until",0.0))>float(world.allied_state.time_shift.elapsed):continue
		if u.attack_ordered and world.actor_alive(u.attack_target) and u.attack_target.side=="ally":continue
		if u.special.has("shift_global_move"):
			var goal:Vector2=u.special.shift_global_move
			var before_deadline:bool=float(world.allied_state.time_shift.elapsed)<float(u.special.shift_global_move_due)
			if u.has_move_order and before_deadline:continue
			if u.position.distance_to(goal)>80.0 and before_deadline:
				u.order_move(goal,false,null,world.path_for_unit(u,goal));continue
			u.special.erase("shift_global_move")
			u.special.erase("shift_global_move_due")
		var script:Array=u.special.shift_global_script
		var step:int=u.special.shift_global_step
		if step>=script.size():
			u.special.erase("shift_global_script");u.special.erase("shift_global_job");continue
		var command:int=int(script[step][0])
		var arg:int=int(script[step][1])
		if command in [0,46]:
			var target=find_target(world,u,command,arg)
			if target!=null:
				if command==46 and u.unit_id in ["ENGINEER","SENGINEER","YENGINEER"]:
					if u.order_interaction("allied_engineer",target,false):continue
				else:u.order_target(target,false,false);continue
		elif command==5:
			u.order_guard()
			u.special.shift_global_guard_until=float(world.allied_state.time_shift.elapsed)+float(arg)
		elif command==58:
			for b in world.buildings:
				if not world.actor_alive(b) or native_house(b)!=native_house(u) or b.building_id!=DATA.data.structureTargets.get(str(arg&65535),""):continue
				var goal:Vector2=world.path_service.nearest_reachable(b.position,u.position,false,10)
				if goal.is_finite():
					u.special.shift_global_move=goal
					u.special.shift_global_move_due=float(world.allied_state.time_shift.elapsed)+45.0
					u.order_move(goal,false,null,world.path_for_unit(u,goal))
				break
		elif command in [53,54]:
			order_rally(world,u,command)
		elif command in [61,62,63]:
			for reactor in world.buildings:
				if world.actor_alive(reactor) and native_house(reactor)==native_house(u) and reactor.building_id=={61:"NATBNK",62:"YAPOWR",63:"NABNKR"}[command] and u.order_interaction("allied_garrison",reactor,false):break
		elif command==9 and not u.deploy_building_id().is_empty():
			if u.deploy():continue
			# A producer exit is not a legal foundation; walk to the nearest legal site.
			var tries:=int(u.special.get("shift_global_deploy_tries",0))
			var goal:=deploy_site(world,u) if tries<2 else Vector2.INF
			if goal.is_finite():
				u.special.shift_global_deploy_tries=tries+1
				u.special.shift_global_move=goal
				u.special.shift_global_move_due=float(world.allied_state.time_shift.elapsed)+45.0
				u.order_move(goal,false,null,world.path_for_unit(u,goal))
				continue
			u.special.erase("shift_global_deploy_tries")
			u.special.erase("shift_global_script")
			u.special.erase("shift_global_job")
			continue
		elif command==11:
			u.order_guard()
		elif command==49:
			u.special.shift_global_success=true # Recorded for diagnostics; no native weight feedback here.
		elif command==6 and arg>0 and arg<=step:
			u.special.shift_global_step=arg-1
			continue
		u.special.shift_global_step=step+1

static func deploy_site(world,u) -> Vector2:
	var center:Vector2=world.snap_build_pos(u.position)
	for radius in range(1,7):
		for y in range(-radius,radius+1):
			for x in range(-radius,radius+1):
				if maxi(absi(x),absi(y))!=radius:continue
				var point:Vector2=center+Vector2(x,y)*55.0
				if world.construction_deploy_check(u,point).ok and world.path_service.same_zone(u.position,point):return point
	return Vector2.INF

static func find_target(world,u,command:int,arg:int):
	var best=null
	var distance:=INF
	var engineer:bool=command==46 and u.unit_id in ["ENGINEER","SENGINEER","YENGINEER"]
	for actor in world.units+world.buildings:
		if not world.actor_alive(actor) or (actor.side!="ally" and not (engineer and actor.side=="neutral")):continue
		if actor is Unit and actor.embarked_in!=null:continue
		if command==46:
			if not actor is Building or actor.building_id!=DATA.data.structureTargets.get(str(arg&65535),""):continue
			if engineer and not AlliedAbilities.can_order(u,actor,"allied_engineer"):continue
		else:
			match arg:
				2:if not actor is Building:continue
				3:if not actor is Unit or not actor.is_harvester:continue
				4:if not actor is Unit or not AlliedAbilities.infantry(actor):continue
				5:if not actor is Unit or actor.is_air or AlliedAbilities.infantry(actor):continue
				6:if not actor is Building or actor.buildable.is_empty():continue
				7:if not actor is Building or actor.data.get("weapon",{}).is_empty():continue
				8:if not actor is Unit or not (actor.attack_ordered or actor.attack_move):continue
				9:if not actor is Building or actor.power<=0.0:continue
		if not engineer and not u.attack_domain_valid(actor):continue
		var d:float=u.position.distance_squared_to(actor.position)
		if d<distance:best=actor;distance=d
	return best

static func order_rally(world,u,command:int) -> void:
	var origin:Vector2=u.special.get("shift_global_rally",u.position)
	var raw:Vector2=origin if command==54 else world._player_target().move_toward(u.position,440.0)
	var goal:Vector2=world.path_service.nearest_reachable(raw,u.position,false,12)
	if goal.is_finite() and u.position.distance_to(goal)>80.0:
		u.special.shift_global_move=goal
		u.special.shift_global_move_due=float(world.allied_state.time_shift.elapsed)+45.0
		u.order_move(goal,false,null,world.path_for_unit(u,goal))

static func uses_rally(row:Dictionary) -> bool:
	var a:PackedStringArray=str(row.raw).split(",")
	if not row.enabled or int(a[12])!=3 or a[2]!="<all>" or int(a[4]) not in [0,1,4]:return false
	return row.script.values().any(func(v):return str(v).begins_with("53,") or str(v).begins_with("54,") or str(v).begins_with("61,"))

static func compares(count:float, encoded:String) -> bool:
	var bytes:=encoded.hex_decode()
	if bytes.size()!=32:return false
	var threshold:=bytes.decode_u32(0)
	match bytes.decode_u32(4):
		0:return count<threshold
		1:return count<=threshold
		2:return count==threshold
		3:return count>=threshold
		4:return count>threshold
		5:return count!=threshold
	return false

static func executable_house(row:Dictionary,house:String,level:int) -> bool:
	var info:Dictionary=DATA.data.houses.get(house,{})
	if info.is_empty() or info.player or info.passive or not row.enabled:return false
	var a:PackedStringArray=str(row.raw).split(",")
	return int(info.techLevel)>=int(a[3]) and int(info.side)==int(a[12]) and (a[2]=="<all>" or a[2]==house or a[2]==info.country) and int(a[15+level])!=0

static func eligible_houses(row:Dictionary,level:int) -> Array:
	return DATA.data.houses.keys().filter(func(h):return executable_house(row,h,level))

static func script_ready(script:Dictionary) -> bool:
	for key in script:
		if not str(key).is_valid_int():continue
		var cmd:=int(str(script[key]).get_slice(",",0))
		if cmd not in [0,5,6,9,11,46,49,53,54,58,61,62,63]:return false
	return true

static func condition_value(world,house:String,kind:int,entity:String) -> float:
	if kind==4:return world.funds_for("ally")
	if kind in [5,6]:
		for b in world.buildings:
			if world.actor_alive(b) and native_house(b)==house and b.is_operational() and b.sw_type()==("IronCurtain" if kind==5 else "ChronoSphere") and b.sw_progress()>=float(DATA.data.minorReady):return 1.0
		return 0.0
	var needed:String={0:"Russians",1:house,7:"Neutral"}.get(kind,"")
	var count:=0.0
	for actor in world.buildings+world.units:
		if not world.actor_alive(actor) or native_house(actor)!=needed:continue
		if kind==7 and (not actor is Building or actor.under_construction):continue
		if (actor.building_id if actor is Building else actor.unit_id)==entity:count+=1.0
	return count

static func condition_met(world,house:String,row:Dictionary) -> bool:
	var a:PackedStringArray=str(row.raw).split(",")
	var kind:=int(a[4])
	if kind not in [0,1,4,5,6,7]:return false
	var value:=condition_value(world,house,kind,RetailTeams.product(a[5]))
	return value>0.0 if kind in [5,6] else compares(value,a[6])

static func eligible_candidate(world,row:Dictionary,house:String,level:int) -> bool:
	if not executable_house(row,house,level) or DATA.data.houses[house].allies.has("Russians"):return false
	return script_ready(row.script) and condition_met(world,house,row) and can_form(world,members_of(row.force),row.team.get("recruiter")=="yes",house)

static func active_houses(world) -> Dictionary:
	var active:Dictionary={}
	for actor in world.buildings+world.units:
		if not world.actor_alive(actor) or actor.side!="enemy":continue
		var house:=native_house(actor)
		var spec:Dictionary=DATA.data.houses.get(house,{})
		if not spec.is_empty() and int(spec.iq)>0 and not spec.player and not spec.passive:active[house]=true
	return active

static func tick(world,s:Dictionary,elapsed:float) -> void:
	initialize_accounts(world)
	var state:Dictionary=s.get_or_add("global_ai",{"left":125.0})
	state.erase("team") # Older snapshots stored only a flat queue, not a formed team.
	command_tick(world)
	var groups:Array=state.get_or_add("groups",[])
	for i in range(groups.size()-1,-1,-1):
		if advance(world,groups[i]):groups.remove_at(i)
	if not groups.is_empty():return
	state.left=float(state.get("left",125.0))-elapsed
	if state.left>0:return
	state.left=125.0
	if not active_houses(world).has(RETURN_ADAPTER_HOUSE):return
	var level:=clampi(int(BattleRequest.skirmish_config.get("difficulty",1)),0,2)
	select_for_house(world,state,RETURN_ADAPTER_HOUSE,level)

static func select_for_house(world,state:Dictionary,house:String,level:int) -> void:
	var candidates:Array=[]
	var weights:=PackedFloat32Array()
	for row in DATA.data.rows:
		var a:PackedStringArray=str(row.raw).split(",")
		if eligible_candidate(world,row,house,level) and float(a[7])>0.0:
			candidates.append(row)
			weights.append(float(a[7]))
	if candidates.is_empty():return
	var rng:=RandomNumberGenerator.new()
	rng.randomize()
	var chosen:Dictionary=candidates[rng.rand_weighted(weights)]
	start_group(state,chosen.force,chosen.team,chosen.script,house,chosen.id)
	if chosen.get("secondary")!=null and script_ready(chosen.secondary_script) and can_form_pair(world,chosen,house):
		start_group(state,chosen.secondary_force,chosen.secondary,chosen.secondary_script,house,chosen.id)
