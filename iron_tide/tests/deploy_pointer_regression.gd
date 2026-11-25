extends "res://tests/cursor_regression.gd"

const Ranges = preload("res://scripts/world/attack_range_preview.gd")

func deployment_rings() -> Array:
	return Ranges.ranges(battle).filter(func(r): return r.get("deploy_preview", false))

func exercise_mode(mode: String) -> void:
	BattleRequest.configure_skirmish(mode, {"map_size": 3200, "starting_funds": 8000, "fog_of_war": false})
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
	battle.camera.position = Vector2(1600, 1600)
	battle.camera.zoom = Iso.cam_zoom(2.0)
	battle.camera.reset_smoothing()
	battle.camera.force_update_scroll()
	var cursor = battle.command_cursor
	for uid in ["GGI", "E1"]:
		var unit = battle.spawn_unit(uid, "ally", Vector2(1600, 1600))
		var peer = battle.spawn_unit(uid, "ally", Vector2(1700, 1600))
		for actor in [unit, peer]: actor.process_mode = Node.PROCESS_MODE_DISABLED
		await get_tree().process_frame
		await render_frame()
		place_art_at(unit, Vector2(650, 400))
		place_art_at(peer, Vector2(850, 400))
		await render_frame()
		battle.clear_selection()
		battle._last_click_unit = null
		await point(Vector2(650, 400))
		check(cursor.state == "select", mode + uid + " unselected unit advertises selection")
		await gesture(Vector2(650, 400), Vector2(650, 400))
		check(battle.selected_units == [unit] and not unit.is_deployed(), mode + uid + " first click selects without deploying")
		# A rapid second click is still type selection; it must not accidentally deploy.
		battle._last_click_ms = Time.get_ticks_msec()
		await gesture(Vector2(650, 400), Vector2(650, 400))
		check(battle.selected_units.has(peer) and not unit.is_deployed() and not peer.is_deployed(), mode + uid + " rapid double-click selects type without deployment")
		battle.select_unit(unit, false)
		battle._emit_selection()
		battle._last_click_ms = Time.get_ticks_msec() - 1000
		await point(Vector2(650, 400))
		var expected := "deploy_infantry" if uid == "E1" else "deploy"
		check(cursor.state == expected and cursor.sprite.visible, mode + uid + " selected hover displays original deploy cursor", cursor.state)
		var rings := deployment_rings()
		check(rings.size() == 1 and rings[0].radius == unit.data.deployed_weapon.range and rings[0].minimum == unit.data.deployed_weapon.min_range, mode + uid + " hover adds actual deployed range and blind zone")
		check(Ranges.ranges(battle).size() == 2, mode + uid + " mobile range remains visible")
		battle.queue_redraw()
		var first: Rect2 = cursor.sprite.texture.region
		cursor.refresh(0.1)
		check(cursor.sprite.texture.region != first, mode + uid + " deploy cursor animates")
		check(not unit.is_deployed(), mode + uid + " hover has no side effect")
		await photo(mode + "-" + uid + "-deploy-hover")
		await gesture(Vector2(650, 400), Vector2(650, 400))
		check(unit.is_deployed() and not unit.has_move_order and battle.selected_units == [unit], mode + uid + " plain selected click deploys and retains selection")
		if uid == "GGI":
			check(unit._active_weapon().ra2_weapon_id == "YR_MissileLauncher" and not unit.is_prone() and not unit.crushable, mode + " GGI deploy is fixed missile stance, not GI prone buffs")
			check(unit.stance_label() == "部署导弹", mode + " GGI status names its actual missile stance")
		await render_frame()
		place_art_at(unit, Vector2(650, 400))
		battle._last_click_ms = Time.get_ticks_msec() - 1000
		await point(Vector2(650, 400))
		check(cursor.state == "undeploy", mode + uid + " deployed hover displays original undeploy cursor")
		check(deployment_rings().is_empty(), mode + uid + " no duplicate range while undeploying")
		await photo(mode + "-" + uid + "-undeploy-hover")
		await gesture(Vector2(650, 400), Vector2(650, 400))
		check(not unit.is_deployed(), mode + uid + " selected click returns to mobile stance")
		if uid == "GGI": check(unit._active_weapon().ra2_weapon_id == "YR_M60", mode + " GGI restores machine gun")
		await render_frame()
		place_art_at(unit, Vector2(650, 400))
		battle._last_click_ms = 0
		await gesture(Vector2(650, 400), Vector2(650, 400), true)
		check(not unit.is_deployed() and not battle.selected_units.has(unit), mode + uid + " Shift click removes selection without deployment")
		battle.select_unit(unit, false)
		battle._last_click_ms = 0
		await gesture(Vector2(650, 400), Vector2(690, 435))
		check(not unit.is_deployed(), mode + uid + " drag from selected body does not deploy")
		battle.select_unit(unit, false)
		battle._last_click_unit = null
		battle.arm_command("attack_move")
		await point(Vector2(650, 400))
		check(cursor.state == "attack_move" and battle.pointer_deploy_target(unit.art_center()) == null, mode + uid + " explicit command overrides deployment")
		battle.arm_command("")
		unit._stun_timer = 1.0
		check(battle.pointer_deploy_target(unit.art_center()) == null, mode + uid + " stunned unit has no deploy action")
		unit._stun_timer = 0.0
		battle.select_unit(peer, true)
		check(battle.pointer_deploy_target(unit.art_center()) == null, mode + uid + " multiselection keeps selection semantics")
		battle.select_unit(unit, false)
		battle._emit_selection()
		check(not screen.hud.cmd_buttons.deploy.disabled, mode + uid + " deployment command remains available in HUD")
		await key(KEY_J)
		check(unit.is_deployed(), mode + uid + " J hotkey deploys")
		screen.hud.cmd_buttons.deploy.pressed.emit()
		check(not unit.is_deployed(), mode + uid + " real HUD button undeploys")
		unit._grant_veteran(2, false)
		await render_frame()
		place_art_at(unit, Vector2(650,400))
		battle._last_click_unit = null
		await point(Vector2(650,400))
		var elite := deployment_rings()
		check(elite.size() == 1 and elite[0].radius == unit.data.elite_deployed_weapon.range, mode + uid + " preview uses elite weapon")
		unit.side = "enemy"
		check(battle.pointer_deploy_target(unit.art_center()) == null, mode + uid + " enemy cannot become deployment target")
		battle.clear_selection()
		battle.units.erase(unit)
		battle.units.erase(peer)
		unit.free()
		peer.free()
	var old_camera: Vector2 = battle.camera.position
	for uid in ["DESO", "SCHP"]:
		var unit = battle.spawn_unit(uid, "ally", Vector2(1600,1600))
		unit.process_mode = Node.PROCESS_MODE_DISABLED
		await render_frame()
		var pixel := Vector2(650,400)
		if uid == "SCHP":
			for y in range(800, 2200, 100):
				for x in range(800, 2200, 100):
					unit.position = Vector2(x,y)
					if unit.logistics.SiegeChopper.can_begin(unit,true): break
				if unit.logistics.SiegeChopper.can_begin(unit,true): break
			battle.camera.position = unit.position
			battle.camera.reset_smoothing()
			battle.camera.force_update_scroll()
			await render_frame()
			pixel = stage.get_canvas_transform() * unit.art_center()
		else: place_art_at(unit,pixel)
		battle.select_unit(unit,false)
		battle._last_click_unit = null
		await point(pixel)
		var rings := deployment_rings()
		check(rings.size() == 1 and rings[0].radius == unit.data.deployed_weapon.range and not unit.is_deployed(), mode + uid + " radiation or siege artillery radius on hover")
		if uid == "SCHP":
			var blocker = battle.spawn_unit("E2", "ally", unit.position)
			blocker.hide()
			await point(pixel)
			check(deployment_rings().is_empty() and not unit.logistics.SiegeChopper.can_begin(unit, true), mode + " obstructed landing has no artillery preview")
			battle.units.erase(blocker)
			blocker.free()
		await point(Vector2(900,500))
		check(deployment_rings().is_empty(), mode + uid + " leaving unit hides preview")
		battle.clear_selection()
		battle.units.erase(unit)
		unit.free()
	battle.camera.position = old_camera
	battle.camera.reset_smoothing()
	battle.camera.force_update_scroll()
	var bunker = battle._place_building("NABNKR", "ally", Vector2(1600, 1600), true)
	bunker._buildup_play = -1
	var garrison: Array = []
	for i in 5:
		var soldier = battle.spawn_unit("E2", "ally", bunker.position)
		preload("res://scripts/units/civilian_orders.gd").enter(soldier, bunker)
		garrison.append(soldier)
	await render_frame()
	var at: Vector2 = stage.get_canvas_transform() * bunker.art_center()
	battle.clear_selection()
	await gesture(at, at)
	check(battle.selected_building == bunker and bunker.special.get("occupants", []).size() == 5, mode + " first click selects full bunker")
	await point(at)
	check(cursor.state == "undeploy", mode + " full bunker offers evacuation cursor", cursor.state)
	await gesture(at, at, true)
	check(bunker.special.get("occupants", []).size() == 5, mode + " Shift click preserves garrison")
	await gesture(at, at)
	check(battle.selected_building == bunker and bunker.special.get("occupants", []).is_empty() and garrison.all(func(u): return u.embarked_in == null and u.hp > 0), mode + " second plain click evacuates all five")
	await point(at)
	check(cursor.state != "undeploy", mode + " empty bunker has no evacuation cursor")
	screen.free()
	await get_tree().process_frame

func render_frame() -> void:
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
