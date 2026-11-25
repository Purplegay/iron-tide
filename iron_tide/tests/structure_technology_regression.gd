extends "res://tests/dual_build_regression.gd"

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
	battle.enemy_power.low = false
	battle.enemy_funds = 50000
	GM.unlock_production_tech = true
	var prefix := mode + ": "
	await click_card("building", "GAPOWR")
	battle._tick_structure_queue(1.0)
	var head: Dictionary = battle.struct_queue[0].duplicate(true)
	var money: float = battle.funds
	await click_card("building", "GAREFN")
	check(battle.structure_jobs("building").size() == 1, prefix + "default card cannot reserve another building")
	if battle.structure_jobs("building").size() != 1:
		screen.free()
		return
	check(hud._prod_buttons.GAREFN.disabled and "建筑预约" in hud._prod_buttons.GAREFN.tooltip_text, prefix + "blocked card explains reservation technology")
	check("左键追加" not in hud._prod_buttons.GAPOWR.tooltip_text, prefix + "active card no longer advertises locked action")
	battle.request_structure("GAPOWR")
	check(battle.struct_queue.size() == 1 and battle.struct_queue[0] == head and battle.funds == money, prefix + "backend rejects repeated orders without payment or progress changes")
	await click_card("defense", "GAPILL")
	await click_card("defense", "GAWALL")
	check(battle.structure_jobs("defense").size() == 1, prefix + "defense has its own single slot")
	battle._tick_structure_queue(1.0)
	check(job("GAPOWR").elapsed > head.elapsed and job("GAPILL").elapsed > 0.0, prefix + "building and defense still advance together")
	battle._tick_structure_queue(1000.0)
	await click_card("building", "GAREFN")
	battle.request_structure("GAREFN")
	check(battle.struct_queue.is_empty() and int(battle.struct_ready.GAPOWR) == 1, prefix + "ready building holds category until placed or canceled")
	await click_card("building", "GAPOWR")
	check(battle.armed_build == "GAPOWR" and not hud._prod_buttons.GAPOWR.disabled, prefix + "ready card stays usable for placement")
	var pos := placement("GAPOWR")
	check(pos != Vector2.INF, prefix + "legal placement available")
	if pos != Vector2.INF: battle._try_place_building(pos)
	await click_card("building", "GAREFN")
	check(battle.structure_jobs("building").size() == 1, prefix + "placing building releases only its category")
	await click_card("building", "GAREFN", MOUSE_BUTTON_RIGHT)
	check(battle.structure_is_paused("GAREFN"), prefix + "first RMB holds occupied slot")
	await click_card("building", "GAREFN", MOUSE_BUTTON_RIGHT)
	await click_card("building", "GAPOWR")
	check(battle.structure_jobs("building").size() == 1 and job("GAPOWR").size() > 0, prefix + "right cancellation frees single slot")
	check(battle.production_technology.is_unlocked("refinery_miner", "ally") and not battle.production_technology.is_unlocked("structure_queue", "ally"), prefix + "miner debug bypass does not unlock reservations")
	# Retain existing queued orders from old saves, but stop at a ready item.
	battle.struct_queue.append({"id": "GAREFN", "cost": 2000.0, "time": 84.0, "elapsed": 0.0, "paid": 0.0})
	var old_save := BattleSaves.save_slot(battle, "slot1")
	var old_loaded := BattleSaves.read_slot("slot1")
	check(old_save.ok and old_loaded.ok, prefix + "legacy locked queue serializes")
	if old_loaded.ok:
		preload("res://scripts/save/battle_snapshot.gd").new().restore(battle, old_loaded.snapshot)
		check(not battle.structure_reservations_enabled() and battle.structure_jobs("building").size() == 2, prefix + "restore preserves old queue without granting technology")
	battle._tick_structure_queue(1000.0)
	money = battle.funds
	battle._tick_structure_queue(1000.0)
	check(battle.structure_jobs("building").size() == 1 and job("GAREFN").elapsed == 0.0 and battle.funds == money, prefix + "legacy backlog waits without deletion or extra charges while ready building blocks")
	var console := GMConsole.new()
	console.battle_hud = hud
	hud.add_child(console)
	var unlock_button = console.find_child("UnlockStructureQueue", true, false)
	check(unlock_button != null, prefix + "GM has explicit match-local technology grant")
	if unlock_button != null: unlock_button.pressed.emit()
	console.free()
	check(battle.production_technology.is_unlocked("structure_queue", "ally") and not battle.production_technology.is_unlocked("structure_queue", "enemy"), prefix + "grant applies only to this player's technology")
	await refresh()
	check("建筑预约：已解锁" in hud._structure_status.text, prefix + "HUD exposes unlocked reservation state")
	battle._tick_structure_queue(1.0)
	check(job("GAREFN").elapsed > 0.0, prefix + "grant resumes retained backlog")
	await click_card("building", "GAREFN")
	check(battle.structure_jobs("building").size() == 2, prefix + "unlocked card adds repeat reservation")
	battle.request_structure("GAPOWR", "enemy")
	battle.request_structure("GAREFN", "enemy")
	check(battle.structure_jobs("building", "enemy").size() == 1, prefix + "enemy uses its own locked gate")
	battle.production_technology.unlock("structure_queue", "enemy")
	battle.request_structure("GAREFN", "enemy")
	check(battle.structure_jobs("building", "enemy").size() == 2, prefix + "enemy independent grant enables reservation")
	var save := BattleSaves.save_slot(battle, "slot1")
	var loaded := BattleSaves.read_slot("slot1")
	check(save.ok and loaded.ok, prefix + "technology and queued work serialize through real slot")
	if loaded.ok:
		preload("res://scripts/save/battle_snapshot.gd").new().restore(battle, loaded.snapshot)
		check(battle.production_technology.is_unlocked("structure_queue", "ally") and battle.structure_jobs("building").size() == 2, prefix + "restore retains unlocked technology and queued work")
	var fresh = preload("res://scripts/rules/production_technology.gd").new()
	check(not fresh.is_unlocked("structure_queue", "ally"), prefix + "new match remains locked after previous grant")
	screen.free()
	await get_tree().process_frame
	check(GM.cmd_unlock_structure_queue() == "请先进入对局", prefix + "grant outside active match safely rejected")
