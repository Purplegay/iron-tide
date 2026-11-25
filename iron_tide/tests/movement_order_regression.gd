extends "res://tests/selection_regression.gd"

const Preview = preload("res://scripts/world/movement_order_preview.gd")

func exercise_mode(mode: String) -> void:
	BattleRequest.configure_skirmish(mode, {"map_size": 3200, "starting_funds": 8000, "fog_of_war": true})
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
	for unit in battle.units: unit.free()
	for building in battle.buildings: building.free()
	battle.units.clear()
	battle.buildings.clear()
	for group in ["obstacles", "resource_nodes"]:
		for actor in get_tree().get_nodes_in_group(group): actor.free()
	battle.path_service.set_water([])
	battle._refresh_pathing()
	battle.camera.position = Vector2(1600, 1600)
	battle.camera.zoom = Iso.cam_zoom(1.0)
	battle.camera.reset_smoothing()
	battle.camera.force_update_scroll()
	get_window().focus_entered.emit()
	var tank = battle.spawn_unit("MTNK", "ally", Vector2(1250, 1600))
	var peer = battle.spawn_unit("FV", "ally", Vector2(1250, 1700))
	var enemy = battle.spawn_unit("MTNK", "enemy", Vector2(2500, 2500))
	for unit in [tank, peer, enemy]:
		unit.process_mode = Node.PROCESS_MODE_DISABLED
		unit.order_stop()
	battle.fog.rebuild()
	battle.fog.visible = false
	battle.select_unit(tank, false)
	battle._emit_selection()
	check(Preview.routes(battle).is_empty(), mode + " idle selection has no line")
	var goal := Vector2(1800, 1600)
	await click_move(goal)
	var routes := Preview.routes(battle)
	check(tank.has_move_order and routes.size() == 1, mode + " real right click produces a selected movement line")
	if routes.is_empty():
		screen.free()
		return
	check(routes[0].points == PackedVector2Array([tank.global_position, tank.move_target]), mode + " line ends at accepted formation destination")
	var accepted: Vector2 = tank.move_target
	await click_move(Vector2(1800, 1900), true)
	routes = Preview.routes(battle)
	check(routes[0].points.size() == 3 and routes[0].points[1] == accepted and routes[0].points[2] == tank.order_queue[0], mode + " Shift line includes active destination before queued point")
	for zoom in [0.5, 1.0, 2.0]:
		battle.camera.zoom = Iso.cam_zoom(zoom)
		battle.camera.force_update_scroll()
		await capture(mode + "-queue-" + str(zoom))
	battle.camera.zoom = Iso.cam_zoom(1.0)
	battle.camera.force_update_scroll()
	await click_move(Vector2(1700, 1500))
	routes = Preview.routes(battle)
	check(tank.order_queue.is_empty() and routes[0].points.size() == 2 and routes[0].points[1] == tank.move_target, mode + " replacement command removes stale queued lines")
	tank.position += Vector2(40, 0)
	check(Preview.routes(battle)[0].points[0] == tank.global_position, mode + " line origin follows moving unit")
	battle.select_unit(peer, true)
	battle._command_move(Vector2(1900, 1700), false, true)
	routes = Preview.routes(battle)
	check(routes.size() == 2 and routes.all(func(row): return row.attack_move), mode + " formation attack move has a distinct color and per-unit destinations")
	battle.selected_units.append(enemy)
	enemy.order_move(Vector2(2600, 2500))
	check(Preview.routes(battle).size() == 2, mode + " enemy order never appears even in malformed selection")
	peer.embarked_in = tank
	check(Preview.routes(battle).size() == 1, mode + " embarked unit has no ghost line")
	peer.embarked_in = null
	peer._dead = true
	check(Preview.routes(battle).size() == 1, mode + " dead unit has no ghost line")
	peer._dead = false
	battle.select_unit(tank, false)
	tank.order_move(Vector2(2300, 1800))
	battle.fog.visible = true
	battle.fog.rebuild()
	var visible_before: PackedByteArray = battle.fog.visible_cells.ally.duplicate()
	var explored_before: PackedByteArray = battle.fog.explored_cells.ally.duplicate()
	await capture(mode + "-fog-order")
	check(battle.fog.visible_cells.ally == visible_before and battle.fog.explored_cells.ally == explored_before, mode + " drawing own orders never explores terrain or reveals enemies")
	check(battle.move_order_overlay.z_index > battle.fog.z_index, mode + " own order remains above fog without changing visibility")
	tank.attack_ordered = true
	check(Preview.routes(battle).is_empty(), mode + " direct attack never masquerades as a movement command")
	tank.attack_ordered = false
	tank.has_move_order = false
	check(Preview.routes(battle).is_empty(), mode + " arrived order disappears")
	tank.order_move(goal)
	tank.order_stop()
	check(Preview.routes(battle).is_empty(), mode + " stop clears line immediately")
	tank.order_move(goal)
	battle.clear_selection()
	check(Preview.routes(battle).is_empty(), mode + " deselection clears line")
	battle.select_unit(tank, false)
	battle.ended = true
	check(Preview.routes(battle).is_empty(), mode + " battle end clears line")
	screen.free()
	await get_tree().process_frame

func click_move(world: Vector2, shift := false) -> void:
	var point: Vector2 = stage.get_canvas_transform() * world
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	stage.push_input(motion, true)
	await get_tree().process_frame
	await mouse_button(point, true, shift, MOUSE_BUTTON_RIGHT)
	await mouse_button(point, false, shift, MOUSE_BUTTON_RIGHT)

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	battle.move_order_overlay.visible = false
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var before := stage.get_texture().get_image()
	battle.move_order_overlay.visible = true
	battle.move_order_overlay.queue_redraw()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var after := stage.get_texture().get_image()
	var changed := 0
	# Central play area avoids HUD timers and production overlays.
	for y in range(250, 620):
		for x in range(300, 1150):
			var a := after.get_pixel(x, y)
			if a.g > 0.4 and a.r > 0.3 and a.b < 0.4 and a != before.get_pixel(x, y): changed += 1
	check(changed > 25, label + " real render contains visible green command strokes", changed)
	after.save_png(output_dir.path_join(label + ".png"))
