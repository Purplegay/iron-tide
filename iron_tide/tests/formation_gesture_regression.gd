extends "res://tests/selection_regression.gd"

func exercise_mode(mode: String) -> void:
	BattleRequest.configure_skirmish(mode, {"map_size":3200,"fog_of_war":false})
	screen=load("res://scenes/battle.tscn").instantiate()
	stage.add_child(screen)
	battle=screen.battle
	screen.process_mode=Node.PROCESS_MODE_DISABLED
	battle.process_mode=Node.PROCESS_MODE_ALWAYS
	battle.set_process(false)
	battle.set_physics_process(false)
	battle.camera.position=Vector2(1600,1600)
	battle.camera.reset_smoothing()
	battle.camera.force_update_scroll()
	get_window().focus_entered.emit()
	var at:=Vector2(680,420)
	var center:Vector2=battle.get_canvas_transform().affine_inverse()*at
	battle.clear_selection()
	var squad: Array=[]
	for i in 3:
		var id:String=["MTNK","R3REAPER","E1"][i] if mode==MatchRules.EXTENDED else "MTNK"
		var u=battle.spawn_unit(id,"ally",center+Vector2(-140,i*60))
		u.process_mode=Node.PROCESS_MODE_ALWAYS
		u.set_physics_process(false)
		squad.append(u)
		battle.select_unit(u,true)
	for first in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]:
		battle.right_click_scroll=first==MOUSE_BUTTON_LEFT
		var second:=MOUSE_BUTTON_RIGHT if first==MOUSE_BUTTON_LEFT else MOUSE_BUTTON_LEFT
		for u in squad: u.order_stop()
		await mouse_button(at,true,false,first)
		await mouse_button(at,true,false,second)
		var g=battle.formation_gesture
		check(g.held!=0 and g.assigned.size()==3,"chord takes ownership")
		if not g.held:break
		var motion:=InputEventMouseMotion.new()
		motion.position=at+Vector2(90,-60)
		motion.global_position=motion.position
		motion.relative=motion.position-at
		motion.button_mask=MOUSE_BUTTON_MASK_LEFT|MOUSE_BUTTON_MASK_RIGHT
		stage.push_input(motion,true)
		await get_tree().process_frame
		var facing:float=g.heading
		var assigned:Dictionary=g.assigned.duplicate()
		check(g.columns==3 and absf(angle_difference(g.initial_heading,facing)-PI/2)<0.001,"drag widens and rotates line")
		check(g.ghosts.size()==3 and g.meshes.size()==(1 if mode==MatchRules.EXTENDED else 0),"correct preview model sources")
		for u in squad:
			var ghost=g.ghosts[u]
			check(ghost.position==assigned[u] and is_equal_approx(ghost.hull_angle,facing) and ghost.unit_id==u.unit_id and not ghost.is_in_group("combatants"),"preview model matches its real order")
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var frame:=stage.get_texture().get_image()
			if first==MOUSE_BUTTON_LEFT:frame.save_png(output_dir.path_join("models-"+mode+".png"))
			for u in squad:
				var where:Vector2=battle.get_canvas_transform()*assigned[u]
				var hits:=0
				for x in range(int(where.x)-25,int(where.x)+26):
					for y in range(int(where.y)-40,int(where.y)+10):
						var c:=frame.get_pixel(x,y)
						if c.g>0.27 and c.g>c.r*2 and c.g>c.b*1.6:hits+=1
				check(hits>14,"green model pixels for "+u.unit_id,hits)
		await mouse_button(motion.position,false,false,first)
		check(not squad[0].has_move_order and g.held!=0,"first release keeps preview")
		await mouse_button(motion.position,false,false,second)
		check(g.preview_root==null and g.ghosts.is_empty() and g.meshes.is_empty(),"release clears preview resources")
		check(g.held==0 and battle.selected_units.size()==3 and not battle.dragging and not battle._rmb_panning,"second release preserves selection")
		for u in squad:
			check(u.has_move_order and u.move_target.distance_to(assigned[u])<2 and u.special.get("formation_heading",INF)==facing,"move uses preview position and heading",[u.move_target,assigned[u]])
			u.position=u.move_target
			u.hull_angle=facing+PI/2
			for tick in 180: u._physics_process(1.0/60)
			check(absf(angle_difference(u.hull_angle,facing))<0.02,"body turns to ordered heading after arrival", [u.hull_angle,facing])
	var tank=squad[0]
	battle.select_unit(tank,false)
	tank.order_stop()
	await mouse_button(at,true)
	await mouse_button(at,true,false,MOUSE_BUTTON_RIGHT)
	await key(KEY_ESCAPE)
	await mouse_button(at,false,false,MOUSE_BUTTON_RIGHT)
	await mouse_button(at,false)
	check(not tank.has_move_order and battle.formation_gesture.held==0,"Escape cancels without an order")
	# Let a single tank drive from open ground under its normal physics controller.
	at+=Vector2(-75,55)
	center=battle.get_canvas_transform().affine_inverse()*at
	tank.position=center+Vector2(0,-110)
	await mouse_button(at,true,false,MOUSE_BUTTON_RIGHT)
	await mouse_button(at,true)
	var arrival_heading:float=battle.formation_gesture.heading
	await mouse_button(at,false)
	await mouse_button(at,false,false,MOUSE_BUTTON_RIGHT)
	var target:Vector2=tank.move_target
	check(tank.has_move_order and tank.position.distance_to(target)>60,"single tank starts away from its assigned slot")
	for tick in 360:
		await get_tree().physics_frame
		tank._physics_process(1.0/60)
		if not tank.has_move_order and not tank.special.has("formation_heading"):break
	check(not tank.has_move_order and tank.position.distance_to(target)<=tank.ARRIVE_EPS+1 and absf(angle_difference(tank.hull_angle,arrival_heading))<0.02,"single tank drives to slot and settles facing", [tank.position,target,tank.hull_angle,arrival_heading])
	screen.free()
	await get_tree().process_frame
