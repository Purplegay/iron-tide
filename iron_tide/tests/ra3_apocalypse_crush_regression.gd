extends "res://tests/allied_abilities_regression.gd"
const Crush=preload("res://scripts/units/ra3_apocalypse_crush.gd")

func exercise_mode(mode:String) -> void:
	if mode==MatchRules.RA2:return
	setup_logistics_scene(mode,"苏俄")
	screen.hud.set_process(false)
	# This fixture asserts 90 contact ticks and manually advances at 1/60 s.
	Engine.physics_ticks_per_second=60
	for node in battle.units+battle.buildings:node.free()
	battle.units.clear();battle.buildings.clear()
	battle.invalidate_building_membership()
	for obstacle in battle.get_tree().get_nodes_in_group("obstacles"):
		if battle.is_ancestor_of(obstacle):obstacle.free()
	var path=battle.path_service
	battle.water_rects=[];path.set_water([]);battle._refresh_pathing()
	var start:=Vector2(1300,1500)
	var tank=actor("R3APOC","ally",start)
	tank.hull_angle=0;tank.turret_angle=0;tank.set_fire_stance("none")
	var rifle=actor("E1","enemy",start+Vector2(95,0))
	var grey=actor("MTNK","enemy",start+Vector2(155,0))
	var tesla=actor("R3TESLA","enemy",start+Vector2(255,0))
	var wall=battle._place_building("NAWALL","enemy",start+Vector2(355,0),true)
	wall.process_mode=Node.PROCESS_MODE_ALWAYS;wall.set_process(false)
	var goal:=start+Vector2(465,0)
	var tanks=[]
	for id in ["APOC","BFRT","SMCV","R3APOC","R3FUTURE","R3REAPER","R3MIRAGE"]:
		var u=actor(id,"enemy",start+Vector2(tanks.size()*100,280));tanks.append(u)
		check(Crush.eligible(tank,u)==(id in ["R3REAPER","R3MIRAGE"]),"moving crush eligibility "+id)
	var friend=actor("MTNK","ally",start+Vector2(90,110))
	var nearby=actor("MTNK","enemy",start+Vector2(100,70))
	var air=actor("JUMPJET","enemy",start+Vector2(120,120))
	var base=battle._place_building("NAPOWR","enemy",start+Vector2(450,190),true)
	check(not Crush.eligible(tank,friend) and not Crush.eligible(tank,air) and not Crush.eligible(tank,base),"friends, aircraft and buildings are protected")
	check(path.is_blocked(wall.position) and not path.is_blocked(wall.position,false,false,true),"wall passability is specific to the wall crusher")
	check(path.is_blocked(base.position,false,false,true),"ordinary structures still block Apocalypse routing")
	check(not path.line_walkable(start,goal,path.cost) and path.line_walkable(start,goal,path.crusher_cost),"only crusher path may cross the wall")
	battle.select_unit(tank,false);battle._command_move(goal)
	check(tank.has_move_order and tank.move_target.distance_to(goal)<5,"ordinary move command across the wall")
	var tracked=[weakref(rifle),weakref(grey),weakref(tesla),weakref(wall)]
	var required_xp:float=rifle._vet_value+grey._vet_value+tesla._vet_value+float(wall.data.cost)
	var contact_frames:Dictionary={}
	var timed_kills:=0
	for i in 1100:
		await get_tree().physics_frame
		tank._physics_process(1.0/60)
		var pending:Dictionary=tank.special.get("rolling_crush",{})
		if not pending.is_empty():
			var id:int=pending.target.get_instance_id()
			if not contact_frames.has(id):contact_frames[id]=[i,weakref(pending.target)]
		for id in contact_frames.keys():
			var first:Array=contact_frames[id]
			if not AlliedAbilities.alive(first[1].get_ref()):
				check(i-int(first[0])==90,"rolling crush completes after 90 physics ticks",i-int(first[0]))
				timed_kills+=1;contact_frames.erase(id)
		if tank.position.x>goal.x-16:break
	check(timed_kills==4,"infantry, vehicles and wall all spend time in contact")
	for i in tracked.size():
		check(not AlliedAbilities.alive(tracked[i].get_ref()),"ordinary move crushes contact "+str(i))
	check(tank.position.x>goal.x-30,"movement continues through broken wall")
	check(tank._vet_kills==required_xp,"one kill award per crushed enemy",tank._vet_kills)
	check(nearby.hp==nearby.max_hp and friend.hp==friend.max_hp,"no parallel-lane or friendly victims")
	var start2:Vector2=tank.position
	var heavy=actor("APOC","enemy",start2+Vector2(80,0))
	battle._command_move(start2+Vector2(180,0))
	for i in 100:
		await get_tree().physics_frame
		tank._physics_process(1.0/60)
	check(heavy.hp==heavy.max_hp,"actual collision does not crush a YR Apocalypse")
	tank.order_stop()
	var mixed:=Vector2(1950,2300)
	var owned_wall=battle._place_building("NAWALL","ally",mixed,true)
	check(Crush.eligible(tank,owned_wall),"wall relationship ignored by Soviet crush weapon")
	var fort=battle._place_building("NAPOWR","ally",mixed,true)
	check(path.is_blocked(mixed,false,false,true),"overlapping structure remains solid even on a crushable wall cell")
	path.rebuild_terrain([fort,owned_wall])
	check(path.is_blocked(mixed,false,false,true),"wall stamped last cannot reopen a building cell")
	path.set_water([Rect2(mixed-Vector2(60,60),Vector2(120,120))]);path.rebuild_terrain([owned_wall])
	check(path.is_blocked(mixed,false,false,true),"a wall on water does not open land passage")
	await exercise_interruption_and_save()
	screen.free();await get_tree().process_frame

func exercise_interruption_and_save() -> void:
	var start:=Vector2(1900,1300)
	var driver=actor("R3APOC","ally",start)
	var victim=actor("MTNK","enemy",start+Vector2(70,0))
	driver.order_move(start+Vector2(180,0))
	for i in 140:
		await get_tree().physics_frame
		driver._physics_process(1.0/60)
		if float(driver.special.get("rolling_crush",{}).get("elapsed",0))>0.5:break
	check(driver.special.has("rolling_crush") and victim.hp==victim.max_hp,"first half second does not deal crush damage")
	driver.order_stop()
	check(not driver.special.has("rolling_crush") and AlliedAbilities.alive(victim),"stop cancels pending contact")
	driver.order_move(start+Vector2(180,0))
	for i in 100:
		await get_tree().physics_frame
		driver._physics_process(1.0/60)
		if float(driver.special.get("rolling_crush",{}).get("elapsed",0))>=0.5:break
	if not driver.special.has("rolling_crush"):
		check(false,"can re-establish rolling contact")
		return
	var elapsed:float=driver.special.rolling_crush.elapsed
	var codec=preload("res://scripts/save/battle_snapshot.gd").new()
	var snapshot=codec.capture(battle)
	codec.restore(battle,snapshot)
	screen.hud.process_mode=Node.PROCESS_MODE_DISABLED
	screen.hud.set_process(false)
	driver=battle.units.filter(func(u):return u.unit_id=="R3APOC" and u.special.has("rolling_crush"))[0]
	activate(driver,false)
	victim=driver.special.rolling_crush.target
	activate(victim,false)
	check(AlliedAbilities.alive(victim) and victim.unit_id=="MTNK" and is_equal_approx(driver.special.rolling_crush.elapsed,elapsed),"load preserves victim and elapsed crush time")
	var frames:=0
	while frames<110 and AlliedAbilities.alive(victim):
		await get_tree().physics_frame
		driver._physics_process(1.0/60)
		frames+=1
	check(not AlliedAbilities.alive(victim) and absi(frames-roundi((1.5-elapsed)*60))<=1,"resumed crush waits only the remaining time",frames)
