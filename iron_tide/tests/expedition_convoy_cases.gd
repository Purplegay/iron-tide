extends RefCounted
const Rules=preload("res://scripts/expedition/rules.gd")

static func run(t) -> void:
	for country:String in ["美国","苏俄"]:
		t.new_ready(country,3 if country=="美国" else 14)
		t.check(Expedition.launch(0),"convoy control launch "+country)
		if not t.instantiate_battle():await t.finish();continue
		var runtime=t.screen.expedition_runtime
		var tasks=runtime.tasks
		var truck=tasks.actor("convoy0")
		var authored_midpoint:Vector2=t.battle.player_start().lerp(t.battle.enemy_base_center,0.65)
		t.check(tasks.state.points[2].distance_to(authored_midpoint)>t.battle.map_size*0.12,"escort endpoint extends deep into the enemy side "+country,{"endpoint":tasks.state.points[2],"old_midpoint":authored_midpoint})
		t.check(tasks.state.escort_next_raid==60.0 and tasks.state.next_wave==95.0,"escort opening grace period "+country)
		t.check(runtime.convoy_button!=null and runtime.convoy_button.text=="暂停车队","escort HUD exposes pause control "+country)
		var normal=t.battle.spawn_unit("HTK","ally",t.battle.player_start()+Vector2(350,200))
		t.check(is_equal_approx(Rules.speed_factor(normal),1.0),"ordinary troop vehicle speed unchanged "+country)
		truck.special.expedition_convoy=false;truck._recompute_bonuses()
		var original_speed:float=truck.move_speed
		truck.special.expedition_convoy=true;truck._recompute_bonuses()
		t.check(is_equal_approx(truck.move_speed,original_speed*0.65),"convoy really consumes 65 percent speed "+country)
		var moving_speed:float=truck.move_speed
		truck._recompute_bonuses()
		t.check(is_equal_approx(truck.move_speed,moving_speed),"speed reduction never compounds "+country)
		t.battle.select_unit(normal,false)
		t.battle.select_unit(truck,true)
		t.check(t.battle.selected_units==[normal],"convoy cannot join player selection "+country)
		normal.special.expedition_mission_unit=true
		t.battle.clear_selection();t.battle.select_unit(normal,false)
		t.check(t.battle.selected_units.is_empty(),"side NPC cannot receive player orders "+country)
		t.check(runtime.convoy_controls.size()==3,"three vehicle controls "+country)
		runtime.convoy_controls[1].pressed.emit()
		t.check(tasks.state.convoy_paused and runtime.convoy_button.text=="继续前进" and not t.battle.paused,"pause control stops convoy without pausing battle "+country)
		var positions:Array=[]
		for n in 3:
			var vehicle=tasks.actor("convoy"+str(n))
			positions.append(vehicle.position)
			vehicle.set_fire_stance("none")
			activate(vehicle)
		await t.get_tree().physics_frame
		for frame in 90:
			for n in 3:tasks.actor("convoy"+str(n))._physics_process(1.0/60.0)
			if frame%30==0:tasks.tick(0.5)
			await t.get_tree().physics_frame
		for n in 3:
			var vehicle=tasks.actor("convoy"+str(n))
			t.check(vehicle.position.is_equal_approx(positions[n]) and not vehicle.has_move_order and vehicle.move_speed==0,"paused convoy stays still despite automatic objective ticks "+country+str(n),{"start":positions[n],"end":vehicle.position,"speed":vehicle.move_speed,"order":vehicle.has_move_order})
		for n in 3:tasks.actor("convoy"+str(n)).position=truck.position+Vector2(n*35,0)
		truck.position=tasks.state.origin+Vector2(520,0)
		for n in 3:
			var vehicle=tasks.actor("convoy"+str(n))
			vehicle.position=truck.position+Vector2(n*35,0)
			vehicle.order_stop();vehicle.hold_position=true
		var before_raiders:int=t.battle.units.size()
		tasks.tick(60.0)
		var warning_markers:Array=tasks.minimap_markers().filter(func(marker):return marker.key=="escort_raid")
		t.check(tasks.state.has("escort_pending") and warning_markers.size()==1 and int(warning_markers[0].countdown)==10,"first convoy warning lasts ten seconds "+country)
		tasks.tick(10.0)
		var raiders:Array=[]
		for unit in t.battle.units:
			if t.battle.actor_alive(unit) and unit.special.get("expedition_escort_raider",false):raiders.append(unit)
		t.check(raiders.size()>=3 and tasks.state.escort_raids==1 and t.battle.units.size()>before_raiders,"chrono raiders arrive during convoy pause "+country,{"raiders":raiders.size()})
		for unit in raiders:unit.set_physics_process(false)
		t.check(Expedition.checkpoint(t.battle),"paused convoy checkpoint saves "+country)
		await t.finish()
		t.check(Expedition.load_run() and Expedition.prepare_battle(),"paused convoy checkpoint reloads "+country)
		if not t.instantiate_battle():await t.finish();continue
		await t.get_tree().process_frame
		t.get_tree().paused=false;t.battle.paused=false
		runtime=t.screen.expedition_runtime;tasks=runtime.tasks;truck=tasks.actor("convoy0")
		t.check(tasks.state.convoy_paused and truck.move_speed==0 and not truck.has_move_order and runtime.convoy_button.text=="继续前进","resume checkpoint keeps convoy parked "+country)
		runtime.convoy_button.pressed.emit()
		for n in 3:
			var vehicle=tasks.actor("convoy"+str(n))
			t.check(vehicle.has_move_order and vehicle.move_target==tasks.state.points[2] and is_equal_approx(vehicle.move_speed,moving_speed),"continue restores automatic destination and slower speed "+country+str(n))
		var before:Vector2=truck.position
		activate(truck)
		await t.get_tree().physics_frame
		truck.hull_angle=truck.position.angle_to_point(tasks.state.points[2])
		for frame in 360:
			truck._physics_process(1.0/60.0)
			await t.get_tree().physics_frame
			if truck.position.distance_to(before)>10:break
		t.check(truck.position.distance_to(before)>10,"continued convoy actually drives without another player order "+country)
		if country=="美国":
			for n in 2:tasks.actor("convoy"+str(n)).position=tasks.state.points[2]
			tasks.tick(1.0)
			t.check(t.battle.ended and tasks.state.outcome==1,"resumed convoy still wins with two arrivals")
		else:
			runtime.convoy_button.pressed.emit()
			for n in 2:tasks.actor("convoy"+str(n))._die()
			tasks.tick(1.0)
			t.check(t.battle.ended and tasks.state.outcome==-1,"parking convoy does not prevent loss from two destroyed vehicles")
		t.check(not tasks.set_convoy_paused(false),"finished mission rejects convoy commands "+country)
		await t.finish()

static func activate(vehicle) -> void:
	vehicle.process_mode=Node.PROCESS_MODE_ALWAYS
	vehicle.set_process(false)
	vehicle.set_physics_process(false)
