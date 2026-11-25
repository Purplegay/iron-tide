extends "res://tests/logistics_regression.gd"

func exercise_mode(mode:String) -> void:
	setup_logistics_scene(mode,"韩国")
	battle.paused=false;get_tree().paused=false
	battle.power_low=false
	var base=airport("ally",Vector2(2100,2200))
	for id in ["ORCA","BEAG"]:
		var plane=battle.spawn_unit(id,"ally",base.position)
		activate(plane);plane.logistics.assign_producer(base)
		plane.hp=plane.max_hp-40
		var hp:float=plane.hp;var funds:float=battle.funds
		for i in 60:plane._physics_process(.016)
		check(is_equal_approx(plane.hp,hp+8),mode+id+" full-ammo parked aircraft repairs through real physics")
		check(battle.funds==funds,mode+id+" airport repair is free")
		plane.logistics.ammo=0
		plane.logistics.tick_return(.96)
		check(is_equal_approx(plane.hp,hp+16) and plane.logistics.air_state=="rearming" and plane.logistics.reload_elapsed>0,mode+id+" repair and rearming run together")
		hp=plane.hp;battle.power_low=true;plane.logistics.tick_return(5)
		check(plane.hp==hp,mode+id+" low power pauses repair")
		battle.power_low=false;battle.funds=0;plane.logistics.tick_return(.96)
		check(is_equal_approx(plane.hp,hp+8) and battle.funds==0,mode+id+" no funds still repairs")
		plane.logistics.tick_return(10)
		check(plane.hp==plane.max_hp,mode+id+" repair clamps at maximum health")
		plane.logistics.ammo=plane.logistics.ammo_max
		plane.hp-=20;plane.order_move(base.position+Vector2(400,0));hp=plane.hp
		for i in 20:plane.logistics.tick(.016)
		check(plane.hp==hp and plane.logistics.air_state=="flying",mode+id+" takeoff cancels repair")
		plane.logistics.request_return(base);plane.position=base.position+Vector2(400,0);plane.logistics.tick_return(.1)
		check(plane.hp==hp,mode+id+" approach cannot remotely repair")
		plane.position=plane.logistics.dock_destination();plane.logistics.air_lift=0;plane.logistics.tick_return(.48)
		var codec=BattleSaves.Snapshot.new();var file=FileAccess.open(output_dir.path_join(mode+id+".bin"),FileAccess.WRITE)
		file.store_var(codec.capture(battle),false);file.close()
		file=FileAccess.open(output_dir.path_join(mode+id+".bin"),FileAccess.READ);var snap=file.get_var(false);file.close();codec.restore(battle,snap)
		battle.paused=false;get_tree().paused=false
		plane=battle.units.filter(func(u):return u.unit_id==id and u.logistics.home!=null and u.hp<u.max_hp)[0]
		base=plane.logistics.home;battle.power_low=false;activate(plane,false)
		check(codec.error.is_empty() and plane.hp==hp,mode+id+" binary restore retains health")
		plane.logistics.tick_return(.48)
		check(is_equal_approx(plane.hp,hp+8),mode+id+" binary restore retains partial repair interval")
		hp=plane.hp;base.side="enemy";plane.logistics.tick_return(.96)
		check(plane.hp==hp,mode+id+" captured airport stops repair")
		base.side="ally";remove_actor(plane)
	var plane=battle.spawn_unit("ORCA","ally",base.position)
	activate(plane);plane.logistics.assign_producer(base);plane.hp-=30
	var hp:float=plane.hp
	for reason in ["paused","ended","construction","full_ammo_power"]:
		battle.paused=reason=="paused";battle.ended=reason=="ended"
		base.under_construction=reason=="construction";battle.power_low=reason=="full_ammo_power"
		plane.logistics.tick_return(2)
		check(plane.hp==hp,mode+" blocked airport repair: "+reason)
	battle.paused=false;battle.ended=false;base.under_construction=false;battle.power_low=false
	plane.logistics.tick_return(.96)
	check(is_equal_approx(plane.hp,hp+8),mode+" blocked time is not banked for instant healing")
	hp=plane.hp;base.hp=0;plane.logistics.tick_return(.96)
	check(plane.hp==hp,mode+" destroyed airport cannot repair")
	screen.free();await get_tree().process_frame
