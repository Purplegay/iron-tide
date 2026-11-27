extends RefCounted
## The three Soviet air-threat rules share a TeamType and its Max=2 limit.
const ROOM := "Confederation"
const ORDER := "all01_ai_order"

static func site(world,kind: String,at: Vector2):
	var result = null
	var best := INF
	for b in world.buildings:
		if not world.actor_alive(b) or b.building_id!=kind or b.side!="enemy" or b.special.get("allied_first_room","")!=ROOM or not b.is_operational(): continue
		var dist: float = b.position.distance_squared_to(at)
		if dist<best:
			best=dist
			result=b
	return result

static func can_train(world,b,row: Dictionary) -> bool:
	for kind in row.requires:
		if b.building_id!=kind and site(world,kind,b.position)==null: return false
	return b.can_queue(row.product)

static func factory_for(world,s: Dictionary,row):
	if s.get("flak_jobs",{}).size()>=int(row.team_max): return null
	var threats := 0
	for u in world.units:
		if world.actor_alive(u) and u.side=="ally" and u.special.get("allied_first_room","Americans")=="Americans" and u.unit_id==row.threat: threats+=1
	if threats<int(row.minimum): return null
	for b in world.buildings:
		if not world.actor_alive(b) or b.side!="enemy" or b.building_id!="NAHAND" or b.special.get("allied_first_room","")!=ROOM: continue
		if b.is_operational() and not b.special.has(ORDER) and b.production.is_empty() and can_train(world,b,row) and site(world,row.target,b.position)!=null: return b
	return null

static func begin(s: Dictionary,b,row: Dictionary) -> void:
	s.flak_serial = int(s.get("flak_serial",0))+1
	var id := str(s.flak_serial)
	var jobs: Dictionary = s.get_or_add("flak_jobs",{})
	jobs[id] = {"rule":row.id,"target":row.target,"quantity":int(row.quantity),"made":0,"phase":"build"}
	b.special.all01_flak_job=id

static func produced(world,b,u,row: Dictionary) -> void:
	var s: Dictionary = world.allied_state.allied_first
	var id: String = b.special.get("all01_flak_job","")
	var job: Dictionary = s.get("flak_jobs",{}).get(id,{})
	if job.is_empty() or b.side!="enemy" or b.special.get("allied_first_room","")!=ROOM: return
	u.special.allied_first_room=ROOM
	u.special.allied_first_team=row.team
	u.special.allied_first_ai=row.id
	u.special.all01_flak_job=id
	u.refresh_house_color()
	job.made=int(job.made)+1
	if job.made<job.quantity and s.get("confederation_production",false) and can_train(world,b,row) and b.enqueue(row.product): return
	b.special.erase(ORDER)
	b.special.erase("all01_flak_job")
	job.phase="dispatch"

static func guard(members: Array) -> void:
	for u in members:
		u.order_guard()
		u.cancel_stance()
		u.special.campaign_area_guard=u.global_position

static func tick(world,s: Dictionary,delta: float) -> void:
	var jobs: Dictionary = s.get("flak_jobs",{})
	if jobs.is_empty(): return
	s.flak_poll = float(s.get("flak_poll",0.0))-delta
	if s.flak_poll>0: return
	s.flak_poll=0.25
	for id in jobs.keys():
		var job: Dictionary = jobs[id]
		if job.phase=="build":
			var valid: bool = world.buildings.any(func(b):return world.actor_alive(b) and b.side=="enemy" and b.special.get("all01_flak_job","")==id)
			if valid: continue
			job.phase="dispatch"
		var members: Array = world.units.filter(func(u):return world.actor_alive(u) and u.side=="enemy" and u.special.get("all01_flak_job","")==id)
		if members.is_empty():
			jobs.erase(id)
			continue
		if job.phase=="guard": continue
		var gun = site(world,job.target,members[0].position)
		if gun==null:
			guard(members)
			job.phase="guard"
			continue
		var anchor := [gun.position.x,gun.position.y]
		if job.get("anchor",[])!=anchor:
			job.anchor=anchor
			job.phase="dispatch"
		match str(job.phase):
			"dispatch":
				for u in members: u.order_move(world.AlliedFirst.Orders.approach(u,gun))
				job.phase="rally"
			"rally":
				if not members.all(func(u):return u.position.distance_to(gun.position)<=gun.radius+120): continue
				for i in members.size():
					var dest: Vector2 = gun.position+Vector2.RIGHT.rotated(TAU*i/members.size())*(gun.radius+90)
					var spot: Vector2 = world.path_service.nearest_reachable(dest,members[i].position,false,4)
					if spot.is_finite(): members[i].order_move(spot)
				job.phase="scatter"
			"scatter":
				if not members.any(func(u):return u.has_move_order):
					guard(members)
					job.phase="guard"
