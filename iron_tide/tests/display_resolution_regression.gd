extends "res://tests/input_ownership_regression.gd"

func exercise_mode(mode: String) -> void:
	stage.size = Vector2i(2560, 1440)
	stage.size_2d_override = Vector2i(1600, 900)
	stage.size_2d_override_stretch = true
	BattleRequest.configure_skirmish(mode, {"map_size": 3200, "starting_funds": 7600})
	screen = load("res://scenes/battle.tscn").instantiate()
	stage.add_child(screen)
	battle = screen.battle
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	battle.process_mode = Node.PROCESS_MODE_ALWAYS
	battle.set_process(false)
	battle.set_physics_process(false)
	for child in battle.get_children(): child.process_mode = Node.PROCESS_MODE_DISABLED
	var hud = screen.hud
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	hud.set_process(false)
	get_window().focus_entered.emit()
	for i in 6: await get_tree().process_frame
	check(stage.get_texture().get_size() == Vector2(2560, 1440), mode + ": actual render target is 1440p")
	check(stage.get_visible_rect().size == Vector2(1600, 900), mode + ": UI keeps readable design dimensions")
	check(Rect2(0, 0, 1600, 900).encloses(hud.prod_panel.get_global_rect()), mode + ": sidebar fits scaled viewport")
	var tank = battle.spawn_unit("MTNK", "ally", Vector2(1600, 1600))
	tank.process_mode = Node.PROCESS_MODE_DISABLED
	await get_tree().process_frame
	place_art_at(tank, Vector2(650, 400))
	await move_pointer(Vector2(650, 400))
	await mouse_button(Vector2(650, 400), true)
	await mouse_button(Vector2(650, 400), false)
	check(battle.selected_units.has(tank), mode + ": scaled battlefield picking matches rendered unit")
	await gesture(Vector2(600, 350), Vector2(700, 450))
	check(battle.selected_units.has(tank), mode + ": scaled drag selection still works")
	var factory = battle._place_building("GAWEAP", "ally", Vector2(1200, 1800), true)
	factory._buildup_play = -1.0
	battle.select_building(factory)
	hud.select_prod_tab("vehicle")
	hud._refresh_production()
	for i in 6: await get_tree().process_frame
	var card: Button = hud._prod_buttons["MTNK"]
	hud._prod_scroll.ensure_control_visible(card)
	for i in 3: await get_tree().process_frame
	var at := card.get_global_rect().get_center()
	await move_pointer(at)
	check(hud._production_inspector.title.text == "灰熊坦克", mode + ": scaled hover reaches sidebar details")
	await mouse_button(at, true)
	await mouse_button(at, false)
	check(factory.production == ["MTNK"], mode + ": scaled production click reaches correct card")
	Ra3Skin.upgrade_tree(hud.prod_panel, UiKit.RA_CYAN)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var picture := stage.get_texture().get_image()
		check(picture.get_size() == Vector2i(2560, 1440), mode + ": screenshot contains 2560x1440 pixels")
		picture.save_png(output_dir.path_join(mode + "-1440p.png"))
	check(ProjectSettings.get_setting("display/window/size/window_width_override") == 2560 and ProjectSettings.get_setting("display/window/size/window_height_override") == 1440, mode + ": default 1440p target")
	check(ProjectSettings.get_setting("display/window/size/mode") == Window.MODE_WINDOWED, mode + ": default windowed startup")
	check(ProjectSettings.get_setting("display/window/stretch/mode") == "canvas_items", mode + ": native canvas rendering instead of low-resolution framebuffer upscale")
	screen.free()
	await get_tree().process_frame
