extends "res://tests/selection_regression.gd"

func texts(node: Node) -> String:
	var result := str(node.text) if node is Label else ""
	for child in node.get_children():
		result += "\n" + texts(child)
	return result

func refresh_hud() -> void:
	screen.hud._refresh_top()
	screen.hud._refresh_production()
	for i in 3:
		await get_tree().process_frame

func exercise_mode(mode: String) -> void:
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
	var hud = screen.hud
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	hud.set_process(false)
	var prefix := mode + ": "
	battle.funds = 8000.0
	battle.power_low = false
	battle.power_produced = 50.0
	battle.power_drain = 100.0
	battle.request_structure("GAPOWR")
	battle.request_structure("GAPILE")
	var duration := GameData.ra2_build_time(GameData.get_building("GAPOWR"))
	battle._tick_structure_queue(duration * 0.5)
	hud.select_prod_tab("building")
	await refresh_hud()
	check("建造中" in texts(hud._prod_buttons["GAPOWR"]), prefix + "card shows construction state without hovering")
	check("排队" in texts(hud._prod_buttons["GAPILE"]), prefix + "waiting building has queue status")
	check(not hud._prod_buttons["GAPOWR"].disabled, prefix + "live refresh allows another building order")
	var same_button = hud._prod_buttons["GAPOWR"]
	var saved_funds: float = battle.funds
	battle.funds = 0.0
	var progress_before: float = battle.current_structure_job().elapsed
	battle._tick_structure_queue(2.0)
	await refresh_hud()
	check(battle.current_structure_job().elapsed == progress_before, prefix + "insufficient funds actually stalls building")
	check("资金不足" in texts(hud._prod_buttons["GAPOWR"]), prefix + "stalled building explains funds")
	check(same_button == hud._prod_buttons["GAPOWR"], prefix + "status refresh preserves button identity")
	await capture(mode + "-funds")
	battle.funds = saved_funds
	battle.power_low = true
	check(battle.power_build_factor() < 1.0, prefix + "fixture has an actual power deficit")
	progress_before = battle.current_structure_job().elapsed
	battle._tick_structure_queue(1.0)
	check(is_equal_approx(float(battle.current_structure_job().elapsed) - progress_before, battle.power_build_factor()),
		prefix + "low power actually slows building progress")
	await refresh_hud()
	check("缺电" in texts(hud._prod_buttons["GAPOWR"]), prefix + "low power shows slowdown")
	get_tree().paused = true
	await refresh_hud()
	check("已暂停" in texts(hud._prod_buttons["GAPOWR"]), prefix + "pause overrides production status")
	get_tree().paused = false
	battle.power_low = false
	battle._tick_structure_queue(duration)
	await refresh_hud()
	check("就绪" in texts(hud._prod_buttons["GAPOWR"]), prefix + "ready building clearly labelled")
	battle.request_structure("GAPOWR")
	await refresh_hud()
	check("选址中" in texts(hud._prod_buttons["GAPOWR"]), prefix + "armed building labelled")
	await capture(mode + "-ready")
	battle._tick_structure_queue(GameData.ra2_build_time(GameData.get_building("GAPILE")))
	battle.request_structure("GAPILE")
	check(battle.armed_build == "GAPILE" and battle.struct_ready["GAPOWR"] == 1,
		prefix + "switching ready type preserves previous inventory")
	hud._cancel_build("GAPOWR")
	check(battle.armed_build == "GAPILE", prefix + "cancel other stock preserves active placement")
	var refund_before: float = battle.funds
	hud._cancel_build("GAPILE")
	check(battle.armed_build.is_empty() and not battle.struct_ready.has("GAPILE"),
		prefix + "refunding last armed building exits placement")
	check(is_equal_approx(battle.funds - refund_before, float(GameData.get_building("GAPILE").cost)),
		prefix + "last ready refund remains exact")
	refund_before = battle.funds
	hud._cancel_build("GAPILE")
	check(battle.funds == refund_before, prefix + "repeated cancellation never refunds twice")
	var count_after_cancel: int = battle.buildings.size()
	battle._try_place_building(Vector2(800, 800))
	check(battle.buildings.size() == count_after_cancel and battle.funds == refund_before,
		prefix + "cancelled placement cannot enter legacy construction")
	battle.armed_build = ""
	battle.request_structure("GAPOWR")
	battle._tick_structure_queue(duration)
	battle.request_structure("GAPOWR")
	hud.armed_escape()
	check(battle.armed_build.is_empty() and battle.struct_ready.get("GAPOWR", 0) == 1,
		prefix + "Escape preserves paid ready building")
	var producer
	for node in battle.buildings:
		if node.side == "ally" and node.building_id == "GAPILE":
			producer = node
	check(producer != null, prefix + "actual barracks fixture")
	if producer != null:
		producer._buildup_play = -1.0
		battle.selected_building = producer
		producer.enqueue("E1")
		producer.progress = 1.0
		hud.select_prod_tab("infantry")
		battle.funds = 0.0
		var before_unit: float = producer.progress
		producer._process(0.2)
		await refresh_hud()
		check(producer.progress == before_unit, prefix + "unit production actually stalls without funds")
		check("资金不足" in hud._queue_caption(producer), prefix + "unit queue explains funds stall")
		check(not "剩" in hud._queue_caption(producer), prefix + "stalled unit has no misleading countdown")
		battle.funds = 5000.0
		battle.power_low = true
		await refresh_hud()
		check("缺电" in hud._queue_caption(producer), prefix + "unit queue reports low power")
		await capture(mode + "-power")
		get_tree().paused = true
		await refresh_hud()
		check("已暂停" in hud._queue_caption(producer), prefix + "unit queue reports pause")
		get_tree().paused = false
		battle.power_low = false
		producer.build_speed = 2.0
		var unit_duration := GameData.ra2_build_time(GameData.get_unit("E1"))
		producer.progress = unit_duration * 0.25
		await refresh_hud()
		check("生产中" in hud._queue_caption(producer), prefix + "unit queue resumes normal status")
		var seconds := int(ceil(unit_duration * 0.25))
		check(("剩 %ds" % seconds) in hud._queue_caption(producer),
			prefix + "ETA accounts for double production speed", hud._queue_caption(producer))
		battle.power_low = true
		var normal_seconds := seconds
		seconds = int(ceil(unit_duration * 0.25 / battle.power_build_factor()))
		check(seconds > normal_seconds, prefix + "power deficit increases remaining time")
		check(("剩 %ds" % seconds) in hud._queue_caption(producer),
			prefix + "ETA accounts for low power slowdown", hud._queue_caption(producer))
		producer.powered = true
		check("缺电停工" in hud._queue_caption(producer) and not "剩" in hud._queue_caption(producer),
			prefix + "powered factory offline has no countdown")
	screen.free()
	await get_tree().process_frame

func capture(label: String) -> void:
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		check(stage.get_texture().get_image().save_png(output_dir.path_join(label + ".png")) == OK,
			"save " + label)
