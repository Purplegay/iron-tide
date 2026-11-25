extends RefCounted
## Diagnostics only. Sample at most 16 actors per rendered frame; never issue orders.
const Counters = preload("res://scripts/world/battle_call_counters.gd")
const BUDGET := 16
const PROGRESS_DISTANCE := 8.0
const WAIT_SECONDS := 2.0
const RECENT_LIMIT := 48
var clock := 0.0
var cursor := 0
var visits := 0
var decks: Array = []
var initialized := false
var states := {}
var windows := {}
var recent: Array = []
var detail_ticks := {}
var suppressed_details := 0

static func record(unit: Unit, kind: String, other: Unit = null) -> void:
	if Counters.owner == 0: return
	var scope = Counters.enter(55)
	var world := unit._navigation_world()
	if world != null: world.bridge_traffic.note(world,unit,kind,other)

func prepare(world: Battle) -> void:
	if initialized or world.path_service == null: return
	initialized = true
	var service: PathService = world.path_service
	decks = preload("res://scripts/world/native_maps.gd").data(service.native_map_id).bridge_decks if not service.native_map_id.is_empty() else service.bridge_decks

func bridge_at(point: Vector2, margin: float) -> int:
	for i in decks.size():
		var deck: Rect2 = decks[i]
		if deck.grow(margin).has_point(point): return i
	return -1

func window(index: int) -> Dictionary:
	if not windows.has(index):
		var deck: Rect2 = decks[index]
		windows[index] = {"bridge":index,"rect":[deck.position.x,deck.position.y,deck.size.x,deck.size.y],
			"events":{},"busy_reasons":{},"sampled_actor_visits":0,"max_no_progress_s":0.0,"peak_waiter":{}}
	return windows[index]

# Same first-matching refusal as LocalTraffic.request_yield, read only.
func busy_reason(other: Unit) -> String:
	if other.has_move_order: return "move_order"
	if other.hold_position and not other._local_traffic.mobile_ai_guard(other): return "hold_position"
	if other._deployed: return "deployed"
	if other.is_harvester: return "harvester"
	if other.repairing: return "repairing"
	if other.is_air: return "air"
	if other.is_naval: return "naval"
	if other.attack_target != null: return "attack_target"
	if other._stun_timer > 0.0: return "stunned"
	return "unknown"

func note(world: Battle, unit: Unit, kind: String, other: Unit = null) -> void:
	prepare(world)
	var index := bridge_at(unit.global_position,unit.radius+64.0)
	if index < 0: return
	var row := window(index)
	row.events[kind] = int(row.events.get(kind,0))+1
	var reason := busy_reason(other) if kind=="yield_rejected_busy" and is_instance_valid(other) else ""
	if not reason.is_empty(): row.busy_reasons[reason] = int(row.busy_reasons.get(reason,0))+1
	# Keep exact counters, but do not allocate duplicate snapshots in dense queues.
	var tick := Engine.get_physics_frames()
	var key := str(index)+":"+kind+":"+reason
	if detail_ticks.get(key,-1)==tick:
		suppressed_details += 1
		return
	detail_ticks[key] = tick
	if recent.size() >= RECENT_LIMIT: recent.pop_front()
	recent.append({"sim_s":clock,"physics_tick":tick,"bridge":index,"event":kind,"reason":reason,"unit":unit.get_instance_id(),"type":unit.unit_id,"side":unit.side,
		"position":[unit.global_position.x,unit.global_position.y],"other":other.get_instance_id() if is_instance_valid(other) else 0,
		"other_type":other.unit_id if is_instance_valid(other) else "",
		"other_state":{"side":other.side,"position":[other.global_position.x,other.global_position.y],"moving_order":other.has_move_order,
			"hold":other.hold_position,"deployed":other._deployed,"harvester":other.is_harvester,"repairing":other.repairing,
			"has_target":is_instance_valid(other.attack_target),"stun_s":other._stun_timer} if is_instance_valid(other) else {}})

func sample(world: Battle, delta: float) -> void:
	var scope = Counters.enter(54)
	prepare(world)
	clock += maxf(0.0,delta)
	if decks.is_empty() or world.units.is_empty(): return
	var count := mini(BUDGET,world.units.size())
	Counters.iterations(54,count)
	visits += count
	for n in count:
		cursor %= world.units.size()
		var candidate = world.units[cursor]
		cursor += 1
		if not is_instance_valid(candidate) or not candidate is Unit: continue
		var unit: Unit = candidate
		var id := unit.get_instance_id()
		if unit.is_air or unit.is_naval or unit._dead or unit.hp<=0.0 or unit.embarked_in!=null:
			states.erase(id)
			continue
		var index := bridge_at(unit.global_position,unit.radius+64.0)
		if index < 0:
			states.erase(id)
			continue
		var row := window(index)
		row.sampled_actor_visits += 1
		var wants_move := unit.has_move_order or unit._local_traffic.yield_target.is_finite() or (unit.is_harvester and unit.harvest_state in ["to_node","to_base"])
		if not wants_move or unit._deployed or unit._stun_timer>0.0 or AlliedAbilities.frozen(unit):
			states.erase(id)
			continue
		var point := unit.global_position
		if not states.has(id) or states[id].bridge!=index or states[id].goal!=unit.move_target or point.distance_squared_to(states[id].origin)>PROGRESS_DISTANCE*PROGRESS_DISTANCE:
			states[id] = {"unit":id,"type":unit.unit_id,"side":unit.side,"bridge":index,"origin":point,"since":clock,"goal":unit.move_target}
		var state: Dictionary = states[id]
		state.seen = clock
		state.position = [point.x,point.y]
		state.velocity = [unit.velocity.x,unit.velocity.y]
		state.harvest_state = unit.harvest_state if unit.is_harvester else ""
		var age := clock-float(state.since)
		if age > float(row.max_no_progress_s):
			row.max_no_progress_s = age
			row.peak_waiter = waiter_snapshot(state)

func waiter_snapshot(state: Dictionary) -> Dictionary:
	return {"unit":state.unit,"type":state.type,"side":state.side,"bridge":state.bridge,
		"no_progress_s":float(state.seen)-float(state.since),"observed_sim_s":float(state.seen),
		"sample_age_s":clock-float(state.seen),"position":state.position,"velocity":state.velocity,
		"goal":[state.goal.x,state.goal.y] if state.goal.is_finite() else null,"harvest_state":state.harvest_state}

func take() -> Dictionary:
	var waiting: Array = []
	for id in states.keys():
		if not is_instance_id_valid(id):
			states.erase(id)
			continue
		var state: Dictionary = states[id]
		var age := float(state.seen)-float(state.since)
		if age < WAIT_SECONDS: continue
		waiting.append(waiter_snapshot(state))
	waiting.sort_custom(func(a,b):return a.no_progress_s>b.no_progress_s)
	var result := {"scope":"Bridge areas including 64px approaches; exact event counts, bounded round-robin movement samples. No progress means remaining within 8px with movement intent, not proof of a collision deadlock. Durations are active game seconds; sample_age_s exposes stale samples.",
		"sample_budget_per_frame":BUDGET,"sampled_actor_visits":visits,"bridges":windows.values(),"waiting_sample_count":waiting.size(),"longest_waiting":waiting.slice(0,20),"recent_events":recent,
		"detail_policy":"At most one detail per bridge/event/first-matching busy reason per physics tick; last 48 retained. Counters are not sampled.","suppressed_duplicate_details":suppressed_details}
	windows = {}
	recent = []
	detail_ticks.clear()
	suppressed_details = 0
	visits = 0
	return result
