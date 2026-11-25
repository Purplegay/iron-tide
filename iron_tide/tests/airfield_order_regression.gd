extends "res://tests/cursor_regression.gd"

func plane_at(id: String, airport):
	var plane = battle.spawn_unit(id, "ally", airport.position + Vector2(-400, 0))
	plane.process_mode = Node.PROCESS_MODE_DISABLED
	plane.logistics.assign_producer(airport)
	return plane

func exercise_mode(mode: String) -> void:
	BattleRequest.configure_skirmish(mode, {"map_size": 3200, "starting_funds": 8000, "fog_of_war": false})
	screen = load("res://scenes/battle.tscn").instantiate()
	stage.add_child(screen)
	battle = screen.battle
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	battle.process_mode = Node.PROCESS_MODE_ALWAYS
	battle.set_process(false)
	battle.set_physics_process(false)
	for child in battle.get_children(): child.process_mode = Node.PROCESS_MODE_DISABLED
	for actor in battle.units + battle.buildings: actor.free()
	battle.units.clear()
	battle.buildings.clear()
	for group in ["resource_nodes", "obstacles"]:
		for node in get_tree().get_nodes_in_group(group): node.free()
	if battle.fog != null: battle.fog.free(); battle.fog = null
	var airport = battle._place_building("GAAIRC", "ally", Vector2(1600,1600), true)
	var old = battle._place_building("GAAIRC", "ally", Vector2(2200,1600), true)
	for b in [airport, old]: b.process_mode = Node.PROCESS_MODE_DISABLED; b._buildup_play = -1.0
	battle.camera.position = airport.position
	battle.camera.zoom = Iso.cam_zoom(1.0)
	battle.camera.reset_smoothing()
	battle.camera.force_update_scroll()
	get_window().focus_entered.emit()
	var prefix := mode + ": "
	for id in ["ORCA", "BEAG"]:
		var plane = plane_at(id, old)
		plane.order_move(old.position + Vector2(-100,0))
		battle.select_unit(plane, false)
		await get_tree().process_frame
		if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
		var point_at: Vector2 = stage.get_canvas_transform() * airport.art_center()
		await point(point_at)
		check(battle.command_cursor.state == "enter", prefix + id + " original landing cursor")
		check(plane.logistics.home == old and plane.logistics.air_state == "flying", prefix + id + " hover never changes reservation")
		await mouse_button(point_at, true, false, MOUSE_BUTTON_RIGHT)
		await mouse_button(point_at, false, false, MOUSE_BUTTON_RIGHT)
		check(plane.logistics.home == airport and plane.logistics.air_state == "returning", prefix + id + " actual right click chooses requested airport even with full ammo")
		check(not plane.attack_ordered and not plane.has_move_order and plane.logistics.resume_target == null, prefix + id + " return cancels old sortie")
		var slot: int = plane.logistics.dock_slot
		check(plane.logistics.request_return(airport) and plane.logistics.dock_slot == slot, prefix + id + " repeated return retains own slot")
		plane.position = plane.logistics.dock_destination()
		plane.logistics.air_lift = 0.0
		plane.logistics.tick_return(0.1)
		check(plane.logistics.air_state == "parked" and not plane.attack_ordered, prefix + id + " touchdown parks without new attack")
		var residents: Array = []
		for i in 3: residents.append(plane_at("ORCA", airport))
		var extra = plane_at(id, old)
		extra.order_move(old.position + Vector2(-100,0))
		battle.select_unit(extra, false)
		await point(point_at)
		check(battle.command_cursor.state == "enter_blocked", prefix + id + " full airport blocked cursor")
		await mouse_button(point_at, true, false, MOUSE_BUTTON_RIGHT)
		await mouse_button(point_at, false, false, MOUSE_BUTTON_RIGHT)
		check(extra.logistics.home == old and extra.logistics.air_state == "flying" and extra.has_move_order, prefix + id + " rejection preserves existing order and home")
		check(plane.logistics.return_slot(airport) == slot, prefix + id + " own reserved pad allowed when all pads occupied")
		var freed = residents.pop_back()
		battle.units.erase(freed); freed.free()
		var second = plane_at(id, old)
		battle.select_unit(second, true)
		battle._issue_order(airport.art_center())
		check(extra.logistics.home == airport and second.logistics.home == old, prefix + id + " multi-select reserves final pad once")
		airport.under_construction = true
		check(second.logistics.return_slot(airport) == -1 and not second.logistics.request_return(airport), prefix + id + " unfinished airport rejected")
		airport.under_construction = false
		airport.side = "enemy"
		check(second.logistics.return_slot(airport) == -1 and battle.airfield_order_status(airport).is_empty(), prefix + id + " hostile airport cannot receive friendly plane")
		airport.side = "ally"
		for unit in [plane, extra, second] + residents:
			battle.units.erase(unit); unit.free()
	var flyer = battle.spawn_unit("JUMPJET", "ally", Vector2(1500,1600))
	flyer.process_mode = Node.PROCESS_MODE_DISABLED
	battle.select_unit(flyer, false)
	check(battle.airfield_order_status(airport).is_empty() and not flyer.logistics.request_return(airport), prefix + "flying infantry do not receive airport orders")
	screen.free()
	await get_tree().process_frame
