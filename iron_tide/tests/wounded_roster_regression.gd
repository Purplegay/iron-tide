extends "res://tests/base_recovery_regression.gd"

var theme_changes := 0
var body_draws := 0

func _ready() -> void:
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not ProjectSettings.get_setting("application/config/use_custom_user_dir", false):
		get_tree().quit(2)
		return
	start(MatchRules.EXTENDED)
	var hud = screen.hud
	var center: Vector2 = battle.player_start() + Vector2(150, 100)
	battle.camera.position = center
	battle.camera.force_update_scroll()
	for i in 96:
		var soldier = battle.spawn_unit("E2", "ally", center + Vector2((i % 12 - 6) * 19, (floori(i / 12.0) - 4) * 19))
		soldier.process_mode = Node.PROCESS_MODE_ALWAYS
	hud.sel_panel.theme_changed.connect(func(): theme_changes += 1)
	for health in [1.0, 0.16, 1.0, 0.16]:
		battle.clear_selection()
		battle._emit_selection()
		for unit in battle.units:
			unit.hp = unit.max_hp * health
			unit.queue_redraw()
		for i in 8:
			await get_tree().process_frame
		var box := Rect2(get_viewport().get_canvas_transform() * battle.units[0].art_center(), Vector2.ONE)
		for unit in battle.units:
			box = box.expand(get_viewport().get_canvas_transform() * unit.art_center())
		box = box.grow(2)
		battle.drag_start_screen = box.position
		battle.dragging = true
		for i in 8:
			battle.queue_redraw()
			await get_tree().process_frame
		battle.dragging = false
		var release := Time.get_ticks_usec()
		battle._apply_selection(Vector2.ZERO, false, box)
		release = Time.get_ticks_usec() - release
		check(battle.selected_units.size() == 96, "box selects entire formation", battle.selected_units.size())
		for i in 12:
			await get_tree().process_frame
		check(hud._sel_panel_low == (health < hud.LOW_HP_TINT), "warning follows current selection health")
		theme_changes = 0
		var frames := PackedFloat64Array()
		for i in 60:
			var tick := Time.get_ticks_usec()
			await get_tree().process_frame
			frames.append((Time.get_ticks_usec() - tick) / 1000.0)
		frames.sort()
		print("WOUNDED hp=", health, " release_ms=", release / 1000.0, " median_ms=", frames[30], " p95_ms=", frames[56], " theme_changes=", theme_changes)
		check(theme_changes == 0, "steady selection does not invalidate the panel theme")
	var soldier = battle.units[0]
	soldier.draw.connect(func(): body_draws += 1)
	check(soldier.group_idle_redraw, "large selection uses staggered idle redraw")
	soldier._hp_flash = 1.0
	for i in 6:
		await get_tree().process_frame
	check(body_draws >= 5, "recent hit redraws promptly even in large formation", body_draws)
	soldier.order_move(soldier.global_position + Vector2(0, -250))
	var origin: Vector2 = soldier.global_position
	body_draws = 0
	for i in 18:
		await get_tree().process_frame
	check(origin.distance_to(soldier.global_position) > 1 and body_draws >= 15, "moving unit keeps full redraw cadence", body_draws)
	battle.focus_unit(soldier)
	check(not soldier.group_idle_redraw and not battle.units[1].group_idle_redraw, "single and deselected units leave group cadence")
	await finish()
	print("WOUNDED checks=", checks.size(), " failed=", failed)
	get_tree().quit(0 if failed == 0 else 1)
