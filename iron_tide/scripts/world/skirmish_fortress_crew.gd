extends RefCounted
## A fortress recruits real riflemen from its own house and its own barracks.
const PICKUP_RANGE := 10.0 * Ra2Damage.PX_PER_CELL
const WAIT_SECONDS := 12.0

static func needs_riflemen(world, owner: String) -> bool:
	var seats := 0
	var riflemen := 0
	for u in world.units:
		if not world.actor_alive(u) or u.side != owner: continue
		if u.unit_id == "BFRT":
			seats += u.logistics.capacity - u.logistics.used_capacity()
		elif u.unit_id == "E1" and u.embarked_in == null and not u.special.has("ai_oil_post"):
			if u.special.has("action"): continue
			var carrier = u.logistics.boarding if is_instance_valid(u.logistics.boarding) else u.special.get("ai_carrier")
			if not is_instance_valid(carrier) or carrier.unit_id == "BFRT": riflemen += 1
	if seats <= riflemen: return false
	for b in world.buildings:
		if world.actor_alive(b) and b.side == owner and b.building_id == "GAPILE":
			riflemen += b.production.count("E1")
	return seats > riflemen

static func load_nearby(ai, fortress) -> void:
	if fortress.repairing or fortress.attack_ordered or is_instance_valid(fortress.attack_target) or fortress.logistics.unloading: return
	var seats: int = fortress.logistics.capacity - fortress.logistics.used_capacity()
	if seats <= 0: return
	var candidates := []
	var world = ai.battle
	for u in world.units:
		if not world.actor_alive(u) or u.side != fortress.side or u.embarked_in != null: continue
		if u.special.get("ai_carrier") == fortress or u.logistics.boarding == fortress:
			seats -= fortress.logistics.passenger_size(u)
			continue
		if u.unit_id != "E1" or u.repairing or u.attack_ordered or is_instance_valid(u.attack_target): continue
		if u.special.has("ai_oil_post") or u.special.has("action") or u.special.get("ai_transport_reserved", false) or is_instance_valid(u.logistics.boarding): continue
		if u.position.distance_squared_to(fortress.position) <= PICKUP_RANGE * PICKUP_RANGE and world.path_service.same_zone(u.position, fortress.position):
			candidates.append(u)
	if seats <= 0 or candidates.is_empty(): return
	candidates.sort_custom(func(a,b): return a.position.distance_squared_to(fortress.position) < b.position.distance_squared_to(fortress.position))
	var assigned := 0
	for u in candidates:
		if not fortress.logistics.can_board(u): continue
		if not world.ai_dispatch.defer_job(world,u,"board",fortress) and not board(ai, u, fortress): continue
		u.special.ai_transport_reserved = true
		u.special.ai_carrier = fortress
		ai._army.erase(u)
		assigned += 1
		if assigned >= seats: break
	if assigned > 0:
		fortress.special.ai_crew_wait = fortress._anim + WAIT_SECONDS
		fortress.ai_order("stop")

static func board(ai, rifleman, fortress) -> bool:
	if not fortress.logistics.can_board(rifleman): return false
	ai.Micro.release(rifleman)
	return not rifleman.is_deployed() and rifleman.logistics.request_board(fortress)
