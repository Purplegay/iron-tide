extends "res://tests/selection_regression.gd"
## Includes the existing selection regression, then exercises modifiers and GUI ownership.

func exercise_additional_input(mode: String, soldier, peer, tank) -> void:
	var prefix := mode + ": "
	place_art_at(tank, Vector2(850, 400))
	battle.select_unit(soldier, false)
	battle._last_click_unit = null
	await gesture(Vector2(730, 400), Vector2(730, 400), true)
	check(battle.selected_units.size() == 2 and battle.selected_units.has(soldier) and battle.selected_units.has(peer),
		prefix + "Shift click adds without losing original unit")
	battle.select_unit(soldier, false)
	battle.select_unit(peer, true)
	await gesture(Vector2(730, 400), Vector2(730, 400), true)
	check(battle.selected_units.size() == 1 and battle.selected_units.has(soldier) and not peer.selected,
		prefix + "Shift click removes selected unit and its visual flag")
	battle.select_unit(soldier, false)
	await gesture(Vector2(1000, 350), Vector2(1000, 350), true)
	check(battle.selected_units.size() == 1 and battle.selected_units.has(soldier), prefix + "Shift empty click preserves selection")
	battle.select_unit(soldier, false)
	await gesture(Vector2(710, 370), Vector2(880, 430), true)
	check(battle.selected_units.size() == 3 and battle.selected_units.has(soldier) and battle.selected_units.has(peer)
		and battle.selected_units.has(tank), prefix + "Shift box appends mixed unit types")
	battle.select_unit(soldier, false)
	battle.select_unit(peer, true)
	battle.select_unit(tank, true)
	await gesture(Vector2(710, 370), Vector2(880, 430), true)
	check(battle.selected_units.size() == 3, prefix + "Shift box does not duplicate or toggle existing units")
	await gesture(Vector2(950, 300), Vector2(1050, 340), true)
	check(battle.selected_units.size() == 3, prefix + "empty Shift box preserves selection")
	var enemy = battle.spawn_unit("E1", "enemy", Vector2(1600, 1600))
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	place_art_at(enemy, Vector2(920, 400))
	await gesture(Vector2(900, 370), Vector2(940, 430), true)
	check(not battle.selected_units.has(enemy) and battle.selected_units.size() == 3,
		prefix + "Shift box excludes enemies and preserves friendly selection")
	await gesture(Vector2(620, 370), Vector2(680, 430))
	check(battle.selected_units.size() == 1 and battle.selected_units.has(soldier), prefix + "plain box replaces selection")
	var plant
	for building in battle.buildings:
		if building.side == "ally" and building.building_id == "GAPOWR":
			plant = building
	check(plant != null, prefix + "real building fixture exists")
	if plant != null:
		# 选择互斥测试使用落成建筑；展开第 0 帧可能没有可点击的中心像素。
		plant._buildup_play = -1.0
		plant.queue_redraw()
		await get_tree().process_frame
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			check(plant.hit_test(plant.art_center()), prefix + "finished building selection starts on visible pixels")
		var previous_position: Vector2 = plant.global_position
		place_art_at(plant, Vector2(1000, 400))
		await gesture(Vector2(1000, 400), Vector2(1000, 400), true)
		check(battle.selected_building == plant and battle.selected_units.is_empty(), prefix + "building remains an exclusive selection")
		await gesture(Vector2(650, 400), Vector2(650, 400), true)
		check(battle.selected_building == null and battle.selected_units.has(soldier), prefix + "adding a unit leaves building selection")
		plant.global_position = previous_position
	battle.select_unit(soldier, false)
	battle._emit_selection()
	await get_tree().process_frame
	var blank: Vector2 = screen.hud.prod_panel.get_global_rect().end - Vector2(20, 20)
	var minimap: Control = screen.hud.minimap
	var map_point: Vector2 = minimap.get_global_rect().get_center()
	for point in [blank, map_point]:
		battle.select_unit(soldier, false)
		var old_camera: Vector2 = battle.camera.position
		await move_pointer(point)
		check(stage.gui_get_hovered_control() != null, prefix + "HUD test point hits a real control", str(point))
		soldier.has_move_order = false
		await mouse_button(point, true, false, MOUSE_BUTTON_RIGHT)
		check(not battle._rmb_panning, prefix + "HUD right press never starts world pan")
		await mouse_button(point, false, false, MOUSE_BUTTON_RIGHT)
		check(not soldier.has_move_order and battle.camera.position.is_equal_approx(old_camera),
			prefix + "HUD right click neither orders nor moves world")
	# Click blank production space, then drag from the world into that same space.
	await move_pointer(blank)
	await mouse_button(blank, true)
	check(not battle.dragging, prefix + "blank HUD left press does not start selection")
	await mouse_button(blank, false)
	check(battle.selected_units.has(soldier), prefix + "blank HUD click preserves selection")
	battle.select_unit(soldier, false)
	await gesture(Vector2(600, 330), blank)
	check(not battle.dragging and battle.selected_units.has(soldier) and battle.selected_units.has(peer) and battle.selected_units.has(tank),
		prefix + "world-to-HUD release completes the world-owned box")
	var boxed: Array = battle.selected_units.duplicate()
	# Do not reset drag state: a later release must not finish a stale gesture.
	await move_pointer(Vector2(1000, 350))
	await mouse_button(Vector2(1000, 350), false)
	check(battle.selected_units == boxed, prefix + "no stale selection after crossing HUD")
	await move_pointer(blank)
	await mouse_button(blank, true)
	await move_pointer(Vector2(1000, 350), MOUSE_BUTTON_MASK_LEFT, Vector2(1000, 350) - blank)
	await mouse_button(Vector2(1000, 350), false)
	check(not battle.dragging and battle.selected_units.has(soldier), prefix + "HUD-to-world drag never starts a world selection")
	# Production button: real mouse event must cancel one queued building, not move units.
	battle.select_unit(soldier, false)
	screen.hud.select_prod_tab("building")
	battle.request_structure("GAPOWR")
	screen.hud._refresh_production()
	await get_tree().process_frame
	var button: Button = screen.hud._prod_buttons["GAPOWR"]
	var button_point: Vector2 = button.get_global_rect().get_center()
	check(battle.struct_queue.size() == 1, prefix + "one queued building before cancel")
	soldier.has_move_order = false
	await move_pointer(button_point)
	await mouse_button(button_point, true, false, MOUSE_BUTTON_RIGHT)
	await mouse_button(button_point, false, false, MOUSE_BUTTON_RIGHT)
	check(battle.struct_queue.size() == 1 and battle.struct_queue[0].get("paused", false), prefix + "first right click pauses production without leaking a world order")
	await mouse_button(button_point, true, false, MOUSE_BUTTON_RIGHT)
	await mouse_button(button_point, false, false, MOUSE_BUTTON_RIGHT)
	check(battle.struct_queue.is_empty(), prefix + "right click actual production button cancels queue")
	check(not soldier.has_move_order and not battle._rmb_panning, prefix + "production cancel does not leak world input")
	# A hoverable child must also give the parent UI ownership.
	button = screen.hud._prod_buttons["GAPOWR"]
	var child: Control = button.get_child(0) as Control
	if is_instance_valid(child):
		var old_filter := child.mouse_filter
		child.mouse_filter = Control.MOUSE_FILTER_PASS
		await move_pointer(child.get_global_rect().get_center())
		var before: Vector2 = battle.camera.position
		await mouse_button(child.get_global_rect().get_center(), true, false, MOUSE_BUTTON_MIDDLE)
		check(not battle._rmb_panning, prefix + "HUD child prevents middle-button world pan")
		await mouse_button(child.get_global_rect().get_center(), false, false, MOUSE_BUTTON_MIDDLE)
		check(battle.camera.position.is_equal_approx(before), prefix + "HUD child leaves camera unchanged")
		child.mouse_filter = old_filter
	var barracks
	for building in battle.buildings:
		if building.side == "ally" and building.building_id == "GAPILE":
			barracks = building
	check(barracks != null, prefix + "real infantry producer exists")
	if barracks != null:
		barracks._buildup_play = -1.0
		barracks.enqueue("E1")
		barracks.enqueue("E1")
		screen.hud.select_prod_tab("infantry")
		screen.hud._refresh_production()
		await get_tree().process_frame
		var queue_tiles: Array = stage.get_tree().get_nodes_in_group("rmb_cancel")
		check(not queue_tiles.is_empty(), prefix + "real queue tile exists")
		if not queue_tiles.is_empty():
			var tile: Control = queue_tiles[0]
			var icon: Control = tile.get_child(0)
			icon.mouse_filter = Control.MOUSE_FILTER_PASS
			screen.hud._prod_scroll.ensure_control_visible(tile)
			await get_tree().process_frame
			var point := icon.get_global_rect().get_center()
			soldier.has_move_order = false
			await move_pointer(point)
			await mouse_button(point, true, false, MOUSE_BUTTON_RIGHT)
			await mouse_button(point, false, false, MOUSE_BUTTON_RIGHT)
			check(barracks.production.size() == 2 and barracks.production_paused(), prefix + "first queue-child right click pauses")
			await mouse_button(point, true, false, MOUSE_BUTTON_RIGHT)
			await mouse_button(point, false, false, MOUSE_BUTTON_RIGHT)
			check(barracks.production.size() == 1 and not soldier.has_move_order,
				prefix + "right click queue child cancels exactly one without world order")
	# Minimap owns its drag even when released outside; the battle never selects.
	battle.select_unit(soldier, false)
	soldier.has_move_order = false
	await move_pointer(map_point)
	await mouse_button(map_point, true)
	check(minimap._dragging and not battle.dragging, prefix + "minimap owns left drag")
	await move_pointer(Vector2(1000, 350), MOUSE_BUTTON_MASK_LEFT, Vector2(1000, 350) - map_point)
	await mouse_button(Vector2(1000, 350), false)
	check(not minimap._dragging and not battle.dragging and battle.selected_units.has(soldier)
		and not soldier.has_move_order, prefix + "minimap drag ends outside without leaking selection or order")
	# A right gesture originating on the world retains drag ownership across UI.
	battle.right_click_scroll = true
	battle.select_unit(soldier, false)
	soldier.has_move_order = false
	await move_pointer(blank)
	await mouse_button(blank, true, false, MOUSE_BUTTON_RIGHT)
	check(not battle._rmb_panning, prefix + "HUD blocks right pan when right-drag setting is enabled")
	await mouse_button(blank, false, false, MOUSE_BUTTON_RIGHT)
	battle._rmb_panning = false
	soldier.has_move_order = false
	await move_pointer(Vector2(900, 350))
	await mouse_button(Vector2(900, 350), true, false, MOUSE_BUTTON_RIGHT)
	check(battle._rmb_panning, prefix + "world right press starts pan")
	await move_pointer(blank, MOUSE_BUTTON_MASK_RIGHT, blank - Vector2(900, 350))
	await mouse_button(blank, false, false, MOUSE_BUTTON_RIGHT)
	check(not battle._rmb_panning and not soldier.has_move_order, prefix + "world pan releases over HUD without issuing order")
	await move_pointer(Vector2(900, 350))
	await mouse_button(Vector2(900, 350), true, false, MOUSE_BUTTON_RIGHT)
	await mouse_button(Vector2(900, 350), false, false, MOUSE_BUTTON_RIGHT)
	check(soldier.has_move_order, prefix + "ordinary world right click still issues order")

func move_pointer(at: Vector2, mask := 0, relative := Vector2.ZERO) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	event.relative = relative
	event.button_mask = mask
	stage.push_input(event, true)
	await get_tree().process_frame
