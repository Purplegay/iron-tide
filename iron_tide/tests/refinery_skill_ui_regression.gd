extends "res://tests/selection_regression.gd"

func settle() -> void:
	for i in 4: await get_tree().process_frame

func click(control: Control, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	var at := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	stage.push_input(motion, true)
	await get_tree().process_frame
	await mouse_button(at, true, false, button)
	await mouse_button(at, false, false, button)
	await settle()

func check_portrait(hud, prefix: String) -> void:
	var portrait: TextureRect = hud._refinery_btn.get_node("Content/Portrait")
	var caption: Label = hud._refinery_btn.get_node("Content/Caption")
	check(portrait.texture != null and portrait.texture.resource_path == GameData.ra2_cameo_path("CMIN"), prefix + "original miner portrait")
	check(portrait.is_visible_in_tree() and portrait.size.x >= 40 and portrait.size.y >= 30, prefix + "portrait keeps visible dimensions", str(portrait.size))
	check(hud._refinery_btn.get_global_rect().encloses(portrait.get_global_rect()) and not portrait.get_global_rect().intersects(caption.get_global_rect()), prefix + "portrait enclosed without caption overlap")

func exercise_mode(mode: String) -> void:
	BattleRequest.configure_skirmish(mode, {"map_size": 3200, "starting_funds": 50000})
	screen = load("res://scenes/battle.tscn").instantiate()
	stage.add_child(screen)
	battle = screen.battle
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	var hud = screen.hud
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	hud.set_process(false)
	GM.unlock_production_tech = true
	GM.infinite_funds = false
	battle.power_low = false
	get_window().focus_entered.emit()
	var refinery
	for b in battle.buildings:
		b._buildup_play = -1.0
		if b.side == "ally" and b.is_refinery(): refinery = b
	var other = battle._place_building("GAREFN", "ally", Vector2(2000, 1800), true)
	other._buildup_play = -1.0
	var infantry = battle.spawn_unit("E1", "ally", Vector2(1600, 1600))
	for dimensions in [Vector2i(1280, 720), Vector2i(1600, 900)]:
		stage.size = dimensions
		battle.select_building(refinery)
		battle._emit_selection()
		await settle()
		for collapsed in [false, true]:
			if hud.unit_menu_collapsed != collapsed: await click(hud.unit_menu_toggle)
			var prefix := "%s %s collapsed=%s: " % [mode, dimensions, collapsed]
			check(hud.ability_panel.is_visible_in_tree() and hud._refinery_btn.is_visible_in_tree(), prefix + "refinery action remains visible")
			check(not hud._refinery_btn.disabled, prefix + "usable manufacture action")
			check_portrait(hud, prefix + "idle: ")
			check(hud.sel_panel.is_visible_in_tree() != collapsed, prefix + "details respect menu state")
			await click(hud._refinery_btn)
			refinery._process(0.5)
			hud._update_refinery_live()
			await settle()
			check_portrait(hud, prefix + "producing: ")
			await RenderingServer.frame_post_draw
			stage.get_texture().get_image().save_png(output_dir.path_join("%s-%dx%d-%s-producing.png" % [mode, dimensions.x, dimensions.y, collapsed]))
			check(refinery.production == ["CMIN"], prefix + "real pointer starts one miner")
			var paid: float = refinery.production_paid
			var progress: float = refinery.progress
			var money: float = battle.funds
			var bounds := Rect2(Vector2.ZERO, Vector2(dimensions))
			for control in [hud.ability_panel, hud._refinery_btn, hud._refinery_cancel]:
				check(bounds.encloses(control.get_global_rect()) and not control.get_global_rect().intersects(hud.prod_panel.get_global_rect()), prefix + "busy action fits without sidebar overlap", str(control.get_global_rect()))
			check(hud.ability_panel.get_global_rect().encloses(hud._refinery_btn.get_global_rect()), prefix + "manufacture button enclosed by skill bar")
			check(not hud.ability_panel.get_global_rect().intersects(hud.unit_menu_toggle.get_global_rect()), prefix + "collapse toggle clears skill bar")
			await click(hud._refinery_btn, MOUSE_BUTTON_RIGHT)
			check_portrait(hud, prefix + "paused: ")
			refinery._process(1.0)
			check(refinery.production_paused() and refinery.progress == progress and battle.funds == money, prefix + "right click pauses without losing progress or funds")
			await click(hud._refinery_btn)
			check(not refinery.production_paused() and refinery.production.size() == 1, prefix + "left click resumes without duplicate")
			await click(hud._refinery_cancel)
			check(refinery.production_paused(), prefix + "visible pause action works")
			await click(hud._refinery_cancel)
			check(refinery.production.is_empty() and is_equal_approx(battle.funds, money + paid), prefix + "cancel refunds only paid amount")
			if collapsed:
				await RenderingServer.frame_post_draw
				stage.get_texture().get_image().save_png(output_dir.path_join("%s-%dx%d-refinery.png" % [mode, dimensions.x, dimensions.y]))
				battle.select_building(other)
				battle._emit_selection()
				await settle()
				check(other.is_operational() and not hud._refinery_btn.disabled, prefix + "second refinery is ready for production", other.queue_block_reason("CMIN"))
				await click(hud._refinery_btn)
				check(other.production == ["CMIN"] and refinery.production.is_empty(), prefix + "switching refineries targets newly selected building")
				other.production_right_click("CMIN")
				other.production_right_click("CMIN")
				battle.select_unit(infantry, false)
				battle._emit_selection()
				await settle()
				check(hud._refinery_btn == null and hud._ability_btns.size() == 3 and hud.ability_panel.is_visible_in_tree(), prefix + "switching to infantry restores unit skills without stale building action")
				battle.select_building(refinery)
				battle._emit_selection()
				await settle()
	GM.unlock_production_tech = false
	battle.production_technology.unlocked.clear()
	hud._update_refinery_live()
	check(hud._refinery_btn.disabled and not refinery.production_tech_block_reason("CMIN").is_empty(), mode + ": collapsed action retains technology gate")
	check(hud._refinery_btn.get_node("Content/Caption").text.contains(refinery.production_tech_block_reason("CMIN")), mode + ": locked reason remains visible")
	screen.free()
	await get_tree().process_frame
