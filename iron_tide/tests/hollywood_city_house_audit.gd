extends RefCounted
const Orders = preload("res://scripts/units/civilian_orders.gd")
const Maps = preload("res://scripts/world/native_maps.gd")
const CLOSED := ["CALA05","CARUS08","CARUS10","CARUS11"]

static func run(world, tree: SceneTree) -> int:
	var map := Maps.data(world.map_layout())
	var soldier = world.units.filter(func(u):return u.side=="ally" and u.unit_id=="E1")[0]
	for actor in world.units: actor.set_physics_process(false)
	for building in world.buildings: building.set_process(false)
	world.set_process(false)
	var failures := 0
	var passed := 0
	var forbidden := 0
	var types := {}
	for site in map.structures:
		var id: String = site[0]
		var definition: Dictionary = map.site_types[id]
		if definition.canbeoccupied != "yes": continue
		var dims: PackedStringArray = str(definition.foundation).to_lower().split("x")
		var point := Vector2(site[1],site[2])*Maps.CELL + Vector2(1-int(dims[1]),int(dims[0])-1)*Maps.CELL*.5
		var matches: Array = world.buildings.filter(func(b):return world.actor_alive(b) and b.building_id==id and b.position.is_equal_approx(point))
		var key := "%s %s" % [id,point]
		if matches.size()!=1:
			print("HOUSE MISSING ",key)
			failures+=1
			continue
		var house = matches[0]
		if id in CLOSED:
			if Orders.can_enter(soldier,house): failures+=1;print("HOUSE CLOSED FAILED ",key)
			else: forbidden+=1
			continue
		types[id]=true
		var problems := PackedStringArray()
		if Orders.slots(house)!=int(definition.maxnumberoccupants):problems.append("capacity")
		world.center_on(point)
		soldier.position=point+Vector2(55,0)
		world.fog.rebuild()
		house.selected=true
		house.queue_redraw()
		await RenderingServer.frame_post_draw
		if house._art_frame!=0:problems.append("empty")
		Orders.enter(soldier,house)
		await RenderingServer.frame_post_draw
		if soldier.embarked_in!=house or house.side!="ally" or house._art_frame!=2:problems.append("occupied")
		house.hp=house.max_hp*.4
		Orders.withdraw(house,soldier)
		house.queue_redraw()
		await RenderingServer.frame_post_draw
		if soldier.embarked_in!=null or house.side!="neutral" or house._art_frame!=1:problems.append("withdraw/damage")
		house.hp=house.max_hp
		house.queue_redraw()
		house.selected=false
		if problems.is_empty():passed+=1
		else: failures+=1
		print("HOUSE ROW ",key," ","OK" if problems.is_empty() else problems)
	print("HOUSE TOTAL passed=",passed," types=",types.size()," forbidden=",forbidden," failures=",failures)
	return int(failures>0 or passed!=109 or types.size()!=51 or forbidden!=36)
