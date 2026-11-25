extends "res://tests/allied_abilities_regression.gd"

func exercise_mode(mode: String) -> void:
	setup_logistics_scene(mode, "美国")
	for unit in battle.units: unit.free()
	battle.units.clear()
	for building in battle.buildings: building.free()
	battle.buildings.clear()
	for group in ["obstacles", "resource_nodes"]:
		for node in get_tree().get_nodes_in_group(group): node.free()
	battle.water_rects.clear()
	battle.path_service.set_water([])
	if battle.fog != null: battle.fog.free(); battle.fog = null
	battle._refresh_pathing()
	for id in ["GAPOWR", "GAREFN", "GAPILE", "GAWEAP", "GATECH", "NAWEAP", "NAHAND", "NAREFN", "NAPOWR", "NANRCT"]:
		var target = battle._place_building(id, "enemy", Vector2(2107, 2109), true)
		target.process_mode = Node.PROCESS_MODE_ALWAYS
		target.set_process(false)
		target._buildup_play = -1.0
		battle._refresh_pathing()
		await get_tree().physics_frame
		for direction in 8:
			battle.funds = 20000.0
			battle.enemy_funds = 8000.0
			battle.allied_state.clear()
			var spy = actor("SPY", "ally", target.position + Vector2.RIGHT.rotated(direction * PI / 4.0) * 500.0)
			battle.select_unit(spy, false)
			battle._issue_order(target.position + (target.footprint_poly()[0] + target.footprint_poly()[2]) * 0.5)
			var label := "%s %s direction=%d " % [mode, id, direction]
			check(spy.special.get("action") == "allied_infiltrate", label + "right-click dispatches infiltration")
			var end: Vector2 = spy.position
			for tick in 1200:
				spy._physics_process(1.0 / 60.0)
				end = spy.position
				if spy._dead: break
				if tick % 30 == 0: await get_tree().physics_frame
			check(spy._dead, label + "real navigation reaches building and infiltrates", {"position":str(end),"action":spy.special.get("action", ""),"goal":str(AlliedAbilities.approach(spy,target))})
			check(not spy._dead or Geometry2D.is_point_in_polygon(end-target.position,target.footprint_poly()), label + "consumption occurs inside actual footprint")
			check(spy.get_collision_exceptions().is_empty(), label + "entry leaves no collision exceptions")
			var effect: bool = battle.funds == 24000.0 and battle.enemy_funds == 4000.0 if id in ["GAREFN", "NAREFN"] else battle.allied_state.has("blackout_enemy") if id in ["GAPOWR", "NAPOWR", "NANRCT"] else battle.allied_state.get("stolen_ally_RequiresStolenAlliedTech", false) if id == "GATECH" else battle.allied_state.get("training_ally_" + str({"NAWEAP":"GAWEAP", "NAHAND":"GAPILE"}.get(id, id)), false)
			check(effect, label + "correct infiltration benefit applies exactly once")
			if direction == 7 and id in ["NAHAND", "NAWEAP"]:
				var uid := "E1" if id == "NAHAND" else "MTNK"
				var alias := "GAPILE" if id == "NAHAND" else "GAWEAP"
				for producer_id in [alias, id]:
					var producer = battle._place_building(producer_id, "ally", Vector2(600, 800), true)
					var recruit = battle.spawn_unit(uid, "ally", Vector2(800, 800), producer)
					check(recruit.veteran_level == 1, label + producer_id + " produces a veteran after infiltration")
					remove_actor(recruit)
					battle.buildings.erase(producer)
					producer.free()
			remove_actor(spy)
		battle.buildings.erase(target)
		target.free()
		await get_tree().physics_frame
	await check_boundaries(mode)
	await check_gui_commands(mode)
	screen.free()
	await get_tree().process_frame

func check_boundaries(mode: String) -> void:
	var target = battle._place_building("GAPOWR", "enemy", Vector2(2107, 2109), true)
	target.process_mode = Node.PROCESS_MODE_ALWAYS
	target.set_process(false)
	target._buildup_play = -1.0
	var spy = actor("SPY", "ally", target.position + Vector2(200, 0))
	spy.position = AlliedAbilities.approach(spy, target)
	# A thin physical barrier across the last entry segment must still block entry.
	var barrier := StaticBody2D.new()
	barrier.process_mode = Node.PROCESS_MODE_ALWAYS
	barrier.collision_layer = target.collision_layer
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(8, 180)
	shape.shape = box
	barrier.add_child(shape)
	barrier.position = spy.position - Vector2(12, 0)
	battle.add_child(barrier)
	await get_tree().physics_frame
	battle.allied_state.clear()
	check(AlliedAbilities.use(spy, "allied_infiltrate", target), mode + " accepts order with blocked entry")
	for tick in 180: spy._physics_process(1.0 / 60.0)
	check(not spy._dead and not battle.allied_state.has("blackout_enemy"), mode + " final approach cannot infiltrate through another collider")
	check(spy.get_collision_exceptions().is_empty(), mode + " blocked entry restores collision")
	spy.order_stop()
	check(not spy.special.has("action"), mode + " stop cancels blocked infiltration")
	barrier.free()
	await get_tree().physics_frame
	var before: Vector2 = spy.position
	spy._physics_process(0.1)
	check(not spy._dead and spy.position.distance_to(before) < 1.0, mode + " removing barrier does not resume cancelled infiltration")
	target.side = "ally"
	check(not AlliedAbilities.use(spy,"allied_infiltrate",target), mode + " rejects own building")
	target.side = "enemy"
	target.under_construction = true
	check(not AlliedAbilities.use(spy,"allied_infiltrate",target), mode + " rejects incomplete building")
	target.under_construction = false
	AlliedAbilities.use(spy,"allied_infiltrate",target)
	target.hp = 0.0
	spy._physics_process(0.1)
	check(not spy._dead and not spy.special.has("action"), mode + " target destruction cancels without consuming spy or reward")
	remove_actor(spy)
	battle.buildings.erase(target)
	target.free()

func check_gui_commands(mode: String) -> void:
	var target = battle._place_building("GAPOWR", "enemy", Vector2(2107, 2109), true)
	target.process_mode = Node.PROCESS_MODE_ALWAYS
	target.set_process(false)
	target._buildup_play = -1.0
	battle._refresh_pathing()
	var spy = actor("SPY", "ally", Vector2(2000, 1600))
	battle.process_mode = Node.PROCESS_MODE_ALWAYS
	battle.set_process(false)
	battle.set_physics_process(false)
	battle.camera.position = target.position
	battle.camera.zoom = Vector2(1, 0.5)
	battle.camera.reset_smoothing()
	battle.camera.force_update_scroll()
	get_window().focus_entered.emit()
	battle.select_unit(spy, false)
	battle._emit_selection()
	await get_tree().process_frame
	var point: Vector2 = stage.get_canvas_transform() * target.art_center()
	check(battle.command_cursor.resolve(target.art_center()) == "enter", mode + " valid target shows entry cursor")
	await mouse_button(point,true,false,MOUSE_BUTTON_RIGHT)
	await mouse_button(point,false,false,MOUSE_BUTTON_RIGHT)
	check(spy.special.get("action") == "allied_infiltrate", mode + " real right-click dispatches infiltration")
	spy.order_stop()
	await key(KEY_Q)
	check(battle.cast_slot >= 0, mode + " Q opens native infiltration targeting")
	await mouse_button(point,true)
	await mouse_button(point,false)
	check(spy.special.get("action") == "allied_infiltrate", mode + " Q plus actual building click dispatches infiltration")
	for tick in 1200:
		spy._physics_process(1.0/60.0)
		if spy._dead: break
		if tick % 30 == 0: await get_tree().physics_frame
	check(spy._dead, mode + " GUI skill order reaches entry and completes")
