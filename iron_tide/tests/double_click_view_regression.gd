extends "res://tests/selection_regression.gd"

func exercise_additional_input(mode: String, _soldier, _peer, tank) -> void:
	battle.clear_selection()
	for unit in battle.units.duplicate():
		if unit != tank:
			battle.units.erase(unit)
			unit.free()
	var peer = battle.spawn_unit("MTNK", "ally", Vector2(1600, 1600))
	var excluded: Array = []
	for i in 8: excluded.append(battle.spawn_unit("MTNK", "ally", Vector2(1600, 1600)))
	var hidden = battle.spawn_unit("MTNK", "ally", Vector2(1600, 1600))
	var dead = battle.spawn_unit("MTNK", "ally", Vector2(1600, 1600))
	var passenger = battle.spawn_unit("MTNK", "ally", Vector2(1600, 1600))
	var carrier = battle.spawn_unit("LCRF", "ally", Vector2(1600, 1600))
	var enemy = battle.spawn_unit("MTNK", "enemy", Vector2(1600, 1600))
	for unit in battle.units: unit.process_mode = Node.PROCESS_MODE_DISABLED
	dead.hp = 0
	dead._dead = true
	passenger.embarked_in = carrier
	for dimensions in [Vector2i(1280, 720), Vector2i(1600, 900)]:
		stage.size = dimensions
		for zoom in [0.5, 1.0, 2.0, 4.0]:
			battle.camera.zoom = Iso.cam_zoom(zoom)
			battle.camera.position = Vector2(1600, 1600)
			battle.camera.reset_smoothing()
			battle.camera.force_update_scroll()
			battle.select_unit(tank, false)
			battle._emit_selection()
			for i in 3: await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var click := Vector2(580, 320)
			place_art_at(tank, click)
			place_art_at(peer, Vector2(740, 390))
			var points := [
				Vector2(-30, 300), Vector2(dimensions.x + 30, 300),
				Vector2(600, -30), Vector2(600, dimensions.y + 30),
				screen.hud.prod_panel.get_global_rect().get_center(),
				screen.hud._minimap_frame.get_global_rect().get_center(),
				screen.hud._topbar.get_global_rect().get_center(),
				screen.hud.sel_panel.get_global_rect().get_center(),
			]
			for i in excluded.size(): place_art_at(excluded[i], points[i])
			place_art_at(hidden, Vector2(680, 470)); hidden.hide()
			place_art_at(dead, Vector2(780, 470))
			place_art_at(passenger, Vector2(880, 470))
			place_art_at(carrier, Vector2(-150, 470))
			place_art_at(enemy, Vector2(800, 300))
			battle._last_click_unit = null
			await gesture(click, click)
			# Keep the actual second mouse gesture within the double-click window
			# even when an overloaded test renderer takes >350ms between frames.
			battle._last_click_ms = Time.get_ticks_msec()
			await gesture(click, click)
			var label := "%s %s zoom %.1f: " % [mode, dimensions, zoom]
			check(battle.selected_units.size() == 2 and battle.selected_units.has(tank) and battle.selected_units.has(peer),
				label + "double click selects only visible friendly peers", battle.selected_units.size())
			for i in excluded.size():
				check(not battle.selected_units.has(excluded[i]), label + "excludes offscreen or HUD-covered peer " + str(i))
			check(not battle.selected_units.has(hidden) and not battle.selected_units.has(dead) and not battle.selected_units.has(passenger) and not battle.selected_units.has(enemy),
				label + "hidden dead embarked and hostile units excluded")
			battle.select_same_type_now()
			check(battle.selected_units.has(excluded[0]), label + "explicit same-type command retains its existing scope")
			# Move a formerly offscreen peer into view: recompute on the next gesture.
			place_art_at(excluded[0], Vector2(820, 420))
			battle._last_click_unit = null
			await gesture(click, click)
			battle._last_click_ms = Time.get_ticks_msec()
			await gesture(click, click)
			check(battle.selected_units.size() == 3 and battle.selected_units.has(excluded[0]), label + "next double click uses current view")
