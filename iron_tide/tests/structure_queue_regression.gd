extends "res://tests/dual_build_regression.gd"

func exercise_mode(mode: String) -> void:
	BattleRequest.configure_skirmish(mode, {"map_size": 3200, "starting_funds": 50000})
	screen = load("res://scenes/battle.tscn").instantiate()
	stage.add_child(screen)
	battle = screen.battle
	# Reservation behavior is now the explicit technology-unlocked branch.
	battle.production_technology.unlock("structure_queue", "ally")
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	var hud = screen.hud
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	hud.set_process(false)
	for b in battle.buildings: b._buildup_play = -1.0
	battle.power_low = false
	battle.funds = 50000
	var prefix := mode + ": "
	await click_card("building", "GAPOWR")
	battle._tick_structure_queue(2.0)
	var head: Dictionary = battle.struct_queue[0]
	var saved := head.duplicate(true)
	var money: float = battle.funds
	await refresh()
	check(not hud._prod_buttons["GAPOWR"].disabled, prefix + "active building remains clickable")
	await click_card("building", "GAPOWR")
	await click_card("building", "GAREFN")
	await click_card("building", "GAPOWR")
	check(battle.struct_queue.size() == 4, prefix + "real clicks queue repeated and different buildings", battle.struct_queue.duplicate(true))
	check(head == saved and battle.funds == money, prefix + "new orders preserve active progress and charge only when worked")
	if battle.struct_queue.size() != 4:
		screen.free()
		return
	check(hud._prod_wipes["GAPOWR"].badge == 3, prefix + "cameo sums separated same-type jobs")
	check("左键追加" in hud._prod_buttons["GAPOWR"].tooltip_text, prefix + "active card explains repeat order")
	await click_card("building", "GAPOWR", MOUSE_BUTTON_RIGHT)
	check(battle.structure_is_paused("GAPOWR") and battle.struct_queue.size()==4,prefix+"first right click pauses head")
	await click_card("building", "GAPOWR", MOUSE_BUTTON_RIGHT)
	await click_card("building", "GAPOWR") # Resume the original paid head.
	check(battle.struct_queue.size() == 3 and battle.struct_queue[2].id == "GAREFN" and head == saved and battle.funds == money,
		prefix + "right click removes latest matching job without resetting active work")
	await click_card("defense", "GAPILL")
	await click_card("defense", "GAPILL")
	battle._tick_structure_queue(1.0)
	check(head.elapsed > saved.elapsed and job("GAPILL").elapsed > 0 and battle.struct_queue[1].elapsed == 0,
		prefix + "categories advance independently while repeated jobs stay FIFO")
	battle._tick_structure_queue(1000.0)
	check(int(battle.struct_ready.get("GAPOWR", 0)) == 1 and battle.structure_jobs("building").size() == 2,
		prefix + "completion promotes exactly one repeated job")
	battle._tick_structure_queue(1000.0)
	check(int(battle.struct_ready.get("GAPOWR", 0)) == 2 and int(battle.struct_ready.get("GAPILL", 0)) == 2,
		prefix + "repeated buildings accumulate ready inventory")
	money = battle.funds
	await click_card("building", "GAPOWR")
	check(battle.armed_build == "GAPOWR" and battle.funds == money and battle.structure_jobs("building").size() == 1,
		prefix + "ready click selects placement without an extra order or charge")
	var pos := placement("GAPOWR")
	check(pos != Vector2.INF, prefix + "fixture has legal building footprint")
	if pos != Vector2.INF:
		battle._try_place_building(pos)
		check(int(battle.struct_ready.get("GAPOWR", 0)) == 1 and battle.funds == money, prefix + "placement consumes one ready copy without charging again")
	await click_card("building", "GAPOWR", MOUSE_BUTTON_RIGHT)
	check(not battle.struct_ready.has("GAPOWR") and is_equal_approx(battle.funds - money, float(GameData.get_building("GAPOWR").cost)), prefix + "cancel last ready copy refunds its cost")
	# Check capacity and disabled-click reasons through the actual UI.
	battle.struct_queue.clear()
	battle.struct_ready.clear()
	battle.struct_ready_order.clear()
	battle.funds = 50000
	for i in 9: await click_card("building", "GAPOWR")
	check(battle.structure_jobs("building").size() == 9 and hud._prod_wipes["GAPOWR"].badge == 9, prefix + "nine same-type orders fill category capacity")
	check(hud._prod_buttons["GAPOWR"].disabled and "队列已满" in hud._prod_buttons["GAPOWR"].tooltip_text, prefix + "full active card explains capacity block")
	battle.request_structure("GAPOWR")
	check(battle.structure_jobs("building").size() == 9, prefix + "backend refuses tenth repeated job")
	await click_card("defense", "GAPILL")
	check(battle.structure_jobs("defense").size() == 1, prefix + "full building queue leaves defense available")
	await click_card("building", "GAPOWR", MOUSE_BUTTON_RIGHT)
	await click_card("building", "GAPOWR", MOUSE_BUTTON_RIGHT)
	await click_card("building", "GAPOWR")
	check(not hud._prod_buttons["GAPOWR"].disabled and battle.structure_jobs("building").size() == 8, prefix + "cancel frees capacity and re-enables repeat order")
	battle.funds = 0
	await refresh()
	check(not hud._prod_buttons["GAPOWR"].disabled, prefix + "installment order remains available with zero funds")
	hud._start_build("GAPOWR")
	check(battle.structure_jobs("building").size() == 9 and battle.funds == 0, prefix + "reservation is free until its work starts")
	battle.struct_queue.clear()
	battle.struct_ready.clear()
	battle.funds = 10000
	battle.request_structure("GAPOWR")
	battle.request_structure("GAPILL")
	battle._tick_structure_queue(1)
	battle.structure_right_click("GAPILL")
	GM.set_flag("no_build_time",true)
	battle._tick_structure_queue(0.06)
	check(battle.struct_ready.has("GAPOWR") and not battle.struct_ready.has("GAPILL"),prefix+"fast build finishes active building and respects paused defense")
	battle.resume_structure("GAPILL")
	var available: float = battle.funds
	battle.funds = 0
	battle._tick_structure_queue(0.06)
	check(not battle.struct_ready.has("GAPILL"),prefix+"fast build cannot bypass price")
	battle.funds = available
	battle._tick_structure_queue(0.06)
	check(battle.struct_ready.has("GAPILL") and is_equal_approx(battle.funds,10000.0-float(GameData.get_building("GAPOWR").cost)-float(GameData.get_building("GAPILL").cost)),prefix+"both categories pay exactly once")
	GM.set_flag("no_build_time", false)
	var barracks = battle._place_building("GAPILE","ally",Vector2(1800,1800),true)
	barracks._buildup_play = -1.0
	var cash: float = battle.funds
	barracks.enqueue("E1")
	barracks._process(0.5)
	check(barracks.queue_progress() > 0.0 and not barracks.production.is_empty(),prefix+"unit already in production")
	GM.set_flag("no_build_time",true)
	barracks._process(0.06)
	check(barracks.production.is_empty() and is_equal_approx(cash-battle.funds,float(GameData.get_unit("E1").cost)),prefix+"mid-order fast unit pays once and exits")
	var site = battle._place_building("GAPOWR","ally",Vector2(1980,1800),false)
	site._process(0.06)
	check(not site.under_construction,prefix+"GM also completes on-site construction")
	GM.set_flag("no_build_time",false)
	screen.free()
	await get_tree().process_frame
