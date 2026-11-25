extends "res://tests/ground_control_regression.gd"

func exercise(mode: String) -> void:
	for angle in [0.0, PI / 4.0, PI / 2.0, PI]:
		start(mode)
		for b in battle.buildings: b.free()
		battle.buildings.clear()
		battle._refresh_pathing()
		var center := Vector2(1200,1200)
		var forward := Vector2.RIGHT.rotated(angle)
		var lateral := forward.orthogonal()
		var origin := center - forward * 300.0
		var goal := center + forward * 300.0
		var mover = battle.spawn_unit("E1", "ally", origin)
		activate(mover)
		var guards: Array = []
		var clearance: float = 0.0
		for sign_value in [-1.0, 1.0]:
			var guard = battle.spawn_unit("GGI", "ally", center)
			activate(guard)
			clearance = mover.radius + guard.radius + 8.0
			guard.position = center + lateral * (clearance + 5.0) * sign_value
			guard.set_deployed(true)
			guards.append(guard)
		await get_tree().physics_frame
		var path: PackedVector2Array = battle.path_for_unit(mover,goal)
		var length := 0.0
		for i in range(1,path.size()): length += path[i-1].distance_to(path[i])
		check(path.size() == 2 and is_equal_approx(length,600.0), mode + str(angle) + ": physical open gap uses direct route", str(path))
		var original_cost = battle.path_service.cost.duplicate()
		mover.order_move(goal)
		var lateral_peak := 0.0
		for tick in 1200:
			await get_tree().physics_frame
			mover._physics_process(1.0/60.0)
			lateral_peak = maxf(lateral_peak,absf((mover.position-origin).dot(lateral)))
			if not mover.has_move_order: break
		check(not mover.has_move_order and mover.position.distance_to(goal) <= 12.0, mode + str(angle) + ": finishes movement through gap", str(mover.position))
		check(lateral_peak <= 8.0, mode + str(angle) + ": does not loop around deployed friends", lateral_peak)
		check(battle.path_service.cost == original_cost, mode + ": shared terrain unchanged")
		for guard in guards:
			check(guard._deployed and guard.hp == guard.max_hp and absf((guard.position-center).dot(lateral)) > clearance, mode + ": no displaced or crushed guard")
		# A real blocker still forces a collision-free route.
		guards[0].position = center
		await get_tree().physics_frame
		mover.position = origin
		path = battle.path_for_unit(mover,goal)
		var safe := path.size() > 2
		for i in range(1,path.size()):
			for guard in guards:
				var closest := Geometry2D.get_closest_point_to_segment(guard.position,path[i-1],path[i])
				if closest.distance_to(guard.position) < mover.radius + guard.radius: safe = false
		check(safe, mode + str(angle) + ": obstructed gap still detours safely", str(path))
		metrics.append({"mode":mode,"angle":angle,"open_path_length":length,"lateral_peak":lateral_peak})
		await finish()
