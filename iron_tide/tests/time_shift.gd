extends Node

var failures := 0
func check(value:bool,label:String) -> void:
	print("SOV01 ",value," ",label)
	if not value:failures+=1

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	var tree:=get_tree()
	reparent(tree.root)
	var args := OS.get_cmdline_user_args()
	if "--cold-crossings" in args:
		var i := int(args[args.find("--cold-crossings") + 1])
		var result := BattleSaves.load_into_scene("slot%d" % (i + 1) if i < 3 else "auto")
		check(result.ok, "从磁盘加载旋涡断点 %d" % i)
		if not result.ok:
			tree.quit(failures)
			return
		await tree.scene_changed
		var world = tree.current_scene.battle
		var state: Dictionary = world.allied_state.time_shift
		var era := 1 + int(i >= 2)
		var after := i % 2 == 1
		var phase := era + (2 if after else 1)
		var overlay: Node = world.get_node_or_null("TimeVortex")
		var elapsed := 1.5 if after else 0.7
		check(world.paused and state.phase == phase and is_equal_approx(state.crossing_time, elapsed), "暂停读档保留阶段和计时 %d" % i)
		check(overlay != null and is_equal_approx(overlay.get_child(0).material.get_shader_parameter("progress"), elapsed / world.TimeShift.CROSSING_DURATION), "暂停画面复原旋涡进度 %d" % i)
		var area: Rect2i = Rect2i(4,29,52,67) if phase == 2 else world.TimeShift.BOUNDS[phase - 2]
		check(world.path_service.time_shift_area == area and not world.has_node("HollywoodFilm"), "阶段边界一致且未提前播放简报 %d" % i)
		world.hud._toggle_pause()
		world.TimeShift.advance_crossing(world, state, 2.2)
		check(state.phase == era + 2 and not state.has("crossing_era") and world.has_node("HollywoodFilm"), "继续后完成切换并播放简报 %d" % i)
		if after and era == 2:
			check(state.dominator.hp == state.dominator.max_hp * 0.5, "过半后的目标建筑伤害未被重复切换抹掉")
		tree.quit(failures)
		return
	if "--cold" in args:
		var loaded:=BattleSaves.load_into_scene("quick")
		check(loaded.ok,"冷进程从磁盘读取第一关 "+str(loaded.get("message","")))
		if loaded.ok:
			await tree.scene_changed
			var restored=tree.current_scene.battle
			check(restored.allied_state.time_shift.phase==3 and restored.actor_alive(restored.allied_state.time_shift.machine),"冷读档保留时代和时光机")
			check(restored.path_service.time_shift_area==restored.TimeShift.BOUNDS[1] and not restored.has_node("HollywoodFilm"),"读档恢复区域且不重播开场")
		tree.quit(failures)
		return
	var menu=load("res://scenes/campaign_command.tscn").instantiate()
	tree.root.add_child(menu)
	for b in menu.find_children("*","Button",true,false):
		if b.text=="苏军战役":b.pressed.emit();break
	check(menu.mission.id=="yr_time_shift","苏军菜单第一关")
	for b in menu.find_children("*","Button",true,false):
		if b.text=="出击":b.pressed.emit();break
	await tree.scene_changed
	var w=tree.current_scene.battle
	var m=w.TimeShift
	var s:Dictionary=w.allied_state.time_shift
	if "--media" in OS.get_cmdline_user_args():
		for file in m.ASSETS.data.voices.values():
			var stream=load("res://assets/ra2/time_shift/"+file+".wav")
			check(stream is AudioStreamWAV and stream.get_length()>0,"原版电台录音 "+file)
		for clip in m.AFTER_FILM:
			if clip=="S01_P02E":BattleClock.set_speed(3.0)
			if clip!="S01_F00E":m.scenario_film(w,clip)
			var started := Time.get_ticks_msec()
			var film=w.get_node("HollywoodFilm")
			var full:bool=clip=="S01_F00E"
			var at:float=3.5 if clip=="S01_P02E" else 6.0 if not full else 0.35
			while film.player.is_playing() and film.player.stream_position<at:await tree.process_frame
			check(film.player.is_playing() and film.clip_id==clip and not film.subtitle.text.is_empty(),"原声影片及同步字幕 "+clip)
			if clip=="S01_P02E":
				var real_time := (Time.get_ticks_msec()-started)/1000.0
				check(absf(film.player.stream_position-real_time)<0.45 and absf(film.mission_audio.get_playback_position()-real_time)<0.45,"三倍速下影片与人声按现实时间播放")
				BattleClock.set_speed(1.0)
			if not full:check(film.player.get_global_rect().get_center().x>get_viewport().get_visible_rect().size.x*0.75,"右上雷达小窗 "+clip)
			Ra2Sfx.stop_eva()
			if clip=="S01_P01E":await film.player.finished
			else:film.skip.pressed.emit()
			var first:String=m.AFTER_FILM[clip][0] if not m.AFTER_FILM[clip].is_empty() else "EVA_BattlefieldControlOnline"
			var file:String=m.ASSETS.data.voices[first]
			check(Ra2Sfx._eva_player.playing and Ra2Sfx._eva_player.stream.resource_path.ends_with("/"+file+".wav"),"片尾衔接原版电台 "+file)
			await tree.process_frame
			await tree.process_frame
		tree.quit(failures)
		return
	check(w.get_node("HollywoodFilm").player.is_playing() and not w.get_node("HollywoodFilm").subtitle.text.is_empty(),"战前简报播放")
	w.get_node("HollywoodFilm").skip.pressed.emit()
	await tree.process_frame
	if "--shop-capture-color" in args:
		var shops=w.buildings.filter(func(b):return w.actor_alive(b) and b.building_id=="CAMACH")
		check(shops.size()==1,"第一关载入原图机械维修厂")
		if shops.is_empty():tree.quit(failures);return
		var shop=shops[0]
		check(shop.side=="enemy" and shop._ra2.tex.resource_path.ends_with("/shp/CAMACH.png"),"维修厂初始属盟军并使用原版蓝色贴图")
		check(shop.material!=null and shop.material.get_shader_parameter("paint_mode")==HouseColor.PaintMode.SHOP_FACADE and shop.material.get_shader_parameter("target_color").is_equal_approx(HouseColor.color_for_side("enemy","#57a8ff")),"占领前使用盟军房色材质")
		w.center_on(shop.position)
		w.fog._reveal("ally",shop.position,650)
		w.fog._sync_mask()
		var engineer=w.spawn_unit("SENGINEER","ally",shop.position+Vector2(160,120))
		check(engineer.order_interaction("allied_engineer",shop,false),"工程师下达正式占领命令")
		if engineer.special.get("action")=="allied_engineer":
			engineer.position=AlliedAbilities.approach(engineer,shop)
			AlliedAbilities.tick_action(engineer,1.0)
		check(shop.side=="ally" and not w.actor_alive(engineer),"工程师进门后转属并消耗")
		check(shop.material!=null and shop.material.get_shader_parameter("paint_mode")==HouseColor.PaintMode.SHOP_FACADE and shop.material.get_shader_parameter("target_color").is_equal_approx(HouseColor.mission_color("ally")),"占领同一步刷新维修厂苏军房色")
		tree.quit(failures)
		return
	check(w.units.filter(func(u):return u.side=="ally" and u.is_naval).size()==13,"13艘苏军舰艇")
	check(w.units.filter(func(u):return u.side=="ally").all(func(u):return w.path_service.in_naval_water(u.position)),"开场舰艇实际在水面")
	if "--alcatraz-cliff" in OS.get_cmdline_user_args():
		m.bounds(w,2)
		var coast := Vector2(123.5,40.5)*55
		var cliff := Vector2(123.5,39.5)*55
		var top := Vector2(128.5,36.5)*55
		var beach := Vector2(128.5,42.5)*55
		var hover=w.spawn_unit("SAPC","ally",coast)
		var tank=w.spawn_unit("HTNK","ally",beach)
		check(hover.is_amphibious and hover._domain_ok(coast) and not hover._domain_ok(cliff),"运输艇可航行，崖壁禁止进入")
		check(not tank._domain_ok(coast) and not tank._domain_ok(cliff),"坦克不能进入水面或崖壁")
		for v in range(36,44):
			check(hover._domain_ok(Vector2(128.5,v+.5)*55) and tank._domain_ok(Vector2(128.5,v+.5)*55),"沙滩坡道可通过 %d"%v)
		hover.position = Vector2(123.5,40.02)*55
		for i in 5:
			hover.velocity = Vector2.UP*240
			hover._move_water_safe()
		check(hover.position.y >= 40*55,"运输艇从水面顶向直崖时停在崖脚")
		w.selected_units.assign([tank])
		w._command_move(top + Vector2.UP*30)
		for frame in 900:
			await tree.physics_frame
			if tank.position.distance_to(top)<23:break
		check(tank.position.distance_to(top)<23,"坦克从沙滩沿坡道抵达高地 "+str(tank.position/55))
		w.center_on(Vector2(125.5,39.5)*55)
		if OS.has_environment("S01_CLIFF_PICTURE"):
			for frame in 6:await tree.process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(OS.get_environment("S01_CLIFF_PICTURE"))
		tree.quit(failures)
		return
	if "--fence" in OS.get_cmdline_user_args():
		m.bounds(w,0,true)
		var fence=w.wall_cells.values().filter(func(b):return b.position==Vector2(97.5,125.5)*55)[0]
		var start:Vector2=fence.position+Vector2.UP*110
		var goal:Vector2=fence.position+Vector2.DOWN*110
		var tank=w.spawn_unit("HTNK","ally",start)
		var infantry=w.spawn_unit("E2","ally",start+Vector2.LEFT*110)
		check(WallArt.supported(fence.data,fence._ra2),"围栏加载连接帧")
		check(w.movement_service(infantry).is_blocked(fence.position),"步兵受完整围栏阻挡")
		check(not w.movement_service(tank).is_blocked(fence.position),"犀牛可以规划穿过轻围栏")
		var wall=w.wall_cells.values().filter(func(b):return b.building_id=="GAWALL")[0]
		check(not WallArt.crushable_fence(wall) and w.movement_service(tank).is_blocked(wall.position),"混凝土墙仍阻挡犀牛")
		var center:Vector2=fence.position
		w.selected_units.assign([tank])
		w._command_move(goal)
		for frame in 420:
			await tree.physics_frame
			if tank.position.distance_to(goal)<25:break
		check(not w.actor_alive(fence),"行驶接触后压毁栏段")
		check(tank.position.distance_to(goal)<25,"坦克越过围栏抵达命令目标 "+str(tank.position-center))
		tree.quit(failures)
		return
	if "--outline" in OS.get_cmdline_user_args():
		w.center_on(m.wp(18))
		w.attack_target_outlines.refresh(w)
		for frame in 6:await tree.process_frame
		await RenderingServer.frame_post_draw
		for ship in w.units:
			if ship.side != "ally" or not ship.is_naval:continue
			var outline = ship.get_node_or_null("SelectionOutline")
			check(outline != null and outline.visible and outline.used > 0 and outline.get_child(0).material.get_shader_parameter("outline_color").is_equal_approx(outline.OWN_COLOR),ship.unit_id+" 舰艇黄色识别描边")
		tree.quit(failures)
		return
	if OS.has_environment("S01_SCREEN_DIR"):
		var cam:Camera2D=w.camera
		w.center_on(m.wp(18))
		for frame in 6:await tree.process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(OS.get_environment("S01_SCREEN_DIR")+"/fleet.png")
	var ids=world_bridge_ids(w)
	check(ids.size()==6 and not ids.has("CASANF10"),"原图七段金门大桥保留初始断口")
	var all_sites:=true
	for row in m.FIELD.data.sites:
		if GameData.get_building(row[0]).is_empty() or not RA2Art.has_art(row[0]):all_sites=false;break
	check(all_sites,"原图155条建筑记录均有定义及贴图")
	if OS.has_environment("S01_SCREEN_DIR"):
		await portrait(w,tree)
	var stations=w.buildings.filter(func(b):return b.building_id in m.POWER_PLANTS)
	var dread=w.units.filter(func(u):return u.unit_id=="DRED" and u.side=="ally")[0]
	check(stations.size()==6,"原图六座任务电厂")
	for station in stations:
		station.receive_hit(100000,"shell",{},dread)
		check(station.hp==5000 and station.data.unsellable and not dread._weapon_domain_valid(station),"海战中电厂免伤且排除武器锁定 "+station.building_id)
	check(s.has("Mis_xS1_ZofiaDoNotKillPower"),"误伤电厂保留索菲亚提醒")
	var targets=w.units.filter(func(u):return u.special.get("time_shift_tag")=="SP2.1_Destroy_AlliedDef")+w.buildings.filter(func(b):return b.special.get("time_shift_tag")=="SP2.1_Destroy_AlliedDef")
	check(w.hud.minimap.objective_marks().size()==7 and w.CampaignMarks.marks(w, false).size()==7,"海战战场和雷达显示七个目标")
	if OS.has_environment("S01_RADAR_PNG"):
		w.hud.minimap.queue_redraw()
		await RenderingServer.frame_post_draw
		var radar=w.hud.minimap
		var rect:=Rect2i(get_viewport().get_final_transform()*radar.get_global_transform_with_canvas()*Rect2(Vector2.ZERO,radar.size))
		get_viewport().get_texture().get_image().get_region(rect).save_png(OS.get_environment("S01_RADAR_PNG"))
	check(targets.size()==7,"七个原图岸防目标")
	for target in targets:target.receive_hit(100000)
	m.tick(w,1)
	check(s.phase==1 and w.units.filter(func(u):return u.unit_id=="SAPC").size()==4,"四艘登陆艇入场")
	stations[0].receive_hit(100000)
	check(stations[0].hp==5000,"登陆排雷阶段电厂继续免伤")
	check(w.hud.minimap.objective_marks().size()==4 and w.CampaignMarks.marks(w, false).size()==4,"登陆后两处均改标四座碉堡")
	var landing_film=w.get_node("HollywoodFilm")
	if OS.has_environment("S01_SCREEN_DIR"):
		while landing_film.player.stream_position<6 and landing_film.player.is_playing():await tree.process_frame
		await RenderingServer.frame_post_draw
		check(not landing_film.subtitle.text.is_empty(),"雷达小窗续音同步显示中文字幕")
		get_viewport().get_texture().get_image().save_png(OS.get_environment("S01_SCREEN_DIR")+"/radio.png")
	landing_film.skip.pressed.emit()
	for i in 1800:
		await tree.physics_frame
		if w.units.any(func(u):return w.actor_alive(u) and u.unit_id=="BORIS" and u.embarked_in==null):break
	check(w.units.any(func(u):return w.actor_alive(u) and u.unit_id=="BORIS" and u.embarked_in==null),"鲍里斯自行登陆")
	for b in w.buildings.duplicate():
		if w.actor_alive(b) and b.special.get("time_shift_tag")=="Destroy_Time Defenses":b.receive_hit(100000)
	m.tick(w,1)
	check(s.phase==2 and s.machine.side=="ally","摧毁守卫后接管时光机")
	if "--raid-single" in args:
		var row: Dictionary = m.FIELD.data.raids.filter(func(r): return r.group == "Reinforce_Atk Group 1" and r.route.back() == 130)[0]
		m.Story.raid(w,row)
		var boat = w.units.filter(func(u): return w.actor_alive(u) and u.unit_id == "YHVR")[0]
		for frame in 1500:
			await tree.physics_frame
			if frame % 24 == 0:
				m.Story.power_contest(w,s)
				if boat.logistics.passengers.is_empty(): break
		check(boat.logistics.passengers.is_empty(), "第三艘单独自然抵达并卸载")
		print("SOV01 SINGLE end=", boat.position / 55.0, " target=", boat.special.get("shift_raid", Vector2.INF) / 55.0, " aboard=", boat.logistics.passengers.size())
		tree.quit(failures)
		return
	stations[0].receive_hit(150)
	check(not stations[0].is_protected_mission_plant() and stations[0].hp<5000,"接管时光机后恢复受击")
	if "--raid-timing" in OS.get_cmdline_user_args():
		var boats:=func():return w.units.filter(func(u):return u.unit_id=="YHVR").size()
		check(boats.call()==0,"登陆及接管期间没有尤里气垫船")
		m.tick(w,64)
		check(boats.call()==0 and not s.has("Mis_xS1_ZofiaYuriNeedsPower"),"第64秒尚未预警")
		m.tick(w,1)
		check(boats.call()==0 and s.has("Mis_xS1_ZofiaYuriNeedsPower"),"第65秒先预警")
		m.tick(w,2)
		check(boats.call()==0,"第67秒尚未出兵")
		m.tick(w,1)
		check(boats.call()==3,"第68秒三艘新兵船出发")
		if "--raid-voyage" in args:
			s.raid_index = 4 # Isolate the first wave from the next timed wave.
			var attack_boats: Array = w.units.filter(func(u): return w.actor_alive(u) and u.unit_id == "YHVR")
			var all_landed := false
			for frame in 2100:
				await tree.physics_frame
				if frame % 30 != 0: continue
				all_landed = attack_boats.all(func(u): return w.actor_alive(u) and u.logistics.passengers.is_empty())
				if all_landed: break
			check(all_landed, "第一批三艘尤里船自然驶抵并卸空")
			var infantry_ashore: Array = w.units.filter(func(u): return w.actor_alive(u) and u.unit_id == "INIT" and u.special.has("shift_plant") and u.embarked_in == null)
			check(infantry_ashore.size() == 9, "九名尤里新兵实际在岸上")
			if not all_landed or infantry_ashore.size() != 9:
				for boat in attack_boats:
					print("SOV01 VOYAGE pos=", boat.position / 55.0, " goal=", boat.move_target / 55.0, " passengers=", boat.logistics.passengers.size())
			tree.quit(failures)
			return
		m.tick(w,30)
		check(boats.call()==6,"第98秒三艘工程师船出发")
		var raiders: Array = w.units.filter(func(u): return w.actor_alive(u) and u.unit_id in ["INIT", "YENGINEER"] and u.special.has("shift_plant"))
		check(raiders.filter(func(u): return u.unit_id == "INIT").size() == 9 and raiders.filter(func(u): return u.unit_id == "YENGINEER").size() == 3, "原图三船九名尤里新兵、三船三名工程师均已装船")
		# Isolate landing and capture from the long sea crossing; the retail shore
		# and native unload/interaction logic remain unchanged.
		for boat in w.units.filter(func(u): return w.actor_alive(u) and u.unit_id == "YHVR"):
			var shore: Vector2 = boat.special.shift_raid
			boat.order_stop()
			boat.position = shore
			boat.special.erase("shift_raid_via")
			boat.special.shift_raid = shore
			boat.reset_physics_interpolation()
		m.Story.power_contest(w, s)
		var landed_inits := false
		var landed_engineers := false
		var captured := false
		for frame in 360:
			await tree.physics_frame
			if frame % 12 != 0: continue
			landed_inits = landed_inits or raiders.any(func(u): return w.actor_alive(u) and u.unit_id == "INIT" and u.embarked_in == null)
			landed_engineers = landed_engineers or raiders.any(func(u): return w.actor_alive(u) and u.unit_id == "YENGINEER" and u.embarked_in == null)
			captured = captured or w.buildings.any(func(b): return w.actor_alive(b) and b.building_id in m.POWER_PLANTS and b.special.get("yuri_power", false))
			if landed_inits and landed_engineers and captured: break
		check(landed_inits, "尤里新兵从第一批运输艇实际登岸")
		check(landed_engineers, "尤里工程师从第二批运输艇实际登岸")
		check(captured, "尤里工程师到达电厂并登记尤里归属")
		if not (landed_inits and landed_engineers and captured):
			for boat in w.units.filter(func(u): return w.actor_alive(u) and u.unit_id == "YHVR"):
				print("SOV01 RAID_DIAG pos=", boat.position / 55.0, " target=", boat.special.get("shift_raid", Vector2.INF) / 55.0, " passengers=", boat.logistics.passengers.size(), " unloading=", boat.logistics.unloading, " move=", boat.has_move_order)
		tree.quit(failures)
		return
	if "--power-ownership" in args:
		var plant = w.buildings.filter(func(b): return w.actor_alive(b) and b.building_id == "GAPOWRA")[0]
		var first = w.spawn_unit("YENGINEER", "enemy", plant.position)
		first.special.shift_plant = plant
		first.position = AlliedAbilities.approach(first, plant)
		m.Story.power_contest(w,s)
		check(plant.special.get("yuri_power", false) and not w.actor_alive(first), "首次进门后才登记尤里归属")
		var recapture = w.spawn_unit("SENGINEER", "ally", plant.position)
		recapture.position = AlliedAbilities.approach(recapture, plant)
		w.fog.rebuild()
		recapture.order_interaction("allied_engineer", plant, false)
		AlliedAbilities.tick_action(recapture, 1.0)
		check(plant.side == "ally" and not plant.special.has("yuri_power"), "苏军夺回后清除尤里归属")
		var second = w.spawn_unit("YENGINEER", "enemy", plant.position + Vector2(0, 400))
		second.special.shift_plant = plant
		m.Story.power_contest(w,s)
		check(second.special.get("action") == "allied_engineer" and not plant.special.has("yuri_power"), "抢占命令不会抢先登记归属")
		var codec = preload("res://scripts/save/battle_snapshot.gd").new()
		var snapshot = codec.capture(w)
		check(BattleSaves.validate(snapshot).is_empty(), "占领途中可保存")
		codec.restore(w, snapshot)
		s = w.allied_state.time_shift
		w.hud._toggle_pause()
		plant = w.buildings.filter(func(b): return w.actor_alive(b) and b.building_id == "GAPOWRA")[0]
		second = w.units.filter(func(u): return w.actor_alive(u) and u.unit_id == "YENGINEER" and u.special.get("shift_plant") == plant)[0]
		check(second.special.get("target") == plant and plant.side == "ally" and not plant.special.has("yuri_power"), "读档保留待完成命令而不改变归属")
		second.position = AlliedAbilities.approach(second, plant)
		AlliedAbilities.tick_action(second, 1.0)
		check(plant.side == "enemy" and plant.special.get("yuri_power", false) and not w.actor_alive(second), "读档后实际进门才登记尤里归属")
		tree.quit(failures)
		return
	if "--power-loss" in args:
		var incoming=m.FIELD.data.raids.filter(func(r):return r.group=="Reinforce_Cap Group 1")[0]
		m.Story.raid(w,incoming)
		var raiders=w.units.filter(func(u):return w.actor_alive(u) and u.unit_id=="YENGINEER" and u.special.has("shift_plant"))
		check(not raiders.is_empty() and raiders.back().embarked_in!=null,"尤里工程师乘原版运输艇争夺电厂")
		var spy=raiders.back()
		var objective=spy.special.shift_plant
		spy.embarked_in.logistics.passengers.erase(spy)
		spy.set_stowed(null)
		spy.position=AlliedAbilities.approach(spy,objective)
		m.Story.power_contest(w,s)
		check(objective.special.get("yuri_power",false),"尤里工程师进入盟军厂门转属")
		for b in w.buildings:
			if w.actor_alive(b) and b.building_id in ["GAPOWRA","GAPOWRB","GAPOWRC"]:b.receive_hit(100000)
		m.tick(w,1)
		check(w.ended,"发电厂剩余不足四座时失败")
		tree.quit(failures)
		return
	var plants=w.buildings.filter(func(b):return w.actor_alive(b) and b.building_id.begins_with("GAPOWR") and b.building_id.length()==7)
	check(plants.size()==6,"六座可占领发电厂")
	check(w.CampaignMarks.marks(w, false).size() == 6, "供电阶段仅标仍待占领的发电厂")
	for i in 4:
		check(w.hud.minimap.objective_marks().size()==6-i,"占领后撤下电厂标记")
		var plant=plants[i]
		var engineer=w.spawn_unit("SENGINEER","ally",plant.position+Vector2(110,0))
		engineer.position=AlliedAbilities.approach(engineer,plant)
		w.fog.rebuild()
		engineer.order_interaction("allied_engineer",plant,false)
		AlliedAbilities.tick_action(engineer,1.0)
		check(plant.side=="ally","工程师占领 "+plant.building_id)
	m.tick(w,1)
	check(s.has("crossing_era"),"时光机开始穿越")
	m.tick(w,0.7)
	if OS.has_environment("S01_VORTEX_PNG"):
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(OS.get_environment("S01_VORTEX_PNG"))
	check(w.has_node("TimeVortex") and s.phase==2,"原时代显示旋涡")
	check(w.hud.minimap.objective_marks().is_empty() and w.CampaignMarks.marks(w, false).is_empty(), "穿越过场清除任务标记")
	if "--write-crossings" in args: check(BattleSaves.save_slot(w,"slot1").ok,"保存第一次穿越过半前")
	m.tick(w,0.8)
	check(s.phase==3 and not w.has_node("HollywoodFilm"),"旋涡中切换时代")
	if "--write-crossings" in args: check(BattleSaves.save_slot(w,"slot2").ok,"保存第一次穿越过半后")
	m.tick(w,1.5)
	check(s.phase==3 and s.machine.building_id=="CATIME02","穿越至侏罗纪")
	if "--dino-contact" in OS.get_cmdline_user_args():
		w.get_node("HollywoodFilm").skip.pressed.emit()
		var entrances := {}
		var contacted := {}
		for frame in 4200:
			await tree.physics_frame
			if s.phase != 3: break
			for rex in w.units:
				if not w.actor_alive(rex) or rex.unit_id != "DNOA" or rex.side != "enemy": continue
				var id = rex.get_instance_id()
				if not entrances.has(id):
					entrances[id] = 69 if rex.position.distance_to(m.wp(69)) < rex.position.distance_to(m.wp(70)) else 70
				if not contacted.has(entrances[id]) and w.actor_visible_to("ally",rex) and rex.hp < rex.max_hp:
					contacted[entrances[id]] = s.timer
			if contacted.size() == 2: break
		for entrance in [69,70]:
			check(contacted.has(entrance),"入口 %s 的敌对霸王龙进入守军视野并受击，充能剩余 %s 秒" % [entrance,contacted.get(entrance,"未知")])
		tree.quit(failures)
		return
	if "--loss" in OS.get_cmdline_user_args():
		if w.has_node("HollywoodFilm"):w.get_node("HollywoodFilm").skip.pressed.emit()
		s.machine.receive_hit(100000)
		m.tick(w,1)
		check(w.ended,"侏罗纪时光机毁坏后任务失败")
		tree.quit(failures)
		return
	var codec=preload("res://scripts/save/battle_snapshot.gd").new()
	var saved:=BattleSaves.save_slot(w,"quick")
	check(saved.ok,"侏罗纪战场写入隔离测试槽 "+str(saved.get("message","")))
	var snap=codec.capture(w)
	check(BattleSaves.validate(snap)=="","跨时代存档 "+BattleSaves.validate(snap))
	if w.has_node("HollywoodFilm"):w.get_node("HollywoodFilm").skip.pressed.emit()
	await tree.process_frame
	codec.restore(w,snap)
	s=w.allied_state.time_shift
	w.hud._toggle_pause()
	check(w.hud.minimap.objective_marks()[0].position==s.machine.position and w.CampaignMarks.marks(w,false)[0].actor==s.machine,"读档后战场和雷达标记时光机")
	check(s.phase==3 and w.actor_alive(s.machine) and w.path_service.time_shift_area==m.BOUNDS[1],"恢复时光机引用及侏罗纪通行边界")
	m.tick(w,11)
	check(w.units.any(func(u):return w.actor_alive(u) and u.side=="enemy" and u.unit_id=="DNOA"),"敌对霸王龙增援")
	
	m.tick(w,125)
	check(s.has("crossing_era"),"时光机开始穿越")
	m.tick(w,0.7)
	check(w.has_node("TimeVortex") and s.phase==3,"原时代显示旋涡")
	if "--write-crossings" in args: check(BattleSaves.save_slot(w,"slot3").ok,"保存第二次穿越过半前")
	m.tick(w,0.8)
	check(s.phase==4 and not w.has_node("HollywoodFilm"),"旋涡中切换时代")
	if "--write-crossings" in args:
		s.dominator.hp = s.dominator.max_hp * 0.5
		check(BattleSaves.save_slot(w,"auto").ok,"保存第二次穿越过半后及建筑伤害")
	m.tick(w,1.5)
	check(s.phase==4 and w.actor_alive(s.dominator),"返回旧金山")
	if w.has_node("HollywoodFilm"):w.get_node("HollywoodFilm").skip.pressed.emit()
	if OS.has_environment("S01_SCREEN_DIR"):
		w.center_on(Vector2(91.5,51.5)*55)
		w.fog.hide()
		for b in w.buildings:
			if w.actor_alive(b) and b.building_id in m.Story.BRIDGE:b.show()
		for frame in 4:await tree.process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(OS.get_environment("S01_SCREEN_DIR")+"/bridge.png")
	check(w.hud.minimap.objective_marks()[0].position==m.wp(104) and w.CampaignMarks.marks(w,false)[0].position==m.wp(104),"返回时两处均只标待接管基地")
	var trigger:Array=m.FIELD.data.base_contact[0]
	var scout=w.units.filter(func(u):return w.actor_alive(u) and u.side=="ally" and u.unit_id=="BORIS")[0]
	scout.position=(Vector2(trigger[0],trigger[1])+Vector2.ONE*0.5)*55
	m.tick(w,1)
	check(s.get("base_found",false) and w._player_hq()!=null,"进入原版格子接管苏军基地")
	check(w.hud.minimap.objective_marks()[0].position==s.dominator.position and w.CampaignMarks.marks(w,false)[0].actor==s.dominator,"接管后两处均改标恶魔岛目标")
	var bridge=w.buildings.filter(func(b):return w.actor_alive(b) and b.building_id=="CASANF04")[0]
	bridge.receive_hit(100000)
	m.tick(w,1)
	check(s.get("bridge_fallen",false) and not world_bridge_ids(w).has("CASANF14"),"金门大桥指定桥段受毁后连锁坍塌")
	if "--airstrike" in OS.get_cmdline_user_args():
		var target=s.dominator
		scout.position=target.position+Vector2(130,150)
		w.fog.rebuild()
		scout.order_target(target,false,false)
		for frame in 2500:
			await tree.physics_frame
			if w.ended:break
		check(w.ended,"鲍里斯指示目标后由正式空袭摧毁控制器")
	else:
		s.dominator.receive_hit(100000)
		m.tick(w,1)
	check(w.ended,"摧毁心灵控制器结算")
	tree.quit(failures)

func world_bridge_ids(w) -> Array:
	return w.buildings.filter(func(b):return w.actor_alive(b) and b.building_id in w.TimeShift.Story.BRIDGE).map(func(b):return b.building_id)

func portrait(w,tree) -> void:
	tree.paused=true
	w.hud.hide()
	w.fog.hide()
	var originals:Array=[]
	for u in w.units+w.buildings:
		if w.actor_alive(u) and u.visible:originals.append(u);u.hide()
	var cam:Camera2D=w.camera
	var old_pos:=cam.position
	var old_zoom:=cam.zoom
	cam.position=w.TimeShift.wp(18)
	cam.zoom=Vector2(1.25,0.625)
	cam.force_update_scroll()
	var models:Array=[]
	var ids:=["COP","BUS","CBLC","CRUISE","TUG","DNOB","DNOA"]
	var points:=[Vector2(250,320),Vector2(600,320),Vector2(950,320),Vector2(1300,320),Vector2(390,640),Vector2(800,640),Vector2(1210,640)]
	var overlay:=CanvasLayer.new()
	overlay.layer=55
	add_child(overlay)
	for i in ids.size():
		var actor=w.spawn_unit(ids[i],"neutral",get_viewport().get_canvas_transform().affine_inverse()*points[i])
		actor.order_stop();actor.show();actor.hull_angle=0.1;actor.turret_angle=0.1;actor.aim_dir=Vector2.from_angle(0.1);actor.queue_redraw()
		models.append(actor)
		var label:=Label.new()
		label.text=["警车","校车","有轨电车","游轮","拖船","雷龙","霸王龙"][i]
		label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		label.position=points[i]+Vector2(-120,32)
		label.size=Vector2(240,46)
		label.add_theme_font_size_override("font_size",24)
		label.add_theme_constant_override("outline_size",5)
		overlay.add_child(label)
	for i in 5:await tree.process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_environment("S01_SCREEN_DIR")+"/city-wildlife.png")
	for actor in models:AlliedAbilities.consume(actor)
	overlay.queue_free()
	for actor in originals:
		if w.actor_alive(actor):actor.show()
	cam.position=old_pos;cam.zoom=old_zoom;cam.force_update_scroll()
	w.hud.show();w.fog.show();tree.paused=false
