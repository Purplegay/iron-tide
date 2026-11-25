extends "res://tests/input_ownership_regression.gd"

func refresh() -> void:
	screen.hud._refresh_production()
	for i in 3:
		await get_tree().process_frame

func drain(producer) -> void:
	while not producer.production.is_empty():
		producer.cancel_at(producer.production.size() - 1)

func exercise_mode(mode: String) -> void:
	BattleRequest.configure_skirmish(mode, {"map_size": 3200, "starting_funds": 10000})
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
	var prefix := mode + ": "
	var factory
	for b in battle.buildings:
		if b.side == "ally" and b.building_id == "GAPILE":
			factory = b
	check(factory != null, prefix + "actual barracks fixture")
	if factory == null:
		screen.free()
		return
	factory._buildup_play = -1.0
	battle.power_low = false
	battle.funds = 10000
	battle.select_building(factory)
	battle._emit_selection()
	hud.select_prod_tab("infantry")
	await refresh()
	var first_at: Vector2 = hud._prod_buttons["E1"].get_global_rect().get_center()
	await move_pointer(first_at)
	await mouse_button(first_at, true)
	await mouse_button(first_at, false)
	check(factory.production.size() == 1, prefix + "mouse click queues exactly one", {
		"queue": factory.production.duplicate(), "producer_matches": hud._active_producer() == factory,
		"disabled": hud._prod_buttons["E1"].disabled, "reason": hud._catalog_block_reason("E1"),
		"click": str(first_at), "rect_after": str(hud._prod_buttons["E1"].get_global_rect()),
		"hover": str(stage.gui_get_hovered_control()), "focused": battle._window_focused})
	drain(factory)
	await key(KEY_F1)
	check(factory.production.is_empty(), prefix + "F1 no longer queues units")
	await key(KEY_F1, true)
	check(factory.production.is_empty(), prefix + "Shift F1 no longer queues units")
	drain(factory)
	await refresh()
	var button: Button = hud._prod_buttons["E1"]
	var at := button.get_global_rect().get_center()
	await move_pointer(at)
	await mouse_button(at, true)
	hud._tick_prod_hold(hud.HOLD_TIME + 0.1)
	await mouse_button(at, false)
	check(factory.production.size() == 5, prefix + "long press release adds exactly five")
	await move_pointer(at)
	await mouse_button(at, true)
	await mouse_button(at, false)
	check(factory.production.size() == 6, prefix + "mouse click works immediately after long press")
	await mouse_button(at, true)
	hud._tick_prod_hold(hud.HOLD_TIME + 0.1)
	await mouse_button(at, false)
	check(factory.production.size() == mini(11, factory.queue_capacity()), prefix + "batch respects current factory capacity")
	drain(factory)
	factory.enqueue("E1")
	factory.enqueue("DOG")
	factory.enqueue("E1")
	var duration: float = GameData.ra2_build_time(GameData.get_unit("E1")) / factory.build_speed
	var money_before: float = battle.funds
	factory._process(duration * 0.25 / factory.production_work_rate("E1"))
	await refresh()
	var wipe = hud._prod_wipes["E1"]
	check(wipe.badge == 2 and is_equal_approx(wipe.frac, 0.25),
		prefix + "separated same-type runs sum badge and retain head progress")
	var money_after_payment: float = battle.funds
	hud._prod_scroll.ensure_control_visible(hud._queue_host.get_node("queue_strip"))
	await get_tree().process_frame
	var tail_at: Vector2 = hud._queue_host.get_node("queue_strip").get_child(2).get_global_rect().get_center()
	await move_pointer(tail_at)
	await mouse_button(tail_at, true, false, MOUSE_BUTTON_RIGHT)
	await mouse_button(tail_at, false, false, MOUSE_BUTTON_RIGHT)
	check(battle.funds == money_after_payment and is_equal_approx(factory.queue_progress(), 0.25),
		prefix + "cancel unstarted tail neither refunds nor resets current job")
	check(factory.production == ["E1", "DOG"], prefix + "right-click tail removes only pointed queue item")
	await refresh()
	var head_at: Vector2 = hud._queue_host.get_node("queue_strip").get_child(0).get_global_rect().get_center()
	await move_pointer(head_at)
	await mouse_button(head_at, true, false, MOUSE_BUTTON_RIGHT)
	await mouse_button(head_at, false, false, MOUSE_BUTTON_RIGHT)
	check(factory.production_paused() and battle.funds == money_after_payment, prefix + "first head RMB pauses without refund")
	head_at = hud._queue_host.get_node("queue_strip").get_child(0).get_global_rect().get_center()
	await mouse_button(head_at, true, false, MOUSE_BUTTON_RIGHT)
	await mouse_button(head_at, false, false, MOUSE_BUTTON_RIGHT)
	check(is_equal_approx(battle.funds, money_before) and factory.progress == 0.0,
		prefix + "cancel current job refunds only actual payment")
	check(factory.production == ["DOG"], prefix + "right-click head preserves next unit")
	drain(factory)
	# Long press cancelled outside the button must not swallow the next mouse click.
	await refresh()
	hud._prod_scroll.ensure_control_visible(hud._prod_buttons["E1"])
	await get_tree().process_frame
	at = hud._prod_buttons["E1"].get_global_rect().get_center()
	await move_pointer(at)
	await mouse_button(at, true)
	hud._tick_prod_hold(hud.HOLD_TIME + 0.1)
	await move_pointer(Vector2(800, 350), MOUSE_BUTTON_MASK_LEFT)
	await mouse_button(Vector2(800, 350), false)
	var queued: int = factory.production.size()
	await move_pointer(at)
	await mouse_button(at, true)
	await mouse_button(at, false)
	check(factory.production.size() == queued + 1, prefix + "outside release does not swallow next mouse click")
	drain(factory)
	await refresh()
	hud._prod_scroll.ensure_control_visible(hud._prod_buttons["E1"])
	await get_tree().process_frame
	at = hud._prod_buttons["E1"].get_global_rect().get_center()
	await move_pointer(at)
	await mouse_button(at, true)
	hud.select_prod_tab("building")
	hud._tick_prod_hold(hud.HOLD_TIME + 0.1)
	await mouse_button(at, false)
	check(factory.production.is_empty(), prefix + "changing tab cancels pending long press")
	drain(factory)
	# Nearby factories must not steal each other's rally orders.
	var other = battle._place_building("GAPILE", "ally", factory.global_position, true)
	other.process_mode = Node.PROCESS_MODE_DISABLED
	other._buildup_play = -1.0
	var goal_a := Vector2(1400, 1600)
	var goal_b := Vector2(1800, 1600)
	battle._set_rally(factory, goal_a)
	battle._set_rally(other, goal_b)
	other.enqueue("E1")
	other._process(GameData.ra2_build_time(GameData.get_unit("E1")) / other.build_speed)
	var produced = battle.units[-1]
	produced.process_mode = Node.PROCESS_MODE_DISABLED
	check(produced.has_move_order and produced.move_target.is_equal_approx(goal_b),
		prefix + "actual completed production uses its own factory rally", str(produced.move_target))
	check(produced._path_pts.size() >= 2, prefix + "rally order enters actual pathfinding")
	var unrelated = battle.spawn_unit("E1", "ally", factory.global_position)
	unrelated.process_mode = Node.PROCESS_MODE_DISABLED
	check(not unrelated.has_move_order, prefix + "non-production spawn does not inherit nearby rally")
	battle.select_building(other)
	battle._emit_selection()
	battle._order_marks.clear()
	battle.camera.position = goal_b
	battle.camera.zoom = Vector2(2, 1)
	battle.camera.reset_smoothing()
	battle.camera.force_update_scroll()
	battle.hp_overlay.queue_redraw()
	battle.queue_redraw()
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var image := stage.get_texture().get_image()
		var point: Vector2 = stage.get_canvas_transform() * goal_b
		var cyan := 0
		for x in range(int(point.x), int(point.x) + 20):
			for y in range(int(point.y) - 30, int(point.y) - 10):
				if x < 0 or y < 0 or x >= image.get_width() or y >= image.get_height():
					continue
				var c := image.get_pixel(x, y)
				if c.g > 0.7 and c.b > 0.8 and c.r > 0.35 and c.r < 0.75:
					cyan += 1
		check(cyan >= 30, prefix + "persistent rally flag renders above world", cyan)
		image.save_png(output_dir.path_join(mode + "-rally.png"))
	battle._issue_order(other.global_position)
	check(battle.rally_for(other) == Vector2.INF and battle.rally_for(factory) == goal_a,
		prefix + "right-click own factory clears only its rally")
	battle._set_rally(other, goal_b)
	var dead_id: int = other.get_instance_id()
	other._die()
	await get_tree().process_frame
	check(not battle.rally_points.has(dead_id), prefix + "destroyed factory removes stale rally entry")
	screen.free()
	await get_tree().process_frame
