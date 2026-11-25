extends "res://tests/ground_control_regression.gd"

func step(actors: Array, count: int) -> void:
	for i in count:
		await get_tree().physics_frame
		for actor in actors: actor._physics_process(1.0 / 60.0)

func exercise(mode: String) -> void:
	start(mode)
	for b in battle.buildings: b.free()
	battle.buildings.clear()
	battle._refresh_pathing()
	# Far actors must not exhaust a fixed scan budget before the local blocker.
	var mover = battle.spawn_unit("MTNK", "ally", Vector2(400,600))
	activate(mover)
	for i in 45:
		var far = battle.spawn_unit("E1", "ally", Vector2(100 + i * 30,2000))
		activate(far)
	var blocker = battle.spawn_unit("MTNK", "ally", Vector2(400 + mover.radius * 2,600))
	activate(blocker)
	await get_tree().physics_frame
	mover.velocity = Vector2.ZERO
	mover.apply_separation(1.0/60.0)
	check(mover.velocity.x < 0, prefix + "nearby blocker remains visible after forty distant allies")
	for u in battle.units: u.free()
	battle.units.clear()
	# Idle friend can sidestep; guard remains immovable.
	mover = battle.spawn_unit("MTNK", "ally", Vector2(400,600))
	blocker = battle.spawn_unit("MTNK", "ally", Vector2(750,600))
	activate(mover)
	activate(blocker)
	mover.order_move(Vector2(1100,600))
	await get_tree().physics_frame
	await step([mover,blocker],1800)
	check(not mover.has_move_order, prefix + "moving tank routes around stationary friendly within thirty seconds", str(mover.position))
	check(blocker.position.distance_to(Vector2(750,600)) <= 65.0 and not blocker.has_move_order, prefix + "idle friend yields only a bounded distance without replacing its orders")
	blocker.order_guard()
	var guard_pos: Vector2 = blocker.position
	mover.position = guard_pos - Vector2(80,0)
	mover.order_move(guard_pos + Vector2(200,0))
	await step([mover,blocker],180)
	check(blocker.position.is_equal_approx(guard_pos), prefix + "guard order never yields to traffic")
	for u in battle.units: u.free()
	battle.units.clear()
	# Two groups cross a bounded throat in opposite directions.
	var rocks: Array = []
	for y in range(80,2320,80):
		if y >= 1080 and y <= 1240: continue
		var rock = preload("res://scripts/world/obstacle.gd").new()
		rock.position = Vector2(1200,y)
		rock.radius = 50
		rock.process_mode = Node.PROCESS_MODE_ALWAYS
		battle.add_child(rock)
		rocks.append(rock)
	battle._refresh_pathing()
	var actors: Array = []
	for i in 12:
		var rightward := i < 6
		var u = battle.spawn_unit("MTNK" if i % 2 == 0 else "E1", "ally", Vector2(500 if rightward else 1800,1040 + (i % 6) * 50))
		activate(u)
		u.hull_angle = 0.0 if rightward else PI
		u.order_move(Vector2(1850 if rightward else 450,1000 + (i % 6) * 60))
		actors.append(u)
	await get_tree().physics_frame
	var arrived := 0
	var elapsed := 0
	for tick in 5400:
		await get_tree().physics_frame
		arrived = 0
		for u in actors:
			u._physics_process(1.0/60.0)
			if not u.has_move_order: arrived += 1
		elapsed = tick + 1
		if arrived == actors.size(): break
		if tick % 60 == 0: await get_tree().process_frame
	check(arrived == actors.size(), prefix + "opposing mixed squads cross throat within ninety seconds", {"arrived":arrived,"seconds":elapsed/60.0})
	metrics.append({"scenario":"opposing_throat","mode":mode,"arrived":arrived,"seconds":elapsed/60.0})
	for u in actors:
		check(absf(u.position.x - 1200) > 100, prefix + "no unit remains stuck in throat",str(u.position))
	for u in battle.units: u.free()
	battle.units.clear()
	for rock in rocks: rock.free()
	battle._refresh_pathing()
	# Fixed workload: report simulation update p95/p99, not rendered FPS.
	for count in [50,100,200]:
		actors.clear()
		for i in count:
			var u = battle.spawn_unit("MTNK" if i % 3 == 0 else "E1", "ally",Vector2(200+(i%10)*60,200+(i/10)*65))
			activate(u)
			actors.append(u)
		battle.selected_units = actors.duplicate()
		battle._command_move(Vector2(1600,1300))
		var goals: Array = []
		for u in actors: goals.append(u.move_target)
		await get_tree().physics_frame
		var times: Array = []
		for tick in 6000:
			await get_tree().physics_frame
			var started := Time.get_ticks_usec()
			arrived = 0
			for u in actors:
				u._physics_process(1.0/60.0)
				if not u.has_move_order: arrived += 1
			times.append((Time.get_ticks_usec()-started)/1000.0)
			elapsed = tick + 1
			if arrived == count: break
			if tick % 60 == 0: await get_tree().process_frame
		times.sort()
		metrics.append({"scenario":"mixed_open","mode":mode,"count":count,"arrived":arrived,"seconds":elapsed/60.0,"update_p95_ms":times[int(times.size()*0.95)],"update_p99_ms":times[int(times.size()*0.99)]})
		print("TRAFFIC ", metrics.back())
		if arrived != count:
			for u in actors:
				if u.has_move_order: print("STRANDED ", u.unit_id, " ", u.position, " goal=",u.move_target," angle=",u.hull_angle," speed=",u.velocity)
		check(arrived == count, prefix + "mixed formation arrives: " + str(count),arrived)
		await step(actors,180)
		var overlaps := 0
		var max_error := 0.0
		for i in actors.size():
			max_error = maxf(max_error, actors[i].position.distance_to(goals[i]))
			for j in range(i+1,actors.size()):
				if actors[i].position.distance_to(actors[j].position) < (actors[i].radius+actors[j].radius)*0.95:
					overlaps += 1
					print("OVERLAP ",i, " ",j," ", actors[i].unit_id," ",actors[j].unit_id, " ",actors[i].position," ",actors[j].position," radii=",actors[i].radius,"/",actors[j].radius)
		metrics.back()["overlaps"] = overlaps
		metrics.back()["max_slot_offset"] = max_error
		check(overlaps == 0, prefix + "settled mixed formation has no body overlap: " + str(count), overlaps)
		check(max_error <= 114.0, prefix + "yielding and occupied-slot fallback stay near ordered formation: " + str(count),max_error)
		battle.clear_selection()
		for u in battle.units: u.free()
		battle.units.clear()
	await finish()
