extends "res://tests/allied_abilities_regression.gd"

func exercise_mode(mode: String) -> void:
	get_tree().paused = false
	setup_logistics_scene(mode, "美国")
	for group in ["obstacles", "resource_nodes"]:
		for node in get_tree().get_nodes_in_group(group): node.free()
	for node in battle.units + battle.buildings: node.free()
	battle.units.clear(); battle.buildings.clear()
	battle.water_rects = []; battle.path_service.set_water([])
	if battle.fog != null: battle.fog.free(); battle.fog = null
	battle._refresh_pathing()
	var spy = actor("SPY", "ally", Vector2(1400, 1400))
	var enemy = actor("E1", "enemy", Vector2(1600, 1400))
	battle.select_unit(spy, false)
	spy.order_move(Vector2(1800, 1800))
	check(battle.command_cursor.resolve(enemy.art_center()) == "attack", mode + ": enemy infantry has actionable pointer")
	battle._issue_order(enemy.art_center())
	check(spy.special.get("disguise") == "E1", mode + ": actual right-click copies infantry")
	check(not spy.has_move_order and spy.attack_target == null and not spy.attack_ordered, mode + ": disguise stops old order without chasing or attacking")
	var visual := AlliedAbilities.disguise_visual(spy)
	check(not visual.is_empty() and visual.art.tex == RA2Art.art("E1").tex, mode + ": displayed sprite uses target infantry sheet")
	check(enemy.hp == enemy.max_hp and spy.unit_id == "SPY", mode + ": appearance does not damage target or replace spy identity")
	if DisplayServer.get_name() != "headless":
		battle.camera.position = Vector2(1500, 1400)
		battle.camera.zoom = Vector2(3, 1.5)
		battle.camera.reset_smoothing(); battle.camera.force_update_scroll()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		stage.get_texture().get_image().save_png(output_dir.path_join(mode + "-spy-disguise.png"))
	var other = actor("GGI", "enemy", Vector2(1700, 1400))
	battle.command_mode = "attack"
	check(battle.command_cursor.resolve(other.art_center()) == "attack", mode + ": attack mode also permits disguise")
	battle.force_attack(other)
	check(spy.special.get("disguise") == "GGI" and not spy.attack_ordered, mode + ": explicit attack changes disguise")
	battle.command_mode = ""
	var soldier = actor("E1", "ally", Vector2(1400, 1500))
	battle.select_unit(soldier, true)
	battle._issue_order(enemy.art_center())
	check(spy.special.get("disguise") == "E1" and spy.attack_target == null, mode + ": mixed group spy disguises")
	check(soldier.attack_target == enemy and soldier.attack_ordered, mode + ": mixed group combatant still attacks")
	battle.clear_selection(); battle.select_unit(spy, false)
	var tank = actor("MTNK", "enemy", Vector2(1800, 1400))
	check(battle.command_cursor.resolve(tank.art_center()) == "blocked", mode + ": vehicles cannot be copied")
	battle.force_attack(tank)
	check(spy.special.get("disguise") == "E1" and not spy.has_move_order and spy.attack_target == null, mode + ": rejected vehicle attack does not chase or erase disguise")
	check(not AlliedAbilities.use(spy, "allied_disguise", soldier), mode + ": friendly infantry rejected")
	check(not AlliedAbilities.use(soldier, "allied_disguise", enemy), mode + ": ordinary soldiers cannot invoke disguise")
	spy._stun_timer = 1.0
	check(not AlliedAbilities.can_order(spy, enemy, "allied_disguise") and battle.command_cursor.resolve(enemy.art_center()) == "blocked", mode + ": stunned spy cursor and dispatch reject together")
	spy._stun_timer = 0.0
	other.hp = 0.0
	check(not AlliedAbilities.use(spy, "allied_disguise", other), mode + ": dead target rejected")
	other.hp = other.max_hp
	var carrier = actor("FV", "enemy", Vector2(1900, 1500))
	other.embarked_in = carrier
	check(not AlliedAbilities.use(spy, "allied_disguise", other), mode + ": embarked target rejected")
	other.embarked_in = null
	var lab = battle._place_building("GATECH", "enemy", Vector2(2400, 2200), true)
	lab._buildup_play = -1.0
	check(battle.command_cursor.resolve(lab.art_center()) == "enter", mode + ": buildings retain infiltration pointer")
	battle._issue_order(lab.art_center())
	check(spy.special.get("action") == "allied_infiltrate", mode + ": building right-click remains infiltration")
	battle.force_attack(enemy)
	check(not spy.special.has("action") and not spy.has_move_order, mode + ": new disguise cancels prior infiltration")
	check(AlliedAbilities.concealed(spy, "enemy"), mode + ": copied appearance retains disguise concealment")
	var dog = actor("DOG", "enemy", spy.position + Vector2(40, 0))
	check(not AlliedAbilities.concealed(spy, "enemy"), mode + ": dog can still detect spy")
	remove_actor(dog)
	var saved := BattleSaves.save_slot(battle, "quick")
	var loaded := BattleSaves.read_slot("quick")
	check(saved.ok and loaded.ok, mode + ": disguise saves through normal save entry")
	if loaded.ok:
		BattleSaves.Snapshot.new().restore(battle, loaded.snapshot)
		spy = battle.units.filter(func(u): return u.unit_id == "SPY")[0]
		check(spy.special.get("disguise") == "E1" and not AlliedAbilities.disguise_visual(spy).is_empty(), mode + ": loading restores copied model")
	screen.free()
	get_tree().paused = false
	await get_tree().process_frame
