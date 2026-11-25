extends RefCounted
## Bounded local connectivity probes; never mutate the live navigation grid.
const STEPS := [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]
const MARGIN := 6

static func region(nav, bounds: Rect2) -> Rect2i:
	var first:Vector2i=nav._cell_of(bounds.position)
	var last:Vector2i=nav._cell_of(bounds.end)
	return Rect2i(first,last-first+Vector2i.ONE)

static func center(nav, point: Vector2i) -> Vector2:
	return (Vector2(point)+Vector2.ONE*0.5)*nav.cell

static func flood(nav, start: Vector2i, area: Rect2i, patch: Dictionary) -> Dictionary:
	var seen:Dictionary={}
	if not area.has_point(start) or float(patch.get(start,nav.cost[start.y*nav.cols+start.x]))<0: return seen
	var queue:Array[Vector2i]=[start]
	seen[start]=true
	var cursor:=0
	while cursor<queue.size():
		var point:Vector2i=queue[cursor]
		cursor+=1
		for step in STEPS:
			var next:Vector2i=point+step
			if not area.has_point(next) or seen.has(next): continue
			if float(patch.get(next,nav.cost[next.y*nav.cols+next.x]))<0: continue
			seen[next]=true
			queue.append(next)
	return seen

static func placement_ok(nav, footprint: Rect2) -> bool:
	var stamp:=footprint.grow(nav.cell*0.5)
	var cells:=region(nav,stamp)
	var patch:Dictionary={}
	var edge:Dictionary={}
	for y in range(cells.position.y,cells.end.y):
		for x in range(cells.position.x,cells.end.x):
			var point:=Vector2i(x,y)
			if stamp.has_point(center(nav,point)): patch[point]=-1.0
	for point in patch:
		for step in STEPS:
			var next:Vector2i=point+step
			if next.x<0 or next.y<0 or next.x>=nav.cols or next.y>=nav.rows or patch.has(next): continue
			if nav.cost[next.y*nav.cols+next.x]>=0: edge[next]=true
	if edge.size()<2: return true
	var zones:PackedInt32Array=nav._movement_zones(false,false,false)
	var area:=region(nav,stamp.grow(nav.cell*MARGIN))
	var reached:Dictionary={}
	for point in edge:
		var zone:int=zones[point.y*nav.cols+point.x]
		if reached.has(zone):
			if not reached[zone].has(point): return false
		else: reached[zone]=flood(nav,point,area,patch)
	return true

static func removal_patch(nav, building) -> Dictionary:
	var bounds:=Placement.aabb(building.footprint_poly(),building.position)
	var stamp:=bounds.grow(2.0+nav.cell*0.5)
	var cells:=region(nav,stamp)
	var shapes:Array=[]
	var omitted:=false
	for shape in nav.passages.shapes:
		if not omitted and shape.position==building.position and shape.bounds==bounds:
			omitted=true
			continue
		if shape.bounds.grow(nav.BLOCK_PAD+nav.cell).intersects(stamp,true): shapes.append(shape)
	var patch:Dictionary={}
	for y in range(cells.position.y,cells.end.y):
		for x in range(cells.position.x,cells.end.x):
			var point:=Vector2i(x,y)
			var at:=center(nav,point)
			if not stamp.has_point(at): continue
			var cost:float=nav.passages.terrain[y*nav.cols+x]
			for shape in shapes:
				if not shape.poly.is_empty():
					if shape.bounds.grow(2.0+nav.cell*0.5).has_point(at): cost=-1.0;break
				else:
					var radius:float=shape.radius+nav.BLOCK_PAD
					if region(nav,Rect2(shape.position-Vector2.ONE*radius,Vector2.ONE*radius*2)).has_point(point) and at.distance_to(shape.position)<=radius+nav.cell*0.4: cost=-1.0;break
			patch[point]=cost
	return patch

static func opens_route(nav, unit, goal: Vector2, building) -> bool:
	var zones:PackedInt32Array=nav._movement_zones(false,false,false)
	var target:Vector2i=nav._nearest_walkable(nav._cell_of(goal),nav.cost,zones,-1,6)
	var start:Vector2i=nav._cell_of(unit.position)
	if target.x<0 or nav.cost[start.y*nav.cols+start.x]<0: return false
	var target_zone:int=zones[target.y*nav.cols+target.x]
	if target_zone==zones[start.y*nav.cols+start.x]: return false
	var bounds:=Placement.aabb(building.footprint_poly(),building.position).expand(unit.position).grow(nav.cell*MARGIN)
	var reached:=flood(nav,start,region(nav,bounds),removal_patch(nav,building))
	for point in reached:
		if zones[point.y*nav.cols+point.x]==target_zone: return true
	return false

static func obstruction(ai, now: float):
	var state:Dictionary=ai.ai_state
	if now<float(state.get("access_sale_after",0.0)): return null
	var trapped:Array=[]
	for unit in ai.battle.units:
		if not ai.Tactics.fighter(ai.battle,unit,ai.house_id) or unit.special.get("ai_campaign_role")!="attack": continue
		if not unit.special.has("ai_blocked_route") or unit.has_move_order or unit.repairing or unit.special.has("action") or ai.battle.actor_alive(unit.attack_target): continue
		if unit.position.distance_to(ai.base_center)>900: continue
		var old:Vector2=unit.special.get("ai_route_position",Vector2.INF)
		if old.distance_to(unit.position)>16.0:
			unit.special.ai_route_position=unit.position
			unit.special.ai_route_since=now
		if now-float(unit.special.get("ai_route_since",now))>=ai.BaseAccess.BLOCK_WAIT: trapped.append(unit)
	if trapped.is_empty(): return null
	var candidates:Array=[]
	for building in ai.battle.buildings:
		if ai.BaseAccess.sellable(ai,building) and building.position.distance_to(ai.base_center)<1000: candidates.append(building)
	if candidates.is_empty(): return null
	var cursor:int=int(state.get("access_route_cursor",0))
	state.access_route_cursor=cursor+1
	var building=candidates[cursor%candidates.size()]
	var unit=trapped[(cursor/candidates.size())%trapped.size()]
	var goal:Vector2=unit.special.ai_blocked_route.goal
	if not opens_route(ai.battle.path_service,unit,goal,building): return null
	# Coarse grid separation alone cannot justify demolition of a narrow but usable passage.
	var used:Array[Vector2]=[]
	if ai.battle.resolve_move_slot(unit,goal,used,50.0).distance_to(unit.position)>Unit.ARRIVE_EPS: return null
	return building
