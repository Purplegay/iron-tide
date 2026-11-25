extends "res://tests/ground_control_regression.gd"

func exercise(mode: String) -> void:
	start(mode)
	for b in battle.buildings: b.free()
	battle.buildings.clear()
	battle._refresh_pathing()
	BattleRequest.house_teams = {"ally":1,"ai2":1,"ai3":1,"enemy":2}
	for dense in [false,true]:
		if dense:
			for i in 100:
				var far=battle.spawn_unit("E1","ally",Vector2(200+(i%10)*45,1500+(i/10)*45))
				activate(far)
		for row in [["E1","E1","ally",true],["MTNK","E1","ally",true],["E1","MTNK","ally",true],
			["MTNK","MTNK","ally",false],["BFRT","BFRT","ai2",true],["MTNK","MTNK","enemy",false],
			["BFRT","BFRT","ally",true,"ai2"],["BFRT","BFRT","ai2",false,"ai2"],
			["BFRT","BFRT","ai3",false,"ai2"],["E1","E1","ai2",true,"ai2"],
			["DEST","DEST","ai2",false,"ai2"],["ZEP","ZEP","ai2",false,"ai2"],
			["E1","E1","enemy",false],["DEST","DEST","ai2",true],["DEST","DEST","enemy",false],
			["ZEP","ZEP","ai2",true],["ZEP","ZEP","enemy",false]]:
			await crossing(row,dense,mode)
	# Team membership is evaluated per move, including captured/charmed actors.
	var a=battle.spawn_unit("MTNK","ally",Vector2(400,600))
	var b=battle.spawn_unit("MTNK","enemy",Vector2(500,600))
	activate(a); activate(b)
	var teams: Dictionary=BattleRequest.house_teams.duplicate(true)
	BattleRequest.house_teams={"ally":0,"enemy":0}
	check(a._local_traffic.friendly_unit_pair(a,b),mode+": allied houses share vehicle collision policy")
	await get_tree().physics_frame
	check(a.move_with_traffic_exceptions(Vector2(150,0),true)==null and a.position==Vector2(400,600),mode+": friendly sweep probe does not move the actor")
	BattleRequest.house_teams={"ally":0,"enemy":1}
	check(not a._local_traffic.friendly_unit_pair(a,b),mode+": hostile ownership immediately restores collision policy")
	check(a.move_with_traffic_exceptions(Vector2(150,0),true)!=null and a.get_collision_exceptions().is_empty(),mode+": hostile sweep probe restores blocking immediately")
	BattleRequest.house_teams=teams
	# No blanket layer/mask disabling: buildings and terrain remain solid.
	battle.units.erase(b); b.free()
	var wall=battle._place_building("GAPOWR","ally",Vector2(550,600),true)
	wall.process_mode=Node.PROCESS_MODE_ALWAYS
	wall.set_process(false)
	await get_tree().physics_frame
	for i in 90:
		a.velocity=Vector2(180,0)
		a._slide_across_bridge_layers(1.0/60.0)
		await get_tree().physics_frame
	check(a.position.x<550 and a.collision_mask==7,mode+": friendly building remains solid to vehicles",a.position)
	await preload("res://tests/base_escape_cases.gd").run(self,mode)
	await finish()

func crossing(row: Array, dense: bool, mode: String) -> void:
	var label:=mode+"/dense="+str(dense)+"/"+str(row)+": "
	var mover=battle.spawn_unit(row[0],row[4] if row.size()>4 else "ally",Vector2(400,600))
	var blocker=battle.spawn_unit(row[1],row[2],Vector2(500,600))
	activate(mover); activate(blocker)
	blocker.order_guard()
	mover.has_move_order=true; mover.move_target=Vector2(800,600)
	await get_tree().physics_frame
	var before: Vector2=blocker.position
	if row[3]:
		mover.position=Vector2(480,600)
		mover.velocity=Vector2(180,0)
		await get_tree().physics_frame
		mover._local_traffic.apply(mover,1.0/60.0)
		check(mover.velocity.is_equal_approx(Vector2(180,0)),label+"no friendly separation or slowdown",mover.velocity)
		check(mover._local_traffic.stalled_blockers(mover,mover.move_target).is_empty(),label+"no detour blocker from friendly units")
		check(not mover._local_traffic.request_yield(mover,blocker,Vector2.RIGHT),label+"no request to push friendly guards aside")
		mover.position=Vector2(400,600)
	for i in 90:
		mover.velocity=Vector2(180,0)
		if i%2==0: mover._slide_across_bridge_layers(1.0/60.0)
		else: mover.move_with_traffic_exceptions(mover.velocity/60.0)
		await get_tree().physics_frame
	check((mover.position.x>570) if row[3] else (mover.position.x<500),label+"actual swept movement matches collision policy",mover.position)
	check(blocker.position==before and blocker.hp==blocker.max_hp,label+"stationary unit is neither pushed nor damaged")
	check(mover.get_collision_exceptions().is_empty(),label+"temporary exceptions do not leak")
	# Exceptions owned by another command survive the movement wrapper.
	mover.add_collision_exception_with(blocker)
	mover.velocity=Vector2(180,0)
	mover._slide_across_bridge_layers(1.0/60.0)
	check(mover.get_collision_exceptions().has(blocker),label+"existing command exception preserved")
	mover.remove_collision_exception_with(blocker)
	battle.units.erase(mover); battle.units.erase(blocker)
	mover.free(); blocker.free()
