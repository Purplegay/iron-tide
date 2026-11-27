extends "res://tests/ground_control_regression.gd"
const Traffic=preload("res://scripts/units/local_traffic.gd")

func wait_blocked(unit, seconds: float) -> void:
	for i in roundi(seconds*60): unit._local_traffic.tick_congestion(unit,1.0/60.0)

func exercise(mode: String) -> void:
	start(mode)
	for b in battle.buildings: b.free()
	battle.buildings.clear(); battle._refresh_pathing()
	for owner in ["ally","enemy"]:
		var a=battle.spawn_unit("MTNK",owner,Vector2(480,600))
		var b=battle.spawn_unit("MTNK",owner,Vector2(514,600))
		activate(a);activate(b);b.order_guard()
		a.order_move(Vector2(900,600));a._local_traffic.nearby=[b]
		await get_tree().physics_frame
		check(a.move_with_traffic_exceptions(Vector2(80,0),true)!=null,prefix+owner+" normal vehicle collision exists")
		a._local_traffic.tick_congestion(a,0.0)
		wait_blocked(a,1.9)
		check(not Traffic.passing(a) and a.move_with_traffic_exceptions(Vector2(80,0),true)!=null,prefix+owner+" still solid before two seconds")
		wait_blocked(a,0.1)
		check(Traffic.passing(a) and a.move_with_traffic_exceptions(Vector2(80,0),true)==null,prefix+owner+" two seconds of blockage opens actual swept movement")
		check(a.move_target==Vector2(900,600) and a.has_move_order and b.hold_position and b.position==Vector2(514,600),prefix+owner+" preserves mover goal and blocking guard")
		b.side="enemy" if owner=="ally" else "ally"
		check(a.move_with_traffic_exceptions(Vector2(80,0),true)!=null,prefix+owner+" hostile capture restores collision immediately")
		b.side=owner
		a.move_with_traffic_exceptions(Vector2(34,0))
		a.order_stop()
		check(Traffic.passing(a) and a.position.distance_to(b.position)<1.0,prefix+owner+" stop keeps the overlapping pair passable before saving")
		var saved=BattleSaves.save_slot(battle,"slot1")
		check(saved.ok,prefix+owner+" save active escape through real save entry",saved)
		if not saved.ok: return
		check(BattleSaves.prepare_load("slot1").ok,prefix+owner+" reload active escape")
		BattleSaves.restore_pending(battle)
		var movers=battle.units.filter(func(u):return u.special.has(Traffic.CONGESTION))
		check(movers.size()==1,prefix+owner+" restored one active congestion record")
		if movers.size()!=1:return
		a=movers[0]
		b=battle.units.filter(func(u):return u!=a)[0]
		battle.paused=false;get_tree().paused=false
		activate(b);b.order_guard()
		check(Traffic.passing(a) and a.position.distance_to(b.position)<1.0,prefix+owner+" escape survives load without solid overlap")
		wait_blocked(a,1.0)
		var separated:bool=a.position.distance_to(b.position)>=a.radius+b.radius
		check(Traffic.passing(a) or separated,prefix+owner+" stopped hulls remain passable until physically separated")
		b.position+=Vector2(100,0);battle.neighborhood.relocate(b)
		wait_blocked(a,0.4)
		check(not Traffic.passing(a) and not Traffic.friendly_unit_pair(a,b),prefix+owner+" restores collision after clearance")
		a.position=Vector2(480,600);b.position=Vector2(514,600)
		a.order_move(Vector2(900,600));a._local_traffic.nearby=[b]
		a._local_traffic.tick_congestion(a,0)
		wait_blocked(a,1.5);a.position+=Vector2(0,9)
		a._local_traffic.tick_congestion(a,0.1);wait_blocked(a,1.5)
		check(not Traffic.passing(a),prefix+owner+" meaningful movement resets the stall clock")
		a.order_guard();wait_blocked(a,3)
		check(not Traffic.passing(a),prefix+owner+" stationary guard never starts escape")
		for u in battle.units: u.free()
		battle.units.clear()
	# Production physics must invoke the detector without test-side timer calls.
	var mover=battle.spawn_unit("MTNK","enemy",Vector2(480,900))
	var guard=battle.spawn_unit("MTNK","enemy",Vector2(514,900))
	activate(mover);activate(guard);guard.order_guard()
	mover.hull_angle=0.0;mover.order_move(Vector2(900,900))
	var start_point:Vector2=mover.position
	for i in 150:
		await get_tree().physics_frame
		mover._physics_process(1.0/15.0)
	check(mover.position.distance_to(start_point)>100,prefix+" real physics gets past the friendly guard",mover.position)
	check(guard.position==Vector2(514,900) and guard.hp==guard.max_hp,prefix+" real escape does not push or damage guard")
	check(mover.collision_mask==7 and mover.get_collision_exceptions().is_empty(),prefix+" no permanent physics layer or exception leak")
	await finish()
