extends RefCounted
class_name FlowField
## 单一目标的流场：在共享通行代价网格上跑多源 Dijkstra，
## 为每个格子求出「朝目标」的梯度方向。由 PathService 创建 / 复用。
##
## 说明：Packed*Array 在 GDScript 中按值传递（写时复制），
## 因此二叉堆写成成员数组 + 成员方法，避免函数内改动丢失。

const DIAG := 1.41421356

var cell: float = 40.0
var cols: int = 1
var rows: int = 1
var cost: PackedFloat32Array = PackedFloat32Array()   # <0 表示不可通行
var integ: PackedFloat32Array = PackedFloat32Array()  # 到目标的积分代价
var flow: PackedVector2Array = PackedVector2Array()   # 梯度方向（单位向量）

var epoch: int = -1
var goal_point: Vector2 = Vector2.ZERO
var reachable: bool = false

var _hi: PackedInt32Array = PackedInt32Array()
var _hc: PackedFloat32Array = PackedFloat32Array()
var _pop_cost: float = 0.0
var _settled := PackedByteArray()
var _routing_cost := PackedFloat32Array()

func configure(p_cell: float, p_cols: int, p_rows: int, p_cost: PackedFloat32Array) -> void:
	cell = p_cell
	cols = max(1, p_cols)
	rows = max(1, p_rows)
	cost = p_cost

func _cell_of(p: Vector2) -> Vector2i:
	var cx := int(floor(p.x / cell))
	var cy := int(floor(p.y / cell))
	return Vector2i(clampi(cx, 0, cols - 1), clampi(cy, 0, rows - 1))

func compute(p_goal: Vector2, p_epoch: int, lazy := false) -> void:
	var n := cols * rows
	integ.resize(n)
	flow.resize(n)
	integ.fill(INF)
	flow.fill(Vector2.ZERO)
	_settled.resize(n)
	_settled.fill(0)
	_hi.clear()
	_hc.clear()
	epoch = p_epoch
	_routing_cost = cost.duplicate() if lazy else cost
	goal_point = p_goal
	reachable = false

	var gc := _cell_of(p_goal)
	var goal_cell := gc.y * cols + gc.x

	# 目标格不可通行时，向外找一圈可通行的邻格作为多源种子
	var seeds: Array[int] = []
	if cost[goal_cell] >= 0.0:
		seeds.append(goal_cell)
	else:
		for rad in range(1, 7):
			var found := false
			for dy in range(-rad, rad + 1):
				for dx in range(-rad, rad + 1):
					if max(abs(dx), abs(dy)) != rad:
						continue
					var cx := gc.x + dx
					var cy := gc.y + dy
					if cx < 0 or cy < 0 or cx >= cols or cy >= rows:
						continue
					var idx := cy * cols + cx
					if cost[idx] >= 0.0:
						seeds.append(idx)
						found = true
			if found:
				break
	if seeds.is_empty():
		return

	# 多源 Dijkstra（8 邻域，禁止贴角穿行）
	reachable = true
	for s in seeds:
		integ[s] = 0.0
		_heap_push(s, 0.0)
	if not lazy: _expand_to(-1)

# Resume the same Dijkstra frontier. Once a cell is settled, all lower-cost
# neighbours used by its gradient already have their final distances.
func _expand_to(wanted: int) -> void:
	while _hi.size() > 0:
		var cur := _heap_pop()
		var cur_cost := _pop_cost
		if _settled[cur] != 0 or cur_cost > integ[cur] + 1e-4:
			continue
		_settled[cur] = 1
		var cx := cur % cols
		var cy := cur / cols
		var best := integ[cur]
		var direction := Vector2.ZERO
		for dy in range(-1, 2):
			var ny := cy + dy
			if ny < 0 or ny >= rows:
				continue
			for dx in range(-1, 2):
				var nx := cx + dx
				if nx < 0 or nx >= cols or (dx == 0 and dy == 0):
					continue
				var ni := ny * cols + nx
				var nc := _routing_cost[ni]
				if nc < 0.0:
					continue
				var diagonal := dx != 0 and dy != 0
				# Corner clearance gates travel. The gradient considers every open neighbour.
				if not diagonal or (_routing_cost[cy * cols + nx] >= 0.0 and _routing_cost[ny * cols + cx] >= 0.0):
					var step := DIAG if diagonal else 1.0
					var nd := cur_cost + step * nc
					if nd < integ[ni] - 1e-4:
						integ[ni] = nd
						_heap_push(ni, nd)
				# Only this neighbour's cost can change during this iteration.
				if integ[ni] < best - 1e-4:
					best = integ[ni]
					direction = Vector2(dx, dy)
		if direction != Vector2.ZERO:
			flow[cur] = direction.normalized()
		if cur == wanted: return

## 采样：返回该世界坐标处的流场方向；不可用 / 障碍格返回零向量（调用方兜底直行）
func direction_at(world: Vector2) -> Vector2:
	if flow.is_empty():
		return Vector2.ZERO
	var g := _cell_of(world)
	var i := g.y * cols + g.x
	if i < 0 or i >= flow.size():
		return Vector2.ZERO
	if i < cost.size() and cost[i] < 0.0:
		return Vector2.ZERO
	if _settled[i] == 0 and not _hi.is_empty(): _expand_to(i)
	return flow[i]

func is_ready() -> bool:
	return reachable and not flow.is_empty()

# ------------------------------------------------------------------ 二叉堆

func _heap_push(idx: int, c: float) -> void:
	var i := _hi.size()
	_hi.append(idx)
	_hc.append(c)
	# Priorities are float32 in the heap; compare the stored value to preserve ties.
	var priority := _hc[i]
	while i > 0:
		var parent := (i - 1) / 2
		if _hc[parent] <= priority:
			break
		_hi[i] = _hi[parent]
		_hc[i] = _hc[parent]
		i = parent
	_hi[i] = idx
	_hc[i] = priority

func _heap_pop() -> int:
	var top := _hi[0]
	_pop_cost = _hc[0]
	var last := _hi.size() - 1
	var moved := _hi[last]
	var priority := _hc[last]
	_hi.resize(last)
	_hc.resize(last)
	if last == 0:
		return top
	var i := 0
	while i * 2 + 1 < last:
		var child := i * 2 + 1
		var right := child + 1
		if right < last and _hc[right] < _hc[child]:
			child = right
		if _hc[child] >= priority:
			break
		_hi[i] = _hi[child]
		_hc[i] = _hc[child]
		i = child
	_hi[i] = moved
	_hc[i] = priority
	return top
