extends "res://tests/automatic_defense_regression.gd"
const Keys = preload("res://scripts/ui/battle_hotkeys.gd")
const Stances = preload("res://scripts/ui/combat_stance_bar.gd")

func _ready() -> void:
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2); return
	for mode in [MatchRules.RA2, MatchRules.EXTENDED]:
		await exercise_stances(mode)
	FileAccess.open(output_dir.path_join("result.json"), FileAccess.WRITE).store_string(JSON.stringify({"checks": checks, "failed": failed}, "  "))
	get_tree().quit(0 if failed == 0 else 1)

func press(key: int) -> void:
	var event := InputEventKey.new()
	event.keycode = key; event.pressed = true
	screen.hud._input(event)

func exercise_stances(mode: String) -> void:
	open_arena(mode)
	get_tree().paused = false; battle.paused = false
	get_window().focus_entered.emit()
	Keys.save(Keys.defaults())
	var tank = battle.spawn_unit("MTNK", "ally", Vector2(1200, 1200))
	var gi = battle.spawn_unit("E1", "ally", Vector2(1150, 1200))
	var enemy = battle.spawn_unit("HTNK", "enemy", Vector2(1600, 1200))
	for unit in [tank, gi, enemy]:
		unit.set_physics_process(false); unit.set_process(false); unit.order_stop()
	battle.select_unit(tank, false); battle.select_unit(gi, true)
	var hud = screen.hud
	var buttons: Dictionary = hud._unit_command_buttons
	check(not buttons.has("stance") and Stances.IDS.all(func(id): return buttons.has(id)), mode + " five direct stances replace hidden cycle")
	for id: String in Stances.IDS:
		check(buttons[id].get_child(0) is TextureRect and buttons[id].get_child(0).texture != null and buttons[id].get_child(1).text == Stances.SHORT[id], id + " native icon plus readable name")
	press(KEY_V)
	check(battle.selected_fire_stance() == "free" and buttons.aggressive.button_pressed, "V enables and highlights aggressive")
	press(KEY_V)
	check(battle.selected_fire_stance() == "defend" and not buttons.aggressive.button_pressed and buttons.defend.button_pressed, "second V disables and highlights defense")
	buttons.aggressive.pressed.emit()
	buttons.aggressive.pressed.emit()
	check(battle.selected_fire_stance() == "defend", "icon toggles just like hotkey")
	tank.order_guard(); gi.set_fire_stance("none")
	hud._sync_unit_commands()
	check(hud._stance_bar.status.text.contains("混合") and not buttons.guard.button_pressed and buttons.guard.tooltip_text.contains("部分开启"), "mixed selection has explicit status without false active highlight")
	press(KEY_V)
	check(battle.selected_fire_stance() == "free" and not tank.hold_position, "mixed selection enters aggressive together")
	gi.set_deployed(true, false)
	press(KEY_V)
	check(gi.is_deployed() and battle.selected_fire_stance() == "defend", "closing aggressive preserves deployment")
	tank.order_move(Vector2(1700, 1400))
	var destination: Vector2 = tank.move_target
	press(KEY_V); press(KEY_V)
	check(tank.has_move_order and tank.move_target == destination, "V on/off preserves explicit movement")
	tank.order_target(enemy, false, false)
	press(KEY_V); press(KEY_V)
	check(tank.attack_ordered and tank.attack_target == enemy, "V on/off preserves explicit target order")
	tank.order_stop(); gi.order_stop()
	tank._return_timer = 0
	# Leaving aggressive must discard a retained automatic burst, not keep pursuing it.
	tank.set_fire_stance("free"); gi.set_fire_stance("free")
	tank.attack_target = enemy; tank._burst_target = enemy; tank._burst_left = 2
	press(KEY_V)
	check(tank.fire_stance == "defend" and tank._burst_left == 0 and tank.attack_target == null, "V off cancels automatic burst and distant focus")
	for id in ["return_fire", "hold_fire", "defend", "guard"]:
		buttons[id].pressed.emit()
		check(battle.selected_fire_stance() == Stances.STATES[id] and buttons[id].button_pressed, id + " directly selects and highlights")
		check(Stances.IDS.filter(func(other): return buttons[other].button_pressed).size() == 1, id + " exactly one stance highlighted")
	buttons.guard.pressed.emit()
	check(battle.selected_fire_stance() == "defend", "guard icon closes to defense")
	for id in ["aggressive", "defend", "guard", "return_fire", "hold_fire"]:
		battle.paused = true
		buttons[id].pressed.emit()
		battle.paused = false
		check(battle.selected_fire_stance() == "defend" and buttons.defend.button_pressed, id + " paused command cannot change state")
	buttons.reverse_attack.pressed.emit()
	check(battle.command_mode == "reverse_attack" and buttons.reverse_attack.button_pressed and hud.cmd_hint_label.text.contains("后退"), "D command has named icon and destination hint")
	press(KEY_ESCAPE)
	check(battle.command_mode.is_empty() and not buttons.reverse_attack.button_pressed, "Escape clears targeting highlight")
	buttons.attack_move.pressed.emit()
	check(hud.cmd_hint_label.text.contains("途中遇敌"), "attack move has explicit targeting instructions")
	press(KEY_ESCAPE)
	buttons.follow.pressed.emit()
	check(buttons.follow.button_pressed and battle.follow_target == tank, "follow highlight reflects persistent camera mode")
	buttons.follow.pressed.emit()
	check(not buttons.follow.button_pressed, "second follow clears highlight")
	Keys.assign("aggressive", KEY_B)
	hud._refresh_hotkey_labels(); hud._sync_unit_commands()
	check(buttons.aggressive.get_meta("hotkey_label").text == "B" and buttons.aggressive.tooltip_text.contains("再按 B"), "rebound key updates icon and explanation")
	press(KEY_B); press(KEY_B)
	check(battle.selected_fire_stance() == "defend", "rebound key also toggles off")
	Keys.save(Keys.defaults())
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	check(hud.sel_panel.get_global_rect().end.y <= get_viewport().get_visible_rect().end.y, "command panel stays above bottom edge")
	check(hud.ability_panel.get_global_rect().end.y <= hud.sel_panel.get_global_rect().position.y, "skills stay above expanded command panel")
	check(hud.buff_panel.get_global_rect().end.y <= hud.ability_panel.get_global_rect().position.y, "buffs stay above skills")
	for id in buttons:
		var button: Button = buttons[id]
		check(button.get_global_rect().size.x >= 48, id + " larger click target")
		check(hud.sel_panel.get_global_rect().encloses(button.get_global_rect()), id + " button is fully inside visible command panel")
		if id not in Stances.IDS: check(button.get_node("CommandCaption").text.length() > 0, id + " always shows name")
	check(buttons.aggressive.get_global_rect().end.x <= hud._unit_command_box.get_global_rect().end.x + 1 and buttons.hold_fire.get_global_rect().end.x <= hud._unit_command_box.get_global_rect().end.x + 1, "stance row fits command panel")
	battle.clear_selection(); hud._sync_unit_commands()
	check(Stances.IDS.all(func(id): return buttons[id].disabled), "no units disables stance buttons")
	await finish()
