extends "res://tests/ggi_skill_regression.gd"

func settle(unit) -> void:
	for i in 3: unit.logistics.tick(15.0)

func choose(members: Array) -> void:
	battle.clear_selection()
	for member in members: battle.select_unit(member, true)
	battle._emit_selection()
	screen.hud._update_ability_live()

func label() -> String:
	screen.hud._update_ability_live()
	return screen.hud._ability_btns[2].get_meta("name_label").text

func exercise_mode(mode: String) -> void:
	BattleRequest.configure_skirmish(mode, {"map_size": 3200, "starting_funds": 8000, "fog_of_war": false})
	screen = load("res://scenes/battle.tscn").instantiate()
	stage.add_child(screen)
	battle = screen.battle
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	battle.process_mode = Node.PROCESS_MODE_ALWAYS
	battle.set_process(false)
	battle.set_physics_process(false)
	for child in battle.get_children(): child.process_mode = Node.PROCESS_MODE_DISABLED
	screen.hud.process_mode = Node.PROCESS_MODE_ALWAYS
	screen.hud.set_process(false)
	for group in ["obstacles", "resource_nodes"]:
		for node in get_tree().get_nodes_in_group(group): node.free()
	battle.water_rects.clear()
	battle.path_service.water_rects.clear()
	battle._refresh_pathing()
	get_window().focus_entered.emit()
	var a = actor("SCHP", "ally", Vector2(1400, 1400))
	var b = actor("SCHP", "ally", Vector2(1700, 1400))
	var unselected = actor("SCHP", "ally", Vector2(2000, 1400))
	var transport = actor("SHAD", "ally", Vector2(1400, 1900))
	var passenger = actor("E1", "ally", Vector2(1450, 1900))
	transport.logistics.air_lift = 0.0
	passenger.position = transport.position
	check(passenger.logistics.request_board(transport), mode + " transport boarding accepted")
	passenger.logistics.tick(0.1)
	check(passenger.embarked_in == transport, mode + " transport fixture loaded")
	for first in [a, b]:
		var second = b if first == a else a
		choose([first, second, transport])
		check(label() == "全部部署", mode + " airborne group offers deployment")
		await key(KEY_E)
		check(a.is_deployed() and b.is_deployed(), mode + " E deploys both")
		await key(KEY_E)
		check(a.is_deployed() and b.is_deployed(), mode + " repeated E preserves ongoing descent")
		settle(a); settle(b)
		check(a._active_weapon().name == "160mm" and b._active_weapon().name == "160mm", mode + " landing finishes with artillery")
		check(label() == "全部收炮起飞", mode + " fully deployed group offers takeoff")
		check(second.set_deployed(false, false), mode + " create mixed state")
		settle(second)
		check(label() == "全部部署", mode + " deployed leader still offers mixed deployment")
		screen.hud._ability_btns[2].pressed.emit()
		check(first.is_deployed() and second.is_deployed(), mode + " HUD fills deployment without folding peer")
		settle(second)
		first.order_move(first.position + Vector2(0, 200))
		check(not first.has_move_order and first.is_deployed(), mode + " deployed chopper stays fixed like GI")
		await key(KEY_E)
		check(not a.is_deployed() and not b.is_deployed(), mode + " all deployed E folds both")
		settle(a); settle(b)
		check(a.logistics.air_lift > 0.95 and b.logistics.air_lift > 0.95, mode + " both return airborne")
		check(passenger.embarked_in == transport and not transport.logistics.unloading and not unselected.is_deployed(), mode + " E does not unload shared-ability transport or affect unselected chopper")
	# A blocked member keeps deployment priority; clearing the blockage permits retry.
	a.set_deployed(true, false); settle(a)
	var original: Vector2 = b.position
	b.position = a.position
	choose([a, b])
	await key(KEY_E)
	check(a.is_deployed() and not b.is_deployed(), mode + " occupied landing preserves deployed peer")
	b.position = original
	a._stun_timer = 1.0
	check(label() == "全部部署" and not screen.hud._ability_btns[2].disabled, mode + " stunned leader does not disable actionable peer")
	screen.hud._ability_btns[2].pressed.emit()
	check(a.is_deployed() and b.is_deployed(), mode + " cleared landing retry deploys peer")
	a._stun_timer = 0.0
	settle(b)
	b.set_deployed(false, false); settle(b)
	await key(KEY_J)
	check(a.is_deployed() and b.is_deployed(), mode + " general deploy command fills mixed group")
	settle(b)
	await key(KEY_J)
	check(not a.is_deployed() and not b.is_deployed(), mode + " general deploy command folds full group")
	settle(a); settle(b)
	choose([a])
	check(label() == "部署火炮", mode + " single airborne label")
	await key(KEY_E)
	settle(a)
	check(label() == "收炮起飞", mode + " single deployed label")
	var enemy = actor("SCHP", "enemy", Vector2(2000, 1700))
	battle.selected_units = [a, a, b, enemy, passenger]
	b.hp = 0.0
	check(battle.selected_deploy_group(true) == [a], mode + " group excludes duplicate dead enemy and embarked units")
	b.hp = b.max_hp
	screen.free()
	await get_tree().process_frame
