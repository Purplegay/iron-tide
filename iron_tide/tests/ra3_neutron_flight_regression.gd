extends "res://tests/ra3_future_presentation_regression.gd"
const Flight=preload("res://scripts/units/ra3_neutron_flight.gd")

func arrive(shot) -> void:
	for i in 150:
		if shot.splinters.get("neutron_stage","node")=="node":return
		Ra3Expansion.tick_shot(shot,1.0/15.0)
	check(false,"projectile arrives within ten seconds")

func color_balance(image: Image) -> float:
	var sum:=0.0;var count:=0
	for y in image.get_height():
		for x in image.get_width():
			var c:=image.get_pixel(x,y)
			if c.a>0.05:sum+=c.b-c.r;count+=1
	return sum/maxi(1,count)

func exercise_mode(mode: String) -> void:
	if mode==MatchRules.RA2:return
	setup_logistics_scene(mode,"美国")
	for node in battle.units+battle.buildings:node.free()
	battle.units.clear();battle.buildings.clear()
	if battle.fog!=null:battle.fog.free();battle.fog=null
	var future=actor("R3FUTURE","ally",Vector2(1400,1400))
	var target=actor("R3FUTURE","enemy",Vector2(1775,1400))
	var shot=Ra3Expansion.make_shot(future,target,target.position,"neutron")
	var muzzle: Vector2=shot.position
	var hp: float=target.hp
	Ra3Expansion.tick_shot(shot,1.0/15.0)
	check(shot.position.distance_to(muzzle)<0.001,"native acceleration begins with zero movement")
	Ra3Expansion.tick_shot(shot,1.0/15.0)
	check(is_equal_approx(float(shot.splinters.flight_distance),7.5),"second native frame moves 5 SAGE units at 1.5 world scale")
	check(shot.position.distance_to(muzzle)>1 and shot.position.distance_to(target.position)>100,"orb travels from muzzle instead of spawning at target")
	check(target.hp==hp and float(shot.splinters.age)==0,"in-flight orb has neither target damage nor node aging")
	var path:=Flight.curve(shot.splinters)
	check(path[16].z>path[0].lerp(path[-1],0.5).z,"native control heights produce a shallow curved flight")
	var codec=preload("res://scripts/save/battle_snapshot.gd").new()
	var snapshot=codec.capture(battle)
	check(not snapshot.is_empty(),"real snapshot captures an in-flight orb")
	arrive(shot);Ra3Expansion.tick_shot(shot,3.0)
	var expected_hp: float=target.hp
	check(is_equal_approx(hp-expected_hp,65.1),"flight adds no extra damage to original seven plus nineteen node pulses")
	codec.restore(battle,snapshot)
	future=battle.units.filter(func(u):return u.side=="ally")[0]
	target=battle.units.filter(func(u):return u.side=="enemy")[0]
	shot=battle.projectiles_root.get_child(0)
	check(shot.splinters.neutron_stage=="flight" and target.hp==hp,"restore does not detonate the saved flying orb")
	arrive(shot);Ra3Expansion.tick_shot(shot,3.0)
	check(is_equal_approx(target.hp,expected_hp),"restored flight hits exactly once and preserves full node damage")
	shot.free()
	for dt in [1.0/60.0,1.0/15.0,0.4]:
		target.hp=target.max_hp
		shot=Ra3Expansion.make_shot(future,target,target.position,"neutron")
		for i in ceili(4.0/dt):Ra3Expansion.tick_shot(shot,dt)
		check(is_equal_approx(target.max_hp-target.hp,65.1),"arrival and node catch-up preserve damage at delta "+str(dt))
		shot.free()
	# Track live targets at the XML adjustment limit; removed targets keep last aim.
	shot=Ra3Expansion.make_shot(future,target,target.position,"neutron")
	var old_end: Vector2=shot.splinters.flight_end
	target.position+=Vector2(0,100)
	Ra3Expansion.tick_shot(shot,1.0/15.0)
	check(is_equal_approx(old_end.distance_to(shot.splinters.flight_end),2.0),"moving target endpoint is limited by native 20 units per second")
	remove_actor(target);arrive(shot)
	check(shot.splinters.neutron_stage=="node","destroyed target does not erase the already fired orb")
	shot.free()
	var flight_images: Array[Image]=[]
	var impact_images: Array[Image]=[]
	for rank in 4:
		future._grant_veteran(rank,false)
		shot=Ra3Expansion.make_shot(future,null,future.position+Vector2(375,0),"neutron")
		Ra3Expansion.tick_shot(shot,0.35)
		check(bool(shot.splinters.heroic)==(rank==3),"rank %d uses official HEROIC weapon gate"%rank)
		if DisplayServer.get_name()!="headless":
			var visual=shot.get_node("NativeFlightFx");visual.set_process(false);visual._sample()
			check(visual.model_id==("fxfutureprojectile02_vet" if rank==3 else "fxfutureprojectile02"),"rank %d renders native flight model"%rank)
			var image: Image=await capture(visual.viewport,"flight-rank-"+str(rank))
			check(image.get_used_rect().get_area()>0,"rank %d flight mesh emits real pixels"%rank)
			flight_images.append(image)
			battle.camera.position=future.position+Vector2(140,0);battle.camera.zoom=Iso.cam_zoom(2);battle.camera.reset_smoothing();battle.camera.force_update_scroll()
			await capture(stage,"flight-battle-rank-"+str(rank))
		arrive(shot)
		check(not shot.has_node("NativeFlightFx"),"rank %d removes flight renderer at impact"%rank)
		if DisplayServer.get_name()!="headless":
			var visual=shot.get_node("NativeFx");visual.set_process(false);visual.age=1.8;visual._sample()
			impact_images.append(await capture(visual.viewport,"impact-rank-"+str(rank)))
		shot.free()
	if not flight_images.is_empty():
		check(changed_pixels(flight_images[0],flight_images[3])>100,"heroic flight color differs in actual rendered pixels")
		check(color_balance(flight_images[0])>color_balance(flight_images[3])+0.03,"normal blue-violet and heroic red-pink remain distinguishable",[color_balance(flight_images[0]),color_balance(flight_images[3])])
		check(changed_pixels(impact_images[0],impact_images[3])>100,"impact also retains the original heroic color variant")
	# No stage in legacy saves means an already-existing node, never a new launch.
	shot=Ra3Expansion.make_shot(future,null,future.position+Vector2(100,0),"neutron")
	for key in shot.splinters.keys():
		if str(key).begins_with("flight_") or key=="neutron_stage":shot.splinters.erase(key)
	shot.splinters.age=3.0;shot.splinters.erase("neutron_pre");shot.splinters.erase("neutron_tick");shot.splinters.erase("neutron_direct")
	Ra3Expansion.tick_shot(shot,0.1)
	check(shot.position==shot.target_point and is_equal_approx(float(shot.splinters.age),3.1),"legacy node resumes at its existing age without replaying launch")
	screen.free();await get_tree().process_frame
