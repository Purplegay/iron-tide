extends "res://tests/bridge_sections_regression.gd"

func _ready() -> void:
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_environment("APPDATA").begins_with(OS.get_environment("TEMP")+"/"):
		get_tree().quit(2)
		return
	for mode in [MatchRules.RA2, MatchRules.EXTENDED]: await exercise(mode)
	print("BRIDGE_INDICATOR checks=", checks, " failed=", failed)
	get_tree().quit(int(failed>0))

func exercise(mode: String) -> void:
	for layout in ["yr_unrepent", "river_delta", "yr_crctbrd"]:
		BattleRequest.configure_skirmish(mode,{"map_layout":layout,"opening":"mcv","fog_of_war":false})
		screen = load("res://scenes/battle.tscn").instantiate()
		add_child(screen)
		screen.process_mode = Node.PROCESS_MODE_DISABLED
		battle = screen.battle
		var found := false
		for crossing: Rect2 in Bridges.spans(battle):
			for part: Rect2 in Bridges.sections(battle,crossing):
				var point := part.get_center()
				if not battle.path_service.near_deck(point): continue
				var low: bool = layout == "yr_crctbrd"
				if low:
					if not Native.data(layout).low_bridge_cells.has(Vector2i((point/55).floor())): continue
				elif not battle.path_service.in_naval_water(point): continue
				var ship = actor("DEST","ally",point,"ship")
				var tank = actor("MTNK","ally",point,"tank")
				battle._update_depth_order()
				check(ship.occluded_by_bridge == (not low) and not tank.occluded_by_bridge,mode+layout+" 桥下舰船与桥面车辆")
				ship.position = crossing.end + Vector2.ONE*200
				battle._update_depth_order()
				check(not ship.occluded_by_bridge,mode+layout+" 离桥清除提示")
				ship.position = point
				Bridges.damage_section(battle,part,Bridges.strength())
				battle._update_depth_order()
				check(not ship.occluded_by_bridge,mode+layout+" 断桥缺口清除提示")
				found = true
				break
			if found: break
		check(found,mode+layout+" 找到可测桥段")
		await finish()
