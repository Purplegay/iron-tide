extends RefCounted
## Isolated campaign stress scenario; prints wall intervals and the coincident physics work.

func run(harness, world, args: PackedStringArray) -> void:
	var tree: SceneTree = world.get_tree()
	var pacing = world.frame_pacing
	harness.check(not tree.current_scene.get_node("BattleAutosave").is_processing(), "掉帧采样已停用自动保存")
	if harness.failed > 0: return
	seed(7027)
	for i in 5: await tree.process_frame
	var beacons: Array = world.buildings.filter(func(b): return world.actor_alive(b) and b.special.has("head_games_beacon"))
	harness.check(beacons.size() == 2 and not world.paused and not tree.paused, "两翼信标存活且验证战场已交控")
	if harness.failed > 0: return
	var untouched := "--battle-untouched" in args
	for beacon in ([] if untouched else beacons):
		world.center_on(beacon.position)
		for i in 4: await tree.process_frame
		var wing: int = beacon.special.head_games_beacon
		var start := Time.get_ticks_usec()
		beacon.receive_hit(100000)
		world._check_end()
		var sync := Time.get_ticks_usec() - start
		await tree.process_frame
		print("FRAME_BEACON ", JSON.stringify({"wing":wing,"sync_ms":sync / 1000.0,"interval_ms":(Time.get_ticks_usec() - start) / 1000.0,"physics_ms":pacing._work_us / 1000.0,"steps":pacing._steps}))
		harness.check(world.allied_state.has("head_games_freed_%d" % wing), "信标实际触发转属 %d" % wing)
	var castles: Array = world.buildings.filter(func(b): return world.actor_alive(b) and b.building_id == world.HeadGames.CASTLE)
	harness.check(castles.size() == 1, "战场有原图城堡")
	if harness.failed > 0: return
	var castle = castles[0]
	if not untouched: world.center_on(castle.position)
	var roster: Array = world.units.filter(func(u): return world.actor_alive(u) and u.side == "ally" and u.embarked_in == null and u.special.has("head_games_wing") and not u.is_harvester)
	var start_order := Time.get_ticks_usec()
	var attack := not untouched and "--battle-idle" not in args
	if attack:
		for wing in 2:
			world.selected_units = roster.filter(func(u): return int(u.special.head_games_wing) == wing)
			world._command_move(castle.position + Vector2(-220 if wing == 0 else 220, 120), false, true)
		world.selected_units = []
	print("FRAME_ORDER ", JSON.stringify({"units":roster.size(),"ms":(Time.get_ticks_usec()-start_order)/1000.0,"mode":"untouched" if untouched else ("attack_move" if attack else "idle")}))
	Engine.time_scale = 3.0 if "--battle-fast" in args else 1.0
	await tree.process_frame
	pacing.take_logic_stats()
	var start := Time.get_ticks_usec()
	var last := start
	var path_before: int = world.path_service.stats_paths
	var last_units: int = world.units.size()
	var last_buildings: int = world.buildings.size()
	var windows: Array = []
	var rows: Array = []
	var total_slow := 0
	var window_limit := 45 if "--battle-long" in args else 15
	for window in window_limit:
		var begin := last
		var slow := 0
		var interval_sum := 0
		var phys_sum := 0
		var step_count := 0
		var max_interval := 0
		var frames := 0
		var largest_phys_on_slow := 0
		while last - begin < 2000000 and not world.ended:
			await tree.process_frame
			var now := Time.get_ticks_usec()
			var interval := now - last
			last = now
			var work: int = pacing._work_us
			var steps: int = pacing._steps
			frames += 1
			interval_sum += interval
			phys_sum += work
			step_count += steps
			max_interval = maxi(max_interval, interval)
			if interval >= 50000:
				slow += 1
				largest_phys_on_slow = maxi(largest_phys_on_slow, work)
			rows.append([int((now-start)/1000.0), interval, work, steps,
				int(Performance.get_monitor(Performance.TIME_PROCESS)*1000000.0),
				int(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000000.0),
				int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))])
		if frames == 0: break
		total_slow += slow
		var paths: int = world.path_service.stats_paths
		var window_data := {"mission_seconds":world.allied_state.get("head_media_clock",0),"seconds":(last-start)/1000000.0,"frames":frames,"fps":frames*1000000.0/maxi(1,interval_sum),"slow50":slow,"max_ms":max_interval/1000.0,"physics_ms":phys_sum/1000.0,"physics_steps":step_count,"slow_max_physics_ms":largest_phys_on_slow/1000.0,"units":world.units.size(),"unit_delta":world.units.size()-last_units,"buildings":world.buildings.size(),"building_delta":world.buildings.size()-last_buildings,"projectiles":world.projectiles_root.get_child_count(),"paths":paths-path_before,"castle_hp":castle.hp if world.actor_alive(castle) else 0}
		windows.append(window_data)
		print("FRAME_WINDOW ", JSON.stringify(window_data))
		last_units=world.units.size()
		last_buildings=world.buildings.size()
		path_before=paths
		if world.ended: break
	if untouched:
		harness.check(beacons.all(func(b): return world.actor_alive(b)) and not world.allied_state.has("head_games_freed_0") and not world.allied_state.has("head_games_freed_1"), "无攻击测试结束，两座信标仍存活且两翼未解放")
	var report := {"speed":Engine.time_scale,"slow50":total_slow,"logic":pacing.take_logic_stats(),"windows":windows,"display":DisplayServer.get_name(),"viewport":str(world.get_viewport_rect().size),"vsync":DisplayServer.window_get_vsync_mode(),"max_fps":Engine.max_fps,"rows_columns":["since_start_ms","interval_us","physics_us","steps","engine_process_sample_us","engine_physics_sample_us","draw_calls"],"rows":rows,"ended":world.ended}
	var output := FileAccess.open("user://s07_frame_probe.json", FileAccess.WRITE)
	harness.check(output != null and not rows.is_empty(), "隔离性能样本已记录")
	if output != null: output.store_string(JSON.stringify(report))
	print("FRAME_TOTAL ", JSON.stringify({"windows":windows.size(),"frames":rows.size(),"slow50":total_slow,"logic":report.logic,"ended":world.ended}))
