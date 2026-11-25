extends "res://tests/allied_abilities_regression.gd"
const Tools=preload("res://scripts/admin/gm_unit_tools.gd")

func exercise_mode(mode:String) -> void:
	setup_logistics_scene(mode,"美国")
	for node in battle.units+battle.buildings:node.free()
	battle.units.clear();battle.buildings.clear()
	if battle.fog!=null:battle.fog.free();battle.fog=null
	battle.water_rects=[];battle.path_service.set_water([]);battle._refresh_pathing()
	battle.camera.position=Vector2(1500,1500)
	battle.camera.reset_smoothing();battle.camera.force_update_scroll()
	for i in 3:await get_tree().process_frame
	var ids:=Tools.target_ids()
	for id in ["E1","MTNK","R3MIRAGE","R3FUTURE","R3HARBINGER"]:
		check(ids.count(id)==1,"target roster includes one "+id)
	# Registration of a new RA3 unit must be enough; no hardcoded target edit.
	var probe:Dictionary=GameData.unit_index.MTNK.duplicate(true)
	probe.id="R3GM_TARGET_PROBE";probe.name="GM regression probe"
	GameData.unit_index[probe.id]=probe
	check(Tools.target_ids().has(probe.id),"newly registered RA3 unit automatically becomes a target")
	var panel=preload("res://scripts/admin/gm_unit_panel.gd").new()
	var messages:Array=[];panel.notify=func(message):messages.append(message)
	battle.hud.add_child(panel)
	panel._filter("R3")
	var pick: int = panel.ids.find("R3REAPER")
	panel.choices.select(pick)
	panel.choices.item_selected.emit(pick)
	panel.search.text = "no such unit"
	panel.search.text_changed.emit(panel.search.text)
	panel.hide()
	panel.show()
	check(panel.ids[panel.choices.selected] == "R3REAPER", mode + " reopen restores last explicit choice after empty search")
	panel._filter("R3FUTURE")
	panel.get_node("SpawnUnit").pressed.emit()
	check(battle.units.size() == 1 and battle.units[0].unit_id == "R3FUTURE", mode + " single filtered result spawns chosen unit")
	panel.get_node("ClearSpawns").pressed.emit()
	await get_tree().process_frame
	panel.free()
	panel = preload("res://scripts/admin/gm_unit_panel.gd").new()
	panel.notify = func(message): messages.append(message)
	battle.hud.add_child(panel)
	check(panel.ids[panel.choices.selected] == "R3FUTURE", mode + " newly created console restores last spawned unit from disk")
	messages.clear()
	panel.get_node("SpawnTargets").pressed.emit()
	check(messages.size()==1 and "全部已接入 RA3" in messages[0],"real GM button reports the dynamic roster")
	for id in Tools.target_ids():
		var matches=battle.units.filter(func(u):return u.unit_id==id)
		check(matches.size()==1,"actual target button spawns one "+id)
		if matches.size()==1:
			var unit=matches[0]
			check(unit.side=="enemy" and unit.special.get("gm_stationary",false) and unit.fire_stance=="none" and unit.is_physics_processing(),id+" disables combat without disabling lifecycle callbacks")
	GameData.unit_index.erase(probe.id)
	check(not Tools.target_ids().has(probe.id),"removed registration does not leave a stale target")
	panel.get_node("ClearSpawns").pressed.emit()
	await get_tree().process_frame
	check(battle.units.is_empty(),"GM cleanup removes every generated target")
	battle.water_rects = [Rect2(220,220,640,512)]
	battle.path_service.set_water(battle.water_rects)
	battle._countries["enemy"] = "Russians"
	for team in ["ally","enemy"]:
		panel.side.select(0 if team == "ally" else 1)
		panel.count.value = 5
		panel.get_node("SpawnFaction").pressed.emit()
		var faction: String = battle.roster_faction(team)
		var expected := GameData.faction_unit_catalog(faction)
		var actual: Array = battle.units.map(func(u): return u.unit_id)
		var naval_id := "DLPH" if team == "ally" else "SUB"
		check(expected.has(naval_id) and expected.has("R3FUTURE" if team=="ally" else "R3APOC") == (mode == MatchRules.EXTENDED),mode+" "+faction+" includes navy and respects expansion mode")
		check(actual.size()==expected.size() and battle.buildings.is_empty() and not actual.has("DMISL"),faction+" spawns full faction once and no buildings",messages.back())
		for id in expected: check(actual.count(id)==1,faction+" exactly one "+id)
		var ships = battle.units.filter(func(u):return u.unit_id==naval_id)
		check(ships.size()==1 and battle.in_water_world(ships[0].position) and ships[0].side==team,faction+" finds offscreen water for its own navy")
		if team=="ally":
			battle.selected_units.clear()
			for unit in battle.units:
				if unit.unit_id in ["MTNK","E1","R3FUTURE"]:
					battle.selected_units.append(unit)
					if unit.unit_id != "MTNK": unit._grant_veteran(2,false)
			panel.get_node("PromoteOnce").pressed.emit()
			for unit in battle.selected_units:
				check(unit.veteran_level==int({"MTNK":1,"E1":2,"R3FUTURE":3}[unit.unit_id]),unit.unit_id+" promotion is relative to current rank")
		panel.get_node("ClearSpawns").pressed.emit()
		await get_tree().process_frame
	screen.free();await get_tree().process_frame
