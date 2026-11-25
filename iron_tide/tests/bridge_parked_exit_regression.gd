extends "res://tests/ground_control_regression.gd"

func exercise(mode:String) -> void:
	BattleRequest.configure_skirmish(mode,{"map_layout":"yr_isleland","opening":"mcv","fog_of_war":false})
	screen=load("res://scenes/battle.tscn").instantiate();add_child(screen)
	screen.process_mode=Node.PROCESS_MODE_DISABLED;battle=screen.battle
	Engine.physics_ticks_per_second=60
	BattleRequest.house_teams={"ally":1,"ai2":1,"enemy":2}
	var mover=battle.spawn_unit("BFRT","ally",Vector2(4732.212,6523.475))
	activate(mover)
	var parked=[]
	for point:Vector2 in [Vector2(4758.248,6563.861),Vector2(4742.646,6476.62),Vector2(4720.405,6606.646)]:
		var unit=battle.spawn_unit("BFRT","ai2",point);activate(unit);unit.hold_position=true;parked.append(unit)
	var target:=Vector2(4928.534,6607.074)
	mover.order_move(target)
	mover.hull_angle=mover.position.angle_to_point(target);mover.turret_angle=mover.hull_angle
	check(battle.path_service.near_deck(mover.position,mover.radius+40),mode+" saved obstruction lies in bridge steering zone")
	var contacts_clear:=true
	var dry:=true
	for tick in 1800:
		await get_tree().physics_frame
		mover._physics_process(1.0/60)
		contacts_clear=contacts_clear and no_friendly_contact(mover)
		dry=dry and mover._domain_ok(mover.position)
		if not mover.has_move_order:break
	check(contacts_clear and mover._local_traffic.stalled_blockers(mover,target).is_empty(),mode+" allied bridge guards never create collision or detour blockers")
	check(not mover.has_move_order and mover.position.distance_to(target)<mover.ARRIVE_EPS+1,mode+" fortress clears parked hulls and arrives",mover.position)
	check(dry,mode+" passage through allied hulls stays on land")
	for other in parked:check(other.hold_position and other._local_traffic.yield_target==Vector2.INF,mode+" explicit parked guard is not displaced")
	for actor in [mover]+parked:battle.units.erase(actor);actor.free()
	Engine.physics_ticks_per_second=15
	mover=battle.spawn_unit("BFRT","ally",Vector2(4622.603,6483.855));activate(mover)
	var peer=battle.spawn_unit("BFRT","ai2",Vector2(4628.667,6531.642));activate(peer)
	var stopped=battle.spawn_unit("BFRT","ally",Vector2(4582.937,6517.046));activate(stopped);stopped.hold_position=true
	mover.order_move(Vector2(4543.794,6665.776));peer.order_move(Vector2(4404.395,6847.444))
	dry=true;contacts_clear=true
	for tick in 900:
		await get_tree().physics_frame
		for actor in [mover,peer]:
			actor._physics_process(1.0/15)
			dry=dry and actor._domain_ok(actor.position)
			contacts_clear=contacts_clear and no_friendly_contact(actor)
		if not mover.has_move_order and not peer.has_move_order:break
	check(not mover.has_move_order and not peer.has_move_order,mode+" two moving fortresses clear a bridge-mouth wedge at 15 Hz",[mover.position,peer.position])
	check(dry and contacts_clear,mode+" player and allied AI retain terrain boundaries without mutual collisions")
	var route=preload("res://scripts/units/bridge_traffic_route.gd")
	mover.position=Vector2(4702.5,6105)
	var obstacles=[{"position":Vector2(4740,6190),"radius":mover.radius*2+8}]
	preload("res://scripts/world/bridge_damage.gd").hit(battle,Vector2(4702.5,6240),100000)
	check(route.find(mover,Vector2(4702.5,6420),obstacles).is_empty(),mode+" local detour never crosses a collapsed bridge section")
	check(route.find(mover,mover.position+Vector2(1000,0),obstacles).is_empty(),mode+" local search retains a bounded range")
	check(route.find(mover,Vector2(4702.5,6420),[]).is_empty(),mode+" no parked blockers means no local graph")
	await finish()

func no_friendly_contact(actor: Unit) -> bool:
	for index in actor.get_slide_collision_count():
		var other = actor.get_slide_collision(index).get_collider()
		if other is Unit and actor._local_traffic.friendly_unit_pair(actor, other): return false
	return actor.get_collision_exceptions().is_empty()
