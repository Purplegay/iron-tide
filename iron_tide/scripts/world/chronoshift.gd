extends RefCounted
## 3x3 original-cell area, continuous positions preserved inside the footprint.
const CELL := 55.0

static func actors(world, point: Vector2, observer: String) -> Array:
	return world.units.filter(func(u):
		return world.actor_alive(u) and not u.is_air and u.embarked_in == null \
			and world.actor_visible_to(observer, u) and absf(u.position.x - point.x) <= CELL * 1.5 \
			and absf(u.position.y - point.y) <= CELL * 1.5 and not AlliedAbilities.frozen(u))

static func landing_clear(world, unit, point: Vector2, transported: Array) -> bool:
	for i in 9:
		var edge: Vector2 = point if i == 0 else point + Vector2.from_angle((i - 1) * TAU / 8.0) * unit.radius
		if edge.x < 0 or edge.y < 0 or edge.x >= world.map_size or edge.y >= world.map_size or not unit._domain_ok(edge): return false
	for other in world.buildings:
		if world.actor_alive(other) and Placement.circle_hits_poly(other.footprint_poly(), point, unit.radius, other.position): return false
	for other in world.units:
		if other not in transported and world.actor_alive(other) and not other.is_air and other.embarked_in == null and point.distance_to(other.position) < unit.radius + other.radius: return false
	for obstacle in world.get_tree().get_nodes_in_group("obstacles"):
		if point.distance_to(obstacle.position) < unit.radius + obstacle.radius: return false
	return true

static func move(building, destination: Vector2, origin := Vector2.INF) -> bool:
	var world = building.battle
	if world == null or not destination.is_finite(): return false
	if not origin.is_finite(): origin = world._chrono_source_point
	if not origin.is_finite(): return false
	if destination.x < 0 or destination.y < 0 or destination.x >= world.map_size or destination.y >= world.map_size: return false
	if not world.position_explored_by(building.side, destination): return false
	var selected := actors(world, origin, building.side)
	if selected.is_empty(): return false
	# Compute all outcomes before mutating positions. Dangerous terrain consumes
	# the charge and destroys affected units; it is not a free placement probe.
	var outcomes := []
	for unit in selected:
		var point: Vector2 = destination + unit.position - origin
		var organic: bool = AlliedAbilities.infantry(unit) or AlliedAbilities.flag(unit, "Organic")
		var dies: bool = organic and not AlliedAbilities.flag(unit, "Teleporter")
		outcomes.append({"point": point, "dies": dies or not landing_clear(world, unit, point, selected), "organic": dies})
	Ra2Fx.play(world.effects_root, origin, "CHRONOFD")
	Ra2Fx.play(world.effects_root, destination, "CHRONOTG")
	for i in selected.size():
		var unit = selected[i]
		var outcome: Dictionary = outcomes[i]
		if unit.special.has("squid"): preload("res://scripts/units/soviet_specials.gd").release_squid(unit, true)
		unit.order_stop()
		for key in ["repair_exit_depot", "repair_exit_point", "repair_entry", "repair_stage"]: unit.special.erase(key)
		if not outcome.organic:
			unit.position = outcome.point
			unit.reset_physics_interpolation()
		if outcome.dies:
			unit.hp = 0.0
			unit._die(building, outcome.organic)
			continue
		unit.velocity = Vector2.ZERO
		unit._last_water_pos = outcome.point
		unit._clear_field()
		unit._stun_timer = maxf(unit._stun_timer, SupportSystems.general("ChronoDelay", 60.0) / 15.0)
		for passenger in unit.logistics.passengers:
			if world.actor_alive(passenger): passenger.position = unit.position
		unit.queue_redraw()
	if world.fog != null: world.fog.rebuild()
	Ra2Sfx.play("ChronoMinerTeleport", destination)
	return true
