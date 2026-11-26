extends RefCounted
## One admission per distinct computer-controlled unit and rendered frame.
## Pending records use battle snapshot actor references, never instance IDs.
const LIMITS := [128,64,32,16]
const WAITING := "ai_dispatch_waiting"
const COMBAT_WINDOW := 2.0
const NORMAL_SHARE_DIVISOR := 4
var frame := -1
var admitted := {}
var limit := 128

func _begin(world) -> void:
	var now := Engine.get_process_frames()
	if frame == now: return
	frame = now
	admitted.clear()
	limit = LIMITS[world.frame_pacing.tier] if is_instance_valid(world.frame_pacing) else LIMITS[0]
	var waiting: Dictionary = world.allied_state.get(WAITING,{})
	var tick := Engine.get_physics_frames()
	# Only classify requests when they actually compete for this frame.
	var congested := waiting.size() > limit
	var normal_quota := limit / NORMAL_SHARE_DIVISOR
	var combat_quota := limit - normal_quota
	var combat := []
	var normal := []
	for unit in waiting.keys():
		var entry: Dictionary = waiting[unit]
		if not world.actor_alive(unit) or unit.side != entry.owner or not BattleRequest.is_ai_house(unit.side):
			waiting.erase(unit)
			continue
		# If no physics step happened between two renders, keep a path request
		# in line until its caller actually gets to use the reservation.
		if entry.has("path_tick") and (tick < entry.path_tick or tick-entry.path_tick > 4):
			entry.erase("path_tick")
		if entry.size() == 1:
			waiting.erase(unit)
			continue
		if not congested:
			admitted[unit] = true
			continue
		var lane := combat if _in_combat(unit) else normal
		if lane.size() < limit:
			lane.append(unit)
		if combat.size() >= combat_quota and normal.size() >= normal_quota:
			break
	if congested:
		# Oldest first inside each group. Give any unused share to the other group.
		var combat_seats := mini(combat.size(), limit - mini(normal_quota, normal.size()))
		for i in combat_seats: admitted[combat[i]] = true
		for i in mini(normal.size(), limit - combat_seats): admitted[normal[i]] = true

static func record_exchange(attacker, target) -> void:
	if not is_instance_valid(attacker) or not is_instance_valid(target): return
	if not (attacker is Unit or attacker is Building) or not (target is Unit or target is Building): return
	if BattleRequest.friendly(attacker.side, target.side): return
	if attacker is Unit and BattleRequest.is_ai_house(attacker.side):
		attacker.special.ai_exchange_at = attacker._anim
	if target is Unit and BattleRequest.is_ai_house(target.side):
		target.special.ai_exchange_at = target._anim

static func _in_combat(unit) -> bool:
	if unit._return_timer > 0.0 or unit._hp_flash > 0.0 or unit._muzzle > 0.0: return true
	if not unit.special.has("ai_exchange_at"): return false
	var since: float = unit._anim - float(unit.special.ai_exchange_at)
	return since >= 0.0 and since < COMBAT_WINDOW

func _admit(world,unit) -> bool:
	_begin(world)
	if admitted.has(unit): return true
	if admitted.size() == limit: return false
	admitted[unit] = true
	return true

func _entry(world,unit) -> Dictionary:
	# Allocate mutable queue records only on insertion, preserving existing owners.
	var state:Dictionary=world.allied_state
	var waiting=state.get(WAITING)
	if waiting==null:
		waiting={}
		state[WAITING]=waiting
	var entry=waiting.get(unit)
	if entry==null:
		entry={"owner":unit.side}
		waiting[unit]=entry
	return entry

func allow(world, unit) -> bool:
	if not world.skirmish or not BattleRequest.is_ai_house(unit.side): return true
	if not _admit(world,unit):
		var entry := _entry(world,unit)
		var tick := Engine.get_physics_frames()
		if entry.get("path_tick", -1) != tick: entry.path_tick = tick
		return false
	var waiting: Dictionary = world.allied_state.get(WAITING,{})
	if waiting.has(unit):
		var entry: Dictionary = waiting[unit]
		entry.erase("path_tick")
		if entry.size()==1: waiting.erase(unit)
	return true

# Target acquisition can wait in the same fair queue as other AI decisions.
# A grant wakes the ordinary unit think path, where current orders still win.
func allow_scan(world, unit) -> bool:
	if not world.skirmish or not BattleRequest.is_ai_house(unit.side): return true
	if not _admit(world,unit):
		var entry := _entry(world,unit)
		if not entry.has("scan"): entry.scan = true
		return false
	var waiting:Dictionary = world.allied_state.get(WAITING,{})
	if waiting.has(unit):
		var entry:Dictionary = waiting[unit]
		entry.erase("scan")
		if entry.size()==1: waiting.erase(unit)
	return true

func submit(world, unit, order: Dictionary) -> void:
	if is_instance_valid(unit) and unit.special.get("expedition_objective","")=="command":return
	if is_instance_valid(unit) and preload("res://scripts/world/air_relief.gd").blocks_order(world,unit,order): return
	if not world.actor_alive(unit) or not BattleRequest.is_ai_house(unit.side): return
	if _admit(world,unit):
		cancel_order(world,unit)
		_apply(world,unit,order)
	else:
		_entry(world,unit).order = order
		if not unit.special.has("ai_dispatch_pending"): unit.special.ai_dispatch_pending = true

static func cancel_order(world,unit) -> void:
	if not unit.special.erase("ai_dispatch_pending"): return
	var waiting: Dictionary = world.allied_state.get(WAITING,{})
	if waiting.has(unit):
		waiting[unit].erase("order")
		if waiting[unit].size()==1: waiting.erase(unit)

func defer_job(world,unit,kind:String,value) -> bool:
	if _admit(world,unit):
		var waiting: Dictionary = world.allied_state.get(WAITING,{})
		if waiting.has(unit) and waiting[unit].has("jobs"):
			var entry: Dictionary = waiting[unit]
			entry.jobs.erase(kind)
			if entry.jobs.is_empty(): entry.erase("jobs")
			if entry.size()==1: waiting.erase(unit)
		return false
	var jobs: Dictionary = _entry(world,unit).get_or_add("jobs",{})
	# Marker jobs and object targets are idempotent. Leave structured intents
	# and micro timing on their existing latest-payload path.
	if kind == "operations" or kind == "recover" or kind == "board":
		if is_same(jobs.get(kind), value): return true
	jobs[kind] = value
	return true

func pump(world) -> void:
	if not world.skirmish or world.paused or world.ended or world.get_tree().paused: return
	_begin(world)
	var waiting: Dictionary = world.allied_state.get(WAITING,{})
	if waiting.is_empty(): return
	var contacts := {}
	for unit in admitted.keys():
		if not waiting.has(unit): continue
		var entry: Dictionary = waiting[unit]
		if not world.actor_alive(unit) or unit.side != entry.owner:
			waiting.erase(unit)
			continue
		var order: Dictionary = entry.get("order",{})
		var jobs: Dictionary = entry.get("jobs",{})
		if entry.erase("scan"):
			unit._scan_grant_until = Engine.get_physics_frames()+1
			unit._think_timer = 0.0
		entry.erase("order")
		entry.erase("jobs")
		unit.special.erase("ai_dispatch_pending")
		if entry.size()==1: waiting.erase(unit)
		if not order.is_empty(): _apply(world,unit,order)
		if jobs.is_empty() or not world.actor_alive(unit) or unit.side != entry.owner: continue
		var ai = world.house_controllers.get(unit.side,world.skirmish_ai)
		if not is_instance_valid(ai): continue
		if jobs.has("recover") and not world.owned_building_ids(unit.side).has(world.roster_id("GACNST",unit.side)):
			ai._recover_base()
			if not world.actor_alive(unit): continue
		if jobs.has("interaction"):
			var task: Dictionary = jobs.interaction
			if world.actor_alive(task.target) and AlliedAbilities.use(unit,task.action,task.target): ai._army.erase(unit)
		if jobs.has("board"):
			var ship = jobs.board
			if world.actor_alive(ship) and ship.side == unit.side and unit.special.get("ai_carrier") == ship:
				if ship.unit_id == "BFRT":
					preload("res://scripts/world/skirmish_fortress_crew.gd").board(ai, unit, ship)
				else: unit.logistics.request_board(ship)
		if not jobs.has("operations") and not jobs.has("micro"): continue
		if jobs.has("operations"): ai.Operations.unit_decision(ai,unit,null,contacts)
		if jobs.has("micro"): ai.Micro.unit_decision(ai,unit,null,jobs.micro,contacts)

static func _apply(world, unit, order: Dictionary) -> void:
	if order.get("air_relief",false) and preload("res://scripts/world/air_relief.gd").assignment(world,unit).is_empty(): return
	if preload("res://scripts/world/air_relief.gd").blocks_order(world,unit,order): return
	if unit.embarked_in != null or unit.repairing or AlliedAbilities.frozen(unit): return
	match order.kind:
		"rally":
			preload("res://scripts/world/skirmish_assembly.gd").park(world,unit,order.point)
		"advance":
			unit.special.erase("ai_assembly_point")
			unit.special.erase("ai_assembly_cursor")
			unit.special.erase("ai_assembly_retry")
			unit.cancel_stance()
			var goal: Vector2 = order.point
			var used: Array[Vector2] = []
			if not unit.is_air and world.path_service != null:
				if order.batch>0:
					for other in world.units:
						if world.actor_alive(other) and other != unit and other.special.get("ai_formation_batch",-1)==order.batch:
							used.append(other.move_target)
				goal = world.resolve_move_slot(unit,goal,used,order.spacing)
			if preload("res://scripts/world/ai_blocked_route.gd").failed(world,unit,order.point,goal): return
			unit.special.erase("ai_blocked_route")
			unit.order_move(goal,true)
			if order.batch>0 and not unit.is_air: unit.special.ai_formation_batch = order.batch
		"attack":
			var target = order.target
			if is_instance_valid(target) and target is Building and WallArt.is_wall(target.data): return
			if not world.actor_alive(target) or BattleRequest.friendly(unit.side,target.side) or not unit.attack_domain_valid(target): return
			if unit.logistics.ammo_max > 0 and (unit.logistics.ammo == 0 or unit.logistics.air_state in ["returning","rearming"]): return
			# Keep the active approach path and reload/burst for a repeated AI order.
			if unit.attack_ordered and is_same(unit.attack_target, target):
				return
			unit.order_target(target, false, false)
		"detour":
			if not unit.has_move_order or not unit.move_target.is_equal_approx(order.goal): return
			var via: Vector2 = world.path_service.nearest_reachable(unit.position+order.offset,unit.position,false,8,unit.is_amphibious)
			if via.is_finite() and via.distance_to(unit.position)>20:
				unit.order_move(via,order.attack)
				unit.queue_waypoint(order.goal,null,order.attack)
		"move": unit.order_move(order.point,order.attack)
		"guard": unit.order_guard()
		"stop": unit.order_stop()
