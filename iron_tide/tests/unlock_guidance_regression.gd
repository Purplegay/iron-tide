extends "res://tests/production_reason_regression.gd"

func exercise_mode(mode: String) -> void:
	BattleRequest.configure_skirmish(mode, {"map_size": 3200, "starting_funds": 20000, "country": "德国"})
	screen = load("res://scenes/battle.tscn").instantiate()
	stage.add_child(screen)
	battle = screen.battle
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	var hud = screen.hud
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	hud.set_process(false)
	GM.infinite_funds = false
	battle.funds = 20000
	Events.battle_message.connect(record_message)
	hud.select_prod_tab("vehicle")
	await refresh_reasons()
	var prefix := mode + ": "
	var tip: String = hud._prod_buttons["SREF"].tooltip_text
	check("解锁条件" in tip, prefix + "locked unit exposes unlock checklist")
	check("战车工厂" in tip and "作战实验室" in tip, prefix + "missing producer does not mask technology")
	check("参考建造顺序" in tip and "空指部" in tip, prefix + "transitive radar prerequisite is explained")
	check(tip.find("空指部", tip.find("参考建造顺序")) < tip.find("作战实验室", tip.find("参考建造顺序")),
		prefix + "radar precedes lab in suggested order", tip)
	messages.clear()
	hud._explain_disabled_cameo("SREF")
	check("空指部" in last_message() and "解锁顺序" in last_message(), prefix + "disabled card activation explains path", last_message())
	check(battle.funds == 20000, prefix + "guidance is read only")
	await capture_tooltip("SREF", mode + "-locked-prism")
	var factory = battle._place_building("GAWEAP", "ally", Vector2(1200, 1800), true)
	factory._buildup_play = -1.0
	await refresh_reasons()
	tip = hud._prod_buttons["SREF"].tooltip_text
	check("[已满足] 盟军战车工厂" in tip, prefix + "finished producer checked")
	check("[未建造] 盟军作战实验室" in tip, prefix + "missing lab remains visible")
	hud.select_prod_tab("building")
	await refresh_reasons()
	check("空指部 / 间谍卫星（任一）" in hud._prod_buttons["GATECH"].tooltip_text,
		prefix + "alternative prerequisites explicitly say any")
	messages.clear()
	hud._start_build("GATECH")
	check("解锁顺序" in last_message() and "空指部" in last_message(),
		prefix + "building activation explains missing route")
	var enemy_radar = battle._place_building("GAAIRC", "enemy", Vector2(2200, 1800), true)
	enemy_radar._buildup_play = -1.0
	await refresh_reasons()
	check("[未建造] 空指部" in hud._prod_buttons["GATECH"].tooltip_text,
		prefix + "enemy radar cannot satisfy unlock checklist")
	# Queue-state guidance requires the explicitly unlocked reservation branch.
	check(not battle.structure_reservations_enabled(), prefix + "reservation guidance starts from locked default")
	battle.production_technology.unlock("structure_queue", "ally")
	battle.request_structure("GAPOWR")
	battle.request_structure("GAAIRC")
	check(battle.structure_jobs("building").size() == 2, prefix + "unlocked reservation fixture creates both orders")
	await refresh_reasons()
	check("[排队中]" in hud._prod_buttons["GATECH"].tooltip_text, prefix + "waiting structure queue is explained")
	battle.cancel_structure("GAPOWR")
	await refresh_reasons()
	check("[建造中]" in hud._prod_buttons["GATECH"].tooltip_text, prefix + "active structure queue is explained")
	battle.cancel_structure("GAAIRC")
	battle.struct_ready["GAAIRC"] = 1
	await refresh_reasons()
	check("[待放置]" in hud._prod_buttons["GATECH"].tooltip_text, prefix + "ready but unplaced is not unlocked")
	battle.struct_ready.erase("GAAIRC")
	var radar = battle._place_building("GAAIRC", "ally", Vector2(1500, 1800), false)
	await refresh_reasons()
	check("[施工中]" in hud._prod_buttons["GATECH"].tooltip_text, prefix + "placed construction explained")
	check(hud._prod_buttons["GATECH"].disabled, prefix + "unfinished radar cannot unlock lab")
	await capture_tooltip("GATECH", mode + "-building-radar")
	radar.under_construction = false
	radar._buildup_play = -1.0
	await refresh_reasons()
	check(not hud._prod_buttons["GATECH"].disabled, prefix + "finished radar unlocks lab")
	var lab = battle._place_building("GATECH", "ally", Vector2(1800, 1800), true)
	lab._buildup_play = -1.0
	hud.select_prod_tab("vehicle")
	await refresh_reasons()
	tip = hud._prod_buttons["SREF"].tooltip_text
	check("科技条件已满足" in tip and not "参考建造顺序" in tip, prefix + "unlocked checklist removes stale guidance")
	check(not hud._prod_buttons["SREF"].disabled, prefix + "unlocked unit can queue")
	battle.funds = 0
	await refresh_reasons()
	tip = hud._prod_buttons["SREF"].tooltip_text
	check(not hud._prod_buttons["SREF"].disabled and "可下单" in tip and "资金耗尽时等待" in tip and "科技条件已满足" in tip,
		prefix + "deferred payment shortage remains distinct from technology unlock", tip)
	battle.funds = 20000
	lab._die()
	await get_tree().process_frame
	await refresh_reasons()
	check("[未建造] 盟军作战实验室" in hud._prod_buttons["SREF"].tooltip_text, prefix + "destroyed prerequisite relocks guide")
	# A valid existing alternate radar should satisfy the rule even if the
	# primary airport is gone; no new airport should be suggested.
	radar._die()
	var satellite = battle._place_building("GASPYSAT", "ally", Vector2(1900, 2100), true)
	satellite._buildup_play = -1.0
	hud.select_prod_tab("building")
	await refresh_reasons()
	tip = hud._prod_buttons["GATECH"].tooltip_text
	check("[已满足] 空指部 / 间谍卫星（任一）" in tip and not "参考建造顺序" in tip,
		prefix + "owned alternative removes unnecessary airport suggestion")
	hud.select_prod_tab("vehicle")
	await refresh_reasons()
	var original_button: Button = hud._prod_buttons["SREF"]
	await refresh_reasons()
	check(original_button == hud._prod_buttons["SREF"], prefix + "guidance refresh preserves production button")
	# Exercise a long route from a destroyed base. It must terminate, deduplicate
	# shared dependencies and present a bounded-width tooltip.
	for building in battle.buildings.duplicate():
		if is_instance_valid(building) and building.side == "ally" and not building.is_dead():
			building._die()
	await get_tree().process_frame
	await refresh_reasons()
	tip = hud._prod_buttons["SREF"].tooltip_text
	var path := tip.substr(tip.find("参考建造顺序"))
	check(path.count("恢复盟军建造场") == 1 and path.count("建造发电厂") == 1,
		prefix + "shared dependencies appear once in recovery route", path)
	await capture_tooltip("SREF", mode + "-recovery-chain")
	hud.select_prod_tab("infantry")
	await refresh_reasons()
	tip = hud._prod_buttons["SNIPE"].tooltip_text
	if mode == MatchRules.RA2:
		check("仅限英国" in tip and "本局无法通过建造解锁" in tip, prefix + "country restriction cannot be solved by tech")
	else:
		check(not "本局无法通过建造解锁" in tip, prefix + "extension roster remains open")
	Events.battle_message.disconnect(record_message)
	screen.free()
	await get_tree().process_frame

func capture_tooltip(uid: String, filename: String) -> void:
	# Render the exact production tooltip factory in the isolated viewport;
	# this checks its layout without depending on the OS tooltip popup timer.
	var button: Button = screen.hud._prod_buttons[uid]
	var panel: Control = button._make_custom_tooltip(button.tooltip_text)
	screen.hud.add_child(panel)
	panel.position = Vector2(650, 90)
	for i in 3:
		await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	check(panel.size.x <= 440 and panel.size.y <= 700, filename + ": tooltip fits viewport", str(panel.size))
	check(panel.get_child(0).text == button.tooltip_text, filename + ": rendered tooltip uses live requirements")
	if DisplayServer.get_name() != "headless":
		stage.get_texture().get_image().save_png(output_dir.path_join(filename + ".png"))
	panel.free()
