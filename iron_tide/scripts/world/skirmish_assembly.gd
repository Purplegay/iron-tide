extends RefCounted
const SEARCH_RINGS := 8

## Allocate parking only when an AI rally order is issued. Production lanes stay
## traversable: these exclusions apply to destinations, never to pathfinding.
static func assemble(ai, unit) -> void:
	ai.battle.ai_dispatch.submit(ai.battle,unit,{"kind":"rally","point":ai.rally})

static func park(world, unit, rally: Vector2) -> void:
	var nav = world.path_service
	var center: Vector2 = rally if unit.is_air else nav.nearest_reachable(rally, unit.position, false, 20, unit.is_amphibious)
	var spacing: float = world._formation_spacing([unit])
	var yards := production_lanes(world, unit)
	var occupied: Array[Vector3] = []
	for other in world.units:
		if other == unit or not world.actor_alive(other) or other.side != unit.side or other.embarked_in != null or other.is_air != unit.is_air: continue
		var clearance: float = unit.radius + other.radius + 2 * Unit.ARRIVE_EPS + 4.0
		var nearby := (SEARCH_RINGS * spacing + clearance) ** 2
		if center.distance_squared_to(other.position) <= nearby:
			occupied.append(Vector3(other.position.x, other.position.y, clearance))
		if other.has_move_order and center.distance_squared_to(other.move_target) <= nearby:
			occupied.append(Vector3(other.move_target.x, other.move_target.y, clearance))
	var approach: Vector2 = center.direction_to(unit.position)
	if approach.is_zero_approx(): approach = Vector2.DOWN
	# Under load a crowded rally can test dozens of full A* routes in one call.
	# Continue from the next candidate on the ordinary assembly retry.
	var limited: bool = world.frame_pacing != null and world.frame_pacing.tier >= 2
	var resume: int = int(unit.special.get("ai_assembly_cursor",0)) if limited else 0
	var index := 0
	var probes := 0
	for ring in range(SEARCH_RINGS + 1):
		var count := maxi(1, ring * 6)
		for i in count:
			index += 1
			if index <= resume: continue
			var point: Vector2 = center + approach.rotated(TAU * i / count) * ring * spacing
			if point.x < unit.radius or point.y < unit.radius or point.x >= world.map_size - unit.radius or point.y >= world.map_size - unit.radius: continue
			if not unit.is_air:
				if yards.any(func(rect): return rect.has_point(point)): continue
				if not parking_clear(nav, point, unit): continue
				if nav.nearest_reachable(point, unit.position, false, 0, unit.is_amphibious) != point: continue
			if occupied.any(func(slot): return point.distance_squared_to(Vector2(slot.x, slot.y)) < slot.z * slot.z - 0.01): continue
			if limited and probes >= 3:
				unit.order_stop()
				unit.special.erase("ai_assembly_point")
				unit.special.ai_assembly_cursor = index - 1
				unit.special.ai_assembly_retry = true
				return
			probes += 1
			var path: PackedVector2Array = world.path_for_unit(unit, point)
			if not unit.is_air and (path.size() < 2 or path[-1].distance_to(point) > Unit.ARRIVE_EPS): continue
			unit.order_move(point, false, null, path)
			unit.special.erase("ai_assembly_cursor")
			unit.special.ai_assembly_point = point
			unit.special.ai_assembly_epoch = nav.epoch
			unit.special.erase("ai_assembly_retry")
			unit.special.erase("ai_defense_goal")
			return
	unit.order_stop()
	unit.special.erase("ai_assembly_cursor")
	unit.special.erase("ai_assembly_point")
	unit.special.ai_assembly_retry = true

static func parking_clear(nav, point: Vector2, unit) -> bool:
	for direction: Vector2 in [Vector2.ZERO, Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		if nav.is_blocked(point + direction * unit.radius, false, unit.is_amphibious): return false
	return true

static func production_lanes(world, unit) -> Array[Rect2]:
	var lanes: Array[Rect2] = []
	if unit.is_air: return lanes
	for building in world.buildings:
		if not world.actor_alive(building) or building.side != unit.side: continue
		if building.buildable.is_empty() and not building.is_refinery(): continue
		var footprint: Rect2 = building.footprint_rect()
		footprint.position += building.position
		lanes.append(footprint.grow(unit.radius + world.path_service.cell + 60.0))
	return lanes

static func needs_new_slot(ai, unit) -> bool:
	if unit.attack_move or unit.attack_ordered or not unit.order_queue.is_empty() or unit.special.has("action"): return false
	if unit.special.has("ai_assembly_retry"): return true
	var goal: Vector2 = unit.special.get("ai_assembly_point", Vector2.INF)
	if not goal.is_finite():
		# Old saves issued one shared rally destination.
		return not unit.has_move_order or unit.move_target.is_equal_approx(ai.rally)
	if unit.has_move_order and not unit.move_target.is_equal_approx(goal): return false
	var nav = ai.battle.path_service
	if unit.special.get("ai_assembly_epoch", -1) == nav.epoch: return false
	unit.special.ai_assembly_epoch = nav.epoch
	if unit.is_air: return false
	return not parking_clear(nav, goal, unit) or production_lanes(ai.battle, unit).any(func(lane): return lane.has_point(goal))

static func ready(unit, rally: Vector2) -> bool:
	if unit.special.has("ai_assembly_retry"): return false
	if unit.position.distance_to(rally) <= 300.0: return true
	var slot: Vector2 = unit.special.get("ai_assembly_point", Vector2.INF)
	return slot.is_finite() and unit.position.distance_to(slot) <= unit.radius + Unit.ARRIVE_EPS

## Same formation spacing and terrain-aware slot assignment used by player
## movement, without changing the player's selection, markers or voices.
static func advance(ai, units: Array, target: Vector2) -> void:
	if units.is_empty(): return
	var origin := Vector2.ZERO
	for unit in units: origin += unit.position
	var slots := Formations.layout(units.size(), target, (origin / units.size()).direction_to(target), "line", ai.battle._formation_spacing(units))
	var assigned: Dictionary = ai.battle._assign_move_slots(units, slots, target,true)
	var batch := 0
	if units.size()>1:
		batch = int(ai.battle.allied_state.get("ai_formation_sequence",0))+1
		ai.battle.allied_state.ai_formation_sequence = batch
	var spacing: float = ai.battle._formation_spacing(units)
	for unit in assigned:
		ai.battle.ai_dispatch.submit(ai.battle,unit,{"kind":"advance","point":assigned[unit],"batch":batch,"spacing":spacing})
