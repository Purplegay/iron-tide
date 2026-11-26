extends "res://scripts/units/local_traffic.gd"
# Frozen seconds-based reference owns its retired field independently.
var query_left := 0.0

func reset() -> void:
	super.reset()
	query_left = 0.0

func original_apply(unit:Unit, delta: float) -> void:
	var _call_log_scope = preload("res://scripts/world/battle_call_counters.gd").enter(26)
	# Ground infantry passes every friendly ground body; enemies and other
	# domains never receive separation. Its consumers do not use vehicle steering.
	if not unit.is_air and not unit.is_naval and AlliedAbilities.infantry(unit):
		query_left = 0.0
		query_origin = Vector2.INF
		nearby.clear()
		return
	query_left -= delta
	var speed: float = unit.velocity.length()
	var forward: Vector2 = unit.velocity.normalized()
	var remaining: float = unit.global_position.distance_to(unit.move_target)
	var look := minf(maxf(60.0, speed * 0.8), remaining)
	# Cache only candidate membership for 0.1 s; positions/states are read live.
	# The extra margin covers newcomers between refreshes; teleports/orders reset it.
	if query_left <= 0.0 or query_origin.distance_to(unit.global_position) > 24.0:
		var radius := unit.radius + 60.0 + maxf(60.0, unit.move_speed * 0.8) + 64.0
		var mask := 8 if unit.is_air else 1
		var world := unit._navigation_world() as Battle
		nearby.clear()
		var query_position := unit.global_position
		if world != null and world.units.size() >= 96:
			# Occupancy follows transforms, including teleports. Test current layer
			# and circle extents before retaining candidates for the next tick.
			for candidate in world.neighborhood.nearby(query_position, radius + world.neighborhood.max_unit_radius, true):
				if not is_instance_valid(candidate) or not candidate is Unit: continue
				var actor: Unit = candidate
				if actor == unit or (actor.collision_layer & mask) == 0:
					continue
				var distance: float = radius + actor.radius
				if query_position.distance_squared_to(actor.global_position) <= distance * distance:
					nearby.append(actor)
		else:
			shape.radius = radius
			query.shape = shape
			query.transform = Transform2D(0.0, unit.global_position)
			query.collision_mask = mask
			query.exclude = [unit.get_rid()]
			for hit in unit.get_world_2d().direct_space_state.intersect_shape(query, 256):
				nearby.append(hit.collider)
		query_origin = unit.global_position
		query_left = 0.1
	var check_lane: bool = not unit.is_air and not unit.is_naval and speed > 1.0 and remaining > 30.0
	var position: Vector2 = unit.global_position
	var actor_radius: float = unit.radius
	var owner: String = unit.side
	var air: bool = unit.is_air
	var naval: bool = unit.is_naval
	var push := Vector2.ZERO
	var head_on := 0.0
	var wait_factor := 1.0
	preload("res://scripts/world/battle_call_counters.gd").iterations(26,nearby.size())
	for candidate in nearby:
		if not is_instance_valid(candidate) or not candidate is Unit: continue
		var other:Unit=candidate
		var offset: Vector2 = other.global_position - position
		var clearance: float = actor_radius + other.radius + 4.0
		var distance_squared := offset.length_squared()
		var along := offset.dot(forward)
		var ahead := check_lane and along > 0.0 and along < look
		var lateral := absf(offset.cross(forward)) if ahead else 0.0
		var in_lane: bool = ahead and lateral < clearance
		# The broad-phase margin is for next-tick arrivals, not a reason to read
		# every distant actor's combat/order state on every movement step.
		if distance_squared >= clearance * clearance and not in_lane:
			continue
		if friendly_unit_pair(unit,other): continue
		if not BattleRequest.friendly(other.side,owner) or other.hp <= 0.0 or other.embarked_in != null \
			or other.is_air != air or other.is_naval != naval:
			continue
		if distance_squared < clearance * clearance:
			var distance := sqrt(distance_squared)
			if distance > 0.01 and distance < clearance:
				push -= offset / distance * (clearance - distance) * 0.6
		if in_lane:
			if yield_target == Vector2.INF and (unit.has_move_order or unit.is_harvester):
				var combined_radius: float = actor_radius + other.radius
				if lateral < combined_radius and request_yield(unit, other, forward):
					# Use the actual front of the swept circle at this offset.
					var contact := sqrt(maxf(0.0, combined_radius * combined_radius - lateral * lateral))
					wait_factor = minf(wait_factor, clampf((along - contact - 4.0) / look, 0.0, 1.0))
			var facing: Vector2 = other.velocity.normalized()
			if (other.has_move_order or other.is_harvester) and facing.dot(forward) < -0.5:
				head_on = maxf(head_on, 1.0 - along / look)
				BridgeTraffic.record(unit,"head_on",other)
	if head_on > 0.0:
		var right := Vector2(-forward.y, forward.x)
		var world = unit._navigation_world()
		if world != null and world.path_service != null:
			var service = world.path_service
			if service.line_walkable(unit.global_position, unit.global_position + right * 40.0, service.cost):
				unit.velocity = (forward + right * head_on).normalized() * speed
	if wait_factor < 1.0: BridgeTraffic.record(unit,"yield_slowdown")
	unit.velocity = unit.velocity * wait_factor + push
