extends "res://tests/dual_build_regression.gd"

func tab_image(id: String, phase: float, name: String = "") -> Image:
	var hud = screen.hud
	hud._ready_tab_phase = phase
	hud._update_ready_tabs(0.0)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := stage.get_texture().get_image()
	if not name.is_empty(): image.save_png(output_dir.path_join(name + ".png"))
	var rect: Rect2 = hud.deck_tabs_btns[id].get_global_rect()
	return image.get_region(Rect2i(rect))

func changed_pixels(a: Image, b: Image) -> int:
	var changed := 0
	for y in a.get_height():
		for x in a.get_width():
			var diff := a.get_pixel(x, y) - b.get_pixel(x, y)
			if absf(diff.r) + absf(diff.g) + absf(diff.b) > 0.08: changed += 1
	return changed

func exercise_mode(mode: String) -> void:
	BattleRequest.configure_skirmish(mode, {"map_size": 3200, "starting_funds": 50000})
	screen = load("res://scenes/battle.tscn").instantiate()
	stage.add_child(screen)
	battle = screen.battle
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	var hud = screen.hud
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	hud.set_process(false)
	for b in battle.buildings: b._buildup_play = -1.0
	battle.power_low = false
	battle.production_technology.unlock("structure_queue", "ally")
	var prefix := mode + ": "
	var button: Button = hud.deck_tabs_btns.defense
	hud.select_prod_tab("defense")
	await refresh()
	var empty_bright := await tab_image("defense", 0.0)
	var empty_dim := await tab_image("defense", 0.5)
	check(changed_pixels(empty_bright, empty_dim) == 0, prefix + "idle tab does not blink")
	battle.request_structure("GAPOWR")
	battle.request_structure("GAPILE")
	battle.request_structure("GAPILL")
	battle._tick_structure_queue(1.0)
	await refresh()
	check(not "就绪" in button.tooltip_text, prefix + "in-progress production has no ready alert")
	battle._tick_structure_queue(1000.0)
	await refresh()
	check("1 项建造就绪" in button.tooltip_text and "1 项建造就绪" in hud.deck_tabs_btns.building.tooltip_text,
		prefix + "both categories receive independent ready reminders")
	var bright := await tab_image("defense", 0.0, mode + "-selected-bright")
	var dim := await tab_image("defense", 0.5, mode + "-selected-dim")
	var changed := changed_pixels(bright, dim)
	check(changed > 300, prefix + "selected defense tab visibly pulses in rendered pixels", changed)
	check(button.button_pressed and button == hud.deck_tabs_btns.defense, prefix + "pulse preserves active state and button identity")
	# The regular skin refresh must not replace or hide the overlay.
	Ra3Skin.upgrade_tree(hud.deck_tabs, UiKit.RA_CYAN)
	var reskinned := await tab_image("defense", 0.0)
	check(changed_pixels(reskinned, bright) == 0, prefix + "skin refresh preserves ready flash")
	hud.select_prod_tab("vehicle")
	await refresh()
	bright = await tab_image("defense", 0.0, mode + "-other-tab-bright")
	dim = await tab_image("defense", 0.5)
	check(changed_pixels(bright, dim) > 300 and not button.button_pressed, prefix + "unselected ready tab also pulses")
	# Click the actual flashing tab, then the ready card; placement must not acknowledge it away.
	var at := button.get_global_rect().get_center()
	await move_pointer(at)
	await mouse_button(at, true)
	await mouse_button(at, false)
	check(hud.prod_tab == "defense", prefix + "flashing tab still receives real mouse input")
	await click_card("defense", "GAPILL")
	check(battle.armed_build == "GAPILL" and "就绪" in button.tooltip_text, prefix + "arming placement keeps ready reminder")
	battle._try_place_building(Vector2(-100, -100))
	await refresh()
	check("就绪" in button.tooltip_text, prefix + "invalid placement does not clear alert")
	var spot := placement("GAPILL")
	check(spot != Vector2.INF, prefix + "legal placement fixture exists")
	if spot != Vector2.INF: battle._try_place_building(spot)
	await refresh()
	bright = await tab_image("defense", 0.0)
	dim = await tab_image("defense", 0.5)
	check(changed_pixels(bright, dim) == 0 and not "就绪" in button.tooltip_text, prefix + "placing final defense stops its flash")
	check("就绪" in hud.deck_tabs_btns.building.tooltip_text, prefix + "defense placement leaves building alert intact")
	battle._tick_structure_queue(1000.0)
	await refresh()
	check("2 项建造就绪" in hud.deck_tabs_btns.building.tooltip_text, prefix + "multiple ready buildings counted")
	battle.cancel_structure("GAPOWR")
	await refresh()
	check("1 项建造就绪" in hud.deck_tabs_btns.building.tooltip_text, prefix + "partial cancellation keeps remaining alert")
	battle.cancel_structure("GAPILE")
	await refresh()
	bright = await tab_image("building", 0.0)
	dim = await tab_image("building", 0.5)
	check(changed_pixels(bright, dim) == 0 and not "就绪" in hud.deck_tabs_btns.building.tooltip_text, prefix + "cancelling final ready building clears flash")
	check(hud._ready_tab_phase == 0.0, prefix + "idle animation timer resets")
	screen.free()
	await get_tree().process_frame
