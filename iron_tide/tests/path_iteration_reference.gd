extends PathService
# Frozen pre-optimization navigation oracle. Preserve visit and tie order.

func _nearest_walkable(cell_pos: Vector2i, grid: PackedFloat32Array, zones: PackedInt32Array, zone_id: int, max_rad: int) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := INF
	for r in range(0, max_rad + 1):
		for dy in range(-r, r + 1):
			var stride := 1 if absi(dy) == r else r * 2
			for dx in range(-r, r + 1, stride):
				var nx := cell_pos.x + dx
				var ny := cell_pos.y + dy
				if nx < 0 or ny < 0 or nx >= cols or ny >= rows:
					continue
				var ni := ny * cols + nx
				if grid[ni] < 0.0:
					continue
				if zone_id > 0 and zones[ni] != zone_id:
					continue
				var d := float(dx * dx + dy * dy)
				if d < best_d:
					best_d = d
					best = Vector2i(nx, ny)
		if best.x >= 0:
			return best
	return best

static func _octile(dx: int, dy: int) -> float:
	var ax := absi(dx)
	var ay := absi(dy)
	var mn := mini(ax, ay)
	return float(maxi(ax, ay) - mn) + 1.41421356 * float(mn)


func _bounded_grid_path(from:Vector2,to:Vector2,sc:Vector2i,gc:Vector2i,grid:PackedFloat32Array,max_expand:int,temporary:bool) -> PackedVector2Array:
	var out:=PackedVector2Array([from])
	var si:=sc.y*cols+sc.x
	var gi:=gc.y*cols+gc.x
	# ---- A*（八方向，禁止切角；桶队列避免 GDScript 排序开销）----
	var n := cols * rows
	if _search_marks.size() != n:
		_search_marks.resize(n)
		_search_scores.resize(n)
		_search_parents.resize(n)
	if _search_id == 2147483647:
		_search_marks.fill(0)
		_search_id = 0
	_search_id += 1
	_search_marks[si] = _search_id
	var buckets: Array = []
	var cap := int((cols + rows) * 2) + 16
	buckets.resize(cap)
	_search_scores[si] = 0.0
	var h0 := _octile(gc.x - sc.x, gc.y - sc.y)
	buckets[int(h0)]=[si]
	var cur := int(h0)
	var expanded := 0
	var best_idx := si
	var best_h := h0
	while expanded < max_expand:
		while cur < buckets.size() and (buckets[cur]==null or (buckets[cur] as Array).is_empty()):
			cur += 1
		if cur >= buckets.size():
			break
		var idx: int = (buckets[cur] as Array).pop_back()
		if _search_marks[idx] == -_search_id:
			continue
		_search_marks[idx] = -_search_id
		expanded += 1
		var cx := idx % cols
		var cy := int(idx / cols)
		var hx := _octile(gc.x - cx, gc.y - cy)
		if hx < best_h:
			best_h = hx
			best_idx = idx
		if idx == gi:
			best_idx = gi
			break
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if dx == 0 and dy == 0:
					continue
				var nx := cx + dx
				var ny := cy + dy
				if nx < 0 or ny < 0 or nx >= cols or ny >= rows:
					continue
				var ni := ny * cols + nx
				if _search_marks[ni] == -_search_id or grid[ni] < 0.0:
					continue
				if dx != 0 and dy != 0:
					if grid[cy * cols + nx] < 0.0 or grid[ny * cols + cx] < 0.0:
						continue
				var step := 1.41421356 if (dx != 0 and dy != 0) else 1.0
				var tentative := _search_scores[idx] + step
				if _search_marks[ni] == _search_id and tentative + 0.0001 >= _search_scores[ni]:
					continue
				_search_marks[ni] = _search_id
				_search_scores[ni] = tentative
				_search_parents[ni] = idx
				var f := tentative + _octile(gc.x - nx, gc.y - ny)
				var bucket := int(f)
				if bucket >= buckets.size():
					buckets.resize(bucket + 32)
				if buckets[bucket]==null:buckets[bucket]=[]
				(buckets[bucket] as Array).append(ni)
	# ---- 回溯 ----
	var cells: Array[Vector2i] = []
	var walk := best_idx
	var guard := 0
	while walk != -1 and guard < n:
		cells.append(Vector2i(walk % cols, int(walk / cols)))
		if walk == si:
			break
		walk = _search_parents[walk]
		guard += 1
	if cells.is_empty():
		stats_path_fail += 1
		return out
	cells.reverse()
	for ci in range(1, cells.size()):
		out.append(Vector2(cells[ci].x * cell + cell * 0.5, cells[ci].y * cell + cell * 0.5))
	# 终点：目标格可达时贴精确点，否则停在格心
	if best_idx == gi and _cell_of(to) == gc:
		out[out.size() - 1] = to
	elif best_idx == gi:
		out[out.size() - 1] = Vector2(gc.x * cell + cell * 0.5, gc.y * cell + cell * 0.5)
	if best_idx != gi:
		stats_path_fail += 1
		if temporary: return PackedVector2Array([from])
	return out

# A nearby unit can join a proven route going to the same destination cell.
# Recheck both changed segments against the current corner/shore rules.
