extends RefCounted
## EP1 HeavyWalker BezierProjectile, LeapWeapon and ReplaceSelf. World scale is 1.5.
# Uprising UNPACKING uses JMPA (36 samples at 30 FPS, played at 2x).
const TAKEOFF_SECONDS:=35.0/60.0
const SPEED:=300.0*1.5
const STEPS:=24

static func takeoff_seconds(jump:Dictionary) -> float:
	# Existing saves encode elapsed time against the former three-second pre-roll.
	return float(jump.get("takeoff_seconds",3.0))

# A pending approach or flight owns its destination, so group orders also work
# before the first building exists. Both fields already survive battle saves.
static func landing_position(unit,requested:Vector2,launch:Vector2,at_contact:=false) -> Vector2:
	var world=unit._battle_world()
	var tower:=GameData.get_building("R3REAPERTURRET")
	var poly:=Building.placement_poly(tower)
	var bounds:=Placement.aabb(poly)
	var spacing:=maxf(maxf(bounds.size.x,bounds.size.y),float(tower.radius)*2.0)+4.0
	var occupied:Array[Vector2]=[]
	for b in world.buildings:
		if AlliedAbilities.alive(b) and b.building_id=="R3REAPERTURRET":occupied.append(b.global_position)
	var reserved:Array[Vector2]=[]
	for other in world.units:
		if other==unit or not AlliedAbilities.alive(other) or other.unit_id!="R3REAPER" or other.embarked_in!=null:continue
		if other.special.has("walker_jump"):reserved.append(other.special.walker_jump.end)
		elif other.has_move_order and other.special.has("walker_approach"):reserved.append(other.special.walker_approach)

	var conflicts:=_near_tower(requested,occupied,spacing) or (not at_contact and _near_tower(requested,reserved,spacing))
	if not conflicts and _clear_site(world,requested,poly):return requested
	if not conflicts and not at_contact:return Vector2.INF
	# Search nearby footprint-sized steps. Prefer the nearest offset to the order,
	# then the shorter flight. A correction must not extend an in-range leap.
	var local_jump:=at_contact or launch.distance_to(requested)<=300.0
	var best:=Vector2.INF
	var best_offset:=INF
	var best_flight:=INF
	for y in range(-4,5):
		for x in range(-4,5):
			var offset:=x*x+y*y
			if offset==0 or offset>16 or offset>best_offset:continue
			var candidate:=requested+Vector2(x,y)*spacing
			var flight:=launch.distance_to(candidate)
			if flight<30 or (local_jump and flight>300) or (offset==best_offset and flight>=best_flight):continue
			if _near_tower(candidate,occupied,spacing) or _near_tower(candidate,reserved,spacing):continue
			if not _clear_site(world,candidate,poly):continue
			best=candidate;best_offset=offset;best_flight=flight
	return best

static func _near_tower(point:Vector2,locations:Array[Vector2],spacing:float) -> bool:
	for pos in locations:
		if absf(pos.x-point.x)<spacing-0.01 and absf(pos.y-point.y)<spacing-0.01:return true
	return false

static func _clear_site(world,point:Vector2,poly:PackedVector2Array) -> bool:
	# Landing checks physical footprints below. A neighboring turret can stamp
	# the same navigation cell without occupying this reserved site.
	var rect:=Placement.aabb(poly,point)
	if rect.position.x<0 or rect.position.y<0 or rect.end.x>world.map_size or rect.end.y>world.map_size:return false
	for water:Rect2 in world.water_rects:
		if rect.intersects(water):return false
	for b in world.buildings:
		if AlliedAbilities.alive(b) and Placement.polys_overlap(poly,point,b.footprint_poly(),b.global_position):return false
	for obstacle in world.get_tree().get_nodes_in_group("obstacles"):
		if world.is_ancestor_of(obstacle) and Placement.circle_hits_poly(poly,obstacle.global_position,obstacle.radius,point):return false
	return true

static func create(start:Vector2,end:Vector2) -> Dictionary:
	var jump:={"start":start,"end":end,"age":0.0,"takeoff_seconds":TAKEOFF_SECONDS,"height1":randf_range(150,160)*1.5,"height2":randf_range(100,110)*1.5}
	build_curve(jump)
	jump.flight=jump.lengths[-1]/SPEED
	return jump

static func build_curve(jump:Dictionary) -> void:
	# Older saves contain the endpoints and duration only. Keep their clock.
	var distance:float=jump.start.distance_to(jump.end)
	jump.height1=jump.get("height1",155*1.5)
	jump.height2=jump.get("height2",105*1.5)
	var lengths:Array[float]=[0.0]
	var previous:=Vector2.ZERO
	for i in range(1,STEPS+1):
		var t:=float(i)/STEPS
		var point:=Vector2(distance*bezier_interpolate(0,0.4,0.6,1,t),bezier_interpolate(0,jump.height1,jump.height2,0,t))
		lengths.append(lengths.back()+point.distance_to(previous))
		previous=point
	jump.lengths=lengths

static func move(unit,jump:Dictionary) -> bool:
	if not jump.has("lengths") and not jump.has("height1"):
		# Finish an already-launched legacy shot along its saved trajectory.
		if jump.age>takeoff_seconds(jump):
			var old_t:=clampf((jump.age-takeoff_seconds(jump))/maxf(0.01,jump.flight),0,1)
			unit.position=jump.start.lerp(jump.end,old_t)
			unit.special.walker_height=sin(old_t*PI)*225.0
			return old_t>=1.0
	if not jump.has("lengths"):build_curve(jump)
	var phase:=clampf((float(jump.age)-takeoff_seconds(jump))/maxf(0.01,jump.flight),0,1)
	var lengths:Array=jump.lengths
	var distance:float=phase*lengths.back()
	var hi:=clampi(lengths.bsearch(distance),1,STEPS)
	var t:=(hi-1+inverse_lerp(lengths[hi-1],lengths[hi],distance))/STEPS
	unit.position=jump.start.lerp(jump.end,bezier_interpolate(0,0.4,0.6,1,t))
	unit.special.walker_height=bezier_interpolate(0,jump.height1,jump.height2,0,t)*sqrt(0.75)
	return phase>=1.0
