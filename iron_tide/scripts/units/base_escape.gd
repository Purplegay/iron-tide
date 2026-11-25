extends RefCounted
## Player-only congestion fallback. Weighted cells prefer the edge of friendly
## foundations; terrain and hostile/neutral structures remain hard obstacles.
const KEY:="player_base_escape"

static func active(unit) -> bool:
	if not unit.special.has(KEY):return false
	var state:Dictionary=unit.special.get(KEY,{})
	var world=unit._navigation_world()
	return not state.is_empty() and unit.side=="ally" and unit.has_move_order and not unit.is_air and not unit.is_naval and not unit._deployed and world!=null and world.path_service!=null and state.get("goal",Vector2.INF)==unit.move_target and int(state.get("epoch",-1))==world.path_service.epoch

static func try_route(unit) -> bool:
	if unit.side!="ally" or not unit.has_move_order or unit.is_air or unit.is_naval or unit._deployed:return false
	var world=unit._navigation_world()
	if world==null or world.path_service==null:return false
	var service=world.path_service
	if service.near_deck(unit.position,unit.radius+40.0):return false
	var friends:Dictionary={}
	var nearby:=false
	for building in world.buildings:
		if not world.actor_alive(building) or not BattleRequest.friendly(unit.side,building.side):continue
		var bounds:Rect2=Placement.aabb(building.footprint_poly(),building.position)
		friends[building.position]=bounds
		if bounds.grow(unit.radius+80.0).has_point(unit.position):nearby=true
	# Unit-only congestion uses the timed friendly collision fallback.
	if not nearby:return false
	var grid:PackedFloat32Array=service.passages.terrain.duplicate()
	# Stamp solid objects after assigning friendly costs, so overlaps never reopen enemies or rocks.
	for shape:Dictionary in service.passages.shapes:
		if not friends.has(shape.position):continue
		var bounds:Rect2=shape.bounds.grow(2.0)
		var lo:Vector2i=service._cell_of(bounds.position)
		var hi:Vector2i=service._cell_of(bounds.end)
		for y in range(lo.y,hi.y+1):
			for x in range(lo.x,hi.x+1):
				var i:int=y*service.cols+x
				if grid[i]<=0:continue
				var p:Vector2=Vector2(x+0.5,y+0.5)*service.cell
				var depth:=maxf(0.0,minf(minf(p.x-bounds.position.x,bounds.end.x-p.x),minf(p.y-bounds.position.y,bounds.end.y-p.y)))
				grid[i]=maxf(grid[i],8.0+depth/service.cell*12.0)
	for shape:Dictionary in service.passages.shapes:
		if friends.has(shape.position):continue
		var bounds:Rect2=shape.bounds.grow(2.0 if not shape.poly.is_empty() else service.BLOCK_PAD)
		var lo:Vector2i=service._cell_of(bounds.position)
		var hi:Vector2i=service._cell_of(bounds.end)
		for y in range(lo.y,hi.y+1):
			for x in range(lo.x,hi.x+1):grid[y*service.cols+x]=-1.0
	var start:Vector2i=service._cell_of(unit.position)
	var goal:Vector2i=service._cell_of(unit.move_target)
	if grid[start.y*service.cols+start.x]<=0 or grid[goal.y*service.cols+goal.x]<=0:return false
	var search:=AStarGrid2D.new()
	search.region=Rect2i(0,0,service.cols,service.rows);search.cell_size=Vector2.ONE*service.cell
	search.offset=Vector2.ONE*service.cell*0.5
	search.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	search.update()
	for y in service.rows:
		for x in service.cols:
			var weight:float=grid[y*service.cols+x]
			if weight<=0:search.set_point_solid(Vector2i(x,y))
			else:search.set_point_weight_scale(Vector2i(x,y),weight)
	var path:=search.get_point_path(start,goal)
	if path.size()<2:return false
	path[0]=unit.position;path[path.size()-1]=unit.move_target
	unit.set_agent_path(path)
	unit.special[KEY]={"goal":unit.move_target,"epoch":service.epoch}
	unit._dodge_t=0.0
	return true

static func buildings(unit,motion:Vector2,existing:Array) -> Array:
	var result:Array=[]
	if not active(unit):return result
	var world=unit._navigation_world()
	var sweep:=Rect2(unit.position,motion).abs().grow(unit.radius+4.0)
	for building in world.buildings:
		if not world.actor_alive(building) or not BattleRequest.friendly(unit.side,building.side) or existing.has(building):continue
		if sweep.intersects(Placement.aabb(building.footprint_poly(),building.position),true):
			unit.add_collision_exception_with(building);result.append(building)
	return result
