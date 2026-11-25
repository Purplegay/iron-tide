extends "res://tests/ground_control_regression.gd"
const EconomyCycle = preload("res://scripts/world/economy_cycle.gd")

func finish() -> void:
	screen.free()
	Ra2Sfx.stop_all(); Music.stop(); Music.player.stream = null
	await get_tree().process_frame
	OS.delay_msec(150)

func arena(mode: String) -> void:
	start(mode)
	if battle.fog != null:
		battle.fog.free()
		battle.fog = null
	for b in battle.buildings: b.free()
	battle.buildings.clear()
	battle._refresh_pathing()

func ore(at: Vector2):
	var node := ResourceNode.new()
	node.position = at
	battle.add_child(node)
	node.process_mode = Node.PROCESS_MODE_DISABLED
	return node

func exercise(mode: String) -> void:
	for id in ["CMIN", "MTNK", "BFRT"]:
		for offset in [0.0, 20.0]:
			arena(mode)
			var factory = battle._place_building("GAWEAP", "ally", Vector2(1200 + offset, 1200), true)
			factory.process_mode = Node.PROCESS_MODE_DISABLED
			var goal := Vector2(1500, 1350)
			var node = ore(goal)
			var unit = battle.spawn_unit(id, "ally", Vector2(900, 1050))
			activate(unit)
			if unit.is_harvester: unit.order_harvest(node)
			else: unit.order_move(goal)
			await get_tree().physics_frame
			var path: Array = Array(unit._path_for(goal))
			var elapsed := 0
			for tick in 2400:
				unit._physics_process(1.0 / 60.0)
				await get_tree().physics_frame
				elapsed = tick + 1
				if (unit.is_harvester and unit.cargo > 0) or (not unit.is_harvester and not unit.has_move_order): break
			var info := {"unit": id, "mode": mode, "offset": offset, "seconds": elapsed / 60.0,
				"position": str(unit.position), "goal": str(goal), "cargo": unit.cargo,
				"state": unit.harvest_state, "path": str(path), "blacklisted": unit._ore_block.size()}
			metrics.append(info)
			check(unit.cargo > 0 if unit.is_harvester else unit.position.distance_to(goal) < 15.0,
				mode + " " + id + " goes around factory and completes order offset=" + str(offset), info)
			await finish()
	await crowded_ore(mode)
	await building_clearance(mode)
	await ore_at_dock(mode)
	await blocked_home(mode)
	await enclosed_ore(mode)
	if mode == MatchRules.RA2 and not OS.get_environment("IRON_TIDE_MINING_SAVE").is_empty():
		await saved_mining()

func saved_mining() -> void:
	DirAccess.make_dir_recursive_absolute(BattleSaves.DIRECTORY)
	var input := OS.get_environment("IRON_TIDE_MINING_SAVE")
	check(DirAccess.copy_absolute(input, ProjectSettings.globalize_path(BattleSaves.slot_path("slot1"))) == OK, "copy supplied diagnostic save into isolated user directory")
	var loaded := BattleSaves.prepare_load("slot1")
	check(loaded.ok, "diagnostic save passes normal validation", loaded)
	if not loaded.ok: return
	screen = load("res://scenes/battle.tscn").instantiate()
	add_child(screen)
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	battle = screen.battle
	battle.paused = false
	get_tree().paused = false
	var miners: Array = battle.units.filter(func(u): return u.is_harvester and u.side == "ally")
	var delivered: Dictionary = {}
	for miner in miners:
		miner.process_mode = Node.PROCESS_MODE_ALWAYS
		miner.set_physics_process(false)
		miner.set_process(false)
	for tick in 7200:
		for miner in miners:
			var before: float = miner.cargo
			miner._physics_process(1.0 / 60.0)
			if miner.cargo < before: delivered[miner.get_instance_id()] = true
		await get_tree().physics_frame
		if tick % 600 == 0:
			for miner in miners:
				metrics.append({"saved_tick": tick, "miner": miner.get_instance_id(), "position": str(miner.position), "cargo": miner.cargo, "state": miner.harvest_state, "manual": miner.has_move_order,
					"exit": str(miner._harvest_exit), "path": str(miner._path_pts), "path_index": miner._path_i, "speed": miner.velocity.length(), "dock_phase": miner._dock_phase,
					"status": EconomyCycle.miner_status(miner), "home": str(miner.home_base.position) if is_instance_valid(miner.home_base) else "none",
					"ore": str(miner.resource_node.position) if is_instance_valid(miner.resource_node) else "none"})
	for miner in miners:
		check(delivered.has(miner.get_instance_id()), "saved miner completes a delivery within 120 simulated seconds", {"miner": miner.get_instance_id(), "state": miner.harvest_state})
	await finish()

func building_clearance(mode: String) -> void:
	for building_id in ["GAPOWR", "GAWEAP", "GAREFN", "GAAIRC"]:
		arena(mode)
		var center := Vector2(1200, 1200)
		var building = battle._place_building(building_id, "ally", center, true)
		building.process_mode = Node.PROCESS_MODE_DISABLED
		for id in ["CMIN", "MTNK", "BFRT"]:
			var unit = battle.spawn_unit(id, "ally", center + Vector2(350, 0))
			activate(unit)
			await get_tree().physics_frame
			var collisions: Array = []
			for direction in 16:
				var offset := Vector2.from_angle(TAU * direction / 16.0) * 350.0
				unit.position = center + offset
				var path: PackedVector2Array = unit._path_for(center - offset)
				for i in range(path.size() - 1):
					if unit.test_move(Transform2D(0.0, path[i]), path[i + 1] - path[i], null, 0.001):
						collisions.append({"direction": direction, "from": str(path[i]), "to": str(path[i + 1])})
			check(collisions.is_empty(), mode + " planned route clears actual " + id + " body around " + building_id, collisions)
			if id in ["CMIN", "MTNK"] and building_id in ["GAWEAP", "GAAIRC"]:
				for direction in 4:
					var offset := Vector2.from_angle(PI * direction / 4.0) * 350.0
					unit.order_stop()
					unit.position = center + offset
					unit.hull_angle = (-offset).angle()
					var goal: Vector2 = center - offset
					unit.order_move(goal)
					await get_tree().physics_frame
					for tick in 1800:
						unit._physics_process(1.0 / 60.0)
						await get_tree().physics_frame
						if not unit.has_move_order: break
					check(unit.position.distance_to(goal) < 15.0, mode + " real " + id + " follows building corners " + building_id + " angle=" + str(direction), {"position": str(unit.position), "goal": str(goal), "path": str(unit._path_pts)})
			battle.units.erase(unit)
			unit.free()
		await finish()

func ore_at_dock(mode: String) -> void:
	arena(mode)
	var refinery = battle._place_building("GAREFN", "ally", Vector2(900, 900), true)
	refinery.process_mode = Node.PROCESS_MODE_DISABLED
	refinery._buildup_play = -1.0
	check(refinery.is_operational(), mode + " completed refinery fixture is operational")
	var miner = battle.spawn_unit("CMIN", "ally", Vector2(1500, 1500))
	activate(miner)
	miner.home_base = refinery
	miner.cargo = miner.cargo_cap
	miner.harvest_state = "to_base"
	miner._lock_dock()
	var node = ore(miner._dock_stage())
	check(not EconomyCycle.landing_clear(battle, node.position, miner.radius, miner), mode + " growth and placement still reserve existing ore")
	check(EconomyCycle.miner_landing_clear(battle, node.position, miner.radius, miner), mode + " miner arrival accepts traversable ore")
	var money: float = battle.funds
	await get_tree().physics_frame
	for tick in 1800:
		miner._physics_process(1.0 / 60.0)
		await get_tree().physics_frame
		if miner.cargo == 0 and miner._harvest_exit == Vector2.INF: break
	check(miner.cargo == 0 and battle.funds > money, mode + " traversable ore at refinery entrance does not prevent delivery", {"state": miner.harvest_state, "status": EconomyCycle.miner_status(miner), "position": str(miner.position)})
	check(miner._harvest_exit == Vector2.INF, mode + " miner finishes leaving ore-covered unloading entrance")
	check(is_equal_approx(node.amount, node.max_amount), mode + " returning miner never destroys entrance ore")
	await finish()

func crowded_ore(mode: String) -> void:
	arena(mode)
	var nodes: Array = []
	for x in 3:
		for y in 3: nodes.append(ore(Vector2(1200 + x * 40, 1000 + y * 40)))
	var miners: Array = []
	for i in 3:
		var miner = battle.spawn_unit("CMIN", "ally", Vector2(1350, 1000 + i * 50))
		activate(miner)
		miner.order_harvest(nodes[3])
		miners.append(miner)
	await get_tree().physics_frame
	for tick in 2400:
		for miner in miners: miner._physics_process(1.0 / 60.0)
		await get_tree().physics_frame
		if miners.all(func(m): return m.cargo > 1.0): break
	for miner in miners:
		check(miner.cargo > 1.0, mode + " crowded miners all begin collecting", {"position": str(miner.position), "cargo": miner.cargo, "state": miner.harvest_state})
	await finish()

func blocked_home(mode: String) -> void:
	arena(mode)
	var first = battle._place_building("GAREFN", "ally", Vector2(900, 900), true)
	var second = battle._place_building("GAREFN", "ally", Vector2(1700, 900), true)
	for refinery in [first, second]:
		refinery._buildup_play = -1.0
		refinery.process_mode = Node.PROCESS_MODE_DISABLED
	var miner = battle.spawn_unit("CMIN", "ally", Vector2(1200, 1400))
	activate(miner)
	miner.home_base = first
	miner.cargo = miner.cargo_cap
	miner.harvest_state = "to_base"
	miner._lock_dock()
	var blocker = battle.spawn_unit("MTNK", "ally", miner._dock_stage())
	activate(blocker)
	var money: float = battle.funds
	for tick in 240:
		miner._physics_process(1.0 / 60.0)
		await get_tree().physics_frame
	check(miner.home_base == first and miner.cargo == miner.cargo_cap and battle.funds == money, mode + " temporary vehicle occupancy preserves home and cargo without remote credit")
	battle.units.erase(blocker)
	blocker.free()
	var wall = battle._place_building("GAWALL", "ally", miner._dock_stage(), true)
	wall._buildup_play = -1.0
	wall.process_mode = Node.PROCESS_MODE_DISABLED
	check(not Placement.polys_overlap(first.footprint_poly(), first.position, wall.footprint_poly(), wall.position), mode + " entrance blocker never overlaps refinery foundation")
	var second_stage: Vector2 = second.refinery_dock_point(miner.radius) + second.refinery_dock_direction() * miner.DOCK_STAGE_BACK
	var second_wall = battle._place_building("GAWALL", "ally", second_stage, true)
	second_wall.process_mode = Node.PROCESS_MODE_DISABLED
	for tick in 240:
		miner._physics_process(1.0 / 60.0)
		await get_tree().physics_frame
	check(miner.home_base == null and miner.cargo == miner.cargo_cap and battle.funds == money, mode + " all blocked refineries retain cargo and wait")
	battle.buildings.erase(second_wall)
	second_wall.free()
	battle._refresh_pathing()
	await get_tree().physics_frame
	for tick in 1800:
		miner._physics_process(1.0 / 60.0)
		await get_tree().physics_frame
		if miner.cargo == 0: break
	check(miner.cargo == 0 and battle.funds > money and miner.home_base == second, mode + " newly blocked unloading entrance reroutes to usable refinery", {"state": miner.harvest_state, "status": EconomyCycle.miner_status(miner)})
	check(first.refinery_traffic.waiting.is_empty(), mode + " reroute releases old unloading reservation")
	await finish()

func enclosed_ore(mode: String) -> void:
	arena(mode)
	for index in 7:
		for at in [Vector2(1000 + index * 40, 1000), Vector2(1000 + index * 40, 1240), Vector2(1000, 1000 + index * 40), Vector2(1240, 1000 + index * 40)]:
			var wall = battle._place_building("GAWALL", "ally", at, true)
			wall._buildup_play = -1.0
			wall.process_mode = Node.PROCESS_MODE_DISABLED
	var sealed = ore(Vector2(1120, 1120))
	var reachable = ore(Vector2(800, 1540))
	var miner = battle.spawn_unit("CMIN", "ally", Vector2(800, 1120))
	activate(miner)
	check(not battle.path_service.same_zone(miner.position, sealed.position), mode + " wall enclosure really disconnects closest ore")
	check(miner._ore_target() == reachable, mode + " automatic ore choice skips disconnected nearer field")
	miner._ore_block[reachable] = 20.0
	check(miner._ore_target() == reachable, mode + " blacklist fallback still rejects disconnected ore")
	miner._ore_block.clear()
	miner.order_harvest(sealed)
	await get_tree().physics_frame
	for tick in 1200:
		miner._physics_process(1.0 / 60.0)
		await get_tree().physics_frame
		if miner.cargo > 0: break
	check(miner.resource_node == reachable and miner.cargo > 0, mode + " stale enclosed target recovers to reachable ore in real movement")
	miner.order_stop()
	reachable.amount = 0
	check(miner._ore_target() == null, mode + " no reachable ore waits rather than selecting enclosed field")
	for wall in battle.buildings: wall.free()
	battle.buildings.clear()
	battle._refresh_pathing()
	check(miner._ore_target() == sealed, mode + " opening enclosure makes ore eligible again")
	await finish()
