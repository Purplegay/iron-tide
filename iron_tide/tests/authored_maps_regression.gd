extends "res://tests/base_recovery_regression.gd"
const Maps=preload("res://scripts/world/skirmish_maps.gd")
const Sites=preload("res://scripts/world/civilian_sites.gd")
const Landing=preload("res://scripts/world/skirmish_landing.gd")
const Ops=preload("res://scripts/world/skirmish_operations.gd")
const Prefs=preload("res://scripts/ui/lobby_preferences.gd")

func free_point(point:Vector2,water:=false) -> Vector2:
	for ring in range(8):
		for j in maxi(1,ring*8):
			var p:=point+Vector2.RIGHT.rotated(TAU*j/maxi(1,ring*8))*ring*40
			if not battle.path_service.is_blocked(p,water):return p
	return Vector2.INF

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2);return
	MetaProgress.reset_save()
	for id:String in Maps.MAPS:
		check(Prefs.normalize({"map_layout":id}).map_layout==id,id+" preference accepts stable map id")
		check(Prefs.write({"map_layout":id})==OK and Prefs.read().map_layout==id,id+" preference persists")
		for size in [2400,3200,4000]:
			BattleRequest.configure_skirmish(MatchRules.RA2 if size==2400 else MatchRules.EXTENDED,{"map_layout":id,"map_size":size,"enemy_base":"soviet","country":"美国","starting_funds":12000,"fog_of_war":true})
			screen=load("res://scenes/battle.tscn").instantiate();add_child(screen)
			screen.process_mode=Node.PROCESS_MODE_DISABLED;battle=screen.battle
			prefix=id+"/"+str(size)+" "
			check(battle.map_layout()==id and battle.water_rects==Maps.water(id,size),prefix+" actual battle consumes authored map")
			check(battle.buildings.filter(func(b):return b.is_hq and b.side in ["ally","enemy"]).size()==2 and battle.buildings.filter(func(b):return b.is_refinery()).size()==2,prefix+" both bases and refineries spawn")
			check(battle.buildings.all(func(b):return not battle.in_water_world(b.position)),prefix+" no starting or neutral building centre in water")
			var oils:Array=battle.buildings.filter(func(b):return b.building_id=="CAOILD")
			check(oils.size()>=3 and oils.all(func(b):return b.side=="neutral"),prefix+" contested neutral oil wells")
			check(battle.buildings.filter(func(b):return b.building_id=="CAHSE01").size()>=2,prefix+" garrison villages present")
			var resources:Array=get_tree().get_nodes_in_group("resource_nodes").filter(func(n):return not n.is_queued_for_deletion())
			check(resources.size()>=100 and resources.all(func(n):return not battle.in_water_world(n.position)),prefix+" ore and gems stay on land")
			check(resources.any(func(n):return n.resource_kind=="gems"),prefix+" contested gem fields")
			var ally:=free_point(Vector2(.18,.67)*size)
			var enemy:=free_point(Vector2(.82,.33)*size)
			check(ally.is_finite() and enemy.is_finite(),prefix+" base exits have walkable ground")
			if ally.is_finite() and enemy.is_finite():
				check(battle.path_service.same_zone(ally,enemy)==(id!="island_cross"),prefix+" intended land connection or island separation")
			var bridges:Array=battle.buildings.filter(func(b):return b.special.has("bridge_span"))
			check(bridges.size()==2*Maps.MAPS[id].bridges.size(),prefix+" two huts per bridge")
			for entry:Dictionary in Maps.bridges(id,size):
				for east in [false,true]:
					var point:=Sites.hut_point(entry.span,east)
					check(bridges.any(func(b):return b.position==point and b.special.bridge_span==entry.span and b.special.bridge_repaired==entry.intact),prefix+" matching hut on each bank")

			for hut in bridges:
				var span:Rect2=hut.special.bridge_span
				if hut.special.bridge_repaired:
					check(not battle.path_service.is_blocked(span.get_center()) and not battle.path_service.is_blocked(span.get_center(),true),prefix+" bridge deck and water below both passable")
					Sites.break_bridge(hut)
					check(battle.path_service.is_blocked(span.get_center()) and not battle.path_service.is_blocked(span.get_center(),true),prefix+" demolition blocks deck but preserves water")
					Sites.repair(hut)
			if id!="ore_frontier":
				var sea:Vector2=battle.water_rects[0].get_center()
				check(battle.water_rects.all(func(r):return battle.path_service.same_zone(sea,r.get_center(),true)),prefix+" connected naval basin")
			var ai=battle.skirmish_ai
			if id!="ore_frontier":check(Ops.build_spot(ai,battle.roster_id("GAYARD","enemy")).is_finite(),prefix+" AI can site a shipyard")
			if id=="island_cross":
				var home:=Landing.beach(battle,battle.water_rects[0],ai.rally)
				var away:=Landing.beach(battle,battle.water_rects[0],battle.player_start())
				check(home.has("land") and away.has("land") and battle.path_service.same_zone(home.sea,away.sea,true),prefix+" AI transport embark and disembark shores connected by sea")
			if size==3200:
				var snapshot=BattleSaves.Snapshot.new()
				var old_water:Array=battle.water_rects.duplicate()
				var old_bridges:Array=battle.allied_state.get("repaired_bridges",[]).duplicate()
				snapshot.restore(battle,snapshot.capture(battle))
				check(battle.map_layout()==id and battle.water_rects==old_water and battle.allied_state.get("repaired_bridges",[])==old_bridges,prefix+" snapshot preserves terrain and bridge states")
				get_tree().paused=false
			if id=="island_cross" and size==3200:
				for building in battle.buildings:building._buildup_play=-1
				ai=battle.skirmish_ai
				var yard_id:String=battle.roster_id("GAYARD","enemy")
				var yard_point:Vector2=Ops.build_spot(ai,yard_id)
				if yard_point.is_finite():
					var yard=battle._place_building(yard_id,"enemy",yard_point,true)
					yard._buildup_play=-1
					Ops.train_navy(ai,0,true)
					check(yard.production.has("SAPC"),prefix+" AI queues paid island transport first")
					yard._process(120)
					check(battle.units.any(func(u):return u.unit_id=="SAPC" and u.side=="enemy"),prefix+" island transport leaves real shipyard")
			await finish()
		BattleRequest.configure_skirmish(MatchRules.RA2,{"map_layout":id,"map_size":3200,"opening":"mcv","enemy_base":"soviet"})
		screen=load("res://scenes/battle.tscn").instantiate();add_child(screen);screen.process_mode=Node.PROCESS_MODE_DISABLED;battle=screen.battle
		check(battle.units.filter(func(u):return u.unit_id in ["AMCV","SMCV"] and not battle.in_water_world(u.position)).size()==2,id+" both mobile-base starts stay on land")
		await finish()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed}))
	get_tree().quit(0 if failed==0 else 1)
