extends RefCounted
## Candidates only. Ownership, visibility and weapon eligibility are live checks.
const CELL := 256.0
const TRAFFIC_CELL := 64.0
var _traffic_buckets: Dictionary = {}
var _traffic_membership: Dictionary = {}
var buckets := {}
var membership := {}
# Same relocation order, with structures omitted for unit-only movement queries.
var unit_buckets := {}
var unit_membership := {}
var unit_membership_revision := 0
var _unit_cell_revisions := {}
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
		if actor is Unit: _relocate_traffic(actor)
		return
	remove(actor)
	membership[actor] = cell
	buckets.get_or_add(cell, []).append(actor)
	if actor is Unit:
		unit_membership[actor] = cell
		unit_buckets.get_or_add(cell, []).append(actor)
		_touch_unit_cell(cell)
		_relocate_traffic(actor)
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
		_remove_traffic(actor)
		var units: Array = unit_buckets[cell]
		units.erase(actor)
		if units.is_empty(): unit_buckets.erase(cell)
		_touch_unit_cell(cell)
	else:
		var structures: Array = structure_buckets[cell]
		structures.erase(actor)
		if structures.is_empty(): structure_buckets.erase(cell)

# Membership changes only: same-cell movement is checked by the caller's watch.
func _touch_unit_cell(cell: Vector2i) -> void:
	unit_membership_revision += 1
	if unit_buckets.has(cell):
		_unit_cell_revisions[cell] = unit_membership_revision
	else:
		_unit_cell_revisions.erase(cell)

# Snapshot every covered cell, including empty cells, without changing query order.
func unit_region_stamp(point: Vector2, reach: float) -> Dictionary:
	if not is_finite(reach):
		return {"first":Vector2i.ZERO,"last":Vector2i.ZERO,"versions":{},"global":unit_membership_revision,"all":true}
	var margin := Vector2.ONE * reach
	var first := Vector2i(((point - margin) / CELL).floor())
	var last := Vector2i(((point + margin) / CELL).floor())
	var all_units := (last.x - first.x + 1) * (last.y - first.y + 1) > membership.size()
	var versions := {}
	if not all_units:
		for y in range(first.y, last.y + 1):
			for x in range(first.x, last.x + 1):
				var cell := Vector2i(x, y)
				versions[cell] = _unit_cell_revisions.get(cell, 0)
	return {"first":first,"last":last,"versions":versions,"global":unit_membership_revision,"all":all_units}

func unit_region_unchanged(stamp: Dictionary, point: Vector2, reach: float) -> bool:
	if stamp.is_empty(): return false
	# A full-query snapshot already includes every registered unit.
	if stamp.all:
		return int(stamp["global"]) == unit_membership_revision
	if not is_finite(reach): return false
	var margin := Vector2.ONE * reach
	var first := Vector2i(((point - margin) / CELL).floor())
	var last := Vector2i(((point + margin) / CELL).floor())
	var old_first: Vector2i = stamp.first
	var old_last: Vector2i = stamp.last
	if first.x < old_first.x or first.y < old_first.y or last.x > old_last.x or last.y > old_last.y:
		return false
	if int(stamp["global"]) == unit_membership_revision: return true
	var versions: Dictionary = stamp.versions
	for cell: Vector2i in versions:
		if int(versions[cell]) != int(_unit_cell_revisions.get(cell, 0)):
			return false
	# Unrelated distant changes need not be rechecked by the next consumer.
	stamp["global"] = unit_membership_revision
	return true

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

func _relocate_traffic(actor: Unit) -> void:
	var cell := Vector2i((actor.global_position / TRAFFIC_CELL).floor())
	if _traffic_membership.get(actor) == cell: return
	_remove_traffic(actor)
	_traffic_membership[actor] = cell
	_traffic_buckets.get_or_add(cell, []).append(actor)

func _remove_traffic(actor: Node2D) -> void:
	if not _traffic_membership.has(actor): return
	var cell: Vector2i = _traffic_membership[actor]
	var items: Array = _traffic_buckets[cell]
	items.erase(actor)
	if items.is_empty(): _traffic_buckets.erase(cell)
	_traffic_membership.erase(actor)

# Borrow bucket arrays only for synchronous read-only geometry selection.
# Never retain or mutate the returned arrays, or move actors during traversal.
func traffic_contact_buckets(origin: Vector2, forward: Vector2, look: float, clearance: float) -> Array:
	# Slack covers float32 projection/quantization at the cell boundary.
	var pad := clearance + 1.0
	var margin := Vector2.ONE * pad
	var finish := origin + forward * look
	var first := Vector2i(((origin.min(finish) - margin) / TRAFFIC_CELL).floor())
	var last := Vector2i(((origin.max(finish) + margin) / TRAFFIC_CELL).floor())
	var result: Array = []
	var half := TRAFFIC_CELL / 2.0
	var allowance := half * (absf(forward.x) + absf(forward.y)) + 1.0
	for y in range(first.y,last.y + 1):
		for x in range(first.x,last.x + 1):
			var cell := Vector2i(x,y)
			var bucket = _traffic_buckets.get(cell)
			if bucket == null: continue
			var mid := (Vector2(cell) * TRAFFIC_CELL + Vector2.ONE * half) - origin
			var nearest := (mid.abs() - Vector2.ONE * half).max(Vector2.ZERO)
			if nearest.length_squared() > pad * pad:
				if look <= 0.0: continue
				var along := mid.dot(forward)
				if along < -allowance or along > look + allowance or absf(mid.cross(forward)) > pad + allowance: continue
			result.append(bucket)
	return result
