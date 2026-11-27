extends RefCounted
## Retail TeamType slice. The house owns one team of each role and its script cursor.
const RULES = preload("res://data/ra2/retail_skirmish.json")
const Planner = preload("res://scripts/world/retail_team_planner.gd")
const MEMBER := "yr_skirmish_team"
const TEAMS := "yr_skirmish_teams"

static func construction(ai,group:String,fallback:String) -> String:
	var mapped:String=ai.battle.roster_id(fallback,ai.house_id)
	var options:Array=RULES.data.production[group]
	if ai.enemy_base=="soviet": mapped={"BuildRadar":"NARADR","BuildTech":"NATECH"}.get(group,mapped)
	if ai.battle._countries.get(ai.house_id)=="Americans" and group=="BuildRadar" and GameData.building_index.has("AMRADR"): mapped="AMRADR"
	if mapped in options and ai.battle.country_block_reason(mapped,ai.house_id).is_empty(): return mapped
	for id:String in options:
		if str(GameData.get_building(id).get("faction",""))==ai.enemy_base and ai.battle.country_block_reason(id,ai.house_id).is_empty(): return id
	return mapped

static func airfield(ai,owned:Array) -> String:
	if ai.enemy_base!="allied" or not owned.has(construction(ai,"BuildTech","GATECH")): return ""
	var id:=construction(ai,"BuildRadar","GAAIRC")
	var n:=owned.count(id)
	if n==0 or n>=quota("airfield",owned.size()): return ""
	var seats:int=ai.battle.aircraft_capacity(ai.house_id)
	return id if seats>0 and ai.battle.aircraft_population(ai.house_id)>=seats else ""

static func ground_defense(ai,owned:Array) -> String:
	var ids:Array=RULES.data.defenses.get(ai.enemy_base,[])
	var total:=0
	for id in ids: total+=owned.count(id)
	if total>=quota("defense",owned.size()): return ""
	var choice:=""
	var least:=2147483647
	for id in ids:
		if id in ["NASAM","NAFLAK","YAGGUN"] or not GameData.ra2_prereq_ok(id,owned,ai.battle.allied_state,ai.house_id): continue
		var n:=owned.count(id)
		if id in ["ATESLA","TESLA","YAPSYT"] and n>=quota("tesla",owned.size()): continue
		if n<least:
			least=n
			choice=id
	return choice

static func quota(role:String,structures:int) -> int:
	var q:Dictionary=RULES.data.quotas[role]
	return clampi(ceili(structures*float(q.ratio)),1,int(q.limit))

static func available(ai, unit, product: String) -> bool:
	return ai.battle.actor_alive(unit) and unit.side == ai.house_id and unit.unit_id == product \
		and unit.embarked_in == null and not unit.repairing and not AlliedAbilities.frozen(unit) \
		and unit.logistics.boarding==null and unit.logistics.passengers.is_empty() \
		and not unit.special.has(MEMBER) and not unit.special.has("expedition_objective") \
		and not unit.special.has("field_convoy") and not unit.special.has("ai_oil_post") \
		and not unit.special.has("action") and not unit.special.has("ai_deploy_mission") \
		and not unit.special.get("ai_transport_reserved",false) and not unit.attack_ordered \
		and not ai.battle.actor_alive(unit.attack_target) and not unit.special.has("ai_air_relief")

static func tick(ai, elapsed: float) -> void:
	if not ai.battle.skirmish or ai.enemy_base not in ["allied","soviet","yuri"]: return
	var state:Dictionary=ai.ai_state.get_or_add(Planner.STATE,{"jobs":{},"weights":{},"serial":0,"left":8.0})
	if ai.enemy_base!="yuri": tick_priority(ai,elapsed,state)
	Planner.tick(ai,elapsed,ai.Retail)

static func tick_priority(ai,elapsed:float,state:Dictionary) -> void:
	var teams: Dictionary = ai.ai_state.get_or_add(TEAMS,{})
	for role in teams.keys():
		var job: Dictionary = teams[role]
		var members: Array = []
		for unit in job.members:
			if not ai.battle.actor_alive(unit): continue
			if unit.side != ai.house_id or unit.special.has("expedition_objective") or unit.special.has("field_convoy"):
				if unit.special.get(MEMBER) == role: release(unit)
				continue
			if unit.special.get(MEMBER) == role: members.append(unit)
		job.members = members
		if members.is_empty() or not advance(ai,role,job,elapsed):
			for unit in members:
				release(unit)
				if job.has("target") and is_same(unit.attack_target,job.target): unit.ai_order("stop")
			if role == "hunter": ai.ai_state.yr_team_check = maxf(24.0,float(ai.ai_state.get("yr_team_check",0.0)))
			teams.erase(role)
	var left := float(ai.ai_state.get("yr_team_check",0.0))-elapsed
	ai.ai_state.yr_team_check = left
	if left > 0.0: return
	# Team planning uses the house clock. No unit independently polls the map.
	ai.ai_state.yr_team_check = 8.0
	var roles: Array = ["hunter"] if ai.enemy_base == "allied" else ["flak","patrol_soviet","patrol_allied"]
	var threats := {}
	if ai.enemy_base == "soviet":
		for enemy in ai.Tactics.visible_opponents(ai.battle,ai.house_id):
			threats[enemy.unit_id] = int(threats.get(enemy.unit_id,0))+1
	for role: String in roles:
		var row: Dictionary = RULES.data.rows[role]
		var slot := "patrol" if role.begins_with("patrol") else role
		if teams.has(slot) or not Planner.room(ai,state,row.team): continue
		if row.has("enemy") and (not row.difficulties[mini(ai.difficulty,2)] or int(threats.get(row.enemy,0)) < int(row.minimum)): continue
		if role == "hunter" and ai.battle.allied_state.get("expedition_task",{}).has("counter_point"): continue
		if role == "flak" and site(ai,"NAFLAK",ai.base_center) == null: continue
		recruit(ai,teams,slot,role,row)

static func release(unit) -> void:
	if unit.special.has("yr_flak_post"):
		unit.special.erase("campaign_area_guard")
		unit.special.erase("yr_flak_post")
	unit.special.erase(MEMBER)

static func recruit(ai,teams: Dictionary,slot: String,role: String,row: Dictionary) -> void:
	var groups := {}
	var size := int(row.count)
	var usable_count := 0
	for unit in ai.battle.units:
		if not ai.battle.actor_alive(unit) or unit.side != ai.house_id or unit.unit_id != row.unit: continue
		if unit.special.has("field_convoy") or unit.special.has("expedition_objective"): continue
		usable_count += 1
		if not available(ai,unit,row.unit): continue
		var zone: int = ai.battle.path_service.zone_at(unit.position)
		if zone <= 0: continue
		var group: Array = groups.get_or_add(zone,[])
		group.append(unit)
		if group.size() != size: continue
		for member in group:
			member.special[MEMBER] = slot
			ai._army.erase(member)
		teams[slot] = {"row":role,"members":group,"step":0,"wait":0.0,"age":0.0}
		advance(ai,slot,teams[slot],0.0)
		return
	# Existing units and committed orders count once across both producers.
	if usable_count >= size or ai.battle.ai_population_full(ai.house_id): return
	for producer in ai.battle.buildings:
		if ai.battle.actor_alive(producer) and producer.side == ai.house_id:
			usable_count += producer.production.count(row.unit)
	if usable_count >= size: return
	buy_member(ai,row.unit)

static func buy_member(ai,id:String) -> bool:
	var world=ai.battle
	var spare:float=ai.funds-ai.Tactics.committed(world,ai.house_id)-maxf(ai.Economy.reserve(ai),ai.Power.reserve(ai))
	var price:float=world.production_price(GameData.get_unit(id),ai.house_id)
	if spare<price: return false
	var spotted:int=ai.Tactics.visible_kirovs(world,ai.house_id)
	if spotted>0:
		var air_site:String=ai.Tactics.air_defense_order(world,ai.house_id,ai.difficulty,world.owned_building_ids(ai.house_id))
		if air_site!="" and spare-price<float(GameData.get_building(air_site).cost): return false
		var counts:={}
		for u in world.units:
			if world.actor_alive(u) and u.side==ai.house_id: counts[u.unit_id]=int(counts.get(u.unit_id,0))+1
		for b in world.buildings:
			if world.actor_alive(b) and b.side==ai.house_id:
				for queued in b.production: counts[queued]=int(counts.get(queued,0))+1
		for line in world.buildings:
			if not world.actor_alive(line) or line.side!=ai.house_id or not line.is_operational() or not line.production.is_empty(): continue
			var emergency:String=ai.Tactics.emergency_aa_product(world,ai.house_id,line,spotted,counts,spare)
			if emergency!="" and emergency!=id: return false
	return ai.Operations.enqueue(ai,id)

static func site(ai, id: String, origin: Vector2):
	var nearest = null
	for building in ai.battle.buildings:
		if not ai.battle.actor_alive(building) or building.side != ai.house_id or building.building_id != id or not building.is_operational(): continue
		if nearest == null or origin.distance_squared_to(building.position)<origin.distance_squared_to(nearest.position): nearest=building
	return nearest

static func advance(ai,slot: String,job: Dictionary,elapsed: float) -> bool:
	if slot == "hunter" and ai.battle.allied_state.get("expedition_task",{}).has("counter_point"): return false
	job.age += elapsed
	if slot == "hunter":
		if job.get("followup",false): return Planner.Orders.advance(ai,slot,job,elapsed,ai.Retail)
		return hunt(ai,job)
	var row: Dictionary = RULES.data.rows[job.row]
	var members: Array = job.members
	if job.wait > 0.0:
		job.wait -= elapsed
		return true
	var building = site(ai,row.sites[int(job.step)],members[0].position)
	if building == null:
		if slot == "flak": return false
		job.step = (int(job.step)+1) % row.sites.size()
		return true
	var arrived := true
	for i in members.size():
		var unit = members[i]
		if slot == "flak" and unit.special.has("yr_flak_post"):
			if unit.special.yr_flak_post == building.position: continue
			unit.special.erase("yr_flak_post")
			unit.special.erase("campaign_area_guard")
		if ai.battle.actor_alive(unit.attack_target):
			arrived=false
			continue
		var offset: Vector2 = Vector2.RIGHT.rotated(TAU*i/members.size())*(building.radius+60.0)
		var point: Vector2 = ai.battle.path_service.nearest_reachable(building.position+offset,unit.position,false,5)
		if not point.is_finite() or point.distance_to(building.position)>building.radius+150.0: return false
		if unit.position.distance_to(point)>55.0:
			arrived=false
			move(ai,unit,slot,point,false)
		elif slot == "flak":
			if not unit.special.has("yr_flak_post"): send(ai,unit,slot,{"kind":"area_guard","site":building.position})
		elif not unit.hold_position:
			send(ai,unit,slot,{"kind":"guard"})
	if arrived and slot == "patrol":
		job.wait = float(row.steps[int(job.step)*2+1][1])
		job.step = (int(job.step)+1) % row.sites.size()
	return true

static func hunt(ai,job: Dictionary) -> bool:
	var lead = job.members[0]
	var target = job.get("target")
	if not ai.battle.actor_alive(target) or BattleRequest.friendly(ai.house_id,target.side) or not ai.battle.actor_visible_to(ai.house_id,target):
		if job.has("target"):
			if ai.battle.actor_alive(target): return false
			job.erase("target")
			job.followup=true
			job.team=RULES.data.rows.hunter.team
			job.step=2 # Mark success, then hunt vehicles and finally any target.
			job.success=false
			return Planner.Orders.advance(ai,"hunter",job,0,ai.Retail)
		if job.age>120: return false
		for contact in ai.Operations.targets(ai):
			if not contact is Unit or not contact.is_harvester or not lead.attack_domain_valid(contact): continue
			var point: Vector2 = ai.battle.path_service.nearest_reachable(contact.position,lead.position,false,4)
			if point.distance_to(contact.position)>lead.attack_range: continue
			if not ai.battle.actor_alive(target) or lead.position.distance_squared_to(contact.position)<lead.position.distance_squared_to(target.position): target=contact
	if ai.battle.actor_alive(target):
		job.target=target
		for unit in job.members:
			if not unit.attack_ordered or unit.attack_target!=target: send(ai,unit,"hunter",{"kind":"attack","target":target})
		return true
	# Use geography and the house's exploration mask until it has a live contact.
	# The waypoints are an Iron Tide adaptation of the retail gathering distance.
	var step := int(job.step)
	var enemy_home: Vector2 = Vector2.ONE*ai.battle.map_size-ai.base_center
	var axis: Vector2 = enemy_home.direction_to(ai.base_center)
	var radius := minf(float(RULES.data.safe_distance)*Ra2Damage.PX_PER_CELL,enemy_home.distance_to(ai.base_center)*0.4)
	var headings := [0.0,-0.65,0.65]
	if step >= headings.size():
		Planner.Orders.explore(ai,"hunter",job,ai.Retail)
		return true
	var goal := enemy_home + axis.rotated(headings[step])*radius
	if ai.battle.position_explored_by(ai.house_id,goal) or lead.position.distance_to(goal)<80.0:
		job.step += 1
		return true
	for unit in job.members:
		var point: Vector2 = ai.battle.path_service.nearest_reachable(goal,unit.position,false,8)
		if not point.is_finite() or point.distance_to(goal)>180.0:
			job.step += 1
			return true
		move(ai,unit,"hunter",point,true)
	return true

static func move(ai,unit,role: String,point: Vector2,attack: bool) -> void:
	if not unit.has_move_order or unit.move_target.distance_to(point)>48.0:
		send(ai,unit,role,{"kind":"move","point":point,"attack":attack})

static func send(ai,unit,role: String,order: Dictionary) -> void:
	order[MEMBER]=role
	ai.battle.ai_dispatch.submit(ai.battle,unit,order)
