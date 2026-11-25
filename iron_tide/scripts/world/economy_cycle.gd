extends RefCounted
## Independent Godot adapter. Rule values come from the local rules.ini export;
## seconds, continuous-world spacing and bounded spread are explicit adapters.

const MAX_ORE_NODES := 512
const ChronoMinerFx = preload("res://scripts/world/chrono_miner_fx.gd")

## One whole-load transfer after parking; independent of cargo capacity/type.
static func unload_seconds() -> float:
	return maxf(0.01, float(GameData.ra2_economy.get("adapter", {}).get("unload_seconds", 1.0)))

## Preserve elapsed fraction if an older compatible snapshot stored a 4s unload.
## Already-paid cargo was removed at payment time; never restore or repay it.
static func normalize_unload(unit) -> void:
	var seconds := unload_seconds()
	if not is_equal_approx(unit.unload_time, seconds):
		if unit.harvest_state == "unloading":
			unit._unload_timer = clampf(unit._unload_timer / maxf(0.01, unit.unload_time), 0.0, 1.0) * seconds
		unit.unload_time = seconds
	unit._unload_work = 0.0 # Retained only for legacy snapshot compatibility.

static func income_factor(world, owner: String) -> float:
	var count := 0
	for b in world.buildings:
		if is_instance_valid(b) and not b.is_queued_for_deletion() and b.hp > 0.0 \
				and b.side == owner and b.data.get("tags", []).has("purifier") and b.is_operational():
			count += 1
	return 1.0 + count * float(GameData.ra2_economy.get("purifier_bonus", 0.25))

# Each point uses the same nine terrain samples and exact footprint test. A
# refinery entrance can share the static candidates for its five adjacent points.
static func _static_sites_clear(world, sites: PackedVector2Array, radius: float, buildings: Array, ignore_building, ignore_ore) -> bool:
	for pos in sites:
		for i in 9:
			var p := pos if i == 0 else pos + Vector2.RIGHT.rotated(TAU * (i - 1) / 8.0) * radius
			if p.x < 0.0 or p.y < 0.0 or p.x >= world.map_size or p.y >= world.map_size or world.in_water_world(p):
				return false
	for candidate in buildings:
		if not is_instance_valid(candidate) or not candidate is Building or candidate == ignore_building: continue
		var building: Building = candidate
		if building._dead or building.is_queued_for_deletion(): continue
		var center := building.global_position
		var extent := radius + building.footprint_radius() + 0.01
		for pos in sites:
			if pos.distance_squared_to(center) <= extent * extent and Placement.circle_hits_poly(building.footprint_poly(), pos, radius, center):
				return false
	for group in ["obstacles", "native_ore_drills"]:
		for node in world.get_tree().get_nodes_in_group(group):
			if node == ignore_ore or not world.is_ancestor_of(node): continue
			for pos in sites:
				if pos.distance_to(node.global_position) < radius + float(node.radius) * 0.85: return false
	return true

static func landing_clear(world, pos: Vector2, radius: float, ignore_unit = null, ignore_building = null, ignore_ore = null, traverse_ore := false, ignore_traffic := false) -> bool:
	var indexed: bool = world is Battle and world.units.size() >= 96
	var nearby: Array = []
	if indexed:
		var extent: float = maxf(world.neighborhood.max_footprint, world.neighborhood.max_unit_radius + 3.0)
		nearby = world.neighborhood.nearby(pos, radius + extent)
	if not _static_sites_clear(world, PackedVector2Array([pos]), radius, nearby if indexed else world.buildings, ignore_building, ignore_ore):
		return false
	if not ignore_traffic:
		for u in (nearby if indexed else world.units):
			if u != ignore_unit and is_instance_valid(u) and u is Unit and not u._dead and not u.is_air and u.embarked_in == null:
				if pos.distance_to(u.global_position) < radius + u.radius + 3.0:
					return false
	if not traverse_ore:
		var nodes: Array = world.ore_neighborhood.nearby(pos, radius + world.ore_neighborhood.max_unit_radius) if indexed else world.get_tree().get_nodes_in_group("resource_nodes")
		for node in nodes:
			if node == ignore_ore or not world.is_ancestor_of(node): continue
			if node.native_variant >= 0 and node.is_empty(): continue
			if pos.distance_to(node.global_position) < radius + float(node.radius) * 0.85: return false
	return true

## Moving miners cross ore; resource growth and other placement callers still reserve it.
static func miner_landing_clear(world, pos: Vector2, radius: float, miner) -> bool:
	return landing_clear(world, pos, radius, miner, null, null, true)

## Static access only: a vehicle waiting in the FIFO must not cause refinery hopping.
static func refinery_accessible(miner, refinery) -> bool:
	var world = miner._battle_world()
	if world == null:
		return true
	var dock: Vector2 = refinery.refinery_dock_point(miner.radius)
	var stage: Vector2 = dock + refinery.refinery_dock_direction() * miner.DOCK_STAGE_BACK
	var sites := PackedVector2Array()
	for i in 5: sites.append(stage.lerp(dock, i / 4.0))
	var radius: float = miner.radius + 3.0
	var buildings: Array = world.buildings
	if world is Battle and world.units.size() >= 96:
		var center := stage.lerp(dock, 0.5)
		buildings = world.neighborhood.nearby(center, radius + world.neighborhood.max_footprint + center.distance_to(stage) + 0.01)
	if not _static_sites_clear(world, sites, radius, buildings, refinery, null): return false
	# Chrono miners can return across disconnected regions; ordinary miners cannot.
	return miner.unit_id == "CMIN" or world.path_service.nearest_reachable(stage, miner.global_position, false, 2).distance_to(stage) <= miner.DOCK_STOP

static func chrono_return(unit, delta: float) -> bool:
	if unit.unit_id != "CMIN" or unit.cargo <= 0.0 or unit._dock_phase != 0:
		return false
	var world = unit._battle_world()
	if world == null or world.paused or world.ended:
		return true
	var target: Vector2 = unit._dock_stage()
	if unit.global_position.distance_to(target) <= unit.radius * 2.0 + 24.0:
		unit.chrono_return_elapsed = 0.0
		unit.chrono_return_blocked = false
		return false
	unit.velocity = Vector2.ZERO
	unit._clear_field()
	var delay := maxf(0.01, float(GameData.ra2_economy.get("chrono_return_seconds", 16.0 / 15.0)))
	unit.chrono_return_elapsed = minf(delay, unit.chrono_return_elapsed + maxf(0.0, delta))
	unit.chrono_return_blocked = unit._dock_occupied() or not miner_landing_clear(world, target, unit.radius + 3.0, unit)
	if unit.chrono_return_elapsed < delay or unit.chrono_return_blocked:
		return true
	ChronoMinerFx.spawn(world, unit.global_position, "WARPOUT")
	# Arrival reuses the small blue-white ring as a presentation adapter.
	# General.WarpIn is a brown ground ring, not the miner's blue warp effect.
	ChronoMinerFx.spawn(world, target, "WARPOUT")
	# One local miner sound, never the Chronosphere destination's StartSound.
	if world.position_visible_to("ally", target):
		Ra2Sfx.play("ChronoMinerTeleport", target)
	elif world.position_visible_to("ally", unit.global_position):
		Ra2Sfx.play("ChronoMinerTeleport", unit.global_position)
	unit.global_position = target
	unit._last_water_pos = target
	unit._stuck_reset()
	unit._back_in = false
	unit.chrono_return_elapsed = 0.0
	return true

static func miner_status(unit) -> String:
	if unit.repairing: return "维修中"
	if unit.has_move_order:
		return "执行移动指令"
	if unit.hold_position: return "固守中 · 不自动采矿"
	if unit.harvest_state in ["idle", ""]:
		return "空闲 · %d 秒后尝试自动采矿" % ceili(BattleClock.real_seconds(maxf(0.0, unit.AUTO_HARVEST_IDLE_SECONDS - unit.auto_harvest_idle))) if unit.auto_harvest_enabled else "空闲 · 自动采矿已关闭"
	if unit._harvest_exit != Vector2.INF:
		return "驶离卸矿口"
	if unit._dock_locked and is_instance_valid(unit._dock_home):
		var place: int = unit._dock_home.refinery_traffic.index_of(unit._dock_home, unit)
		if place > 0:
			return "排队卸矿 · 前方 %d 辆" % place
	if unit.harvest_state in ["to_base", "unloading"] and not is_instance_valid(unit.home_base):
		return "等待可用矿场"
	if unit.chrono_return_blocked:
		return "传送等待 · 矿场入口被占用"
	if unit.chrono_return_elapsed > 0.0:
		var delay := maxf(0.01, float(GameData.ra2_economy.get("chrono_return_seconds", 16.0 / 15.0)))
		return "超时空返场 · %d%%" % int(unit.chrono_return_elapsed / delay * 100.0)
	match unit.harvest_state:
		"harvesting": return "正在采矿"
		"unloading": return "正在卸矿"
		"to_base": return "倒车入库" if unit._back_in else "返回矿场"
	return "前往矿区" if is_instance_valid(unit.resource_node) else "等待可采矿石"

static func tick(world, delta: float) -> void:
	if delta <= 0.0 or world.paused or world.ended:
		return
	if not BattleRequest.native_ore_map().is_empty():
		preload("res://scripts/world/native_ore.gd").tick(world, delta)
		return
	if BattleRequest.extensions_enabled():
		return
	var interval := maxf(1.0, float(GameData.ra2_economy.get("growth", {}).get("interval_seconds", 300.0)))
	world.ore_growth_elapsed += delta
	# Bound catch-up work; carry any remaining elapsed time to subsequent frames.
	for i in 4:
		if world.ore_growth_elapsed < interval:
			break
		world.ore_growth_elapsed -= interval
		grow(world)

static func grow(world) -> void:
	var cells: Array = []
	var full: Array = []
	var rules: Dictionary = GameData.ra2_economy.get("growth", {})
	var fraction := clampf(float(rules.get("fraction", 0.06)), 0.0, 1.0)
	for node in world.get_tree().get_nodes_in_group("resource_nodes"):
		if not world.is_ancestor_of(node):
			continue
		cells.append(node)
		if node.resource_kind != "ore" or node.is_empty():
			continue
		# Only cells already full at cycle start seed neighbors: no same-cycle cascade.
		if node.amount >= node.max_amount:
			full.append(node)
		fill(node, minf(node.max_amount, node.amount + node.max_amount * fraction))
	var budget := ceili(full.size() * clampf(float(rules.get("spread_fraction", 0.06)), 0.0, 1.0))
	for source in full:
		if budget <= 0:
			break
		var spacing := maxf(46.0, source.radius * 2.1)
		for direction in [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]:
			var pos: Vector2 = source.global_position + direction * spacing
			var empty = null
			for cell in cells:
				if cell.resource_kind == "ore" and cell.is_empty() and pos.distance_to(cell.global_position) < spacing * 0.55:
					empty = cell
					break
			if empty != null:
				pos = empty.global_position
			if not landing_clear(world, pos, source.radius * 0.85, null, null, empty):
				continue
			if empty == null:
				if cells.size() >= MAX_ORE_NODES:
					continue
				empty = preload("res://scripts/world/resource_node.gd").new()
				empty.position = pos
				empty.radius = source.radius
				empty.max_amount = source.max_amount
				empty.amount = empty.max_amount / 12.0
				empty.z_index = DepthLayers.GROUND_OBJ
				world.add_child(empty)
				cells.append(empty)
			fill(empty, empty.max_amount / 12.0)
			budget -= 1
			break

static func fill(cell, value: float) -> void:
	cell.amount = value
	cell.depleted = cell.is_empty()
	cell.queue_redraw()
