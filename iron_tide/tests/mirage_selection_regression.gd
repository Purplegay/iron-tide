extends "res://tests/selection_regression.gd"

func exercise_mode(mode: String) -> void:
	BattleRequest.configure_skirmish(mode, {"map_size": 3200, "starting_funds": 8000})
	screen = load("res://scenes/battle.tscn").instantiate()
	stage.add_child(screen)
	battle = screen.battle
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	battle.process_mode = Node.PROCESS_MODE_ALWAYS
	battle.set_process(false)
	battle.set_physics_process(false)
	for child in battle.get_children(): child.process_mode = Node.PROCESS_MODE_DISABLED
	screen.hud.process_mode = Node.PROCESS_MODE_ALWAYS
	screen.hud.set_process(false)
	if battle.fog != null: battle.fog.free(); battle.fog = null
	await get_tree().process_frame
	get_window().focus_entered.emit()
	for id in ["MGTK", "R3MIRAGE"]:
		if id == "R3MIRAGE" and mode == MatchRules.RA2: continue
		var tank = battle.spawn_unit(id, "ally", Vector2(1600, 1600))
		tank.process_mode = Node.PROCESS_MODE_DISABLED
		tank.order_stop()
		tank.special.reveal = 0.0
		tank.motion_pose.capture(tank)
		for tree in ["TREE01", "TREE02", "TREE03", "TREE04"]:
			if id == "R3MIRAGE" and tree != "TREE01": continue
			tank.special.mirage_tree = tree
			var visual := AlliedAbilities.disguise_visual(tank)
			var label: String = mode + "/" + id + "/" + tree
			check(not visual.is_empty(), label + ": disguised fixture")
			var missed_pixels := 0
			for offset in [Vector2.ZERO, Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
				var point: Vector2 = tank.position + offset * tank.radius
				var tree_hit := RA2Art.hits_pixel(point, tank.position, visual.art, tank.radius, visual.anchors, visual.frame, 0.0, tank.RA2_SPRITE_SCALE)
				if not tree_hit: missed_pixels += 1
				check(tank.hit_test(point), label + ": ground footprint selectable " + str(offset))
				check(battle._pick_at(point) == tank, label + ": real picker finds ground footprint " + str(offset))
				tank.side = "enemy"
				check(tank.hit_test(point) == tree_hit, label + ": enemy retains tree pixel boundary")
				tank.side = "ally"
			check(missed_pixels > 0, label + ": reproduces transparent tree pixels over tank footprint")
			var canopy: Vector2 = canopy_point(tank, visual)
			check(tank.hit_test(canopy), label + ": canopy remains selectable")
			check(not tank.hit_test(tank.position + Vector2(500, 500)), label + ": distant ground rejected")
			for zoom in [0.5, 1.0, 2.0, 4.0]:
				battle.camera.rotation = PI / 4.0
				battle.camera.zoom = Vector2(zoom, zoom * 0.5)
				battle.camera.position = tank.position
				battle.camera.reset_smoothing()
				battle.camera.force_update_scroll()
				await get_tree().process_frame
				battle.clear_selection()
				battle._last_click_unit = null
				# Keep the injected pointer above the selection/status panels.
				var pixel := Vector2(650, 350)
				tank.position = stage.get_canvas_transform().affine_inverse() * pixel - Vector2.RIGHT * tank.radius
				tank.motion_pose.capture(tank)
				await gesture(pixel, pixel)
				check(battle.selected_units == [tank], label + ": ground mouse click selects at zoom " + str(zoom))
				check(AlliedAbilities.disguise_visual(tank).art.key == visual.art.key, label + ": selecting does not reveal or change disguise")
			tank.embarked_in = tank
			check(not tank.hit_test(tank.position), label + ": embarked tank cannot be picked")
			tank.embarked_in = null
			tank._dead = true
			check(not tank.hit_test(tank.position), label + ": dead tank cannot be picked")
			tank._dead = false
			tank.special.reveal = 1.0
			check(AlliedAbilities.disguise_visual(tank).is_empty(), label + ": firing reveal still removes disguise")
			tank.special.reveal = 0.0
		battle.clear_selection()
		battle.units.erase(tank)
		tank.free()
	screen.free()
	await get_tree().process_frame

func canopy_point(tank, visual: Dictionary) -> Vector2:
	var rect := RA2Art.draw_rect(visual.art, tank.radius, visual.anchors, 0.0, tank.RA2_SPRITE_SCALE)
	for y in range(int(rect.position.y), int(rect.get_center().y), 2):
		for x in range(int(rect.position.x), int(rect.end.x), 2):
			var point: Vector2 = tank.position + RA2Art.art_dir(Vector2(x, y))
			if RA2Art.hits_pixel(point, tank.position, visual.art, tank.radius, visual.anchors, visual.frame, 0.0, tank.RA2_SPRITE_SCALE): return point
	return Vector2.INF
