extends RefCounted
## Source TeamType orders for the first mission's pre-warp assault waves.

static func form(w,s: Dictionary,d,cmd: Dictionary) -> bool:
	var spec: Dictionary=d.resolve_spawn(cmd)
	if spec.is_empty(): return false
	var group: Dictionary=spec.team
	var team: String=cmd.fields[2]
	var room: String=group.team.house
	var origin: Vector2=w.AlliedFirst.wp(int(spec.waypoint.id))
	var tags: Dictionary={"allied_first_room":room,"allied_first_team":team,"assault_line":0,"assault_spawn":spec.waypoint.id}
	if group.team.get("droppod","no")=="yes":
		var member:=str(group.task_force["0"]).split(",")
		var entry: Vector2=w.AlliedFirst.wp(d.code(group.team.transportwaypoint))
		return preload("res://scripts/world/american_paradrop.gd").launch_story(w,origin,member[1],int(member[0]),entry,tags,w.AlliedFirst.side(room))
	if cmd.opcode!=4 and not w.AlliedFirst.Places.data(w.AlliedFirst.MAP).waypoints[str(int(spec.waypoint.id))][2]:
		var first:=str(group.script["0"]).split(",")
		if first[0]=="3":
			var amphibious: bool=group.task_force.values().any(func(v):return str(v).ends_with(",YHVR"))
			origin=w.path_service.nearest_reachable(origin,w.AlliedFirst.wp(int(first[1])),false,w.path_service.cols,amphibious)
	var actors: Array=[]
	var boat=null
	var slot:=0
	while group.task_force.has(str(slot)):
		var force:=str(group.task_force[str(slot)]).split(",")
		slot+=1
		var count:=int(force[0])
		if cmd.opcode==4:
			var available: Array=[]
			for u in w.units:
				if not w.actor_alive(u) or u.unit_id!=force[1] or u.special.get("allied_first_room","")!=room or u.embarked_in!=null: continue
				if u.unit_id=="YHVR" and (not u.logistics.passengers.is_empty() or not u.special.get("assault_return_ready",false)): continue
				if d.state.map=="yr_all01umd_closing" and u.special.has("allied_first_team"): continue # These two original teams have Recruiter=no.
				available.append(u)
			available.sort_custom(func(a,b):return a.position.distance_squared_to(origin)<b.position.distance_squared_to(origin))
			actors.append_array(available.slice(0,count))
		else:
			for i in count:
				var ordinal:=actors.size()
				var u=w.spawn_unit(force[1],w.AlliedFirst.side(room),origin+Vector2(ordinal%3,ordinal/3)*18.0)
				if u==null:
					for made in actors: w.AlliedFirst.Orders.consume(made)
					return false
				actors.append(u)
	for u in actors:
		u.special.merge(tags,true)
		u.special.erase("assault_return_ready")
		u.special.erase("assault_boundary_target")
		u.special.erase("all01_patrol_step")
		u.refresh_house_color()
		u.hold_position=false
		if u.unit_id in ["YHVR","FV"]: boat=u
	if team=="09F3BC1C": s.ggi_attack_sent=true
	if boat!=null and boat.unit_id=="YHVR" and cmd.opcode!=4:
		for u in actors:
			if u==boat: continue
			u.set_stowed(boat)
			boat.logistics.passengers.append(u)
			u.special.assault_line=3 # Disembarked members continue after the transport's local flag.
	for u in actors:
		if boat!=null and u.unit_id=="ENGINEER":
			u.logistics.request_board(boat)
			u.special.erase("assault_line")
		elif u.embarked_in==null: step(w,d,u)
	return true

static func target_for(w,u,op: int,arg: int):
	var best=null
	for a in w.units+w.buildings:
		if not w.actor_alive(a) or a.side!="ally": continue
		if a is Unit and a.embarked_in!=null: continue
		if op==46:
			if not a is Building or a.building_id!=w.AlliedFirst.Assault.TANK_TARGET: continue
		else:
			match arg:
				1: pass # anything
				2:
					if not a is Building: continue
				4:
					if not a is Unit or not AlliedAbilities.infantry(a): continue
				5:
					if not a is Unit or AlliedAbilities.infantry(a) or a.is_air: continue
				7:
					if not a is Building or a.attack_range<=0: continue
		if best==null or u.position.distance_squared_to(a.position)<u.position.distance_squared_to(best.position): best=a
	return best

static func step(w,d,u) -> void:
	if u.embarked_in!=null or u.special.has("para_height"): return
	var line:=int(u.special.assault_line)
	var script: Dictionary=d.definition.teams[str(u.special.allied_first_team).to_lower()].script
	if not script.has(str(line)):
		u.special.erase("assault_line")
		return
	var f:=str(script[str(line)]).split(",")
	var op:=int(f[0])
	var arg:=int(f[1])
	match op:
		3:
			var dest: Vector2=w.AlliedFirst.wp(arg)
			if not w.AlliedFirst.Places.data(w.AlliedFirst.MAP).waypoints[str(arg)][2]:
				if not u.special.has("assault_boundary_target"):
					u.special.assault_boundary_target=w.path_service.nearest_reachable(dest,u.position,false,w.path_service.cols,u.unit_id=="YHVR")
				dest=u.special.assault_boundary_target
			if u.position.distance_to(dest)>w.AlliedFirst.Places.CELL:
				if not u.has_move_order or not u.move_target.is_equal_approx(dest): u.order_move(dest)
				return
		8:
			if not u.logistics.passengers.is_empty():
				if not u.logistics.unloading: u.logistics.request_unload()
				return
		39:
			d.set_local(arg,true)
			u.special.assault_return_ready=true
			u.special.erase("assault_line")
			return
		14:
			# Boarding is issued to the engineer during recruitment. The IFV stays available to the player.
			pass
		37:
			w.AlliedFirst.Orders.consume(u)
			w.units.erase(u)
			return
		0,46:
			var target=target_for(w,u,op,arg)
			if target!=null:
				if not u.attack_ordered or u.attack_target!=target: u.order_target(target,false,false)
				return
		1,59:
			var at: Vector2=w.AlliedFirst.wp(arg)
			for b in w.buildings:
				if not w.actor_alive(b) or b.special.get("allied_first_index","")!=d.definition.assault_sites[str(arg)]: continue
				if not u.attack_ordered or u.attack_target!=b: u.order_target(b,true,false)
				return
			if op==59:
				u.special.assault_line=line+1
				return
			if not u.attack_ordered or not u.attack_target is ForceFirePoint:
				var p:=ForceFirePoint.new()
				p.global_position=at
				p.side="ally"
				u.order_target(p,true,false)
			return
		50:
			u.special.assault_flash_until=float(d.state.time)+float(arg)/BattleClock.RULE_TICKS_PER_SECOND
		49:
			u.hold_position=false
	u.special.erase("assault_boundary_target")
	u.special.assault_line=line+1
