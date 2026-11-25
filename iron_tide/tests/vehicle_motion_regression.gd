extends "res://tests/selection_regression.gd"

func actor(id: String, at: Vector2):
	var unit = battle.spawn_unit(id, "ally", at)
	unit.process_mode = Node.PROCESS_MODE_ALWAYS
	unit.set_process(false)
	unit.set_physics_process(false)
	unit.order_stop()
	unit.set_fire_stance("none")
	return unit

func draw_frame() -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw

func check_emitters(unit, label: String) -> void:
	check(unit._weapon_art.get("muzzles", []).size() == 32, label + " all 32 weapon origins exist")
	var aligned := true
	var selectable := true
	for direction in 32:
		unit.hull_angle = float(direction) * TAU / 32.0
		unit.turret_angle = unit.hull_angle
		unit.queue_redraw()
		await draw_frame()
		var local: Vector2 = Iso.dir(unit._weapon_muzzle() - unit.position)
		var pixel: Vector2i = Vector2i(unit._turret_draw_source.position + (local - unit._turret_draw_rect.position) / unit.RA2_SPRITE_SCALE)
		var pixels: Image = unit._ra2_tur.img
		var occupied := false
		for y in range(-2, 3):
			for x in range(-2, 3):
				var p := pixel + Vector2i(x, y)
				if p.x >= 0 and p.y >= 0 and p.x < pixels.get_width() and p.y < pixels.get_height() and pixels.get_pixelv(p).a > 0.08:
					occupied = true
					var world: Vector2 = unit.position + RA2Art.art_dir(unit._turret_draw_rect.position + (Vector2(p) - unit._turret_draw_source.position + Vector2(0.5, 0.5)) * unit.RA2_SPRITE_SCALE)
					selectable = selectable and unit.hit_test(world)
		aligned = aligned and occupied
	check(aligned, label + " every emitter touches actual rendered turret pixels")
	check(selectable, label + " turret-tip pixels remain selectable in every heading")

func exercise_mode(mode: String) -> void:
	BattleRequest.configure_skirmish(mode, {"map_size": 2400, "starting_funds": 8000})
	screen = load("res://scenes/battle.tscn").instantiate()
	stage.add_child(screen)
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	battle = screen.battle
	for group in ["obstacles", "resource_nodes"]:
		for node in get_tree().get_nodes_in_group(group): node.free()
	for unit in battle.units: unit.free()
	battle.units.clear()
	for building in battle.buildings: building.free()
	battle.buildings.clear()
	if battle.fog != null:
		battle.fog.free()
		battle.fog = null
	battle.water_rects.clear()
	battle.path_service.water_rects.clear()
	battle._refresh_pathing()
	for id in ["GAPOWR", "GAROBO"]:
		var b = battle._place_building(id, "ally", Vector2(300, 300 if id == "GAPOWR" else 600), true)
		b._buildup_play = -1.0
	battle._update_power()
	for id in ["MTNK", "FV", "SREF", "MGTK", "TNKD", "ROBO", "CMIN", "AMCV"]:
		var unit = actor(id, Vector2(1100, 1100))
		check(int(unit._ra2.get("facings", 0)) == 32, mode + id + " body has 32 source-rendered headings")
		check(int(unit._ra2_shd.get("facings", 0)) == 32, mode + id + " shadow matches body headings")
		if not unit._ra2_tur.is_empty():
			check(unit._ra2_tur.facings == 32 and RA2Art.frame_size(unit._ra2_tur) == RA2Art.frame_size(unit._ra2), mode + id + " turret shares heading count and canvas")
		if not unit.is_harvester:
			var speeds: Array[float] = []
			for degrees in [34.0, 35.0, 36.0, 45.0, 60.0, 80.0, 180.0]:
				unit._hull_prev = 0.0
				unit.velocity = Vector2.from_angle(deg_to_rad(degrees)) * unit.move_speed
				unit._align_drive_velocity(1.0 / 60.0)
				speeds.append(unit.velocity.length())
			check(speeds[0] > 0.0 and speeds[3] == 0.0 and speeds[4] == 0.0, mode + id + " small bends roll; sharp bends retain tight pivot envelope", speeds)
			check(absf(speeds[1] - speeds[2]) < unit.move_speed * 0.06, mode + id + " no speed cliff at previous 35-degree cutoff")
			check(speeds[6] == 0.0, mode + id + " reverse still turns before driving")
		battle.units.erase(unit)
		unit.free()
	var ifv = actor("FV", Vector2(1100, 1100))
	for id in ["E1", "ENGINEER", "CLEG"]:
		var passenger = actor(id, ifv.position + Vector2(20, 0))
		check(passenger.logistics.request_board(ifv), mode + id + " boarding for alternate turret")
		passenger.logistics.tick(0.1)
		check(passenger.embarked_in == ifv and ifv._ra2_tur.facings == 32, mode + id + " actual passenger installs 32-heading turret")
		await check_emitters(ifv, mode + id)
		ifv.logistics.request_unload()
		ifv.logistics.tick(0.5)
		battle.units.erase(passenger)
		passenger.free()
	battle.units.erase(ifv)
	ifv.free()
	var robot = actor("ROBO", Vector2(1200, 1200))
	robot.hull_angle = 0.0
	robot.turret_angle = 0.0
	robot.velocity = Vector2.ZERO
	var ground_muzzle: Vector2 = robot._weapon_muzzle()
	for tick in 180: robot._physics_process(1.0 / 60.0)
	await draw_frame()
	check(robot._art_lift > 8.0 and robot._art_lift < 24.0, mode + " online robot visibly suspended above ground", robot._art_lift)
	var first_lift: float = robot._art_lift
	var shadow: Rect2 = robot._shadow_draw_rect
	var turret_y: float = robot._turret_draw_rect.position.y
	var first_muzzle: Vector2 = robot._weapon_muzzle()
	check(first_muzzle.distance_to(ground_muzzle) > 4.0, mode + " weapon origin rises with robot")
	for tick in 50: robot._physics_process(1.0 / 60.0)
	await draw_frame()
	check(absf(robot._art_lift - first_lift) > 0.1, mode + " unselected idle robot continues bobbing")
	check(robot._shadow_draw_rect.position.distance_to(shadow.position) < 0.001, mode + " shadow stays on the ground while body bobs")
	check(absf(robot._turret_draw_rect.position.y - turret_y + robot._art_lift - first_lift) < 0.001, mode + " turret follows exactly the body's lift")
	check(Iso.dir(robot._weapon_muzzle() - first_muzzle).distance_to(Vector2(0, first_lift - robot._art_lift)) < 0.001, mode + " muzzle and visual lift stay aligned")
	check(robot.hit_test(robot.art_center()), mode + " hovering body remains selectable at rendered position")
	check(not robot.is_air_target() and robot.is_amphibious, mode + " hover stays ground-targetable and amphibious")
	robot.order_move(Vector2(1700, 1200))
	for tick in 15: robot._physics_process(1.0 / 60.0)
	var stopped: Vector2 = robot.position
	var destination: Vector2 = robot.move_target
	for b in battle.buildings:
		if b.power > 0: b.power = 0
	battle._update_power()
	for tick in 180: robot._physics_process(1.0 / 60.0)
	await draw_frame()
	check(robot._art_lift < 0.1 and robot.position == stopped and robot.has_move_order and robot.move_target == destination, mode + " loss of power settles body and pauses original order")
	for b in battle.buildings:
		if b.building_id == "GAPOWR": b.power = 200
	battle._update_power()
	for tick in 90: robot._physics_process(1.0 / 60.0)
	await draw_frame()
	check(robot._art_lift > 8.0 and robot.position.distance_to(stopped) > 20, mode + " power restoration raises robot and resumes destination")
	robot.order_stop()
	var stopped_again: Vector2 = robot.position
	for tick in 60: robot._physics_process(1.0 / 60.0)
	check(robot.position == stopped_again, mode + " stop order has no hover ground drift")
	await check_emitters(robot, mode + "ROBO suspended")
	screen.hud.hide()
	battle.camera.position = robot.position
	battle.camera.zoom = Iso.cam_zoom(3.0)
	battle.camera.reset_smoothing()
	battle.camera.force_update_scroll()
	await draw_frame()
	stage.get_texture().get_image().save_png(output_dir.path_join(mode + "-hover.png"))
	screen.free()
	await get_tree().process_frame
