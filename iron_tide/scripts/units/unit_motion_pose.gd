extends RefCounted
## Presentation samples only. Never feed interpolated coordinates into combat.
var previous_hull := 0.0
var previous_turret := 0.0
var previous_position := Vector2.ZERO
var last_position := Vector2.ZERO

func capture(unit: Unit) -> void:
	previous_hull = unit.hull_angle
	previous_turret = unit.turret_angle
	previous_position = unit.global_position
	last_position = previous_position

func fraction(unit: Unit) -> float:
	if not unit.is_inside_tree() or not unit.is_physics_interpolated_and_enabled() or unit.get_tree().paused: return 1.0
	return clampf(Engine.get_physics_interpolation_fraction(), 0.0, 1.0)

func hull(unit: Unit, blend: float) -> float:
	return lerp_angle(previous_hull, unit.hull_angle, blend)

func turret(unit: Unit, blend: float) -> float:
	return lerp_angle(previous_turret, unit.turret_angle, blend)

func point(unit: Unit, blend: float) -> Vector2:
	return previous_position.lerp(unit.global_position, blend)

func turning(unit: Unit) -> bool:
	return absf(angle_difference(previous_hull, unit.hull_angle)) > 0.00001 or absf(angle_difference(previous_turret, unit.turret_angle)) > 0.00001

func moved(unit: Unit) -> void:
	var distance := last_position.distance_squared_to(unit.global_position)
	last_position = unit.global_position
	var limit := maxf(64.0, unit.move_speed * unit.get_physics_process_delta_time() * 3.0)
	if not Engine.is_in_physics_frame() or distance > limit * limit:
		unit.reset_physics_interpolation()
