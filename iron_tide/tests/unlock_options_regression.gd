extends "res://tests/unlock_navigation_regression.gd"

func exercise_mode(mode: String) -> void:
	BattleRequest.configure_skirmish(mode, {"map_size": 3200, "starting_funds": 20000, "country": "德国"})
	screen = load("res://scenes/battle.tscn").instantiate()
	stage.add_child(screen)
	battle = screen.battle
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	battle.process_mode = Node.PROCESS_MODE_ALWAYS
	battle.set_process(false)
	battle.set_physics_process(false)
	for child in battle.get_children():
		child.process_mode = Node.PROCESS_MODE_DISABLED
	var hud = screen.hud
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	hud.set_process(false)
	GM.infinite_funds = false
	battle.funds = 20000
	var factory = battle._place_building("GAWEAP", "ally", Vector2(1200, 1800), true)
	factory.process_mode = Node.PROCESS_MODE_DISABLED
	factory._buildup_play = -1.0
	# A surviving lab after losing radar makes either replacement radar viable.
	var lab = battle._place_building("GATECH", "ally", Vector2(1600, 1800), true)
	lab.process_mode = Node.PROCESS_MODE_DISABLED
	lab._buildup_play = -1.0
	hud.select_prod_tab("vehicle")
	await refresh_reasons()
	get_window().focus_entered.emit()
	var prefix := mode + ": "
	await tap(hud._prod_buttons["TNKD"])
	var panel = hud._unlock_panel
	var alternatives = panel.get("alternative_buttons")
	check(alternatives != null and alternatives.has("RADAR:GASPYSAT"),
		prefix + "missing radar offers an explicit satellite alternative")
	if alternatives == null or not alternatives.has("RADAR:GASPYSAT"):
		screen.free()
		await get_tree().process_frame
		return
	check(not alternatives["RADAR:GASPYSAT"].disabled and not alternatives["RADAR:GAAIRC"].disabled,
		prefix + "both radar replacements are feasible with an existing lab")
	await tap(alternatives["RADAR:GASPYSAT"])
	check(panel.route_buttons.has("GASPYSAT") and not panel.route_buttons.has("GAAIRC"),
		prefix + "choosing satellite updates the build route")
	check(panel.alternative_buttons["RADAR:GASPYSAT"].button_pressed,
		prefix + "selected alternative visibly marked")
	check(panel.alternative_buttons["RADAR:GASPYSAT"].text.begins_with("已选："),
		prefix + "selected branch has an explicit text marker")
	await tap(panel.alternative_buttons["RADAR:GASPYSAT"])
	check(panel.alternative_buttons["RADAR:GASPYSAT"].button_pressed,
		prefix + "clicking selected option does not leave radio group empty")
	hud._choose_unlock_alternative("RADAR", "GTGCAN")
	check(hud._unlock_choices.get("RADAR") == "GASPYSAT", prefix + "unlisted alternative cannot alter the route")
	var tip: String = hud._prod_buttons["TNKD"].tooltip_text
	check("建造间谍卫星" in tip and not "建造空指部" in tip, prefix + "source tooltip follows selected route", tip)
	check(hud.prod_tab == "vehicle" and battle.funds == 20000 and battle.struct_queue.is_empty(),
		prefix + "alternative choice neither navigates nor purchases")
	await RenderingServer.frame_post_draw
	stage.get_texture().get_image().save_png(output_dir.path_join(mode + "-selected-satellite.png"))
	await refresh_reasons()
	check(panel.route_buttons.has("GASPYSAT"), prefix + "selected branch survives refresh")
	await tap(panel.back_button)
	check(panel.route_buttons.has("GASPYSAT"), prefix + "selected branch survives returning to source")
	# Queue preservation: selecting the other option is only a planning choice.
	battle.request_structure("GAAIRC")
	battle._tick_structure_jobs(1.0, battle.struct_queue, battle.struct_ready, "ally")
	var jobs: Array = battle.struct_queue.duplicate(true)
	var funds: float = battle.funds
	await refresh_reasons()
	check(panel.route_buttons.has("GASPYSAT"), prefix + "manual choice remains explicit despite another pending option")
	await tap(panel.alternative_buttons["RADAR:GAAIRC"])
	check(panel.route_buttons.has("GAAIRC") and "建造中" in panel.route_buttons["GAAIRC"].text,
		prefix + "queued option can be selected with its actual state")
	check(battle.struct_queue == jobs and battle.funds == funds, prefix + "changing option preserves paid queue exactly")
	await tap(panel.alternative_buttons["RADAR:GASPYSAT"])
	battle.cancel_structure("GAAIRC")
	# Removing the lab makes satellite depend on the missing radar again.
	lab._die()
	await get_tree().process_frame
	await refresh_reasons()
	check(panel.route_buttons.has("GAAIRC") and "不可用" in panel.message.text,
		prefix + "invalidated choice falls back with an explanation")
	check(panel.alternative_buttons["RADAR:GASPYSAT"].disabled,
		prefix + "cyclic technology route cannot be selected")
	await tap(panel.alternative_buttons["RADAR:GASPYSAT"])
	check("依赖" in panel.message.text and panel.route_buttons.has("GAAIRC"),
		prefix + "disabled branch click explains why without changing the route")
	hud._choose_unlock_alternative("RADAR", "GASPYSAT")
	check(panel.route_buttons.has("GAAIRC"), prefix + "direct stale selection is rejected")
	# Any actual alternative satisfies technology regardless of the chosen plan.
	var radar = battle._place_building("GAAIRC", "ally", Vector2(1800, 1800), true)
	radar.process_mode = Node.PROCESS_MODE_DISABLED
	radar._buildup_play = -1.0
	await refresh_reasons()
	check(panel.route_buttons.is_empty() and panel.alternative_buttons.is_empty()
		and "科技条件已满足" in panel.message.text, prefix + "actual completed alternative unlocks regardless of preference")
	check(not hud._prod_buttons["TNKD"].disabled, prefix + "preference is not an extra production prerequisite")
	await tap(panel.close_button)
	check(hud._unlock_choices.is_empty(), prefix + "closing guide clears per-goal choices")
	radar._die()
	await get_tree().process_frame
	hud.select_prod_tab("building")
	await refresh_reasons()
	await tap(hud._prod_buttons["GATECH"])
	check(panel.alternative_buttons.has("RADAR:GASPYSAT") and panel.alternative_buttons["RADAR:GASPYSAT"].disabled,
		prefix + "lab does not advertise satellite as its own unlock route")
	stage.size = Vector2i(1280, 720)
	for i in 4:
		await get_tree().process_frame
	await refresh_reasons()
	check(panel.size.y <= 270 and hud._prod_scroll.size.y >= 80,
		prefix + "branch choices share bounded scroll area on small viewport")
	await RenderingServer.frame_post_draw
	stage.get_texture().get_image().save_png(output_dir.path_join(mode + "-unlock-options.png"))
	screen.free()
	await get_tree().process_frame
	stage.size = Vector2i(1600, 900)
