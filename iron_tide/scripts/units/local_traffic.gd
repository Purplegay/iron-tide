extends RefCounted
const BridgeTraffic = preload("res://scripts/world/bridge_traffic.gd")
## Physical broad-phase keeps work local instead of scanning the first N allies.
## Idle mobile friends can make a short, collision-checked sidestep. Guarded,
## deployed, fighting, harvesting and explicitly moving units are never displaced.
var shape := CircleShape2D.new()
var query := PhysicsShapeQueryParameters2D.new()
var yield_target := Vector2.INF
var yield_left := 0.0
var yield_origin := Vector2.INF
var nearby: Array = []
var _query_ranks: Dictionary = {}
var query_origin := Vector2.INF
var _query_world: Battle
var _query_radius := 0.0
var _query_mask := 0
var _query_max_radius := 0.0
var _query_region: Dictionary = {}
# Keep rejected broad-phase members so same-cell arrivals and layer changes
# cannot hide behind a valid bucket revision. These are not steering candidates.
var _query_watch: Array = []

const CONGESTION := "friendly_congestion_escape"
const CONGESTION_SECONDS := 2.0
const EMPTY_CONGESTION: Dictionary = {}

static func passing(unit: Unit) -> bool:
	return unit.special.has(CONGESTION) and unit.special[CONGESTION].get("passing", false)

func tick_congestion(unit: Unit, delta: float) -> void:
	if unit.is_air or unit.is_naval or unit.embarked_in != null or unit._dead: return
	if not unit.has_move_order and (Engine.get_physics_frames() + unit.get_instance_id()) % 30 == 0:
		settle_overlapping_vehicle(unit)
	var state: Dictionary = unit.special.get(CONGESTION, EMPTY_CONGESTION)
	if state.get("passing", false):
		# Never restore a solid body while another friendly hull still overlaps it.
		var world = unit._navigation_world()
		var contacts: Array = world.neighborhood.nearby(unit.position, unit.radius + world.neighborhood.max_unit_radius + 4.0, true) if world != null else nearby
		for other in contacts:
			if not is_instance_valid(other) or not other is Unit: continue
			if unit.position.distance_squared_to(other.position) >= pow(unit.radius + other.radius + 4.0, 2): continue
			if _ground_friend(unit,other):
				state.clear_seconds = 0.0
				return
		state.clear_seconds = float(state.get("clear_seconds",0.0)) + delta
		if state.clear_seconds >= 0.35 and (not unit.has_move_order or unit.position.distance_to(state.origin) >= 24.0):
			unit.special.erase(CONGESTION)
		return
	if not unit.has_move_order or unit.hold_position or unit._deployed or unit.repairing or unit._stun_timer > 0.0 or AlliedAbilities.frozen(unit):
		unit.special.erase(CONGESTION)
		return
	var blocked := false
	for i in unit.get_slide_collision_count():
		var other = unit.get_slide_collision(i).get_collider()
		if _ground_friend(unit,other) and not friendly_unit_pair(unit,other) and unit.position.distance_squared_to(other.position) < pow(unit.radius+other.radius+8.0,2): blocked=true; break
	if not blocked:
		blocked = _congestion_blocker_ahead(unit)
	if not blocked:
		unit.special.erase(CONGESTION)
		return
	if state.is_empty() or unit.position.distance_to(state.origin) >= 8.0:
		unit.special[CONGESTION] = {"origin":unit.position,"seconds":0.0,"passing":false}
		return
	state.seconds += delta
	if state.seconds + 0.000001 >= CONGESTION_SECONDS:
		state.passing = true
		state.origin = unit.position
		state.clear_seconds = 0.0
		# These transient steering probes must not retain the old solid-body detour.
		invalidate_query()
		unit._dodge_t=0.0

# Only the close forward obstruction matters to the congestion timer. The
# wider steering/watch cache is still validated by every steering consumer.
func _congestion_blocker_ahead(unit: Unit) -> bool:
	var world := unit._navigation_world()
	var origin := unit.position
	var contacts: Array
	if world != null and world.units.size() >= 96 and origin == unit.global_position and not AlliedAbilities.infantry(unit):
		contacts = world.neighborhood.nearby(origin, unit.radius + world.neighborhood.max_unit_radius + 8.0, true)
	else:
		ensure_candidates(unit)
		contacts = nearby
	if contacts.is_empty(): return false
	var waypoint: Vector2 = unit.move_target
	if unit._path_pts.size() >= 2: waypoint=unit._path_pts[clampi(unit._path_i,1,unit._path_pts.size()-1)]
	var direction := origin.direction_to(waypoint)
	for other in contacts:
		if not is_instance_valid(other) or not other is Unit or other == unit: continue
		if (other.collision_layer & 1) == 0: continue
		var offset: Vector2 = other.position-origin
		if offset.dot(direction)<=0.0 or offset.length_squared()>=pow(unit.radius+other.radius+8.0,2): continue
		if _ground_friend(unit,other) and not friendly_unit_pair(unit,other): return true
	return false

# Resolve a parked hull intersection locally, preserving the unit's current orders.
func settle_overlapping_vehicle(unit: Unit) -> void:
	if unit._deployed or unit.is_harvester or unit.repairing or unit.special.get("expedition_convoy_paused", false) or AlliedAbilities.infantry(unit): return
	var world := unit._navigation_world()
	if world == null or world.path_service == null: return
	var reach: float = unit.radius + world.neighborhood.max_unit_radius
	var start := unit.global_position
	var blocking: Array[Unit] = []
	var distance := 0.0
	for other in world.neighborhood.nearby(start, reach, true):
		if not _ground_friend(unit, other) or other.has_move_order: continue
		var clearance: float = unit.radius + other.radius
		if start.distance_squared_to(other.global_position) >= pow(clearance - 1.0, 2) or AlliedAbilities.infantry(other): continue
		blocking.append(other)
		distance = maxf(distance, clearance + 4.0)
	if blocking.is_empty(): return
	var existing := unit.get_collision_exceptions()
	for other in blocking:
		if other not in existing: unit.add_collision_exception_with(other)
	for i in 12:
		var step := Vector2.RIGHT.rotated(i * TAU / 12.0) * distance
		var goal := start + step
		if not Rect2(Vector2.ZERO, Vector2.ONE * world.path_service.map_size).has_point(goal): continue
		if not unit._domain_ok(goal) or not world.path_service.line_walkable(start, goal, world.path_service.cost): continue
		var free := true
		for other in blocking:
			if goal.distance_to(other.global_position) < unit.radius + other.radius + 1.0:
				free = false
				break
		if free and not unit.test_move(unit.global_transform, step):
			unit.move_and_collide(step)
			world.neighborhood.relocate(unit)
			break
	for other in blocking:
		if other not in existing: unit.remove_collision_exception_with(other)

static func _ground_friend(unit: Unit, other) -> bool:
	return is_instance_valid(other) and other is Unit and other != unit and not other._dead and other.embarked_in == null and not other.is_air and not other.is_naval and BattleRequest.friendly(unit.side,other.side)


static func friendly_unit_pair(unit: Unit, other: Unit) -> bool:
	if not BattleRequest.friendly(unit.side,other.side): return false
	return _friendly_pair_policy(unit,other)

static func _friendly_pair_policy(unit: Unit, other: Unit) -> bool:
	if not unit.is_air and not other.is_air and not unit.is_naval and not other.is_naval and (passing(unit) or passing(other)): return true
	if not unit.is_air and not other.is_air and not unit.is_naval and not other.is_naval and (preload("res://scripts/units/base_escape.gd").active(unit) or preload("res://scripts/units/base_escape.gd").active(other)):return true
	if (unit.side == "ally" and BattleRequest.is_ai_house(other.side)) \
		or (other.side == "ally" and BattleRequest.is_ai_house(unit.side)):
		return true
	return not unit.is_air and not other.is_air and not unit.is_naval and not other.is_naval \
		and (AlliedAbilities.infantry(unit) or AlliedAbilities.infantry(other))

func bridge_direction(unit: Unit, direction: Vector2) -> Vector2:
	if unit.is_air or unit.is_naval or direction.is_zero_approx(): return direction
	var waypoint: Vector2 = unit.move_target
	if unit._path_pts.size()>=2:
		waypoint = unit._path_pts[clampi(unit._path_i,1,unit._path_pts.size()-1)]
	# Hand back to exact route/arrival steering near a corner or destination.
	if unit.global_position.distance_squared_to(waypoint)<80.0*80.0: return direction
	var world = unit._navigation_world()
	if world == null or world.path_service == null: return direction
	var deck: Rect2 = world.path_service.bridge_at(unit.global_position,unit.radius+40.0)
	if not deck.has_area(): return direction
	var axis := Vector2.RIGHT if deck.size.x>deck.size.y else Vector2.DOWN
	if absf(direction.dot(axis))<0.4: return direction
	if axis.dot(direction)<0: axis=-axis
	var right := Vector2(-axis.y,axis.x)
	var width := minf(deck.size.x,deck.size.y)
	var lane := minf(width*0.25,maxf(0.0,width*0.5-unit.radius-5.0))
	var lateral: float = (unit.global_position-deck.get_center()).dot(right)
	# Opposing columns keep their own right-hand lane instead of both targeting
	# the same A* cell centre. The original path still owns entry, exit and orders.
	return (axis*80.0+right*clampf(lane-lateral,-50.0,50.0)).normalized()

func invalidate_query() -> void:
	query_origin = Vector2.INF
	_query_region.clear()
	_query_watch.clear()
	nearby.clear()
	_query_ranks.clear()

func reset() -> void:
	invalidate_query()
	yield_origin = Vector2.INF
	yield_target = Vector2.INF
	yield_left = 0.0

func tick_idle(unit: Unit, delta: float) -> bool:
	yield_left = maxf(0.0, yield_left - delta)
	if yield_target == Vector2.INF:
		return false
	if yield_left <= 0.0 or unit.global_position.distance_to(yield_target) <= 6.0:
		yield_target = Vector2.INF
		unit.move_target = unit.global_position
		unit.velocity = Vector2.ZERO
		return true
	unit._move_toward(yield_target, delta, false)
	unit._face_if_moving()
	return true

# Candidate membership lives for the battle until its dependencies change.
# Every consumer validates coverage and live membership before reuse.
func ensure_candidates(unit: Unit, force := false) -> void:
	if not unit.is_air and not unit.is_naval and AlliedAbilities.infantry(unit):
		invalidate_query()
		return
	var world := unit._navigation_world() as Battle
	var radius := unit.radius + 60.0 + maxf(60.0, unit.move_speed * 0.8) + 64.0
	var mask := 8 if unit.is_air else 1
	if not force and _can_reuse_candidates(unit, world, radius, mask):
		return
	_rebuild_candidates(unit, world, radius, mask)

func _can_reuse_candidates(unit: Unit, world: Battle, radius: float, mask: int) -> bool:
	# Physics-only bodies have no complete membership change journal. Preserve
	# the original physical query rather than claiming an unsafe sparse hit.
	if world == null or world.units.size() < 96 or world != _query_world:
		return false
	if mask != _query_mask or radius > _query_radius:
		return false
	if query_origin.distance_squared_to(unit.global_position) > 24.0 * 24.0:
		return false
	var index = world.neighborhood
	if index.max_unit_radius > _query_max_radius:
		return false
	if not index.unit_region_unchanged(_query_region, unit.global_position, radius + index.max_unit_radius):
		return false
	for candidate in _query_watch:
		if not is_instance_valid(candidate) or not candidate is Unit:
			continue
		var actor: Unit = candidate
		if (actor.collision_layer & mask) != 0 and unit.global_position.distance_squared_to(actor.global_position) <= pow(radius + actor.radius, 2.0):
			return false
	return true

func _rebuild_candidates(unit: Unit, world: Battle, radius: float, mask: int) -> void:
	nearby.clear()
	_query_ranks.clear()
	_query_watch.clear()
	_query_region.clear()
	var query_position := unit.global_position
	if world != null and world.units.size() >= 96:
		var index = world.neighborhood
		var reach: float = radius + index.max_unit_radius
		for candidate in index.nearby(query_position, reach, true):
			if not is_instance_valid(candidate) or not candidate is Unit or candidate == unit:
				continue
			var actor: Unit = candidate
			var distance: float = radius + actor.radius
			if (actor.collision_layer & mask) != 0 and query_position.distance_squared_to(actor.global_position) <= distance * distance:
				_query_ranks[actor] = nearby.size()
				nearby.append(actor)
			else:
				_query_watch.append(actor)
		_query_region = index.unit_region_stamp(query_position, reach)
		_query_max_radius = index.max_unit_radius
	else:
		shape.radius = radius
		query.shape = shape
		query.transform = Transform2D(0.0, query_position)
		query.collision_mask = mask
		query.exclude = [unit.get_rid()]
		for hit in unit.get_world_2d().direct_space_state.intersect_shape(query, 256):
			nearby.append(hit.collider)
	_query_world = world
	_query_radius = radius
	_query_mask = mask
	query_origin = query_position

func apply(unit:Unit, _delta: float) -> void:
	var _call_log_scope = preload("res://scripts/world/battle_call_counters.gd").enter(26)
	ensure_candidates(unit)
	if not unit.is_air and not unit.is_naval and AlliedAbilities.infantry(unit): return
	var speed: float = unit.velocity.length()
	var forward: Vector2 = unit.velocity.normalized()
	var remaining: float = unit.global_position.distance_to(unit.move_target)
	var look := minf(maxf(60.0, speed * 0.8), remaining)
	# Passing ground units never steer away from friendly hulls. Keep the
	# refreshed query for turn planning and the tick that restores collision.
	if not unit.is_air and not unit.is_naval and passing(unit): return
	var check_lane: bool = not unit.is_air and not unit.is_naval and speed > 1.0 and remaining > 30.0
	var position: Vector2 = unit.global_position
	var actor_radius: float = unit.radius
	var owner: String = unit.side
	var air: bool = unit.is_air
	var naval: bool = unit.is_naval
	var push := Vector2.ZERO
	var head_on := 0.0
	var wait_factor := 1.0
	var contacts := _exact_avoidance_contacts(unit, position, forward, look, check_lane, owner, air, naval)
	preload("res://scripts/world/battle_call_counters.gd").iterations(26,contacts.size())
	for entry in contacts:
		var other: Unit = entry[0]
		var offset: Vector2 = entry[1]
		var clearance: float = entry[2]
		var distance_squared: float = entry[3]
		var along: float = entry[4]
		var lateral: float = entry[5]
		var in_lane: bool = entry[6]
		if (owner == other.side or BattleRequest.house_teams.get(other.side) is int) and _friendly_pair_policy(unit,other): continue
		if owner != other.side and not BattleRequest.house_teams.get(other.side) is int and friendly_unit_pair(unit,other): continue
		if distance_squared < clearance * clearance:
			var distance := sqrt(distance_squared)
			if distance > 0.01 and distance < clearance:
				push -= offset / distance * (clearance - distance) * 0.6
		if in_lane:
			if yield_target == Vector2.INF and (unit.has_move_order or unit.is_harvester):
				var combined_radius: float = actor_radius + other.radius
				if lateral < combined_radius and _request_yield_after_pair_check(unit, other, forward):
					# Use the actual front of the swept circle at this offset.
					var contact := sqrt(maxf(0.0, combined_radius * combined_radius - lateral * lateral))
					wait_factor = minf(wait_factor, clampf((along - contact - 4.0) / look, 0.0, 1.0))
			if (other.has_move_order or other.is_harvester) and other.velocity.normalized().dot(forward) < -0.5:
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

# Exact geometry is evaluated once, before sorting and before any yield policy.
# The legacy cache remains authoritative for order and for other consumers.
func _exact_avoidance_contacts(unit: Unit, point: Vector2, direction: Vector2, look: float, check_lane: bool, owner: String, air: bool, naval: bool) -> Array:
	var buckets: Array = [nearby]
	var rank_candidates := false
	if _query_world != null and _query_world.units.size() >= 96 and nearby.size() > 2:
		var tree_parent := unit.get_parent() as Node2D
		if tree_parent != null and tree_parent.global_transform == Transform2D.IDENTITY:
			var index = _query_world.neighborhood
			var reach: float = unit.radius + index.max_unit_radius + 4.0
			var lane_look := look if check_lane else 0.0
			if point.is_finite() and direction.is_finite() and is_finite(lane_look) and is_finite(reach) and reach >= 0.0 and reach + lane_look <= 512.0:
				buckets = index.traffic_contact_buckets(point, direction, lane_look, reach)
				rank_candidates = true
	var selected: Array = []
	var ranked := PackedInt32Array()
	var by_rank: Dictionary = {}
	var actor_radius := unit.radius
	for bucket: Array in buckets:
		for candidate in bucket:
			var rank := -1
			if rank_candidates:
				rank = _query_ranks.get(candidate, -1)
				if rank < 0: continue
			if not is_instance_valid(candidate) or not candidate is Unit: continue
			var other: Unit = candidate
			if (other.collision_layer & _query_mask) == 0: continue
			var offset := other.global_position - point
			var clearance := actor_radius + other.radius + 4.0
			var distance_squared := offset.length_squared()
			var along := offset.dot(direction)
			var ahead := check_lane and along > 0.0 and along < look
			var lateral := absf(offset.cross(direction)) if ahead else 0.0
			var in_lane := ahead and lateral < clearance
			if distance_squared >= clearance * clearance and not in_lane: continue
			# These live predicates do not depend on a previous contact's yield
			# decision. Reject here so they never need a row, rank or sort entry.
			if other.hp <= 0.0 or other.embarked_in != null or other.is_air != air or other.is_naval != naval: continue
			if not BattleRequest.friendly(other.side,owner): continue
			var entry := [other,offset,clearance,distance_squared,along,lateral,in_lane]
			if rank_candidates:
				ranked.append(rank)
				by_rank[rank] = entry
			else:
				selected.append(entry)
	if rank_candidates:
		ranked.sort()
		for rank in ranked:
			selected.append(by_rank[rank])
	return selected

# Neutral actors are solid without being eligible for friendly yielding. Use a
# short live corridor, not a map-wide occupancy grid or remembered unit list.
static func campaign_neutral_blockers(unit: Unit, world: Battle, waypoint: Vector2, stalled := false) -> Array:
	if world == null or world.skirmish or world.endless or not world.uses_ground_passages(unit):
		return []
	if preload("res://scripts/expedition/rules.gd").active(): return []
	if unit.special.has("hollywood_on_deck") or unit.special.get("hollywood_deck_goal", Vector2.INF) == unit.move_target:
		return [] # The elevated lane cannot use the street planner's circles.
	var start := unit.global_position
	var leg := (waypoint - start).limit_length(240.0)
	if leg.is_zero_approx(): return []
	var end := start + leg
	var corridor_margin := 48.0
	var reach: float = leg.length() * 0.5 + unit.radius + world.neighborhood.max_unit_radius + 8.0 + corridor_margin
	var blockers := []
	var blocked := false
	for other in world.neighborhood.nearby(start + leg * 0.5, reach, true):
		if not is_instance_valid(other) or not other is Unit or other == unit or other.side != "neutral": continue
		if other._dead or other.hp <= 0.0 or other.is_queued_for_deletion() or other.embarked_in != null or other.is_air or other.is_naval: continue
		if (other.collision_layer & unit.collision_mask) == 0 or other.special.has("hollywood_on_deck") or friendly_unit_pair(unit, other): continue
		if other.velocity.length_squared() > 64.0 or (not stalled and other.has_move_order): continue
		var clearance: float = unit.radius + other.radius + 8.0
		var closest := Geometry2D.get_closest_point_to_segment(other.global_position, start, end)
		var distance_sq := closest.distance_squared_to(other.global_position)
		if distance_sq > pow(clearance + corridor_margin, 2) or not world.actor_visible_to(unit.side, other, unit): continue
		if distance_sq <= clearance * clearance: blocked = true
		blockers.append({"position": other.global_position, "radius": clearance})
	return blockers if blocked else []

# Only detour when a stopped ally or neutral actor obstructs the current leg.
# These circles belong to one request; they never change shared terrain.
func stalled_blockers(unit: Unit, waypoint: Vector2) -> Array:
	var neutrals := campaign_neutral_blockers(unit, unit._navigation_world(), waypoint, true)
	ensure_candidates(unit, true)
	var blockers := []
	var blocked := false
	for other in nearby:
		if not is_instance_valid(other) or not other is Unit or other._dead or other.embarked_in != null:
			continue
		if (other.collision_layer & _query_mask) == 0: continue
		if not BattleRequest.friendly(other.side,unit.side) or other.is_air or other.is_naval != unit.is_naval or other._deployed:
			continue
		if friendly_unit_pair(unit,other): continue
		if other.has_move_order or other._local_traffic.yield_target.is_finite() or other.velocity.length_squared() > 64.0:
			continue
		var clearance: float = unit.radius + other.radius + 8.0
		var closest := Geometry2D.get_closest_point_to_segment(other.global_position, unit.global_position, waypoint)
		if closest.distance_squared_to(other.global_position) <= clearance * clearance: blocked = true
		blockers.append({"position":other.global_position, "radius":clearance})
	if blocked:
		blockers.append_array(neutrals)
		return blockers
	return neutrals

func request_yield(requester: Unit, other: Unit, forward: Vector2) -> bool:
	if friendly_unit_pair(requester,other): return false
	return _request_yield_after_pair_check(requester, other, forward)

func _request_yield_after_pair_check(requester: Unit, other: Unit, forward: Vector2) -> bool:
	var _call_log_scope = preload("res://scripts/world/battle_call_counters.gd").enter(72)
	BridgeTraffic.record(requester,"yield_requested",other)
	if other.has_move_order or (other.hold_position and not mobile_ai_guard(other)) or other._deployed or other.is_harvester or other.repairing \
			or other.is_air or other.is_naval or other.attack_target != null or other._stun_timer > 0.0:
		BridgeTraffic.record(requester,"yield_rejected_busy",other)
		return false
	var traffic = other._local_traffic
	if traffic.yield_target != Vector2.INF:
		BridgeTraffic.record(requester,"yield_reused",other)
		return true
	if traffic.yield_left > 0.0:
		BridgeTraffic.record(requester,"yield_rejected_cooldown",other)
		return false
	var right := Vector2(-forward.y, forward.x)
	# Step away from the travel line, preferring the already nearer side.
	if (other.global_position - requester.global_position).dot(right) < 0.0:
		right = -right
	var world = other._navigation_world()
	var deck := Rect2()
	if world != null and world.path_service != null:
		deck = world.path_service.bridge_at(other.global_position, other.radius)
	var directions := [right, -right]
	if deck.has_area():
		var axis := Vector2.RIGHT if deck.size.x > deck.size.y else Vector2.DOWN
		if axis.dot(forward)<0.0: axis=-axis
		# A parked hull cannot sidestep into the river. Advance along the deck
		# instead, retaining its original stop/guard policy and all collision checks.
		directions.push_front(axis)
	elif BattleRequest.is_ai_house(other.side):
		# At a crowded bridge mouth both side sweeps can be occupied even when
		# the road ahead is clear. Try a local forward step only after both sides;
		# retain the same body, shore, path and maximum-displacement checks.
		directions.append(forward)
	for lateral: Vector2 in directions:
		preload("res://scripts/world/battle_call_counters.gd").iterations(72,1)
		var step_length: float = requester.radius + other.radius + 24.0
		if absf(lateral.dot(forward)) < 0.6 and world != null and world.uses_ground_passages(requester) and world.uses_ground_passages(other):
			# Clear the moving hull plus separation (4) and stopping tolerance (6).
			var already_clear: float = (other.global_position - requester.global_position).dot(lateral)
			step_length = maxf(0.0, requester.radius + other.radius + 11.0 - already_clear)
		var offset := lateral * step_length
		var goal: Vector2 = other.global_position + offset
		var anchor: Vector2 = other.global_position if traffic.yield_origin == Vector2.INF else traffic.yield_origin
		var max_yield := maxf(deck.size.x,deck.size.y)+128.0 if deck.has_area() else 64.0
		if anchor.distance_to(goal) > max_yield:
			BridgeTraffic.record(requester,"yield_rejected_leash",other)
			continue
		if not other._domain_ok(goal):
			BridgeTraffic.record(requester,"yield_rejected_terrain",other)
			continue
		if other.test_move(other.global_transform, offset):
			BridgeTraffic.record(requester,"yield_rejected_collision",other)
			continue
		if world != null and world.path_service != null:
			var service = world.path_service
			if not service.line_walkable(other.global_position, goal, service.cost):
				if not world.uses_ground_passages(other) or not service.passages.clear(service,other.global_position,goal,other.radius+1.0,[]):
					BridgeTraffic.record(requester,"yield_rejected_path",other)
					continue
		traffic.yield_origin = anchor
		traffic.yield_target = goal
		traffic.yield_left = 3.0
		if not deck.has_area() and lateral == forward: BridgeTraffic.record(requester,"yield_forward",other)
		BridgeTraffic.record(requester,"yield_new",other)
		return true
	BridgeTraffic.record(requester,"yield_rejected_space",other)
	return false

static func mobile_ai_guard(unit: Unit) -> bool:
	# Computer guard is an assignment, not a player's explicit hold command.
	# Keep its role/stance after a short collision-checked yield.
	return BattleRequest.is_ai_house(unit.side) and unit.special.get("ai_campaign_role")=="guard" and not unit.special.has("action")

func can_settle(unit: Unit, distance_limit := 40.0) -> bool:
	# A finished friend may have yielded into the exact slot. Accept a free
	# nearby landing within one grid cell instead of circling that occupied slot.
	if unit.is_air or unit.is_naval or unit.is_harvester or unit.global_position.distance_to(unit.move_target) > distance_limit:
		return false
	shape.radius = maxf(100.0, distance_limit + unit.radius + 4.0)
	query.shape = shape
	query.transform = Transform2D(0.0, unit.global_position)
	query.collision_mask = 1
	query.exclude = [unit.get_rid()]
	var occupied := false
	for hit in unit.get_world_2d().direct_space_state.intersect_shape(query, 256):
		var other = hit.collider
		if not is_instance_valid(other) or not other.has_method("order_move") or other.hp <= 0 or other.embarked_in != null:
			continue
		if other is Unit and friendly_unit_pair(unit,other): continue
		if other.is_naval and unit._navigation_world().path_service.near_deck(unit.global_position, unit.radius): continue
		var clearance: float = unit.radius + other.radius
		if unit.global_position.distance_to(other.global_position) < clearance - 0.1:
			return false
		if BattleRequest.friendly(other.side,unit.side) and not other.has_move_order and other._local_traffic.yield_target == Vector2.INF \
				and unit.move_target.distance_to(other.global_position) < clearance + 4.0:
			occupied = true
	return occupied
