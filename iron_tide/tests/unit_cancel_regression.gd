extends "res://tests/factory_tabs_regression.gd"

func production_ownership(_mode: String) -> void:
	pass

func category(mode: String, tab: String, bid: String, uid: String) -> void:
	var prefix := mode + " " + tab + ": "
	var hud = screen.hud
	# Keep real world input alive so GUI cancellation must not issue an order.
	battle.process_mode = Node.PROCESS_MODE_ALWAYS
	battle.set_process(false)
	battle.set_physics_process(false)
	for child in battle.get_children():
		child.process_mode = Node.PROCESS_MODE_DISABLED
	var a = add_factory(bid, Vector2(1200, 1200))
	var b = add_factory(bid, Vector2(1700, 1200))
	battle.select_building(b)
	battle._emit_selection()
	await refresh()
	check(hud._active_producer() == b and hud._prod_buttons.has(uid), prefix + "actual factory card selected")
	var soldier = battle.spawn_unit("E1", "ally", Vector2(1300, 1500))
	soldier.process_mode = Node.PROCESS_MODE_DISABLED
	battle.select_unit(soldier, false)
	battle._emit_selection()
	await refresh()
	check(battle.world_input_enabled() and not soldier.has_move_order, prefix + "world input active with idle selected unit")
	a.enqueue(uid)
	b.enqueue_many(uid, 3)
	a._process(0.5)
	b._process(0.25)
	var other_progress: float = a.progress
	var other_paid: float = a.production_paid
	var progress: float = b.progress
	var paid: float = b.production_paid
	var money: float = battle.funds
	await refresh()
	await click_control(hud._prod_buttons[uid], MOUSE_BUTTON_RIGHT)
	check(b.production_paused() and b.production == [uid, uid, uid], prefix + "first card right-click pauses without removing orders")
	b._process(100.0)
	check(b.progress == progress and b.production_paid == paid and battle.funds == money, prefix + "held factory cannot advance or charge")
	check("已暂停" in hud._prod_status_labels[uid].text, prefix + "card exposes paused state")
	await click_control(hud._prod_buttons[uid], MOUSE_BUTTON_RIGHT)
	check(b.production == [uid, uid], prefix + "card right-click removes exactly one waiting order")
	check(b.progress == progress and b.production_paid == paid and battle.funds == money, prefix + "waiting cancellation preserves paid active progress")
	await click_control(hud._prod_buttons[uid], MOUSE_BUTTON_RIGHT)
	await click_control(hud._prod_buttons[uid], MOUSE_BUTTON_RIGHT)
	check(b.production.is_empty() and b.progress == 0.0 and b.production_paid == 0.0, prefix + "last right-click clears active order")
	check(is_equal_approx(battle.funds, money + paid), prefix + "active cancellation refunds exactly actual payment")
	await click_control(hud._prod_buttons[uid], MOUSE_BUTTON_RIGHT)
	check(a.production == [uid] and a.progress == other_progress and a.production_paid == other_paid, prefix + "empty active factory never cancels another factory")
	check(is_equal_approx(battle.funds, money + paid), prefix + "empty cancellation cannot duplicate refund")
	drain(b)
	b.enqueue(uid)
	b._process(0.25)
	paid = b.production_paid
	battle.funds = 0.0
	await refresh()
	check(not hud._prod_buttons[uid].disabled, prefix + "insufficient funds keeps production card available")
	await click_control(hud._prod_buttons[uid], MOUSE_BUTTON_RIGHT)
	check(b.production_paused() and battle.funds == 0.0 and not hud._prod_buttons[uid].disabled, prefix + "card pauses and enables resume with zero funds")
	await click_control(hud._prod_buttons[uid])
	check(not b.production_paused() and b.production == [uid] and b.production_paid == paid, prefix + "zero funds resume neither appends nor refunds")
	await click_control(hud._prod_buttons[uid], MOUSE_BUTTON_RIGHT)
	await click_control(hud._prod_buttons[uid], MOUSE_BUTTON_RIGHT)
	check(b.production.is_empty() and is_equal_approx(battle.funds, paid), prefix + "second right-click cancels and refunds")
	battle.funds = 50000.0
	drain(b)
	if tab != "air":
		b.enqueue_many(uid, b.queue_capacity())
		await refresh()
		check(hud._prod_buttons[uid].disabled, prefix + "full queue disables production")
		await click_control(hud._prod_buttons[uid], MOUSE_BUTTON_RIGHT)
		check(b.production_paused() and b.production.size() == b.queue_capacity(), prefix + "full queue first pauses")
		await click_control(hud._prod_buttons[uid])
		check(not b.production_paused() and b.production.size() == b.queue_capacity(), prefix + "full queue resumes without appending")
		await click_control(hud._prod_buttons[uid], MOUSE_BUTTON_RIGHT)
		await click_control(hud._prod_buttons[uid], MOUSE_BUTTON_RIGHT)
		check(b.production.size() == b.queue_capacity() - 1, prefix + "full queue second right-click cancels one")
		drain(b)
	if tab == "infantry":
		b.enqueue("ENGINEER")
		b.enqueue(uid)
		b.enqueue("ENGINEER")
		b._process(0.25)
		progress = b.progress
		paid = b.production_paid
		await refresh()
		await click_control(hud._prod_buttons[uid], MOUSE_BUTTON_RIGHT)
		check(b.production == ["ENGINEER", "ENGINEER"] and b.progress == progress and b.production_paid == paid, prefix + "mixed queue cancels matching type without disturbing active different type")
		drain(b)
	b.enqueue(uid)
	await refresh()
	await click_control(hud._queue_host.get_node("queue_strip").get_child(0), MOUSE_BUTTON_RIGHT)
	check(b.production_paused() and b.production == [uid], prefix + "queue tile first right-click pauses")
	await click_control(hud._queue_host.get_node("queue_strip").get_child(0))
	check(not b.production_paused() and b.production == [uid], prefix + "queue tile left-click resumes")
	await click_control(hud._queue_host.get_node("queue_strip").get_child(0), MOUSE_BUTTON_RIGHT)
	await click_control(hud._queue_host.get_node("queue_strip").get_child(0), MOUSE_BUTTON_RIGHT)
	check(b.production.is_empty() and not b.production_paused(), prefix + "queue tile second right-click cancels and clears hold")
	check(battle.selected_units == [soldier] and not soldier.has_move_order, prefix + "GUI cancellation preserves army selection without issuing movement")
	drain(a)
