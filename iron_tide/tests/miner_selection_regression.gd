extends "res://tests/selection_regression.gd"
## Real viewport gestures; production picking and selection are not replaced.

func expect_selected(expected: Array, label: String) -> void:
	check(battle.selected_units.size() == expected.size() and expected.all(func(u): return battle.selected_units.has(u)), label, battle.selected_units.map(func(u): return u.unit_id))
	check(battle.units.all(func(u): return u.selected == expected.has(u)), label + " visual flags match")

func exercise_mode(mode: String) -> void:
	BattleRequest.configure_skirmish(mode, {"map_size": 5000, "starting_funds": 8000})
	screen = load("res://scenes/battle.tscn").instantiate()
	stage.add_child(screen)
	battle = screen.battle
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	battle.process_mode = Node.PROCESS_MODE_ALWAYS
	battle.set_process(false); battle.set_physics_process(false)
	for child in battle.get_children(): child.process_mode = Node.PROCESS_MODE_DISABLED
	screen.hud.process_mode = Node.PROCESS_MODE_ALWAYS
	screen.hud.set_process(false)
	for actor in battle.units: actor.free()
	battle.units.clear()
	var miners: Array = []
	for i in 2: miners.append(battle.spawn_unit("CMIN", "ally", Vector2(2400,2400)))
	var tank = battle.spawn_unit("MTNK", "ally", Vector2(2400,2400))
	var engineer = battle.spawn_unit("ENGINEER", "ally", Vector2(2400,2400))
	var enemy = battle.spawn_unit("MTNK", "enemy", Vector2(2400,2400))
	var dead = battle.spawn_unit("MTNK", "ally", Vector2(2400,2400))
	var passenger = battle.spawn_unit("E1", "ally", Vector2(2400,2400))
	dead.hp = 0.0
	passenger.embarked_in = tank
	for actor in battle.units: actor.process_mode = Node.PROCESS_MODE_DISABLED
	get_window().focus_entered.emit()
	for zoom in [0.5,1.0,2.0]:
		battle.camera.position = Vector2(2500,2500)
		battle.camera.zoom = Iso.cam_zoom(zoom)
		battle.camera.force_update_scroll()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		place_art_at(miners[0],Vector2(450,350)); place_art_at(miners[1],Vector2(600,390))
		place_art_at(tank,Vector2(750,350)); place_art_at(engineer,Vector2(900,500))
		place_art_at(enemy,Vector2(530,370)); place_art_at(dead,Vector2(560,430)); place_art_at(passenger,Vector2(580,450))
		var prefix := "%s zoom %.1f: " % [mode,zoom]
		await gesture(Vector2(400,300),Vector2(800,480))
		expect_selected([tank],prefix+"mixed box excludes both miners")
		await gesture(Vector2(800,480),Vector2(400,300))
		expect_selected([tank],prefix+"reverse box excludes miners")
		await gesture(Vector2(400,300),Vector2(670,480))
		expect_selected(miners,prefix+"miners-only box ignores enemy dead and passenger priority")
		await gesture(Vector2(420,320),Vector2(490,380))
		expect_selected([miners[0]],prefix+"one miner can be boxed")
		battle.select_unit(tank,false); battle._emit_selection()
		await gesture(Vector2(400,300),Vector2(670,480),true)
		expect_selected([tank,miners[0],miners[1]],prefix+"Shift miner-only box intentionally appends miners")
		battle.select_unit(miners[0],false); battle._emit_selection()
		await gesture(Vector2(400,300),Vector2(800,480),true)
		expect_selected([miners[0],tank],prefix+"Shift mixed box preserves prior miner but excludes new miner")
		battle._last_click_unit = null
		await gesture(Vector2(450,350),Vector2(450,350))
		expect_selected([miners[0]],prefix+"direct click still selects miner")
		battle.select_unit(tank,false); battle._last_click_unit = null; battle._emit_selection()
		await gesture(Vector2(450,350),Vector2(450,350),true)
		expect_selected([tank,miners[0]],prefix+"Shift click explicitly adds miner")
		place_art_at(tank,Vector2(900,550)); place_art_at(engineer,Vector2(750,350))
		await gesture(Vector2(400,300),Vector2(800,480))
		expect_selected([engineer],prefix+"unarmed non-miner retains normal priority")
		await gesture(Vector2(300,230),Vector2(350,280))
		expect_selected([],prefix+"empty normal box clears selection")
	screen.free()
	await get_tree().process_frame
