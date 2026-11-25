extends RefCounted
## Geometric routes through gaps that disappear when foundations are rasterized.
## Store geometry at the same time the shared service stamps its navigation grid.
var shapes: Array[Dictionary] = []
var gates: Array[Dictionary] = []
var shape_bins: Dictionary = {}
const BIN := 240.0
var terrain := PackedFloat32Array()

func reset(ground: PackedFloat32Array) -> void:
	terrain = ground.duplicate()
	shapes.clear()
	gates.clear()
	shape_bins.clear()

func add_shape(pos: Vector2, poly: PackedVector2Array, radius: float, grid_size: float) -> void:
	var bounds := Placement.aabb(poly,pos) if not poly.is_empty() else Rect2(pos-Vector2.ONE*radius,Vector2.ONE*radius*2)
	# Only neighbouring footprints can form a gate. Long rows of walls should
	# not make each terrain rebuild compare every pair on the map.
	var reach := bounds.grow(2.5*grid_size)
	var first := Vector2i((reach.position / BIN).floor())
	var last := Vector2i((reach.end / BIN).floor())
	var neighbors := {}
	for y in range(first.y,last.y+1):
		for x in range(first.x,last.x+1):
			for index in shape_bins.get(Vector2i(x,y),[]): neighbors[index] = true
	for index in neighbors:
		var box: Rect2 = shapes[index].bounds
		if not box.grow(2.5*grid_size).intersects(bounds): continue
		record_gap(bounds,box,false)
		record_gap(bounds,box,true)
	first = Vector2i((bounds.position/BIN).floor())
	last = Vector2i((bounds.end/BIN).floor())
	for y in range(first.y,last.y+1):
		for x in range(first.x,last.x+1):
			var key := Vector2i(x,y)
			if not shape_bins.has(key): shape_bins[key] = []
			shape_bins[key].append(shapes.size())
	shapes.append({"bounds":bounds,"position":pos,"poly":poly,"radius":radius})

func record_gap(a: Rect2, b: Rect2, vertical: bool) -> void:
	# Project onto the direction of travel and its perpendicular.
	var axis := Vector2.DOWN if vertical else Vector2.RIGHT
	var normal := Vector2.RIGHT if vertical else Vector2.DOWN
	var low := minf(a.end.dot(normal), b.end.dot(normal))
	var high := maxf(a.position.dot(normal), b.position.dot(normal))
	if high <= low: return
	if minf(a.end.dot(axis), b.end.dot(axis)) <= maxf(a.position.dot(axis), b.position.dot(axis)): return
	var mid := normal * (low+high)*0.5
	gates.append({"a":mid+axis*minf(a.position.dot(axis),b.position.dot(axis)),
		"b":mid+axis*maxf(a.end.dot(axis),b.end.dot(axis)), "axis":axis, "width":high-low})

func clear(service, a: Vector2, b: Vector2, radius: float, stationary: Array) -> bool:
	var bounds := Rect2(Vector2.ZERO,Vector2.ONE*service.map_size).grow(-radius)
	if not bounds.has_point(a) or not bounds.has_point(b): return false
	if not service.line_walkable(a,b,terrain) or not service._segment_clear_of_units(a,b,stationary): return false
	var sweep := Rect2(a,b-a).abs().grow(radius)
	# Short traffic probes usually touch only a handful of the map's foundations.
	var first:=Vector2i((sweep.position/BIN).floor())
	var last:=Vector2i((sweep.end/BIN).floor())
	var candidates:Array=shapes
	if (last.x-first.x+1)*(last.y-first.y+1)*4 < shapes.size():
		candidates=[]
		var visited:Dictionary={}
		for y in range(first.y,last.y+1):
			for x in range(first.x,last.x+1):
				for idx:int in shape_bins.get(Vector2i(x,y),[]):
					if not visited.has(idx):
						visited[idx]=true
						candidates.append(shapes[idx])
	for item in candidates:
		if not sweep.intersects(item.bounds,true): continue
		var off: Vector2 = item.position
		var poly: PackedVector2Array = item.poly
		if poly.is_empty():
			var closest := Geometry2D.get_closest_point_to_segment(off,a,b)
			if off.distance_squared_to(closest) <= (radius+item.radius)**2: return false
		else:
			if Placement.point_in_poly(poly,a-off) or Placement.point_in_poly(poly,b-off): return false
			for i in poly.size():
				var pair := Geometry2D.get_closest_points_between_segments(a,b,off+poly[i],off+poly[(i+1)%poly.size()])
				if pair[0].distance_squared_to(pair[1]) <= radius*radius: return false
	return true

func route(service, start: Vector2, goal: Vector2, radius: float, stationary: Array) -> PackedVector2Array:
	var _call_log_scope = preload("res://scripts/world/battle_call_counters.gd").enter(25)
	var best := PackedVector2Array()
	if shapes.is_empty() or start.is_equal_approx(goal): return best
	var map := Rect2(Vector2.ZERO,Vector2.ONE*service.map_size)
	if not map.has_point(start) or not map.has_point(goal): return best
	if service.line_walkable(start,goal,service.cost): return best
	if clear(service,start,goal,radius,stationary): return PackedVector2Array([start,goal])
	var travel := start.direction_to(goal)
	var shortest: float = start.distance_to(goal)*1.2 + service.cell
	for gate in gates:
		if gate.width <= radius*2: continue
		var axis: Vector2 = gate.axis
		var along := travel.dot(axis)
		if absf(along)<0.6: continue
		if along<0: axis = -axis
		var entry: Vector2 = gate.a if along>0 else gate.b
		var exit_point: Vector2 = gate.b if along>0 else gate.a
		entry -= axis*(radius+20)
		exit_point += axis*(radius+20)
		if (entry-start).dot(axis)<0 or (goal-exit_point).dot(axis)<0: continue
		var length := start.distance_to(entry)+entry.distance_to(exit_point)+exit_point.distance_to(goal)
		if length>=shortest: continue
		if clear(service,start,entry,radius,stationary) and clear(service,entry,exit_point,radius,stationary) and clear(service,exit_point,goal,radius,stationary):
			best=PackedVector2Array([start,entry,exit_point,goal])
			shortest=length
	return best
