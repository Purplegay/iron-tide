extends "res://tests/logistics_regression.gd"

func exercise_mode(mode: String) -> void:
	setup_logistics_scene(mode, "美国")
	for group in ["obstacles", "resource_nodes"]:
		for node in get_tree().get_nodes_in_group(group): node.free()
	for unit in battle.units: unit.free()
	battle.units.clear()
	for building in battle.buildings: building.free()
	battle.buildings.clear()
	if battle.fog != null: battle.fog.free(); battle.fog = null
	battle.water_rects = []
	battle.path_service.set_water([])
	var depot = battle._place_building("GADEPT", "ally", Vector2(1600, 1600), true)
	depot._buildup_play = -1.0
	depot.process_mode = Node.PROCESS_MODE_ALWAYS
	depot.set_process(false)
	battle._refresh_pathing()
	var tank = battle.spawn_unit("MTNK", "ally", Vector2(900, 1600))
	activate(tank)
	tank.set_fire_stance("none")
	tank.hp = tank.max_hp - 16.0
	depot._buildup_play = 0.0
	check(not tank.order_repair(depot), mode + ": unfinished buildup cannot accept service")
	depot._buildup_play = -1.0
	depot.under_construction = true
	check(not tank.order_repair(depot), mode + ": incomplete depot cannot accept service")
	depot.under_construction = false
	tank.order_move(Vector2(900, 2200))
	check(tank._path_pts.size() >= 2, mode + ": fixture has an existing movement route")
	battle.select_unit(tank, false)
	battle.camera.position = depot.position
	battle.camera.zoom = Iso.cam_zoom(1.5)
	battle.camera.reset_smoothing()
	battle.camera.force_update_scroll()
	await get_tree().physics_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
	var click: Vector2 = depot.art_center()
	# The art center may be an empty platform pixel; choose an actual visible pixel.
	for y in range(-100, 101, 5):
		for x in range(-100, 101, 5):
			var point: Vector2 = depot.art_center() + Vector2(x, y)
			if depot.hit_test(point): click = point; break
		if depot.hit_test(click): break
	check(battle._pick_building_at(click) == depot, mode + ": depot visible model can be picked")
	battle._issue_order(click)
	check(tank.repairing and tank.repair_depot == depot, mode + ": real right-click dispatches repair")
	check(tank._path_pts.size() >= 2 and tank._path_pts[-1].distance_to(tank.special.repair_entry) < 45.0, mode + ": repair replaces previous path with depot route")
	check(battle.command_cursor.resolve(click) == "repair", mode + ": valid repair target has repair cursor")
	var initial_hp: float = tank.hp
	var initial_funds: float = battle.funds
	depot._process(1.0)
	check(tank.hp == initial_hp and battle.funds == initial_funds, mode + ": travelling vehicles neither heal nor pay")
	check(not depot._repair_active and depot._layer_visible("idleanim") and not depot._layer_visible("specialanim"), mode + ": travelling repair order keeps one idle arm")
	var healed_on_pad := false
	for frame in 1200:
		await get_tree().physics_frame
		tank._physics_process(1.0 / 60.0)
		depot._process(1.0 / 60.0)
		if not healed_on_pad and tank.hp > initial_hp and tank.position.distance_to(RepairDock.pad(depot)) <= 6.0:
			healed_on_pad = true
			if DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				stage.get_texture().get_image().save_png(output_dir.path_join(mode + "-vehicle-on-platform.png"))
		if tank.hp >= tank.max_hp and not tank.repairing: break
	check(tank.hp == tank.max_hp, mode + ": vehicle physically reaches depot and heals", {"hp": tank.hp, "position": tank.position, "dock": tank._repair_dock})
	check(healed_on_pad, mode + ": real movement reaches platform before healing")
	check(not tank.repairing and tank.has_move_order, mode + ": repaired vehicle exits automatically")
	check(is_equal_approx(initial_funds - battle.funds, 16.0 * float(tank.data.cost) * 0.15 / tank.max_hp), mode + ": actual repair cost follows source percentage")
	# A second vehicle waits until the first physically vacates the platform.
	var queued = battle.spawn_unit("MTNK", "ally", depot.dock_point(Vector2(900, 1600)))
	activate(queued)
	queued.hp -= 8.0
	RepairDock.candidates(battle) # Prime before a new order in this same physics step.
	queued.order_repair(depot)
	check(RepairDock.candidates(battle).has(queued),mode+": new same-frame repair order invalidates candidates")
	queued.special.repair_stage="inside"
	check(RepairDock.occupied(tank,depot),mode+": live stage changes remain visible through shared candidates")
	queued.special.repair_stage="approach"
	queued._physics_process(1.0 / 60.0)
	check(queued.special.get("repair_stage") == "approach", mode + ": second vehicle waits for exiting occupant")
	for frame in 240:
		await get_tree().physics_frame
		tank._physics_process(1.0 / 60.0)
		queued._physics_process(1.0 / 60.0)
		if not tank.special.has("repair_exit_point"): break
	check(not tank.special.has("repair_exit_point") and tank.get_collision_exceptions().is_empty(), mode + ": vehicle physically exits without persistent collision exception", {"position": tank.position, "exit": tank.special.get("repair_exit_point"), "waiting": queued.position, "goal": queued.move_target})
	for frame in 600:
		await get_tree().physics_frame
		tank._physics_process(1.0 / 60.0)
		queued._physics_process(1.0 / 60.0)
		if queued.special.get("repair_stage") == "inside": break
	check(queued.special.get("repair_stage") == "inside", mode + ": waiting vehicle takes freed platform", {"position": queued.position, "entry": queued.special.get("repair_entry"), "goal": queued.move_target, "departed": tank.position})
	queued.order_stop()
	remove_actor(queued)
	# Reproduce a restored order whose approach point is now on blocked terrain.
	var returning = battle.spawn_unit("MTNK", "ally", Vector2(900, 1600))
	activate(returning)
	returning.hp -= 8.0
	returning.order_repair(depot)
	returning.special.repair_entry = depot.position
	var paths_before: int = battle.path_service.stats_paths
	for frame in 30:
		returning._physics_process(1.0 / 60.0)
	check(returning._path_pts.size() >= 2 and returning._path_pts[-1].distance_to(depot.position) > 16.0, mode + ": blocked repair entry yields a partial route")
	check(returning.move_target == depot.position and battle.path_service.stats_paths == paths_before + 1, mode + ": partial repair route is reused across physics ticks")
	remove_actor(returning)
	tank.order_stop()
	tank.hp = tank.max_hp - 4.0
	tank.order_repair(depot)
	tank.position = tank._repair_dock
	battle.funds = 0.0
	depot._process(1.0)
	check(tank.hp == tank.max_hp - 4.0, mode + ": no free healing with insufficient funds")
	battle.funds = 100.0
	depot._process(1.0)
	check(tank.hp == tank.max_hp, mode + ": funding resumes repair and clamps final step")
	tank._physics_process(1.0 / 60.0)
	tank.order_stop()
	tank.hp = tank.max_hp - 0.25
	tank.order_repair(depot)
	tank.position = tank._repair_dock
	tank._physics_process(1.0 / 60.0)
	depot._process(1.0)
	check(tank.hp == tank.max_hp, mode + ": fractional damage is fully repaired")
	for id in ["E1", "ORCA", "DEST"]:
		var rejected = battle.spawn_unit(id, "ally", Vector2(900, 1000))
		activate(rejected)
		rejected.hp *= 0.5
		rejected.order_repair(depot)
		check(not rejected.repairing, mode + ": depot rejects unsupported domain " + id)
		remove_actor(rejected)
	tank.order_stop()
	tank.hp = tank.max_hp - 8.0
	tank.order_repair(depot)
	tank.position = tank._repair_dock
	depot.side = "enemy"
	var before: float = tank.hp
	depot._process_repair(1.0)
	tank._physics_process(1.0 / 60.0)
	check(tank.hp == before and not tank.repairing, mode + ": ownership change cancels service without healing")
	var enemy = battle.spawn_unit("MTNK", "enemy", Vector2(1400, 1400))
	activate(enemy)
	enemy.hp -= 8.0
	check(enemy.order_repair(depot), mode + ": enemy vehicle can use its own depot")
	enemy.position = enemy._repair_dock
	var enemy_funds: float = battle.enemy_funds
	var ally_funds: float = battle.funds
	depot._process(1.0)
	check(enemy.hp == enemy.max_hp and battle.enemy_funds < enemy_funds and battle.funds == ally_funds, mode + ": enemy service heals and charges correct owner")
	depot.side = "ally"
	depot.hp -= 100.0
	var engineer = battle.spawn_unit("ENGINEER", "ally", Vector2(1400, 1200))
	activate(engineer)
	battle.select_unit(engineer, false)
	check(battle.command_cursor.resolve(click) == "repair", mode + ": engineer building repair cursor retains priority")
	tank.order_stop()
	tank.hp -= 8.0
	tank.order_repair(depot)
	tank.position = tank._repair_dock
	before = tank.hp
	battle.paused = true
	depot._process_repair(1.0)
	check(tank.hp == before, mode + ": paused game cannot advance service")
	battle.paused = false
	screen.free()
	await get_tree().process_frame
