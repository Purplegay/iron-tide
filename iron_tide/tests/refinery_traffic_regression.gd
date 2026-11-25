extends "res://tests/ground_control_regression.gd"

func step(actors: Array, count: int) -> void:
	for i in count:
		await get_tree().physics_frame
		for actor in actors: actor._physics_process(1.0 / 60.0)

func exercise(mode: String) -> void:
	for side in ["ally", "enemy"]:
		start(mode)
		if battle.fog != null:
			battle.fog.free()
			battle.fog = null
		for b in battle.buildings: b.free()
		battle.buildings.clear()
		battle._refresh_pathing()
		prefix = mode + " " + side + ": "
		var refinery = battle._place_building("GAREFN", side, Vector2(900, 900), true)
		refinery._buildup_play = -1.0
		if side == "ally": await check_manual_return(refinery)
		var actors: Array = []
		var expected := 0.0
		var money: float = battle.funds if side == "ally" else battle.enemy_funds
		for i in 4:
			var miner = battle.spawn_unit("CMIN", side, Vector2(1500 + i * 130, 1500))
			activate(miner)
			miner.home_base = refinery
			miner.cargo = miner.cargo_cap
			miner.cargo_gems = miner.cargo * 0.25
			expected += miner.cargo_value()
			miner.harvest_state = "to_base"
			miner._lock_dock()
			actors.append(miner)
		check(refinery.refinery_traffic.waiting.size() == 4, prefix + "four loaded miners reserve one FIFO")
		refinery.refinery_traffic.waiting.push_front(null) # An expired reference from an older save.
		check(not actors[0]._dock_occupied() and actors[1]._dock_occupied(), prefix + "only queue head may enter")
		check("前方 2 辆" in preload("res://scripts/world/economy_cycle.gd").miner_status(actors[2]), prefix + "selection status explains unloading queue")
		var entered: Array = []
		var max_unloading := 0
		var overlap := false
		var elapsed := 0
		var reverse_ticks := [0, 0, 0, 0]
		var unload_ticks := [0, 0, 0, 0]
		var exit_ticks := [0, 0, 0, 0]
		var backwards_only := true
		for tick in 4800:
			for i in actors.size():
				if actors[i].harvest_state == "to_base" and actors[i]._back_in: reverse_ticks[i] += 1
				if actors[i].harvest_state == "unloading": unload_ticks[i] += 1
				if actors[i]._harvest_exit != Vector2.INF: exit_ticks[i] += 1
			await step(actors, 1)
			var unloading := 0
			for i in actors.size():
				if actors[i]._back_in and actors[i].velocity.length() > 1.0:
					backwards_only = backwards_only and Vector2.from_angle(actors[i].hull_angle).dot(actors[i].velocity) < 0.0
				if actors[i].harvest_state == "unloading":
					unloading += 1
					if not entered.has(i): entered.append(i)
				for j in range(i + 1, actors.size()):
					if actors[i].position.distance_to(actors[j].position) < (actors[i].radius + actors[j].radius) * 0.95: overlap = true
			max_unloading = maxi(max_unloading, unloading)
			elapsed = tick + 1
			if actors.all(func(u): return u.cargo == 0.0 and u._harvest_exit == Vector2.INF): break
		var state: Array = []
		for miner in actors: state.append({"position": str(miner.position), "cargo": miner.cargo, "state": miner.harvest_state, "exit": str(miner._harvest_exit)})
		check(entered == [0, 1, 2, 3], prefix + "actual chrono entry and unloading follow FIFO", {"entered": entered, "state": state})
		check(max_unloading == 1 and not overlap, prefix + "one unloading vehicle with no physical overlap")
		check(actors.all(func(u): return u.cargo == 0.0 and u._harvest_exit == Vector2.INF), prefix + "all miners unload and leave entrance even without remaining ore", state)
		var paid: float = (battle.funds if side == "ally" else battle.enemy_funds) - money
		check(is_equal_approx(paid, expected), prefix + "mixed cargo credits exactly once to owning side", {"actual": paid, "expected": expected})
		check(unload_ticks.all(func(t): return t >= 59 and t <= 61), prefix + "all four real trucks transfer after one second", unload_ticks)
		check(backwards_only and reverse_ticks.all(func(t): return t > 0 and t <= 120), prefix + "short reverse approach stays rearward and below two seconds", reverse_ticks)
		metrics.append({"mode": mode, "side": side, "four_miner_seconds": elapsed / 60.0,
			"reverse_seconds": reverse_ticks.map(func(t): return t / 60.0),
			"unload_seconds": unload_ticks.map(func(t): return t / 60.0),
			"exit_seconds": exit_ticks.map(func(t): return t / 60.0)})
		# A saved partial exit route ends near the truck, far short of its request.
		var stranded = actors[0]
		stranded.position = refinery.refinery_dock_point(stranded.radius)
		stranded.home_base = refinery
		stranded._harvest_exit = Vector2(-120,-120)
		stranded._exit_check_left = 0
		stranded.set_agent_path(PackedVector2Array([stranded.position, stranded.position+Vector2.ONE]))
		stranded._process_harvester(1.0/60.0)
		check(stranded._harvest_exit.is_finite() and stranded._harvest_exit != Vector2(-120,-120) and stranded._path_pts.size() >= 2 and stranded._path_pts[-1].is_equal_approx(stranded._harvest_exit),prefix+"saved partial exit replaced by a complete navigable route", [stranded.position,stranded._harvest_exit,stranded._path_pts,stranded.has_move_order])
		stranded._harvest_exit = Vector2.INF
		stranded._clear_field()
		# Queue entries are discarded on explicit orders, death and refinery loss.
		for i in actors.size():
			actors[i].position = Vector2(1500 + i * 130, 1500)
			actors[i].cargo = actors[i].cargo_cap
			actors[i].harvest_state = "to_base"
			actors[i]._lock_dock()
		actors[0].order_move(Vector2(1900, 1900))
		check(not actors[1]._dock_occupied(), prefix + "manual move releases head reservation")
		actors[1]._die()
		check(not actors[2]._dock_occupied(), prefix + "dead head cannot hold the entrance")
		refinery._dead = true
		refinery.hp = 0
		await step([actors[2], actors[3]], 1)
		check(actors[2].home_base == null and not actors[2]._dock_locked and actors[2].cargo > 0, prefix + "destroyed refinery releases reservation and retains cargo")
		await finish()
	# Automatic miners can request a bounded sidestep from an idle friend.
	start(mode)
	for b in battle.buildings: b.free()
	battle.buildings.clear()
	battle._refresh_pathing()
	var miner = battle.spawn_unit("CMIN", "ally", Vector2(500, 600))
	var friend = battle.spawn_unit("MTNK", "ally", Vector2(565, 600))
	activate(miner)
	activate(friend)
	await get_tree().physics_frame
	miner.move_target = Vector2(900, 600)
	miner.velocity = Vector2(100, 0)
	miner.harvest_state = "to_node"
	miner.apply_separation(1.0 / 60.0)
	check(friend._local_traffic.yield_target != Vector2.INF and not friend.has_move_order, mode + " automatic mining traffic requests bounded idle yield")
	friend._local_traffic.reset()
	friend.position = miner.position + Vector2(14.0, miner.radius + friend.radius + 2.0)
	await get_tree().physics_frame
	miner._local_traffic.reset()
	miner.velocity = Vector2(100,0)
	miner.apply_separation(1.0 / 60.0)
	check(miner.velocity.x > 95.0 and friend._local_traffic.yield_target == Vector2.INF, mode+" miner drives past an idle friend beside its clear approach")
	friend.position = Vector2(565,600)
	await get_tree().physics_frame
	friend.order_guard()
	miner._local_traffic.reset()
	miner.apply_separation(1.0 / 60.0)
	check(friend._local_traffic.yield_target == Vector2.INF and friend.hold_position, mode + " mining priority preserves explicit guard")
	await finish()

func check_manual_return(nearby) -> void:
	var chosen = battle._place_building("NAREFN", "ally", Vector2(1350, 900), true)
	chosen._buildup_play = -1.0
	var chrono = battle.spawn_unit("CMIN", "ally", nearby.position + Vector2(0, 140))
	var war = battle.spawn_unit("HARV", "ally", nearby.position + Vector2(45, 140))
	var group := [chrono, war]
	for miner in group:
		activate(miner)
		miner.order_guard()
		miner.home_base = nearby
		miner.cargo = 2
		battle.select_unit(miner, true)
	var point: Vector2 = chosen.art_center()
	check(chosen.hit_test(point), prefix + "refinery accepts context click fixture")
	check(battle.command_cursor.resolve(point) == "enter", prefix + "selected miners get return cursor")
	battle._issue_order(point)
	check(group.all(func(m): return m.home_base == chosen and m.harvest_state == "to_base" and m._dock_locked and not m.hold_position and not m.has_move_order), prefix + "both partially loaded miner types reserve clicked refinery instead of nearest")
	check(chosen.refinery_traffic.index_of(chosen, chrono) == 0 and chosen.refinery_traffic.index_of(chosen, war) == 1, prefix + "manual return uses FIFO")
	battle._issue_order(point)
	check(chosen.refinery_traffic.waiting.size() == 2 and chosen.refinery_traffic.index_of(chosen, chrono) == 0, prefix + "repeat click preserves queue order")
	chrono.harvest_state = "unloading"
	chrono._unload_timer = 0.4
	battle._issue_order(point)
	check(chrono.harvest_state == "unloading" and is_equal_approx(chrono._unload_timer, 0.4), prefix + "repeat click preserves unloading timer")
	var funds: float = battle.funds
	var value: float = chrono.cargo_value()
	chrono._process_harvester(0.4)
	check(chrono.cargo == 0 and is_equal_approx(battle.funds - funds, value), prefix + "partial load pays once at chosen refinery")
	war.order_stop()
	war.cargo = 0
	battle.select_unit(war, false)
	chosen.under_construction = true
	check(battle.command_cursor.resolve(point) == "enter_blocked", prefix + "unfinished refinery rejects return")
	battle._issue_order(point)
	check(not war._dock_locked, prefix + "blocked order cannot reserve unfinished dock")
	chosen.under_construction = false
	battle.arm_command("harvest")
	battle._issue_command_at(point)
	check(war.harvest_state == "to_base" and war.home_base == chosen, prefix + "empty Soviet miner can return via harvest targeting")
	battle.clear_selection()
	for miner in group:
		miner.order_stop()
		battle.units.erase(miner)
		miner.free()
	battle.buildings.erase(chosen)
	chosen.free()
