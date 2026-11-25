extends "res://tests/ground_control_regression.gd"

func exercise(mode: String) -> void:
	start(mode)
	for b in battle.buildings: b.free()
	battle.buildings.clear()
	var upper = battle._place_building("GAPOWR", "ally", Vector2(1200, 900), true)
	var lower = battle._place_building("GAPOWR", "ally", Vector2(1200, 1100), true)
	for b in [upper, lower]:
		b.process_mode = Node.PROCESS_MODE_ALWAYS
		b.set_process(false)
		b.set_physics_process(false)
	var body: Rect2 = upper.footprint_rect()
	var axis := 1000.0
	for width: float in [26.0, 38.0, 52.0, 92.0]:
		upper.position.y = axis - width/2 - body.end.y
		lower.position.y = axis + width/2 - body.position.y
		battle._refresh_pathing()
		var tank = battle.spawn_unit("MTNK","ally",Vector2(900,axis))
		activate(tank)
		tank.hull_angle = 0
		var goal := Vector2(1500,axis)
		var pts: PackedVector2Array = battle.path_for_unit(tank,goal)
		check((pts.size()==2 and pts[-1]==goal)==(width>tank.radius*2),prefix+"straight passage at "+str(width),str(pts))
		battle.units.erase(tank)
		tank.free()
	# A short column starts off-axis and enters the same real gap on a group move.
	upper.position.y = axis - 25 - body.end.y
	lower.position.y = axis + 25 - body.position.y
	battle._refresh_pathing()
	var actors: Array = []
	for i in 3:
		var tank = battle.spawn_unit("MTNK" if i!=1 else "HTNK","ally",Vector2(919-i*60,axis+29))
		activate(tank)
		tank.hull_angle=0
		actors.append(tank)
	battle.selected_units.assign(actors)
	battle._command_move(Vector2(1530,axis+20))
	battle._refresh_pathing()
	await get_tree().physics_frame
	for i in PathService.ROUTE_REFRESHES_PER_TICK: battle.path_service.take_route_refresh()
	check(not battle.path_service.take_route_refresh(), prefix+"computer route budget is exhausted")
	var refreshed := 0
	for tank in actors:
		tank._steer_dir(tank.move_target)
		if tank._path_epoch == battle.path_epoch(): refreshed += 1
	check(refreshed == actors.size(), prefix+"entire player column refreshes even with computer budget exhausted")

	var through := {}
	var clipped := false
	for tick in 1500:
		await get_tree().physics_frame
		for tank in actors:
			tank._physics_process(1.0/60)
			if absf(tank.position.x - (upper.position.x+body.get_center().x)) < 12 and absf(tank.position.y-axis)<25:
				through[tank.get_instance_id()]=true
			for b in [upper,lower]:
				if Placement.circle_hits_poly(b.footprint_poly(),tank.position,tank.radius-0.6,b.position):clipped=true
		if actors.all(func(u):return not u.has_move_order): break
	check(through.size()==3,prefix+"three ordered vehicles take the opening",through.size())
	check(actors.all(func(u):return u.position.x>1400 and not u.has_move_order),prefix+"column arrives")
	check(not clipped,prefix+"bodies stay outside both foundations")
	# Two vehicles fit abreast here, but a full-width fixed sidestep would hit the building.
	upper.position.y = axis-46-body.end.y
	lower.position.y = axis+46-body.position.y
	battle._refresh_pathing()
	for u in actors:
		battle.units.erase(u)
		u.free()
	var moving = battle.spawn_unit("MTNK","ally",Vector2(upper.position.x-75,axis-10))
	var parked = battle.spawn_unit("HTNK","ally",Vector2(upper.position.x,axis+5))
	for u in [moving,parked]: activate(u)
	await get_tree().physics_frame
	check(parked._local_traffic.yield_target==Vector2.INF and moving._local_traffic.request_yield(moving,parked,Vector2.RIGHT),prefix+"parked tank can yield inside opening")
	check(parked._local_traffic.yield_target.is_finite() and not Placement.circle_hits_poly(lower.footprint_poly(),parked._local_traffic.yield_target,parked.radius-0.1,lower.position),prefix+"sidestep fits available space")
	for u in [moving, parked]:
		battle.units.erase(u)
		u.free()
	await infantry_passage(upper, lower, body, axis)
	await finish()

func infantry_passage(upper, lower, body: Rect2, axis: float) -> void:
	var infantry: Array = []
	for i in 2:
		var u = battle.spawn_unit("E1" if i == 0 else "GGI", "ally", Vector2(970 - 55*i, axis))
		activate(u)
		infantry.append(u)
	for width in [12.0, 28.0]:
		upper.position.y = axis - width / 2 - body.end.y
		lower.position.y = axis + width / 2 - body.position.y
		battle._refresh_pathing()
		for u in infantry:
			var goal := Vector2(1450, axis)
			var route: PackedVector2Array = battle.path_for_unit(u, goal)
			check((route.size() == 2 and route[-1] == goal) == (width > 2*(u.radius+1)), prefix + u.unit_id + " doorway " + str(width), str(route))
	for i in infantry.size():
		infantry[i].order_move(Vector2(1480-60*i, axis))
	var crossed := {}
	var clipped := false
	for tick in 1200:
		await get_tree().physics_frame
		for u in infantry:
			u._physics_process(1.0/60)
			if absf(u.position.x - (upper.position.x + body.get_center().x)) < 10 and absf(u.position.y-axis) < 14:
				crossed[u.get_instance_id()] = true
			for b in [upper,lower]:
				if Placement.circle_hits_poly(b.footprint_poly(),u.position,u.radius-0.6,b.position): clipped = true
		if infantry.all(func(u): return not u.has_move_order): break
	check(crossed.size() == 2 and infantry.all(func(u): return u.position.x > 1390 and not u.has_move_order), prefix + "single-file infantry pass the real doorway", crossed.size())
	check(not clipped, prefix + "infantry stay outside both foundations")
	# Opposing orders through an opening wide enough to pass shoulder to shoulder.
	upper.position.y = axis-26-body.end.y
	lower.position.y = axis+26-body.position.y
	battle._refresh_pathing()
	for i in 2:
		infantry[i].position = Vector2(1030 if i == 0 else 1370,axis)
		infantry[i].order_move(Vector2(1440 if i == 0 else 960,axis))
	crossed.clear()
	for tick in 1000:
		await get_tree().physics_frame
		for u in infantry:
			u._physics_process(1.0/60)
			if absf(u.position.x-(upper.position.x+body.get_center().x))<10 and absf(u.position.y-axis)<26: crossed[u.get_instance_id()] = true
		if infantry.all(func(u): return not u.has_move_order): break
	check(crossed.size() == 2 and infantry[0].position.x>1410 and infantry[1].position.x<990, prefix+"two opposing infantry orders both arrive", [infantry[0].position,infantry[1].position])
	for u in infantry: activate(u)
	var mover = infantry[0]
	var parked = infantry[1]
	mover.position = Vector2(upper.position.x-50, axis-8)
	parked.position = Vector2(upper.position.x, axis+5)
	await get_tree().physics_frame
	check(parked._local_traffic.request_yield(mover, parked, Vector2.RIGHT), prefix + "idle infantry can step aside within the door")
	check(parked._local_traffic.yield_target.is_finite() and not Placement.circle_hits_poly(lower.footprint_poly(),parked._local_traffic.yield_target,parked.radius,lower.position), prefix + "infantry sidestep clears the foundation")
