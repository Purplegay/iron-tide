extends RefCounted
# Diagnostic only: installed into an isolated soak copy, never into the game.
static var next_sample := 0.0
static var ai_calls := {}
static var routes := []
static var route_counts := {}
static func route(world,unit,requested:Vector2,resolved:Vector2) -> void:
	var count:int=route_counts.get(unit.side,0)
	if count>=12:return
	route_counts[unit.side]=count+1
	var nav=world.path_service
	routes.append({"side":unit.side,"type":unit.unit_id,"from":point(unit.position),"requested":point(requested),"resolved":point(resolved),"from_zone":nav.zone_at(unit.position),"goal_zone":nav.zone_at(requested),"goal_blocked":nav.is_blocked(requested),"from_blocked":nav.is_blocked(unit.position)})
static func hit(side:String,event:String) -> void:
	var row:Dictionary=ai_calls.get_or_add(side,{})
	row[event]=int(row.get(event,0))+1
static func plain(value,depth:int=0):
	if typeof(value)==TYPE_OBJECT:
		return {"instance":value.get_instance_id()} if is_instance_valid(value) else null
	if value is Vector2:return point(value)
	if value is Dictionary:
		if depth>=5:return {"keys":value.keys()}
		var out:Dictionary={}
		for key in value:out[str(key)]=plain(value[key],depth+1)
		return out
	if value is Array:
		var out:Array=[]
		for i in mini(value.size(),128):out.append(plain(value[i],depth+1))
		return out
	return value
static func point(v:Vector2) -> Array:
	return [v.x,v.y] if v.is_finite() else []
static func sample(world:Battle,seconds:float,out:String) -> void:
	if seconds<next_sample:return
	next_sample=seconds+5.0
	var actors:=[]
	for candidate in world.units:
		if not is_instance_valid(candidate) or not candidate is Unit:continue
		var unit:Unit=candidate
		if unit._dead or unit.is_air or unit.is_naval or unit.embarked_in!=null:continue
		var path:=[]
		for p:Vector2 in unit._path_pts:path.append(point(p))
		var neighbors:=[]
		for other in unit._local_traffic.nearby:
			if is_instance_valid(other):neighbors.append(other.get_instance_id())
		actors.append({"id":unit.get_instance_id(),"type":unit.unit_id,"side":unit.side,"p":point(unit.global_position),
			"velocity":point(unit.velocity),"radius":unit.radius,"move":unit.has_move_order,"goal":point(unit.move_target),
			"path":path,"path_index":unit._path_i,"stuck_s":unit._nav_stuck_t,"turning":unit._drive_turning,"hull":unit.hull_angle,
			"blocked_goal":point(unit._blocked_move_goal),"dodge_s":unit._dodge_t,"hold":unit.hold_position,"deployed":unit._deployed,
			"target":unit.attack_target.get_instance_id() if is_instance_valid(unit.attack_target) else 0,
			"ordered_attack":unit.attack_ordered,"yield":point(unit._local_traffic.yield_target),"nearby":neighbors,
			"ai_special":plain(unit.special),"attack_move":unit.attack_move,"queue":plain(unit.order_queue),"collision_layer":unit.collision_layer,"collision_mask":unit.collision_mask})
	var houses:=[]
	for side in world.house_controllers:
		var ai=world.house_controllers[side]
		var lines:=[]
		for building in world.buildings:
			if world.actor_alive(building) and building.side==side:
				lines.append({"type":building.building_id,"p":point(building.position),"queue":plain(building.production),"exit_blocked":building.exit_blocked,"operational":building.is_operational()})
		var repair_checks:=[]
		if BattleRequest.friendly(side,"ally"):
			var opponents:Array=preload("res://scripts/world/skirmish_operations.gd").targets(ai)
			for hut in world.buildings:
				if not world.actor_alive(hut) or hut.building_id!="CABHUT" or hut.special.get("bridge_repaired",false):continue
				var threats:=[]
				for threat in opponents:
					if not threat.weapon.is_empty() and threat.position.distance_to(hut.position)<maxf(330.0,threat.attack_range+110.0):threats.append(threat.get_instance_id())
				var producers:=[]
				var worker_id:String="SENGINEER" if ai.enemy_base=="soviet" else "ENGINEER"
				for line in world.buildings:
					if not world.actor_alive(line) or line.side!=side or worker_id not in line.buildable:continue
					var exit_point:Vector2=ProductionExit.origin(line,GameData.get_unit(worker_id))
					producers.append({"id":line.get_instance_id(),"p":point(line.position),"exit":point(exit_point),"blocked":line.queue_block_reason(worker_id),"reachable":exit_point.is_finite() and preload("res://scripts/world/ai_bridge_repair.gd").reachable(world,exit_point,hut)})
				repair_checks.append({"hut":hut.get_instance_id(),"p":point(hut.position),"visible":world.actor_visible_to(side,hut),"threats":threats,"producers":producers})
		houses.append({"repair_checks":repair_checks,"population":world.ai_living_count(side),"population_full":world.ai_population_full(side),"side":side,"friendly_to_player":BattleRequest.friendly(side,"ally"),"base":point(ai.base_center),"rally":point(ai.rally),"funds":ai.funds,"difficulty":ai.difficulty,"processing":ai.is_processing(),"calls":ai_calls.get(side,{}).duplicate(),"state":plain(ai.ai_state),"buildings":lines})
	var file=FileAccess.open(out.path_join("traffic-snapshots.jsonl"),FileAccess.READ_WRITE if FileAccess.file_exists(out.path_join("traffic-snapshots.jsonl")) else FileAccess.WRITE)
	file.seek_end();file.store_line(JSON.stringify({"sim_s":seconds,"actors":actors,"houses":houses,"teams":BattleRequest.house_teams,"routes":routes,"bridge_health":plain(world.allied_state.get("bridge_section_health",{})),"legacy_bridge_health":plain(world.allied_state.get("bridge_health",{}))}));file.close()
