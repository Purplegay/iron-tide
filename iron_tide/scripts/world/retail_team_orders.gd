extends RefCounted
## Global AIMD ScriptType commands. Each invocation advances at most one command.
const DB = preload("res://data/ra2/retail_skirmish.json")
const Garrison = preload("res://scripts/units/civilian_orders.gd")
const Shift = preload("res://scripts/world/chronoshift.gd")
const Support = preload("res://scripts/world/skirmish_support.gd")

static func quarry(actor,kind:int) -> bool:
	match kind:
		0,1: return true
		2: return actor is Building
		3: return actor is Unit and (actor.is_harvester or actor.unit_id=="SMIN")
		4: return actor is Unit and AlliedAbilities.infantry(actor)
		5: return actor is Unit and not AlliedAbilities.infantry(actor)
		6: return actor is Building and not actor.buildable.is_empty()
		7: return actor is Building and actor.battle.structure_category(actor.building_id)=="defense"
		9: return actor is Building and float(actor.data.get("power",0))>0
	return false

static func choose(ai,j:Dictionary,op:int,arg:int):
	var lead=j.members[0]
	var best=null
	var score:=INF
	var mode:=arg>>16 if op in [46,47,58] else 2
	var own:=op in [58,61,62,63]
	var id: String={61:"NATBNK",62:"YAPOWR",63:"NABNKR"}.get(op,"")
	if op in [46,47,58]:
		if (arg&65535)>=DB.data.buildings.size(): return null
		id=DB.data.buildings[arg&65535]
	var threats:Array=ai.Operations.targets(ai) if mode<2 else []
	var list:Array=ai.battle.buildings if id!="" else ai.Operations.targets(ai)
	for a in list:
		if not ai.battle.actor_alive(a) or (not own and a.special.get("expedition_protected",false)): continue
		if own:
			if a.side!=ai.house_id or not a.is_operational(): continue
		else:
			if BattleRequest.friendly(ai.house_id,a.side) or not ai.battle.actor_visible_to(ai.house_id,a): continue
			if a.side=="neutral" and (op!=46 or not j.members.any(func(u): return u.unit_id in ["ENGINEER","SENGINEER","YENGINEER"])): continue
		if id!="" and a.building_id!=id: continue
		if id=="" and not quarry(a,arg): continue
		if op==0 and not j.members.any(func(u):return not u.weapon.is_empty() and u.attack_domain_valid(a)): continue
		if op==46 and a.side=="neutral" and not j.members.any(func(u):return AlliedAbilities.can_order(u,a,"allied_engineer")): continue
		if op in [61,62,63] and not j.members.any(func(u):return Garrison.can_enter(u,a)): continue
		var d:float=lead.position.distance_squared_to(a.position)
		var rank:=d
		if mode==3: rank=-d
		if mode<2:
			var threat:=0.0
			for other in threats:
				if other==a or other.position.distance_squared_to(a.position)>400.0*400.0: continue
				threat+=1
			rank=(threat if mode==0 else -threat)*1.0e9+d
		if rank<score:
			if op in [0,46,47,58] and not accessible(ai,j,a): continue
			score=rank
			best=a
	return best

static func accessible(ai,j:Dictionary,target) -> bool:
	for u in j.members:
		if u.embarked_in!=null: continue
		if u.is_air: return true
		var reach:=maxf(u.attack_range if not u.weapon.is_empty() else 0.0,target.radius+95.0)
		if u.position.distance_to(target.position)<=reach: return true
		var p:Vector2=ai.battle.path_service.nearest_reachable(target.position,u.position,u.is_naval,8,u.is_amphibious)
		if p.is_finite() and p.distance_to(target.position)<=reach: return true
	return false

static func move_group(ai,key:String,j:Dictionary,goal:Vector2,retail,reach:float=75.0) -> bool:
	var arrived:=true
	for u in j.members:
		if u.embarked_in!=null: continue
		if u.position.distance_to(goal)<=reach: continue
		arrived=false
		var p: Vector2=goal if u.is_air else ai.battle.path_service.nearest_reachable(goal,u.position,u.is_naval,8,u.is_amphibious)
		if p.is_finite() and p.distance_to(goal)<=maxf(180,reach): retail.move(ai,u,key,p,true)
	return arrived

static func explore(ai,key:String,j:Dictionary,retail) -> void:
	var limit:float=ai.battle.map_size
	var points:=7
	var cursor:=int(j.get("scout",0))
	for offset in points*points:
		var i:=(cursor+offset)%49
		var goal:=Vector2(0.5+(i*17%49)%7,0.5+floori((i*17%49)/7.0))*limit/7.0
		if ai.battle.position_explored_by(ai.house_id,goal): continue
		var lead=j.members[0]
		if not lead.is_air:
			var p:Vector2=ai.battle.path_service.nearest_reachable(goal,lead.position,lead.is_naval,6,lead.is_amphibious)
			if not p.is_finite() or p.distance_to(goal)>150: continue
		j.scout=i
		move_group(ai,key,j,goal,retail)
		return

static func engage(ai,key:String,j:Dictionary,t,retail) -> void:
	for u in j.members:
		if u.embarked_in!=null: continue
		if t is Building and u.unit_id in ["TANY","GHOST","CCOMAND"] and AlliedAbilities.can_order(u,t,"allied_c4"):
			if not u.special.has("action"): AlliedAbilities.use(u,"allied_c4",t)
		elif t is Building and (u.unit_id=="SPY" or u.unit_id in ["ENGINEER","SENGINEER","YENGINEER"]):
			if not u.special.has("action"): AlliedAbilities.use(u,"allied_infiltrate" if u.unit_id=="SPY" else "allied_engineer",t)
		elif not u.weapon.is_empty() and u.attack_domain_valid(t) and (not u.attack_ordered or u.attack_target!=t):
			retail.send(ai,u,key,{"kind":"attack","target":t})

static func board(j:Dictionary) -> bool:
	var carriers:Array=j.members.filter(func(u):return u.logistics.capacity>0)
	if carriers.is_empty(): return false
	var done:=true
	for u in j.members:
		if u in carriers or u.embarked_in!=null: continue
		done=false
		if u.logistics.boarding!=null: continue
		for carrier in carriers:
			if u.logistics.request_board(carrier): break
	return done

static func support(ai,j:Dictionary,op:int,arg:int) -> bool:
	var lead=j.members[0]
	for b in ai.battle.buildings:
		if not ai.battle.actor_alive(b) or b.side!=ai.house_id or not b.sw_ready(): continue
		if op==55 and b.sw_type()=="IronCurtain": return b.fire_superweapon(lead.position)
		if op!=57 or b.sw_type()!="ChronoSphere": continue
		var target=choose(ai,j,57,arg)
		if target==null: return false
		var group:=Shift.actors(ai.battle,lead.position,ai.house_id)
		if group.is_empty() or not group.all(func(u):return Support.armour(ai.battle,u,ai.house_id)): continue
		for i in 8:
			var goal:Vector2=target.position+Vector2.from_angle(i*TAU/8.0)*(target.radius+160.0)
			if ai.battle.position_visible_to(ai.house_id,goal) and group.all(func(u):return Shift.landing_clear(ai.battle,u,goal+u.position-lead.position,group)):
				if b.fire_superweapon(goal,lead.position): return true
	return false

static func advance(ai,key:String,j:Dictionary,dt:float,retail) -> bool:
	var script:Array=DB.data.scripts[DB.data.teams[j.team].script]
	if j.step>=script.size(): return false
	var cmd:Array=script[int(j.step)]
	var op:=int(cmd[0])
	var arg:=int(cmd[1])
	var elapsed:=float(j.get("elapsed",0))+dt
	var lead=j.members[0]
	var done:=false
	match op:
		0,46,47,58:
			var t=j.get("target")
			if j.has("target") and (not ai.battle.actor_alive(t) or (op!=58 and BattleRequest.friendly(ai.house_id,t.side))):
				done=true
			else:
				if op!=58 and ai.battle.actor_alive(t) and not ai.battle.actor_visible_to(ai.house_id,t):
					j.erase("target")
					t=null
				if t==null: t=choose(ai,j,op,arg)
				if t==null:
					if op!=58: explore(ai,key,j,retail)
				else:
					j.target=t
					if op in [47,58]:
						done=move_group(ai,key,j,t.position,retail,t.radius+95.0)
					else: engage(ai,key,j,t,retail)
		5,11:
			for u in j.members:
				if u.embarked_in==null and not u.special.has("yr_flak_post"):
					retail.send(ai,u,key,{"kind":"area_guard","site":u.position})
			if op==11: return true
			done=elapsed>=arg
		6:
			j.step=clampi(arg-1,0,script.size()-1)
			j.erase("elapsed")
			return true
		8:
			done=true
			for u in j.members:
				if u.logistics.capacity>0 and not u.logistics.passengers.is_empty():
					done=false
					if not u.logistics.unloading: u.logistics.request_unload()
			if done and arg==2:
				for u in j.members.duplicate():
					if u.logistics.capacity>0:
						retail.release(u)
						j.members.erase(u)
						if DB.data.teams[j.team].transports_return: u.ai_order("move",ai.rally,false)
		9:
			done=true
			for u in j.members:
				if not u.is_deployed(): done=u.set_deployed(true,false) and done
		14: done=board(j)
		43:
			done=j.members.all(func(u):return u.logistics.capacity>0 or u.embarked_in!=null)
		21:
			for i in j.members.size():
				var u=j.members[i]
				retail.move(ai,u,key,u.position+Vector2.from_angle(i*TAU/j.members.size())*75.0,false)
			done=true
		49:
			j.success=true
			done=true
		53,54:
			var goal:Vector2=ai.base_center
			if op==53:
				var contacts:Array=ai.Operations.targets(ai)
				if contacts.is_empty():
					explore(ai,key,j,retail)
					j.elapsed=elapsed
					return elapsed<180
				goal=contacts[0].position
			var back: Vector2=goal.direction_to(ai.base_center if op==53 else ai.rally)
			var offset:float=minf(float(DB.data.safe_distance)*Ra2Damage.PX_PER_CELL,ai.base_center.distance_to(ai.rally) if op==54 else ai.base_center.distance_to(goal)*0.4)
			done=move_group(ai,key,j,goal+back*offset,retail)
		55,57: done=support(ai,j,op,arg)
		61,62,63:
			var t=choose(ai,j,op,arg)
			done=true
			for u in j.members:
				if u.embarked_in!=null: continue
				if t==null: continue # An optional garrison may be absent, full or unable to admit the remaining members.
				if Garrison.can_enter(u,t):
					done=false
					if not u.special.has("action"): u.order_interaction("allied_garrison",t,false)
	if done:
		j.step+=1
		j.erase("elapsed")
		j.erase("target")
		if op==5:
			for u in j.members:
				if u.special.erase("yr_flak_post"): u.special.erase("campaign_area_guard")
		return j.step<script.size() and not j.members.is_empty()
	j.elapsed=elapsed
	return elapsed<maxf(180.0,arg+20.0 if op==5 else 180.0)
