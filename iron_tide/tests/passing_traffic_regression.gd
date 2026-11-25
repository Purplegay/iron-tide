extends "res://tests/ground_control_regression.gd"
const Reference=preload("res://tests/passing_traffic_reference.gd")
const Steering=preload("res://scripts/units/vehicle_steering.gd")
var micro:Array=[]
func exercise(mode:String) -> void:
	start(mode)
	for b in battle.buildings:b.free()
	battle.buildings.clear();battle._refresh_pathing()
	BattleRequest.house_teams={"ally":1,"ai2":1,"enemy":2}
	for dense in [false,true]:
		if dense:
			for i in 105:
				var far=battle.spawn_unit("MTNK","ally",Vector2(1800+(i%10)*30,1600+(i/10)*30))
				activate(far)
		var mover=battle.spawn_unit("MTNK","ally",Vector2(500,700));activate(mover)
		mover.has_move_order=true;mover.move_target=Vector2(1400,700)
		var peers:Array=[]
		for row in [["MTNK","ally",Vector2(525,700)],["MTNK","enemy",Vector2(510,700)],["E1","ally",Vector2(500,710)],["MTNK","ai2",Vector2(540,705)],["DEST","ally",Vector2(505,705)],["ZEP","ally",Vector2(500,700)]]:
			var peer=battle.spawn_unit(row[0],row[1],row[2]);activate(peer);peers.append(peer)
		var probe=Reference.new();mover._local_traffic=probe
		await get_tree().physics_frame
		for pass_state in [false,true]:
			if pass_state:mover.special[probe.CONGESTION]={"passing":true,"origin":mover.position,"clear_seconds":0.0}
			else:mover.special.erase(probe.CONGESTION)
			for owner in ["ally","enemy","ai2"]:
				mover.side=owner
				for speed in [0.0,30.0,150.0]:
					for angle in [0.0,1.0,3.0,5.0]:
						var velocity:Vector2=Vector2.from_angle(angle)*speed
						probe.reset();mover.velocity=velocity
						probe.original_apply(mover,1.0/15)
						var expected:Vector2=mover.velocity
						var contacts:Array=probe.nearby.duplicate()
						var origin:Vector2=probe.query_origin
						var left:float=probe.query_left
						var turn:bool=Steering.open_corridor(mover,angle)
						var blockers:Array=probe.stalled_blockers(mover,mover.move_target)
						probe.reset();mover.velocity=velocity
						probe.apply(mover,1.0/15)
						var label:String=mode+str(dense)+str(pass_state)+owner+str(speed)+str(angle)
						check(mover.velocity.is_equal_approx(expected),label+" same separation")
						check(probe.nearby==contacts and probe.query_origin==origin and probe.query_left==left,label+" same query and refresh cadence")
						check(Steering.open_corridor(mover,angle)==turn and probe.stalled_blockers(mover,mover.move_target)==blockers,label+" same turn corridor and blockers")
		mover.side="ally"
		mover.special[probe.CONGESTION]={"passing":true,"origin":mover.position,"clear_seconds":0.0}
		for i in 6:
			var t:=Time.get_ticks_usec()
			for j in 1200:
				mover.velocity=Vector2(150,0)
				if i%2==0:probe.original_apply(mover,1.0/15)
				else:probe.apply(mover,1.0/15)
			micro.append({"mode":mode,"dense":dense,"variant":"before" if i%2==0 else "after","us":Time.get_ticks_usec()-t})
		mover.special.erase(probe.CONGESTION)
		mover.velocity=Vector2(150,0);probe.apply(mover,1.0/15)
		var expected:Vector2=mover.velocity
		mover.velocity=Vector2(150,0);probe.original_apply(mover,1.0/15)
		check(mover.velocity.is_equal_approx(expected),mode+" same steering immediately after passing ends")
		battle.units.erase(mover);mover.free()
		for peer in peers:battle.units.erase(peer);peer.free()
	# A stale passing marker must never disable air or naval separation.
	for id in ["DEST","ZEP"]:
		var mover=battle.spawn_unit(id,"ally",Vector2(500,700));activate(mover)
		var peer=battle.spawn_unit(id,"ally",Vector2(510,700));activate(peer)
		mover.has_move_order=true;mover.move_target=Vector2(1400,700)
		mover.special[Reference.CONGESTION]={"passing":true,"origin":mover.position}
		var probe=Reference.new();mover._local_traffic=probe
		await get_tree().physics_frame
		mover.velocity=Vector2(150,0);probe.original_apply(mover,1.0/15)
		var expected:Vector2=mover.velocity
		var contacts:Array=probe.nearby.duplicate()
		probe.reset();mover.velocity=Vector2(150,0);probe.apply(mover,1.0/15)
		check(mover.velocity.is_equal_approx(expected) and probe.nearby==contacts,mode+id+" stale passing marker preserves separation")
		for actor in [mover,peer]:battle.units.erase(actor);actor.free()
	await finish()
	FileAccess.open(output_dir.path_join("micro.json"),FileAccess.WRITE).store_string(JSON.stringify(micro))
