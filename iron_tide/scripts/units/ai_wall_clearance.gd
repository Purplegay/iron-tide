extends RefCounted
## Walls are navigation obstacles, never strategic targets. Probe only a failed
## route, at most once per second, and preserve the order while opening a gap.
const STATE := "ai_wall_clearance"
const GOAL := "ai_wall_goal"
const PROBE := "ai_wall_probe"

static func wall(target) -> bool:
	return is_instance_valid(target) and target is Building and WallArt.is_wall(target.data)

static func allowed(unit, target) -> bool:
	if not BattleRequest.is_ai_house(unit.side) or not wall(target): return true
	return is_same(unit.special.get(STATE,{}).get("wall"),target)

static func cancel(unit) -> void:
	unit.special.erase(STATE)
	unit.special.erase(GOAL)
	unit.special.erase(PROBE)

static func remember(unit, goal:Vector2) -> void:
	if not BattleRequest.is_ai_house(unit.side) or unit.is_air or unit.is_naval or unit.is_harvester or unit.unit_id=="R3APOC": return
	var world=unit._battle_world()
	if world==null or world.wall_cells.is_empty(): return
	unit.special[GOAL]=goal
	# Keep a partial route's real destination so reaching its near-side endpoint
	# does not silently discard the order before clearance can be considered.
	unit.move_target=goal

static func restore(unit) -> void:
	if not unit.special.has(STATE): return
	var previous:Dictionary=unit.special[STATE]
	unit.special.erase(STATE)
	unit._cancel_burst()
	unit.attack_target=previous.target if AlliedAbilities.alive(previous.target) else null
	unit.attack_ordered=previous.ordered and unit.attack_target!=null
	unit.attack_move=previous.attack_move
	unit.has_move_order=previous.moving
	unit.move_target=previous.goal
	unit.special[GOAL]=previous.goal
	if unit.has_move_order and unit.ai_path_allowed(): unit._repath_now()

static func update(unit) -> bool:
	if not BattleRequest.is_ai_house(unit.side): return false
	if wall(unit.attack_target) and not unit.special.has(STATE):
		# Discard old AI orders from saves made before walls were excluded.
		unit.order_stop(false)
	var world=unit._battle_world()
	if world==null or world.path_service==null or world.wall_cells.is_empty() or unit.is_air or unit.is_naval or unit.is_harvester or unit.unit_id=="R3APOC" or unit._deployed or unit.repairing or unit.embarked_in!=null or unit.fire_stance=="none" or unit.weapon.is_empty() or unit.special.has("action"):
		restore(unit)
		return false
	var previous:Dictionary=unit.special.get(STATE,{})
	if not previous.is_empty() and not world.actor_alive(previous.wall):
		restore(unit)
		previous={}
		unit.special.erase(PROBE)
	var goal:Vector2=previous.get("goal",unit.special.get(GOAL,unit.move_target))
	if previous.is_empty():
		if not unit.has_move_order: return false
		if AlliedAbilities.alive(unit.attack_target) and unit._weapon_target_valid(unit.attack_target): return false
		if unit.attack_ordered and AlliedAbilities.alive(unit.attack_target): goal=unit._attack_approach(unit.attack_target)
	var probe:Dictionary=unit.special.get(PROBE,{})
	var epoch:int=world.path_service.epoch
	if probe.get("epoch",-1)==epoch and probe.get("goal",Vector2.INF)==goal and unit._anim<float(probe.get("next",0)):
		return not previous.is_empty()
	if not unit.ai_path_allowed(): return not previous.is_empty()
	unit.special[PROBE]={"epoch":epoch,"goal":goal,"next":unit._anim+1.0}
	var blocker=find_blocker(unit,world,goal)
	if blocker==null:
		restore(unit)
		return false
	if previous.is_empty():
		previous={"goal":goal,"target":unit.attack_target,"ordered":unit.attack_ordered,"attack_move":unit.attack_move,"moving":unit.has_move_order}
	previous.wall=blocker
	unit.special[STATE]=previous
	unit.attack_target=blocker
	unit.attack_ordered=false
	unit.attack_move=true
	unit.move_target=goal
	return true

static func reaches(path:PackedVector2Array,goal:Vector2) -> bool:
	return path.size()>=2 and path[-1].distance_to(goal)<=1.0

# A wall outside weapon reach cannot be the clearance target. Use the live
# registry and each wall's cached footprint radius as a conservative bound.
static func wall_in_reach(unit: Unit, world: Battle) -> bool:
	var fixed_range := unit.unit_id not in ["DRED", "DEST"] and not unit.data.has("anti_air_weapon") and unit.logistics.passengers.is_empty()
	var nearby: Array
	if world.wall_cells.size() <= 32:
		nearby = world.wall_cells.values()
	elif fixed_range:
		nearby = world.neighborhood.nearby(unit.global_position, unit.attack_range + world.neighborhood.max_footprint + 0.01)
	else:
		# A target-dependent weapon has no single safe spatial query radius.
		return true
	for actor in nearby:
		if not actor is Building or not world.actor_alive(actor) or not WallArt.is_wall(actor.data): continue
		var wall: Building = actor
		if BattleRequest.friendly(unit.side, wall.side): continue
		var reach := unit.attack_range if fixed_range else OpenTopped.command_range(unit, wall)
		var extent := reach + wall.footprint_radius() + 0.01
		if unit.global_position.distance_squared_to(wall.global_position) <= extent * extent: return true
	return false

static func find_blocker(unit,world,goal:Vector2):
	if world.wall_cells.is_empty(): return null
	# A usable detour is preferable to any demolition, even when a wall is closer.
	if unit._path_epoch==world.path_service.epoch and reaches(unit._path_pts,goal): return null
	if not wall_in_reach(unit,world): return null
	if reaches(world.path_for_unit(unit,goal),goal): return null
	var route:PackedVector2Array=world.path_service.find_path(unit.global_position,goal,false,6000,unit.is_amphibious,[],true)
	if not reaches(route,goal): return null # A cliff/building, not just walls, blocks this goal.
	var first=null
	for i in range(1,route.size()):
		var nearest:=INF
		for candidate in world.wall_cells.values():
			if not world.actor_alive(candidate): continue
			var rect:=Placement.aabb(world.footprint_of(candidate),candidate.global_position).grow(unit.radius)
			var entry:=segment_entry(route[i-1],route[i],rect)
			if entry<nearest:
				nearest=entry
				first=candidate
		if first!=null: break
	if first==null or BattleRequest.friendly(unit.side,first.side) or not world.actor_visible_to(unit.side,first): return null
	if not unit.attack_domain_valid(first): return null
	var distance:=CommandoCombat.distance_to(unit,first)
	if distance<unit.min_range or distance>OpenTopped.command_range(unit,first): return null
	return first

static func segment_entry(start:Vector2,end:Vector2,rect:Rect2) -> float:
	var direction:=end-start
	var near:=0.0
	var far:=1.0
	for axis in 2:
		if absf(direction[axis])<0.0001:
			if start[axis]<rect.position[axis] or start[axis]>rect.end[axis]: return INF
		else:
			var a:float=(rect.position[axis]-start[axis])/direction[axis]
			var b:float=(rect.end[axis]-start[axis])/direction[axis]
			near=maxf(near,minf(a,b))
			far=minf(far,maxf(a,b))
			if near>far: return INF
	return near
