extends RefCounted
## Keep factory doors open. One port per timed inspection, never a per-unit A* loop.
const PERIOD := 3.0
const BLOCK_WAIT := 12.0
const SALE_COOLDOWN := 30.0
const CACHE := &"ai_access_lanes"
const Routes=preload("res://scripts/world/ai_base_routes.gd")

static func lanes(world, owner: String) -> Array:
	var cache: Dictionary = world.get_meta(CACHE,{})
	if cache.get("epoch",-1)!=world.path_service.epoch or cache.get("nav",0)!=world.path_service.get_instance_id():
		cache={"epoch":world.path_service.epoch,"nav":world.path_service.get_instance_id(),"owners":{}}
		world.set_meta(CACHE,cache)
	if cache.owners.has(owner): return cache.owners[owner]
	var result: Array=[]
	for line in world.buildings:
		if not world.actor_alive(line) or line.side!=owner: continue
		if line.building_id not in ["GAWEAP","NAWEAP","GAPILE","NAHAND","GAREFN","NAREFN"]: continue
		var product: String = "CMIN" if line.is_refinery() else ("BFRT" if line.building_id.ends_with("WEAP") else "GGI")
		var radius: float = maxf(16.0,float(GameData.get_unit(product).radius))
		var direction := ProductionExit.direction(line)
		var start: Vector2
		if ProductionExit.supported(line): start=ProductionExit.origin(line,GameData.get_unit(product))
		else: start=line.position+direction*(line.footprint_clearance(direction)+radius+world.path_service.cell+4)
		if not start.is_finite(): continue
		var end: Vector2=start+direction*200.0
		result.append({"line":line,"start":start,"end":end,"radius":radius,
			"rect":Rect2(start,end-start).abs().grow(radius+world.path_service.cell*0.5)})
	cache.owners[owner]=result
	return result

static func placement_ok(world, owner: String, data: Dictionary, point: Vector2) -> bool:
	var footprint := Placement.aabb(Building.placement_poly(data),point).grow(2.0)
	for lane in lanes(world,owner):
		if footprint.intersects(lane.rect,true): return false
	return Routes.placement_ok(world.path_service,footprint)

static func tick(ai, delta: float) -> void:
	if ai.enemy_base=="swarm" or not BattleRequest.is_ai_house(ai.house_id): return
	var state: Dictionary=ai.ai_state
	state.access_clock=float(state.get("access_clock",0.0))+delta
	if float(state.get("access_next",0.0))>state.access_clock: return
	state.access_next=state.access_clock+PERIOD
	var obstruction=Routes.obstruction(ai,state.access_clock)
	if obstruction!=null: sell_building(ai,obstruction,state.access_clock)
	var ports:=lanes(ai.battle,ai.house_id)
	if ports.is_empty(): return
	var cursor:int=int(state.get("access_cursor",0))%ports.size()
	state.access_cursor=cursor+1
	inspect(ai,ports[cursor],state.access_clock)

static func inspect(ai, lane: Dictionary, now: float) -> void:
	var world=ai.battle
	var line=lane.line
	if not world.actor_alive(line) or line.side!=ai.house_id or line.under_construction: return
	var nearby:=false
	var moved:=0
	for unit in world.units:
		if not world.actor_alive(unit) or unit.side!=ai.house_id or unit.is_air or unit.is_naval or unit.embarked_in!=null: continue
		if not lane.rect.grow(60.0).has_point(unit.position): continue
		nearby=true
		if moved>=2 or unit.is_harvester or unit.repairing or unit.special.has("action") or AlliedAbilities.frozen(unit) or world.actor_alive(unit.attack_target): continue
		var old: Vector2=unit.special.get("ai_access_position",unit.position)
		var stalled: bool=unit.position.distance_to(old)<8.0
		unit.special.ai_access_position=unit.position
		if not stalled or not unit.special.has("ai_access_since"): unit.special.ai_access_since=now
		if unit.has_move_order and now-float(unit.special.ai_access_since)<6.0: continue
		if now-float(unit.special.get("ai_access_moved",-100.0))<9.0: continue
		var normal:Vector2=Vector2(lane.end-lane.start).normalized().orthogonal()
		var sign_value:float=1.0 if unit.get_instance_id()%2==0 else -1.0
		if unit.has_move_order:
			world.ai_dispatch.submit(world,unit,{"kind":"detour","offset":normal*sign_value*128.0,"goal":unit.move_target,"attack":unit.attack_move})
		else:
			world.ai_dispatch.submit(world,unit,{"kind":"rally","point":lane.end+normal*sign_value*128.0})
		unit.special.ai_access_moved=now
		moved+=1
	if not nearby and not line.exit_blocked:
		line.special.erase("ai_access_blocked_since")
		return
	# Legacy radial producers have several valid doors. A single preferred lane
	# is not sufficient evidence that demolition is necessary.
	if not ProductionExit.supported(line):
		line.special.erase("ai_access_blocked_since")
		return
	# Mobile congestion cannot justify selling a building.
	if clear_without(world,lane,null):
		line.special.erase("ai_access_blocked_since")
		return
	if not line.special.has("ai_access_blocked_since"):
		line.special.ai_access_blocked_since=now
		return
	if now-float(line.special.ai_access_blocked_since)<BLOCK_WAIT or now<float(ai.ai_state.get("access_sale_after",0.0)): return
	# A valid route around an obstruction also rules out a sale.
	var nav=world.path_service
	if not nav.is_blocked(lane.start) and not nav.is_blocked(lane.end):
		var route:PackedVector2Array=nav.find_path(lane.start,lane.end,false,800)
		if route.size()>1 and route[-1].distance_to(lane.end)<20.0: return
	var candidate=null
	for building in world.buildings:
		if building==line or not sellable(ai,building): continue
		if not lane.rect.intersects(Placement.aabb(building.footprint_poly(),building.position),true): continue
		# Removing exactly this building must open the full lane, terrain included.
		if not clear_without(world,lane,building): continue
		if candidate==null or float(building.data.get("cost",0))<float(candidate.data.get("cost",0)): candidate=building
	if candidate==null: return
	sell_building(ai,candidate,now)
	line.special.erase("ai_access_blocked_since")

static func sell_building(ai, candidate, now: float) -> void:
	var world=ai.battle
	var refund:float=GameData.ra2_refund(int(candidate.data.get("cost",0)))+candidate.total_production_paid()
	candidate.retire_sold()
	world.buildings.erase(candidate)
	world.rally_points.erase(candidate.get_instance_id())
	world._refresh_pathing()
	world._update_power()
	world.credit_side(ai.house_id,refund)
	ai.ai_state.access_sale_after=now+SALE_COOLDOWN
	ai.ai_state.access_sales=int(ai.ai_state.get("access_sales",0))+1

static func sellable(ai, building) -> bool:
	if not ai.battle.actor_alive(building) or building.side!=ai.house_id or building.under_construction: return false
	if building.is_hq or building.is_refinery() or building.building_id=="CAOILD" or building.data.get("tags",[]).has("civilian"): return false
	var raw:Dictionary=GameData.ra2_source_buildings.get(building.building_id,{}).get("extra",{})
	if GameData._ra2_flag(raw.get("Unsellable",false)): return false
	if WallArt.is_wall(building.data): return true
	# Preserve the last production/tech building and every power generator.
	if building.power>0: return false
	var copies:=0
	for other in ai.battle.buildings:
		if not is_instance_valid(other) or other.side!=ai.house_id or other.building_id!=building.building_id or other.under_construction: continue
		if ai.battle.actor_alive(other):
			copies+=1
			if copies>1: return true
	return false

static func clear_without(world, lane: Dictionary, omitted) -> bool:
	var nav=world.path_service
	var a:Vector2=lane.start
	var b:Vector2=lane.end
	var radius:float=lane.radius
	var bounds:=Rect2(Vector2.ZERO,Vector2.ONE*world.map_size).grow(-radius)
	if not bounds.has_point(a) or not bounds.has_point(b): return false
	var normal:=a.direction_to(b).orthogonal()*radius
	for offset in [Vector2.ZERO,normal,-normal]:
		if not nav.line_walkable(a+offset,b+offset,nav.passages.terrain): return false
	for shape in nav.passages.shapes:
		if not lane.rect.intersects(shape.bounds,true): continue
		if omitted!=null and shape.position==omitted.position and shape.bounds==Placement.aabb(omitted.footprint_poly(),omitted.position): continue
		var poly:PackedVector2Array=shape.poly
		var at:Vector2=shape.position
		if poly.is_empty():
			if at.distance_to(Geometry2D.get_closest_point_to_segment(at,a,b))<=radius+float(shape.radius): return false
		else:
			if Placement.point_in_poly(poly,a-at) or Placement.point_in_poly(poly,b-at): return false
			for i in poly.size():
				var pair:=Geometry2D.get_closest_points_between_segments(a,b,at+poly[i],at+poly[(i+1)%poly.size()])
				if pair[0].distance_squared_to(pair[1])<=radius*radius: return false
	return true
