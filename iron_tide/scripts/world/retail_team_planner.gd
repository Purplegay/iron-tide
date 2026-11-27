extends RefCounted
## AIMD trigger selection, recruitment and script cursors are private to each House.
const DB = preload("res://data/ra2/retail_skirmish.json")
const Orders = preload("res://scripts/world/retail_team_orders.gd")
const MEMBER = "yr_skirmish_team"
const STATE = "yr_global_ai"

static func product(id: String) -> String:
	return {"ADOG":"DOG","DOG":"SOV_DOG"}.get(id,id)

static func formation_product(id:String) -> String:
	# AIMD Soviet Bombard Hard lists the spawned missile. Only its launcher can accept orders.
	return "V3" if id=="V3ROCKET" else product(id)

static func compare(value: int, expected: int, op: int) -> bool:
	match op:
		0: return value < expected
		1: return value <= expected
		2: return value == expected
		3: return value >= expected
		4: return value > expected
		5: return value != expected
	return false

static func counts(ai) -> Dictionary:
	var facts := {"own":{},"enemy":{},"neutral":{},"ready":{},"credits":0}
	var opponent := ""
	var near := INF
	for owner in ai.battle._countries:
		if BattleRequest.friendly(owner,ai.house_id) or owner==ai.house_id: continue
		if opponent=="": opponent=owner
		for b in ai.battle.buildings:
			if b.side!=owner or not ai.battle.actor_alive(b) or not ai.battle.actor_visible_to(ai.house_id,b): continue
			var d:float=ai.base_center.distance_squared_to(b.position)
			if d<near:
				opponent=owner
				near=d
	if opponent!="": facts.credits=floori(ai.battle.funds_for(opponent))
	for actors in [ai.battle.buildings,ai.battle.units]:
		for actor in actors:
			if not ai.battle.actor_alive(actor): continue
			var own:bool=actor.side==ai.house_id
			if not own and (not ai.battle.actor_visible_to(ai.house_id,actor) or (actor.side!="neutral" and actor.side!=opponent)): continue
			var bucket:Dictionary=facts.own if own else (facts.neutral if actor.side=="neutral" else facts.enemy)
			var id:String=actor.building_id if actor is Building else actor.unit_id
			bucket[id]=1+int(bucket.get(id,0))
			if own and actor is Building and actor.is_operational() and not actor.superweapon.is_empty():
				facts.ready[actor.sw_type()]=maxf(facts.ready.get(actor.sw_type(),0.0),actor.sw_progress())
	return facts

static func eligible(row: Dictionary,side: String,country: String,difficulty: int,tech: int,facts: Dictionary) -> bool:
	if not row.skirmish or row.side not in ["all",side] or not row.difficulty[clampi(difficulty,0,2)] or row.tech>tech: return false
	if row.country!="<all>" and row.country.to_lower()!=country.to_lower(): return false
	var id:=product(row.object)
	match int(row.condition):
		0: return compare(facts.enemy.get(id,0),row.threshold,row.comparison)
		1: return compare(facts.own.get(id,0),row.threshold,row.comparison)
		4: return compare(facts.credits,row.threshold,row.comparison)
		5: return facts.ready.get("IronCurtain",0.0)>=DB.data.near_ready
		6: return facts.ready.get("ChronoSphere",0.0)>=DB.data.near_ready
		7: return compare(facts.neutral.get(id,0),row.threshold,row.comparison)
	return false

static func room(ai,s: Dictionary,id: String) -> bool:
	var count:=0
	var guards:=0
	var legacy:Dictionary=ai.ai_state.get("yr_skirmish_teams",{})
	for j in legacy.values():
		var old:String=DB.data.rows[j.row].team
		if old==id: count+=1
		if DB.data.teams[old].defense: guards+=1
	for j in s.jobs.values():
		if j.team==id: count+=1
		if DB.data.teams[j.team].defense: guards+=1
	var index:=2-clampi(ai.difficulty,0,2)
	var t:Dictionary=DB.data.teams[id]
	return legacy.size()+s.jobs.size()<int(DB.data.team_caps[index]) and count<int(t.max) and (not t.defense or guards<int(DB.data.defense_caps[index]))

static func select(ai,s: Dictionary) -> void:
	var facts:=counts(ai)
	var ids: Array=[]
	var weights: Array=[]
	var total:=0.0
	for id in DB.data.triggers:
		var row:Dictionary=DB.data.triggers[id]
		if not eligible(row,ai.enemy_base,ai.battle._countries.get(ai.house_id,""),ai.difficulty,BattleRequest.skirmish_config.get("tech_level",10),facts): continue
		if not room(ai,s,row.primary): continue
		var w:float=s.weights.get(id,row.weight)
		if w<=0: continue
		total+=w
		weights.append(total)
		ids.append(id)
	if ids.is_empty(): return
	var rng:=RandomNumberGenerator.new()
	if s.has("rng"): rng.state=int(s.rng)
	else: rng.seed=ai._rng.randi()
	var draw:=rng.randf()*total
	s.rng=str(rng.state)
	var index:=mini(weights.bsearch(draw),ids.size()-1)
	activate(ai,s,ids[index])

static func activate(ai,s:Dictionary,trigger:String) -> void:
	var row:Dictionary=DB.data.triggers[trigger]
	for id in [row.primary,row.secondary]:
		if id=="" or not room(ai,s,id): continue
		s.serial+=1
		var key:="yr_%s"%s.serial
		s.jobs[key]={"team":id,"trigger":trigger,"members":[],"step":0,"age":0.0,"active":false,"success":false}

static func outcome(s: Dictionary,j: Dictionary,positive: bool) -> void:
	var row:Dictionary=DB.data.triggers[j.trigger]
	var delta:float=DB.data.success_delta if positive else DB.data.failure_delta
	s.weights[j.trigger]=clampf(float(s.weights.get(j.trigger,row.weight))+delta,row.min,row.max)

static func free_member(ai,u,key: String) -> void:
	if ai.battle.actor_alive(u) and u.special.get(MEMBER)==key:
		u.special.erase(MEMBER)
		if u.special.erase("yr_flak_post"): u.special.erase("campaign_area_guard")

static func recruit(ai,j: Dictionary,key: String,retail) -> bool:
	var counts_by_id:={}
	for u in j.members: counts_by_id[u.unit_id]=1+int(counts_by_id.get(u.unit_id,0))
	var ready:=true
	var queued:=false
	var starting_size:int=j.members.size()
	for part in DB.data.formations[DB.data.teams[j.team].force]:
		var id:=formation_product(part.product)
		var need:=int(part.count)-int(counts_by_id.get(id,0))
		if need<=0: continue
		for u in ai.battle.units:
			if not retail.available(ai,u,id): continue
			if u.is_harvester and ai.Economy.miners(ai,false)<=ai.Economy.desired_miners(ai): continue
			u.special[MEMBER]=key
			ai._army.erase(u)
			j.members.append(u)
			need-=1
			if need==0: break
		if need==0: continue
		ready=false
		if queued or ai.battle.ai_population_full(ai.house_id) or not GameData.unit_in_production_catalog(id): continue
		var in_line:=0
		for b in ai.battle.buildings:
			if ai.battle.actor_alive(b) and b.side==ai.house_id: in_line+=b.production.count(id)
		if need<=in_line: continue
		queued=retail.buy_member(ai,id)
	if queued or j.members.size()>starting_size: j.age=0.0
	return ready and not j.members.is_empty()

static func tick(ai,dt: float,retail) -> void:
	var s:Dictionary=ai.ai_state[STATE]
	s.left-=dt
	if s.left<=0:
		select(ai,s)
		s.left=float(DB.data.team_delays[2-clampi(ai.difficulty,0,2)])/15.0
	for key in s.jobs.keys():
		var j:Dictionary=s.jobs[key]
		for u in j.members.duplicate():
			if not ai.battle.actor_alive(u) or u.side!=ai.house_id or u.special.get(MEMBER)!=key or u.special.has("expedition_objective") or u.special.has("field_convoy"):
				free_member(ai,u,key)
				j.members.erase(u)
		j.age+=dt
		var finished:=false
		if not j.active:
			j.active=recruit(ai,j,key,retail)
			finished=not j.active and j.age>180
		if j.active:
			if j.members.is_empty(): finished=true
			else:
				var previous:bool=j.success
				finished=not Orders.advance(ai,key,j,dt,retail)
				if j.success and not previous: outcome(s,j,true)
		if finished:
			if not j.success: outcome(s,j,false)
			for u in j.members: free_member(ai,u,key)
			s.jobs.erase(key)
