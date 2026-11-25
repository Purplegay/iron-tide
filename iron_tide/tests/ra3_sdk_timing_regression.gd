extends "res://tests/allied_abilities_regression.gd"

func exercise_mode(mode: String) -> void:
	if mode == MatchRules.RA2: return
	setup_logistics_scene(mode,"美国")
	for group in ["obstacles","resource_nodes"]:
		for node in get_tree().get_nodes_in_group(group): node.free()
	for node in battle.units+battle.buildings: node.free()
	battle.units.clear(); battle.buildings.clear()
	battle.water_rects=[]; battle.path_service.set_water([]); battle._refresh_pathing()
	if battle.fog!=null: battle.fog.free(); battle.fog=null
	var tank=actor("R3MIRAGE","ally",Vector2(1800,1800))
	var target=actor("MTNK","enemy",Vector2(1960,1800))
	target.max_hp=100000; target.hp=100000
	check(tank.data.cost==1600 and GameData.ra2_build_time(tank.data)==15.0,"SDK cost1600 / BuildTime15 without YR price formula")
	check(BattleClock.production_scale(tank.data)==1.0,"RA3 production bypasses YR production scaling")
	check(tank.base_speed==120.0 and tank.sight==750.0,"SDK speed80 and shroud500 share distance scale1.5 with weapon range")
	check(tank.data.move.accel_time==0.01,"SDK acceleration seconds preserved")
	check(is_equal_approx(Ra3UnitModel.SIZE.y/64.0,Ra3Mirage.WORLD_SCALE),"movement/range adapter matches model projection scale")
	var mover=actor("R3MIRAGE","ally",Vector2(1300,1300))
	mover.hull_angle=0.0; mover._hull_prev=0.0
	mover.order_move(Vector2(1600,1300))
	# CharacterBody2D.move_and_slide uses the engine's physics delta internally.
	# Yield real ticks; calling it 60 times in one process frame over-integrates.
	for frame in Engine.physics_ticks_per_second:
		await get_tree().physics_frame
		mover._physics_process(1.0 / Engine.physics_ticks_per_second)
	var travelled: float=mover.position.distance_to(Vector2(1300,1300))
	check(travelled>112.0 and travelled<=120.1,"real one-second movement consumes corrected speed without RA2 tick scaling",travelled)
	remove_actor(mover)
	for rank in [0,3]:
		tank._grant_veteran(rank,false)
		var radius := 187.5 if rank==0 else 225.0
		var inside=actor("MTNK","enemy",target.position+Vector2(0,radius-0.1))
		# Opposite side isolates the first-hop boundary from the hero's new second hop.
		var outside=actor("MTNK","enemy",target.position+Vector2(0,-radius-0.1))
		var inside_hp: float=inside.hp; var outside_hp: float=outside.hp
		tank._fire_shot(target); resolve_ra3_hits()
		check(inside.hp<inside_hp and outside.hp==outside_hp,"rank%d scatter boundary uses CannonNode range, not promoted primary range"%rank)
		remove_actor(inside); remove_actor(outside)
		for fx in Effects._host().get_children():
			if fx is Ra3WeaponFx: fx.free()
	for rank in range(4):
		tank._grant_veteran(rank,false)
		check(is_equal_approx(tank.cooldown,1.35 if rank==3 else 1.6),"rank%d firing+reload cycle uses RA3 seconds"%rank,tank.cooldown)
		check(not tank.bonuses.has("veteran_rof") and not tank.bonuses.has("veteran_speed") and not tank.bonuses.has("veteran_defense"),"rank%d does not leak Yuri promotion multipliers"%rank)
		check(is_equal_approx(tank.max_hp,625.0 if rank>=2 else 500.0),"rank%d native health modifier"%rank)
		check(is_equal_approx(float(tank.bonuses.get("veteran_attack",1.0)),1.25 if rank>=1 else 1.0),"rank%d native firepower modifier"%rank)
		check(is_equal_approx(tank.attack_range,281.25 if rank==3 else 187.5),"rank%d native weapon/range upgrade"%rank)
		for hz in [30,60,120]:
			tank._cd_timer=0; tank.attack_target=target; tank.hull_angle=0; tank._hull_prev=0
			var fired: Array[float]=[]
			var delta:=1.0/float(hz)
			for frame in int(4.0*hz):
				if tank._try_fire_ready(): fired.append(frame*delta)
				tank._cd_timer-=delta
			check(fired.size()>=3,"rank%d / %dHz real fire trigger repeats"%[rank,hz],fired)
			if fired.size()>=3:
				check(absf((fired[2]-fired[1])-tank.cooldown)<=delta+0.0001,"rank%d / %dHz cycle independent of RA2 ticks"%[rank,hz],fired)
			for shot in battle.projectiles_root.get_children(): shot.free()
			for fx in Effects._host().get_children():
				if fx is Ra3WeaponFx:
					check(is_equal_approx(fx.beam_lifetime(),1.5),"SDK explicit laser lifetime remains1.5 independent of rank ROF")
					fx.free()
	# The real delayed impact path must survive save/restore without double damage.
	tank._grant_veteran(0,false); tank.bonuses={}
	var before: float=target.hp
	tank._fire_shot(target)
	check(target.hp==before,"RA3 shot does not apply instant damage")
	resolve_ra3_hits(0.09)
	check(target.hp==before,"damage pending before SDK0.1s")
	var snapshot:=BattleSaves.Snapshot.new().capture(battle)
	BattleSaves.Snapshot.new().restore(battle,snapshot)
	var restored_target=battle.units.filter(func(u):return u.unit_id=="MTNK")[0]
	resolve_ra3_hits(0.01)
	check(is_equal_approx(before-restored_target.hp,125.0),"saved remaining delay applies exactly one125 adapted damage")
	resolve_ra3_hits(0.1)
	check(is_equal_approx(before-restored_target.hp,125.0),"queued impact cannot deal damage twice")
	var restored_tank=battle.units.filter(func(u):return u.unit_id=="R3MIRAGE")[0]
	restored_tank.credit_kill(4800,"enemy")
	check(restored_tank.veteran_level==1 and restored_tank._vet_kills==0,"SDK4800 cumulative promotes veteran")
	restored_tank.credit_kill(3600,"enemy")
	check(restored_tank.veteran_level==2,"SDK8400 cumulative promotes elite")
	restored_tank.credit_kill(6000,"enemy")
	check(restored_tank.veteran_level==3 and restored_tank.veterancy_status().name=="英雄","SDK14400 cumulative promotes heroic")
	restored_tank.hp=500; restored_tank.attack_target=restored_target
	restored_tank.special.ra3_under_fire=3.0
	Ra3Mirage.tick(restored_tank,0.99)
	check(restored_tank.hp==500.0,"heroic heal respects native1s activation delay")
	Ra3Mirage.tick(restored_tank,0.01)
	check(restored_tank.hp==503.0,"heroic heal restores3 even while attacking and under fire")
	Ra3Mirage.tick(restored_tank,1.0)
	check(restored_tank.hp==509.0,"heroic heal catches up two0.5s intervals")
	Ra3Mirage.tick(restored_tank,0.25)
	var heal_snapshot:=BattleSaves.Snapshot.new().capture(battle)
	BattleSaves.Snapshot.new().restore(battle,heal_snapshot)
	restored_tank=battle.units.filter(func(u):return u.unit_id=="R3MIRAGE")[0]
	Ra3Mirage.tick(restored_tank,0.25)
	check(restored_tank.hp==512.0,"save restores fractional heroic healing timer")
	restored_tank.hp=624.0; Ra3Mirage.tick(restored_tank,0.5)
	check(restored_tank.hp==625.0,"native heal caps at promoted maximum health")
	restored_tank._grant_veteran(2,false); restored_tank.hp=400.0
	Ra3Mirage.tick(restored_tank,2.0)
	check(restored_tank.hp==400.0 and not restored_tank.special.has("ra3_heal_remaining"),"nonheroic ranks do not inherit healing")
	var regular=actor("MTNK","ally",Vector2(1600,1800))
	regular._grant_veteran(3,false)
	check(regular.veteran_level==2 and is_equal_approx(regular.bonuses.get("veteran_rof",1.0),0.6),"YR tank keeps existing rank cap and ROF")
	# Native v0.3.8.1 snapshots also need the spatial migration; preserve earned
	# native elite rather than treating it as the old Yuri top rank.
	restored_tank.data=restored_tank.data.duplicate(true)
	restored_tank.data.veteran.erase("adapter_revision")
	restored_tank.data.speed=176.0; restored_tank.data.move.speed=176.0
	restored_tank.data.sight=1100.0; restored_tank.data.weapon.range=275.0
	restored_tank.data.elite_weapon.range=330.0
	restored_tank.base_speed=176.0; restored_tank._base_speed=220.0
	restored_tank._vet_kills=900.0; restored_tank._cd_timer=0.8
	var native_old:=BattleSaves.Snapshot.new().capture(battle)
	BattleSaves.Snapshot.new().restore(battle,native_old)
	restored_tank=battle.units.filter(func(u):return u.unit_id=="R3MIRAGE")[0]
	check(restored_tank.veteran_level==2 and restored_tank._vet_kills==900.0,"native old save keeps elite rank and partial experience")
	check(restored_tank._base_speed==150.0 and restored_tank.attack_range==187.5 and restored_tank.sight==750.0,"native old save replaces spatial scale and retains progression speed multiplier")
	check(restored_tank.hp==400.0 and is_equal_approx(restored_tank._cd_timer,0.8),"native old save preserves health and firing progress")
	var native_again:=BattleSaves.Snapshot.new().capture(battle)
	BattleSaves.Snapshot.new().restore(battle,native_again)
	restored_tank=battle.units.filter(func(u):return u.unit_id=="R3MIRAGE")[0]
	check(restored_tank._base_speed==150.0 and restored_tank.veteran_level==2 and restored_tank._vet_kills==900.0,"spatial migration is idempotent on next load")
	# Recreate serialized v0.3.6.1 values, not just a newly spawned native unit.
	restored_tank.data=restored_tank.data.duplicate(true)
	restored_tank.data.veteran={"elite":{"ROF":true,"SELF_HEAL":true}}
	restored_tank.data.speed=80.0; restored_tank.data.sight=385.0
	restored_tank.base_speed=80.0; restored_tank._base_speed=100.0
	restored_tank.base_hp=500.0; restored_tank._base_max_hp=600.0
	restored_tank.max_hp=600.0; restored_tank.hp=300.0
	restored_tank.bonuses.veteran_rof=0.6; restored_tank.bonuses.veteran_speed=1.2
	restored_tank._vet_self_heal=0.002; restored_tank._cd_timer=0.48; restored_tank.cooldown=1.6
	restored_tank._mv_cache={"accel_time":0.5}
	var legacy:=BattleSaves.Snapshot.new().capture(battle)
	BattleSaves.Snapshot.new().restore(battle,legacy)
	restored_tank=battle.units.filter(func(u):return u.unit_id=="R3MIRAGE")[0]
	check(restored_tank.veteran_level==3 and restored_tank.data.veteran.native_ra3,"legacy top rank migrates once to native heroic")
	check(not restored_tank.bonuses.has("veteran_rof") and not restored_tank.bonuses.has("veteran_speed"),"legacy snapshot cannot restore Yuri speed/ROF leak")
	check(is_equal_approx(restored_tank._cd_timer,0.675) and is_equal_approx(restored_tank.cooldown,1.35),"legacy load preserves half of corrected reload cycle")
	check(is_equal_approx(restored_tank._base_speed,150.0) and is_equal_approx(restored_tank._mv("accel_time",0),0.01),"legacy load refreshes movement but preserves progression multiplier")
	check(restored_tank.hp==375.0 and restored_tank.max_hp==750.0,"legacy load preserves health fraction and progression multiplier")
	var again:=BattleSaves.Snapshot.new().capture(battle)
	BattleSaves.Snapshot.new().restore(battle,again)
	restored_tank=battle.units.filter(func(u):return u.unit_id=="R3MIRAGE")[0]
	check(restored_tank.hp==375.0 and restored_tank._base_speed==150.0 and is_equal_approx(restored_tank._cd_timer,0.675),"native reload does not repeat migration")
	for multiplier in [1.0,2.0]:
		BattleClock.set_speed(multiplier)
		check(is_equal_approx(Engine.time_scale,multiplier),"match speed has no hidden15/30 conversion")
		check(is_equal_approx(BattleClock.production_real_seconds(15.0,restored_tank.data),15.0/multiplier),"RA3 native production follows only match multiplier")
	BattleClock.leave_battle()
	screen.free(); Music.stop(); Ra2Sfx.stop_all()
	await get_tree().process_frame
