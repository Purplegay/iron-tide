class_name RepairDock
extends RefCounted
const Access = preload("res://scripts/buildings/repair_access.gd")
## Approach uses normal navigation; only the final pad traversal ignores this depot.
## Transient collision exceptions are removed in the same physics call.

static func pad(depot) -> Vector2:
	return depot.depth_anchor()

static func invalidate(world) -> void:
	if is_instance_valid(world): world.remove_meta("repair_dock_candidates")

static func candidates(world) -> Array:
	var _call_log_scope = preload("res://scripts/world/battle_call_counters.gd").enter(68)
	# One broad scan per physics step, shared by every waiting vehicle/depot.
	# Live occupancy is still checked below so simultaneous arrivals cannot enter.
	var frame := Engine.get_physics_frames()
	var cached: Dictionary = world.get_meta("repair_dock_candidates", {})
	if cached.get("frame", -1) == frame: return cached.units
	var units: Array = []
	preload("res://scripts/world/battle_call_counters.gd").iterations(68,world.units.size())
	for other in world.units:
		if is_instance_valid(other) and (other.repairing or other.special.has("repair_exit_depot")) and world.actor_alive(other): units.append(other)
	world.set_meta("repair_dock_candidates", {"frame":frame, "units":units})
	return units

static func occupied(unit, depot) -> bool:
	for other in candidates(depot.battle):
		if other == unit or not depot.battle.actor_alive(other): continue
		if other.special.get("repair_exit_depot") == depot: return true
		if other.repairing and other.repair_depot == depot and other.special.get("repair_stage", "") == "inside": return true
	return false

static func queue_rank(unit, depot) -> int:
	var rank := 0
	for other in candidates(depot.battle):
		if not depot.battle.actor_alive(other) or not other.repairing or other.repair_depot != depot: continue
		if other == unit: return rank
		rank += 1
	return rank

static func step(unit, depot, point: Vector2, delta: float) -> bool:
	var offset: Vector2 = point - unit.position
	if offset.length() <= 2.0:
		unit.velocity = Vector2.ZERO
		return true
	unit._face(point)
	var motion := offset.limit_length(unit.move_speed * delta)
	unit.velocity = motion / maxf(delta, 0.001)
	if is_instance_valid(depot): unit.add_collision_exception_with(depot)
	var collision = unit.move_and_collide(motion)
	if collision != null:
		var slide: Vector2 = collision.get_remainder().slide(collision.get_normal())
		if slide.length_squared() > 0.01: unit.move_and_collide(slide)
	if is_instance_valid(depot): unit.remove_collision_exception_with(depot)
	unit._limit_turn(delta)
	unit.queue_redraw()
	return unit.position.distance_to(point) <= 2.0

static func tick(unit, delta: float) -> void:
	var _call_log_scope = preload("res://scripts/world/battle_call_counters.gd").enter(31)
	var depot = unit.repair_depot
	# Also upgrades old saves whose dock was outside the building.
	unit._repair_dock = pad(depot)
	if int(unit.get_meta("repair_access_epoch", -1)) != depot.battle.path_service.epoch:
		var replacement: Vector2 = Access.nearest(unit, depot)
		unit.set_meta("repair_access_epoch", depot.battle.path_service.epoch)
		if not replacement.is_finite():
			# A wide vehicle cannot fit this depot. Release its reservation so other
			# vehicles can use it; future AI requests try another reachable depot.
			unit._end_repair(false)
			return
		unit.special.repair_entry = replacement
		if unit.special.get("repair_stage", "approach") == "inside" and not Access.clear(unit,depot,unit.position,unit._repair_dock):
			unit.special.repair_stage = "approach"
			unit._clear_field()
	var entry: Vector2 = unit.special.repair_entry if unit.special.has("repair_entry") else depot.dock_point(unit.position)
	if not entry.is_finite(): return
	unit.special.repair_entry = entry
	# These read-only queries stay valid until this unit moves or changes stage;
	# every such branch below returns. Other actors still query live occupancy.
	var inside: bool = unit.special.get("repair_stage", "approach") == "inside"
	var rank := 0 if inside else queue_rank(unit, depot)
	var pad_busy := false if inside else occupied(unit, depot)
	# A large vehicle in a narrow legacy layout must not reserve the whole
	# facility forever. Retry later (or immediately after topology changes).
	if inside or (rank==0 and not pad_busy):
		var watch: Dictionary = unit.get_meta("repair_progress", {})
		if watch.is_empty() or unit.position.distance_to(watch.point)>8.0:
			watch={"point":unit.position,"left":8.0}
		else: watch.left-=delta
		unit.set_meta("repair_progress",watch)
		if watch.left<=0.0 and unit.position.distance_to(unit._repair_dock)>6.0:
			unit.set_meta("repair_unreachable",{"depot":depot,"epoch":depot.battle.path_service.epoch,"until":unit._anim+15.0})
			unit._end_repair(false)
			if unit.side=="ally": Events.emit_message("维修通道受阻，请清理平台附近空间。",Color(1.0,0.8,0.5))
			return
	if inside:
		if step(unit, depot, unit._repair_dock, delta): unit.has_move_order = false
		return
	# Grid padding can close an otherwise physically clear platform entrance.
	# Use the actual vehicle shape for the last short segment, still colliding
	# with every other building/vehicle. Only this depot is exempted.
	var near_entry: bool = unit.position.distance_to(entry) < 180.0
	if (near_entry or not unit.get_meta("repair_local_route",{}).get("points",PackedVector2Array()).is_empty()) and not pad_busy and rank == 0:
		var route: Dictionary = unit.get_meta("repair_local_route", {})
		var epoch: int = depot.battle.path_service.epoch
		if route.get("goal") != entry or route.get("epoch",-1) != epoch:
			route={"goal":entry,"epoch":epoch,"retry":0.0,"points":PackedVector2Array()}
		route.retry=maxf(0.0,float(route.retry)-delta)
		if route.points.is_empty() and route.retry<=0.0:
			route.points=PackedVector2Array([entry]) if Access.clear(unit,depot,unit.position,entry) else Access.local_route(unit,depot,entry)
			route.retry=2.0
		unit.set_meta("repair_local_route",route)
		if not route.points.is_empty():
			if step(unit,depot,route.points[0],delta):
				route.points.remove_at(0)
				if route.points.is_empty():
					unit.special.repair_stage = "inside"
					unit._clear_field()
			return
	var busy := pad_busy or rank > 0
	var waiting: Vector2 = Access.waiting(unit, depot, entry, rank) if busy else entry
	var destination: Vector2 = waiting if busy else entry
	# Keep waiting vehicles off the entrance/exit lane; otherwise a queue can
	# physically block the repaired vehicle whose departure it is waiting for.
	if unit.move_target.distance_to(destination) > 1.0:
		if not unit.ai_path_allowed():
			unit.velocity = Vector2.ZERO
			return
		unit._clear_field()
		unit.set_agent_path(unit._path_for(destination))
		# A partial route ends at a reachable cell. Keep the requested dock
		# point as the order so a snapped endpoint doesn't retrigger A* each tick.
		unit.move_target = destination
	if busy and unit.position.distance_to(destination) <= 16.0:
		unit.velocity = Vector2.ZERO
		unit._nav_stuck_t = 0.0
		return
	unit._tick_path_stuck(delta)
	if unit._go_to(destination, delta, 16.0):
		unit.velocity = Vector2.ZERO
		if not busy:
			unit.special.repair_stage = "inside"
			unit._clear_field()
	unit._move_water_safe()
	unit._face_if_moving()

static func leave(unit, depot) -> void:
	if not is_instance_valid(depot): return
	invalidate(depot.battle)
	var direction: Vector2 = depot.position.direction_to(unit.position)
	if unit.position.distance_to(depot.position) <= depot.footprint_clearance(direction) + unit.radius + 4.0:
		unit.special.repair_exit_depot = depot
		unit.special.repair_exit_point = unit.special.get("repair_entry", depot.dock_point(unit.position))
	unit.special.erase("repair_stage")
	unit.special.erase("repair_entry")
	unit.remove_meta("repair_access_epoch")
	unit.remove_meta("repair_local_route")
	unit.remove_meta("repair_progress")

static func tick_exit(unit, delta: float) -> bool:
	if not unit.special.has("repair_exit_point"): return false
	var depot = unit.special.get("repair_exit_depot")
	if is_instance_valid(depot) and not depot.is_dead() and not depot.data.get("water_bound", false):
		var epoch: int = depot.battle.path_service.epoch
		if int(unit.get_meta("repair_exit_epoch", -1)) != epoch:
			unit.set_meta("repair_exit_epoch", epoch)
			for point: Vector2 in Access.entries(unit,depot):
				if Access.clear(unit,depot,unit.position,point):
					unit.special.repair_exit_point = point
					break
	if not is_instance_valid(depot) or depot.is_dead() or unit.position.distance_to(unit.special.repair_exit_point) <= maxf(16.0, unit.radius) or step(unit, depot, unit.special.repair_exit_point, delta):
		unit.special.erase("repair_exit_depot")
		unit.special.erase("repair_exit_point")
		unit._clear_field()
		if unit.has_move_order:
			if unit.ai_path_allowed(): unit.set_agent_path(unit._path_for(unit.move_target))
			else: unit.special.ai_route_goal = unit.move_target
	return true
