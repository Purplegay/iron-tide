extends "res://tests/batch_rally_regression.gd"

func add_factory(id: String, at: Vector2, side := "ally"):
	var b = battle._place_building(id, side, at, true)
	b.process_mode = Node.PROCESS_MODE_DISABLED
	b._buildup_play = -1.0
	return b

func click_control(control: Control, button := MOUSE_BUTTON_LEFT) -> void:
	var scroll: ScrollContainer = screen.hud._prod_scroll
	if scroll.is_ancestor_of(control):
		# The skin timer changes the new queue tile's margins on its first layout.
		for pass_index in 2:
			for i in 3: await get_tree().process_frame
			scroll.ensure_control_visible(control)
		for i in 3: await get_tree().process_frame
		check(scroll.get_global_rect().encloses(control.get_global_rect()), "click target scrolled fully into production list", {"control": str(control.get_path()), "rect": str(control.get_global_rect()), "scroll": str(scroll.get_global_rect())})
	var at := control.get_global_rect().get_center()
	await move_pointer(at)
	await mouse_button(at, true, false, button)
	await mouse_button(at, false, false, button)

func exercise_mode(mode: String) -> void:
	BattleRequest.configure_skirmish(mode, {"map_size": 3200, "starting_funds": 50000})
	screen = load("res://scenes/battle.tscn").instantiate()
	stage.add_child(screen)
	battle = screen.battle
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	screen.hud.process_mode = Node.PROCESS_MODE_ALWAYS
	screen.hud.set_process(false)
	for b in battle.buildings:
		b._buildup_play = -1.0
	for id in ["GAPOWR", "GAREFN", "GATECH", "GAWEAP", "GAAIRC"]:
		add_factory(id, Vector2(500, 2100))
	battle.power_low = false
	get_window().focus_entered.emit()
	for entry in [["infantry", "GAPILE", "E1"], ["vehicle", "GAWEAP", "MTNK"], ["air", "GAAIRC", "ORCA"], ["naval", "GAYARD", "DEST"]]:
		await category(mode, str(entry[0]), str(entry[1]), str(entry[2]))
	await production_ownership(mode)
	screen.free()
	await get_tree().process_frame

func production_ownership(mode: String) -> void:
	var hud = screen.hud
	var war = add_factory("GAWEAP", Vector2(1300, 1700))
	var barracks = add_factory("GAPILE", Vector2(1600, 1700))
	var refinery = add_factory("GAREFN", Vector2(2100, 1800))
	for row in [["GAPILE", "infantry"], ["GAWEAP", "vehicle"], ["GAAIRC", "air"], ["GAYARD", "naval"]]:
		for unit_data in GameData.units_from_building("allied", row[0]):
			check(hud._unit_cat(unit_data) == ("air" if unit_data.id == "SHAD" else row[1]), mode + ": catalog category " + str(unit_data.id))
	for row in [[barracks, "JUMPJET", "infantry"], [war, "SHAD", "air"], [war, "CMIN", "vehicle"]]:
		var producer = row[0]
		var uid: String = row[1]
		battle.select_building(producer)
		battle._emit_selection()
		await refresh()
		if uid == "SHAD":
			hud.select_prod_tab("air")
			await refresh()
		check(hud.prod_tab == row[2] and hud._prod_buttons.has(uid), mode + ": selecting actual factory shows " + uid)
		check(hud._producer_for(uid) == producer, mode + ": selected factory owns " + uid)
		await click_control(hud._prod_buttons[uid])
		check(producer.production == [uid] and refinery.production.is_empty(), mode + ": card queues only at original factory " + uid)
		var count_before: int = battle.units.size()
		var money_before: float = battle.funds
		for tick in 1200:
			producer._process(0.25)
			if producer.production.is_empty(): break
		check(producer.production.is_empty() and battle.units.size() == count_before + 1, mode + ": real factory produces " + uid)
		check(is_equal_approx(money_before - battle.funds, float(GameData.get_unit(uid).cost)), mode + ": original factory charges exactly one price " + uid)
		if uid == "CMIN":
			var miner = battle.units[-1]
			# Production now issues a short port-clearance move before harvesting.
			# Advance the real physics entry until departure and home selection finish.
			miner.process_mode = Node.PROCESS_MODE_ALWAYS
			miner.set_process(false)
			miner.set_physics_process(false)
			for tick in 1200:
				await get_tree().physics_frame
				miner._physics_process(1.0 / 60.0)
				if is_instance_valid(miner.home_base) and not miner.has_move_order: break
			check(miner.is_harvester and is_instance_valid(miner.home_base) and miner.home_base.is_refinery() and not miner.has_move_order,
				mode + ": war factory miner finds refinery and automatically harvests")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			stage.get_texture().get_image().save_png(output_dir.path_join(mode + "-ownership-" + uid + ".png"))
		# Existing batch contract now runs in the correct production category.
		var card: Control = hud._prod_buttons[uid]
		var at := card.get_global_rect().get_center()
		await move_pointer(at)
		await mouse_button(at, true)
		hud._tick_prod_hold(hud.HOLD_TIME + 0.1)
		await mouse_button(at, false)
		await refresh()
		check(producer.production.size() == 5 and refinery.production.is_empty(), mode + ": long press adds exactly five at original producer " + uid)
		drain(producer)
		producer.under_construction = true
		await refresh()
		check(hud._prod_buttons[uid].disabled and hud._unit_state(uid).reason.contains("施工中"), mode + ": selected producer construction blocks without spill " + uid)
		producer.under_construction = false
		await refresh()
	hud.select_prod_tab("air")
	await refresh()
	check(hud._prod_buttons.has("ORCA") and hud._prod_buttons.has("BEAG") and not hud._prod_buttons.has("JUMPJET") and hud._prod_buttons.has("SHAD"), mode + ": aircraft tab includes factory helicopters and excludes flying infantry")
	check(hud._factories.candidates().has(war) and hud._factories.candidates().all(func(b): return b.building_id in ["GAAIRC", "GAWEAP"]), mode + ": air tab lists aircraft producers only")
	hud.select_prod_tab("vehicle")
	battle.select_building(refinery)
	battle._emit_selection()
	await refresh()
	check(hud._producer_for("CMIN") == war and not hud._factories.candidates().has(refinery), mode + ": selected refinery cannot steal vehicle-card orders")
	for tab in ["building", "defense"]:
		hud.select_prod_tab(tab)
		await refresh()
		check(not hud._building_catalog().has("GASAND"), mode + ": sandbags removed from " + tab)
		for id in ["GACSPH", "GAWEAT", "GASPYSAT"]:
			check(hud._building_catalog().has(id) == (tab == "defense") and battle.structure_category(id) == "defense", mode + ": original BuildCat=Combat owns " + id + " in " + tab)
	check(battle.structure_category("GAROBO") == "building" and battle.structure_category("GAPOWR") == "building", mode + ": resource and power buildings stay in main category")
	var jobs: int = battle.struct_queue.size() + battle.enemy_struct_queue.size()
	battle.request_structure("GASAND")
	battle.request_structure("GASAND", "enemy")
	battle.set_build_mode("GASAND")
	check(battle.struct_queue.size() + battle.enemy_struct_queue.size() == jobs and battle.armed_build != "GASAND", mode + ": sandbags blocked at order and placement entry points")
	# Technology applies per side; disabling the debug override still leaves AI
	# able to replace miners through an original war factory.
	var enemy_war = add_factory("GAWEAP", Vector2(2400, 1700), "enemy")
	add_factory("GAREFN", Vector2(2600, 1900), "enemy")
	for u in battle.units.duplicate():
		if battle.actor_alive(u) and u.side == "enemy" and u.is_harvester:
			battle.units.erase(u)
			u.free()
	GM.unlock_production_tech = false
	battle.production_technology.unlock("refinery_miner", "ally")
	battle.skirmish_ai._replace_miners()
	check(enemy_war.production == ["CMIN"], mode + ": AI uses war factory while refinery technology is locked")
	battle.skirmish_ai._replace_miners()
	check(enemy_war.production == ["CMIN"], mode + ": AI counts queued factory miners without duplicate orders")
	GM.unlock_production_tech = true

func category(mode: String, tab: String, bid: String, uid: String) -> void:
	var prefix := mode + " " + tab + ": "
	var hud = screen.hud
	var a = add_factory(bid, Vector2(1200, 1200))
	var b = add_factory(bid, Vector2(1700, 1200))
	var hostile = add_factory(bid, Vector2(1700, 1700), "enemy")
	battle.select_building(a)
	battle._emit_selection()
	await refresh()
	check(hud.prod_tab == tab and hud._active_producer() == a, prefix + "world selection focuses matching factory/category")
	check(not hud._factories.candidates().has(hostile), prefix + "enemy factory excluded")
	check(hud._factories.buttons.has(a.get_instance_id()) and hud._factories.buttons.has(b.get_instance_id()), prefix + "each own factory has a tab")
	var soldier = battle.spawn_unit("E1", "ally", Vector2(1300, 1500))
	soldier.process_mode = Node.PROCESS_MODE_DISABLED
	battle.select_unit(soldier, false)
	battle._emit_selection()
	await refresh()
	await click_control(hud._factories.buttons[a.get_instance_id()].button)
	await refresh()
	await click_control(hud._prod_buttons[uid])
	check(a.production == [uid] and b.production.is_empty(), prefix + "first tab routes only to first factory")
	await click_control(hud._factories.buttons[b.get_instance_id()].button)
	await refresh()
	await click_control(hud._prod_buttons[uid])
	check(b.production == [uid] and a.production == [uid], prefix + "second tab routes only to second factory")
	check(battle.selected_units == [soldier], prefix + "factory tabs preserve battlefield army selection")
	var first_button: Button = hud._factories.buttons[a.get_instance_id()].button
	var second_button: Button = hud._factories.buttons[b.get_instance_id()].button
	a._process(0.5)
	b._process(0.25)
	hud._update_production_live()
	check(a.progress > b.progress and b.progress > 0.0, prefix + "both real factory queues advance independently")
	check(is_equal_approx(hud._factories.buttons[a.get_instance_id()].bar.value, a.queue_progress()) and is_equal_approx(hud._factories.buttons[b.get_instance_id()].bar.value, b.queue_progress()), prefix + "each tab shows its own progress")
	check(hud._prod_wipes[uid].badge == 1 and is_equal_approx(hud._prod_wipes[uid].frac, b.queue_progress()), prefix + "catalog progress belongs only to active factory")
	hud._refresh_production()
	check(hud._factories.buttons[a.get_instance_id()].button == first_button and hud._factories.buttons[b.get_instance_id()].button == second_button, prefix + "progress refresh does not destroy pressed controls")
	var first_progress: float = a.progress
	var first_paid: float = a.production_paid
	var refund: float = b.production_paid
	var money: float = battle.funds
	await click_control(hud._queue_host.get_node("queue_strip").get_child(0), MOUSE_BUTTON_RIGHT)
	check(b.production_paused() and not a.production_paused() and battle.funds == money, prefix + "first queue RMB holds only selected factory")
	await click_control(hud._queue_host.get_node("queue_strip").get_child(0), MOUSE_BUTTON_RIGHT)
	check(b.production.is_empty() and a.production == [uid] and a.progress == first_progress and a.production_paid == first_paid, prefix + "right-click cancels only active factory")
	check(is_equal_approx(battle.funds, money + refund), prefix + "refund includes only active factory actual payment")
	hud.select_prod_tab("building")
	hud.select_prod_tab(tab)
	await refresh()
	check(hud._active_producer() == b, prefix + "category round trip remembers factory, including idle factory")
	# A blocked selected factory cannot silently send orders to a different one.
	drain(a)
	drain(b)
	if tab != "air":
		b.enqueue_many(uid, b.queue_capacity())
		await refresh()
		hud._queue(uid)
		check(a.production.is_empty() and b.production.size() == b.queue_capacity(), prefix + "full selected queue does not spill into another factory")
		drain(b)
		hud._close_unlock_panel()
	# A held card must not migrate to the newly selected factory.
	hud._factories.choose(a)
	await refresh()
	hud._begin_prod_hold(uid)
	hud._factories.choose(b)
	hud._tick_prod_hold(hud.HOLD_TIME + 0.1)
	check(a.production.is_empty() and b.production.is_empty(), prefix + "factory switch cancels old long press")
	var old_number: int = hud._factories.number_for(a)
	var count: int = hud._factories.candidates().size()
	var extra = add_factory(bid, Vector2(2200, 1200))
	extra.under_construction = true
	await refresh()
	check(hud._factories.candidates().size() == count + 1 and hud._factories.buttons[extra.get_instance_id()].button.text.contains("施工中"), prefix + "new construction appears with status")
	check(hud._factories.number_for(a) == old_number, prefix + "new factory does not renumber existing tabs")
	hud._factories.choose(extra)
	hud._queue(uid)
	check(extra.production.is_empty() and a.production.is_empty(), prefix + "under-construction selection reports reason without rerouting")
	hud._close_unlock_panel()
	extra.under_construction = false
	await refresh()
	hud._factories.choose(b)
	var dead_id: int = b.get_instance_id()
	b._die()
	await get_tree().process_frame
	await refresh()
	check(hud._active_producer() != b and not hud._factories.buttons.has(dead_id), prefix + "destroyed selected factory falls back to living factory")
	hud._factories.choose(a)
	await refresh()
	if tab == "infantry":
		a.enqueue_many(uid, 3)
		extra.enqueue(uid)
		a._process(0.6)
		extra._process(0.3)
		for i in 4: add_factory(bid, Vector2(2400, 800 + i * 180))
		await refresh()
		for width in [1280, 1600]:
			stage.size = Vector2i(width, 900)
			for i in 4: await get_tree().process_frame
			for item in hud._factories.buttons.values():
				var rect: Rect2 = item.button.get_global_rect()
				check(rect.end.x <= width + 1 and rect.position.x >= 0, prefix + "many factory tabs stay inside viewport")
			if DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				stage.get_texture().get_image().save_png(output_dir.path_join(mode + "-factories-" + str(width) + ".png"))
		stage.size = Vector2i(1600, 900)
	drain(a)
	for actor in [a, extra, hostile]:
		battle.buildings.erase(actor)
		actor.free()
	battle.units.erase(soldier)
	soldier.free()
	await get_tree().process_frame
