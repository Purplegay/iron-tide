extends "res://tests/selection_regression.gd"

func draw_frame() -> void:
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw

func exercise_mode(mode: String) -> void:
	BattleRequest.configure_skirmish(mode, {"map_size": 3200, "starting_funds": 10000})
	screen = load("res://scenes/battle.tscn").instantiate()
	stage.add_child(screen)
	battle = screen.battle
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	# Keep the doorway fixture clear; blockage is injected explicitly below.
	for obstacle in get_tree().get_nodes_in_group("obstacles"): obstacle.free()
	battle._refresh_pathing()
	var prefix := mode + ": "
	var factory = battle._place_building("GAWEAP", "ally", Vector2(1600, 1600), true)
	factory.process_mode = Node.PROCESS_MODE_DISABLED
	battle.select_building(factory)
	battle._emit_selection()
	battle.camera.position = factory.global_position
	battle.camera.zoom = Vector2(2, 1)
	battle.camera.reset_smoothing()
	battle.camera.force_update_scroll()
	check(not factory._buildup_art.is_empty(), prefix + "real factory buildup asset")
	for id in ["GAWEAP_1", "GAWEAP_2", "GAWEAP_3", "GAWEAP_4"]:
		var door_art := RA2Art.art(id)
		check(door_art.get("tex") != null and int(door_art.get("count", 0)) == 4,
			prefix + "real door texture imports " + id)
	var footprint: PackedVector2Array = factory.footprint_poly()
	for fraction in [0.15, 0.5, 0.9]:
		factory._buildup_play = GameData.ra2_buildup_seconds() * fraction
		factory.queue_redraw()
		await draw_frame()
		if DisplayServer.get_name() != "headless":
			var art: Dictionary = factory._buildup_art
			var fi: int = factory._art_frame
			var anchors: Array = [int(art.count) - 1]
			var rect := RA2Art.draw_rect(art, factory.radius, anchors)
			var mismatches := 0
			var opaque := 0
			for x in range(0, int(rect.size.x), 4):
				for y in range(0, int(rect.size.y), 4):
					var world: Vector2 = factory.global_position + RA2Art.art_dir(rect.position + Vector2(x + 0.5, y + 0.5))
					var expected := RA2Art.hits_pixel(world, factory.global_position, art, factory.radius, anchors, fi)
					opaque += 1 if expected else 0
					if factory.hit_test(world) != expected:
						mismatches += 1
			check(opaque > 20 and mismatches == 0, prefix + "buildup hit pixels match drawn frame %.2f" % fraction, mismatches)
			check(factory.art_center().is_equal_approx(RA2Art.draw_center(factory.global_position, art, factory.radius, anchors)),
				prefix + "buildup center uses fixed completion anchor %.2f" % fraction)
			stage.get_texture().get_image().save_png(output_dir.path_join(mode + "-buildup-%d.png" % int(fraction * 100)))
	factory._process(GameData.ra2_buildup_seconds())
	await draw_frame()
	check(factory.is_operational() and factory.footprint_poly() == footprint,
		prefix + "buildup completes without changing physical footprint")
	if DisplayServer.get_name() != "headless":
		check(factory._art_source == factory._ra2 and factory._art_frame == 0,
			prefix + "completion restores finished sprite hit source")
		stage.get_texture().get_image().save_png(output_dir.path_join(mode + "-finished.png"))
	Ra2Sfx.stop_eva()
	Ra2Sfx._eva_last.clear()
	var ready_before: int = Ra2Sfx.a_eva_plays + Ra2Sfx.a_eva_queued
	battle.request_structure("GAPOWR")
	check(Ra2Sfx.a_eva_plays + Ra2Sfx.a_eva_queued == ready_before + 1,
		prefix + "sidebar construction start announces building once")
	# Start and completion are distinct EVA events; measure completion after request.
	ready_before = Ra2Sfx.a_eva_plays + Ra2Sfx.a_eva_queued
	battle._tick_structure_queue(float(battle.current_structure_job().time))
	check(int(battle.struct_ready.get("GAPOWR", 0)) == 1 and Ra2Sfx.a_eva_plays + Ra2Sfx.a_eva_queued == ready_before + 1,
		prefix + "sidebar construction ready announces completion once")
	battle._tick_structure_queue(5.0)
	check(Ra2Sfx.a_eva_plays + Ra2Sfx.a_eva_queued == ready_before + 1,
		prefix + "ready inventory does not repeat completion announcement")
	battle.funds = 10000
	battle.power_low = false
	factory.enqueue("MTNK")
	var duration: float = GameData.ra2_build_time(GameData.get_unit("MTNK")) / factory.build_speed
	var rate: float = factory.production_work_rate("MTNK")
	factory._process(duration * 0.25 / rate)
	check(factory._anim_state != "production", prefix + "doors stay closed during early production")
	var points: Array[Vector2] = []
	for i in 10:
		points.append(factory._spawn_point("MTNK"))
	check(points.all(func(p): return p == points[0]), prefix + "unchanged exits are deterministic")
	check(points[0] != Vector2.INF and not battle.path_service.is_blocked(points[0]),
		prefix + "ground exit is traversable")
	var path = battle.path_service
	var saved_cost: PackedFloat32Array = path.cost.duplicate()
	path.cost.fill(-1.0)
	check(factory._spawn_point("MTNK") == Vector2.INF, prefix + "fully blocked ground exits return no position")
	var saved_water: Array = path.water_rects.duplicate()
	path.water_rects.clear()
	check(factory._spawn_point("DEST") == Vector2.INF, prefix + "ship never falls back onto dry ground")
	var saved_water_cost: PackedFloat32Array = path.water_cost.duplicate()
	path.water_rects.assign([Rect2(Vector2.ZERO, Vector2(battle.map_size, battle.map_size))])
	path.water_cost.fill(1.0)
	var ship_exit: Vector2 = factory._spawn_point("DEST")
	check(ship_exit != Vector2.INF and path.in_water(ship_exit) and not path.is_blocked(ship_exit, true),
		prefix + "ship uses a valid water exit")
	path.water_rects.assign(saved_water)
	path.water_cost = saved_water_cost
	var air_exit: Vector2 = factory._spawn_point("ORCA")
	check(air_exit != Vector2.INF, prefix + "air exit ignores ground blockers")
	check(not factory._exit_position_clear(Vector2(1, 1), 10.0, false, true),
		prefix + "unit body cannot straddle map edge")
	Ra2Sfx.stop_eva()
	Ra2Sfx._eva_last.clear()
	var sound_before: int = Ra2Sfx.a_eva_plays + Ra2Sfx.a_eva_queued
	var units_before: int = battle.units.size()
	var funds_before: float = battle.funds
	factory._process(duration / rate)
	check(battle.units.size() == units_before and factory.production == ["MTNK"],
		prefix + "blocked completed unit stays in queue")
	check(is_equal_approx(factory.progress, duration), prefix + "blocked unit retains full paid progress")
	var paid_funds: float = battle.funds
	check(is_equal_approx(funds_before - paid_funds, float(GameData.get_unit("MTNK").cost) * 0.75),
		prefix + "blocked completion charges only remaining cost")
	factory._process(1.0)
	check(battle.funds == paid_funds and Ra2Sfx.a_eva_plays + Ra2Sfx.a_eva_queued == sound_before,
		prefix + "waiting exit neither charges again nor announces unit ready")
	check(screen.hud._queue_caption(factory).contains("出口受阻"), prefix + "blocked exit has explicit HUD state")
	path.cost = saved_cost
	factory._process(0.0)
	check(battle.units.size() == units_before + 1 and factory.production.is_empty(),
		prefix + "cleared exit releases exactly one waiting unit")
	check(battle.funds == paid_funds, prefix + "release does not charge twice")
	check(Ra2Sfx.a_eva_plays + Ra2Sfx.a_eva_queued == sound_before + 1,
		prefix + "unit ready announcement occurs once on release")
	check(factory._anim_state == "production", prefix + "door remains visible for departing unit")
	check(factory._layer_visible("deployinganim") and not factory._layer_visible("roofdeployinganim"),
		prefix + "ground production opens ground door only")
	var produced = battle.units[-1]
	var next_exit: Vector2 = factory._spawn_point("MTNK")
	check(next_exit != Vector2.INF and next_exit != produced.position and next_exit.distance_to(points[0]) <= 160.01,
		prefix + "occupied physical door uses a nearby free offset")
	factory.queue_redraw()
	await draw_frame()
	var open_image: Image
	if DisplayServer.get_name() != "headless":
		open_image = stage.get_texture().get_image()
		open_image.save_png(output_dir.path_join(mode + "-exit-open.png"))
	produced.position += ProductionExit.direction(factory) * 200.0
	check(factory._spawn_point("MTNK") == points[0], prefix + "departure restores the same fixed factory exit")
	var active_time: float = factory._anim_t
	factory._process(5.0)
	check(factory._anim_state != "production", prefix + "door returns to idle after departure")
	# 固定无关的常驻动画，比较工厂范围的开门/关门真实渲染像素。
	factory._anim_t = active_time
	factory.queue_redraw()
	await draw_frame()
	if open_image != null:
		var closed_image := stage.get_texture().get_image()
		var changed := 0
		for x in range(600, 1000):
			for y in range(200, 420):
				if open_image.get_pixel(x, y) != closed_image.get_pixel(x, y):
					changed += 1
		check(changed > 50, prefix + "door opening changes real factory pixels", changed)
		closed_image.save_png(output_dir.path_join(mode + "-exit-closed.png"))
	factory._process(5.0)
	check(battle.units.size() == units_before + 1 and Ra2Sfx.a_eva_plays + Ra2Sfx.a_eva_queued == sound_before + 1,
		prefix + "idle frames do not duplicate unit or completion announcement")
	factory.enqueue("MTNK")
	var door_time: float = factory._door_open_seconds()
	factory._process(duration / rate - door_time * 0.5)
	check(factory._anim_state == "production" and factory._door_fraction() > 0.0,
		prefix + "next production cycle opens doors before completion")
	path.cost.fill(-1.0)
	factory._process(door_time)
	check(factory.exit_blocked, prefix + "second blocked cycle is tracked")
	factory.cancel_at(0)
	check(not factory.exit_blocked and factory.production.is_empty() and factory.progress == 0.0
		and is_equal_approx(battle.funds, paid_funds),
		prefix + "cancel blocked unit refunds paid amount and clears blocked state")
	path.cost = saved_cost
	factory.enqueue("SHAD")
	factory._process(GameData.ra2_build_time(GameData.get_unit("SHAD")) / factory.build_speed / factory.production_work_rate("SHAD") - 0.1)
	check(factory._anim_state == "production" and factory._layer_visible("roofdeployinganim")
		and not factory._layer_visible("deployinganim"), prefix + "air production opens roof door only")
	screen.free()
	await get_tree().process_frame
