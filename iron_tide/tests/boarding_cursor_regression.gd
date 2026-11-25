extends "res://tests/cursor_regression.gd"

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
	for ore in get_tree().get_nodes_in_group("resource_nodes"): ore.queue_free()
	get_window().focus_entered.emit()
	var prefix := mode + ": "
	var cursor = battle.command_cursor
	var ifv = battle.spawn_unit("FV", "ally", Vector2(1600, 1600))
	var original_weapon: Dictionary = ifv._active_weapon().duplicate(true)
	var tank = battle.spawn_unit("MTNK", "ally", Vector2(1600, 1750))
	var enemy = battle.spawn_unit("FV", "enemy", Vector2(1750, 1600))
	for actor in [ifv, tank, enemy]: actor.process_mode = Node.PROCESS_MODE_DISABLED
	battle.camera.position = ifv.position
	battle.camera.reset_smoothing()
	battle.camera.force_update_scroll()
	await get_tree().process_frame
	place_art_at(ifv, Vector2(650, 400))
	place_art_at(tank, Vector2(500, 450))
	place_art_at(enemy, Vector2(850, 400))
	await get_tree().process_frame
	check(cursor.metadata.sequences.enter.start == 89 and cursor.textures.enter.size() == 10,
		prefix + "original enter animation frames exported")
	check(cursor.metadata.sequences.enter_blocked.start == 99 and cursor.textures.enter_blocked.size() == 1,
		prefix + "original blocked-entry frame exported")
	for id in ["E1", "GGI", "ENGINEER", "SNIPE"]:
		var passenger = battle.spawn_unit(id, "ally", ifv.position + Vector2(150, 0))
		passenger.process_mode = Node.PROCESS_MODE_DISABLED
		battle.select_unit(passenger, false)
		await point(Vector2(650, 400))
		check(battle._pick_at(battle.get_global_mouse_position()) == ifv, prefix + id + " pointer uses visible IFV sprite")
		check(cursor.state == "enter" and cursor.sprite.visible, prefix + id + " eligible infantry sees enter cursor")
		check(passenger.logistics.boarding == null and not passenger.has_move_order, prefix + id + " hover does not issue boarding")
		var frame: Rect2 = cursor.sprite.texture.region
		cursor.refresh(0.1)
		check(cursor.frame == 1 and cursor.sprite.texture.region != frame, prefix + id + " enter arrow animates")
		check(cursor.sprite.position == Vector2(623, 379), prefix + id + " enter hotspot matches pointer")
		if id == "E1": await photo(mode + "-enter-ifv")
		await mouse_button(Vector2(650, 400), true, false, MOUSE_BUTTON_RIGHT)
		await mouse_button(Vector2(650, 400), false, false, MOUSE_BUTTON_RIGHT)
		check(passenger.logistics.boarding == ifv, prefix + id + " actual right click issues boarding")
		passenger.position = ifv.position + Vector2(25, 0)
		passenger.logistics.tick(0.1)
		check(passenger.embarked_in == ifv and ifv.logistics.passengers == [passenger], prefix + id + " real logistics stows exactly one passenger")
		var extra = battle.spawn_unit("E1", "ally", ifv.position + Vector2(120, 0))
		extra.process_mode = Node.PROCESS_MODE_DISABLED
		battle.select_unit(extra, false)
		await point(Vector2(650, 400))
		check(cursor.state == "enter_blocked", prefix + id + " occupied IFV shows blocked entry")
		if id == "E1": await photo(mode + "-ifv-full")
		await mouse_button(Vector2(650, 400), true, false, MOUSE_BUTTON_RIGHT)
		await mouse_button(Vector2(650, 400), false, false, MOUSE_BUTTON_RIGHT)
		check(extra.logistics.boarding == null and not extra.has_move_order, prefix + id + " rejected boarding does not become accidental ground movement")
		check(battle.boarding_order_status(ifv).reason == "载具已满员", prefix + id + " full reason agrees with command")
		battle.select_unit(ifv, false)
		battle._emit_selection()
		battle._last_click_unit = null
		await point(Vector2(650, 400))
		check(cursor.state == "deploy" and cursor.sprite.visible, prefix + id + " selected occupied IFV advertises mouse unload")
		check(not ifv.logistics.unloading and passenger.embarked_in == ifv, prefix + id + " hover does not unload")
		if id == "E1":
			await photo(mode + "-ifv-unload-hover")
			battle.arm_command("move")
			await point(Vector2(650, 400))
			check(cursor.state == "move" and battle.pointer_deploy_target(ifv.art_center()) == null, prefix + "explicit movement overrides unload")
			battle.arm_command("")
			ifv._stun_timer = 1.0
			check(battle.pointer_deploy_target(ifv.art_center()) == null, prefix + "stunned IFV cannot mouse unload")
			ifv._stun_timer = 0.0
			battle.select_unit(tank, true)
			check(battle.pointer_deploy_target(ifv.art_center()) == null, prefix + "mixed selection does not unload")
			battle.select_unit(ifv, false)
			battle._last_click_unit = ifv
			battle._last_click_ms = Time.get_ticks_msec()
			await gesture(Vector2(650, 400), Vector2(650, 400))
			check(not ifv.logistics.unloading and passenger.embarked_in == ifv, prefix + "rapid second click preserves type selection without unloading")
			battle.select_unit(ifv, false)
			battle._last_click_unit = null
			await gesture(Vector2(650, 400), Vector2(650, 400), true)
			check(not ifv.logistics.unloading and not battle.selected_units.has(ifv), prefix + "Shift click changes selection without unloading")
			battle.select_unit(ifv, false)
			battle._last_click_unit = null
			await gesture(Vector2(650, 400), Vector2(690, 435))
			check(not ifv.logistics.unloading, prefix + "drag from vehicle does not unload")
			battle.select_unit(ifv, false)
			battle._last_click_unit = null
		await gesture(Vector2(650, 400), Vector2(650, 400))
		check(ifv.logistics.unloading and not ifv.has_move_order and battle.selected_units == [ifv], prefix + id + " actual left click requests unload and retains selected IFV")
		ifv.logistics.tick(0.5)
		check(passenger.embarked_in == null and passenger.visible and ifv.logistics.passengers.is_empty(), prefix + id + " unloading clears seat and restores passenger")
		check(ifv._active_weapon() == original_weapon and ifv._ra2_tur.get("key") == "FV_tur", prefix + id + " mouse unload restores original IFV weapon and turret")
		battle._last_click_unit = null
		await point(Vector2(650, 400))
		check(cursor.state == "select", prefix + id + " empty IFV no longer offers unload")
		battle.select_unit(extra, false)
		await point(Vector2(650, 400))
		check(cursor.state == "enter", prefix + id + " cursor updates after unloading")
		battle.clear_selection()
		for actor in [passenger, extra]:
			battle.units.erase(actor)
			actor.free()
	battle.select_unit(tank, false)
	await point(Vector2(650, 400))
	check(cursor.state == "enter_blocked", prefix + "tank cannot enter infantry-only IFV")
	await mouse_button(Vector2(650, 400), true, false, MOUSE_BUTTON_RIGHT)
	await mouse_button(Vector2(650, 400), false, false, MOUSE_BUTTON_RIGHT)
	check(tank.logistics.boarding == null and not tank.has_move_order, prefix + "invalid unit order leaves tank stationary")
	var infantry = battle.spawn_unit("E1", "ally", ifv.position + Vector2(150, 0))
	infantry.process_mode = Node.PROCESS_MODE_DISABLED
	battle.select_unit(infantry, true)
	await point(Vector2(650, 400))
	check(cursor.state == "enter", prefix + "mixed selection offers boarding for eligible member")
	await mouse_button(Vector2(650, 400), true, false, MOUSE_BUTTON_RIGHT)
	await mouse_button(Vector2(650, 400), false, false, MOUSE_BUTTON_RIGHT)
	check(infantry.logistics.boarding == ifv and tank.logistics.boarding == null, prefix + "mixed click boards only eligible member")
	infantry.order_stop()
	battle.arm_command("move")
	await point(Vector2(650, 400))
	check(cursor.state == "move", prefix + "explicit movement mode has priority")
	battle.arm_command("")
	battle.select_unit(ifv, false)
	await point(Vector2(650, 400))
	check(cursor.state == "select", prefix + "selected carrier does not offer boarding itself")
	battle.clear_selection()
	await point(Vector2(650, 400))
	check(cursor.state == "select", prefix + "no passengers selected retains selection cursor")
	battle.select_unit(infantry, false)
	await point(Vector2(850, 400))
	check(cursor.state == "attack" and battle.boarding_order_status(enemy).is_empty(), prefix + "enemy transport remains an attack target")
	await point(Vector2(1500, 450))
	check(not cursor.sprite.visible, prefix + "UI hover restores normal pointer")
	# YR open-topped carrier shares entry/unload pointer routes, not IFV weapons.
	ifv.position = Vector2(100, 100)
	var fortress = battle.spawn_unit("BFRT", "ally", Vector2(1600, 1600))
	var guardian = battle.spawn_unit("GGI", "ally", Vector2(1700, 1600))
	fortress.process_mode = Node.PROCESS_MODE_DISABLED
	guardian.process_mode = Node.PROCESS_MODE_DISABLED
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
	place_art_at(fortress, Vector2(650, 400))
	guardian.position = fortress.position + Vector2(120, 0)
	if battle.fog != null: battle.fog.rebuild()
	battle.select_unit(guardian, false)
	await point(Vector2(650, 400))
	check(cursor.state == "enter", prefix + "fortress offers infantry boarding cursor")
	await mouse_button(Vector2(650, 400), true, false, MOUSE_BUTTON_RIGHT)
	await mouse_button(Vector2(650, 400), false, false, MOUSE_BUTTON_RIGHT)
	check(guardian.logistics.boarding == fortress, prefix + "real right click boards fortress")
	guardian.position = fortress.position + Vector2(0, 20)
	guardian.logistics.tick(0.1)
	battle.select_unit(fortress, false)
	battle._last_click_unit = null
	await point(Vector2(650, 400))
	check(guardian.embarked_in == fortress and cursor.state == "deploy", prefix + "occupied fortress offers unload cursor")
	await photo(mode + "-fortress-unload-hover")
	await mouse_button(Vector2(650, 400), true)
	await mouse_button(Vector2(650, 400), false)
	check(fortress.logistics.unloading, prefix + "real left click requests fortress unload")
	fortress.logistics.tick(0.5)
	check(guardian.embarked_in == null and guardian.visible and fortress.logistics.passengers.is_empty(), prefix + "mouse unload restores fortress passenger")
	screen.free()
	await get_tree().process_frame
