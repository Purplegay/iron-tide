extends "res://tests/camera_input_regression.gd"

func exercise_mode(mode: String) -> void:
	BattleRequest.configure_skirmish(mode, {"map_size": 3200, "starting_funds": 10000})
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
	get_window().focus_entered.emit()
	var prefix := mode + ": "
	var unit = battle.spawn_unit("MTNK", "ally", Vector2(3100, 3100))
	unit.process_mode = Node.PROCESS_MODE_DISABLED
	battle.select_unit(unit, false)
	for dimensions in [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(2560, 1440)]:
		stage.size = dimensions
		for i in 4: await get_tree().process_frame
		var right: float = screen.hud.prod_panel.get_global_rect().position.x
		check(is_equal_approx(battle.camera_play_rect().end.x, right), prefix + "play area follows actual sidebar at " + str(dimensions))
		for zoom in [0.45, 1.0, 3.2]:
			for angle in [-PI / 4.0, 0.0, PI / 4.0]:
				battle.camera.rotation = angle
				battle.camera.zoom = Vector2(zoom, zoom * 0.5)
				for point in [Vector2.ZERO, Vector2(3200, 0), Vector2(0, 3200), Vector2(3200, 3200), Vector2(3200, 1600)]:
					battle.center_on(point)
					battle.camera.force_update_scroll()
					var pixel: Vector2 = stage.get_canvas_transform() * point
					check(pixel.x > 30.0 and pixel.x < right - 30.0 and pixel.y > 30.0 and pixel.y < dimensions.y - 30.0,
						prefix + "edge point reaches unobstructed viewport " + str([dimensions, zoom, angle, point]), str(pixel))
				battle.center_on(Vector2(1600, 1600))
				battle.pan_screen(Vector2(100000, 0))
				battle.camera.force_update_scroll()
				var edge := Vector2(3200, 3200) if angle > 0.0 else Vector2(3200, 0)
				if is_zero_approx(angle): edge.y = 1600
				var pixel: Vector2 = stage.get_canvas_transform() * edge
				check(pixel.x > 40.0 and pixel.x < right - 40.0 and pixel.y > 40.0 and pixel.y < dimensions.y - 40.0,
					prefix + "max right pan exposes rightmost map point " + str([dimensions, zoom, angle]), str(pixel))
				if zoom >= 1.0:
					check(absf(pixel.x - (right - 64.0)) < 1.0, prefix + "right edge stops at small sidebar clearance")
				var before: Vector2 = battle.camera.position
				battle.pan_screen(Vector2(100000, 0))
				var drift: Vector2 = (battle.camera.position - before).rotated(-angle) * battle.camera.zoom
				check(drift.length() < 0.05, prefix + "repeated right pan remains bounded within subpixel precision", str(drift))
	stage.size = Vector2i(1600, 900)
	for i in 4: await get_tree().process_frame
	Iso.apply_to(battle.camera, 1.5)
	battle.center_on(Vector2(1600, 1600))
	battle.camera.force_update_scroll()
	battle.edge_scroll_enabled = true
	var panel: Rect2 = screen.hud.prod_panel.get_global_rect()
	await move_pointer(Vector2(panel.position.x - 1, panel.position.y + 120))
	check(stage.gui_get_hovered_control() == null, prefix + "strip beside sidebar belongs to battlefield")
	var before: Vector2 = battle.camera.position
	battle._update_camera(0.1)
	var delta: Vector2 = (battle.camera.position - before).rotated(-battle.camera.rotation) * battle.camera.zoom
	check(delta.distance_to(Vector2(78, 0)) < 0.01, prefix + "sidebar world edge scrolls horizontally", {
		"delta": str(delta), "focus": battle._window_focused,
		"mouse": str(stage.get_mouse_position()), "play": str(battle.camera_play_rect()),
		"direction": str(battle.camera_edge_pan_dir(stage.get_mouse_position()))})
	await move_pointer(panel.position + Vector2(20, 120))
	before = battle.camera.position
	battle._update_camera(0.1)
	check(battle.camera.position == before and stage.gui_get_hovered_control() != null, prefix + "sidebar controls do not trigger scrolling")
	battle.edge_scroll_enabled = false
	battle.center_on(Vector2(1600, 1600))
	var start := Vector2(panel.position.x - 150, 400)
	await move_pointer(start)
	await mouse_button(start, true, false, MOUSE_BUTTON_MIDDLE)
	await move_pointer(start - Vector2(100, 0), MOUSE_BUTTON_MASK_MIDDLE, Vector2(-100, 0))
	await mouse_button(start - Vector2(100, 0), false, false, MOUSE_BUTTON_MIDDLE)
	check(not unit.has_move_order and not battle._rmb_panning, prefix + "camera drag preserves unit orders")
	battle.pan_screen(Vector2(100000, 0))
	battle.camera.force_update_scroll()
	check((stage.get_canvas_transform() * unit.global_position).x < panel.position.x - 40, prefix + "right edge unit exposed beside deck after dragging")
	if battle.fog != null:
		battle.fog.free()
		battle.fog = null
	battle.hp_overlay.queue_redraw()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	stage.get_texture().get_image().save_png(output_dir.path_join(mode + "-right-edge.png"))
	# Live width/visibility changes must not use a cached 360px assumption.
	screen.hud.prod_panel.offset_left -= 100.0
	for i in 3: await get_tree().process_frame
	check(is_equal_approx(battle.camera_play_rect().end.x, screen.hud.prod_panel.get_global_rect().position.x), prefix + "widened sidebar immediately updates play area")
	screen.hud.prod_panel.hide()
	check(battle.camera_play_rect().size == Vector2(stage.size), prefix + "hidden sidebar restores full viewport")
	screen.free()
	await get_tree().process_frame
