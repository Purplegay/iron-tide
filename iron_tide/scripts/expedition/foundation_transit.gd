extends RefCounted
## Ground movement orders can cross allied foundations in an expedition.
const Rules = preload("res://scripts/expedition/rules.gd")
const ANCHOR := "expedition_foundation_entry"

static func enabled(unit) -> bool:
	return unit.side == "ally" and not unit.is_air and not unit.is_naval and Rules.active()

static func parkable(unit, world, point: Vector2, margin: float) -> bool:
	var service = world.path_service
	if service.is_blocked(point, false, unit.is_amphibious): return false
	return service.passages.clear(service, point, point + Vector2(0.01, 0), unit.radius + margin, [])

static func destination(unit, world, goal: Vector2) -> Vector2:
	if parkable(unit, world, goal, unit.ARRIVE_EPS): return goal
	# Only adjust building destinations. Shore and bridge orders use normal routing.
	var near_friend := false
	for building in world.buildings:
		if world.actor_alive(building) and BattleRequest.friendly(unit.side, building.side) and goal.distance_to(building.closest_footprint_point(goal)) <= unit.radius + unit.ARRIVE_EPS:
			near_friend = true
			break
	if not near_friend: return goal
	var direction: Vector2 = goal.direction_to(unit.position)
	if direction == Vector2.ZERO: direction = Vector2.RIGHT
	for ring in range(1, 33):
		for index in 16:
			var point: Vector2 = goal + direction.rotated(index * TAU / 16) * ring * world.path_service.cell
			if parkable(unit, world, point, unit.ARRIVE_EPS): return point
	return unit.position

static func crosses(unit, world, goal: Vector2, stationary: Array) -> bool:
	var service = world.path_service
	var start: Vector2 = unit.position
	if not service.line_walkable(start, goal, service.passages.terrain) or not service._segment_clear_of_units(start, goal, stationary): return false
	var crossing := false
	var sweep := Rect2(start, goal - start).abs().grow(unit.radius)
	for shape in service.passages.shapes:
		var rect: Rect2 = shape.bounds.grow(unit.radius)
		if not sweep.intersects(shape.bounds, true): continue
		if not intersects(rect, start, goal): continue
		var friendly := false
		for building in world.buildings:
			if world.actor_alive(building) and building.position == shape.position and BattleRequest.friendly(unit.side, building.side) and not shape.poly.is_empty():
				friendly = true
				break
		if not friendly: return false
		crossing = true
	return crossing and parkable(unit, world, goal, unit.ARRIVE_EPS)

static func settle(unit) -> void:
	var world = unit._navigation_world()
	if world == null or world.path_service == null: return
	if not parkable(unit, world, unit.position, 0):
		var point: Vector2 = unit.special[ANCHOR]
		if not parkable(unit, world, point, 0): point = destination(unit, world, unit.position)
		if not parkable(unit, world, point, 0): return
		unit.position = point
		unit.reset_physics_interpolation()
	unit.special.erase(ANCHOR)

static func intersects(rect: Rect2, start: Vector2, goal: Vector2) -> bool:
	if rect.has_point(start) or rect.has_point(goal): return true
	var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	for i in 4:
		if Geometry2D.segment_intersects_segment(start, goal, corners[i], corners[(i+1)%4]) != null: return true
	return false
static func buildings(unit,motion:Vector2,existing:Array) -> Array:
	var result:Array=[]
	var world=unit._navigation_world()
	if world==null:return result
	var sweep:=Rect2(unit.position,motion).abs().grow(unit.radius+4.0)
	for building in world.buildings:
		if not world.actor_alive(building) or not BattleRequest.friendly(unit.side,building.side) or existing.has(building):continue
		if not sweep.intersects(Placement.aabb(building.footprint_poly(),building.position),true):continue
		if parkable(unit,world,unit.position,0):unit.special[ANCHOR]=unit.position
		elif not unit.special.has(ANCHOR):
			var safe:=destination(unit,world,unit.position)
			if parkable(unit,world,safe,0):unit.special[ANCHOR]=safe
		unit.add_collision_exception_with(building)
		result.append(building)
	return result