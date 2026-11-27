extends Node

const Controls = preload("res://scripts/ui/battle_speed_controls.gd")
var passed := 0
var failed := 0

func _ready() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("CodexIronTideValidation/") or not ProjectSettings.get_setting("application/config/use_custom_user_dir", false):
		push_error("Use an isolated custom user directory.")
		get_tree().quit(2)
		return
	_run.call_deferred()

func _run() -> void:
	var all_speeds := [1.0, 1.25, 1.5, 2.0, 3.0]
	check(DisplayPreferences.battle_speeds == all_speeds, "clean settings enable all five speeds")
	var stage := SubViewport.new()
	stage.size = Vector2i(1280, 720)
	add_child(stage)
	var settings = load("res://scenes/settings.tscn").instantiate()
	stage.add_child(settings)
	await get_tree().process_frame
	await get_tree().process_frame
	var menu = settings.find_child("BattleSpeedControls", true, false)
	check(menu != null and menu.get_script() == Controls and menu.toggles.size() == 5, "main menu shows all five controls")
	if menu == null:
		get_tree().quit(1)
		return
	var back = settings.find_child("SettingsBack", true, false)
	var scroll = settings.find_child("SettingsScroll", true, false)
	scroll.ensure_control_visible(back)
	await get_tree().process_frame
	check(Rect2(Vector2.ZERO, Vector2(stage.size)).encloses(back.get_global_rect()), "main menu can scroll to return button at 1280×720")
	for speed in [1.0, 1.5, 3.0]:
		menu.toggles[speed].button_pressed = false
	check(DisplayPreferences.battle_speeds == [1.25, 2.0], "main menu toggles update sorted selection")
	check(DisplayPreferences.save_error == OK, "settings written without error")
	DisplayPreferences.reload()
	check(DisplayPreferences.battle_speeds == [1.25, 2.0], "saved fractional subset reloads")
	check(Engine.time_scale == 1.0, "main menu preference changes do not change engine scale")
	settings.free()

	BattleRequest.configure_skirmish(MatchRules.RA2, {"map_size": 3200, "starting_funds": 7600})
	var screen = load("res://scenes/battle.tscn").instantiate()
	stage.add_child(screen)
	var hud = screen.hud
	var panel = hud.settings_panel
	var controls = panel.find_child("BattleSpeedControls", true, false)
	check(controls != null and controls.toggles[1.25].button_pressed and not controls.toggles[1.0].button_pressed, "battle settings use the saved checks")
	check_speed(hud, 1.25, "battle starts at lowest selected speed")
	hud.speed_btn.pressed.emit()
	check_speed(hud, 2.0, "HUD button skips unchecked 1.5×")
	var key := InputEventKey.new()
	key.keycode = KEY_TAB
	key.pressed = true
	stage.push_input(key, true)
	check_speed(hud, 1.25, "Tab wraps to 1.25×")
	panel.show()
	await get_tree().process_frame
	await get_tree().process_frame
	check(Rect2(Vector2.ZERO, Vector2(stage.size)).encloses(controls.get_global_rect()), "battle speed controls fit at 1280×720")
	stage.push_input(key, true)
	check_speed(hud, 1.25, "Tab can navigate the open settings without changing speed")
	controls.toggles[1.25].button_pressed = false
	check_speed(hud, 2.0, "unchecking current speed switches immediately")
	check(controls.toggles[2.0].disabled, "last selected checkbox is protected")
	DisplayPreferences.set_battle_speed_enabled(2.0, false)
	check(DisplayPreferences.battle_speeds == [2.0], "last selected speed cannot be removed by setter")
	hud.speed_btn.pressed.emit()
	check_speed(hud, 2.0, "cycling with one speed leaves it unchanged")
	controls.toggles[1.5].button_pressed = true
	check_speed(hud, 2.0, "enabling another speed keeps the current speed")
	hud.speed_btn.pressed.emit()
	check_speed(hud, 1.5, "HUD shows fractional 1.5× without truncation")
	screen.free()
	check(Engine.time_scale == 1.0 and GM.fast_forward == 1.0, "leaving battle restores menu time")
	var malformed := ConfigFile.new()
	malformed.set_value("battle", "speeds", ["1.25", -2, 5])
	check(malformed.save(DisplayPreferences.SETTINGS_PATH) == OK, "write corrupt fixture to isolated path")
	DisplayPreferences.reload()
	check(DisplayPreferences.battle_speeds == all_speeds, "invalid settings fall back to defaults")
	print("BattleSpeedSettings: %d passed, %d failed" % [passed, failed])
	get_tree().quit(0 if failed == 0 else 1)

func check_speed(hud, expected: float, label: String) -> void:
	check(GM.fast_forward == expected and is_equal_approx(Engine.time_scale, BattleClock.NORMAL_SCALE * expected)
		and hud.speed_btn.text == "倍速 ×" + str(expected).trim_suffix(".0"), label)

func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		print("FAIL: ", label)
