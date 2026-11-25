extends "res://tests/batch_rally_regression.gd"

func job(id: String, side := "ally") -> Dictionary:
	var jobs: Array = battle.struct_queue if side == "ally" else battle.enemy_struct_queue
	for item in jobs:
		if item.id == id: return item
	return {}

func click_card(tab: String, id: String, button := MOUSE_BUTTON_LEFT) -> void:
	screen.hud.select_prod_tab(tab)
	await refresh()
	var at: Vector2 = screen.hud._prod_buttons[id].get_global_rect().get_center()
	await move_pointer(at)
	await mouse_button(at, true, false, button)
	await mouse_button(at, false, false, button)

func placement(id: String) -> Vector2:
	var hq = battle._player_hq()
	for distance in [160, 240, 320, 440, 600, 800]:
		for direction in 24:
			var at: Vector2 = battle.snap_build_pos(hq.global_position + Vector2.RIGHT.rotated(TAU * direction / 24.0) * distance)
			if battle.build_spot_ok(at, GameData.get_building(id), true).ok: return at
	return Vector2.INF

func exercise_mode(mode: String) -> void:
	BattleRequest.configure_skirmish(mode, {"map_size": 3200, "starting_funds": 50000})
	screen = load("res://scenes/battle.tscn").instantiate()
	stage.add_child(screen)
	battle = screen.battle
	# This suite covers FIFO/capacity after the reservation technology grant.
	battle.production_technology.unlock("structure_queue", "ally")
	battle.production_technology.unlock("structure_queue", "enemy")
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	var hud = screen.hud
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	hud.set_process(false)
	for b in battle.buildings: b._buildup_play = -1.0
	battle.power_low = false
	battle.enemy_power.low = false
	battle.funds = 50000
	battle.enemy_funds = 50000
	var prefix := mode + ": "
	await click_card("building", "GAPOWR")
	await click_card("building", "GAREFN")
	await click_card("defense", "GAPILL")
	await click_card("defense", "GAWALL")
	check(battle.struct_queue.size() == 4, prefix + "actual card clicks accept both categories", {
		"jobs": battle.struct_queue.duplicate(true), "funds": battle.funds,
		"owned": battle.owned_building_ids(), "paused": battle.paused, "ended": battle.ended,
		"pointer_ui": str(stage.gui_get_hovered_control())})
	if battle.struct_queue.size() != 4:
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			stage.get_texture().get_image().save_png(output_dir.path_join(mode + "-request-failure.png"))
		screen.free()
		return
	var normal := job("GAPOWR")
	var defense := job("GAPILL")
	var money: float = battle.funds
	battle._tick_structure_queue(3.0)
	check(normal.elapsed > 0 and defense.elapsed > 0, prefix + "normal and defense heads advance together")
	check(job("GAREFN").elapsed == 0 and job("GAWALL").elapsed == 0, prefix + "each category remains FIFO")
	check(is_equal_approx(money - battle.funds, float(normal.paid) + float(defense.paid)), prefix + "both queues charge shared funds exactly once")
	for pair in [["building", "GAPOWR"], ["defense", "GAPILL"]]:
		hud.select_prod_tab(pair[0])
		await refresh()
		var current := job(pair[1])
		check("建造中" in hud._prod_status_labels[pair[1]].text, prefix + pair[0] + " card shows its own active job")
		check(is_equal_approx(hud._prod_wipes[pair[1]].frac, float(current.elapsed) / float(current.time)), prefix + pair[0] + " cameo progress belongs to its category")
		check(hud._structure_status.text.contains(GameData.get_building(pair[1]).name) and "等待 1 项" in hud._structure_status.text, prefix + pair[0] + " footer shows only own head and waiting count")
		check(not hud._queue_host.visible, prefix + pair[0] + " hides unrelated factory idle status")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			stage.get_texture().get_image().save_png(output_dir.path_join(mode + "-" + pair[0] + "-queue.png"))
	var guide = preload("res://scripts/ui/unlock_guidance.gd").new(battle)
	check(guide._status("GAPILL") == "建造中" and guide._status("GAWALL") == "排队中", prefix + "unlock guidance uses category positions")
	money = battle.funds
	var normal_before := normal.duplicate(true)
	var refund: float = defense.paid
	await click_card("defense", "GAWALL", MOUSE_BUTTON_RIGHT)
	await click_card("defense", "GAPILL", MOUSE_BUTTON_RIGHT)
	check(battle.structure_is_paused("GAPILL"), prefix + "defense first right-click pauses")
	await click_card("defense", "GAPILL", MOUSE_BUTTON_RIGHT)
	check(job("GAPILL").is_empty() and job("GAWALL").is_empty() and job("GAPOWR") == normal_before, prefix + "defense cancellation leaves normal queue intact")
	check(is_equal_approx(battle.funds, money + refund), prefix + "only canceled paid defense work is refunded")
	await click_card("defense", "GAPILL")
	defense = job("GAPILL")
	battle.power_low = true
	var old_normal: float = normal.elapsed
	battle._tick_structure_queue(1.0)
	check(is_equal_approx(float(normal.elapsed) - old_normal, battle.structure_work_rate()) and is_equal_approx(float(defense.elapsed), battle.structure_work_rate()), prefix + "low power slows both channels equally")
	battle.power_low = false
	var hq = battle._player_hq()
	hq.hp = 0
	var stalled: Array = battle.struct_queue.duplicate(true)
	battle._tick_structure_queue(2.0)
	check(stalled == battle.struct_queue, prefix + "losing construction yard pauses both channels")
	hq.hp = hq.max_hp
	battle.funds = 0
	battle._tick_structure_queue(2.0)
	check(stalled == battle.struct_queue, prefix + "no shared funds pauses both without negative money")
	battle.funds = 1.0
	var paid_before: float = normal.paid + defense.paid
	battle._tick_structure_queue(2.0)
	check(is_zero_approx(battle.funds) and is_equal_approx(float(normal.paid) + float(defense.paid) - paid_before, 1.0), prefix + "scarce funds cannot be spent twice")
	battle.funds = 50000
	money = battle.funds
	var unpaid: float = normal.cost - normal.paid + defense.cost - defense.paid
	battle._tick_structure_queue(1000.0)
	check(int(battle.struct_ready.get("GAPOWR", 0)) == 1 and int(battle.struct_ready.get("GAPILL", 0)) == 1 and job("GAREFN").elapsed == 0, prefix + "both heads finish once and preserve waiting jobs")
	check(is_equal_approx(money - battle.funds, unpaid), prefix + "completion charges only each head remaining balance")
	for pair in [["defense", "GAPILL"], ["building", "GAPOWR"]]:
		await click_card(pair[0], pair[1])
		check(battle.armed_build == pair[1] and "就绪 1" in hud._structure_status.text, prefix + pair[0] + " only own ready count shown")
		var pos := placement(pair[1])
		check(pos != Vector2.INF, prefix + "fixture has legal " + pair[1] + " footprint")
		if pos != Vector2.INF:
			money = battle.funds
			battle._try_place_building(pos)
			check(not battle.struct_ready.has(pair[1]) and battle.funds == money, prefix + pair[0] + " placing ready building does not charge again")
	# Enemy requests use the same two channels and only the enemy wallet.
	battle.request_structure("GAPOWR", "enemy")
	battle.request_structure("GAPILL", "enemy")
	money = battle.funds
	var enemy_money: float = battle.enemy_funds
	battle._tick_structure_queue(1.0)
	check(job("GAPOWR", "enemy").elapsed > 0 and job("GAPILL", "enemy").elapsed > 0, prefix + "opponent can advance both construction channels")
	check(is_equal_approx(enemy_money - battle.enemy_funds, float(job("GAPOWR", "enemy").paid) + float(job("GAPILL", "enemy").paid)), prefix + "opponent charges own shared wallet")
	# Capacity is per category; synthetic queued jobs exercise the boundary directly.
	for full_tab in ["building", "defense"]:
		battle.struct_queue.clear()
		var filled_id := "GAREFN" if full_tab == "building" else "GAWALL"
		for i in 9:
			battle.struct_queue.append({"id": filled_id, "cost": 100.0, "time": 10.0, "elapsed": 0.0, "paid": 0.0})
		var other_tab := "defense" if full_tab == "building" else "building"
		var other_id := "GAPILL" if other_tab == "defense" else "GAPOWR"
		await click_card(other_tab, other_id)
		check(not job(other_id).is_empty() and battle.struct_queue.size() == 10, prefix + full_tab + " full does not block other category")
		hud.select_prod_tab(full_tab)
		await refresh()
		var blocked_id := "GAPOWR" if full_tab == "building" else "GAPILL"
		check("队列已满" in hud._catalog_block_reason(blocked_id), prefix + full_tab + " capacity reason remains local")
		battle.request_structure(blocked_id)
		check(battle.struct_queue.size() == 10, prefix + full_tab + " backend enforces its own nine-slot cap")
	screen.free()
	await get_tree().process_frame
