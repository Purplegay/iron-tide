extends RefCounted
## Local visibility graph for parked hulls whose inflated grid cells seal a bridge.
const SIDES := 12
const MAX_HULLS := 6
const MAX_DISTANCE := 600.0
const KEY := "bridge_traffic_route"

static func obstructions(unit, parked:Array) -> Array:
	var result:Array=parked.duplicate()
	# Two vehicles can both have movement orders while physically wedged. The
	# last slide contacts reveal that case without treating every mover as parked.
	for index in unit.get_slide_collision_count():
		var other=unit.get_slide_collision(index).get_collider()
		if not other is Unit or not AlliedAbilities.alive(other) or other.embarked_in!=null or other.is_air or other.is_naval:continue
		if not BattleRequest.friendly(unit.side,other.side) or unit._local_traffic.friendly_unit_pair(unit,other):continue
		var point:Vector2=other.global_position
		if result.any(func(item):return item.position.is_equal_approx(point)):continue
		result.append({"position":point,"radius":unit.radius+other.radius+8.0})
	return result

static func find(unit, goal:Vector2, blockers:Array) -> PackedVector2Array:
	var empty:=PackedVector2Array()
	var start:Vector2=unit.global_position
	if blockers.is_empty() or start.distance_to(goal)>MAX_DISTANCE:return empty
	var world=unit._navigation_world()
	if world==null or world.path_service==null:return empty
	var service=world.path_service
	var circles:Array=[]
	for blocker in blockers:
		# stalled_blockers adds eight pixels before rasterization. Retain actual
		# combined body radii; the physical move still checks every live collider.
		var radius:float=blocker.radius-8.0
		if start.distance_to(blocker.position)<radius-0.1:return empty
		circles.append({"position":blocker.position,"radius":radius})
	var nearest:Array=circles.duplicate()
	nearest.sort_custom(func(a,b):return start.distance_squared_to(a.position)<start.distance_squared_to(b.position))
	var points:Array[Vector2]=[start,goal]
	for index in mini(MAX_HULLS,nearest.size()):
		var circle:Dictionary=nearest[index]
		var reach:float=(circle.radius+2.0)/cos(PI/SIDES)
		for side in SIDES:
			var point:Vector2=circle.position+Vector2.from_angle(side*TAU/SIDES)*reach
			if service.passages.clear(service,point,point,unit.radius+0.1,circles):points.append(point)
	var costs:Array[float]=[]
	var parents:Array[int]=[]
	var closed:Array[bool]=[]
	for point in points:costs.append(INF);parents.append(-1);closed.append(false)
	costs[0]=0.0
	for iteration in points.size():
		var best:=-1
		for i in points.size():
			if not closed[i] and is_finite(costs[i]) and (best<0 or costs[i]<costs[best]):best=i
		if best<0:return empty
		if best==1:
			var route:=PackedVector2Array()
			while best>=0:route.insert(0,points[best]);best=parents[best]
			return route
		closed[best]=true
		for i in points.size():
			if closed[i]:continue
			var cost:float=costs[best]+points[best].distance_to(points[i])
			if cost>=costs[i]:continue
			if not service.passages.clear(service,points[best],points[i],unit.radius+0.1,circles):continue
			costs[i]=cost;parents[i]=best
	return empty
