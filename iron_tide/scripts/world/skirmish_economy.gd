extends RefCounted
## Paid expansion, timed difficulty subsidies and emergency miner relief.
const Tactics = preload("res://scripts/world/skirmish_tactics.gd")

static func refineries(ai) -> Array:
	return ai.battle.buildings.filter(func(b): return ai.battle.actor_alive(b) and b.side == ai.house_id and b.is_refinery())

static func miners(ai, queued := true) -> int:
	var n := 0
	if ai.enemy_base == "yuri": n = refineries(ai).size()
	for u in ai.battle.units:
		if is_instance_valid(u) and (u.is_harvester or u.unit_id == "SMIN") and u.side == ai.house_id and ai.battle.actor_alive(u): n += 1
	if queued:
		var miner_id: String = ai.battle.roster_id("CMIN", ai.house_id)
		for b in ai.battle.buildings:
			if is_instance_valid(b) and b.side == ai.house_id and ai.battle.actor_alive(b):
				n += b.production.count(miner_id)
				if b.special.get("construction_free_unit", "") == miner_id: n += 1
	return n

static func known_ore(ai) -> Array:
	var world = ai.battle
	return world.get_tree().get_nodes_in_group("resource_nodes").filter(func(n): return world.is_ancestor_of(n) \
		and not n.is_empty() and world.position_explored_by(ai.house_id, n.global_position))

static func desired_miners(ai) -> int:
	var slots := refineries(ai).size() * 2
	return mini(2, slots) if ai.difficulty == 0 else slots

static func reserve(ai) -> float:
	return float(GameData.get_unit(ai.battle.roster_id("CMIN", ai.house_id)).get("cost", 1400)) if miners(ai) < desired_miners(ai) else 0.0

static func replace_miners(ai) -> void:
	var count := miners(ai)
	var wanted := desired_miners(ai)
	if count >= wanted: return
	var uid: String = ai.battle.roster_id("CMIN", ai.house_id)
	var cost := float(GameData.get_unit(uid).get("cost", INF))
	for refinery_pass in [true, false]:
		for b in ai.battle.buildings:
			if not ai.battle.actor_alive(b) or b.side != ai.house_id or b.is_refinery() != refinery_pass or not b.production.is_empty(): continue
			if not b.buildable.has(uid): continue
			if ai.funds - Tactics.committed(ai.battle, ai.house_id) - preload("res://scripts/world/skirmish_power.gd").reserve(ai) < cost: return
			if b.enqueue(uid):
				count += 1
				if count >= wanted: return

# Use the native point search for the many candidates in one synchronous decision.
# No graph connections or pathfinding are needed to find the nearest position.
static func _point_cloud(actors: Array) -> AStar2D:
	var points := AStar2D.new()
	points.reserve_space(maxi(1, actors.size()))
	for index in actors.size():
		points.add_point(index, actors[index].global_position)
	return points

static func _nearest_distance(points: AStar2D, position: Vector2) -> float:
	var index := points.get_closest_point(position)
	return INF if index < 0 else position.distance_to(points.get_point_position(index))

static func placement(ai, step_towards_ore := false) -> Vector2:
	var world = ai.battle
	var ore := known_ore(ai)
	if ore.is_empty(): return Vector2.INF
	var visible: Array = preload("res://scripts/world/skirmish_operations.gd").targets(ai)
	var id: String = world.roster_id("GAPOWR" if step_towards_ore else "GAREFN",ai.house_id)
	var data: Dictionary = GameData.get_building(id)
	var refs := refineries(ai)
	# Prefer an unexploited patch when placing the second refinery.
	var distant := ore.filter(func(node): return refs.all(func(refinery): return refinery.position.distance_to(node.position) > 550.0))
	if not distant.is_empty(): ore = distant
	if step_towards_ore and (distant.is_empty() or not preload("res://scripts/world/build_range_preview.gd").provides_range(data)): return Vector2.INF
	var deposits := _point_cloud(ore)
	var enemies := _point_cloud(visible)
	var frontier := INF
	if step_towards_ore:
		for building in world.buildings:
			if world.actor_alive(building) and building.side == ai.house_id:
				frontier = minf(frontier, _nearest_distance(deposits, building.position))
	# Rank cheap candidates first, then run the normal expensive footprint checks.
	var candidates: Array = []
	var visited := {}
	for anchor in world.buildings:
		if not world.actor_alive(anchor) or anchor.side != ai.house_id or anchor.under_construction: continue
		for distance in [220.0, 320.0, 440.0, 560.0]:
			for direction in 16:
				var point: Vector2 = world.snap_build_pos(anchor.position + Vector2.RIGHT.rotated(TAU * direction / 16.0) * distance)
				if visited.has(point): continue
				visited[point] = true
				if _nearest_distance(enemies, point) < 450.0: continue
				var nearest := _nearest_distance(deposits, point)
				if step_towards_ore:
					if nearest >= frontier - world.BUILD_GRID: continue
				elif nearest > 900.0: continue
				var crowd := 0.0
				for refinery in refs: crowd += maxf(0.0, 550.0 - point.distance_to(refinery.position))
				candidates.append({"point": point, "score": nearest + crowd})
	candidates.sort_custom(func(a, b): return a.score < b.score)
	for candidate in candidates:
		if preload("res://scripts/world/skirmish_tactics.gd").expansion_site_ok(world,ai.house_id,data,candidate.point): return candidate.point
	return Vector2.INF

static func expand(ai) -> bool:
	var world = ai.battle
	if refineries(ai).size() >= maxi(2,ai.Retail.quota("refinery",world.owned_building_ids(ai.house_id).size())): return false
	if not world.owned_building_ids(ai.house_id).has(ai.battle.roster_id("GAWEAP", ai.house_id)) or miners(ai, false) < 2: return false
	if ai.funds - Tactics.committed(world,ai.house_id) - reserve(ai) <= 0.0: return false
	var id: String = world.roster_id("GAREFN",ai.house_id)
	var point := Vector2.INF
	if placement(ai) == Vector2.INF:
		point = placement(ai,true)
		if not point.is_finite(): return false
		id = world.roster_id("GAPOWR",ai.house_id)
	var before: int = world.enemy_struct_queue.size()
	world.request_structure(id, ai.house_id)
	if point.is_finite() and world.enemy_struct_queue.size() > before: ai.ai_state.ai_ore_outpost = point
	return world.enemy_struct_queue.size() > before

static func manage(ai) -> void:
	for unit in ai.battle.units:
		if not ai.battle.actor_alive(unit) or unit.side != ai.house_id or not unit.is_harvester or unit.special.has("yr_skirmish_team") or unit.embarked_in != null or unit.repairing: continue
		unit.auto_harvest_enabled = true
		if unit.harvest_state in ["idle", ""] and not unit.has_move_order:
			unit.cancel_stance()
			# Existing collector prefers reachable, unclaimed ore and a
			# functioning refinery; never reset an active docking/harvest cycle.
			unit._wait_for_auto_harvest(unit.AUTO_HARVEST_IDLE_SECONDS)

static func subsidy(ai, dt: float) -> void:
	if ai.difficulty < 2 or dt <= 0.0: return
	var world = ai.battle
	var elapsed := float(ai.ai_state.get("ai_subsidy_elapsed",0.0)) + dt
	var periods := floori(elapsed / 10.0)
	ai.ai_state.ai_subsidy_elapsed = fmod(elapsed,10.0)
	if periods > 0 and world.has_surviving_assets(ai.house_id):
		world.credit_income(ai.house_id,500.0 * periods,true)

static func relief(ai, dt: float) -> void:
	var world = ai.battle
	if ai.difficulty == 0 or ai.enemy_base == "swarm" or world.paused or world.ended or world.get_tree().paused: return
	var step := float(ai.ai_state.get("ai_economy_elapsed", 0.0)) + maxf(0.0, dt)
	if step < 1.0:
		ai.ai_state.ai_economy_elapsed = step
		return
	ai.ai_state.ai_economy_elapsed = 0.0
	if miners(ai, false) > 0:
		ai.ai_state.ai_relief_elapsed = 0.0
		return
	var operational := refineries(ai).any(func(b): return b.is_operational())
	if refineries(ai).any(func(b): return b.special.get("construction_free_unit", "") == ai.battle.roster_id("CMIN", ai.house_id)):
		ai.ai_state.ai_relief_elapsed = 0.0
		return
	var cost := float(GameData.get_unit(ai.battle.roster_id("CMIN", ai.house_id)).get("cost", 1400))
	var queued := miners(ai) - miners(ai, false)
	var producer: bool = world.buildings.any(func(b): return world.actor_alive(b) and b.side == ai.house_id and b.is_operational() \
		and ((b.production.is_empty() and b.can_queue(ai.battle.roster_id("CMIN", ai.house_id))) or b.production == [ai.battle.roster_id("CMIN", ai.house_id)]))
	if not operational or not producer or miners(ai, false) > 0 or queued > 1 or ai.funds - Tactics.committed(world,ai.house_id) >= cost or known_ore(ai).is_empty():
		ai.ai_state.ai_relief_elapsed = 0.0
		return
	var elapsed := float(ai.ai_state.get("ai_relief_elapsed", 0.0)) + step
	ai.ai_state.ai_relief_elapsed = elapsed
	if elapsed < 45.0: return
	ai.ai_state.ai_relief_elapsed = 0.0
	var used := float(ai.ai_state.get("ai_relief_total", 0.0))
	var cap := cost * (1 if ai.difficulty == 1 else 2)
	# Finish existing commitments plus one replacement, or the already queued
	# replacement. The per-match cap prevents repeated treasury refills.
	var need := maxf(0.0, Tactics.committed(world,ai.house_id) + (cost if queued == 0 else 0.0) - ai.funds)
	var grant := minf(maxf(0.0, cap - used), need)
	if grant <= 0.0: return
	world.credit_side(ai.house_id, grant)
	ai.ai_state.ai_relief_total = used + grant
