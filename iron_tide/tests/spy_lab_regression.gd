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
	var barracks = battle._place_building("GAPILE", "ally", Vector2(1300, 1300), true)
	var opposing_barracks = battle._place_building("GAPILE", "enemy", Vector2(2800, 2800), true)
	for b in [barracks, opposing_barracks]: b._buildup_play = -1.0
	var target = battle._place_building("GATECH", "enemy", Vector2(2107, 2109), true)
	target.process_mode = Node.PROCESS_MODE_ALWAYS
	target.set_process(false); target._buildup_play = -1.0
	battle._refresh_pathing()
	var spy = actor("SPY", "ally", target.position + Vector2(450, 0))
	battle.select_unit(spy, false)
	check(battle.command_cursor.resolve(target.art_center()) == "enter", mode + ": lab has entry cursor")
	check(not barracks.can_queue("CCOMAND") and not barracks.enqueue("CCOMAND"), mode + ": own ordinary buildings cannot replace stolen tech")
	check(("盟军" if mode==MatchRules.RA2 else "海豹击杀") in barracks.queue_block_reason("CCOMAND"), mode + ": locked production explains required lab")
	battle._issue_order(target.art_center())
	check(spy.special.get("action") == "allied_infiltrate", mode + ": right-click lab accepts infiltration")
	await get_tree().physics_frame
	for tick in 1800:
		spy._physics_process(1.0 / 60.0)
		if spy._dead: break
		if tick % 30 == 0: await get_tree().physics_frame
	check(spy._dead and battle.allied_state.get("stolen_ally_RequiresStolenAlliedTech", false), mode + ": spy enters lab and earns allied tech")
	if mode==MatchRules.EXTENDED:
		check(barracks.can_queue("CCOMAND"), "new extension spy theft independently unlocks production")
		check(not battle.owned_building_ids().has("GATECH"), "stolen unlock needs neither own lab nor card objective")
		check(not GameData.production_prerequisites("CCOMAND",battle.allied_state).has("TECH"), "stolen route guide preserves original prerequisites")
	check(barracks.can_queue("CCOMAND") and barracks.queue_block_reason("CCOMAND").is_empty(), mode + ": allied barracks unlocks chrono commando", barracks.queue_block_reason("CCOMAND"))
	check(not opposing_barracks.can_queue("CCOMAND"), mode + ": enemy does not inherit player's unlock")
	check(not barracks.can_queue("PTROOP"), mode + ": allied tech does not grant Yuri tech")
	var hud = screen.hud
	hud.select_prod_tab("infantry"); hud._refresh_production(); hud._update_production_live()
	await get_tree().process_frame
	check(hud._unit_state("CCOMAND").ok and not hud._prod_buttons.CCOMAND.disabled, mode + ": real HUD card unlocks")
	check(not "窃取" in hud._unlock_guide("CCOMAND").detail, mode + ": unlock guide consumes earned tech")
	battle.buildings.erase(target); target.free()
	check(barracks.can_queue("CCOMAND"), mode + ": destruction of infiltrated lab does not revoke tech")
	check(barracks.enqueue("CCOMAND"), mode + ": actual production accepts unlocked unit")
	for tick in 100:
		barracks._process(1.0)
		if barracks.production.is_empty(): break
	var created: Array = battle.units.filter(func(u): return is_instance_valid(u) and u.unit_id == "CCOMAND")
	check(created.size() == 1, mode + ": completed queue actually spawns chrono commando")
	var saved := BattleSaves.save_slot(battle, "quick")
	var loaded := BattleSaves.read_slot("quick")
	check(saved.ok and loaded.ok, mode + ": stolen tech writes and reads existing save schema")
	if loaded.ok:
		BattleSaves.Snapshot.new().restore(battle, loaded.snapshot)
		battle.paused = false; get_tree().paused = false
		barracks = battle.buildings.filter(func(b): return b.side == "ally" and b.building_id == "GAPILE")[0]
		check(barracks.can_queue("CCOMAND"), mode + ": saved technology still unlocks production")
		check(not GameData.unit_production_block_reason("CCOMAND").is_empty(), mode + ": unlock is per battle, not global GameData")
	screen.free()
	await get_tree().process_frame
	setup_logistics_scene(mode, "美国")
	check(not battle.allied_state.has("stolen_ally_RequiresStolenAlliedTech"), mode + ": new match does not inherit stolen tech")
	screen.free()
	await get_tree().process_frame
