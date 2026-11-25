extends "res://tests/input_ownership_regression.gd"

var messages: Array[String] = []

func record_message(message: String, _color: Color) -> void:
	messages.append(message)

func last_message() -> String:
	return messages.back() if not messages.is_empty() else ""

func refresh_reasons() -> void:
	screen.hud._refresh_production()
	for i in 3:
		await get_tree().process_frame

func exercise_mode(mode: String) -> void:
	BattleRequest.configure_skirmish(mode, {"map_size": 3200, "starting_funds": 7600,
		"country": "德国"})
	screen = load("res://scenes/battle.tscn").instantiate()
	stage.add_child(screen)
	battle = screen.battle
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	var hud = screen.hud
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	hud.set_process(false)
	GM.infinite_funds = false
	battle.power_low = false
	battle.funds = 7600
	Events.battle_message.connect(record_message)
	var factory = battle._place_building("GAWEAP", "ally", Vector2(1200, 1800), true)
	factory._buildup_play = -1.0
	battle.select_building(factory)
	hud.select_prod_tab("vehicle")
	await refresh_reasons()
	var prefix := mode + ": "
	var button: Button = hud._prod_buttons["TNKD"]
	check(button.disabled, prefix + "tank destroyer requires radar despite 7600 funds")
	check("空指部" in button.tooltip_text, prefix + "tooltip names missing radar", button.tooltip_text)
	check("空指部" in hud._prod_status_labels["TNKD"].text, prefix + "card names missing prerequisite")
	messages.clear()
	hud._queue("TNKD")
	check("空指部" in last_message() and not "资金不足" in last_message(), prefix + "rejection names prerequisite", last_message())
	check(factory.production.is_empty() and battle.funds == 7600, prefix + "rejection preserves money and queue")
	messages.clear()
	hud._explain_disabled_cameo("TNKD")
	check("空指部" in last_message(), prefix + "disabled card handler explains reason", last_message())
	messages.clear()
	# Opening the persistent guide changes container layout; aim at the
	# rendered card position after layout, not its previous frame's bounds.
	await refresh_reasons()
	var at := button.get_global_rect().get_center()
	await move_pointer(at)
	await mouse_button(at, true)
	await mouse_button(at, false)
	check("空指部" in last_message(), prefix + "disabled mouse click explains reason", last_message())
	var radar = battle._place_building("GAAIRC", "ally", Vector2(1600, 1800), false)
	await refresh_reasons()
	check(hud._prod_buttons["TNKD"].disabled, prefix + "unfinished radar does not unlock unit")
	radar.under_construction = false
	radar._buildup_play = -1.0
	await refresh_reasons()
	check(not hud._prod_buttons["TNKD"].disabled, prefix + "finished prerequisite unlocks card")
	check(not "缺少前置" in hud._prod_buttons["TNKD"].tooltip_text, prefix + "old reason removed after unlock")
	hud._queue("TNKD")
	check(factory.production == ["TNKD"] and battle.funds == 7600, prefix + "valid order retains deferred payment")
	factory.cancel_at(0)
	factory.under_construction = true
	await refresh_reasons()
	messages.clear()
	hud._queue("TNKD")
	check("施工" in last_message(), prefix + "factory construction explained", last_message())
	factory.under_construction = false
	for i in factory.MAX_QUEUE:
		factory.enqueue("TNKD")
	await refresh_reasons()
	check("队列已满" in hud._prod_buttons["TNKD"].tooltip_text, prefix + "full queue shown before click")
	messages.clear()
	hud._queue("TNKD")
	check("队列已满" in last_message() and not "资金不足" in last_message(), prefix + "full queue explained")
	while not factory.production.is_empty():
		factory.cancel_at(0)
	await refresh_reasons()
	button = hud._prod_buttons["TNKD"]
	battle.funds = 800
	await refresh_reasons()
	check(button == hud._prod_buttons["TNKD"], prefix + "reason refresh preserves button identity")
	check(not hud._prod_buttons["TNKD"].disabled and "尚差 100" in hud._prod_buttons["TNKD"].tooltip_text and "可下单" in hud._prod_buttons["TNKD"].tooltip_text, prefix + "short funds informs without blocking")
	messages.clear()
	get_window().focus_entered.emit()
	at = hud._prod_buttons["TNKD"].get_global_rect().get_center()
	await move_pointer(at)
	await mouse_button(at, true)
	await mouse_button(at, false)
	check(factory.production == ["TNKD"] and battle.funds == 800, prefix + "real click queues without upfront full price")
	factory._process(100.0)
	check(factory.production == ["TNKD"] and is_zero_approx(battle.funds) and is_equal_approx(factory.production_paid, 800.0), prefix + "only available funds advance production without free completion")
	var elapsed: float = factory.progress
	factory._process(100.0)
	check(factory.progress == elapsed and factory.production_paid == 800.0, prefix + "zero funds freezes production")
	await refresh_reasons()
	check("资金不足" in hud._queue_caption(factory), prefix + "stalled queue explains waiting funds")
	hud._queue("TNKD")
	check(factory.production == ["TNKD", "TNKD"] and battle.funds == 0.0, prefix + "zero funds allows waiting order")
	factory.cancel_at(1)
	check(battle.funds == 0.0 and factory.production_paid == 800.0, prefix + "unpaid order cannot create a refund")
	factory.cancel_at(0)
	check(is_equal_approx(battle.funds, 800.0), prefix + "partial production refunds paid amount only")
	battle.funds = 7600
	for i in 8:
		factory.enqueue("TNKD")
	messages.clear()
	hud._queue("TNKD", 5)
	check("已加入 1/5" in last_message() and "队列已满" in last_message(), prefix + "partial batch explains accepted count and stop")
	while not factory.production.is_empty():
		factory.cancel_at(0)
	hud.select_prod_tab("air")
	for i in 4:
		radar.enqueue("ORCA")
	await refresh_reasons()
	check("停机位已满" in hud._prod_buttons["ORCA"].tooltip_text, prefix + "aircraft reservations explain full capacity")
	messages.clear()
	hud._queue("ORCA")
	check("停机位已满" in last_message(), prefix + "aircraft rejection explains capacity", last_message())
	radar.cancel_at(0)
	await refresh_reasons()
	check(not hud._prod_buttons["ORCA"].disabled, prefix + "cancelling aircraft frees capacity")
	# Weather Control belongs to BuildCat=Combat (the defense tab).
	hud.select_prod_tab(battle.structure_category("GAWEAT"))
	check(hud.prod_tab == "defense", prefix + "superweapon prerequisite checked in actual production category")
	await refresh_reasons()
	check("作战实验室" in hud._prod_buttons["GAWEAT"].tooltip_text, prefix + "building prerequisite is named")
	messages.clear()
	hud._start_build("GAWEAT")
	check("作战实验室" in last_message(), prefix + "building attempt explains exact prerequisite", last_message())
	messages.clear()
	battle.request_structure("GAWEAT")
	check("作战实验室" in last_message(), prefix + "direct build menu shares prerequisite names")
	hud.select_prod_tab("vehicle")
	factory.enqueue("TNKD")
	radar._die()
	await get_tree().process_frame
	await refresh_reasons()
	check(hud._prod_buttons["TNKD"].disabled and "空指部" in hud._prod_buttons["TNKD"].tooltip_text,
		prefix + "destroyed prerequisite immediately relocks with reason")
	check("空指部" in hud._queue_caption(factory) and not "剩" in hud._queue_caption(factory),
		prefix + "existing queue explains prerequisite loss without false ETA")
	var old_progress: float = factory.progress
	factory._process(0.1)
	check(factory.progress == old_progress, prefix + "queue stop reason matches actual stalled progress")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		stage.get_texture().get_image().save_png(output_dir.path_join(mode + "-production-reasons.png"))
	factory._die()
	await get_tree().process_frame
	await refresh_reasons()
	messages.clear()
	hud._queue("TNKD")
	check("战车工厂" in last_message(), prefix + "missing producer names required building", last_message())
	Events.battle_message.disconnect(record_message)
	screen.free()
	await get_tree().process_frame
