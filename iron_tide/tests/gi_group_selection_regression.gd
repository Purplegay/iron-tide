extends "res://tests/base_recovery_regression.gd"

var army: Array = []

func sample(label: String) -> void:
	for i in 12:
		await get_tree().process_frame
	var times := PackedFloat64Array()
	for i in 50:
		var tick := Time.get_ticks_usec()
		await get_tree().process_frame
		times.append((Time.get_ticks_usec() - tick) / 1000.0)
	times.sort()
	print("GI ", label, " median=", times[25], " p95=", times[47])

func box_army() -> void:
	var projection := get_viewport().get_canvas_transform()
	var box := Rect2(projection * army[0].art_center(), Vector2.ONE)
	for unit in army:
		box = box.expand(projection * unit.art_center())
	var start_us := Time.get_ticks_usec()
	battle._apply_selection(Vector2.ZERO, false, box.grow(2))
	print("GI release_ms=", (Time.get_ticks_usec() - start_us) / 1000.0)
	check(battle.selected_units.size() == army.size(), "all 96 GIs selected")

func _ready() -> void:
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not ProjectSettings.get_setting("application/config/use_custom_user_dir", false):
		get_tree().quit(2)
		return
	start(MatchRules.EXTENDED)
	battle.process_mode = Node.PROCESS_MODE_ALWAYS
	var center: Vector2 = battle.player_start() + Vector2(150, 110)
	battle.camera.position = center
	for i in 96:
		army.append(battle.spawn_unit("E1", "ally", center + Vector2((i % 12 - 6) * 19, (floori(i / 12.0) - 4) * 19)))
	await sample("standing_unselected")
	box_army()
	await sample("standing_selected")
	battle.use_ability_selected(UnitSkillLayout.index(army[0], 2))
	check(army.all(func(unit): return unit.is_deployed()), "group E deploys every GI")
	await sample("deployed_selected")
	battle.clear_selection()
	battle._emit_selection()
	await sample("deployed_unselected")
	box_army()
	check(screen.hud._strip_icons.size() == 1 and screen.hud._strip_icons[0].icon.count == army.size(), "grouped roster preserves every GI member")
	check(battle.infantry_deploy_group().size() == army.size(), "E still targets entire formation")
	battle.use_ability_selected(UnitSkillLayout.index(army[0], 2))
	check(army.all(func(unit): return not unit.is_deployed()), "group E stands every GI up")
	await finish()
	print("GI checks=", checks.size(), " failed=", failed)
	get_tree().quit(0 if failed == 0 else 1)
