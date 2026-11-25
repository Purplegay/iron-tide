extends "res://tests/logistics_regression.gd"
const Access = preload("res://scripts/buildings/repair_access.gd")

func exercise_mode(mode: String) -> void:
	setup_logistics_scene(mode,"美国")
	for group in ["obstacles","resource_nodes"]:
		for node in get_tree().get_nodes_in_group(group): node.free()
	for u in battle.units: u.free()
	battle.units.clear()
	for b in battle.buildings: b.free()
	battle.buildings.clear()
	battle.water_rects=[]
	battle.path_service.set_water([])
	var depot=battle._place_building("GADEPT","ally",Vector2(1600,1600),true)
	depot._buildup_play=-1.0
	activate(depot,false)
	var block=battle._place_building("GAREFN","ally",Vector2(1680,1680),true)
	block._buildup_play=-1.0
	activate(block,false)
	battle._refresh_pathing()
	var tank=battle.spawn_unit("MTNK","ally",Vector2(2000,1900))
	activate(tank)
	tank.hp=tank.max_hp-16
	await get_tree().physics_frame
	var old=depot.dock_point(tank.position)
	check(not Access.clear(tank,depot,old,RepairDock.pad(depot)),mode+": original nearest entrance blocked by adjacent refinery")
	var entry=Access.nearest(tank,depot)
	check(entry.is_finite() and Access.clear(tank,depot,entry,RepairDock.pad(depot)),mode+": finds a physically clear alternate entrance")
	check(tank.collision_mask==7 and not tank.get_collision_exceptions().has(depot),mode+": corridor probe restores collision state")
	var original_position: Vector2=tank.position
	tank.position=Vector2(1695,1758)
	var near_entry=Access.nearest(tank,depot)
	var route=Access.local_route(tank,depot,near_entry)
	check(not route.is_empty(),mode+": blocked close approach finds a corner route")
	var point_from: Vector2=tank.position
	for corner in route:
		check(Access.clear(tank,depot,point_from,corner),mode+": every corner segment clears the actual vehicle shape")
		point_from=corner
	tank.position=original_position
	check(tank.order_repair(depot),mode+": alternate approach accepted")
	# Loaded inside state with the old obstructed door must not monopolize the pad.
	tank.remove_meta("repair_access_epoch")
	tank.special.repair_stage="inside"
	tank.special.repair_entry=old
	RepairDock.tick(tank,1.0/60.0)
	check(tank.special.get("repair_stage")=="approach",mode+": old blocked inside state returns to approach")
	# A non-progressing reservation must yield to the rest of the queue.
	tank.set_meta("repair_progress",{"point":tank.position,"left":0.001})
	RepairDock.tick(tank,0.1)
	check(not tank.repairing,mode+": stalled leader releases facility")
	check(not tank.order_repair(depot),mode+": stalled leader has bounded retry backoff")
	tank._anim+=16.0
	check(tank.order_repair(depot),mode+": retry is allowed after backoff")
	var slots=[]
	for i in 5:
		var waiting=battle.spawn_unit("MTNK","ally",Vector2(2100+i*70,1900))
		activate(waiting)
		waiting.hp=waiting.max_hp-16
		check(waiting.order_repair(depot),mode+": waiting order accepted")
		var point=Access.waiting(waiting,depot,entry,i+1)
		for prior in slots: check(point.distance_to(prior)>waiting.radius*2,mode+": queue slots do not overlap")
		slots.append(point)
	var queued=battle.units[-1]
	var rank=RepairDock.queue_rank(queued,depot)
	var parked=Access.waiting(queued,depot,queued.special.repair_entry,rank)
	queued.position=parked
	queued.move_target=parked
	queued._clear_field()
	var paths=battle.path_service.stats_paths
	for i in 300: RepairDock.tick(queued,1.0/60.0)
	check(battle.path_service.stats_paths==paths,mode+": parked repair queue does not retry A star")
	var original_clock: float=depot._anim_t
	depot.hide()
	depot._process(0.1)
	check(depot._anim_t>original_clock,mode+": hidden depot animation clock still advances")
	depot.show()
	depot._process(0.1)
	check(depot.is_visible_in_tree(),mode+": revealed depot resumes presentation")
	# Exact platform traversal and payment are covered by repair_depot_regression.
	var wall=StaticBody2D.new()
	wall.process_mode=Node.PROCESS_MODE_ALWAYS
	wall.collision_layer=2
	var shape=CollisionShape2D.new()
	var circle=CircleShape2D.new()
	circle.radius=500
	shape.shape=circle
	wall.add_child(shape)
	wall.position=depot.position
	battle.add_child(wall)
	await get_tree().physics_frame
	battle.path_service.epoch+=1
	check(Access.entries(tank,depot).is_empty(),mode+": surrounded depot rejects corridor")
	check(not tank.order_repair(depot),mode+": impossible repair does not create another path order")
	RepairDock.tick(tank,1.0/60.0)
	check(not tank.repairing,mode+": inaccessible old reservation released")
	wall.free()
	await get_tree().physics_frame
	battle.path_service.epoch+=1
	check(not Access.entries(tank,depot).is_empty(),mode+": removing blocker invalidates negative cache")
	screen.free()
	await get_tree().process_frame
