extends "res://tests/allied_abilities_regression.gd"

func exercise_mode(mode: String) -> void:
	if mode==MatchRules.RA2: return
	setup_logistics_scene(mode,"美国")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED); Engine.max_fps=0
	for n in battle.units+battle.buildings: n.free()
	battle.units.clear(); battle.buildings.clear()
	for group in ["obstacles","resource_nodes"]:
		for n in get_tree().get_nodes_in_group(group): n.free()
	battle.water_rects=[]; battle.path_service.set_water([]); battle._refresh_pathing()
	for i in 3:
		var u=actor(["R3MIRAGE","MTNK","SREF"][i],"ally",Vector2(1800,1800+i*65))
		u.special.reveal=1000
		battle.selected_units.append(u); u.set_selected(true)
	battle.camera.position=Vector2(1900,1850); battle.camera.zoom=Iso.cam_zoom(1.4)
	battle.camera.reset_smoothing(); battle.camera.force_update_scroll(); battle._emit_selection()
	var layer:=VehicleTracks.new(); layer.name="VehicleTracks"; layer.world=battle
	batch_setup(layer)
	for phase in ["idle_fulltracks","move_fulltracks","move_hidden_tracks"]:
		layer.visible=phase!="move_hidden_tracks"
		for i in battle.units.size():
			var u=battle.units[i]; u.position=Vector2(1800,1800+i*65); u.order_stop()
			if phase!="idle_fulltracks": u.order_move(Vector2(2700,1800+i*65))
		var frames:Array[float]=[]; var costs:Array[float]=[]; var last:=Time.get_ticks_usec()
		for i in 240:
			var start:=Time.get_ticks_usec()
			for u in battle.units: u._physics_process(1.0/60)
			var cost:=Time.get_ticks_usec()-start
			if battle.fog!=null: battle.fog._process(1.0/60)
			layer._process(1.0/60)
			battle.queue_redraw()
			await get_tree().process_frame
			var now:=Time.get_ticks_usec()
			if i>=30: frames.append((now-last)/1000.0); costs.append(cost)
			last=now
		frames.sort(); costs.sort()
		var row={"phase":phase,"median_ms":frames[105],"p95_ms":frames[199],"physics_median_us":costs[105],"marks":layer.marks.size()}
		print("PERF ",JSON.stringify(row)); check(true,phase,row)
	screen.free(); Music.stop(); Ra2Sfx.stop_all()

func batch_setup(layer:VehicleTracks) -> void:
	layer.z_index=DepthLayers.DECAL+1; layer.z_as_relative=false
	battle.add_child(layer)
	for i in VehicleTracks.LIMIT: layer.add_mark(Vector2(1600+i%80*5,1700+i/80*5),0.0,i%2==0)
