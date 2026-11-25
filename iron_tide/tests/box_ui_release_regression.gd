extends "res://tests/input_ownership_regression.gd"
## A world-origin selection keeps ownership when released over the minimap/HUD.

func exercise_mode(mode: String) -> void:
	BattleRequest.configure_skirmish(mode, {"map_size": 5000, "starting_funds": 8000})
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
	var targets: Array = []
	for id in ["MTNK", "TNKD", "SREF"]:
		var unit = battle.spawn_unit(id, "ally", Vector2(2400, 2400))
		unit.process_mode = Node.PROCESS_MODE_DISABLED
		targets.append(unit)
	var outside = battle.spawn_unit("E1", "ally", Vector2(2400, 2400))
	outside.process_mode = Node.PROCESS_MODE_DISABLED
	var enemy = battle.spawn_unit("MTNK", "enemy", Vector2(2400, 2400))
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	for dimensions in [Vector2i(1280, 720), Vector2i(1600, 900)]:
		stage.size = dimensions
		for i in 3: await get_tree().process_frame
		for zoom in [0.5, 1.0, 2.0]:
			battle.camera.position = Vector2(2500, 2500)
			battle.camera.zoom = Iso.cam_zoom(zoom)
			battle.camera.force_update_scroll()
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			for i in targets.size(): place_art_at(targets[i], Vector2(400 + i * 90, 300 + i * 40))
			place_art_at(outside, Vector2(850, 300))
			place_art_at(enemy, Vector2(550, 320))
			var minimap: Control = screen.hud.minimap
			var map_point := minimap.get_global_rect().get_center()
			var frame_point: Vector2 = screen.hud._minimap_frame.get_global_rect().position + Vector2(20, 12)
			var begin := Vector2(750, 200)
			var label := "%s %s zoom %.1f: " % [mode, dimensions, zoom]
			for endpoint in [map_point, frame_point]:
				for additive in [false, true]:
					battle.clear_selection()
					if additive: battle.select_unit(outside, false)
					battle._emit_selection()
					await get_tree().process_frame
					var camera_before: Vector2 = battle.camera.position
					await move_pointer(begin)
					await mouse_button(begin, true, additive)
					await move_pointer(endpoint, MOUSE_BUTTON_MASK_LEFT, endpoint - begin)
					check(battle.dragging and not minimap._dragging and stage.gui_get_hovered_control() != null, label + "world drag enters real map/frame without transfer")
					await mouse_button(endpoint, false, additive)
					check(targets.all(func(u): return battle.selected_units.has(u)) and battle.selected_units.has(outside) == additive and not battle.selected_units.has(enemy), label + "release over map/frame selects enclosed allies; Shift preserves outside ally", str(battle.selected_units.size()))
					check(not battle.dragging and not minimap._dragging and battle.camera.position.is_equal_approx(camera_before), label + "release ends gesture without minimap camera jump")
					var selected: Array = battle.selected_units.duplicate()
					await mouse_button(Vector2(900, 250), false)
					check(battle.selected_units == selected and not battle.dragging, label + "later release cannot repeat stale selection")
			# Crossing the minimap and returning to world also keeps the gesture.
			battle.clear_selection()
			battle._emit_selection()
			await move_pointer(begin)
			await mouse_button(begin, true)
			await move_pointer(map_point, MOUSE_BUTTON_MASK_LEFT, map_point - begin)
			await move_pointer(Vector2(300, 430), MOUSE_BUTTON_MASK_LEFT, Vector2(300, 430) - map_point)
			await mouse_button(Vector2(300, 430), false)
			check(targets.all(func(u): return battle.selected_units.has(u)), label + "cross map and return to battlefield selects")
			# The inverse gesture belongs exclusively to the minimap.
			var selected: Array = battle.selected_units.duplicate()
			var camera_before: Vector2 = battle.camera.position
			await move_pointer(map_point)
			await mouse_button(map_point, true)
			check(minimap._dragging and not battle.dragging, label + "map press retains minimap ownership")
			await move_pointer(Vector2(900, 250), MOUSE_BUTTON_MASK_LEFT, Vector2(900, 250) - map_point)
			await mouse_button(Vector2(900, 250), false)
			check(not minimap._dragging and not battle.dragging and battle.selected_units == selected, label + "map-to-world release preserves unit selection")
			check(not battle.camera.position.is_equal_approx(camera_before), label + "map drag still moves camera")
	screen.free()
	await get_tree().process_frame
