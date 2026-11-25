extends Node
## Frozen real actors; mouse/key events still traverse the production battle/HUD.

var checks: Array = []
var failed := 0
var output_dir := ""
var screen
var battle
var stage: SubViewport

func check(ok: bool, label: String, details = null) -> void:
	checks.append({"name": label, "passed": ok, "details": details})
	if not ok:
		failed += 1
		print("FAIL ", label, " ", details)

func _ready() -> void:
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not ProjectSettings.get_setting("application/config/use_custom_user_dir", false):
		push_error("Use the isolated validation runner.")
		get_tree().quit(2)
		return
	await get_tree().process_frame
	# Window mouse queries follow the physical desktop cursor. A SubViewport
	# owns its injected pointer, so test gestures cannot race the user's mouse.
	stage = SubViewport.new()
	stage.size = Vector2i(1600, 900)
	stage.world_2d = World2D.new()
	stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(stage)
	MetaProgress.unit_loadouts["E1"] = {"active": ["ap_deploy"], "passive": ""}
	for mode in [MatchRules.RA2, MatchRules.EXTENDED]:
		await exercise_mode(mode)
	var f := FileAccess.open(output_dir.path_join("result.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks": checks, "failed": failed, "evidence": {
		"project": ProjectSettings.globalize_path("res://"), "user_dir": OS.get_user_data_dir(),
		"engine": Engine.get_version_info().string,
		"input": "Viewport.push_input routes mouse/key events through the real battle/HUD",
		"modes": ["ra2", "iron_tide"], "zooms": [0.5, 1, 2, 4]
	}}, "  "))
	f.close()
	# Stop mixer-owned streams before quitting the test process; otherwise the
	# last voice/VFX callback can outlive a destroyed isolated battle scene.
	Ra2Sfx.stop_all(); Music.stop(); Music.player.stream = null
	OS.delay_msec(150)
	await get_tree().process_frame
	print("SELECTION checks=", checks.size(), " failed=", failed)
	get_tree().quit(0 if failed == 0 else 1)

func exercise_mode(mode: String) -> void:
	if mode == MatchRules.RA2:
		for id in ["MTNK", "FV", "TNKD", "SHAD"]:
			var art := RA2Art.art(id)
			RA2Art.sprite_image(art)
			var scan := art.duplicate()
			scan.key = "uncached-" + id
			scan.visible_centers = {}
			var frames := range(int(art.facings))
			for facing in [0, 3, 7, frames.size() - 1]:
				var baked := RA2Art.visible_unit_center(Vector2.ZERO, art, 16, frames, facing, 11.0, 1.0)
				check(baked.is_equal_approx(RA2Art.visible_unit_center(Vector2.ZERO, scan, 16, frames, facing, 11.0, 1.0)), id + " baked box pick matches native pixel scan")
	BattleRequest.configure_skirmish(mode, {"map_size": 3200, "starting_funds": 8000})
	screen = load("res://scenes/battle.tscn").instantiate()
	stage.add_child(screen)
	battle = screen.battle
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	battle.process_mode = Node.PROCESS_MODE_ALWAYS
	battle.set_process(false)
	battle.set_physics_process(false)
	for child in battle.get_children():
		child.process_mode = Node.PROCESS_MODE_DISABLED
	screen.hud.process_mode = Node.PROCESS_MODE_ALWAYS
	screen.hud.set_process(false)
	await get_tree().process_frame
	# Synthetic viewport input needs an explicit focused-window precondition.
	# Focus loss/return behavior itself is covered by camera_input_regression.
	get_window().focus_entered.emit()
	check(battle.world_input_enabled(), mode + ": focused world-input fixture")
	var tank = battle.spawn_unit("MTNK", "ally", Vector2(1600, 1600))
	tank.process_mode = Node.PROCESS_MODE_DISABLED
	for zoom in [0.5, 1.0, 2.0, 4.0]:
		battle.camera.rotation = PI / 4.0
		battle.camera.zoom = Vector2(zoom, zoom * 0.5)
		battle.camera.position = Vector2(1600, 1600)
		battle.camera.reset_smoothing()
		battle.camera.force_update_scroll()
		await get_tree().process_frame
		place_art_at(tank, Vector2(650, 400))
		for delta in [Vector2(8, 0), Vector2(0, -8), Vector2(20, 0), Vector2(0, -20)]:
			var label := "%s zoom %.1f drag %s: " % [mode, zoom, delta]
			var start := Vector2(652, 402) if delta.x > 0 else Vector2(648, 398)
			var world: Vector2 = stage.get_canvas_transform().affine_inverse() * start
			check(battle._pick_at(world) == tank, label + "gesture starts on real unit pixels")
			battle.clear_selection()
			battle._last_click_unit = null
			await gesture(start, start + delta)
			var expect_click: bool = delta.length() < 14.0
			check(battle.selected_units.has(tank) if expect_click else battle.selected_units.is_empty(),
				label + ("small movement selects unit" if expect_click else "box excludes unit center"),
				battle.selected_units.size())
			check(not battle.dragging, label + "release ends selection drag")
		# A rectangle enclosing the unit proves box selection still works.
		battle._last_click_unit = null
		await gesture(Vector2(620, 370), Vector2(680, 430))
		check(battle.selected_units.has(tank), "%s zoom %.1f: enclosing rectangle selects unit" % [mode, zoom])
	tank.global_position = Vector2(2900, 2900)
	battle.camera.zoom = Vector2(2, 1)
	battle.camera.force_update_scroll()
	await get_tree().process_frame
	if mode == MatchRules.EXTENDED:
		BattleRequest.combat_context.loadouts["E1"] = {"active":["ap_focus_fire"],"passive":""}
	var soldier = battle.spawn_unit("E1", "ally", Vector2(1600, 1600))
	var peer = battle.spawn_unit("E1", "ally", Vector2(1650, 1650))
	soldier.process_mode = Node.PROCESS_MODE_DISABLED
	peer.process_mode = Node.PROCESS_MODE_DISABLED
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	place_art_at(soldier, Vector2(650, 400))
	place_art_at(peer, Vector2(730, 400))
	check((stage.get_canvas_transform() * soldier.art_center()).is_equal_approx(Vector2(650, 400)),
		mode + ": soldier screen placement", str(stage.get_canvas_transform() * soldier.art_center()))
	check(battle._pick_at(soldier.art_center()) == soldier, mode + ": soldier hit-test fixture")
	battle.clear_selection()
	battle._last_click_unit = null
	await gesture(Vector2(650, 400), Vector2(650, 400))
	check(battle.selected_units.size() == 1 and battle.selected_units.has(soldier), mode + ": click selects one soldier",
		{"selected": str(battle.selected_units), "art_pixel": str(stage.get_canvas_transform() * soldier.art_center()),
		"world_mouse": str(battle.get_global_mouse_position()), "art_center": str(soldier.art_center())})
	# Expire the double-click clock without sleeping; then repeat the actual click.
	battle._last_click_ms = Time.get_ticks_msec() - 1000
	await gesture(Vector2(650, 400), Vector2(650, 400))
	check(soldier.is_deployed(), mode + ": explicit selected-unit click deploys after the double-click window")
	var ability: Ability = soldier.ability_at(UnitSkillLayout.index(soldier, 1))
	check(ability == null if mode == MatchRules.RA2 else ability != null and ability.cd_left == 0.0,
		mode + ": selection does not consume ability cooldown")
	await gesture(Vector2(650, 400), Vector2(650, 400))
	check(battle.selected_units.has(soldier) and battle.selected_units.has(peer), mode + ": double click selects same type")
	check(soldier.is_deployed() and not peer.is_deployed() and battle.cast_slot == -1,
		mode + ": rapid type-selection preserves existing stances and does not start targeting")
	# Independent command checks start from a known state, even on buggy builds.
	soldier.set_deployed(false)
	if ability != null:
		ability.cd_left = 0.0
	battle.select_unit(soldier, false)
	battle._emit_selection()
	await key(KEY_J)
	check(soldier.is_deployed(), mode + ": explicit J deploy command still works")
	await key(KEY_J)
	check(not soldier.is_deployed(), mode + ": explicit J undeploy command still works")
	if mode == MatchRules.EXTENDED:
		await key(KEY_W, true)
		check(not soldier.is_deployed() and ability.cd_left > 0 and ability.is_active(), mode + ": Shift+W casts equipped focus fire without deploying")
		var cooldown: float = ability.cd_left
		await key(KEY_W, true)
		check(not soldier.is_deployed() and ability.cd_left == cooldown, mode + ": cooldown blocks a repeated explicit cast")
		ability.cd_left = 0.0
		# Use the existing HUD button signal, with the real connected callback.
		check(screen.hud._ability_btns.size() > 1, mode + ": explicit skill button exists")
		if screen.hud._ability_btns.size() > 1:
			screen.hud._ability_btns[1].pressed.emit()
			check(not soldier.is_deployed() and ability.cd_left > 0, mode + ": skill button still casts")
	await gesture(Vector2(1000, 350), Vector2(1000, 350))
	check(battle.selected_units.is_empty(), mode + ": empty ground clears selection")
	await exercise_strip_removal(mode, soldier, peer, tank)
	await exercise_additional_input(mode, soldier, peer, tank)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		stage.get_texture().get_image().save_png(output_dir.path_join(mode + "-selection.png"))
	screen.free()
	await get_tree().process_frame

func place_art_at(unit, pixel: Vector2) -> void:
	var world: Vector2 = stage.get_canvas_transform().affine_inverse() * pixel
	unit.global_position += world - unit.art_center()

func exercise_additional_input(_mode: String, _soldier, _peer, _tank) -> void:
	pass

func exercise_strip_removal(mode: String, soldier, peer, tank) -> void:
	battle.clear_selection()
	for unit in [soldier, peer, tank]:battle.select_unit(unit, true)
	battle._emit_selection()
	await get_tree().process_frame
	await get_tree().process_frame
	var camera_before: Vector2 = battle.camera.position
	var targets: Array = [soldier.move_target, peer.move_target, tank.move_target]
	var tile = screen.hud._strip_icons[1].icon
	check(tile.tooltip_text.contains("右键：取消选择该单位"), mode + ": individual portrait explains deselection")
	await right_click_portrait(tile)
	check(battle.selected_units == [soldier, tank] and not peer.selected and soldier.selected and tank.selected, mode + ": portrait right click removes only the exact actor, preserving same-type peer")
	check("已选部队 2" in screen.hud.sel_strip_title.text and screen.hud._strip_icons.size() == 2, mode + ": individual deselection updates roster and count immediately")
	check([soldier.move_target, peer.move_target, tank.move_target] == targets and battle.camera.position == camera_before and not battle._rmb_panning, mode + ": portrait right click does not issue move orders or pan camera")
	await right_click_portrait(screen.hud._strip_icons[0].icon)
	check(battle.selected_units == [tank] and not soldier.selected, mode + ": repeated portrait removal retains last unit")
	await right_click_portrait(screen.hud._strip_icons[0].icon)
	check(battle.selected_units.is_empty() and not tank.selected and not screen.hud.sel_strip.visible, mode + ": removing final individual clears selection and hides panel")
	check(tank.move_target == targets[2] and battle.camera.position == camera_before and not battle._rmb_panning, mode + ": final removal release does not leak into world command")

func right_click_portrait(icon: Control) -> void:
	var point: Vector2 = icon.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point;motion.global_position = point
	stage.push_input(motion, true)
	await get_tree().process_frame
	await mouse_button(point, true, false, MOUSE_BUTTON_RIGHT)
	await mouse_button(point, false, false, MOUSE_BUTTON_RIGHT)
	await get_tree().process_frame

func gesture(start: Vector2, finish: Vector2, shift := false) -> void:
	var approach := InputEventMouseMotion.new()
	approach.position = start
	approach.global_position = start
	stage.push_input(approach, true)
	await get_tree().process_frame
	await mouse_button(start, true, shift)
	check(battle.dragging and battle.drag_start_screen.is_equal_approx(start),
		"mouse press reaches selection with the injected screen position", str(battle.drag_start_screen))
	var motion := InputEventMouseMotion.new()
	motion.position = finish
	motion.global_position = finish
	motion.relative = finish - start
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	stage.push_input(motion, true)
	await get_tree().process_frame
	await mouse_button(finish, false, shift)

func mouse_button(at: Vector2, pressed: bool, shift := false, index: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = index
	event.button_mask = (1 << (index - 1)) if pressed else 0
	event.shift_pressed = shift
	event.pressed = pressed
	event.position = at
	event.global_position = at
	stage.push_input(event, true)
	await get_tree().process_frame

func key(code: Key, shift := false) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		event.shift_pressed = shift
		stage.push_input(event, true)
		await get_tree().process_frame
