extends RefCounted
## Physical short leap. The hit occurs at contact, never at take-off.
const LEAP_SECONDS := 0.35
const MAX_DETOUR_SECONDS := 0.30
static func start(unit, target, weapon: Dictionary) -> bool:
	if unit.unit_id == "DRON":
		if not preload("res://scripts/units/soviet_advanced.gd").can_infest(target): return false
	elif unit.unit_id not in ["DOG", "ADOG", "SOV_DOG"] or not AlliedAbilities.infantry(target) or target.is_air_target(): return false
	unit.special.pounce = {"target": target, "origin": unit.position, "elapsed": 0.0, "duration": LEAP_SECONDS, "weapon": weapon.duplicate(true)}
	return true

static func tick(unit, delta: float) -> bool:
	if not unit.special.has("pounce"): return false
	var state: Dictionary = unit.special.pounce
	var target = state.target
	if not AlliedAbilities.alive(target) or target.embarked_in != null or BattleRequest.friendly(target.side,unit.side) or AlliedAbilities.frozen(unit) or unit._stun_timer > 0:
		unit.special.erase("pounce")
		return false
	state.elapsed += delta
	unit._cd_timer -= delta
	unit._anim += delta
	unit._face(target.position)
	var distance: float = unit.position.distance_to(target.position)
	var contact: float = unit.radius + target.radius + 2.0
	var step := minf(maxf(0, distance - contact + 1.0), maxf(float(state.get("hunt_speed",unit.move_speed * 2.0)), 200.0) * delta)
	var motion: Vector2 = unit.position.direction_to(target.position) * step
	if step > 0.0 and unit._domain_ok(unit.position + motion):
		var hit: KinematicCollision2D = unit.move_with_traffic_exceptions(motion)
		if hit != null and unit.unit_id != "DRON" and hit.get_collider() is Unit and hit.get_collider() != target:
			# Keep bodies solid. Spend the unused movement along the blocking unit's flank.
			var tangent := hit.get_normal().orthogonal()
			if tangent.dot(motion) < 0.0: tangent = -tangent
			var sidestep := tangent * hit.get_remainder().length()
			if unit._domain_ok(unit.position + sidestep):
				var before: Vector2 = unit.position
				unit.move_with_traffic_exceptions(sidestep)
				var extra_time := delta * before.distance_to(unit.position) / step
				state.duration = minf(LEAP_SECONDS + MAX_DETOUR_SECONDS, state.duration + extra_time)
	unit.velocity = Vector2.ZERO
	if unit.position.distance_to(target.position) <= contact:
		var weapon: Dictionary = state.weapon
		var damage := CombatMath.full_damage(weapon, target.armor, unit.bonuses, null, target.ra2_armor, 0.0, target)
		unit.special.erase("pounce")
		if unit.unit_id == "DRON":
			if state.has("hunt_from") and not preload("res://scripts/units/expansion_2_drone.gd").legal(unit,target):return true
			preload("res://scripts/units/soviet_advanced.gd").contact(unit, target)
			unit.queue_redraw()
			return true
		target.receive_hit(damage, "melee", unit.bonuses, unit, str(weapon.get("ra2_warhead", "")))
	elif state.elapsed >= state.duration:
		unit.special.erase("pounce") # Blocked/moving target: no remote hit or teleport.
	unit.queue_redraw()
	return true

static func lift(unit) -> float:
	var state: Dictionary = unit.special.get("pounce", {})
	if state.is_empty(): return 0.0
	return sin(PI * clampf(state.elapsed / state.duration, 0.0, 1.0)) * 16.0
