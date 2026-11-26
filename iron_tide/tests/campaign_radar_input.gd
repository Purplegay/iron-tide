extends "res://tests/selection_regression.gd"

func _ready() -> void:
	if not ProjectSettings.get_setting("application/config/use_custom_user_dir", false):
		get_tree().quit(2)
		return
	await get_tree().process_frame
	stage = SubViewport.new()
	stage.size = Vector2i(1600, 900)
	stage.world_2d = World2D.new()
	stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(stage)
	BattleRequest.configure_mission("yr_time_shift", {"campaign_growth": false, "country": "苏俄", "difficulty": 1})
	screen = load("res://scenes/battle.tscn").instantiate()
	stage.add_child(screen)
	battle = screen.battle
	var radar: MiniMap = screen.hud.minimap
	var intro = battle.get_node_or_null("HollywoodFilm")
	check(intro != null and get_tree().paused, "campaign full-screen intro is modal")
	if intro != null: intro.finish()
	battle.set_process(false)
	battle.set_physics_process(false)
	await get_tree().process_frame
	await get_tree().process_frame
	get_window().focus_entered.emit()
	check(battle.world_input_enabled(), "campaign input is enabled after intro")
	var marks := radar.objective_marks()
	check(not marks.is_empty() and not radar._pings.is_empty(), "campaign intro announces public objectives")
	if marks.is_empty():
		get_tree().quit(1)
		return
	var map_point: Vector2 = marks[0].position
	var local: Vector2 = marks[0].local
	await click_radar(radar, local + Vector2(4, 0))
	check(center_matches(map_point), "left click snaps to the nearby public objective")
	var second: Vector2 = battle.TimeShift.wp(18)
	radar.clear_radar_events()
	Events.emit_radar_ping(map_point, "campaign_site")
	Events.emit_radar_ping(second, "campaign_discovery")
	Events.emit_radar_ping(second, "campaign_discovery")
	check(radar._radar_history.size() == 2 and radar._pings.size() == 2, "repeated pings do not flood the radar or history")
	var hidden: Vector2 = battle.TimeShift.wp(104)
	check(not battle.position_visible_to("ally", hidden), "fog fixture is undiscovered")
	Events.emit_radar_ping(hidden, "attack")
	check(radar._radar_history.size() == 2, "hidden non-public events are not exposed by the jump hotkey")
	await key(KEY_PERIOD)
	check(center_matches(second), "HUD hotkey jumps to the newest event")
	await key(KEY_PERIOD)
	check(center_matches(map_point), "quick repeat cycles to the previous event")
	radar._process(6.0)
	check(radar._pings.is_empty() and radar._radar_history.size() == 2, "flashes expire but remain available for navigation")
	var unit = battle.units.filter(func(u): return battle.actor_alive(u) and u.side == "ally" and u.unit_id == "DRED")[0]
	unit.set_physics_process(false)
	battle.select_unit(unit,false)
	var before_cam: Vector2 = battle.camera.position
	await click_radar(radar, radar._world_to_minimap() * second, MOUSE_BUTTON_RIGHT)
	check(unit.has_move_order and unit.move_target.distance_to(second) < 5.0, "right click orders the selected ship to the radar point", unit.move_target)
	check(before_cam.is_equal_approx(battle.camera.position) and battle.selected_units == [unit], "right click does not move camera or change selection")
	var factory = battle._place_building("NAWEAP", "ally", second + Vector2(100,100), true)
	battle.select_building(factory)
	await click_radar(radar, local, MOUSE_BUTTON_RIGHT)
	check(battle.rally_for(factory).distance_to(map_point) < 1.0, "right click sets the selected factory rally point")
	battle.clear_selection()
	battle.center_on(second)
	await click_radar(radar, local, MOUSE_BUTTON_RIGHT)
	check(center_matches(map_point), "right click without a selected unit or factory falls back to camera focus")
	battle.center_on(second)
	battle.TimeShift.scenario_film(battle, "S01_P01E")
	var inset = battle.get_node_or_null("HollywoodFilm")
	check(inset != null and inset.player.is_playing(), "campaign radio inset is playing")
	await get_tree().process_frame
	await click_radar(radar, local)
	check(center_matches(map_point), "left click reaches the radar through the radio inset")
	stage.gui_release_focus()
	if inset != null: inset.finish()
	await get_tree().process_frame
	battle.center_on(second)
	battle.paused = true
	await click_radar(radar, local)
	check(center_matches(second) and not radar.jump_to_radar_event(), "paused world blocks radar navigation")
	battle.paused = false
	battle.allied_state.hollywood = {"radar":false}
	await click_radar(radar, local)
	check(center_matches(second) and not radar.jump_to_radar_event(), "offline campaign radar blocks navigation")
	battle.allied_state.erase("hollywood")
	battle.hud.minimap.clear_radar_events()
	check(not radar.jump_to_radar_event(), "clearing events prevents jumping to the previous era")
	Ra2Sfx.stop_all(); Music.stop()
	print("CAMPAIGN_RADAR checks=", checks.size(), " failed=", failed)
	get_tree().quit(0 if failed == 0 else 1)

func click_radar(radar: MiniMap, local: Vector2, mouse := MOUSE_BUTTON_LEFT) -> void:
	var pixel := radar.get_global_transform_with_canvas() * local
	var move := InputEventMouseMotion.new()
	move.position = pixel
	move.global_position = pixel
	stage.push_input(move, true)
	await mouse_button(pixel, true, false, mouse)
	await mouse_button(pixel, false, false, mouse)

func center_matches(point: Vector2) -> bool:
	var current: Vector2 = battle.camera.position
	battle.center_on(point)
	var expected: Vector2 = battle.camera.position
	battle.camera.position = current
	return current.distance_to(expected) < 1.0
