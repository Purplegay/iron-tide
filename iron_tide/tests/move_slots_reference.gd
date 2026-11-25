extends Battle
func original_assign_move_slots(units: Array, slots: Array, center: Vector2, defer_routes := false) -> Dictionary:
	var res: Dictionary = {}
	if slots.is_empty():
		for u in units:
			res[u] = center
		return res
	var pool: Array = slots.duplicate()
	var order: Array = units.duplicate()
	order.sort_custom(func(a, b):
		return a.global_position.distance_squared_to(center) < b.global_position.distance_squared_to(center))
	var used: Array[Vector2] = []
	var spacing := _formation_spacing(units)
	var origin := Vector2.ZERO
	for actor in units:
		origin += actor.global_position
	origin /= maxf(1.0, units.size())
	var forward := (center - origin).normalized()
	var marching := origin.distance_to(center) > spacing * sqrt(float(units.size()))
	for u in order:
		var wm: bool = u.get("is_naval") == true
		var air: bool = u.get("is_air") == true
		var best := -1
		var best_d := INF
		var best_depth := -INF
		for i in range(pool.size()):
			var s: Vector2 = pool[i]
			if not air and path_service != null and path_service.is_blocked(s, wm, u.is_amphibious, u.unit_id=="R3APOC"):
				continue
			var d: float = u.global_position.distance_squared_to(s)
			var depth := (s - center).dot(forward)
			# Front units occupy front rows, so early arrivals do not park
			# across the route of the rest of the formation. Within a row,
			# retain the nearest slot to avoid lateral crossings.
			var better := d < best_d
			if marching:
				better = depth > best_depth + spacing * 0.25 or (absf(depth - best_depth) <= spacing * 0.25 and d < best_d)
			if better:
				best_d = d
				best_depth = depth
				best = i
		if best < 0:
			best = 0
		var slot: Vector2 = pool[best]
		pool.remove_at(best)
		if not defer_routes and not air and path_service != null:
			slot = resolve_move_slot(u,slot,used,spacing)
			used.append(slot)
		res[u] = slot
	return res
