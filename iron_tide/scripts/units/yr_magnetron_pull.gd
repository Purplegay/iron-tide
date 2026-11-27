extends RefCounted

const KEY := "magnet_lift"
const HEIGHT_PIXEL := preload("res://scripts/units/unit_flight.gd").HEIGHT_PIXEL
const RATE := BattleClock.RULE_TICKS_PER_SECOND
const CELL := Ra2Damage.PX_PER_CELL
# Retail LocomotorBeam requests Jumpjet locomotion; these are the rulesmd [JumpjetControls] defaults.
const HEIGHT := 500.0 * HEIGHT_PIXEL
const CLIMB := 5.0 * HEIGHT_PIXEL * RATE
const SPEED := 14.0 * CELL / 256.0 * RATE
const ACCEL := 2.0 * CELL / 256.0 * RATE * RATE
const DROP_ACCEL := 6.0 * HEIGHT_PIXEL * RATE * RATE

static func airborne(unit) -> bool:
	return unit.special.has(KEY) and float(unit.special[KEY].height) > 0.01

static func start(source, target, gun: Dictionary) -> void:
	if target.special.has(KEY): return
	target.special.erase("magnet_seconds")
	target.special.magnet_source = source
	target.special[KEY] = {"height": 0.0, "speed": 0.0, "fall_speed": 0.0, "origin": target.global_position,
		"range": float(gun.get("range", 12.0 * CELL)), "layer": target.collision_layer, "mask": target.collision_mask}

static func landing_clear(unit, world, at: Vector2) -> bool:
	if not Rect2(Vector2.ZERO, Vector2.ONE * world.map_size).has_point(at): return false
	if not unit._domain_ok(at) or world.path_service.is_blocked(at, unit.is_naval, unit.is_amphibious): return false
	for other in world.neighborhood.nearby(at, unit.radius + 85.0, true):
		if not world.actor_alive(other) or other == unit or not other.ground_contact_eligible(): continue
		if at.distance_squared_to(other.global_position) < pow(unit.radius + other.radius, 2.0): return false
	return true

static func landing_point(unit, world, origin: Vector2) -> Vector2:
	var at: Vector2 = unit.global_position
	if landing_clear(unit, world, at): return at
	# Check nearby ground before using the last launch point as a fallback.
	for ring in range(1, 9):
		for direction in 8:
			var probe := at + Vector2.from_angle(direction * TAU / 8.0) * ring * CELL * 0.5
			if landing_clear(unit, world, probe): return probe
	return origin if landing_clear(unit, world, origin) else Vector2.INF

static func tick(unit, delta: float) -> void:
	var world = unit._battle_world()
	if world == null or world.paused or world.ended: return
	var state: Dictionary = unit.special[KEY]
	var source = unit.special.get("magnet_source")
	var linked: bool = AlliedAbilities.alive(source) and source.attack_target == unit and source.embarked_in == null \
		and not source.special.has(KEY) and source._stun_timer <= 0.0 and not AlliedAbilities.frozen(source) \
		and not BattleRequest.friendly(source.side, unit.side) \
		and source.global_position.distance_squared_to(unit.global_position) <= pow(float(state.range) * 1.1, 2.0)
	unit.velocity = Vector2.ZERO
	unit._stun_timer = maxf(unit._stun_timer, delta * 2.0)
	unit.auto_harvest_idle = 0.0
	if linked:
		# Lift first; only the suspended vehicle is dragged horizontally.
		if float(state.height) < HEIGHT:
			state.height = move_toward(float(state.height), HEIGHT, CLIMB * delta)
		else:
			var separation: float = unit.radius + source.radius + 8.0
			var remaining: float = unit.global_position.distance_to(source.global_position) - separation
			if remaining <= 0.5:
				unit.special.erase("magnet_source")
			else:
				state.speed = move_toward(float(state.speed), SPEED, ACCEL * delta)
				var before: Vector2 = unit.global_position
				unit.global_position = before.move_toward(source.global_position, minf(remaining, float(state.speed) * delta))
				# Preserve the existing high-bridge contact layer rather than carrying a deck flag off the deck.
				if unit.special.has("hollywood_on_deck") and world.ground is Ground and world.ground.overpass != null:
					world.ground.overpass.record_move(unit, before)
					if unit.global_position.is_equal_approx(before): unit.special.erase("magnet_source")
	else:
		unit.special.erase("magnet_source")
		state.fall_speed = float(state.fall_speed) + DROP_ACCEL * delta
		state.height = maxf(0.0, float(state.height) - float(state.fall_speed) * delta)
		if float(state.height) <= 0.0:
			var at := landing_point(unit, world, state.origin)
			if at.is_finite():
				unit.global_position = at
				unit.collision_layer = int(state.layer)
				unit.collision_mask = int(state.mask)
				unit.special.erase(KEY)
			else:
				# No legal touchdown (e.g. deep water): don't leave a stuck airborne unit.
				unit.special.erase(KEY)
				unit.hp = 0.0
				unit._die()
				return
	if airborne(unit):
		unit.collision_layer = 0
		unit.collision_mask = 0
	unit._anim += delta
	unit._tick_buffs(delta)
	unit.decorate_tick(delta)
	unit._request_pose_redraw()
