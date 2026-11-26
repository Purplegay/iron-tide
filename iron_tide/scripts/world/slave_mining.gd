extends RefCounted

const CELL := Ra2Damage.PX_PER_CELL
const TPS := BattleClock.RULE_TICKS_PER_SECOND
const SHORT_SCAN := 8.0 * CELL
const LONG_SCAN := 48.0 * CELL
const WORKER_SCAN := 14.0 * CELL
const RESCAN := 150.0 / TPS

static func transfer(source,destination) -> void:
	for key in ["hollywood_house","slave_crew","slave_wait"]:
		if source.special.has(key): destination.special[key]=source.special[key]
	for worker in destination.special.get("slave_crew",[]):
		if not AlliedAbilities.alive(worker): continue
		worker.order_stop(false)
		worker.special.erase("mine_node")
		worker.special.erase("shoveling")
		if destination is Unit:
			worker.set_stowed(destination)
		else:
			worker.set_stowed(null)
			var exit:Vector2 = destination._spawn_point(worker.unit_id)
			if exit.is_finite(): worker.position=exit
		worker.queue_redraw()

static func release(owner,killer) -> void:
	var side := "neutral"
	if is_instance_valid(killer):
		if killer is Projectile:
			side = killer.owner_side
		elif killer.get("side") != null:
			side = killer.side
	var has_survivors := false
	for worker in owner.special.get("slave_crew",[]):
		if not AlliedAbilities.alive(worker): continue
		if is_instance_valid(worker.embarked_in):
			worker.set_stowed(null)
			worker.position=owner.position
		worker.order_stop(false)
		worker.special.erase("mine_node")
		worker.special.erase("shoveling")
		AlliedAbilities.change_side(worker,side)
		worker.set_fire_stance("free" if side!="neutral" else "none")
		has_survivors=true
	if has_survivors: Ra2Sfx.play("SlaveWorkerLiberated",owner.position)
	owner.special.erase("slave_crew")

static func nearest_ore(w,center:Vector2,origin:Vector2,reach:float):
	# Workers can finish unloading just inside the mine's blocked path cell.
	# Use the adjacent walkable start, as the movement planner does.
	var origin_zone:int=w.path_service.zone_at(origin)
	if origin_zone==0:
		var start:Vector2=w.path_service.ground_near_base(origin,5)
		if not start.is_finite(): return null
		origin_zone=w.path_service.zone_at(start)
	var best := INF
	var found = null
	for node in w.ore_neighborhood.nearby(center,reach):
		if not is_instance_valid(node) or node.amount<=0 or center.distance_squared_to(node.position)>reach*reach: continue
		var dist:float = node.position.distance_squared_to(origin)
		if dist<best and origin_zone==w.path_service.zone_at(node.position):
			found=node
			best=dist
	return found

static func tick(w,elapsed:float) -> void:
	for miner in w.units.duplicate():
		if w.actor_alive(miner) and miner.unit_id=="SMIN" and (miner.side=="enemy" or w.skirmish and BattleRequest.is_ai_house(miner.side)) and miner.embarked_in==null:
			mobile(w,miner,elapsed)
	for site in w.buildings.duplicate():
		if w.actor_alive(site) and site.building_id=="YAREFN" and site.is_operational() and site._buildup_play<0:
			deployed(w,site,elapsed)

static func mobile(w,miner,dt:float) -> void:
	if miner.special.has("mcv_repack_left") and preload("res://scripts/world/construction_transition.gd").active(miner): return
	if miner.special.has("slave_destination"):
		var goal:Vector2=miner.special.slave_destination
		if miner.position.distance_to(goal)<=25:
			miner.special.erase("slave_destination")
			if miner.deploy(): return
		elif miner.has_move_order: return
		else: miner.special.erase("slave_destination")
	miner.special.slave_scan_left=float(miner.special.get("slave_scan_left",0))-dt
	if miner.special.slave_scan_left>0: return
	miner.special.slave_scan_left=RESCAN
	var ore=nearest_ore(w,miner.position,miner.position,LONG_SCAN)
	if ore==null: return
	if ore.position.distance_to(miner.position)<=SHORT_SCAN and miner.deploy(): return
	var start:float=ore.position.direction_to(miner.position).angle()
	for radius in [2,4,6]:
		for i in 12:
			var goal:Vector2=w.snap_build_pos(ore.position+Vector2.from_angle(start+i*TAU/12)*CELL*radius)
			if not w.path_service.same_zone(miner.position,goal) or not w.construction_deploy_check(miner,goal).ok: continue
			var path:PackedVector2Array=w.path_for_unit(miner,goal)
			if path.is_empty(): continue
			miner.order_move(goal,false,null,path)
			miner.special.slave_destination=goal
			return

static func deployed(w,site,dt:float) -> void:
	var desired:int=site.data.workers
	var crew:Array=site.special.get_or_add("slave_crew",[])
	var waits:Array=site.special.get_or_add("slave_wait",[])
	while crew.size()<desired:
		crew.append(null)
		waits.append(0.0)
	for index in desired:
		var worker=crew[index]
		if not w.actor_alive(worker):
			if waits[index]<0:
				crew[index]=null
				waits[index]=float(site.data.regen_ticks)/TPS
			waits[index]=maxf(0,float(waits[index])-dt)
			if waits[index]>0: continue
			var pos:Vector2=site._spawn_point(site.data.worker)
			if not pos.is_finite(): continue
			worker=w.spawn_unit(site.data.worker,site.side,pos)
			if worker==null: continue
			worker.set_fire_stance("none")
			crew[index]=worker
			waits[index]=-1.0
		work(w,site,worker,dt)
	if site.side=="enemy" or w.skirmish and BattleRequest.is_ai_house(site.side):
		site.special.slave_scan_left=float(site.special.get("slave_scan_left",RESCAN))-dt
		if site.special.slave_scan_left<=0:
			site.special.slave_scan_left=RESCAN
			if nearest_ore(w,site.position,site.position,SHORT_SCAN)==null and nearest_ore(w,site.position,site.position,LONG_SCAN)!=null and crew.all(func(u):return not w.actor_alive(u) or u.cargo<=0):
				preload("res://scripts/world/construction_repack.gd").execute(w,site)

static func approach(w,worker,point:Vector2) -> void:
	if not worker.has_move_order or worker.move_target.distance_to(point)>12:
		worker.order_move(point,false,null,w.path_for_unit(worker,point))

static func work(w,site,u,dt:float) -> void:
	var node=u.special.get("mine_node")
	var has_ore:bool=is_instance_valid(node) and node.amount>0
	if not has_ore and u.cargo<float(u.data.storage):
		node=nearest_ore(w,site.position,u.position,WORKER_SCAN)
		u.special.mine_node=node
		has_ore=node!=null
	if u.cargo>=float(u.data.storage) or (not has_ore and u.cargo>0):
		u.special.erase("shoveling")
		var direction:Vector2=site.position.direction_to(u.position)
		if u.position.distance_to(site.position)>site.footprint_clearance(direction)+u.radius+30:
			var bay:Vector2=site._spawn_point(u.unit_id)
			if bay.is_finite(): approach(w,u,bay)
			return
		u.order_stop(false)
		u._unload_cargo(u.cargo)
		preload("res://scripts/units/hollywood_unit_fx.gd").deposit(site)
		u.special.mine_delay=float(site.data.reload_ticks)/TPS
		u.special.erase("mine_node")
		return
	if not has_ore:
		u.special.erase("shoveling")
		return
	if u.position.distance_to(node.position)>node.radius+u.radius+8:
		u.special.erase("shoveling")
		approach(w,u,node.position)
		return
	if u.has_move_order: u.order_stop(false)
	u.special.shoveling=true
	var period:float=float(u.data.harvest_ticks)/TPS
	u.special.mine_delay=float(u.special.get("mine_delay",period))-dt
	if u.special.mine_delay<=0:
		var taken:float=node.extract(1)
		u.cargo+=taken
		if node.resource_kind=="gems": u.cargo_gems+=taken
		u.special.mine_delay=period
