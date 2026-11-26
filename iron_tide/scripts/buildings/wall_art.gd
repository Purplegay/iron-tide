class_name WallArt
extends RefCounted
## Independent wall adapter. Frame bits follow the local SHP: NE/SE/SW/NW.
## One build cell is 40 world units; native overlay pitch is 60x30 art pixels.

const CELL := 40.0
const SCALE := CELL * sqrt(2.0) / 60.0
const DIRECTIONS := [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]

static func is_wall(data: Dictionary) -> bool:
	return (data.get("tags", []) as Array).has("wall")

static func crushable_fence(actor) -> bool:
	if not actor is Building or not is_wall(actor.data): return false
	var rules: Dictionary = GameData.ra2_source_buildings.get(actor.building_id, {}).get("extra", {})
	return GameData._ra2_flag(rules.get("Crushable", false))

static func cell_at(point: Vector2) -> Vector2i:
	return Vector2i((point / CELL + Vector2(0.5, 0.5)).floor())

static func destroys_wall(id: String) -> bool:
	return GameData.warhead_combat_rule(id).get("wall_absolute_destroyer", false)

static func can_damage(id: String, armor: String) -> bool:
	var rules := GameData.warhead_combat_rule(id)
	# Scripted damage (e.g. crushing) and expansion weapons have separate rules.
	if rules.is_empty() or id.begins_with("RA3_"): return true
	return rules.get("wall", false) or rules.get("wall_absolute_destroyer", false) \
		or (armor == "wood" and rules.get("wood", false))

static func shot_blocked(world, source, target, weapon: Dictionary) -> bool:
	var warhead := str(weapon.get("ra2_warhead", ""))
	if target is Building and target.ignores_warhead(warhead): return true
	if not world is Battle or world.wall_cells.is_empty(): return false
	var projectile := GameData.projectile_combat_rule(str(weapon.get("ra2_projectile", "")))
	if not projectile.get("subject_to_walls", false): return false
	var rules := GameData.warhead_combat_rule(warhead)
	if rules.get("wall", false) or rules.get("wall_absolute_destroyer", false): return false
	# Walk crossed placement cells, including both ends. At an exact grid
	# corner only the diagonal cell is entered.
	var start: Vector2 = source.global_position / CELL + Vector2(0.5, 0.5)
	var end: Vector2 = target.global_position / CELL + Vector2(0.5, 0.5)
	var delta := end - start
	var cell := Vector2i(start.floor())
	var last := Vector2i(end.floor())
	var step := Vector2i(delta.sign())
	var stride := Vector2(INF if step.x == 0 else absf(1.0 / delta.x), INF if step.y == 0 else absf(1.0 / delta.y))
	var cross_x := INF if step.x == 0 else (cell.x + int(step.x > 0) - start.x) / delta.x
	var cross_y := INF if step.y == 0 else (cell.y + int(step.y > 0) - start.y) / delta.y
	while true:
		var wall = world.wall_cells.get(cell)
		if AlliedAbilities.alive(wall) and not wall.under_construction and wall != target: return true
		if cell == last: break
		var advance_x := cell.x != last.x and (cell.y == last.y or cross_x <= cross_y)
		var advance_y := cell.y != last.y and (cell.x == last.x or cross_y <= cross_x)
		if advance_x:
			cell.x += step.x
			cross_x += stride.x
		if advance_y:
			cell.y += step.y
			cross_y += stride.y
	return false

static func supported(data: Dictionary, art: Dictionary) -> bool:
	return is_wall(data) and int(art.get("wall_layout", {}).get("variants", 0)) == 16

static func mask_at(position: Vector2, id: String, side: String, buildings: Array, pitch := CELL) -> int:
	var mask := 0
	for b in buildings:
		if not is_instance_valid(b) or b.is_queued_for_deletion() or b.is_dead() or b.under_construction:
			continue
		if b.building_id != id or b.side != side:
			continue
		var offset: Vector2 = b.global_position - position
		for i in 4:
			if offset.distance_to(DIRECTIONS[i] * pitch) < 0.1:
				mask |= 1 << i
	return mask

static func frame(art: Dictionary, mask: int, health: float) -> int:
	var levels := int(art.get("wall_layout", {}).get("damage_levels", 1))
	var state := 0 if health > 0.66 else (1 if health > 0.33 else 2)
	return mask + mini(state, levels - 1) * 16

## Use the same cardinal, same-material connectivity as the wall artwork.
static func connected_component(root, buildings: Array) -> Array:
	if not is_instance_valid(root) or not is_wall(root.data) or root.side != "ally" \
		or root.is_dead() or root.is_queued_for_deletion() or root.under_construction:
		return []
	var by_cell: Dictionary = {}
	for b in buildings:
		if not is_instance_valid(b) or b.is_dead() or b.is_queued_for_deletion() or b.under_construction:
			continue
		if b.side != root.side or b.building_id != root.building_id: continue
		var offset: Vector2 = b.global_position - root.global_position
		var cell := Vector2i((offset / CELL).round())
		if offset.distance_to(Vector2(cell) * CELL) < 0.1: by_cell[cell] = b
	var result: Array = []
	var pending: Array[Vector2i] = [Vector2i.ZERO]
	var visited: Dictionary = {Vector2i.ZERO: true}
	var index := 0
	while index < pending.size():
		var cell := pending[index]
		index += 1
		if not by_cell.has(cell): continue
		result.append(by_cell[cell])
		for direction in DIRECTIONS:
			var neighbor := cell + Vector2i(direction)
			if not visited.has(neighbor) and by_cell.has(neighbor):
				visited[neighbor] = true
				pending.append(neighbor)
	return result

static func footprint() -> PackedVector2Array:
	var half := CELL / 2.0
	return PackedVector2Array([Vector2(-half, -half), Vector2(half, -half),
		Vector2(half, half), Vector2(-half, half)])

static func lift(art: Dictionary, radius: float) -> float:
	# Keep a single anchor across all junction/damage frames, center the base
	# of the isolated wall on its grid cell, and reuse RA2Art's picking transform.
	var anchor := RA2Art.anchor(art, [0])
	var base := RA2Art.base_diamond(art, [0])
	var center_y := anchor.y
	if base.size() == 4:
		center_y = (base[0].y + base[1].y + base[2].y + base[3].y) / 4.0
	return radius * 0.35 + (center_y - anchor.y) * SCALE

static func refresh_neighbors(wall: Node) -> void:
	if not wall.is_inside_tree():
		return
	for other in wall.get_tree().get_nodes_in_group("buildings"):
		if is_instance_valid(other) and other != wall and other.building_id == wall.building_id:
			if other.global_position.distance_to(wall.global_position) <= float(wall.special.get("native_wall_pitch", CELL)) + 0.1:
				other.queue_redraw()

## One plan drives the ready preview and placement. Additional cells are paid
## individually; a blocked direction stops there, never fills an unseen gap.
static func plan(world, id: String, side: String, origin: Vector2) -> Dictionary:
	var data: Dictionary = GameData.get_building(id)
	var points: Array[Vector2] = []
	var blocked: Array[Vector2] = []
	var reason := ""
	var cost := float(data.get("cost", 100))
	var funds: float = INF if side == "ally" and GM.infinite_funds else world.funds_for(side)
	if not is_wall(data): return {"points": points, "blocked": blocked, "cost": 0.0, "reason": ""}
	for direction in DIRECTIONS:
		var length := 0
		for distance in range(2, 6):
			var endpoint: Vector2 = origin + direction * CELL * distance
			for other in world.buildings:
				if world.actor_alive(other) and other.side == side and other.building_id == id and not other.under_construction and other.position.distance_to(endpoint) < 0.1:
					length = distance
					break
			if length > 0: break
		for distance in range(1, length):
			var point: Vector2 = origin + direction * CELL * distance
			var status: Dictionary = world.build_spot_ok(point, data, true, side)
			if not status.ok or funds < cost:
				blocked.append(point)
				reason = str(status.reason) if not status.ok else "资金不足，红格不会补齐"
				break
			funds -= cost
			points.append(point)
	return {"points": points, "blocked": blocked, "cost": cost * points.size(), "reason": reason}

static func bridge(world, wall) -> int:
	if not is_instance_valid(wall) or not is_wall(wall.data): return 0
	var proposed := plan(world, wall.building_id, wall.side, wall.position)
	var count := 0
	for point in proposed.points:
		if not world.build_spot_ok(point, wall.data, true, wall.side).ok: break
		if not world.spend_side(wall.side, float(wall.data.get("cost", 100))): break
		world._place_building(wall.building_id, wall.side, point, true, true)
		count += 1
	return count

static func paint_plan(world, id: String, origin: Vector2) -> void:
	var proposed := plan(world, id, "ally", origin)
	var data: Dictionary = GameData.get_building(id)
	var all_points: Array = [origin]
	all_points.append_array(proposed.points)
	for point in all_points:
		var mask := mask_at(point, id, "ally", world.buildings)
		for neighbor in all_points:
			for i in 4:
				if Vector2(neighbor - point).distance_to(DIRECTIONS[i] * CELL) < 0.1: mask |= 1 << i
		world._draw_build_ghost(data, point, true, mask)
		world._draw_world_poly(footprint(), point, Color(0.5, 1.0, 0.6, 0.85), 2.0)
	for point in proposed.blocked:
		world._draw_world_poly(footprint(), point, Color(1.0, 0.3, 0.25, 0.9), 2.0)
