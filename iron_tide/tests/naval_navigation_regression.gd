extends "res://tests/ground_control_regression.gd"

func exercise(mode: String) -> void:
	start(mode)
	for b in battle.buildings: b.free()
	battle.buildings.clear()
	if battle.fog != null: battle.fog.free(); battle.fog = null
	set_water([Rect2(200, 200, 2000, 2000)])
	for id in ["DEST", "AEGIS", "CARRIER", "DLPH", "LCRF"]:
		for turn in [60.0, 180.0]:
			var u = battle.spawn_unit(id, "ally", Vector2(800, 800))
			activate(u)
			u.hull_angle = 0.0
			u.order_move(u.position + Vector2.from_angle(deg_to_rad(turn)) * 500.0)
			await get_tree().physics_frame
			var slip := 0.0
			var max_turn := 0.0
			var wet := true
			# Slow native ROT=1 hulls need several seconds just for a reversal.
			for tick in 1800:
				var before: float = u.hull_angle
				u._physics_process(1.0 / 60.0)
				max_turn = maxf(max_turn, absf(angle_difference(before, u.hull_angle)))
				if u.velocity.length() > 1.0: slip = maxf(slip, absf(angle_difference(u.hull_angle, u.velocity.angle())))
				wet = wet and battle.in_water_world(u.position)
				if not u.has_move_order: break
				if tick % 60 == 0: await get_tree().process_frame
			check(slip < 0.01, prefix + id + " follows bow through " + str(turn), rad_to_deg(slip))
			check(max_turn <= deg_to_rad(float(u._mv("rot", 0))) / 60.0 + 0.0001, prefix + id + " retains native ROT")
			check(not u.has_move_order and wet, prefix + id + " reaches water destination", str(u.position))
			u.order_stop()
			var stopped: Vector2 = u.position
			await step([u], 30)
			check(u.position.distance_to(stopped) < 0.01, prefix + id + " stop does not drift")
			battle.units.erase(u); u.free()
	await check_yard_and_dolphin()
	Ra2Sfx.stop_all(); Music.stop()
	Music.player.stream = null
	OS.delay_msec(150)
	await finish()

func set_water(rects: Array) -> void:
	battle.water_rects = rects
	battle.path_service.set_water(rects)
	battle._refresh_pathing()

func check_yard_and_dolphin() -> void:
	set_water([Rect2(200, 200, 2000, 2000)])
	var yard = battle._place_building("GAYARD", "ally", Vector2(1200, 1200), true)
	battle.power_low = false
	for id in ["DEST", "DLPH"]:
		var ship = battle.spawn_unit(id, "ally", Vector2(800, 1200))
		activate(ship)
		ship.order_move(Vector2(1600, 1200))
		check(ship._path_pts.size() > 2, prefix + id + " routes around shipyard footprint")
		await get_tree().physics_frame
		await step([ship], 2400)
		check(ship.position.distance_to(Vector2(1600, 1200)) < 35, prefix + id + " physically clears shipyard detour", str(ship.position))
		battle.units.erase(ship); ship.free()
	var hud = screen.hud
	hud.select_prod_tab("naval")
	check(hud._unit_catalog().has("DLPH") and hud._cat_match(GameData.get_unit("DLPH")), prefix + "dolphin belongs to visible naval catalog")
	check(not yard.unit_prereqs_ok("DLPH"), prefix + "dolphin requires battle lab")
	var lab = battle._place_building("GATECH", "ally", Vector2(400, 400), true)
	check(yard.unit_prereqs_ok("DLPH"), prefix + "battle lab unlocks dolphin")
	battle.funds = 10000
	check(yard.enqueue("DLPH"), prefix + "dolphin queues at actual shipyard")
	var duration: float = GameData.ra2_build_time(GameData.get_unit("DLPH")) / yard.build_speed
	yard._process(duration / yard.production_work_rate("DLPH") + 0.01)
	var dolphins: Array = battle.units.filter(func(u): return u.unit_id == "DLPH")
	check(dolphins.size() == 1, prefix + "production releases one dolphin")
	if not dolphins.is_empty():
		var dolphin = dolphins[0]
		check(dolphin._ra2.get("tex") != null and dolphin._seq.has("Walk") and dolphin._seq.has("Guard"), prefix + "dolphin has real sprite and swimming/idle sequences", dolphin._seq.keys())
		var image: Image = dolphin._ra2.tex.get_image()
		if image.is_compressed(): image.decompress()
		for sequence in ["Guard", "Walk", "FireUp", "Die1"]:
			var spec: Dictionary = dolphin._seq[sequence]
			var frames: Array = []
			for facing in (1 if sequence == "Die1" else 8):
				for phase in int(spec.per): frames.append(int(spec.start) + facing * int(spec.per) + phase)
			check(frames.all(func(frame): return not image.get_region(Rect2i(RA2Art.src_rect(dolphin._ra2, frame))).is_invisible()), prefix + "dolphin opaque frames " + sequence)
		activate(dolphin)
		var start_pos: Vector2 = dolphin.position
		dolphin.order_move(start_pos + Vector2(250, 250))
		await get_tree().physics_frame
		await step([dolphin], 420)
		check(dolphin.position.distance_to(start_pos) > 150 and battle.in_water_world(dolphin.position), prefix + "produced dolphin leaves yard under actual movement", str(dolphin.position))
		battle.units.erase(dolphin); dolphin.free()
	# A shoreline may border any side. An open water side must not be ignored
	# merely because the old generic producer direction points inland.
	var extent: Rect2 = yard.footprint_rect().grow(45.0)
	for axis in [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]:
		var area := Rect2(100, 100, 2200, 2200)
		if axis.x > 0: area.position.x = yard.position.x + extent.position.x
		if axis.y > 0: area.position.y = yard.position.y + extent.position.y
		if axis.x < 0: area.size.x = yard.position.x + extent.end.x - area.position.x
		if axis.y < 0: area.size.y = yard.position.y + extent.end.y - area.position.y
		set_water([area])
		var point: Vector2 = yard._spawn_point("DEST")
		check(point != Vector2.INF and yard._exit_position_clear(point, 26, true, false), prefix + "shipyard uses water side " + str(axis), str(point))
	set_water([])
	check(yard._spawn_point("DLPH") == Vector2.INF, prefix + "no dry-ground fallback without water")
	battle.buildings.erase(lab); lab.free()
	battle.buildings.erase(yard); yard.free()
	set_water([Rect2(400, 200, 1800, 2000)])
	for id in ["DEST", "LCRF"]:
		var ship = battle.spawn_unit(id, "ally", Vector2(800, 600))
		activate(ship)
		ship.order_move(Vector2(200, 600))
		await get_tree().physics_frame
		await step([ship], 1800)
		check(battle.in_water_world(ship.position) if id == "DEST" else ship.position.distance_to(Vector2(200, 600)) < 35, prefix + id + " retains water-only versus amphibious domain", str(ship.position))
		battle.units.erase(ship); ship.free()
