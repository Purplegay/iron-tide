extends RefCounted
## Candidates only. Ownership, visibility and weapon eligibility are live checks.
const CELL := 256.0
var buckets := {}
var membership := {}
# Same relocation order, with structures omitted for unit-only movement queries.
var unit_buckets := {}
var unit_membership := {}
var structure_buckets := {}
var max_footprint := 0.0
var max_unit_radius := 0.0

func register(actor: Node2D, extent: float, structure: bool) -> void:
	if structure:
		max_footprint = maxf(max_footprint, extent)
	else:
		max_unit_radius = maxf(max_unit_radius, extent)
	relocate(actor)

func relocate(actor: Node2D) -> void:
	var cell := Vector2i((actor.global_position / CELL).floor())
	if membership.get(actor) == cell:
		return
	remove(actor)
	membership[actor] = cell
	buckets.get_or_add(cell, []).append(actor)
	if actor is Unit:
		unit_membership[actor] = cell
		unit_buckets.get_or_add(cell, []).append(actor)
	else:
		structure_buckets.get_or_add(cell, []).append(actor)

func remove(actor: Node2D) -> void:
	if not membership.has(actor):
		return
	var cell: Vector2i = membership[actor]
	var bucket: Array = buckets[cell]
	bucket.erase(actor)
	if bucket.is_empty():
		buckets.erase(cell)
	membership.erase(actor)
	if unit_membership.erase(actor):
		var units: Array = unit_buckets[cell]
		units.erase(actor)
		if units.is_empty(): unit_buckets.erase(cell)
	else:
		var structures: Array = structure_buckets[cell]
		structures.erase(actor)
		if structures.is_empty(): structure_buckets.erase(cell)

func nearby(point: Vector2, reach: float, units_only := false) -> Array:
	var _call_log_scope = preload("res://scripts/world/battle_call_counters.gd").enter(40)
	var occupants: Dictionary = unit_membership if units_only else membership
	var cells: Dictionary = unit_buckets if units_only else buckets
	if not is_finite(reach):
		return occupants.keys()
	var margin := Vector2.ONE * reach
	var first := Vector2i(((point - margin) / CELL).floor())
	var last := Vector2i(((point + margin) / CELL).floor())
	if (last.x - first.x + 1) * (last.y - first.y + 1) > membership.size():
		return occupants.keys()
	var result: Array = []
	preload("res://scripts/world/battle_call_counters.gd").iterations(40,(last.x-first.x+1)*(last.y-first.y+1))
	for y in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			var bucket = cells.get(Vector2i(x,y))
			if bucket != null:
				result.append_array(bucket)
	return result

# Intersect each row of the existing grid with the two conservative range circles.
# In the shared columns the original mixed bucket preserves relocation order.
func target_contacts(point: Vector2, unit_reach: float, structure_reach: float) -> Array:
	var _call_log_scope = preload("res://scripts/world/battle_call_counters.gd").enter(40)
	var outer := maxf(unit_reach, structure_reach)
	var margin := Vector2.ONE * outer
	var first := Vector2i(((point - margin) / CELL).floor())
	var last := Vector2i(((point + margin) / CELL).floor())
	if (last.x - first.x + 1) * (last.y - first.y + 1) > membership.size():
		return membership.keys()
	var result: Array = []
	var visited := 0
	var units_inside := unit_reach <= structure_reach
	var fringe := structure_buckets if units_inside else unit_buckets
	# One pixel of slack keeps float32 position rounding conservative at a tangent.
	var inner_sq := pow(minf(unit_reach, structure_reach) + 1.0, 2.0)
	var outer_sq := pow(outer + 1.0, 2.0)
	for y in range(first.y, last.y + 1):
		var dy := maxf(0.0, maxf(y * CELL - point.y, point.y - (y + 1) * CELL))
		var dy_sq := dy * dy
		if dy_sq > outer_sq: continue
		var dx := sqrt(outer_sq - dy_sq)
		var left := maxi(first.x, floori((point.x - dx) / CELL))
		var right := mini(last.x, floori((point.x + dx) / CELL))
		var shared_left := right + 1
		var shared_right := left - 1
		if dy_sq <= inner_sq:
			dx = sqrt(inner_sq - dy_sq)
			shared_left = floori((point.x - dx) / CELL)
			shared_right = floori((point.x + dx) / CELL)
		visited += right - left + 1
		for x in range(left, right + 1):
			var cells := buckets if x >= shared_left and x <= shared_right else fringe
			var bucket = cells.get(Vector2i(x, y))
			if bucket != null: result.append_array(bucket)
	preload("res://scripts/world/battle_call_counters.gd").iterations(40, visited)
	return result
