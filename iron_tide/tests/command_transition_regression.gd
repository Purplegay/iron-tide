extends "res://tests/selection_regression.gd"

func exercise_mode(mode: String) -> void:
	BattleRequest.configure_skirmish(mode, {"map_size": 5000, "starting_funds": 20000})
	screen = load("res://scenes/battle.tscn").instantiate()
	stage.add_child(screen)
	battle = screen.battle
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	screen.hud.process_mode = Node.PROCESS_MODE_ALWAYS
	screen.hud.set_process(false)
	battle.water_rects = []
	battle.path_service.set_water([])
	battle._refresh_pathing()
	var unit = battle.spawn_unit("MTNK", "ally", Vector2(2200, 2400))
	activate(unit)
	await get_tree().physics_frame
	battle.select_unit(unit, false)
	battle._emit_selection()
	var first := Vector2(2300, 2400)
	var second := Vector2(2400, 2500)
	var third := Vector2(2500, 2400)
	var replacement := Vector2(2250, 2600)
	battle._command_move(first)
	var first_target: Vector2 = unit.move_target
	battle._command_move(second, true)
	battle._command_move(third, true)
	check(unit.move_target == first_target and unit.order_queue.size() == 2, mode + ": Shift appends without replacing current destination")
	var queued: Array = unit.order_queue.duplicate()
	arrive(unit)
	check(unit.move_target == queued[0] and unit.order_queue == [queued[1]], mode + ": first arrival advances one waypoint")
	arrive(unit)
	check(unit.move_target == queued[1] and unit.order_queue.is_empty(), mode + ": second arrival preserves and advances remaining waypoint")
	arrive(unit)
	check(not unit.has_move_order, mode + ": completed queue stays stopped")
	battle._command_move(first)
	battle._command_move(second, true)
	battle._command_move(replacement)
	check(unit.order_queue.is_empty(), mode + ": ordinary move replaces old Shift queue")
	arrive(unit)
	check(not unit.has_move_order, mode + ": replacement arrival does not resurrect old destination")
	battle._command_move(first)
	battle._command_move(second, true)
	battle._command_move(replacement, false, true)
	check(unit.attack_move and unit.order_queue.is_empty(), mode + ": attack-move replaces old Shift queue")
	var target = battle.spawn_unit("MTNK", "enemy", Vector2(2650, 2600))
	activate(target)
	battle._command_move(second, true)
	battle.force_attack(target)
	check(unit.attack_ordered and unit.attack_target == target and unit.order_queue.is_empty(), mode + ": explicit attack discards old movement queue")
	unit.order_stop()
	unit.position = Vector2(2200, 2400)
	battle._command_move(first)
	battle._command_move(second, true)
	screen.hud.cmd_buttons["patrol"].pressed.emit()
	battle._issue_command_at(replacement)
	check(unit.patrolling and unit.order_queue.is_empty(), mode + ": patrol starts with only its two endpoints")
	var origin: Vector2 = unit.patrol_points[0]
	arrive(unit)
	unit._process_combat(1.0 / 60.0)
	check(unit.patrolling and unit.has_move_order and unit.move_target == origin, mode + ": patrol returns to origin after outward leg")
	arrive(unit)
	unit._process_combat(1.0 / 60.0)
	check(unit.patrolling and unit.move_target == replacement, mode + ": patrol repeats after return leg")
	await key(KEY_S)
	check(not unit.patrolling and not unit.has_move_order and unit.order_queue.is_empty(), mode + ": S stops patrol and clears queue")
	var stopped: Vector2 = unit.position
	for tick in 60:
		unit._physics_process(1.0 / 60.0)
	check(unit.position.distance_to(stopped) < 0.01, mode + ": stopped patrol remains stationary across physics ticks")
	# Pending target modes must be cancelled by immediate stop/guard commands.
	battle.arm_command("attack")
	await key(KEY_S)
	check(battle.command_mode.is_empty(), mode + ": S cancels pending attack targeting")
	battle.arm_command("patrol")
	screen.hud.cmd_buttons["guard"].pressed.emit()
	check(battle.command_mode.is_empty() and unit.hold_position, mode + ": guard cancels pending patrol targeting")
	var depot = battle._place_building("GADEPT", "ally", Vector2(3000, 2600), true)
	depot.process_mode = Node.PROCESS_MODE_DISABLED
	# This frozen fixture represents an already completed service depot.
	depot._buildup_play = -1.0
	check(depot.is_operational(), mode + ": repair interruption fixture is operational")
	unit.hp = unit.max_hp * 0.5
	for command in ["stop", "guard", "move"]:
		unit.order_stop()
		unit.order_repair(depot)
		check(unit.repairing and unit.is_in_group("repair_docked"), mode + " " + command + ": real repair order active")
		if command == "move":
			battle._command_move(first)
		else:
			screen.hud.cmd_buttons[command].pressed.emit()
		check(not unit.repairing and unit.repair_depot == null and not unit.is_in_group("repair_docked"),
			mode + " " + command + ": new command releases repair state")
		var old_position: Vector2 = unit.position
		unit.position = unit._repair_dock
		var hp: float = unit.hp
		var funds: float = battle.funds
		depot._process_repair(1.0)
		check(unit.hp == hp and battle.funds == funds, mode + " " + command + ": cancelled repair neither heals nor charges")
		unit.position = old_position
		if command != "move":
			stopped = unit.position
			for tick in 60:
				unit._physics_process(1.0 / 60.0)
			check(unit.position.distance_to(stopped) < 0.01, mode + " " + command + ": old repair route does not resume")
	unit.order_stop()
	unit.hp = unit.max_hp - 4.0
	unit.order_repair(depot)
	unit.position = unit._repair_dock
	var repair_funds: float = battle.funds
	depot._process_repair(1.0)
	check(unit.hp == unit.max_hp and battle.funds < repair_funds, mode + ": uninterrupted repair still heals and charges")
	unit._physics_process(1.0 / 60.0)
	check(not unit.repairing and unit.has_move_order and unit.move_target.distance_to(unit.position) > 50.0,
		mode + ": completed repair still releases dock and orders exit")
	var passenger = battle.spawn_unit("E1", "ally", Vector2(3500, 3000))
	var carrier = battle.spawn_unit("SHAD", "ally", Vector2(3500, 3000))
	activate(passenger)
	activate(carrier)
	await get_tree().physics_frame
	battle.select_unit(passenger, false)
	check(passenger.logistics.request_board(carrier), mode + ": real boarding order accepted")
	screen.hud.cmd_buttons["guard"].pressed.emit()
	check(passenger.logistics.boarding == null and passenger.hold_position, mode + ": guard cancels boarding")
	for tick in 90:
		carrier._physics_process(1.0 / 60.0)
		passenger._physics_process(1.0 / 60.0)
	check(passenger.embarked_in == null and carrier.logistics.passengers.is_empty(), mode + ": cancelled boarding cannot complete later")
	await exercise_service_routes(mode)
	await exercise_building_route(mode)
	await exercise_attack_completion(mode)
	await exercise_saved_entry(mode)
	screen.free()
	await get_tree().process_frame

func exercise_service_routes(mode: String) -> void:
	for row in [["MTNK","GADEPT","depot"],["ORCA","GAAIRC","airfield"],["CMIN","GAREFN","refinery"]]:
		var building=battle._place_building(row[1],"ally",Vector2(900,2500),true)
		building._buildup_play=-1
		var unit=battle.spawn_unit(row[0],"ally",Vector2(600,2500))
		activate(unit)
		unit.hp=unit.max_hp*0.5
		battle.select_unit(unit,false)
		battle._issue_order(Vector2(720,2360))
		var first:Vector2=unit.move_target
		battle._issue_order(building.art_center(),true)
		check(unit.move_target==first and unit.order_queue.size()==1 and unit.order_queue[0].get("interaction")==row[2],mode+" queued service "+row[2])
		unit.position=first
		unit._physics_process(1.0/60.0)
		var started := false
		match row[2]:
			"depot": started = unit.repairing and unit.repair_depot == building
			"airfield": started = unit.logistics.home == building and unit.logistics.air_state == "returning"
			"refinery": started = unit.home_base == building and unit.harvest_state == "to_base"
		check(started and unit.order_queue.is_empty(),mode+" final waypoint activates "+row[2],[unit.logistics.air_state,unit.harvest_state])
		battle.clear_selection()
		battle.units.erase(unit)
		unit.free()
		battle.buildings.erase(building)
		building.free()
		battle._refresh_pathing()
	await get_tree().process_frame

func exercise_building_route(mode: String) -> void:
	var bunker = battle._place_building("NABNKR", "ally", Vector2(3400,2250), true)
	bunker._buildup_play = -1.0
	var gi = battle.spawn_unit("E1","ally", Vector2(3100,2250))
	activate(gi)
	await get_tree().physics_frame
	battle.select_unit(gi,false)
	battle._issue_order(Vector2(3160,2150))
	var first:Vector2 = gi.move_target
	battle._issue_order(Vector2(3280,2180),true)
	battle._issue_order(bunker.art_center(),true)
	check(gi.move_target == first and gi.order_queue.size() == 2 and not gi.special.has("action"),mode+" Shift bunker keeps both movement legs")
	for tick in 480:
		gi._physics_process(1.0/60.0)
		if gi.order_queue.size()!=2: break
	check(gi.order_queue.size()==1 and not gi.special.has("action"),mode+" first arrival only advances movement")
	for tick in 480:
		gi._physics_process(1.0/60.0)
		if gi.special.has("action"): break
	check(gi.special.get("action")=="allied_garrison" and gi.special.get("target")==bunker and gi.embarked_in==null,mode+" last arrival starts garrison approach")
	for tick in 360:
		gi._physics_process(1.0/60.0)
		if gi.embarked_in==bunker: break
	check(gi.embarked_in==bunker and bunker.special.get("occupants",[]).has(gi),mode+" infantry walks through entry and occupies bunker")
	var engineer=battle.spawn_unit("ENGINEER","ally",Vector2(3050,1850))
	var power=battle._place_building("GAPOWR","enemy",Vector2(3450,1850),true)
	power._buildup_play=-1.0
	activate(engineer)
	battle.select_unit(engineer,false)
	battle._issue_order(Vector2(3150,1850))
	battle._issue_order(power.art_center(),true)
	check(engineer.order_queue.size()==1 and not engineer.special.has("action"),mode+" engineer queues capture")
	engineer.order_stop()
	check(engineer.order_queue.is_empty() and power.side=="enemy",mode+" stop cancels queued capture")
	battle._issue_order(Vector2(3150,1850))
	battle._issue_order(power.art_center(),true)
	var next_point := Vector2(3220,1980)
	engineer.queue_waypoint(next_point)
	battle.buildings.erase(power)
	power.free()
	arrive(engineer)
	check(engineer.move_target==next_point and not engineer.attack_ordered and not engineer.special.has("action"),mode+" destroyed destination skips to later waypoint")
	# A full bunker at execution time must not redirect the remaining squad.
	var spare = battle.spawn_unit("E1","ally",Vector2(3090,2450))
	activate(spare)
	battle.select_unit(spare,false)
	battle._issue_order(Vector2(3150,2450))
	battle._issue_order(bunker.art_center(),true)
	var occupants:Array=bunker.special.occupants.duplicate()
	while bunker.special.occupants.size()<int(bunker.data.garrison_slots): bunker.special.occupants.append(gi)
	arrive(spare)
	check(spare.embarked_in==null and not spare.special.has("action") and not spare.has_move_order,mode+" full bunker skips queued entry")
	bunker.special.occupants=occupants

func exercise_attack_completion(mode: String) -> void:
	for id in ["MTNK", "E1", "JUMPJET", "CLEG", "ORCA"]:
		var actor = battle.spawn_unit(id, "ally", Vector2(3700, 3700))
		var enemy = battle.spawn_unit("MTNK", "enemy", Vector2(3950, 3700))
		activate(actor)
		activate(enemy)
		actor.set_fire_stance("free")
		await get_tree().physics_frame
		battle.select_unit(actor, false)
		battle.force_attack(enemy)
		check(actor.attack_ordered and actor.attack_target == enemy and not actor.attack_move,
			mode + " " + id + ": explicit attack does not enable attack-move")
		# Legacy saves may have both flags set: a new explicit order replaces them.
		actor.attack_move = true
		battle.force_attack(enemy)
		enemy.hp = 0.0
		actor._refresh_target()
		check(not actor.attack_ordered and not actor.attack_move and not actor.has_move_order and actor.attack_target == null,
			mode + " " + id + ": lost target completes engagement without continuing old route")
		var stopped: Vector2 = actor.position
		actor._process_combat(1.0 / 60.0)
		check(actor.position.distance_to(stopped) < 0.01,
			mode + " " + id + ": completed attack remains stationary")
		battle.units.erase(actor)
		battle.units.erase(enemy)
		actor.free()
		enemy.free()
	var tank = battle.spawn_unit("MTNK", "ally", Vector2(3700, 3700))
	var target = battle.spawn_unit("MTNK", "enemy", Vector2(3800, 3700))
	activate(tank)
	activate(target)
	tank.set_fire_stance("free")
	await get_tree().physics_frame
	tank._refresh_target()
	check(tank.attack_target == target and not tank.attack_ordered,
		mode + ": ordinary in-range guard targeting is preserved")
	tank._burst_target = target
	tank._burst_left = 2
	tank.order_move(Vector2(3700, 3950))
	check(tank.attack_target == null and tank._burst_left == 0 and not tank.attack_ordered and not tank.attack_move,
		mode + ": ordinary move clears previous engagement and queued shots immediately")
	tank.order_move(Vector2(3950, 3950), true)
	tank._refresh_target()
	check(tank.attack_move and tank.attack_target == target,
		mode + ": intentionally issued attack-move still acquires targets")
	tank._burst_target = target
	tank._burst_left = 2
	tank.order_stop()
	check(tank._burst_left == 0 and tank.attack_target == null and not tank.attack_move,
		mode + ": stop cancels remaining burst and attack route")

func exercise_saved_entry(mode: String) -> void:
	var spy=battle.spawn_unit("SPY","ally",Vector2(400,3300))
	var lab=battle._place_building("GATECH","enemy",Vector2(740,3300),true)
	lab._buildup_play=-1.0
	activate(spy)
	battle.select_unit(spy,false)
	battle._issue_order(Vector2(620,3300))
	battle._issue_order(lab.art_center(),true)
	var snap=BattleSaves.Snapshot.new().capture(battle)
	BattleSaves.Snapshot.new().restore(battle,snap)
	get_tree().paused=false
	battle.paused=false
	var loaded=battle.selected_units[0]
	check(loaded.unit_id=="SPY" and loaded.has_move_order and loaded.order_queue.size()==1,mode+" save restores move before infiltration")
	if loaded.order_queue.is_empty(): return
	var restored_lab=loaded.order_queue[0].get("target")
	loaded.process_mode=Node.PROCESS_MODE_ALWAYS
	loaded.set_physics_process(false)
	restored_lab.disable_mode=CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
	await get_tree().physics_frame
	check(battle.buildings.has(restored_lab) and loaded.order_queue[0].interaction=="allied_infiltrate",mode+" restored terminal points to restored building")
	arrive(loaded)
	for tick in 450:
		loaded._physics_process(1.0/60.0)
		if loaded._dead: break
	check(loaded._dead and battle.allied_state.get("stolen_ally_RequiresStolenAlliedTech",false),mode+" restored spy finishes actual infiltration")
	await get_tree().process_frame

func activate(actor) -> void:
	actor.process_mode = Node.PROCESS_MODE_ALWAYS
	actor.set_process(false)
	actor.set_physics_process(false)
	actor.set_fire_stance("none")
	actor.order_stop()

func arrive(actor) -> void:
	# Place at the issued destination, then let the real arrival logic consume it.
	# Route traversal is separately covered by navigation_building_regression.
	actor.position = actor.move_target
	actor.velocity = Vector2.ZERO
	actor._process_combat(1.0 / 60.0)
