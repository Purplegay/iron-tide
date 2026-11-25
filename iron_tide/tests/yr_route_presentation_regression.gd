extends "res://tests/ground_control_regression.gd"

func exercise(mode: String) -> void:
	start(mode)
	var tank = battle.spawn_unit("MTNK", "enemy", Vector2(800, 1000))
	var foe = battle.spawn_unit("MTNK", "ally", Vector2(1450, 1000))
	var end := Vector2(1500, 1000)
	tank.set_agent_path(PackedVector2Array([tank.position, end]))
	battle._place_building("GAPOWR", "ally", Vector2(2700,2700), true)
	check(battle.remaining_route_unchanged(tank,battle.path_epoch()),mode+" remote foundation preserves route")
	tank._path_epoch = battle.path_epoch()
	battle._place_building("GAPOWR", "ally", Vector2(1150,1000), true)
	check(not battle.remaining_route_unchanged(tank,battle.path_epoch()),mode+" intersecting foundation invalidates route")
	tank._path_epoch = battle.path_epoch()
	battle._refresh_pathing()
	check(not battle.remaining_route_unchanged(tank,battle.path_epoch()),mode+" complete rebuild invalidates route")
	tank.set_agent_path(PackedVector2Array([tank.position, tank.position + Vector2(1100, 1100)]))
	battle._place_building("GAPOWR", "ally", tank.position+Vector2(850,200), true)
	check(battle.remaining_route_unchanged(tank,battle.path_epoch()),mode+" diagonal path passes beside a changed site")
	var order := {"kind":"attack","target":foe}
	battle.ai_dispatch._apply(battle,tank,order)
	var first: int = battle.path_service.stats_paths
	battle.ai_dispatch._apply(battle,tank,order)
	check(tank.attack_ordered and tank.attack_target==foe and battle.path_service.stats_paths==first,mode+" repeated attack preserves target and path")
	var ore = preload("res://scripts/world/resource_node.gd").new()
	battle.add_child(ore)
	var revision: int = battle.radar_ore_revision
	ore.extract(1)
	check(battle.radar_ore_revision==revision,mode+" mining above zero retains radar markers")
	ore.extract(ore.amount)
	check(battle.radar_ore_revision>revision,mode+" depletion dirties radar")
	revision=battle.radar_ore_revision
	ore.amount=20
	check(battle.radar_ore_revision>revision,mode+" regrowth dirties radar")
	var nav := PathService.new()
	nav.configure(5600)
	var block = preload("res://scripts/world/obstacle.gd").new()
	block.position = Vector2(2600,2600)
	block.radius = 200
	battle.add_child(block)
	nav.add_blocker(block)
	var start_point := Vector2(100,100)
	var goal := Vector2(5100,5100)
	var route := nav.find_path(start_point,goal,false,6000,false,[],false,true)
	check(nav.stats_map_paths==1 and route.size()>2 and route[-1]==goal,mode+" connected long route uses native map search")
	var second = preload("res://scripts/world/obstacle.gd").new()
	second.position=(route[0]+route[1])*0.5
	second.radius=100
	battle.add_child(second)
	nav.add_blocker(second)
	route=nav.find_path(start_point,goal,false,6000,false,[],false,true)
	var clear_path := route.size()>2 and route[-1]==goal
	for i in range(1,route.size()):
		clear_path=clear_path and nav.line_walkable(route[i-1],route[i],nav.cost)
	check(clear_path and nav.stats_map_paths==2,mode+" cached native map respects a new blocker")
	block.free()
	second.free()
	nav.free()
	var base := Image.create(8,2,false,Image.FORMAT_RGBA8)
	var top := Image.create(8,2,false,Image.FORMAT_RGBA8)
	var rows := [{"x":0,"y":0,"w":4,"h":2},{"x":4,"y":0,"w":4,"h":2}]
	for y in 2:
		for x in 8:
			base.set_pixel(x,y,Color(0.2,0.3,0.4,float((x*31+y*17)%256)/255.0))
			top.set_pixel(x,y,Color(0,0,0,float((x*5+y)%3)*0.5))
	var hull := {"img":base,"kind":"shp","rects":rows}
	var turret := {"img":top,"kind":"shp","rects":rows}
	for h in 2:
		for t in 2:
			var merged := RA2Art._shadow_union(hull,turret,h,t)
			var expected := base.get_region(Rect2i(h*4,0,4,2))
			for x in 4:
				for y in 2:
					var col := expected.get_pixel(x,y)
					col.a=maxf(col.a,top.get_pixel(t*4+x,y).a)
					expected.set_pixel(x,y,col)
			check(merged.get_data()==expected.get_data(),mode+" alpha union for independent hull and turret "+str([h,t]))
	await finish()
