extends "res://tests/ground_control_regression.gd"

func exercise(mode: String) -> void:
	start(mode)
	for b in battle.buildings: b.free()
	battle.buildings.clear()
	battle._refresh_pathing()
	for id in ["MTNK", "E1"]:
		var start_point := Vector2(780, 1000)
		var goal := Vector2(1480, 1000)
		var mover = battle.spawn_unit(id, "ally", start_point)
		activate(mover)
		mover.hull_angle = 0
		mover.order_move(goal)
		var guards: Array = []
		for i in range(-3, 4):
			var guard = battle.spawn_unit("HTNK", "ally", Vector2(1100, 1000 + i*31))
			activate(guard)
			guard.order_guard()
			guards.append(guard)
		var moved_around := false
		for tick in 1500:
			await get_tree().physics_frame
			mover._physics_process(1.0/60)
			if absf(mover.position.y-1000)>93: moved_around = true
			if not mover.has_move_order: break
		check(moved_around and mover.position.distance_to(goal)<20 and not mover.has_move_order, prefix+id+" routes around seven guards on original order", mover.position)
		check(guards.all(func(g): return g.hold_position and is_equal_approx(g.position.x,1100)), prefix+id+" leaves guards in position")
		for u in guards + [mover]:
			battle.units.erase(u)
			u.free()
	# A shore-bounded lane has no detour until the blocking units leave.
	battle.water_rects.assign([Rect2(0,0,battle.map_size,920),Rect2(0,1080,battle.map_size,battle.map_size-1080)])
	battle.path_service.set_water(battle.water_rects)
	battle._refresh_pathing()
	var soldier = battle.spawn_unit("E1","ally",Vector2(820,1000))
	activate(soldier)
	var goal := Vector2(1400,1000)
	battle.selected_units.assign([soldier])
	battle._command_move(goal)
	var wall: Array = []
	for i in range(-3,4):
		var guard = battle.spawn_unit("HTNK","ally",Vector2(1100,1000+i*31))
		activate(guard)
		guard.order_guard()
		wall.append(guard)
	for tick in 600:
		await get_tree().physics_frame
		soldier._physics_process(1.0/60)
	check(soldier.has_move_order and soldier.position.x<1100 and soldier.move_target.distance_to(goal)<12, prefix+"closed lane retains movement order", soldier.position)
	for guard in wall:
		battle.units.erase(guard)
		guard.free()
	for tick in 900:
		await get_tree().physics_frame
		soldier._physics_process(1.0/60)
		if not soldier.has_move_order: break
	check(not soldier.has_move_order and soldier.position.distance_to(goal)<20,prefix+"opening lane resumes without another click",soldier.position)
	soldier.position = Vector2(820,1000)
	soldier.order_move(goal)
	var gate = battle._place_building("GAWEAP","ally",Vector2(1100,1000),true)
	gate.process_mode = Node.PROCESS_MODE_ALWAYS
	gate.set_process(false)
	gate.set_physics_process(false)
	battle._refresh_pathing()
	for tick in 720:
		await get_tree().physics_frame
		soldier._physics_process(1.0/60)
	check(soldier.position.x<1100 and soldier.has_move_order and soldier.move_target.distance_to(goal)<12, prefix+"new foundation cutting off lane retains original destination", [soldier.position, soldier.move_target])
	# A fresh order takes precedence, including an explicit stop while waiting.
	var cancelled = battle.spawn_unit("E1", "ally", Vector2(840, 980))
	activate(cancelled)
	cancelled.order_move(goal)
	for tick in 240:
		await get_tree().physics_frame
		cancelled._physics_process(1.0/60)
	cancelled.order_stop()
	var stopped_at: Vector2 = cancelled.position
	battle.buildings.erase(gate)
	gate.free()
	battle._refresh_pathing()
	for tick in 1200:
		await get_tree().physics_frame
		soldier._physics_process(1.0/60)
		cancelled._physics_process(1.0/60)
		if not soldier.has_move_order: break
	check(not cancelled.has_move_order and cancelled.position.distance_to(stopped_at)<1, prefix+"stop cancels retry after lane opens")
	check(not soldier.has_move_order and soldier.position.distance_to(goal)<20,prefix+"removing foundation resumes original order",soldier.position)
	await finish()
