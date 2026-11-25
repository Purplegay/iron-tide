extends RefCounted
## The midfield landmark is map geography. Ownership and defenders require current sight.
const Ops = preload("res://scripts/world/skirmish_operations.gd")
const LIGHT := ["DOG", "SOV_DOG", "FV", "HTK", "E1", "E2", "MTNK", "HTNK", "GGI", "FLAKT"]
const Garrison = preload("res://scripts/units/civilian_orders.gd")

static func midfield(world) -> Vector2:
	if world.allied_state.has("oil_mid_point"): return world.allied_state.oil_mid_point
	# v0.18.3 saves predate the explicit landmark. Use the original placement band.
	var anchor: Vector2 = Vector2(0.30, 0.46) * world.map_size
	for b in world.buildings:
		if world.actor_alive(b) and b.building_id == "CAOILD" and b.position.distance_to(anchor) < world.map_size * 0.16:
			world.allied_state.oil_mid_point = b.position
			return b.position
	return Vector2.INF

static func move_near(unit, point: Vector2, guard: bool) -> void:
	if unit.position.distance_to(point) < 65:
		if guard and not unit.hold_position: unit.ai_order("guard")
		elif not guard and unit.has_move_order: unit.ai_order("stop")
	elif not unit.has_move_order or unit.move_target.distance_to(point) > 45:
		unit.ai_order("move",point, false)

static func defenders(ai, point: Vector2) -> Array:
	var threats := []
	for actor in Ops.targets(ai):
		var reach := 0.0
		if actor is Building and Garrison.has_gunner(actor):
			reach = Garrison.bunker_range(actor)
		else:
			if actor is Building and (not actor.is_operational() or not actor._ground_targeting_allowed): continue
			var weapon: Dictionary = actor._weapon_for_target(null) if actor is Unit else actor.weapon
			if weapon.is_empty() or not bool(weapon.get("ra2_ag", true)) or float(weapon.get("damage", 0)) <= 0: continue
			reach = float(weapon.get("range", 0))
		if actor.position.distance_to(point) <= maxf(280, reach + 80):
			threats.append(actor)
	return threats

static func team(ai, point: Vector2, wanted: int, scout: bool) -> Array:
	var squad := []
	var candidates := []
	for u in ai.battle.units:
		if not ai.battle.actor_alive(u) or u.side != ai.house_id: continue
		if u.special.has("ai_oil_post"):
			if squad.size() < wanted and u.embarked_in == null and not u.repairing:
				squad.append(u)
			else:
				u.special.erase("ai_oil_post")
				if u.embarked_in == null and not u.repairing: u.ai_order("move",ai.rally, false)
		elif u.unit_id in LIGHT and u.embarked_in == null and not u.repairing and not u.attack_ordered and not u.is_deployed() and not u.special.has("action") and not u.special.get("ai_transport_reserved", false):
			candidates.append(u)
	candidates.sort_custom(func(a, b):
		var a_dog: bool = scout and "DOG" in str(a.unit_id)
		var b_dog: bool = scout and "DOG" in str(b.unit_id)
		if a_dog != b_dog: return a_dog
		return a.position.distance_squared_to(point) < b.position.distance_squared_to(point))
	for u in candidates:
		if squad.size() >= wanted: break
		u.special.ai_oil_post = true
		ai._army.erase(u)
		squad.append(u)
	return squad

static func manage(ai, point: Vector2, site, threats: Array, train_scout: bool) -> void:
	var world = ai.battle
	var visible: bool = world.position_visible_to(ai.house_id, point)
	if visible and site == null:
		team(ai, point, 0, false)
		return
	var squad := team(ai, point, 1 if threats.is_empty() else 2, not visible)
	var post: Vector2 = point.move_toward(ai.rally, 125)
	if not visible and squad.is_empty() and train_scout:
		var dog := "SOV_DOG" if ai.enemy_base == "soviet" else "DOG"
		if Ops.count(ai, dog) == 0 and ai.funds - preload("res://scripts/world/skirmish_tactics.gd").committed(world,ai.house_id) >= preload("res://scripts/world/skirmish_economy.gd").reserve(ai) + world.production_price(GameData.get_unit(dog), ai.house_id):
			Ops.enqueue(ai, dog)
	for i in squad.size():
		var unit = squad[i]
		var target = null
		for threat in threats:
			if unit.attack_domain_valid(threat) and (target == null or unit.position.distance_squared_to(threat.position) < unit.position.distance_squared_to(target.position)):
				target = threat
		if target != null: Ops.order_attack(unit, target)
		else: move_near(unit, post + Vector2(0, i * 60), true)
