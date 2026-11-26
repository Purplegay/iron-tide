extends RefCounted
## Wider rolling turns only with a clear swept corridor. Crowds/docking keep tight pivots.
# A U-turn starts with a pivot, then eases into forward travel along the hull.
# Keep this phase through the bend so crossing 90 degrees never brakes the tank again.
const REVERSAL := "drive_reversal"

static func pivot_angle(unit: Unit, wanted: float, error: float) -> float:
	if error <= deg_to_rad(20.0):
		unit.special.erase(REVERSAL)
		return 35.0
	if not unit.is_naval and unit.has_move_order and error >= deg_to_rad(145.0):
		unit.special[REVERSAL] = true
	var open_angle := 125.0 if unit.special.has(REVERSAL) and unit.has_move_order else 65.0
	if error < deg_to_rad(open_angle) and open_corridor(unit, wanted):
		return open_angle
	return 35.0

static func open_corridor(unit: Unit, wanted: float) -> bool:
	var reach := maxf(100.0, unit.move_speed * 0.8)
	if not unit.has_move_order or unit.position.distance_to(unit.move_target) <= maxf(160.0, reach * 1.5): return false
	# Other consumers may run before separation or after a reset in this step.
	unit._local_traffic.ensure_candidates(unit)
	if unit._local_traffic.query_origin.distance_to(unit.global_position) > 24.0: return false
	for other in unit._local_traffic.nearby:
		if not is_instance_valid(other) or other.is_queued_for_deletion() or not other is Node2D: continue
		if other is CollisionObject2D and (other.collision_layer & (8 if unit.is_air else 1)) == 0: continue
		var radius = other.get("radius")
		var clearance: float = unit.radius + (float(radius) if radius != null else 40.0) + reach
		if unit.global_position.distance_to(other.global_position) < clearance: return false
	var world := unit._navigation_world()
	if world == null or world.path_service == null: return false
	var service := world.path_service
	var grid: PackedFloat32Array = service.amphibious_cost if unit.is_amphibious else (service.water_cost if unit.is_naval else service.cost)
	if grid.is_empty(): return false
	var half_turn: float = unit._hull_prev + angle_difference(unit._hull_prev, wanted) * 0.5
	for angle in [unit._hull_prev, half_turn, wanted]:
		var forward := Vector2.from_angle(angle)
		var right: Vector2 = forward.orthogonal() * unit.radius
		for offset in [Vector2.ZERO, right, -right]:
			var start: Vector2 = unit.global_position + offset
			var end := start + forward * reach
			if end.x < 0 or end.y < 0 or end.x >= world.map_size or end.y >= world.map_size: return false
			if not service.line_walkable(start, end, grid): return false
	return true
