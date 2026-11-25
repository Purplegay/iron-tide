extends "res://tests/allied_abilities_regression.gd"
const Flight=preload("res://scripts/units/dread_missile.gd")
const Weapons=preload("res://scripts/units/soviet_advanced.gd")

func exercise_mode(mode:String) -> void:
	if mode!=MatchRules.EXTENDED:return
	setup_logistics_scene(mode,"苏俄")
	if battle.fog!=null:battle.fog.free();battle.fog=null
	var start:=Vector2(1620,1320)
	var truck=actor("V3","ally",start)
	var heading:=Iso.eff_angle()+PI
	truck.turret_angle=heading;truck.hull_angle=heading
	var target=actor("MTNK","enemy",start+Vector2.from_angle(heading)*540)
	battle.camera.zoom=Iso.cam_zoom(2.0)
	battle.camera.position=start;battle.camera.reset_smoothing();battle.camera.force_update_scroll()
	await capture(truck,"loaded")
	Weapons.launch(truck,target)
	var rocket=battle.units.filter(func(u):return u.unit_id=="V3ROCKET")[0]
	rocket.set_physics_process(false)
	for step in [0.0,2.0,1.99,0.02,0.4]:
		Weapons.fly(rocket,step)
		await capture(truck,str(snappedf(rocket.special.flight.elapsed,0.01)))
		var nozzle:=Iso.dir(rocket.position-truck.position)+Flight.exhaust_offset(rocket)
		var rail:=Flight.tail_pixel(rocket,RA2Art.art("V3"),truck.radius,truck.hull_angle)
		if rocket.special.flight.phase=="rack":
			check(nozzle.distance_to(rail)<0.02,"nozzle remains at loaded truck socket during tilt",step)
		elif step<0.1:
			check(nozzle.distance_to(rail)<1.0,"release crosses rack boundary without separation")
		else:
			var smoke=battle.effects_root.get_children().filter(func(n):return n is Ra2Fx).back()
			check(smoke.global_position.is_equal_approx(rocket.global_position) and smoke.draw_offset.distance_to(Flight.exhaust_offset(rocket))<0.01,"boost exhaust starts at visible nozzle")
	for yaw in 32:
		truck.hull_angle=Iso.eff_angle()+yaw*TAU/32
		rocket.special.flight.elapsed=0.0
		Flight.prepare(rocket,truck,0)
		Flight.advance(rocket,rocket.special.flight,2.0)
		var pixel:=Flight.tail_pixel(rocket,RA2Art.art("V3"),truck.radius,truck.hull_angle)
		var nozzle:=Iso.dir(rocket.position-truck.position)+Flight.exhaust_offset(rocket)
		check(nozzle.distance_to(pixel)<0.02,"tail stays attached to the selected voxel facing "+str(yaw))
	check(rocket.special.flight.phase=="rack" and rocket.is_air_target(),"on-rail missile remains interceptable")

	for launcher_id in ["V3","DRED"]:
		var launcher=actor(launcher_id,"ally",start)
		launcher.hull_angle=heading
		var aim:Vector2=start+Vector2.from_angle(heading)*10.0*Ra2Damage.PX_PER_CELL
		var id:="V3ROCKET" if launcher_id=="V3" else "DMISL"
		var probe=actor(id,"ally",start)
		probe.special.flight={"source":launcher,"elapsed":0.0,"aim":aim,"altitude":launcher.data.rocket.altitude}
		Flight.prepare(probe,launcher,1.0)
		var release:=0.0
		var reached:=false
		var sampled_descent:=false
		probe.set_physics_process(false)
		for tick in 3600:
			reached=Flight.advance(probe,probe.special.flight,1.0/60.0)
			if release==0.0 and probe.special.flight.phase!="rack":
				release=probe.special.flight.elapsed
			if reached:break
			if not sampled_descent and probe.special.flight.pitch < -0.3 and probe.logistics.air_lift < 110:
				sampled_descent=true
				var puff=battle.effects_root.get_children().filter(func(n):return n is Ra2Fx).back()
				check(puff.frame>=Flight.SMOKE_FRAME,id+" detached trail starts with smoke")
				check(puff.z_index<DepthLayers.AIR,id+" smoke is behind missile and flame")
				await capture_descent(probe,id)
		check(sampled_descent,id+" rendered descending nozzle")
		var seconds:float=probe.special.flight.elapsed-release
		print(id," 10 cells flight seconds=",snappedf(seconds,0.01)," cap px/s=",probe.special.flight.speed*Flight.TICKS)
		check(reached and probe.position.is_equal_approx(aim),id+" reaches 10-cell target")
		var expected_cap:=123.75 if id=="V3ROCKET" else 148.5
		check(is_equal_approx(probe.special.flight.speed*Flight.TICKS,expected_cap),id+" reaches converted native speed",probe.special.flight.speed*Flight.TICKS)
	# Photograph the same heading on either side of a real two-rail salvo.
	var ship = actor("DRED","ally",start+Vector2(0,650))
	ship.hull_angle = heading
	battle.camera.position = ship.position
	battle.camera.force_update_scroll()
	await capture(ship,"dread-loaded")
	ship._burst_left = 2
	Weapons.launch(ship,target)
	ship._burst_left = 1
	Weapons.launch(ship,target)
	ship._burst_left = 0
	ship.set_fire_stance("none")
	for i in 120:
		ship._physics_process(1.0/15.0)
		for missile in battle.units:
			if missile.unit_id=="DMISL" and missile.special.get("flight",{}).get("source")==ship:
				Weapons.fly(missile,1.0/15.0)
	check(ship._ra2.key=="DREDWO" and ship._cd_timer>2.5, "both rails empty in the middle of actual regeneration")
	await capture(ship,"dread-empty")
	ship._physics_process(3.0)
	check(ship._ra2.key=="DRED", "both rounds visible again when ready")
	await capture(ship,"dread-reloaded")
	for launcher_id in ["V3","DRED"]:
		var carrier=actor(launcher_id,"ally",start)
		Weapons.launch(carrier,target)
		var flying=carrier.special.raising_missile_0
		Weapons.fly(flying,6.0)
		Weapons.tick_racks(carrier,1.0)
		var left:float=carrier.special.missile_racks[0]
		flying.receive_hit(10000)
		check(flying._dead and not carrier.special.has("raising_missile_0") and is_equal_approx(carrier.special.missile_racks[0],left),launcher_id+" airborne interception does not restart regeneration")
		var second=actor(launcher_id,"ally",start)
		Weapons.launch(second,target)
		var raising=second.special.raising_missile_0
		second.receive_hit(10000)
		Weapons.fly(raising,0.1)
		check(raising.is_queued_for_deletion(),launcher_id+" loss of launcher cancels attached missile")
	screen.free();await get_tree().process_frame

func capture(truck,label:String) -> void:
	if DisplayServer.get_name()=="headless":return
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var center:Vector2=truck.get_global_transform_with_canvas().origin
	var full:=stage.get_texture().get_image()
	full.get_region(Rect2i(Vector2i(center)-Vector2i(140,145),Vector2i(280,200))).save_png(output_dir.path_join(label+".png"))


func capture_descent(probe,id:String) -> void:
	if DisplayServer.get_name()=="headless":return
	battle._update_depth_order()
	var nozzle:Vector2=probe.position+RA2Art.art_dir(Flight.exhaust_offset(probe))
	battle.camera.position=nozzle
	battle.camera.force_update_scroll()
	probe.queue_redraw()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var pixel:Vector2=probe.get_canvas_transform()*nozzle
	var crop:=Rect2i(Vector2i(pixel)-Vector2i(90,90),Vector2i(180,180))
	var image:=stage.get_texture().get_image().get_region(crop)
	image.save_png(output_dir.path_join(id+"-descent.png"))
	var flame_pixels:=0
	for x in range(80,101):
		for y in range(80,101):
			var c:=image.get_pixel(x,y)
			if c.r>0.85 and c.g>0.55 and c.b<c.r*0.7:flame_pixels+=1
	check(flame_pixels>=4,id+" visible flame pixels at descending nozzle",flame_pixels)
