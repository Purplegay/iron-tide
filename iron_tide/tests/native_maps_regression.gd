extends "res://tests/base_recovery_regression.gd"
const Native=preload("res://scripts/world/native_maps.gd")
const Maps=preload("res://scripts/world/skirmish_maps.gd")
const Prefs=preload("res://scripts/ui/lobby_preferences.gd")

func exit_near(anchor:Vector2) -> Vector2:
	for ring in range(10,24):
		for step in ring*8:
			var point:=anchor+Vector2.RIGHT.rotated(TAU*step/(ring*8))*ring*40
			if not battle.path_service.is_blocked(point):return point
	return Vector2.INF

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2);return
	MetaProgress.reset_save()
	for id:String in Native.IDS:
		var row:Dictionary=Native.data(id)
		check(row.cells.size()==int(row.local_size[2])*int(row.local_size[3])*2 and row.sha256.length()==64,id+" actual decoded map provenance")
		var roads:Array=row.cells.filter(func(c):return int(c[2])==12)
		check(roads.all(func(c):return (Native.flags(id,Vector2(c[0]+.5,c[1]+.5)*Native.CELL)&1)!=0),id+" FinalAlert dirt-road type 0x0c stays traversable")
		check(Prefs.write({"map_layout":id})==OK and Prefs.read().map_layout==id,id+" map preference survives reload")
		var lobby=load("res://scenes/lobby.tscn").instantiate();add_child(lobby)
		check(lobby._map_preview.map_id==id and lobby._map_preview.preview!=null and lobby._map_opt.disabled,id+" original preview and fixed map size")
		lobby.free()
		BattleRequest.configure_skirmish(MatchRules.RA2,{"map_layout":id,"map_size":2400,"enemy_base":"soviet","country":"美国","starting_funds":12000,"fog_of_war":false})
		screen=load("res://scenes/battle.tscn").instantiate();add_child(screen)
		screen.process_mode=Node.PROCESS_MODE_DISABLED;battle=screen.battle
		check(battle.map_layout()==id and battle.map_size==Native.size_for(id),id+" real battle uses native map and extent")
		check(battle.ground.native_id==id and battle.ground._surface.texture!=null,id+" actual native ground texture")
		check(battle.player_start()==Native.start(id),id+" original player spawn")
		check(battle.buildings.filter(func(b):return b.is_hq and b.side in ["ally","enemy"]).size()==2,id+" both HQs exist")
		check(battle.buildings.filter(func(b):return b.is_refinery()).size()==2,id+" both starting refineries exist")
		check(battle.buildings.filter(func(b):return b.side!="neutral").all(func(b):return (Native.flags(id,b.position)&1)!=0),id+" starting bases stay on native land")
		var ores:Array=get_tree().get_nodes_in_group("resource_nodes")
		check(ores.size()==row.resources.size(),id+" original resource fields consumed")
		check(ores.all(func(n):return (Native.flags(id,n.position)&1)!=0),id+" resources stay on land")
		check(battle.path_service.native_map_id==id and battle.path_service.is_blocked(Vector2(5,5)),id+" outside original playable diamond is impassable")
		var ally_exit:=exit_near(Native.start(id));var enemy_exit:=exit_near(Native.start(id,true))
		check(ally_exit.is_finite() and enemy_exit.is_finite(),id+" starting bases have walkable exits")
		check(battle.path_service.same_zone(ally_exit,enemy_exit),id+" original roads and bridges connect both starting regions",[ally_exit,enemy_exit])
		check(battle.units.all(func(u):return battle.path_service.same_zone(u.position,ally_exit)),id+" starting miners can leave their base into the main land region")
		var low_blocked := true
		for bridge:Array in row.bridges:
			if not str(bridge[2]).begins_with("LOBRDG"): continue
			var center := Vector2(bridge[0]+0.5,bridge[1]+0.5) * Native.CELL
			low_blocked = low_blocked and Native.flags(id,center) == 1 and battle.path_service.is_blocked(center,true)
		if not row.bridges.is_empty(): check(low_blocked,id+" every imported low bridge blocks ships")
		var kinds:Dictionary={}
		for tile:Array in row.cells:
			var point:Vector2=Vector2(tile[0]+.5,tile[1]+.5)*Native.CELL
			var flag:int=Native.flags(id,point)
			if kinds.has(flag) or flag==3:continue
			if battle.buildings.any(func(b):return b.position.distance_to(point)<300):continue
			kinds[flag]=true
			if flag==2:
				check(battle.path_service.is_blocked(point) and not battle.path_service.is_blocked(point,true),id+" water separates ground and naval movement")
			if flag==4:check(battle.path_service.is_blocked(point),id+" original cliff is impassable")
		var capture=BattleSaves.Snapshot.new().capture(battle)
		check(BattleSaves.validate(capture).is_empty(),id+" native neutral buildings accepted by save validation",BattleSaves.validate(capture))
		var tampered:Dictionary=capture.duplicate(true);tampered.context.native_map_sha="changed"
		check(not BattleSaves.validate(tampered).is_empty(),id+" changed native terrain rejected instead of silently mismatching save")
		var saved:Dictionary=BattleSaves.save_slot(battle,"slot1")
		check(saved.ok,id+" real save file written",saved)
		var neutral_count:int=battle.buildings.filter(func(b):return b.side=="neutral").size()
		await finish()
		check(BattleSaves.prepare_load("slot1").ok,id+" real save file read")
		screen=load("res://scenes/battle.tscn").instantiate();add_child(screen);screen.process_mode=Node.PROCESS_MODE_DISABLED;battle=screen.battle
		check(battle.map_layout()==id and battle.path_service.native_map_id==id and battle.ground.native_id==id,id+" cold scene restore keeps native map pathing and ground")
		check(battle.buildings.filter(func(b):return b.side=="neutral").size()==neutral_count and get_tree().get_nodes_in_group("resource_nodes").size()==ores.size(),id+" restored native sites and resources have no duplicates")
		get_tree().paused=false
		await finish()
		BattleRequest.configure_skirmish(MatchRules.RA2,{"map_layout":id,"opening":"mcv","enemy_base":"soviet"})
		screen=load("res://scenes/battle.tscn").instantiate();add_child(screen);screen.process_mode=Node.PROCESS_MODE_DISABLED;battle=screen.battle
		check(battle.units.size()==2 and battle.units.all(func(u):return u.unit_id in ["AMCV","SMCV"] and (Native.flags(id,u.position)&1)!=0),id+" both MCV opening locations are on land")
		check(battle.buildings.filter(func(b):return b.side!="neutral").is_empty(),id+" MCV opening retains native sites without prebuilt bases")
		await finish()
		BattleRequest.configure_skirmish(MatchRules.EXTENDED,{"map_layout":id,"opening":"prebuilt","country":"苏俄","enemy_country":"美国","enemy_base":"allied"})
		screen=load("res://scenes/battle.tscn").instantiate();add_child(screen);screen.process_mode=Node.PROCESS_MODE_DISABLED;battle=screen.battle
		check(battle.ground.native_id==id and battle.path_service.native_map_id==id,id+" extension mode uses original terrain and navigation")
		check(battle.buildings.filter(func(b):return b.is_hq).size()==2 and battle.buildings.filter(func(b):return b.is_refinery()).size()==2,id+" reversed factions get both bases and economy")
		check(get_tree().get_nodes_in_group("resource_nodes").size()==row.resources.size(),id+" extension mode retains original resource layout")
		await finish()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed}))
	get_tree().quit(0 if failed==0 else 1)
