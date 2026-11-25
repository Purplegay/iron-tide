extends "res://tests/selection_regression.gd"

func exercise_mode(mode: String) -> void:
	BattleRequest.configure_skirmish(mode, {"map_size": 3200, "starting_funds": 10000, "country": "美国"})
	screen = load("res://scenes/battle.tscn").instantiate()
	stage.add_child(screen)
	battle = screen.battle
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	GM.infinite_funds = false
	var hud = screen.hud
	var yard = battle._place_building("GAYARD", "ally", Vector2(1600, 1800), true)
	var barracks = battle._place_building("GAPILE", "ally", Vector2(1200, 1400), true)
	for producer in [yard, barracks]: producer._buildup_play = -1.0
	for id in ["GAAIRC", "GATECH"]:
		var b = battle._place_building(id, "ally", Vector2(2100, 1800), true)
		b._buildup_play = -1.0
	var prefix := mode + ": "
	await audit_all_tabs(mode, hud)
	var catalog: Array = hud._unit_catalog()
	check(not catalog.has("CDEST") and not yard.buildable.has("CDEST"), prefix + "scenario boat absent from HUD and shipyard")
	for id in ["CDEST", "HORNET", "ASW", "SUB", "not_a_unit"]:
		var funds: float = battle.funds
		check(not yard.enqueue(id) and not yard.can_queue(id), prefix + "direct player/AI order rejects " + id)
		check(not hud._unit_state(id).ok and not str(hud._unit_state(id).reason).is_empty(), prefix + "same catalog rejection has explanation " + id)
		check(yard.production.is_empty() and battle.funds == funds, prefix + "rejection leaves funds and queue unchanged " + id)
	check(not catalog.has("PTROOP") and not barracks.can_queue("PTROOP"),prefix+"psychic commando fully hidden")
	var secret:="CCOMAND"
	var reason_text:="窃取" if mode==MatchRules.RA2 else "海豹击杀"
	check(catalog.has(secret),prefix+"chrono commando discoverable")
	check(not barracks.enqueue(secret) and not barracks.can_queue(secret),prefix+"ordinary prerequisites cannot bypass special condition")
	check(reason_text in barracks.queue_block_reason(secret),prefix+"exact unlock condition explained")
	hud.select_prod_tab("infantry")
	hud._refresh_production()
	await get_tree().process_frame
	check(not hud._prod_buttons.has("PTROOP"),prefix+"no hidden psychic UI card")
	check(hud._prod_buttons.has(secret) and hud._prod_buttons[secret].disabled and reason_text in hud._prod_buttons[secret].tooltip_text,prefix+"actual locked tooltip")
	var guide:Dictionary=hud._unlock_guide(secret)
	check(reason_text in guide.detail and not "已满足" in guide.detail and guide.get("steps",[]).is_empty(),prefix+"no invented ordinary route")
	hud._show_unlock_panel(secret)
	check(hud._unlock_panel.visible and reason_text in hud._unlock_panel.message.text,prefix+"real unlock panel condition")
	hud._close_unlock_panel()
	# A pre-patch save may contain these paid orders. Pause safely, keep refunds usable.
	for pair in [[yard, "CDEST"], [barracks, "PTROOP"]]:
		var producer = pair[0]
		var id: String = pair[1]
		producer.production = [id]
		producer.progress = 2.0
		producer.production_paid = 100.0
		var funds: float = battle.funds
		producer._process(10.0)
		check(producer.progress == 2.0 and producer.production_paid == 100.0 and battle.funds == funds, prefix + "legacy prohibited queue cannot continue " + id)
		check(not hud._production_status("生产中", 0.0, producer).is_empty() and hud._production_status("生产中", 0.0, producer) != "生产中", prefix + "legacy paused queue explains restriction " + id)
		check(producer.cancel_at(0) and producer.production.is_empty() and battle.funds == funds + 100.0, prefix + "legacy paid queue cancellable with exact refund " + id)
	for id in ["LCRF", "DEST", "AEGIS", "CARRIER", "DLPH"]:
		check(catalog.has(id) and yard.enqueue(id), prefix + "legitimate Allied navy buildable " + id)
		yard.cancel_at(0)
	for id in ["E1", "ENGINEER", "GGI", "JUMPJET", "GHOST", "CLEG", "SPY", "TANY"]:
		check(barracks.enqueue(id), prefix + "legitimate Allied infantry buildable " + id)
		barracks.cancel_at(0)
	check(not barracks.enqueue("SNIPE") and "英国" in barracks.queue_block_reason("SNIPE"), prefix + "American roster cannot produce British sniper")
	battle._countries.ally="British"
	check(barracks.enqueue("SNIPE"),prefix+"British roster can produce sniper")
	barracks.cancel_at(0)
	battle._countries.ally="Americans"
	# Map/GM actors and saves still resolve their models/data, independent of production.
	var coast = battle.spawn_unit("CDEST", "ally", Vector2(1800, 1800))
	check(is_instance_valid(coast) and not coast._ra2.is_empty(), prefix + "existing scenario actors retain data and model")
	screen.free()
	await get_tree().process_frame

func audit_all_tabs(mode: String, hud) -> void:
	# Independent expected user-facing roster, not copied from the sorting function at runtime.
	var expected := {
		"building": ["GAPOWR", "GAPILE", "GAREFN", "GAWEAP", "GAAIRC", "GAYARD", "GADEPT", "GATECH", "GAROBO", "GAOREP"],
		"defense": ["GAWALL", "GAPILL", "NASAM", "ATESLA", "GTGCAN", "GAGAP", "GASPYSAT", "GACSPH", "GAWEAT"],
		"infantry": ["E1", "GGI", "DOG", "ENGINEER", "JUMPJET", "GHOST", "SPY", "CLEG", "TANY", "SNIPE", "CCOMAND"],
		"vehicle": ["CMIN", "MTNK", "FV", "ROBO", "TNKD", "SREF", "MGTK", "BFRT", "AMCV"],
		"air": ["SHAD", "ORCA", "BEAG"],
		"naval": ["LCRF", "DEST", "DLPH", "AEGIS", "CARRIER"],
	}
	if mode == MatchRules.EXTENDED:
		expected.vehicle.append_array(["R3FUTURE", "R3MIRAGE"])
		expected.air.append("R3HARBINGER")
	var report := {}
	var original_country: String = battle._countries.get("ally", "Americans")
	for country in ["美国", "韩国", "法国", "德国", "英国"]:
		battle._countries["ally"] = GameData.ra2_country_id(country)
		var seen := {}
		for tab in expected:
			hud.select_prod_tab(tab)
			hud._refresh_production()
			hud._update_production_live()
			var actual: Array = hud._prod_buttons.keys()
			check(actual == expected[tab], "%s/%s/%s real card order" % [mode, country, tab], actual)
			var shuffled: Array = expected[tab].duplicate()
			shuffled.reverse()
			check(GameData.catalog_sorted(shuffled, tab if tab in ["building", "defense"] else "unit") == expected[tab], "%s/%s/%s independent of input order" % [mode, country, tab])
			var entries: Array = []
			for id in actual:
				check(not seen.has(id), "%s/%s unique tab entry %s" % [mode, country, id])
				seen[id] = tab
				var data: Dictionary = GameData.get_entity(id)
				var category: String = GameData.building_production_category(id) if GameData.is_building(id) else GameData.unit_production_category(data)
				check(category == tab, "%s/%s category and producer agree %s" % [mode, country, id])
				entries.append({"id": id, "name": data.get("name"), "producer": data.get("built_at", "GACNST"), "disabled": hud._prod_buttons[id].disabled})
			if country == "美国": report[tab] = entries
			check(not actual.has("GASAND") and not actual.has("CDEST") and not actual.has("HORNET"), "%s/%s/%s excludes removed and spawned actors" % [mode, country, tab])
		check(seen.size() == (50 if mode == MatchRules.EXTENDED else 47), "%s/%s complete mode-specific roster without duplicates" % [mode, country])
	check(GameData.catalog_sort_id("DOG") == "ADOG", mode + " legacy allied dog gets native allied sort slot")
	var dog: Dictionary = GameData.unit_index.DOG
	var original_faction: String = dog.faction
	dog.faction = "soviet"
	check(GameData.catalog_sort_id("DOG") == "DOG", mode + " Soviet dog identity is never globally aliased")
	dog.faction = original_faction
	battle._countries["ally"] = original_country
	FileAccess.open(output_dir.path_join(mode + "-catalog-audit.json"), FileAccess.WRITE).store_string(JSON.stringify(report, "  "))
	hud.select_prod_tab("infantry")
	hud._refresh_production()
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		stage.get_texture().get_image().save_png(output_dir.path_join(mode + "-infantry-order.png"))
