extends "res://tests/allied_abilities_regression.gd"
const Mounts=preload("res://scripts/units/ra3_gunship_mounts.gd")
const Shell=preload("res://scripts/units/ra3_gunship_shell.gd")
const Crash=preload("res://scripts/units/ra3_gunship_crash.gd")
const Impulse=preload("res://scripts/units/ra3_meta_impact.gd")
const Extras=preload("res://scripts/units/ra3_mirage_extras.gd")

func clear_shots() -> void:
	for shot in battle.projectiles_root.get_children():shot.free()

func exercise_mode(mode: String) -> void:
	if mode==MatchRules.RA2:return
	setup_logistics_scene(mode,"美国")
	for node in battle.units+battle.buildings:node.free()
	battle.units.clear();battle.buildings.clear()
	if battle.fog!=null:battle.fog.free();battle.fog=null
	var mirage=actor("R3MIRAGE","ally",Vector2(1600,1600))
	var primary=actor("R3FUTURE","enemy",Vector2(1800,1600))
	var first=actor("R3FUTURE","enemy",Vector2(1970,1600))
	var second=actor("R3FUTURE","enemy",Vector2(2070,1600))
	var friend=actor("MTNK","ally",second.position+Vector2(0,20))
	var air=actor("R3HARBINGER","enemy",second.position+Vector2(0,30))
	await get_tree().physics_frame
	for rank in [0,3]:
		mirage._grant_veteran(rank,false)
		var before:float=second.hp
		mirage._fire_shot(primary)
		check(battle.projectiles_root.get_child_count()==(3 if rank==3 else 2),"Mirage rank %d emits only source-valid chain targets"%rank)
		for shot in battle.projectiles_root.get_children():Ra3Mirage.tick_impact(shot,0.099)
		check(is_equal_approx(second.hp,before),"Mirage rank %d respects damage delay"%rank)
		for shot in battle.projectiles_root.get_children():Ra3Mirage.tick_impact(shot,0.002)
		var expected:float=20.0*1.25*float(Shell.rules.cannon_armor.R3FUTURE) if rank==3 else 0.0
		check(is_equal_approx(before-second.hp,expected),"hero second hop uses 20 CANNON and one rank multiplier",before-second.hp)
		check(friend.hp==friend.max_hp and air.hp==air.max_hp,"scatter excludes allies and air")
		clear_shots()
	var gunship=actor("R3HARBINGER","ally",Vector2(2300,2200))
	var target=actor("R3FUTURE","enemy",Vector2(2300,1900))
	gunship.attack_target=target;gunship.attack_ordered=true;gunship.hull_angle=0;gunship.logistics.air_lift=1
	Mounts.tick(gunship,2.0)
	var mounts:Dictionary=Mounts.states(gunship)
	mounts.side.remaining=0.0;mounts.side.used=11;mounts.rear.remaining=0.4;mounts.rear.used=5
	check(gunship._try_fire_ready(),"independent side mount fires through actual Unit gate")
	check(battle.projectiles_root.get_child_count()==1 and mounts.side.used==0 and mounts.rear.used==5,"one ready cannon does not spend the other cannon clip")
	check(is_equal_approx(mounts.side.remaining,4.0) and is_equal_approx(mounts.rear.remaining,0.4),"independent reload and cadence remain separate")
	var shot=battle.projectiles_root.get_child(0)
	var curve=Shell.path(shot.splinters)
	check(curve[0].z>0 and curve[-1].z==0,"shell travels from native airborne muzzle height to ground")
	check(not curve[16].is_equal_approx(curve[0].lerp(curve[-1],0.5)),"shell path has a muzzle-tangent curve")
	var original:Dictionary=shot.splinters.duplicate(true)
	var arrival:Array=[]
	for hz in [15,60,120]:
		shot.splinters=original.duplicate(true)
		var elapsed:=0.0
		while elapsed<5:
			elapsed+=1.0/hz
			if Shell.advance(shot,1.0/hz):break
		arrival.append(elapsed)
	check(absf(arrival[0]-arrival[1])<0.001 and absf(arrival[0]-arrival[2])<0.001,"shell arrival is independent of render frequency",arrival)
	shot.splinters=original.duplicate(true)
	Shell.advance(shot,0.1)
	var before_end:Vector2=shot.splinters.shell_end
	target.position+=Vector2(100,0)
	Shell.advance(shot,1.0/15.0)
	check(is_equal_approx(before_end.distance_to(shot.splinters.shell_end),30.0),"shell tracking obeys 300 native distance per second")
	clear_shots()
	Mounts.tick(gunship,0.4)
	check(gunship._try_fire_ready() and battle.projectiles_root.get_child_count()==1,"rear fires while side is reloading")
	clear_shots()
	var remaining:float=mounts.side.remaining
	Ra3Expansion.use(gunship,Vector2.INF)
	Mounts.tick(gunship,0.1)
	check(is_equal_approx(mounts.side.remaining,remaining-0.1),"inactive cannon reload advances in machine gun mode")
	Ra3Expansion.use(gunship,Vector2.INF)
	check(is_equal_approx(mounts.side.remaining,remaining-0.1),"mode switch preserves cannon clock")
	var codec=preload("res://scripts/save/battle_snapshot.gd").new()
	var snapshot=codec.capture(battle)
	check(not snapshot.is_empty(),"independent mount references serialize")
	codec.restore(battle,snapshot)
	for unit in battle.units:
		unit.process_mode=Node.PROCESS_MODE_ALWAYS
		unit.set_process(false);unit.set_physics_process(false)
		if unit.unit_id=="R3HARBINGER" and unit.side=="ally":gunship=unit
		if unit.unit_id=="R3MIRAGE":mirage=unit
	check(is_equal_approx(Mounts.states(gunship).side.remaining,remaining-0.1),"read restores independent reload without resetting it")
	battle.selected_units=[gunship]
	preload("res://scripts/admin/gm_unit_tools.gd").run(battle,{"action":"reset"})
	check(Mounts.states(gunship).values().all(func(m):return m.used==0 and m.remaining==0.0),"GM reset clears every mount including the inactive weapon")
	gunship.logistics.air_lift=0
	check(not gunship._try_fire_ready(),"parked gunship cannot bypass logistics firing gate")
	gunship.position=Vector2(2600,2600);gunship.velocity=Vector2.ZERO;gunship.logistics.air_lift=1
	var victim=actor("R3FUTURE","enemy",gunship.position+Vector2(20,0))
	var friendly=actor("R3FUTURE","ally",gunship.position+Vector2(0,20))
	var overhead=actor("R3HARBINGER","enemy",gunship.position+Vector2(0,30))
	var hp:float=victim.hp;var friend_hp:float=friendly.hp
	gunship.hp=0;gunship._die()
	check(battle.projectiles_root.get_child_count()==1 and victim.hp==hp,"air death creates a crash with no premature splash")
	var crash=battle.projectiles_root.get_child(0)
	Crash.tick(crash,0.1)
	check(victim.hp==hp and Crash.altitude(crash.splinters)>0,"falling body remains harmless above ground")
	var saved=codec.capture(battle)
	codec.restore(battle,saved)
	check(get_tree().get_nodes_in_group("ra3_crash_fx").is_empty(),"restore clears explosions from the previous timeline")
	for unit in battle.units:
		unit.process_mode=Node.PROCESS_MODE_ALWAYS
		unit.set_process(false);unit.set_physics_process(false)
	# References belong to the old scene after restore; reacquire by position/type.
	for unit in battle.units:
		if unit.unit_id=="R3FUTURE" and unit.position.distance_to(Vector2(2620,2600))<1:victim=unit
		if unit.unit_id=="R3FUTURE" and unit.position.distance_to(Vector2(2600,2620))<1:friendly=unit
		if unit.unit_id=="R3HARBINGER" and unit.position.distance_to(Vector2(2600,2630))<1:overhead=unit
	crash=battle.projectiles_root.get_child(0)
	check(is_equal_approx(float(crash.splinters.age),0.1),"mid-fall save resumes exact age")
	Crash.tick(crash,3.0)
	var impact_hp:float=victim.hp
	Crash.tick(crash,1.0)
	check(victim.hp==impact_hp,"queued crash never applies the ground weapon twice")
	check(hp>victim.hp and is_equal_approx(hp-victim.hp,2.0*(friend_hp-friendly.hp)),"ground crash applies native hostile and half allied splash")
	check(overhead.hp==overhead.max_hp,"crash weapon excludes airborne targets")
	check(victim.special.has("ra3_impulse"),"crash creates native MetaImpact impulse")
	await get_tree().physics_frame
	var point:Vector2=victim.position;hp=victim.hp
	Impulse.tick(victim,0.1)
	check(victim.position.distance_to(point)>0 and victim.hp==hp,"knockback moves via collision without extra damage")
	Impulse.tick(victim,2.0)
	check(not victim.special.has("ra3_impulse"),"impulse lifetime is bounded")
	clear_shots()
	var parked=actor("R3HARBINGER","ally",Vector2(3000,2600))
	parked.logistics.air_lift=0;parked.hp=0;parked._die()
	check(battle.projectiles_root.get_child_count()==0,"grounded death skips airborne crash weapon")
	var erased=actor("R3HARBINGER","ally",Vector2(3100,2600))
	erased.hp=0;erased._die(null,true)
	check(battle.projectiles_root.get_child_count()==0,"temporal erasure skips crash lifecycle")
	# Visual source resources and transition are exercised in the real renderer.
	for unit in battle.units:
		if unit.unit_id=="R3MIRAGE":mirage=unit
	mirage.special.erase("reveal");mirage.special.ra3_field=false;mirage.has_move_order=false;mirage.velocity=Vector2.ZERO
	battle.set_meta("ra3_terrain_class","Snow")
	mirage.special.erase("ra3_disguise_prop")
	var expected:String=Extras.data.terrain.get("Snow","Tree01")
	check(Extras.disguise_id(mirage)==expected,"simulation chooses native terrain disguise")
	check(Extras.data.props.size()==4 and Extras.data.parts.size()==3,"four original props and three omitted FX meshes imported")
	if DisplayServer.get_name()!="headless":
		var blast=preload("res://scripts/units/ra3_crash_fx.gd").spawn(battle,Vector2(1500,1500))
		blast.set_process(false)
		check(blast.rows.size()==42,"crash FX emits the four official systems and source burst counts")
		var saved_pause:bool=battle.paused;battle.paused=false
		blast._process(0.2);battle.paused=saved_pause
		battle.camera.position=blast.position;battle.camera.zoom=Iso.cam_zoom(1.0)
		battle.camera.reset_smoothing();battle.camera.force_update_scroll()
		for i in 3:await get_tree().process_frame
		await RenderingServer.frame_post_draw
		stage.get_texture().get_image().save_png(output_dir.path_join("crash.png"))
		blast.free()
		var model=mirage._ra3_model;model.set_process(false)
		check(model.native_extras.get_child_count()>=3,"native model FX attached to rig")
		model.native_extras.tick(0.2)
		check(model.native_extras.rays.size()==2,"both disguise ears emit after source initial delay")
		model.sync_pose(true);model.viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
		for i in 3:await get_tree().process_frame
		await RenderingServer.frame_post_draw
		model.viewport.get_texture().get_image().save_png(output_dir.path_join("mirage-extra.png"))
		mirage.special.reveal=2.0;model.native_extras.tick(0.01)
		check(model.native_extras.rays.is_empty(),"attacking reveal stops disguise emitters")
		model.animation.advance(0.1,false,true)
		model.animation.advance(0.1,true,false)
		check(model.animation.transition_left>0 and model.animation.clip=="IDLA","exit field runs source transition before movement")
		model.animation.advance(0.1,false,true)
		check(model.animation.transition_left==0,"reopening field interrupts exit transition")
	screen.free();await get_tree().process_frame
