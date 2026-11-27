extends RefCounted
## World actions in the ALL01UMD transition. Attach by original structure instance, never by type alone.
const CivilianOrders = preload("res://scripts/units/civilian_orders.gd")

static func bind_sites(world) -> void:
	var layout: Dictionary = world.AlliedFirst.Places.data("yr_all01umd")
	var positions := {}
	for b in world.buildings:
		if world.actor_alive(b):
			var key := Vector2i(b.position.round())
			if not positions.has(key): positions[key] = []
			positions[key].append(b)
	for r in world.AlliedFirst.Field.data.structures:
		if not r[8] or str(r[7]).to_lower() not in ["089afd2c","089ae20c","089afa8c","0d86a04c","08a9aacc","08a9a9ec","08a9a90c","08a9a82c","089ed98c"]: continue
		var dims := str(layout.site_types[r[2]].foundation).split("x")
		var center: Vector2 = (Vector2(r[4],r[5])+Vector2(1-int(dims[1]),int(dims[0])-1)*0.5)*world.AlliedFirst.Places.CELL
		for b in positions.get(Vector2i(center.round()),[]):
			if b.building_id==r[2]:
				b.special.allied_first_index = r[0]
				b.special.allied_first_tag = str(r[7]).to_lower()
				break

static func evict(world,tags: Dictionary) -> void:
	for b in world.buildings:
		if world.actor_alive(b) and tags.has(b.special.get("allied_first_tag","")) and not b.special.get("occupants",[]).is_empty():
			CivilianOrders.evacuate(b)

static func remove_room_assets(world,house: String,op: int) -> void:
	if op in [119,121,122]:
		for u in world.units.duplicate():
			if not world.actor_alive(u) or u.special.get("allied_first_room","")!=house: continue
			if op==121 and (u.is_naval or u.is_air): continue
			if op==122 and not u.is_naval: continue
			world.AlliedFirst.Orders.consume(u)
			world.units.erase(u)
	if op in [119,120]:
		for b in world.buildings.duplicate():
			if world.actor_alive(b) and b.special.get("allied_first_room","")==house:
				world.buildings.erase(b)
				b.queue_free()
		world.invalidate_building_membership()

static func rebuild(world,spawn: Dictionary) -> bool:
	var type: String = spawn.get("type","")
	if {"NANRCT":"Confederation","GTGCAN":"Americans","GAPOWR":"Americans"}.get(type,"")!=spawn.get("house","") or type.is_empty(): return false
	var uv: Array = spawn.waypoint.uv
	var dims := str(GameData.get_building(type).foundation).split("x")
	var center: Vector2 = (Vector2(uv[0],uv[1])+Vector2(1-int(dims[1]),int(dims[0])-1)*0.5)*world.AlliedFirst.Places.CELL
	for b in world.buildings:
		if world.actor_alive(b) and b.building_id==type and b.position.is_equal_approx(center): return true
	var reactor = world._place_building(type,world.AlliedFirst.side(spawn.house),center,true)
	if reactor==null: return false
	reactor.special.allied_first_room = spawn.house
	if type=="GTGCAN": reactor.special.no_crew = true
	reactor.refresh_house_color()
	world._refresh_pathing()
	world._update_power()
	return true

static func damage_at_waypoint(world,waypoint: int) -> void:
	var mission = world.AlliedFirst
	var row: Array = mission.Places.data(mission.MAP).waypoints[str(waypoint)]
	if not row[2]: return
	var point: Vector2 = mission.wp(waypoint)
	for actor in world.units + world.buildings:
		if not world.actor_alive(actor) or (actor is Unit and (actor.embarked_in!=null or actor.is_air)): continue
		var ground: Vector2 = actor.position
		if actor is Building:
			# Tile occupation uses the retail foundation, including its edge cells.
			var dims: PackedStringArray = str(actor.data.get("foundation","1x1")).to_lower().split("x")
			if dims.size()!=2: continue
			var half: Vector2 = Vector2(float(dims[1]),float(dims[0]))*mission.Places.CELL*0.5
			ground = point.clamp(actor.position-half,actor.position+half)
		var distance := point.distance_to(ground)
		if Ra2Damage.in_spread(distance,"HE"):
			actor.receive_hit(Ra2Damage.target_damage(100.0,"HE",actor,distance),"explosive",{},null,"HE")
	Ra2Fx.play_impact(world,"HE",100,point)
