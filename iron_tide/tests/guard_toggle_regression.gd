extends "res://tests/input_ownership_regression.gd"

func click_guard() -> void:
	refresh_commands()
	await get_tree().process_frame
	var button: Button = screen.hud.cmd_buttons.guard
	var at := button.get_global_rect().get_center()
	await move_pointer(at)
	await mouse_button(at, true)
	await mouse_button(at, false)

func refresh_commands() -> void:
	screen.hud._refresh_selection()
	screen.hud._on_command_mode(str(battle.command_mode))

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
	get_window().focus_entered.emit()
	await get_tree().process_frame
	var prefix := mode + ": "
	var gi = battle.spawn_unit("E1", "ally", Vector2(1600, 1600))
	var ggi = battle.spawn_unit("GGI", "ally", Vector2(1660, 1600))
	var tank = battle.spawn_unit("MTNK", "ally", Vector2(1700, 1600))
	for unit in [gi, ggi, tank]: unit.process_mode = Node.PROCESS_MODE_DISABLED
	gi.set_deployed(true)
	ggi.set_deployed(true)
	battle.select_unit(gi, false)
	await get_tree().process_frame
	refresh_commands()
	check(battle.guard_selection_state() == 0 and not screen.hud.cmd_buttons.guard.button_pressed, prefix + "new deployed GI starts with guard off")
	await click_guard()
	check(gi.hold_position and gi.fire_stance == "free" and screen.hud.cmd_buttons.guard.button_pressed, prefix + "actual mouse click enables guard and highlights button")
	check("已开启" in screen.hud.cmd_buttons.guard.tooltip_text, prefix + "tooltip reports enabled state and next action")
	await click_guard()
	check(not gi.hold_position and gi.fire_stance == "defend" and not screen.hud.cmd_buttons.guard.button_pressed, prefix + "second mouse click disables guard and restores defense")
	check(gi._deployed and "已关闭" in screen.hud.cmd_buttons.guard.tooltip_text, prefix + "guard off preserves deployment and updates tooltip")
	await key(KEY_G)
	check(gi.hold_position and gi.fire_stance == "free", prefix + "G enables guard through real HUD input")
	await key(KEY_G)
	check(not gi.hold_position and gi.fire_stance == "defend" and gi._deployed, prefix + "second G disables without standing up")
	gi.order_guard()
	ggi.set_fire_stance("return")
	tank.set_fire_stance("none")
	battle.select_unit(ggi, true)
	battle.select_unit(tank, true)
	await get_tree().process_frame
	refresh_commands()
	check(battle.guard_selection_state() == 1 and "部分开启" in screen.hud.cmd_buttons.guard.tooltip_text, prefix + "mixed selection is explicitly reported")
	await click_guard()
	check([gi,ggi,tank].all(func(u): return u.hold_position and u.fire_stance == "free"), prefix + "mixed selection click enables all instead of individually inverting")
	await key(KEY_G)
	check([gi,ggi,tank].all(func(u): return not u.hold_position and u.fire_stance == "defend"), prefix + "all-on selection G disables all")
	check(gi._deployed and ggi._deployed, prefix + "both infantry deployment types preserved")
	await key(KEY_G)
	await key(KEY_S)
	check(battle.guard_selection_state() == 0 and not screen.hud.cmd_buttons.guard.button_pressed, prefix + "S clears guard and updates real button")
	battle.select_unit(tank, false)
	tank.order_move(Vector2(1800, 1800))
	await get_tree().process_frame
	await click_guard()
	check(not tank.has_move_order and tank.hold_position, prefix + "enabling guard still stops an existing move order")
	await click_guard()
	check(not tank.has_move_order and tank.fire_stance == "defend", prefix + "disabling does not resurrect obsolete move orders")
	tank.set_fire_stance("none")
	refresh_commands()
	await click_guard()
	check(tank.fire_stance == "free" and tank.hold_position, prefix + "explicit guard still overrides cease fire")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		stage.get_texture().get_image().save_png(output_dir.path_join(mode + "-guard-on.png"))
	await click_guard()
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		stage.get_texture().get_image().save_png(output_dir.path_join(mode + "-guard-off.png"))
	battle.clear_selection()
	check(battle.guard_selection_state() == -1, prefix + "empty selection has no guard state")
	battle.guard_selected()
	check(tank.fire_stance == "defend" and not tank.hold_position, prefix + "empty selection cannot change previous unit")
	screen.free()
	await get_tree().process_frame
