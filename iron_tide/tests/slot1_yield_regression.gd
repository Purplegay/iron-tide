extends "res://tests/ground_control_regression.gd"

func exercise(mode:String) -> void:
	BattleRequest.configure_skirmish(mode,{"map_layout":"yr_isleland","opening":"mcv","fog_of_war":false})
	screen=load("res://scenes/battle.tscn").instantiate();add_child(screen)
	screen.process_mode=Node.PROCESS_MODE_DISABLED;battle=screen.battle
	Engine.physics_ticks_per_second=15
	var mover=battle.spawn_unit("APOC","enemy",Vector2(7093.34326,4932.40967))
	activate(mover)
	var actors=[mover]
	for spec in [["SOV_DOG",7079.14551,4911.75098],["E2",7095.66504,4903.7627],["E2",7054.05957,4909.70166],["IVAN",7131.2666,4889.51758]]:
		var actor=battle.spawn_unit(spec[0],"enemy",Vector2(spec[1],spec[2]));activate(actor);actors.append(actor)
	var guard=actors[1];guard.hold_position=true;guard.special.ai_campaign_role="guard"
	var origin:Vector2=mover.position;var guard_origin:Vector2=guard.position
	mover.order_move(Vector2(7232.5,4537.5))
	mover._path_pts=PackedVector2Array([origin,Vector2(7067.5,4812.5),Vector2(7232.5,4537.5)]);mover._path_i=1
	mover.hull_angle=origin.angle_to_point(mover._path_pts[1]);mover.turret_angle=mover.hull_angle
	await get_tree().physics_frame
	var forward:Vector2=origin.direction_to(mover._path_pts[1]);var right=Vector2(-forward.y,forward.x)
	var probes=[]
	for direction in [right,-right,forward]:
		var offset:Vector2=direction*(mover.radius+guard.radius+24.0)
		probes.append({"direction":direction,"body_blocked":guard.test_move(guard.global_transform,offset),"dry":guard._domain_ok(guard.position+offset)})
	check(probes[0].body_blocked and probes[1].body_blocked and not probes[2].body_blocked and probes[2].dry,mode+" saved positions reproduce two blocked sidesteps and an open forward sweep")
	check(mover._local_traffic.request_yield(mover,guard,forward),mode+" idle AI guard accepts clear forward escape when both sides are blocked")
	var elapsed:=0
	for tick in 450:
		await get_tree().physics_frame
		for actor in actors:actor._physics_process(1.0/15.0)
		elapsed=tick+1
		if mover.position.y<4812.5:break
	check(mover.position.y<4812.5,mode+" saved bridge-mouth crowd clears toward ordered destination within 30 game seconds",[mover.position,elapsed/15.0])
	check(guard.hold_position and guard.special.ai_campaign_role=="guard",mode+" AI guard assignment retained")
	check(guard.position.distance_to(guard_origin)<=64.1,mode+" guard yield remains local")
	for actor in actors:check(actor._domain_ok(actor.position),mode+" collision-checked dry-ground movement")
	guard._local_traffic.reset();guard.side="ally";guard.hold_position=true
	check(not mover._local_traffic.request_yield(mover,guard,forward),mode+" player hold remains protected")
	guard.side="enemy";guard.attack_target=mover
	check(not mover._local_traffic.request_yield(mover,guard,forward),mode+" active combat remains protected")
	metrics.append({"mode":mode,"mover":mover.position,"guard":guard.position,"elapsed_s":elapsed/15.0,"probes":probes})
	await finish()
