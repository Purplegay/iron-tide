extends RefCounted
## Cache static docking corridors by foundation revision and vehicle radius.
## Dynamic vehicles never invalidate the cache or become permanent obstacles.
static func entries(unit, depot) -> Array:
	var world = depot.battle
	var key := Vector2i(world.path_service.epoch, ceili(unit.radius))
	var cache: Dictionary = depot.get_meta("repair_access", {})
	if cache.get("epoch", -1) != world.path_service.epoch:
		cache = {"epoch":world.path_service.epoch, "radii":{}}
		depot.set_meta("repair_access", cache)
	if cache.radii.has(key.y): return cache.radii[key.y]
	var result: Array = []
	if depot.data.get("water_bound", false):
		var berth: Vector2 = depot.dock_point(unit.position)
		if berth.is_finite(): result.append(berth)
	else:
		for i in 16:
			var direction := Vector2.from_angle(TAU * i / 16.0)
			var point: Vector2 = depot.position + direction * (depot.footprint_clearance(direction) + unit.radius + 40.0)
			if clear(unit, depot, point, RepairDock.pad(depot)): result.append(point)
	cache.radii[key.y] = result
	return result

static func clear(unit, depot, start: Vector2, finish: Vector2) -> bool:
	var mask: int = unit.collision_mask
	var already: bool = unit.get_collision_exceptions().has(depot)
	unit.collision_mask = 2 | 4
	if not already: unit.add_collision_exception_with(depot)
	var blocked: bool = unit.test_move(Transform2D(0.0, start), finish-start, null, 0.08, true)
	if not already: unit.remove_collision_exception_with(depot)
	unit.collision_mask = mask
	return not blocked

static func nearest(unit, depot) -> Vector2:
	var failed: Dictionary = unit.get_meta("repair_unreachable", {})
	if failed.get("depot") == depot and failed.get("epoch") == depot.battle.path_service.epoch and float(failed.get("until",0.0)) > unit._anim: return Vector2.INF
	var result := Vector2.INF
	var distance := INF
	for point: Vector2 in entries(unit, depot):
		var candidate: float = unit.position.distance_squared_to(point)
		if clear(unit,depot,unit.position,point): candidate *= 0.25
		if candidate < distance:
			distance = candidate
			result = point
	return result

static func waiting(unit, depot, entry: Vector2, rank: int) -> Vector2:
	# Distinct, stable slots; no broad A* calls while parked in a queue.
	var key := Vector3i(depot.battle.path_service.epoch, rank, ceili(unit.radius))
	var previous: Dictionary = unit.get_meta("repair_wait_slot", {})
	if previous.get("key") == key and previous.get("entry") == entry: return previous.point
	var outward: Vector2 = depot.position.direction_to(entry)
	var spacing: float = maxf(72.0, unit.radius*2.0+20.0)
	var slot := Vector2.INF
	for attempt in 32:
		var index := rank + attempt
		var point := entry + outward * (spacing * (2 + index/4)) + outward.orthogonal() * spacing * (1 + index%4)
		if depot.battle.path_service.is_blocked(point, unit.is_naval): continue
		var reserved := false
		for other in RepairDock.candidates(depot.battle):
			if other == unit or not depot.battle.actor_alive(other) or other.repair_depot != depot: continue
			var occupied: Dictionary = other.get_meta("repair_wait_slot", {})
			if occupied.has("point") and point.distance_to(occupied.point) < unit.radius + other.radius + 12.0:
				reserved = true
				break
		if not reserved and clear(unit, depot, point, point):
			slot = point
			break
	if not slot.is_finite(): slot = unit.position
	unit.set_meta("repair_wait_slot", {"key":key, "entry":entry, "point":slot})
	return slot

static func local_route(unit, depot, goal: Vector2) -> PackedVector2Array:
	var points: Array[Vector2] = []
	var start: Vector2 = unit.position
	var nav = depot.battle.path_service
	# Bounded geometry escape for the last approach. This does not stamp or
	# rebuild the global navigation grid, and never removes other collisions.
	for body in depot.battle.neighborhood.nearby(start,240.0):
		if not body is Building or body == depot or not depot.battle.actor_alive(body): continue
		var polygons = Geometry2D.offset_polygon(body.footprint_poly(),unit.radius+10.0)
		for poly in polygons:
			for vertex: Vector2 in poly:
				var point: Vector2 = body.position+vertex
				if start.distance_to(point)>300.0 or points.size()>=48: continue
				if not nav.line_walkable(start,point,nav.passages.terrain): continue
				points.append(point)
	var starts: Array[Vector2] = []
	var ends: Array[Vector2] = []
	var result := PackedVector2Array()
	var best := INF
	for point in points:
		var from_start := clear(unit,depot,start,point)
		var to_goal: bool = clear(unit,depot,point,goal) and nav.line_walkable(point,goal,nav.passages.terrain)
		if from_start: starts.append(point)
		if to_goal: ends.append(point)
		var length: float = start.distance_to(point)+point.distance_to(goal)
		if from_start and to_goal and length<best:
			best=length
			result=PackedVector2Array([point,goal])
	if not result.is_empty(): return result
	for first in starts:
		for last in ends:
			var length: float=start.distance_to(first)+first.distance_to(last)+last.distance_to(goal)
			if length<best and clear(unit,depot,first,last) and nav.line_walkable(first,last,nav.passages.terrain):
				best=length
				result=PackedVector2Array([first,last,goal])
	return result
