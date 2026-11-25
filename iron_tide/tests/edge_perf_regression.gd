extends "res://tests/ground_control_regression.gd"

func exercise(mode:String) -> void:
	start(mode)
	var window_size:=Vector2i(1600,900)
	for pair in [[Vector2i(-1,300),Vector2.LEFT],[Vector2i(1600,899),Vector2.RIGHT],[Vector2i(-2,901),Vector2(-1,1)],[Vector2i(1599,0),Vector2.ZERO]]:
		check(battle.outside_window_direction(pair[0],window_size)==pair[1],mode+" client edge "+str(pair[0]))
	var center:=Vector2(400,300)
	check(battle.edge_pointer_direction(center,Vector2.ZERO,false)==Vector2.ZERO,mode+" interior arms exit without panning")
	check(battle.edge_pointer_direction(center,Vector2.RIGHT,true)==Vector2.RIGHT,mode+" fast exit ignores stale GUI hover")
	check(battle.edge_pointer_direction(center,Vector2.ZERO,false)==Vector2.ZERO,mode+" reentry immediately stops scrolling")
	battle.edge_pointer_direction(center,Vector2.ZERO,true)
	check(battle.edge_pointer_direction(center,Vector2.LEFT,false)==Vector2.ZERO,mode+" exit from UI cannot arm scroll")
	battle.edge_pointer_direction(center,Vector2.ZERO,false)
	battle._on_window_focus_exited()
	check(battle.edge_pointer_direction(center,Vector2.LEFT,false)==Vector2.ZERO,mode+" focus loss clears continuation")
	var fog:=preload("res://scripts/world/fog_of_war.gd").new()
	fog.width=43
	var teams:=BattleRequest.house_teams.duplicate()
	BattleRequest.house_teams={"ally":1,"ai2":1,"enemy":2}
	for side in BattleRequest.house_teams:
		var cells:=PackedByteArray()
		cells.resize(fog.width*fog.width)
		fog.visible_cells[side]=cells.duplicate()
		fog.explored_cells[side]=cells.duplicate()
		fog.sight_until[side]={}
	for step in 4:
		var buildings:={1:[Vector3(490,502,330),Vector3(810,20,240)],2:[Vector3(1200,1190,110)]}
		if step>=2: buildings[2].append(buildings[1].pop_back())
		if step==3:buildings.erase(1)
		var expected:Dictionary
		for cached in [false,true]:
			for side in fog.visible_cells:
				fog.visible_cells[side].fill(0)
				fog.explored_cells[side].fill(0)
			if cached:
				fog._begin_live_masks()
				fog._merge_foundation_masks(buildings.duplicate())
			else:
				for team in buildings:
					for pos:Vector3 in buildings[team]:
						fog._reveal("ally" if team==1 else "enemy",Vector2(pos.x,pos.y),pos.z)
			fog._reveal("ai2",Vector2(701+step*80,765),320)
			if cached:
				fog._apply_live_masks()
				check(fog.visible_cells==expected,mode+" exact scout mask on stationary, capture and removal "+str(step))
			else:expected=fog.visible_cells.duplicate(true)
	BattleRequest.house_teams.assign(teams)
	fog.free()
	await finish()
