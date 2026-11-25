extends "res://tests/production_reason_regression.gd"

func tap(control: Control, button := MOUSE_BUTTON_LEFT) -> void:
	# Routes and catalogs are scrollable. Expose the real control before
	# injecting a click; never click a clipped off-screen row's old bounds.
	var parent := control.get_parent()
	while parent != null:
		if parent is ScrollContainer:
			parent.ensure_control_visible(control)
			for i in 2:
				await get_tree().process_frame
		parent = parent.get_parent()
	var point := control.get_global_rect().get_center()
	await move_pointer(point)
	await mouse_button(point, true, false, button)
	await mouse_button(point, false, false, button)
	for i in 3:
		await get_tree().process_frame

func exercise_mode(mode: String) -> void:
	BattleRequest.configure_skirmish(mode, {"map_size": 3200, "starting_funds": 20000, "country": "德国"})
	screen = load("res://scenes/battle.tscn").instantiate()
	stage.add_child(screen)
	battle = screen.battle
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	battle.process_mode = Node.PROCESS_MODE_ALWAYS
	battle.set_process(false)
	battle.set_physics_process(false)
	for child in battle.get_children():
		child.process_mode = Node.PROCESS_MODE_DISABLED
	var hud = screen.hud
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	hud.set_process(false)
	GM.infinite_funds = false
	battle.funds = 20000
	Events.battle_message.connect(record_message)
	var soldier = battle.spawn_unit("E1", "ally", Vector2(1000, 1500))
	soldier.process_mode = Node.PROCESS_MODE_DISABLED
	battle.select_unit(soldier, false)
	hud.select_prod_tab("vehicle")
	await refresh_reasons()
	var prefix := mode + ": "
	get_window().focus_entered.emit()
	check(battle.world_input_enabled(), prefix + "focused world input is active during navigation")
	await tap(hud._prod_buttons["SREF"])
	var panel = hud.get("_unlock_panel")
	check(panel != null and panel.visible, prefix + "actual locked card opens persistent unlock navigation")
	if panel == null:
		Events.battle_message.disconnect(record_message)
		screen.free()
		await get_tree().process_frame
		return
	check(hud.prod_tab == "vehicle" and panel.route_buttons.has("GAWEAP") and panel.route_buttons.has("GATECH"),
		prefix + "route keeps original tab until explicit navigation")
	var camera_before: Vector2 = battle.camera.position
	await tap(panel.route_buttons["GATECH"])
	check(hud.prod_tab == "building", prefix + "route click opens building tab")
	check(hud._prod_buttons["GATECH"].guide_highlight, prefix + "target cameo highlighted even when locked")
	var viewport_rect: Rect2 = hud._prod_scroll.get_global_rect()
	check(viewport_rect.encloses(hud._prod_buttons["GATECH"].get_global_rect()),
		prefix + "target scrolled fully into view", str(viewport_rect))
	check(battle.funds == 20000 and battle.struct_queue.is_empty() and battle.armed_build.is_empty(),
		prefix + "navigation never spends, queues or arms placement")
	check(battle.selected_units.has(soldier) and not soldier.has_move_order and not battle.dragging
		and battle.camera.position.is_equal_approx(camera_before), prefix + "route click does not leak world commands")
	check(panel.visible and hud._unlock_source == "SREF", prefix + "original goal persists across navigation")
	await tap(hud._prod_buttons["GATECH"])
	check(hud._unlock_source == "SREF", prefix + "inspecting a locked prerequisite preserves original goal")
	await RenderingServer.frame_post_draw
	stage.get_texture().get_image().save_png(output_dir.path_join(mode + "-located-lab.png"))
	await tap(panel.back_button)
	check(hud.prod_tab == "vehicle" and hud._prod_buttons["SREF"].guide_highlight,
		prefix + "return button restores original unit and highlight")
	var factory = battle._place_building("GAWEAP", "ally", Vector2(1200, 1800), true)
	factory.process_mode = Node.PROCESS_MODE_DISABLED
	factory._buildup_play = -1.0
	await refresh_reasons()
	check(not panel.route_buttons.has("GAWEAP") and panel.route_buttons.has("GAAIRC"),
		prefix + "completed prerequisite removed from route")
	battle.struct_ready["GAAIRC"] = 1
	await refresh_reasons()
	check("待放置" in panel.route_buttons["GAAIRC"].text, prefix + "ready prerequisite has placement status")
	await tap(panel.route_buttons["GAAIRC"])
	check(battle.struct_ready.get("GAAIRC") == 1 and battle.armed_build.is_empty(),
		prefix + "ready item navigation preserves paid inventory and placement mode")
	await tap(panel.back_button)
	battle.struct_ready.erase("GAAIRC")
	var radar = battle._place_building("GAAIRC", "ally", Vector2(1500, 1800), false)
	radar.process_mode = Node.PROCESS_MODE_DISABLED
	await refresh_reasons()
	check("施工中" in panel.route_buttons["GAAIRC"].text, prefix + "construction state refreshes route")
	radar.under_construction = false
	radar._buildup_play = -1.0
	var lab = battle._place_building("GATECH", "ally", Vector2(1800, 1800), true)
	lab.process_mode = Node.PROCESS_MODE_DISABLED
	lab._buildup_play = -1.0
	await refresh_reasons()
	check(panel.route_buttons.is_empty() and "科技条件已满足" in panel.message.text,
		prefix + "completed technology offers return without automatic production")
	await tap(panel.back_button)
	check(not hud._prod_buttons["SREF"].disabled and factory.production.is_empty(),
		prefix + "unlocked return does not produce automatically")
	lab._die()
	await get_tree().process_frame
	await refresh_reasons()
	check(panel.route_buttons.has("GATECH"), prefix + "destroyed prerequisite reappears")
	# A manual tab switch before deferred scrolling must not jump back.
	hud._locate_unlock_building("GATECH")
	hud.select_prod_tab("infantry")
	for i in 3:
		await get_tree().process_frame
	check(hud.prod_tab == "infantry" and hud._unlock_focus.is_empty(), prefix + "manual tab interrupts navigation highlight")
	await tap(panel.close_button)
	check(not panel.visible and hud._unlock_source.is_empty(), prefix + "close clears pinned route")
	check(not soldier.has_move_order and not battle.dragging, prefix + "close click stays owned by HUD")
	await tap(hud._prod_buttons["SNIPE"])
	if mode == MatchRules.RA2:
		check(panel.visible and "英国" in panel.message.text and panel.route_buttons.is_empty(),
			prefix + "country restriction identifies eligible country without false route")
		await tap(panel.close_button)
	else:
		check(not panel.visible, prefix + "available extended sniper uses ordinary production instead of guide")
	hud.select_prod_tab("vehicle")
	await refresh_reasons()
	await tap(hud._prod_buttons["SREF"])
	check(panel.visible and hud._unlock_source == "SREF", prefix + "disabled mouse activation opens route")
	var route_button: Button = panel.route_buttons["GATECH"]
	await refresh_reasons()
	check(panel.route_buttons["GATECH"] == route_button, prefix + "unchanged route refresh retains button identity")
	# A long recovery route remains bounded while the catalog retains space.
	for building in battle.buildings.duplicate():
		if is_instance_valid(building) and building.side == "ally" and not building.is_dead():
			building._die()
	await get_tree().process_frame
	stage.size = Vector2i(1280, 720)
	for i in 4:
		await get_tree().process_frame
	await refresh_reasons()
	check(panel.route_buttons.has("GACNST") and panel.route_buttons["GACNST"].disabled,
		prefix + "unbuildable construction yard has no misleading navigation")
	check(panel.size.y <= 250 and hud._prod_scroll.size.y >= 80,
		prefix + "small viewport keeps route bounded and catalog usable", [str(panel.size), str(hud._prod_scroll.size)])
	var bounds := Rect2(Vector2.ZERO, Vector2(stage.size))
	check(bounds.encloses(panel.get_global_rect()) and bounds.encloses(hud._prod_scroll.get_global_rect()),
		prefix + "route and catalog stay inside small viewport")
	# Scroll the route list to an item below the fold, then use its real button.
	panel._scroll.ensure_control_visible(panel.route_buttons["GATECH"])
	for i in 3:
		await get_tree().process_frame
	await tap(panel.route_buttons["GATECH"])
	check(hud._prod_scroll.get_global_rect().encloses(hud._prod_buttons["GATECH"].get_global_rect()),
		prefix + "small viewport navigation scrolls target into view")
	await RenderingServer.frame_post_draw
	stage.get_texture().get_image().save_png(output_dir.path_join(mode + "-unlock-route.png"))
	var world_point := Vector2(700, 320)
	await move_pointer(world_point)
	await mouse_button(world_point, true, false, MOUSE_BUTTON_RIGHT)
	await mouse_button(world_point, false, false, MOUSE_BUTTON_RIGHT)
	check(soldier.has_move_order, prefix + "ordinary world input remains functional after navigation")
	Events.battle_message.disconnect(record_message)
	screen.free()
	await get_tree().process_frame
	stage.size = Vector2i(1600, 900)
