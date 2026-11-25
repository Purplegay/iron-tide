extends RefCounted
const IDS := ["GHOST", "TANY", "CCOMAND", "PTROOP"]
static func handles(unit: Unit) -> bool:
	return unit.unit_id in IDS

static func contact_point(unit: Unit, target) -> Vector2:
	var center: Vector2 = target.global_position
	var origin: Vector2 = unit.global_position
	if target is Building:
		return target.closest_footprint_point(origin)
	if target is Unit and unit.unit_id == "DTRUCK":
		return center.move_toward(origin, target.radius)
	return center

static func distance_to(unit: Unit, target) -> float:
	if not unit.is_air and not unit.is_naval:
		return unit.global_position.distance_to(contact_point(unit, target))
	var distance: float = unit.global_position.distance_to(target.global_position)
	if target is Building and (handles(unit) or (unit.unit_id in ["IVAN", "CIVAN"] and target.special.has("bridge_span"))):
		distance -= target.footprint_clearance(target.global_position.direction_to(unit.global_position))
	return maxf(0.0, distance)

