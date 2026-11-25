extends Node
class_name PathService
## 战场寻路服务：
##  - 维护一张静态通行代价网格（障碍 / 建筑标记为不可通行）
##  - 按目标点缓存流场；地形变化时原地重算（保持单位持有的引用有效）
##  - 同一次框选移动共用一个流场，因此 200+ 单位也只需算 1 次寻路

const CELL := 40.0
const BLOCK_PAD := 12.0
const ROUTE_REFRESHES_PER_TICK := 2
# Same dy/dx order as the original nine-cell loop, excluding its unused center.
const SEARCH_DIRECTIONS := [Vector2i(-1,-1), Vector2i(0,-1), Vector2i(1,-1),
	Vector2i(-1,0), Vector2i(1,0), Vector2i(-1,1), Vector2i(0,1), Vector2i(1,1)]
var _route_refresh_frame := -1
var _route_refresh_count := 0
var passages := preload("res://scripts/world/vehicle_passages.gd").new()

var native_map_id: String = ""
var _native_query_id := ""
var _native_query_row: Dictionary = {}
var _native_base: Dictionary = {}
var map_size: float = 2400.0
var cell: float = CELL
var cols: int = 1
var rows: int = 1
var cost: PackedFloat32Array = PackedFloat32Array()
## 水面通行网格：陆地/建筑不可通行，水域可通行（海军流场用）。
# Land grid for the Apocalypse. Water, rocks and building footprints still block;
# stamping a wall must never reopen a cell already covered by another blocker.
var crusher_cost:=PackedFloat32Array()
var _crusher_zone:=PackedInt32Array()
var _crusher_epoch:=-1
var water_cost: PackedFloat32Array = PackedFloat32Array()
var amphibious_cost: PackedFloat32Array = PackedFloat32Array()
var amphibious_zone: PackedInt32Array = PackedInt32Array()
var _blocked: PackedByteArray = PackedByteArray()   # 1=建筑/障碍，水域不置位
var _water_mask: PackedByteArray = PackedByteArray() # 1=水域

var epoch: int = 0
var enabled: bool = true
var stats_built: int = 0
var stats_requests: int = 0

var _fields: Dictionary = {}      # goal_cell_index -> FlowField
var _water_fields: Dictionary = {} # goal_cell_index -> FlowField（海军）
var _cache_cap: int = 64

## RA2 ZoneMap：连通区编号。1..N 表示可互通区域，0 表示不可通行。
## 陆军与海军各一套（与 cost / water_cost 网格对应）。
var ground_zone: PackedInt32Array = PackedInt32Array()
var water_zone: PackedInt32Array = PackedInt32Array()
var _zone_epochs := [-1, -1, -1]
var stats_paths: int = 0
var stats_path_fail: int = 0
const MAX_ROUTE_GOALS := 128
const MAX_CORRIDORS_PER_GOAL := 4
const MAX_CORRIDOR_POINTS := 128
# Bounded native windows use the same corner rule and solid cells as the full map.
const WINDOW_EDGE := 64
const WINDOW_STRIDE := 24
var _windows := {}
var _window_epoch := -1
# A long route within one verified component can use the native grid. Dynamic
# blockers still use the bounded search, including its partial-route rules.
const MAX_NATIVE_MAP_CELLS := 65536
var _native_maps := {}
var stats_map_paths := 0
var stats_window_paths := 0
var stats_route_reuse := 0
var _route_epoch := -1
var _routes_by_goal := {}

## 水域（世界坐标 Rect2 列表）：地面单位不可通行，但允许 RA3 式水上建造
var water_rects: Array = []
var bridge_decks: Array = []
var broken_bridge_decks: Array = []
var bridge_flags: Dictionary = {}

# Native deck geometry is built once from the map tiles. A cell stores zero,
# one candidate (index + 1), or -1 for overlaps that need the original order.
const DECK_CELL := 128.0
const MAX_DECK_MARGIN := 128.0
var _deck_map_id := ""
var _native_decks: Array = []
var _deck_columns := 0
var _deck_cells := PackedInt32Array()

func _build_deck_index() -> void:
	var row := preload("res://scripts/world/native_maps.gd").data(native_map_id)
	_deck_map_id = native_map_id
	_native_decks = row.bridge_decks
	_deck_cells.clear()
	_deck_columns = 0
	if _native_decks.is_empty(): return
	_deck_columns = ceili(float(row.side) * preload("res://scripts/world/native_maps.gd").CELL / DECK_CELL) + 2
	_deck_cells.resize(_deck_columns * _deck_columns)
	for i in _native_decks.size():
		var expanded: Rect2 = _native_decks[i].grow(MAX_DECK_MARGIN)
		var first := Vector2i((expanded.position / DECK_CELL).floor()) + Vector2i.ONE
		var last := Vector2i((expanded.end / DECK_CELL).floor()) + Vector2i.ONE
		for y in range(maxi(0, first.y), mini(last.y + 1, _deck_columns)):
			for x in range(maxi(0, first.x), mini(last.x + 1, _deck_columns)):
				var index := y * _deck_columns + x
				_deck_cells[index] = i + 1 if _deck_cells[index] == 0 else -1

func set_bridge_damage(flags: Dictionary, broken: Array) -> void:
	bridge_flags = flags
	broken_bridge_decks = broken
	_native_base.clear()

func native_flags(point: Vector2) -> int:
	var native_cell := Vector2i((point / preload("res://scripts/world/native_maps.gd").CELL).floor())
	if bridge_flags.has(native_cell): return int(bridge_flags[native_cell])
	# Keep the immutable map's shared row, not a cached walkability answer.
	# Damage/repair overrides above and the row's mask are read on every query.
	if _native_query_id != native_map_id or _native_query_row.is_empty():
		_native_query_row = preload("res://scripts/world/native_maps.gd").data(native_map_id)
		_native_query_id = native_map_id
	var side := int(_native_query_row.side)
	if native_cell.x < 0 or native_cell.y < 0 or native_cell.x >= side or native_cell.y >= side:return 0
	return _native_query_row.mask[native_cell.y * side + native_cell.x]

# One shared snapshot detects direct grid edits as well as ordinary rebuilds.
var _passage_cost := PackedFloat32Array()
var _passage_ground := PackedFloat32Array()
var _passage_geometry_id := 0
var _passage_geometry_revision := -1
var _passage_revision := 0
var _passage_cols := -1
var _passage_rows := -1
var _passage_cell := -1.0
var _passage_map_size := -1.0

func passage_revision() -> int:
	var changed := false
	if _passage_cost != cost:
		_passage_cost = cost.duplicate()
		changed = true
	if _passage_ground != passages.terrain:
		_passage_ground = passages.terrain.duplicate()
		changed = true
	var geometry_id := passages.get_instance_id()
	if changed or _passage_geometry_id != geometry_id or _passage_geometry_revision != passages.geometry_revision or _passage_cols != cols or _passage_rows != rows or _passage_cell != cell or _passage_map_size != map_size:
		_passage_geometry_id = geometry_id
		_passage_geometry_revision = passages.geometry_revision
		_passage_cols = cols
		_passage_rows = rows
		_passage_cell = cell
		_passage_map_size = map_size
		_passage_revision += 1
	return _passage_revision

## Spread invalidated routes across ticks. New orders still plan immediately.
func take_route_refresh() -> bool:
	var frame := Engine.get_physics_frames()
	if _route_refresh_frame != frame:
		_route_refresh_frame = frame
		_route_refresh_count = 0
	if _route_refresh_count >= ROUTE_REFRESHES_PER_TICK:
		return false
	_route_refresh_count += 1
	return true

func configure(p_map_size: float, p_cell: float = CELL) -> void:
	map_size = p_map_size
	cell = p_cell
	cols = max(1, int(ceil(map_size / cell)))
	rows = cols
	_fill_cost()
	_refresh_water_cost()
	epoch += 1
	_fields.clear()

func _fill_cost() -> void:
	_native_maps.clear()
	var n := cols * rows
	water_cost.resize(n)
	# Imported terrain is immutable. Structures and walls are stamped on fresh
	# copies so destroying one can restore the original land or bridge below it.
	if not _native_base.is_empty() and _native_base.id == native_map_id and _native_base.cell == cell and _native_base.dimensions == Vector2i(cols,rows):
		cost = _native_base.ground.duplicate()
		crusher_cost = cost.duplicate()
		_blocked = _native_base.blocked.duplicate()
		_water_mask = _native_base.water.duplicate()
		passages.reset(cost)
		return
	_native_base.clear()
	crusher_cost.resize(n)
	crusher_cost.fill(1.0)
	cost.resize(n)
	cost.fill(1.0)
	_blocked.resize(n)
	_blocked.fill(0)
	_water_mask.resize(n)
	_water_mask.fill(0)
	_stamp_water()
	if not native_map_id.is_empty():
		_native_base = {"id":native_map_id, "cell":cell, "dimensions":Vector2i(cols,rows), "ground":cost.duplicate(), "blocked":_blocked.duplicate(), "water":_water_mask.duplicate()}
	passages.reset(cost)

## 将水域标记为不可通行（-1）并记录水域掩码；水域不算“建筑遮挡”。
## 与建筑同源：旧版只测「格心在矩形内」，岸边同样漏一条 ~1 格的可通行带，
## 地面单位能踏进水里。统一走 _stamp_rect（外扩半格 → 与水域相交的格全封）。
func _stamp_water() -> void:
	if not native_map_id.is_empty():
		for y in rows:
			for x in cols:
				var index:=y*cols+x
				var flags:int=native_flags(Vector2(x+.5,y+.5)*cell)
				cost[index]=1.0 if (flags&1)!=0 else -1.0
				crusher_cost[index]=cost[index]
				_water_mask[index]=1 if (flags&2)!=0 else 0
				_blocked[index]=1 if flags==0 or flags==4 else 0
		return
	for r in water_rects:
		_stamp_rect(r, false)
		_stamp_water_mask(r)
	# Open only the land grids across the deck. Water masks stay continuous,
	# and rebuild_terrain stamps structures and rocks after this pass.
	for deck: Rect2 in bridge_decks:
		var lo := _cell_of(deck.position - Vector2.RIGHT * cell * 0.5)
		var hi := _cell_of(deck.end + Vector2.RIGHT * cell * 0.5)
		for y in range(lo.y, hi.y + 1):
			var center_y := (y + 0.5) * cell
			if center_y - cell * 0.5 < deck.position.y or center_y + cell * 0.5 > deck.end.y: continue
			for x in range(lo.x, hi.x + 1):
				cost[y * cols + x] = 1.0
				crusher_cost[y * cols + x] = 1.0
	# Carve only collapsed sections after stamping the original continuous deck.
	for gap: Rect2 in broken_bridge_decks:
		var lo := _cell_of(gap.position)
		var hi := _cell_of(gap.end)
		for y in range(lo.y,hi.y+1):
			for x in range(lo.x,hi.x+1):
				var center := Vector2(x+0.5,y+0.5)*cell
				if not gap.has_point(center): continue
				for water: Rect2 in water_rects:
					if water.has_point(center):
						cost[y*cols+x] = -1.0
						crusher_cost[y*cols+x] = -1.0
						break

func _stamp_water_mask(rect: Rect2) -> void:
	var grown := rect.grow(cell * 0.5)
	var minc := _cell_of(grown.position)
	var maxc := _cell_of(grown.end)
	for cy in range(minc.y, maxc.y + 1):
		for cx in range(minc.x, maxc.x + 1):
			var cc := Vector2(cx * cell + cell * 0.5, cy * cell + cell * 0.5)
			if grown.has_point(cc):
				_water_mask[cy * cols + cx] = 1

## 海军网格：只保留「水域且未被建筑/障碍占用」的格。
func _refresh_water_cost() -> void:
	var n := cols * rows
	amphibious_cost.resize(n)
	for i in range(n):
		water_cost[i] = 1.0 if (_water_mask[i] == 1 and _blocked[i] == 0) else -1.0
		amphibious_cost[i] = 1.0 if _blocked[i] == 0 else -1.0

## 配置水域并重建通行网格。
func set_water(rects: Array, decks: Array = []) -> void:
	water_rects = rects.duplicate()
	bridge_decks = decks.duplicate()
	_fill_cost()
	_refresh_water_cost()
	epoch += 1

func near_deck(p: Vector2, margin := 0.0) -> bool:
	return bridge_at(p,margin).has_area()

func bridge_at(p: Vector2, margin := 0.0) -> Rect2:
	var _call_log_scope = preload("res://scripts/world/battle_call_counters.gd").enter(50)
	var decks := bridge_decks
	var candidate := -1
	if not native_map_id.is_empty():
		if _deck_map_id != native_map_id: _build_deck_index()
		decks = _native_decks
		if decks.is_empty(): return Rect2()
		if margin >= 0.0 and margin <= MAX_DECK_MARGIN and p.is_finite():
			var cell_x := floori(p.x / DECK_CELL) + 1
			var cell_y := floori(p.y / DECK_CELL) + 1
			if cell_x >= 0 and cell_y >= 0 and cell_x < _deck_columns and cell_y < _deck_columns:
				candidate = _deck_cells[cell_y * _deck_columns + cell_x]
				if candidate == 0: return Rect2()
	for gap: Rect2 in broken_bridge_decks:
		if gap.has_point(p): return Rect2()
	if candidate > 0:
		var deck: Rect2 = decks[candidate - 1]
		preload("res://scripts/world/battle_call_counters.gd").iterations(50,1)
		return deck if deck.grow(margin).has_point(p) else Rect2()
	var visited := 0
	for deck: Rect2 in decks:
		visited += 1
		if deck.grow(margin).has_point(p):
			preload("res://scripts/world/battle_call_counters.gd").iterations(50,visited)
			return deck
	preload("res://scripts/world/battle_call_counters.gd").iterations(50,visited)
	return Rect2()

func in_water(p: Vector2) -> bool:
	if not native_map_id.is_empty():return native_flags(p)==2
	return in_naval_water(p) and not near_deck(p)

func in_naval_water(p: Vector2) -> bool:
	if not native_map_id.is_empty():return (native_flags(p)&2)!=0
	for r in water_rects:
		if (r as Rect2).has_point(p):
			return true
	return false

# Only a complete route far from these cells can use the resulting history entry.
# The rebuild can update packed arrays in place. Keep independent before-images.
func route_snapshot_outside(bounds: Rect2) -> Dictionary:
	return {"grids":[cost.duplicate(), water_cost.duplicate(), amphibious_cost.duplicate(), crusher_cost.duplicate(), passages.terrain.duplicate()],
		"shapes":_route_shapes_outside(bounds), "dimensions":Vector2i(cols,rows), "cell":cell}

func _route_shapes_outside(bounds: Rect2) -> Array:
	var outside := []
	for shape in passages.shapes:
		if not bounds.encloses(shape.bounds): outside.append(shape)
	return outside

func route_matches_outside(bounds: Rect2, before: Dictionary) -> bool:
	if before.dimensions != Vector2i(cols,rows) or before.cell != cell or before.shapes != _route_shapes_outside(bounds):
		return false
	var first := _cell_of(bounds.position)
	var last := _cell_of(bounds.end)
	var grids := [cost, water_cost, amphibious_cost, crusher_cost, passages.terrain]
	for domain in grids.size():
		var old: PackedFloat32Array = before.grids[domain]
		var current: PackedFloat32Array = grids[domain]
		if old == current: continue
		if old.size() != current.size(): return false
		var start := 0
		for y in range(first.y, last.y + 1):
			var end := y * cols + first.x
			if old.slice(start,end) != current.slice(start,end): return false
			start = y * cols + last.x + 1
		if old.slice(start) != current.slice(start): return false
	return true

## 用一组遮挡物（障碍 + 建筑）整体重建通行网格
var _terrain_before_roads:=PackedFloat32Array()

func is_blocked_before_roads(point:Vector2) -> bool:
	if _terrain_before_roads.is_empty():return is_blocked(point)
	var g:=_cell_of(point)
	return _terrain_before_roads[g.y*cols+g.x]<0

func rebuild_terrain(blockers: Array, roads:Array=[]) -> void:
	_fill_cost()
	for b in blockers:
		if is_instance_valid(b):
			_stamp_blocker(b)
	_terrain_before_roads=_movement_grid(false,false,false).duplicate() if not roads.is_empty() else PackedFloat32Array()
	for road in roads:
		var length:float=road.start.distance_to(road.end)
		var steps:=maxi(1,ceili(length/(cell*.45)))
		for i in steps+1:_stamp(road.start.lerp(road.end,float(i)/steps),27.5)
	# 建筑同样要从未通过的海军网格中抹掉（旧版只在 add_blocker 里刷新）
	_refresh_water_cost()
	epoch += 1

## 新增单个遮挡物（建筑落成时调用）
func add_blocker(b) -> void:
	if not is_instance_valid(b):
		return
	_stamp_blocker(b, true)
	epoch += 1

## RA2 式占用：建筑按【真实占地矩形】刷格（旧版只刷一个小圆，单位会从建筑身上穿过去），
## 其它遮挡物仍按半径刷格。
func _block_native_cell(point: Vector2i, wall: bool) -> void:
	for domain in _native_maps:
		if domain != 3 or not wall:
			_native_maps[domain].set_point_solid(point)

func _stamp_blocker(b, update_domains := false) -> void:
	if b.has_method("footprint_poly"):
		var poly: PackedVector2Array = b.footprint_poly()
		if poly.size() >= 3:
			# 建筑只按「占地 + 2」刷格：物理碰撞体已是精确多边形，刷太厚会把窄通道全堵死
			passages.add_shape(b.global_position, poly, 0.0, cell)
			_stamp_rect(Placement.aabb(poly, b.global_position).grow(2.0), true, b is Building and WallArt.is_wall(b.data), update_domains)
			return
	passages.add_shape(b.global_position, PackedVector2Array(), float(b.radius), cell)
	_stamp(b.global_position, float(b.get("radius")) + BLOCK_PAD, update_domains)

## 把与矩形相交的格全部标记为不可通行
func _stamp_rect(rect: Rect2, blocks: bool = true, wall:bool=false, update_domains := false) -> void:
	# 旧版只测「格心落在矩形内」，等于把阻挡区在四边各内缩最多半格（cell*0.5=20px）：
	# 建筑每条边都会漏出一整条 ~1 格宽的「可通行带」，单位贴墙行进时流场在漏格处给出
	# 指向建筑内部的方向，被物理墙挡住后原地卡死（实测可 100% 冻结）。
	# 正解：格心落在「矩形外扩半格」范围内即视为与矩形相交，逐边最多补回 1 格。
	var grown := rect.grow(cell * 0.5)
	var minc := _cell_of(grown.position)
	var maxc := _cell_of(grown.end)
	for cy in range(minc.y, maxc.y + 1):
		for cx in range(minc.x, maxc.x + 1):
			var cc := Vector2(cx * cell + cell * 0.5, cy * cell + cell * 0.5)
			if grown.has_point(cc):
				var i := cy * cols + cx
				cost[i] = -1.0
				if not wall:crusher_cost[i]=-1.0
				# 旧版漏了这一步：_refresh_water_cost() 只看 _blocked，
				# 导致水上建筑（船坞）不会从海军网格里抹掉，船会直接穿模。
				if blocks:
					_blocked[i] = 1
					if update_domains:
						water_cost[i] = -1.0
						amphibious_cost[i] = -1.0
						if not _native_maps.is_empty(): _block_native_cell(Vector2i(cx,cy), wall)

func _stamp(center: Vector2, r: float, update_domains := false) -> void:
	var minc := _cell_of(center - Vector2(r, r))
	var maxc := _cell_of(center + Vector2(r, r))
	for cy in range(minc.y, maxc.y + 1):
		for cx in range(minc.x, maxc.x + 1):
			var cc := Vector2(cx * cell + cell * 0.5, cy * cell + cell * 0.5)
			if cc.distance_to(center) <= r + cell * 0.4:
				cost[cy * cols + cx] = -1.0
				crusher_cost[cy * cols + cx] = -1.0
				_blocked[cy * cols + cx] = 1
				if update_domains:
					water_cost[cy * cols + cx] = -1.0
					amphibious_cost[cy * cols + cx] = -1.0
					if not _native_maps.is_empty(): _block_native_cell(Vector2i(cx,cy), false)

func _cell_of(p: Vector2) -> Vector2i:
	var cx := int(floor(p.x / cell))
	var cy := int(floor(p.y / cell))
	return Vector2i(clampi(cx, 0, cols - 1), clampi(cy, 0, rows - 1))

## 取目标点对应的流场；命中缓存则复用，地形变化时原地重算。
## water_mode=true 时使用海军网格（水域可走、陆地全封）。
func field_for(goal: Vector2, water_mode: bool = false):
	if not enabled or cols <= 1:
		return null
	stats_requests += 1
	var grid: PackedFloat32Array = water_cost if water_mode else cost
	if grid.is_empty():
		return null
	var cache: Dictionary = _water_fields if water_mode else _fields
	var g := _cell_of(goal)
	var key := g.y * cols + g.x
	if cache.has(key):
		var f: FlowField = cache[key]
		if f.epoch != epoch:
			f.configure(cell, cols, rows, grid)
			f.compute(goal, epoch, true)
			stats_built += 1
		return f
	if cache.size() >= _cache_cap:
		cache.clear()
	var nf: FlowField = FlowField.new()
	nf.configure(cell, cols, rows, grid)
	nf.compute(goal, epoch, true)
	stats_built += 1
	cache[key] = nf
	return nf

func _movement_grid(water_mode:bool,amphibious:bool,wall_crusher:bool) -> PackedFloat32Array:
	if wall_crusher:return crusher_cost
	return amphibious_cost if amphibious else (water_cost if water_mode else cost)

func _movement_zones(water_mode:bool,amphibious:bool,wall_crusher:bool) -> PackedInt32Array:
	if wall_crusher:
		if _crusher_epoch!=epoch:
			_crusher_zone=_build_zones(crusher_cost)
			_crusher_epoch=epoch
		return _crusher_zone
	var domain := 2 if amphibious else int(water_mode)
	if _zone_epochs[domain] != epoch:
		match domain:
			0: ground_zone = _build_zones(cost)
			1: water_zone = _build_zones(water_cost)
			2: amphibious_zone = _build_zones(amphibious_cost)
		_zone_epochs[domain] = epoch
	return amphibious_zone if amphibious else (water_zone if water_mode else ground_zone)

func is_blocked(world: Vector2, water_mode: bool = false, amphibious: bool = false, wall_crusher: bool = false) -> bool:
	var grid: PackedFloat32Array = _movement_grid(water_mode,amphibious,wall_crusher)
	if grid.is_empty():
		return false
	var g := _cell_of(world)
	var i := g.y * cols + g.x
	return i < grid.size() and grid[i] < 0.0

## ------------------------------------------------------------------
## RA2 式寻路：ZoneMap 连通区 + 八方向 A* + 视线拉直
## RA2 的 PathFinder 先看 ZoneMap 判断能否到达，再做 A*；同一次框选里每个
## 单位有各自的终点（编队槽位），所以不能用「一张共享流场」。这里按单位求路径。
## ------------------------------------------------------------------

func _build_zones(grid: PackedFloat32Array) -> PackedInt32Array:
	var _call_log_scope = preload("res://scripts/world/battle_call_counters.gd").enter(24)
	var n := cols * rows
	var zones := PackedInt32Array()
	zones.resize(n)
	zones.fill(0)
	# A legal diagonal has both orthogonal neighbours open, so it cannot
	# connect components that left/up labelling would leave separate.
	var parents := PackedInt32Array([0])
	for i in n:
		if grid[i] < 0:
			continue
		var left := zones[i - 1] if i % cols != 0 else 0
		var above := zones[i - cols] if i >= cols else 0
		if left == 0 and above == 0:
			zones[i] = parents.size()
			parents.append(zones[i])
		elif above == 0 or left == above:
			zones[i] = left
		elif left == 0:
			zones[i] = above
		else:
			while left != parents[left]:
				parents[left] = parents[parents[left]]
				left = parents[left]
			while above != parents[above]:
				parents[above] = parents[parents[above]]
				above = parents[above]
			zones[i] = mini(left, above)
			parents[maxi(left, above)] = zones[i]
	# Parents always point to an earlier provisional label. Compacting them
	# in scan order preserves the original component IDs as well as reachability.
	var count := 0
	for label in range(1, parents.size()):
		if parents[label] == label:
			count += 1
			parents[label] = count
		else:
			parents[label] = parents[parents[label]]
	for i in n:
		zones[i] = parents[zones[i]]
	return zones

func zone_at(world: Vector2, water_mode: bool = false) -> int:
	if not enabled or cols <= 1:
		return 1
	var g := _cell_of(world)
	var zones := _movement_zones(water_mode, false, false)
	return zones[g.y * cols + g.x]

func ground_near_base(base: Vector2) -> Vector2:
	if not enabled or cols <= 1:
		return base
	var hit := _nearest_walkable(_cell_of(base), cost, _movement_zones(false, false, false), -1, 20)
	if hit.x < 0:
		return Vector2.INF
	return (Vector2(hit) + Vector2(0.5, 0.5)) * cell

func same_zone(a: Vector2, b: Vector2, water_mode: bool = false) -> bool:
	var za := zone_at(a, water_mode)
	return za > 0 and za == zone_at(b, water_mode)

## 把目标点吸附到「与 from 同一连通区」的最近可走格。
## 点到水里/建筑上时，RA2 会把移动目标改到最近岸边，而不是让单位顶着墙走。
func nearest_reachable(target: Vector2, from: Vector2, water_mode: bool = false, max_rad: int = 20, amphibious: bool = false, wall_crusher: bool = false) -> Vector2:
	if not enabled or cols <= 1:
		return target
	var grid: PackedFloat32Array = _movement_grid(water_mode,amphibious,wall_crusher)
	var zones: PackedInt32Array = _movement_zones(water_mode,amphibious,wall_crusher)
	var sc := _cell_of(from)
	if grid[sc.y * cols + sc.x] < 0.0:
		sc = _nearest_walkable(sc, grid, zones, -1, 4)
	if sc.x < 0:
		return from
	var sz := zones[sc.y * cols + sc.x]
	var tc := _cell_of(target)
	if grid[tc.y * cols + tc.x] >= 0.0 and zones[tc.y * cols + tc.x] == sz:
		return target
	var hit := _row_snap(tc, grid, zones, sz, max_rad, 3 if wall_crusher else (2 if amphibious else int(water_mode)))
	if hit.x < 0:
		return from
	return Vector2(hit.x * cell + cell * 0.5, hit.y * cell + cell * 0.5)

var _snap_rows := {}
var _rows_epoch := -1

func _row_snap(p: Vector2i, grid: PackedFloat32Array, zones: PackedInt32Array, zone: int, radius: int, domain: int) -> Vector2i:
	if radius < 4 or zone <= 0: return _nearest_walkable(p,grid,zones,zone,radius)
	if epoch != _rows_epoch:
		_snap_rows.clear()
		_rows_epoch = epoch
	var best := Vector2i(-1,-1)
	var ring := radius+1
	var dist := INF
	for y in range(maxi(0,p.y-radius),mini(rows-1,p.y+radius)+1):
		var dy := absi(y-p.y)
		if dy > ring: continue
		var key := Vector3i(domain,zone,y)
		var xs = _snap_rows.get(key)
		if xs == null:
			var row := PackedInt32Array()
			var start := y*cols
			for x in cols:
				if zones[start+x]==zone and grid[start+x]>=0: row.append(x)
			if _snap_rows.size() >= 4096: _snap_rows.clear()
			_snap_rows[key] = row
			xs = row
		var line: PackedInt32Array = xs
		if line.is_empty(): continue
		var at := line.bsearch(p.x)
		var x := line[mini(at,line.size()-1)]
		if at > 0 and p.x-line[at-1] <= absi(x-p.x): x=line[at-1]
		var dx := absi(x-p.x)
		var r := maxi(dx,dy)
		var d := dx*dx+dy*dy
		if r <= radius and (r < ring or (r == ring and d < dist)):
			best = Vector2i(x,y)
			ring = r
			dist = d
	return best

func _nearest_walkable(cell_pos: Vector2i, grid: PackedFloat32Array, zones: PackedInt32Array, zone_id: int, max_rad: int) -> Vector2i:
	var _call_log_scope = preload("res://scripts/world/battle_call_counters.gd").enter(65)
	if max_rad >= 0: preload("res://scripts/world/battle_call_counters.gd").iterations(65, 1)
	if max_rad >= 0 and cell_pos.x >= 0 and cell_pos.y >= 0 and cell_pos.x < cols and cell_pos.y < rows:
		var origin := cell_pos.y * cols + cell_pos.x
		if grid[origin] >= 0.0 and (zone_id <= 0 or zones[origin] == zone_id): return cell_pos
	var best := Vector2i(-1, -1)
	var best_d := INF
	for r in range(1, max_rad + 1):
		preload("res://scripts/world/battle_call_counters.gd").iterations(65, 8 * r)
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

func _segment_clear_of_units(from: Vector2, to: Vector2, blockers: Array) -> bool:
	for blocker in blockers:
		var at: Vector2 = blocker.position
		var clearance: float = blocker.radius
		var closest := Geometry2D.get_closest_point_to_segment(at, from, to)
		if closest.distance_squared_to(at) <= clearance * clearance:
			return false
	return true

# Each native search is bounded by the window area. Cross-map routes and
# detours that cannot reach the destination within the window use the full grid.
func _window_route(start: Vector2i, goal: Vector2i, domain: int, base: PackedFloat32Array, temporary: Array[Vector2i]) -> PackedVector2Array:
	var anchor := Vector2(start.min(goal)) / WINDOW_STRIDE
	var origin := Vector2i(anchor.floor()) * WINDOW_STRIDE - Vector2i(8, 8)
	var dimensions := Vector2i(cols, rows)
	var size := dimensions.min(Vector2i.ONE * WINDOW_EDGE)
	origin = origin.clamp(Vector2i.ZERO, dimensions - size)
	var area := Rect2i(origin, size)
	if not area.has_point(start) or not area.has_point(goal):
		# A long, narrow bridge approach can be cheap even when its endpoints
		# do not fit in a square window. Keep the native search bounded.
		var low := Vector2i((Vector2(start.min(goal)) / 8.0).floor()) * 8 - Vector2i(8, 8)
		var high := Vector2i((Vector2(start.max(goal) + Vector2i.ONE) / 8.0).ceil()) * 8 + Vector2i(8, 8)
		area = Rect2i(low, high - low).intersection(Rect2i(Vector2i.ZERO, dimensions))
		if area.get_area() > WINDOW_EDGE * WINDOW_EDGE:
			return PackedVector2Array()
	if _window_epoch != epoch:
		_windows.clear()
		_window_epoch = epoch
	var key := [domain, area]
	if not _windows.has(key):
		if _windows.size() >= 32:
			_windows.erase(_windows.keys()[0])
		_windows[key] = _build_window(area, base)
	var solver: AStarGrid2D = _windows[key]
	# temporary contains only newly blocked, normally traversable cells.
	for point in temporary:
		if area.has_point(point): solver.set_point_solid(point)
	var path := solver.get_point_path(start, goal)
	for point in temporary:
		if area.has_point(point): solver.set_point_solid(point, false)
	return path

func _build_window(area: Rect2i, base: PackedFloat32Array) -> AStarGrid2D:
	var solver := AStarGrid2D.new()
	solver.region = area
	solver.cell_size = Vector2.ONE * cell
	solver.offset = solver.cell_size * 0.5
	solver.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	solver.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	solver.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	solver.update()
	for y in range(area.position.y, area.end.y):
		var x := area.position.x
		while x < area.end.x:
			if base[y * cols + x] >= 0:
				x += 1
				continue
			var left := x
			while x < area.end.x and base[y * cols + x] < 0:
				x += 1
			solver.fill_solid_region(Rect2i(left, y, x - left, 1), true)
	return solver

## 单位路径：返回从 from 到最近可达终点的折线（世界坐标，首点为实际位置）。
## water_mode=true 使用海军网格。无法到达时返回 [from]（调用方应视为原地不动）。
func find_path(from: Vector2, to: Vector2, water_mode: bool = false, max_expand: int = 6000, amphibious: bool = false, temporary_blockers: Array = [], wall_crusher: bool = false, army_route := false) -> PackedVector2Array:
	var _call_log_scope = preload("res://scripts/world/battle_call_counters.gd").enter(23)
	var out := PackedVector2Array()
	out.append(from)
	if not enabled or cols <= 1:
		out.append(to)
		return out
	var grid: PackedFloat32Array = _movement_grid(water_mode,amphibious,wall_crusher)
	var zones: PackedInt32Array = _movement_zones(water_mode,amphibious,wall_crusher)
	stats_paths += 1
	# The cell padding below is deliberately conservative for A*. Do not let
	# it close a physically clear infantry gap: prove the entire direct segment
	# against terrain AND each unit's supplied clearance circle first.
	if not temporary_blockers.is_empty() and max_expand >= 6000 and line_walkable(from, to, grid) and _segment_clear_of_units(from, to, temporary_blockers):
		out.append(to)
		return out
	# Unit-size-specific blockers belong to this request only. Never poison the
	# shared terrain, zone map or cached flow fields when infantry stands up.
	var base_grid := grid
	var temporary_solids:Array[Vector2i]=[]
	if not temporary_blockers.is_empty():
		grid = grid.duplicate()
		var start := _cell_of(from)
		var start_cost := grid[start.y * cols + start.x]
		for blocker in temporary_blockers:
			var at: Vector2 = blocker.position
			# Cover whole cells so smoothing cannot cut a circle between grid centers.
			var reach: float = blocker.radius + cell * 0.707107
			var lo := _cell_of(at - Vector2.ONE * reach)
			var hi := _cell_of(at + Vector2.ONE * reach)
			for y in range(lo.y, hi.y + 1):
				for x in range(lo.x, hi.x + 1):
					var center := Vector2((x + 0.5) * cell, (y + 0.5) * cell)
					if grid[y*cols+x]>=0 and center.distance_squared_to(at) <= reach * reach:
						if army_route and (x!=start.x or y!=start.y):temporary_solids.append(Vector2i(x,y))
						grid[y * cols + x] = -1.0
		# A unit already touching the padded region must still be able to leave.
		grid[start.y * cols + start.x] = start_cost
	var sc := _cell_of(from)
	var gc := _cell_of(to)
	if grid[sc.y * cols + sc.x] < 0.0:
		sc = _nearest_walkable(sc, grid, zones, -1, 5)
		if sc.x < 0:
			stats_path_fail += 1
			return out
	var sz := zones[sc.y * cols + sc.x]
	if grid[gc.y * cols + gc.x] < 0.0 or zones[gc.y * cols + gc.x] != sz:
		var snapped := _row_snap(gc,grid,zones,sz,24,3 if wall_crusher else (2 if amphibious else int(water_mode))) if temporary_blockers.is_empty() else _nearest_walkable(gc, grid, zones, sz, 24)
		if snapped.x < 0:
			stats_path_fail += 1
			return out
		gc = snapped
	var si := sc.y * cols + sc.x
	var gi := gc.y * cols + gc.x
	if si == gi:
		if grid[gi] >= 0.0:
			out.append(to if _cell_of(to) == gc and grid[_cell_of(to).y * cols + _cell_of(to).x] >= 0.0 else Vector2(gc.x * cell + cell * 0.5, gc.y * cell + cell * 0.5))
		return out
	# A clear segment is already the result of path smoothing. Test against the
	# request's padded grid so deployed units and diagonal corners still block it.
	var destination:=to if _cell_of(to)==gc else Vector2(gc.x+0.5,gc.y+0.5)*cell
	if max_expand>=6000 and line_walkable(from,destination,grid):
		out.append(destination)
		return out
	var reuse := max_expand == 6000 and temporary_blockers.is_empty()
	var domain := 3 if wall_crusher else (2 if amphibious else int(water_mode))
	var key := Vector3i(gc.x,gc.y,domain + (4 if army_route else 0))
	if reuse:
		if _route_epoch != epoch:
			_routes_by_goal.clear()
			_route_epoch = epoch
		for previous: PackedVector2Array in _routes_by_goal.get(key,[]):
			var joined := _join_route(previous,from,destination,grid)
			if not joined.is_empty():
				stats_route_reuse += 1
				return joined
	var complete:=true
	var native_path:=PackedVector2Array()
	if army_route and max_expand>=WINDOW_EDGE*WINDOW_EDGE:
		native_path=_window_route(sc,gc,domain,base_grid,temporary_solids)
	if not native_path.is_empty():
		stats_window_paths += 1
	elif army_route and max_expand == 6000 and temporary_blockers.is_empty() and cols * rows <= MAX_NATIVE_MAP_CELLS:
		if not _native_maps.has(domain):
			_native_maps[domain] = _build_window(Rect2i(0, 0, cols, rows), base_grid)
		var solver: AStarGrid2D = _native_maps[domain]
		native_path = solver.get_point_path(sc, gc)
		if not native_path.is_empty(): stats_map_paths += 1
	if not native_path.is_empty():
		out=native_path
		out[0]=from
		out[-1]=destination
	else:
		out=_bounded_grid_path(from,to,sc,gc,grid,max_expand,not temporary_blockers.is_empty())
		if out.size()<2:return out
		complete=out[-1].is_equal_approx(destination)
	var route := _smooth_path(out, grid)
	if reuse and complete and route.size() >= 3 and route.size() <= MAX_CORRIDOR_POINTS:
		for i in range(1,route.size()):
			if not line_walkable(route[i-1],route[i],grid): return route
		if _routes_by_goal.size() >= MAX_ROUTE_GOALS and not _routes_by_goal.has(key):
			_routes_by_goal.erase(_routes_by_goal.keys()[0])
		var corridors: Array = _routes_by_goal.get_or_add(key,[])
		corridors.push_front(route.duplicate())
		if corridors.size() > MAX_CORRIDORS_PER_GOAL: corridors.pop_back()
	return route

# Private to one synchronous path service. Positive stamps mark open cells
# and negative stamps mark closed cells for the current search.
var _search_marks := PackedInt32Array()
var _search_scores := PackedFloat32Array()
var _search_parents := PackedInt32Array()
var _search_id := 0

func _bounded_grid_path(from:Vector2,to:Vector2,sc:Vector2i,gc:Vector2i,grid:PackedFloat32Array,max_expand:int,temporary:bool) -> PackedVector2Array:
	var _call_log_scope = preload("res://scripts/world/battle_call_counters.gd").enter(66)
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
		var current_score := _search_scores[idx]
		for direction: Vector2i in SEARCH_DIRECTIONS:
			var dx := direction.x
			var dy := direction.y
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
			var tentative := current_score + step
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
	preload("res://scripts/world/battle_call_counters.gd").iterations(66, expanded)
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
func _join_route(route: PackedVector2Array, from: Vector2, destination: Vector2, grid: PackedFloat32Array) -> PackedVector2Array:
	for i in range(route.size()-2,0,-1):
		var near := Geometry2D.get_closest_point_to_segment(from,route[i-1],route[i])
		if from.distance_squared_to(near) > 4.0*cell*cell: continue
		if not line_walkable(from,route[i],grid): continue
		if route[-1] != destination and not line_walkable(route[-2],destination,grid): break
		var result := route.slice(i-1)
		result[0] = from
		result[-1] = destination
		return result
	return PackedVector2Array()

## 视线拉直：RA2 A* 输出后同样会删掉多余的格子拐点。
func _smooth_path(points: PackedVector2Array, grid: PackedFloat32Array) -> PackedVector2Array:
	if points.size() <= 2:
		return points
	var res := PackedVector2Array()
	res.append(points[0])
	var anchor := 0
	var guard := 0
	while anchor < points.size() - 1 and guard < points.size() * 2:
		guard += 1
		var far := anchor + 1
		for j in range(points.size() - 1, anchor, -1):
			if line_walkable(points[anchor], points[j], grid):
				far = j
				break
		res.append(points[far])
		anchor = far
	return res

## 遍历线段穿过的每个网格；跨格角时两侧也须可走，与 A* 的禁止切角规则一致。
func line_walkable(a: Vector2, b: Vector2, grid: PackedFloat32Array) -> bool:
	# Keep the DDA crossing order and corner tests, but advance the flat cell
	# index directly. No cached result: live grid changes are visible per call.
	var x := clampi(int(floor(a.x / cell)), 0, cols - 1)
	var y := clampi(int(floor(a.y / cell)), 0, rows - 1)
	var gx := clampi(int(floor(b.x / cell)), 0, cols - 1)
	var gy := clampi(int(floor(b.y / cell)), 0, rows - 1)
	var index := y * cols + x
	if grid[index] < 0.0: return false
	if x == gx and y == gy: return true
	var d := b - a
	var sx := signi(gx - x)
	var sy := signi(gy - y)
	var row_step := sy * cols
	var tx := INF
	var ty := INF
	var dx := INF
	var dy := INF
	if sx != 0:
		dx = cell / absf(d.x)
		var edge := (x + (1 if sx > 0 else 0)) * cell
		tx = (edge - a.x) / d.x
	if sy != 0:
		dy = cell / absf(d.y)
		var edge := (y + (1 if sy > 0 else 0)) * cell
		ty = (edge - a.y) / d.y
	while x != gx or y != gy:
		if x == gx: tx = INF
		if y == gy: ty = INF
		if absf(tx - ty) < 0.000001:
			if grid[index + sx] < 0.0 or grid[index + row_step] < 0.0:
				return false
			x += sx
			y += sy
			index += sx + row_step
			tx += dx
			ty += dy
		elif tx < ty:
			x += sx
			index += sx
			tx += dx
		else:
			y += sy
			index += row_step
			ty += dy
		if x < 0 or y < 0 or x >= cols or y >= rows: return false
		if grid[index] < 0.0: return false
	return true

func stats() -> Dictionary:
	return {
		"cols": cols,
		"rows": rows,
		"cached_fields": _fields.size(),
		"built": stats_built,
		"requests": stats_requests,
		"paths": stats_paths,
		"shared_routes": stats_route_reuse,
		"path_fail": stats_path_fail,
		"zones_ground": _max_zone(ground_zone),
		"zones_water": _max_zone(water_zone),
		"epoch": epoch,
	}

func _max_zone(zones: PackedInt32Array) -> int:
	var m := 0
	for z in zones:
		if z > m:
			m = z
	return m
