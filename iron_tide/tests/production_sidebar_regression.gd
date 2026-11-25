extends "res://tests/input_ownership_regression.gd"

func settle() -> void:
	for i in 5: await get_tree().process_frame

func exercise_mode(mode: String) -> void:
	BattleRequest.configure_skirmish(mode, {"map_size": 3200, "starting_funds": 7600, "country": "德国"})
	screen = load("res://scenes/battle.tscn").instantiate()
	stage.add_child(screen)
	battle = screen.battle
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	var hud = screen.hud
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	hud.set_process(false)
	var factory = battle._place_building("GAWEAP", "ally", Vector2(1200, 1800), true)
	factory._buildup_play = -1.0
	battle.select_building(factory)
	hud.select_prod_tab("vehicle")
	hud._refresh_production()
	await settle()
	get_window().focus_entered.emit()
	var inspector = hud._production_inspector
	var factory_tab: Button = hud._factories.buttons[factory.get_instance_id()].button
	await move_pointer(factory_tab.get_global_rect().get_center())
	check(inspector.title.text == factory.display_name and factory_tab.get_tooltip().is_empty(), mode + ": factory hover uses fixed details")
	for resolution in [Vector2i(1280, 720), Vector2i(1600, 900)]:
		stage.size = resolution
		await settle()
		hud._layout_hud()
		await settle()
		var prefix := "%s %s: " % [mode, resolution]
		var card: Button = hud._prod_buttons["TNKD"]
		hud._prod_scroll.ensure_control_visible(card)
		await settle()
		await move_pointer(Vector2(600, 200))
		await move_pointer(card.get_global_rect().get_center())
		await settle()
		check(card.disabled, prefix + "locked fixture")
		check(inspector.title.text == "坦克杀手", prefix + "real hover on disabled card updates dock", inspector.title.text)
		check("空指部" in inspector.description.text, prefix + "missing prerequisite retained")
		check(card.get_tooltip().is_empty() and not card.tooltip_text.is_empty(), prefix + "native floating tooltip suppressed without losing source details")
		check(card.detail_highlight, prefix + "hover inspection highlighted")
		check(inspector.fold_button.text == "收起" and inspector.description.visible, prefix + "details start expanded with fold control")
		var expanded_details_height: float = inspector.size.y
		inspector.fold_button.pressed.emit()
		await settle()
		check(not inspector.description.visible and inspector.fold_button.text == "展开", prefix + "fold hides description and offers expand")
		check(inspector.size.y < expanded_details_height, prefix + "fold releases sidebar space")
		var preferences := ConfigFile.new()
		check(preferences.load(hud.PANEL_PREFERENCES_PATH) == OK and preferences.get_value("panels", "production_details_collapsed", false) == true, prefix + "fold choice is saved to disk")
		inspector.clear()
		check(inspector._folded and not inspector.description.visible, prefix + "clearing cards preserves fold choice")
		inspector._set_folded(false)
		hud._restore_panel_preferences()
		check(inspector._folded and inspector.fold_button.text == "展开" and not inspector.description.visible, prefix + "disk preferences restore folded details")
		factory_tab.mouse_entered.emit()
		check(inspector.title.text == factory.display_name and not inspector.description.visible, prefix + "fold state persists across inspected cards")
		var list_height: float = hud._prod_scroll.size.y
		var close_button: Button = inspector.find_child("CloseProductionDetails", true, false)
		var close_at := close_button.get_global_rect().get_center()
		await move_pointer(close_at)
		await mouse_button(close_at, true)
		await mouse_button(close_at, false)
		hud._update_production_live()
		await settle()
		check(not inspector.visible and hud._prod_scroll.size.y > list_height, prefix + "close removes the complete folded dock and frees list space")
		card.mouse_entered.emit()
		var config := ConfigFile.new()
		check(config.load(DisplayPreferences.SETTINGS_PATH) == OK and config.get_value("hud", "show_production_details", true) == false, prefix + "closed preference saved to disk")
		DisplayPreferences.reload()
		check(not inspector.visible and inspector.title.text == "生产情报", prefix + "hover and reload keep closed dock inactive")
		var toggle: CheckBox = hud.settings_panel.find_child("ShowProductionDetails", true, false)
		hud.settings_panel.show()
		check(not toggle.button_pressed and toggle.is_visible_in_tree(), prefix + "battle settings reflect the closed dock")
		toggle.button_pressed = true
		hud.settings_panel.hide()
		await settle()
		check(inspector.visible and inspector._folded, prefix + "settings restore dock at its previous fold state")
		inspector.fold_button.pressed.emit()
		await settle()
		check(inspector.description.visible and inspector.fold_button.text == "收起", prefix + "expand restores description")
		card.mouse_entered.emit()
		check(factory.production.is_empty() and battle.funds == 7600, prefix + "hover does not purchase")
		var rect: Rect2 = inspector.get_global_rect()
		check(hud.prod_panel.get_global_rect().encloses(rect), prefix + "details contained by sidebar", str(rect))
		check(Rect2(Vector2.ZERO, Vector2(resolution)).encloses(rect), prefix + "details contained by viewport")
		check(hud._prod_scroll.size.y >= 140, prefix + "at least two card rows remain visible", hud._prod_scroll.size.y)
		await move_pointer(rect.get_center())
		check(inspector.title.text == "坦克杀手", prefix + "reader can move into dock without losing text")
		await mouse_button(rect.get_center(), true)
		await mouse_button(rect.get_center(), false)
		check(not battle.dragging and factory.production.is_empty(), prefix + "dock consumes world clicks")
		if DisplayServer.get_name() != "headless":
			Ra3Skin.upgrade_tree(hud.prod_panel, UiKit.RA_CYAN)
			await settle()
			await RenderingServer.frame_post_draw
			stage.get_texture().get_image().save_png(output_dir.path_join("%s-%d-sidebar.png" % [mode, resolution.y]))
		var repair: Button = hud.building_action_buttons["repair"]
		await move_pointer(repair.get_global_rect().get_center())
		check("维修模式" in inspector.description.text and repair.get_tooltip().is_empty(), prefix + "repair instructions docked")
		await move_pointer(card.get_global_rect().get_center())
		await mouse_button(card.get_global_rect().get_center(), true)
		await mouse_button(card.get_global_rect().get_center(), false)
		hud._update_production_live()
		await settle()
		check(hud._unlock_panel.visible and not inspector.visible, prefix + "unlock route replaces inspector to preserve room")
		hud._close_unlock_panel()
		hud._update_production_live()
		await settle()
		check(inspector.visible, prefix + "closing unlock route restores details")
	hud.select_prod_tab("building")
	await settle()
	check(inspector.title.text == "生产情报", mode + ": tab change clears stale factory/card reference")
	var power: Button = hud._prod_buttons["GAPOWR"]
	hud._prod_scroll.ensure_control_visible(power)
	await settle()
	await move_pointer(power.get_global_rect().get_center())
	check(inspector.title.text == "发电厂", mode + ": building hover uses same dock")
	battle.struct_ready["GAPOWR"] = 1
	hud._update_production_live()
	check("就绪" in inspector.description.text, mode + ": ready state updates without pointer movement")
	hud.select_prod_tab("vehicle")
	await settle()
	var tank: Button = hud._prod_buttons["MTNK"]
	hud._prod_scroll.ensure_control_visible(tank)
	await settle()
	var at := tank.get_global_rect().get_center()
	await move_pointer(at)
	await mouse_button(at, true)
	await mouse_button(at, false)
	check(factory.production == ["MTNK"], mode + ": left click still starts unit production")
	var tile: Control = hud._queue_host.get_node("queue_strip").get_child(0)
	hud._prod_scroll.ensure_control_visible(tile)
	await settle()
	await move_pointer(tile.get_global_rect().get_center())
	check("灰熊坦克" in inspector.title.text and tile.get_tooltip().is_empty(), mode + ": queue tile details are docked")
	check("右键暂停" in inspector.description.text, mode + ": queue retains pause and cancellation instructions")
	hud._prod_scroll.ensure_control_visible(tank)
	await settle()
	at = tank.get_global_rect().get_center()
	await move_pointer(at)
	await mouse_button(at, true, false, MOUSE_BUTTON_RIGHT)
	await mouse_button(at, false, false, MOUSE_BUTTON_RIGHT)
	check(factory.production_paused(), mode + ": first right click pauses")
	hud._update_production_live()
	check("暂停" in inspector.description.text, mode + ": paused state updates fixed details")
	await mouse_button(at, true, false, MOUSE_BUTTON_RIGHT)
	await mouse_button(at, false, false, MOUSE_BUTTON_RIGHT)
	check(factory.production.is_empty(), mode + ": second right click cancels")
	screen.free()
	await get_tree().process_frame
	await soviet_descriptions(mode)

func soviet_descriptions(mode: String) -> void:
	BattleRequest.configure_skirmish(mode, {"map_size":3200,"country":"苏俄","enemy_base":"allied"})
	screen = load("res://scenes/battle.tscn").instantiate()
	stage.add_child(screen)
	battle = screen.battle
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	var hud = screen.hud
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	hud.set_process(false)
	for category in ["building", "defense", "infantry", "vehicle", "air", "naval"]:
		hud.select_prod_tab(category)
		await settle()
		for id in hud._prod_buttons:
			var card: Button = hud._prod_buttons[id]
			var data := GameData.get_entity(id)
			var wanted := EntityDescription.text(data)
			hud._prod_scroll.ensure_control_visible(card)
			await settle()
			await move_pointer(Vector2(600, 200))
			await move_pointer(card.get_global_rect().get_center())
			check(hud._production_inspector.description.text.begins_with("简介　" + wanted),mode+" actual hover reads introduction "+str(id))
			if id == "SHK" and DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				var bounds := Rect2i(hud._production_inspector.get_global_rect())
				stage.get_texture().get_image().get_region(bounds).save_png(output_dir.path_join(mode+"-soviet-overview.png"))
	hud.select_prod_tab("infantry")
	await settle()
	var boris: Button = hud._prod_buttons.BORIS
	hud._prod_scroll.ensure_control_visible(boris)
	await settle()
	var point := boris.get_global_rect().get_center()
	await move_pointer(point)
	await mouse_button(point,true)
	await mouse_button(point,false)
	var info: Button = hud._unlock_panel.find_child("UnlockDescriptionButton",true,false)
	check(info.is_visible_in_tree(),mode+" locked Boris card exposes overview action")
	info.pressed.emit()
	var dialog = hud.get_node("EntityDescriptionDialog")
	check(dialog.visible and dialog.dialog_text == EntityDescription.text(GameData.get_unit("BORIS")),mode+" locked card opens correct overview")
	dialog.hide()
	dialog.free()
	hud._close_unlock_panel()
	for id in ["NACNST","E2","HTNK"]:
		var entity
		if id == "NACNST":
			entity = battle.buildings.filter(func(b):return b.building_id == id and b.side == "ally")[0]
			battle.select_building(entity)
		else:
			entity = battle.spawn_unit(id,"ally",Vector2(900,1800))
			battle.select_unit(entity,false)
		battle._emit_selection()
		if hud.unit_menu_collapsed: hud._toggle_unit_menu()
		await settle()
		var wanted := EntityDescription.text(entity.data)
		var labels: Array = hud.sel_box.find_children("*", "Label", true, false)
		check(labels.any(func(label): return label.is_visible_in_tree() and label.tooltip_text.begins_with(wanted)), mode + " selected overview " + id)
		hud._toggle_unit_menu()
		await settle()
		if not hud.production_collapsed:
			hud.set_production_collapsed(true, false)
			await settle()
		check(hud.sel_strip_title.is_visible_in_tree() and hud.sel_strip_title.tooltip_text == wanted, mode + " compact overview " + id)
	screen.free()
	await get_tree().process_frame
	var meta = load("res://scenes/meta.tscn").instantiate()
	meta.initial_page = "units"
	stage.add_child(meta)
	meta._unit_sel = "SHK"
	meta._rebuild_unit_detail()
	await settle()
	var copy := EntityDescription.text(GameData.get_unit("SHK"))
	check(meta.unit_detail.find_children("*","Label",true,false).any(func(label):return label.text == copy and label.is_visible_in_tree()),mode+" upgrade page shows Tesla Trooper overview")
	meta.free()
	await get_tree().process_frame
