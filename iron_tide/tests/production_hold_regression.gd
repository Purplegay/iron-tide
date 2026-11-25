extends "res://tests/dual_build_regression.gd"

const Snapshot = preload("res://scripts/save/battle_snapshot.gd")

func click_control(control: Control, button := MOUSE_BUTTON_LEFT) -> void:
	var at := control.get_global_rect().get_center()
	await move_pointer(at)
	await mouse_button(at, true, false, button)
	await mouse_button(at, false, false, button)

func exercise_mode(mode: String) -> void:
	# Snapshot restore pauses the tree; each mode starts a fresh running scenario.
	get_tree().paused = false
	BattleRequest.configure_skirmish(mode, {"map_size": 3200, "starting_funds": 50000})
	screen = load("res://scenes/battle.tscn").instantiate()
	stage.add_child(screen)
	battle = screen.battle
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	var hud = screen.hud
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	hud.set_process(false)
	for b in battle.buildings: b._buildup_play = -1.0
	GM.infinite_funds = false
	battle.power_low = false
	battle.production_technology.unlocked.clear()
	get_window().focus_entered.emit()
	var prefix := mode + ": "
	# Real sidebar entry must allow installment production, even from zero funds.
	for bid in ["GAPOWR", "GAPILL"]:
		var category: String = battle.structure_category(bid)
		battle.funds = 50.0 if bid == "GAPOWR" else 0.0
		var available: float = battle.funds
		await click_card(category, bid)
		check(not job(bid).is_empty() and battle.funds == available, prefix + bid + " short funds real click starts without upfront charge")
		battle._tick_structure_queue(1000.0)
		check(not job(bid).is_empty() and is_equal_approx(float(job(bid).paid), available) and is_zero_approx(battle.funds) and int(battle.struct_ready.get(bid, 0)) == 0, prefix + bid + " no free completion when funds run out")
		var stopped: float = job(bid).elapsed
		battle._tick_structure_queue(1000.0)
		check(job(bid).elapsed == stopped, prefix + bid + " zero funds freezes progress")
		await refresh()
		check("资金不足" in hud._prod_status_labels[bid].text, prefix + bid + " waiting funds visible on card")
		battle.add_funds(float(GameData.get_building(bid).cost) - available)
		battle._tick_structure_queue(1000.0)
		check(job(bid).is_empty() and int(battle.struct_ready.get(bid, 0)) == 1 and is_zero_approx(battle.funds), prefix + bid + " income automatically completes exact remaining payment")
		await click_card(category, bid)
		check(battle.armed_build == bid, prefix + bid + " paid building remains placeable with zero funds")
		battle.set_build_mode("")
		await click_card(category, bid, MOUSE_BUTTON_RIGHT)
		check(int(battle.struct_ready.get(bid, 0)) == 0 and is_equal_approx(battle.funds, float(GameData.get_building(bid).cost)), prefix + bid + " ready cancellation refunds exactly once")
	battle.funds = 50000.0
	await click_card("building", "GAPOWR")
	await click_card("defense", "GAPILL")
	battle._tick_structure_queue(0.5)
	var elapsed: float = job("GAPOWR").elapsed
	var paid: float = job("GAPOWR").paid
	var money: float = battle.funds
	await click_card("building", "GAPOWR", MOUSE_BUTTON_RIGHT)
	check(battle.structure_is_paused("GAPOWR") and battle.funds == money, prefix + "first building RMB holds without refund")
	battle._tick_structure_queue(0.5)
	check(job("GAPOWR").elapsed == elapsed and job("GAPOWR").paid == paid, prefix + "held building preserves payment and progress")
	check(job("GAPILL").elapsed > elapsed, prefix + "defense lane continues independently")
	check("已暂停" in hud._prod_status_labels["GAPOWR"].text and not hud._prod_buttons["GAPOWR"].disabled, prefix + "held building card shows resumable state without reservation technology")
	battle.funds = 0.0
	await click_card("building", "GAPOWR")
	check(not battle.structure_is_paused("GAPOWR") and battle.struct_queue.size() == 2 and job("GAPOWR").elapsed == elapsed, prefix + "zero funds left click resumes without appending or resetting")
	battle.funds = 50000.0
	battle._tick_structure_queue(0.25)
	check(job("GAPOWR").elapsed > elapsed, prefix + "resumed building advances from retained progress")
	await click_card("building", "GAPOWR", MOUSE_BUTTON_RIGHT)
	paid = job("GAPOWR").paid
	money = battle.funds
	await click_card("building", "GAPOWR", MOUSE_BUTTON_RIGHT)
	check(job("GAPOWR").is_empty() and is_equal_approx(battle.funds, money + paid), prefix + "second building RMB cancels and refunds only paid amount")
	await click_card("defense", "GAPILL", MOUSE_BUTTON_RIGHT)
	check(battle.structure_is_paused("GAPILL"), prefix + "defense first RMB also holds")
	await click_card("defense", "GAPILL")
	battle._tick_structure_queue(1000.0)
	check(int(battle.struct_ready.get("GAPILL", 0)) == 1, prefix + "resumed defense completes exactly once")
	money = battle.funds
	await click_card("defense", "GAPILL", MOUSE_BUTTON_RIGHT)
	check(int(battle.struct_ready.get("GAPILL", 0)) == 0 and is_equal_approx(battle.funds, money + float(GameData.get_building("GAPILL").cost)), prefix + "completed building RMB immediately reclaims")
	# Reservation technology keeps FIFO and allows removing waiting types while held.
	battle.production_technology.unlock("structure_queue", "ally")
	await click_card("building", "GAPOWR")
	await click_card("building", "GAREFN")
	battle._tick_structure_queue(0.5)
	await click_card("building", "GAPOWR", MOUSE_BUTTON_RIGHT)
	await click_card("building", "GAREFN", MOUSE_BUTTON_RIGHT)
	check(battle.structure_is_paused("GAPOWR") and job("GAREFN").is_empty(), prefix + "waiting type cancels directly without resuming held head")
	for i in 8: battle.request_structure("GAREFN")
	await click_card("building", "GAPOWR")
	check(battle.structure_jobs("building").size() == 9 and not battle.structure_is_paused("GAPOWR"), prefix + "full building queue resumes without adding a tenth item")
	while not job("GAREFN").is_empty(): battle.cancel_structure("GAREFN")
	await click_card("building", "GAPOWR", MOUSE_BUTTON_RIGHT)
	# Refinery manufacture uses the same pause protocol as factories.
	GM.unlock_production_tech = true
	var refinery
	for b in battle.buildings:
		if b.side == "ally" and b.building_id == "GAREFN": refinery = b
	refinery.special["hold_test"] = true
	battle.select_building(refinery)
	battle._emit_selection()
	await refresh()
	await click_control(hud._refinery_btn)
	refinery._process(0.5)
	var progress: float = refinery.progress
	paid = refinery.production_paid
	money = battle.funds
	await click_control(hud._refinery_btn, MOUSE_BUTTON_RIGHT)
	refinery._process(1000.0)
	check(refinery.production_paused() and refinery.progress == progress and refinery.production_paid == paid and battle.funds == money, prefix + "refinery skill RMB holds without spawning or charging")
	await click_control(hud._refinery_btn)
	check(not refinery.production_paused() and refinery.production == ["CMIN"], prefix + "refinery skill LMB resumes without new order")
	await click_control(hud._refinery_cancel)
	check(refinery.production_paused(), prefix + "refinery command button first holds")
	await click_control(hud._refinery_cancel)
	check(refinery.production.is_empty() and is_equal_approx(battle.funds, money + paid), prefix + "refinery command second cancels and refunds")
	refinery.enqueue("CMIN")
	refinery._process(0.5)
	refinery.production_right_click("CMIN")
	progress = refinery.progress
	paid = refinery.production_paid
	elapsed = job("GAPOWR").elapsed
	money = battle.funds
	var saved: Dictionary = BattleSaves.save_slot(battle, "slot1")
	check(saved.ok, prefix + "held queues save to disk", saved)
	var read: Dictionary = BattleSaves.read_slot("slot1")
	check(read.ok, prefix + "held snapshot checksum and schema accepted")
	if read.ok:
		Snapshot.new().restore(battle, read.snapshot)
		for b in battle.buildings:
			if b.special.get("hold_test", false): refinery = b
		battle._tick_structure_queue(1000.0)
		refinery._process(1000.0)
		check(battle.structure_is_paused("GAPOWR") and job("GAPOWR").elapsed == elapsed, prefix + "building hold survives disk restore")
		check(refinery.production_paused() and refinery.progress == progress and refinery.production_paid == paid and battle.funds == money, prefix + "factory hold survives disk restore without spending")
		battle.request_structure("GAPOWR")
		refinery.resume_production("CMIN")
		battle._tick_structure_queue(0.25)
		refinery._process(0.25)
		check(job("GAPOWR").elapsed > elapsed and refinery.progress > progress, prefix + "restored queues resume from retained progress")
		# Old saves contain neither optional dictionary key.
		var legacy: Dictionary = Snapshot.new().capture(battle)
		Snapshot.new().restore(battle, legacy)
		for b in battle.buildings:
			if b.special.get("hold_test", false): refinery = b
		check(not battle.structure_is_paused("GAPOWR") and not refinery.production_paused(), prefix + "snapshots without pause keys retain active behavior")
	screen.free()
	get_tree().paused = false
	await get_tree().process_frame
