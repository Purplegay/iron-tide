extends Node

var failures := 0
var checks := 0

func expect(ok: bool, title: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("ALLIED01 ",ok," ",title)

func button(root: Node, text: String) -> Button:
	for b in root.find_children("*","Button",true,false):
		if b.text==text: return b
	return null

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	get_tree().create_timer(175).timeout.connect(func(): get_tree().quit(2))
	call_deferred("run")

func run() -> void:
	var tree := get_tree()
	tree.current_scene=null
	if "--last-cold" in OS.get_cmdline_user_args():
		var loaded:=BattleSaves.load_into_scene("quick")
		expect(loaded.ok,"从独立进程读取换场后存档")
		if loaded.ok:
			await tree.scene_changed
			var w=tree.current_scene.battle
			if w.paused: tree.current_scene.hud._toggle_pause()
			preload("res://tests/allied_first_closing.gd").cold(self,w)
		finish()
		return
	if "--cold-map65" in OS.get_cmdline_user_args():
		var result:=BattleSaves.load_into_scene("quick")
		expect(result.ok,"读取首关运输途中断点")
		if result.ok:
			await tree.scene_changed
			var w=tree.current_scene.battle
			if w.paused: tree.current_scene.hud._toggle_pause()
			preload("res://tests/allied_first_map65.gd").cold(self,w)
		finish()
		return
	if "--cold-map50" in OS.get_cmdline_user_args():
		var saved:=BattleSaves.load_into_scene("quick")
		expect(saved.ok,"独立进程读取首关驻军与声源："+str(saved.get("message","")))
		if saved.ok:
			await tree.scene_changed
			var w=tree.current_scene.battle
			if w.paused: tree.current_scene.hud._toggle_pause()
			preload("res://tests/allied_first_map50.gd").cold(self,w)
		finish()
		return
	if "--cold-map40" in OS.get_cmdline_user_args():
		var saved := BattleSaves.load_into_scene("quick")
		expect(saved.ok,"独立进程读取城区小队存档："+str(saved.get("message","")))
		if saved.ok:
			await tree.scene_changed
			var w=tree.current_scene.battle
			if w.paused: tree.current_scene.hud._toggle_pause()
			w.AlliedFirst.tick(w,0.3)
			preload("res://tests/allied_first_map40.gd").verify(self,w)
		finish()
		return
	if "--cold-map30" in OS.get_cmdline_user_args():
		var loaded := BattleSaves.load_into_scene("quick")
		expect(loaded.ok,"读取地图小队断点")
		if loaded.ok:
			await tree.scene_changed
			var w = tree.current_scene.battle
			if w.paused: tree.current_scene.hud._toggle_pause()
			preload("res://tests/allied_first_map30.gd").cold(self,w)
		finish()
		return
	if "--slot3-color" in OS.get_cmdline_user_args():
		var loaded := BattleSaves.load_into_scene("slot3")
		expect(loaded.ok,"冷读玩家手动存档 3 的隔离副本："+str(loaded.get("message","")))
		if not loaded.ok: finish(); return
		await tree.scene_changed
		var restored = tree.current_scene.battle
		expect(restored.mission.get("id")=="yr_allied_first","副本确为美国首关")
		var claimed := 0
		var neutral := 0
		for b in restored.buildings:
			if not restored.actor_alive(b) or not b.building_id.begins_with("CAPOWR0"): continue
			print("CAPOWR ",b.building_id," ",b.side," ",b._col)
			if b.side == "ally":
				claimed += 1
				expect(b._col.is_equal_approx(HouseColor.player_color()),"占领电厂按玩家房色恢复："+b.building_id)
				var art: Dictionary = b._ra2
				expect(not art.get("detail",{}).is_empty(),"实际战场加载电厂双倍细节页")
				var image := (art.tex as Texture2D).get_image()
				var found := false
				for y in range(120):
					for x in range(190):
						if image.get_pixel(x,y).is_equal_approx(Color(HouseColor.BASE_HEX)): found = true; break
					if found: break
				expect(found,"占领电厂的实际贴图已使用房色基准像素")
			elif b.side == "neutral":
				neutral += 1
				expect(b.material is ShaderMaterial and b._col.is_equal_approx(Color(131.0/255,131.0/255,131.0/255)),"未占领电厂使用灰色房色："+b.building_id)
		expect(claimed>0 and neutral>0,"存档保留两种归属：%d 已占领，%d 未占领" % [claimed,neutral])
		finish()
		return
	if "--cold-ai-queue" in OS.get_cmdline_user_args() or "--cold-bridge-chain" in OS.get_cmdline_user_args():
		var loaded := BattleSaves.load_into_scene("slot2")
		expect(loaded.ok,"独立进程读取专项断点")
		if not loaded.ok: finish(); return
		await tree.scene_changed
		var w = tree.current_scene.battle
		w.set_process(false)
		w.set_physics_process(false)
		if w.paused: tree.current_scene.hud._toggle_pause()
		preload("res://tests/allied_first_field_audit.gd").cold(self,w,"--cold-ai-queue" in OS.get_cmdline_user_args())
		finish()
		return
	if "--cold-flak" in OS.get_cmdline_user_args():
		var loaded := BattleSaves.load_into_scene("slot2")
		expect(loaded.ok,"独立进程读取防空队在产断点")
		if not loaded.ok: finish(); return
		await tree.scene_changed
		var w = tree.current_scene.battle
		w.set_process(false)
		w.set_physics_process(false)
		if w.paused: tree.current_scene.hud._toggle_pause()
		await preload("res://tests/allied_first_flak.gd").resume(self,w)
		finish()
		return
	if "--cold-legacy-charge" in OS.get_cmdline_user_args():
		var loaded := BattleSaves.load_into_scene("quick")
		expect(loaded.ok,"独立进程读取旧版充能末段存档")
		if not loaded.ok: finish(); return
		await tree.scene_changed
		var w = tree.current_scene.battle
		w.set_process(false)
		w.set_physics_process(false)
		if w.paused: tree.current_scene.hud._toggle_pause()
		var state: Dictionary = w.allied_state.allied_first
		w.AlliedFirst.tick(w,0.0)
		expect(is_equal_approx(float(state.charge),4.0) and state.power_camera_lock and not w.has_node("HollywoodFilm"),"按旧档剩余四秒恢复锁控和并行进度，无重播")
		w.AlliedFirst.tick(w,3.0)
		expect(state.phase==2 and is_equal_approx(float(state.charge),1.0),"旧档继续按剩余时间充能")
		w.AlliedFirst.tick(w,1.0)
		expect(state.phase==3 and w.has_node("TimeVortex"),"旧档在原剩余期限进入穿越")
		finish()
		return
	if "--cold-power-sequence" in OS.get_cmdline_user_args() or "--cold-pairs54" in OS.get_cmdline_user_args():
		var loaded := BattleSaves.load_into_scene("quick")
		expect(loaded.ok,"独立进程读取任务表隔离档")
		if not loaded.ok: finish(); return
		await tree.scene_changed
		var w = tree.current_scene.battle
		w.set_process(false)
		w.set_physics_process(false)
		if w.paused: tree.current_scene.hud._toggle_pause()
		var state: Dictionary = w.allied_state.allied_first
		w.AlliedFirst.tick(w,0.0)
		if "--cold-pairs54" in OS.get_cmdline_user_args():
			expect(state.plant_pair_driver_initialized and state.plant_reveals.get("87",false),"54 条旧档恢复已占配对")
			expect(not state.retail_power_loss.enabled.has("0baad3fc") and state.plant_external_links=={"unported":true},"毁损厂的禁用已消费，未接链接仍保留")
			var pings: Array = []
			Events.radar_ping.connect(func(at: Vector2,_kind: String):
				if at.is_equal_approx(w.AlliedFirst.wp(87)): pings.append(at))
			w.AlliedFirst.tick(w,1.0)
			w.AlliedFirst.tick(w,2.0)
			expect(state.plant_last_ping=="CJ" and pings.size()==1 and not state.retail_power_loss.enabled.has("0baad3fc"),"冷读后只发一次提醒，已毁厂不重新启用")
		else:
			var sequence: Dictionary = state.retail_power_sequence
			print("POWER_RECOVERY left=",state.charge," online=",state.get("power_online_at")," time=",sequence.time," enabled=",sequence.enabled)
			expect(sequence.fired.has("0a8ea21c") and not sequence.fired.has("0c6f847c") and is_equal_approx(float(state.charge),12.0),"冷读保留两条并行分支起点")
			w.AlliedFirst.tick(w,7.0)
			expect(state.power_camera_lock and not w.world_input_enabled() and sequence.fired.has("0c6f847c") and state.phase==2 and is_equal_approx(float(state.charge),5.0),"镜头到期时穿越仍剩五秒")
			w.AlliedFirst.tick(w,5.0)
			expect(sequence.fired.has("0a8e0e9c") and state.phase==3 and w.has_node("TimeVortex"),"独立进程续到原图穿越动作")
			w.AlliedFirst.tick(w,4.0)
			expect(state.crossing_swapped and not state.has("machine_death_era") and not w.ended,"正常换场移除不触发毁机")
		finish()
		return
	if "--cold-plant-driver" in OS.get_cmdline_user_args():
		var loaded := BattleSaves.load_into_scene("quick")
		expect(loaded.ok,"独立进程冷读逐厂触发档")
		if not loaded.ok: finish(); return
		await tree.scene_changed
		var w = tree.current_scene.battle
		var state: Dictionary = w.allied_state.allied_first
		expect(state.destroyed_plants.size()==4 and state.retail_power_loss.locals.get("29",false),"保留四座损失和普通难度变量链")
		if w.paused: tree.current_scene.hud._toggle_pause()
		var plant = w.AlliedFirst.site(w,"CAPOWR05")
		if plant!=null: plant.receive_hit(plant.max_hp*10.0,"explosive")
		w.AlliedFirst.tick(w,0.0)
		expect(w.ended and state.get("failure_trigger")=="06178D0C","冷读后第五座损失触发判负")
		finish()
		return
	if "--cold-victory-driver" in OS.get_cmdline_user_args():
		var loaded := BattleSaves.load_into_scene("quick")
		expect(loaded.ok,"读取庆祝后的驱动存档")
		if not loaded.ok: finish(); return
		await tree.scene_changed
		var w = tree.current_scene.battle
		var state: Dictionary = w.allied_state.allied_first
		var saved_driver: Dictionary = state.get("retail_victory",{})
		expect(state.phase==5 and saved_driver.get("fired",{}).has("089ecdec"),"冷读保留已执行庆祝与结算阶段")
		if w.paused: tree.current_scene.hud._toggle_pause()
		w.AlliedFirst.tick(w,6.0)
		expect(not w.ended,"总计九秒未提前结算")
		w.AlliedFirst.tick(w,1.0)
		expect(w.ended and state.retail_victory.fired.has("089ec79c") and state.retail_victory.serial==3,"总计十秒结算且庆祝不重复")
		finish()
		return
	if "--cold-offmap-yard" in OS.get_cmdline_user_args():
		var loaded := BattleSaves.load_into_scene("quick")
		expect(loaded.ok,"独立进程读取场外转属后的存档")
		if not loaded.ok: finish(); return
		await tree.scene_changed
		var w = tree.current_scene.battle
		var state: Dictionary = w.allied_state.allied_first
		var dom = w.AlliedFirst.site(w,"YAPPPT")
		expect(dom!=null and state.get("offmap_yard_room")=="BridgeHouse" and not state.get("confederation_production",true),"控制器存活，场外转属与关停状态保留")
		w.AlliedFirst.sync_offmap_yard(state,dom)
		expect(state.get("offmap_yard_room")=="BridgeHouse" and not w.ended,"重复检查不改归属、不触发结算")
		finish()
		return
	if "--cold-island-walls" in OS.get_cmdline_user_args():
		var loaded := BattleSaves.load_into_scene("quick")
		expect(loaded.ok,"围栏存档可冷读")
		if not loaded.ok: finish(); return
		await tree.scene_changed
		await tree.process_frame
		var w = tree.current_scene.battle
		expect(w.buildings.filter(func(b):return w.actor_alive(b) and b.special.get("allied_first_overlay",false)).size()==191,"冷读不重复生成围栏")
		finish()
		return
	if "--cold-hospital" in OS.get_cmdline_user_args():
		var loaded := BattleSaves.load_into_scene("quick")
		expect(loaded.ok,"独立进程读取医院存档")
		if not loaded.ok: finish(); return
		await tree.scene_changed
		var w = tree.current_scene.battle
		var hospital = w.AlliedFirst.site(w,"CATHOSP")
		expect(hospital!=null and hospital.side=="ally" and w.allied_state.allied_first.get("hospital_found",false),"恢复归属与发现状态")
		finish()
		return
	if "--cold-followup" in OS.get_cmdline_user_args():
		var loaded := BattleSaves.load_into_scene("quick")
		expect(loaded.ok,"独立进程读取后续舰队途中存档")
		if not loaded.ok: finish(); return
		await tree.scene_changed
		var w = tree.current_scene.battle
		var state: Dictionary = w.allied_state.allied_first
		w.AlliedFirst.deploy_followup_fleet(w,state)
		expect(w.units.filter(func(u):return w.actor_alive(u) and u.unit_id=="DRED").size()==7,"冷读和重复调用不重复生成无畏舰")
		expect(w.units.filter(func(u):return w.actor_alive(u) and u.unit_id=="HYD" and u.special.has("allied_first_patrol_step")).size()==6,"海蝎巡逻状态保留")
		expect(w.units.filter(func(u):return w.actor_alive(u) and u.side=="neutral" and u.unit_id in ["CRUISE","TUG"]).size()==3,"冷读保留三艘平民船")
		finish()
		return
	if "--cold-dread" in OS.get_cmdline_user_args():
		var loaded := BattleSaves.load_into_scene("quick")
		expect(loaded.ok,"独立进程冷读舰队途中存档")
		if not loaded.ok: finish(); return
		await tree.scene_changed
		var w = tree.current_scene.battle
		var fleet: Array = w.units.filter(func(u):return w.actor_alive(u) and u.unit_id=="DRED" and u.special.get("allied_first_team")=="0956959C")
		expect(fleet.size()==1,"冷读没有重复生成 KD")
		if not fleet.is_empty():
			var ship = fleet[0]
			expect(ship.special.get("allied_first_dread_step")==1 and ship.move_target.is_equal_approx(w.AlliedFirst.wp(127)),"保留已完成炮击和正在执行的水路航点")
			var origin: Vector2 = ship.position
			if w.paused: tree.current_scene.hud._toggle_pause()
			for i in range(240):
				if not w.actor_alive(ship) or ship.position.distance_to(origin)>60.0: break
				await tree.physics_frame
			expect(w.actor_alive(ship) and ship.position.distance_to(origin)>60.0,"继续后实际航行")
		finish()
		return
	if "--cold-crossing" in OS.get_cmdline_user_args():
		var loaded := BattleSaves.load_into_scene("slot3" if "--after-midpoint" in OS.get_cmdline_user_args() else "slot1")
		expect(loaded.ok,"独立进程读取穿越中存档")
		if not loaded.ok: finish(); return
		await tree.scene_changed
		await tree.process_frame
		var w = tree.current_scene.battle
		var state: Dictionary = w.allied_state.allied_first
		expect(state.phase==3 and w.has_node("TimeVortex"),"穿越视觉和阶段一同恢复")
		expect(bool(state.get("crossing_swapped",false))==("--after-midpoint" in OS.get_cmdline_user_args()),"冷读保留半程交换标记")
		expect(not w.world_input_enabled() and w.hud.minimap.campaign_radar_offline(),"穿越冷读仍锁指令和雷达")
		if w.paused: tree.current_scene.hud._toggle_pause()
		w.AlliedFirst.tick(w,6.0)
		await tree.process_frame
		expect(state.retail_power_sequence.fired.has("05e9106c") and state.past_report and w.get_node_or_null("HollywoodFilm")!=null,"换场断点读档续播抵达通讯")
		expect(w.buildings.filter(func(b):return w.actor_alive(b) and b.building_id=="NANRCT").size()==1,"换场恢复只保留一座完好或重建的反应堆")
		expect(state.get("awaiting_tanya",false) and not w.units.any(func(u):return w.actor_alive(u) and u.special.get("allied_first_tanya",false)),"续演恢复装甲阶段，未提前生成谭雅")
		expect(w.buildings.filter(func(b):return w.actor_alive(b) and b.special.get("allied_first_dominator",false)).size()==1,"续演仅生成一座过去的控制器")
		if "--retail24" in OS.get_cmdline_user_args():
			expect(state.retail_dominator.fired.has("0951879c") and state.retail_dominator.fired.has("0b8a090c") and w.AlliedFirst.present_controller(w)==null,"穿越中点冷读保留售卖并完成一次重建")
		var expected_apocs := 2 if int(BattleRequest.skirmish_config.get("difficulty",1))==0 else 4
		expect(w.units.filter(func(u):return w.actor_alive(u) and u.unit_id=="APOC" and u.special.get("allied_first_room")=="Special").size()==expected_apocs,"穿越冷读不会重复增援天启坦克")
		finish()
		return
	var reported_slot := "--reported-slot2" in OS.get_cmdline_user_args()
	if reported_slot or "--cold" in OS.get_cmdline_user_args():
		# The reported-slot run must use an isolated APPDATA with a copy of slot 2.
		var loaded := BattleSaves.load_into_scene("slot2" if reported_slot else "quick")
		expect(loaded.ok,"独立进程冷读："+str(loaded.get("message","")))
		if not loaded.ok: finish(); return
		await tree.scene_changed
		var restored = tree.current_scene.battle
		expect(restored.allied_state.get("allied_first",{}).get("phase")==2,"保留供电阶段")
		var grid: Dictionary = restored._side_power("ally")
		var captured: int = restored.buildings.filter(func(b):return b.side=="ally" and b.building_id.begins_with("CAPOWR0")).size()
		print("ALLIED01 restored plants=",captured," power=",grid)
		expect(not grid.low and captured==(8 if reported_slot else 5),"保留已转属电厂及供电")
		if reported_slot:
			var radar = restored.AlliedFirst.site(restored,"GASPYSAT")
			expect(grid.produced==1600 and radar!=null and radar.power==-1 and not SupportSystems.satellite(radar),"旧档保留电厂产量并恢复雷达规则")
		await tree.process_frame
		expect("保护时光机" in tree.current_scene.hud.wave_label.text,"旧供电档显示防守目标")
		expect(restored.get_node_or_null("HollywoodFilm")==null and not restored.ended,"读档不重播影片、不强制结算")
		if reported_slot:
			if restored.paused: tree.current_scene.hud._toggle_pause()
			if "--live-slot2" in OS.get_cmdline_user_args(): await check_live_slot2(restored)
			else: await check_mainline(restored)
		finish()
		return
	tree.change_scene_to_file("res://scenes/main.tscn")
	await tree.scene_changed
	button(tree.current_scene,"战 役").pressed.emit()
	await tree.scene_changed
	button(tree.current_scene,"盟军战役").pressed.emit()
	var entry := button(tree.current_scene,"时间流逝")
	expect(entry!=null,"战役菜单列出美国首关")
	if entry==null: finish(); return
	entry.pressed.emit()
	var extended := "--extended" in OS.get_cmdline_user_args()
	button(tree.current_scene,"带入我的养成" if extended else "原版配置").pressed.emit()
	if "--power-loss" in OS.get_cmdline_user_args() or "--easy" in OS.get_cmdline_user_args() or "--hard" in OS.get_cmdline_user_args():
		tree.current_scene.set_difficulty(0 if "--easy" in OS.get_cmdline_user_args() else (2 if "--hard" in OS.get_cmdline_user_args() else 1))
	button(tree.current_scene,"出击").pressed.emit()
	await tree.scene_changed
	var world = tree.current_scene.battle
	world.set_process(false)
	world.set_physics_process(false)
	var s: Dictionary = world.allied_state.get("allied_first",{})
	expect(world.map_layout()=="yr_all01umd" and not s.is_empty(),"实际装配零售首关地图")
	if s.is_empty(): finish(); return
	if "--retail-transition" in OS.get_cmdline_user_args(): check_opening_site_health(world)
	expect(BattleRequest.extensions_enabled()==extended,"实际进入所选规则模式")
	if "--field-audit" in OS.get_cmdline_user_args():
		preload("res://tests/allied_first_field_audit.gd").field(self,world)
	var home: Vector2 = world.player_start()
	expect(world.fog.is_visible_at("ally",home),"开场暂停前已刷新镜头落点迷雾")
	var cell := Vector2i(home/float(world.fog.CELL))
	expect(world.fog.mask_image.get_pixelv(cell).a < 0.1,"首帧绘制用的迷雾遮罩已打开基地")
	var natural := "--natural" in OS.get_cmdline_user_args()
	var eva_before := Ra2Sfx.a_eva_plays
	var intro = world.get_node_or_null("HollywoodFilm")
	expect(intro!=null and intro.clip_id=="A01_F00E" and tree.paused,"挂载零售片头及暂停")
	if intro!=null:
		expect("情况不妙" in intro.subtitle.text,"全屏片头首次显示中文对白")
		intro.skip.pressed.emit()
	await tree.process_frame
	await tree.process_frame
	var radio = world.get_node_or_null("HollywoodFilm")
	expect(radio!=null and radio.clip_id=="A01_P01E" and radio.mission_audio!=null and tree.paused,"片头后播放雷达图像与独立简报原声，简报期间战场暂停")
	expect("战前简报" in tree.current_scene.hud.wave_label.text and not world.world_input_enabled(),"雷达简报期间显示当前锁控原因，不提前提示可下令")
	if radio!=null:
		if natural:
			expect(not radio.subtitle.text.is_empty(),"雷达简报开始即有中文字幕")
			var first_caption: String = radio.subtitle.text
			await tree.create_timer(6.0,true,false,true).timeout
			expect(is_instance_valid(radio) and radio.hold_radio_frame and radio.mission_audio.get_playback_position()>0.0,"短片自然结束，原声音轨继续推进")
			expect(is_instance_valid(radio) and not radio.subtitle.text.is_empty() and radio.subtitle.text!=first_caption,"小窗定格后底部字幕继续随原声切换")
			for i in range(40):
				if s.phase == 1: break
				await tree.create_timer(0.5).timeout
		elif "--timeout" in OS.get_cmdline_user_args():
			radio.opening_radio_deadline_ms = Time.get_ticks_msec()
			radio._process(0.0)
			expect(s.phase == 1 and not tree.paused,"音频结束信号缺失时超时交还控制")
		else:
			radio._video_finished()
			expect(radio.hold_radio_frame,"短片结束仍保留续音画面")
			radio.skip.pressed.emit()
	await tree.process_frame
	expect(s.phase==1 and not tree.paused,"雷达简报结束后交还控制")
	var hud = tree.current_scene.hud
	expect(Ra2Sfx.a_eva_plays>eva_before and is_instance_valid(hud.field_radio),"开局原版 EVA 进入播放并显示伊娃的中文指令")
	expect(hud.mission_objectives != null and "0/8" in hud.mission_objectives.text and ("需求" in hud.timer_label.text or (s.get("assault_input_locked",false) and "标记完成" in hud.timer_label.text)),"HUD 说明当前镜头锁控，情报仍显示实际占领和供电进度")
	var plants: Array = world.buildings.filter(func(b):return b.building_id.begins_with("CAPOWR0"))
	expect(plants.size()==8 and plants.all(func(b):return b.side=="neutral"),"八座原图独立任务电厂")
	expect(world.buildings.filter(func(b):return b.building_id=="GTGCAN" and b.side=="ally").size()==4,"四门盟军巨炮")
	expect(world.buildings.any(func(b):return b.building_id=="CATIME01" and b.side=="ally"),"时光机开场为己方")
	expect(world.CampaignMarks.marks(world,true).size()==8,"八座任务电厂可定位")
	expect(not GameData.mission_tech_block_reason("TANY").is_empty() and not GameData.mission_tech_block_reason("GTGCAN").is_empty() and GameData.mission_tech_block_reason("ENGINEER").is_empty(),"3级科技封锁保留工程师")
	expect(plants.size()==8 and plants.all(func(b):return not b._ra2.is_empty()),"八座电厂加载原图 SHP")
	if "--retail-sites" in OS.get_cmdline_user_args():
		var radar = world.AlliedFirst.site(world,"GASPYSAT")
		var gun = world.AlliedFirst.site(world,"GTGCAN")
		expect(radar!=null and radar.power==-1 and not SupportSystems.satellite(radar),"原图雷达耗电1且不会全图开雾")
		expect(gun!=null and gun.max_hp==2000 and gun.weapon.damage==150 and gun.attack_range==1650 and gun.weapon.min_range==165,"四门巨炮使用零售属性和射界")
		var tank = world.spawn_unit("HTNK","enemy",world.player_start()+Vector2(150,0))
		tank.special.allied_first_room = "Soviet2House"
		tank.refresh_house_color()
		expect(tank._col.is_equal_approx(Color.from_hsv(0,230.0/255,1)),"苏军脚本房色为红，不沿用敌方统一色")
		tank.special.allied_first_room = "YuriCountry"
		tank.refresh_house_color()
		expect(tank._col.is_equal_approx(Color.from_hsv(201.0/255,201.0/255,189.0/255)),"尤里脚本房色为紫")
		finish()
		return
	if "--island-walls" in OS.get_cmdline_user_args():
		var walls: Array = world.buildings.filter(func(b):return world.actor_alive(b) and b.special.get("allied_first_overlay",false))
		expect(walls.size()==191,"全图载入 99 铁丝网、67 围墙、25 黑色围栏")
		var island := walls.filter(func(b):return b.building_id=="CAFNCP" and Rect2(84,26,7,7).has_point(b.position/55.0))
		expect(island.size()==23 and island.all(func(b):return WallArt.supported(b.data,b._ra2)),"控制器周界实际载入 23 格可连接铁丝网")
		var entrance := Vector2(84.5,29.5)*55.0
		expect(not island.any(func(b):return b.position==entrance),"保留原图入口格")
		var path: PackedVector2Array = world.path_service.find_path(Vector2(83.5,29.5)*55.0,Vector2(85.5,29.5)*55.0,false)
		expect(path.size()>1 and path[-1].distance_to(Vector2(85.5,29.5)*55.0)<40.0,"围栏入口保留寻路")
		var saved := BattleSaves.save_slot(world,"quick")
		expect(saved.ok,"围栏真实写档："+str(saved.get("message","")))
		finish()
		return
	if "--last-pre" in OS.get_cmdline_user_args():
		preload("res://tests/allied_first_closing.gd").opening(self,world,s)
		finish()
		return
	if "--map65" in OS.get_cmdline_user_args():
		await preload("res://tests/allied_first_map65.gd").run(self,world,s)
		finish()
		return
	if "--map50-rescue" in OS.get_cmdline_user_args(): world.AlliedFirst.tick_opening_ggi(world,s,91.0)
	if "--map50-rescue" in OS.get_cmdline_user_args():
		await preload("res://tests/allied_first_map50.gd").rescue(self,world,s)
		finish()
		return
	if "--map50-open" in OS.get_cmdline_user_args():
		world.AlliedFirst.tick(world,0.0)
		preload("res://tests/allied_first_map50.gd").opening(self,world,s,false)
		finish()
		return
	if "--map50-isolated" in OS.get_cmdline_user_args():
		preload("res://tests/allied_first_map50.gd").opening(self,world,s,true)
		finish()
		return
	if "--map40-guards" in OS.get_cmdline_user_args():
		preload("res://tests/allied_first_map40.gd").guards(self,world,s)
		finish()
		return
	if "--map30" in OS.get_cmdline_user_args():
		await preload("res://tests/allied_first_map30.gd").run(self,world,s,plants)
		finish()
		return
	if "--ggi-intro" in OS.get_cmdline_user_args():
		world.AlliedFirst.tick_opening_ggi(world,s,66.0-float(s.retail_assault.time))
		expect(s.get("ggi_intro_shown",false) and not s.has("ggi_intro_left"),"真实开局接入重装大兵提示并只触发一次")
		expect(ResourceLoader.exists("res://assets/ra2/allied_first/cevau75.wav"),"零售重装大兵原声已导入")
		var bait: Array = world.units.filter(func(u):return world.actor_alive(u) and u.special.get("allied_first_team")=="0BF1048C")
		expect(bait.size()==2 and bait.all(func(u): return u.move_target.is_equal_approx(world.AlliedFirst.wp(22))),"两辆原图诱饵坦克接到真实行军命令")
		world.AlliedFirst.tick_opening_ggi(world,s,4.0)
		expect(not s.get("ggi_attack_sent",false),"接战队不提前生成")
		world.AlliedFirst.tick_opening_ggi(world,s,1.0)
		world.AlliedFirst.tick_opening_ggi(world,s,5.0)
		expect(world.units.filter(func(u):return world.actor_alive(u) and u.special.get("allied_first_team")=="09F3BC1C").size()==5,"开场接战只发一队五名尤里新兵")
		finish()
		return
	# Reach Return_Control before issuing player orders in the post-briefing fixtures.
	if s.get("map_assault_rows",false): world.AlliedFirst.tick_opening_ggi(world,s,maxf(0.0,91.0-float(s.retail_assault.time)))
	# The following engineer fixture teleports to the door. Let the map's one-second
	# initial ownership and enable actions finish before simulating that journey.
	var plant_clock: float = s.get("retail_power_loss",{}).get("time",0.0)
	if plant_clock<1.0: world.AlliedFirst.tick(world,1.0-plant_clock+0.00001)
	var orders = preload("res://scripts/units/allied_abilities.gd")
	var engineer = world.units.filter(func(u):return world.actor_alive(u) and u.unit_id=="ENGINEER" and u.side=="ally").front()
	if "--barrels" in OS.get_cmdline_user_args() or "--boris-barrel" in OS.get_cmdline_user_args() or "--boris-barrel-elite" in OS.get_cmdline_user_args():
		var elite := "--boris-barrel-elite" in OS.get_cmdline_user_args()
		var boris := elite or "--boris-barrel" in OS.get_cmdline_user_args()
		var barrels: Array = world.buildings.filter(func(b):return world.actor_alive(b) and b.is_explosive_barrel())
		expect(barrels.size()==2 and barrels.all(func(b):return b.side=="neutral" and b.max_hp==5),"原图单桶和桶堆均为可损毁的中立物件")
		if barrels.size()!=2: finish(); return
		var target_id := "CAMISC02" if elite else "CAMISC01"
		var barrel = barrels.filter(func(b):return b.building_id==target_id).front()
		var nearby = barrels.filter(func(b):return b!=barrel).front()
		var shooter = world.spawn_unit("BORIS" if boris else "MTNK","ally",barrel.position+Vector2(260 if boris else 110,0))
		if elite: shooter._grant_veteran(2,false)
		shooter.fire_stance="none"
		world.center_on(barrel.position)
		world.fog.rebuild()
		await tree.process_frame
		await tree.process_frame
		var pick := Vector2.INF
		for y in range(-32,33,3):
			for x in range(-32,33,3):
				var p: Vector2 = barrel.art_center()+Vector2(x,y)
				if world._pick_enemy_at(p)==barrel: pick=p; break
			if pick.is_finite(): break
		expect(pick.is_finite(),"右键拾取真正命中可见油桶")
		if not pick.is_finite(): finish(); return
		world.clear_selection()
		world.select_unit(shooter,false)
		if boris:
			expect(world.command_cursor.attack_cursor(barrel)=="attack","油桶显示普通攻击指针而非米格空袭")
			expect(shooter._weapon_for_target(barrel).name==("AKME" if elite else "AKM"),"按军衔选择步枪")
			Unit.SovietSpecials.set_airstrike_reload(shooter,60.0)
		world._issue_order(pick)
		expect(shooter.attack_ordered and shooter.attack_target==barrel,"普通右键下达对油桶的攻击命令")
		if boris: expect(shooter.command_voice_kind("attack")=="attack","油桶使用步枪攻击语音")
		var hp: float = shooter.hp
		var called := false
		var chip := false
		for i in range(650 if boris else 300):
			if not world.actor_alive(nearby) and (boris or not world.actor_alive(shooter) or shooter.hp<hp): break
			await tree.physics_frame
			if not boris: continue
			called = called or (is_instance_valid(shooter) and shooter.special.has("airstrike_wing")) or (world.actor_alive(barrel) and barrel.special.has("airstrike_mark"))
			chip = chip or (world.actor_alive(barrel) and barrel.hp < barrel.max_hp)
		if boris:
			expect(chip,"真实步枪命中能扣除油桶血量")
			expect(not called and world.actor_alive(shooter) and shooter.special.get("airstrike_cd",0.0)>45.0,"空袭尚在冷却时步枪仍开火且不派机")
		expect(not world.actor_alive(barrel),"真实武器击毁直接瞄准的油桶")
		expect(not world.actor_alive(nearby),"爆炸引爆相邻油桶")
		if not boris: expect(not world.actor_alive(shooter) or shooter.hp<hp,"油桶爆炸伤及附近坦克")
		if boris and not elite and world.actor_alive(shooter):
			var lab = world._place_building("GATECH", "enemy", shooter.position+Vector2(245,0), true)
			world.fog.rebuild()
			expect(world.command_cursor.attack_cursor(lab)=="boris_airstrike","普通敌方建筑仍显示米格空袭指针")
			Unit.SovietSpecials.set_airstrike_reload(shooter,0.0)
			shooter.order_target(lab,false,false)
			for i in 120:
				if lab.special.has("airstrike_mark"): break
				await tree.physics_frame
			expect(lab.special.has("airstrike_mark") and shooter.special.get("airstrike_wing",[]).size()==2,"攻击普通敌方建筑仍标记并派出两架米格")
		finish()
		return
	if "--hospital" in OS.get_cmdline_user_args():
		var hospital = world.AlliedFirst.site(world,"CATHOSP")
		expect(hospital!=null and hospital.side=="neutral","原址存在中立科技医院")
		if hospital==null or engineer==null: finish(); return
		engineer.position = Vector2(73.5,84.5)*55.0
		world.AlliedFirst.check_hospital_discovery(world,s)
		expect(not s.get("hospital_found",false),"标记格之外不提前提示")
		engineer.position = Vector2(74.5,84.5)*55.0
		world.AlliedFirst.check_hospital_discovery(world,s)
		expect(s.get("hospital_found",false) and world.CampaignMarks.marks(world,true).any(func(m):return m.actor==hospital),"进入原图标记格触发提示和医院标点")
		engineer.position = orders.approach(engineer,hospital)+Vector2(32,0)
		world.fog.rebuild()
		expect(orders.use(engineer,"allied_engineer",hospital),"工程师可接到真实占领命令")
		for i in range(720):
			if hospital.side=="ally": break
			orders.tick_action(engineer,1.0/60)
		expect(hospital.side=="ally" and not world.actor_alive(engineer),"到门才转属")
		var u = world.units.filter(func(actor):return world.actor_alive(actor) and actor.side=="ally" and orders.infantry(actor)).front()
		var hp: float = u.hp-15
		u.hp = hp
		hospital._process(4.0)
		expect(u.hp>hp,"科技医院实际恢复步兵生命")
		var saved := BattleSaves.save_slot(world,"quick")
		expect(saved.ok,"发现与占领状态写档："+str(saved.get("message","")))
		finish()
		return
	# This route is intentionally a local fixture; it exercises the final walk and capture, not exploration.
	var plant = plants[0]
	engineer.global_position = orders.approach(engineer,plant)+Vector2(40,0)
	world.fog.rebuild()
	expect(orders.use(engineer,"allied_engineer",plant),"真实工程师命令可以占领任务电厂")
	for i in range(600):
		if plant.side=="ally": break
		orders.tick_action(engineer,1.0/60)
	expect(plant.side=="ally" and not world.actor_alive(engineer),"到门转属并消耗工程师")
	expect(plant._col.is_equal_approx(HouseColor.player_color()),"工程师占领后立即更新电厂房色")
	if "--production" in OS.get_cmdline_user_args():
		var factory = world.AlliedFirst.site(world,"GAPILE")
		hud.select_prod_tab("infantry")
		hud._refresh_production()
		hud._update_production_live()
		var card: Button = hud._prod_buttons.get("ENGINEER")
		expect(factory!=null and card!=null and not card.disabled,"指令甲板允许从盟军兵营训练工程师")
		if factory!=null and card!=null:
			var before: float = world.funds
			card.pressed.emit()
			expect(factory.production.has("ENGINEER"),"点击生产卡进入实际兵营队列")
			factory._tick_unit_queue(180.0,"ENGINEER")
			expect(world.funds<before and world.units.any(func(u):return world.actor_alive(u) and u.side=="ally" and u.unit_id=="ENGINEER"),"真实工时结算扣费并生成工程师")
		for id in ["TANY","AMCV","GTGCAN"]:
			expect(not GameData.mission_tech_block_reason(id).is_empty(),"本关明确禁止生产 "+id)
		finish()
		return
	if "--late-machine" in OS.get_cmdline_user_args():
		# The current normal transition removes this instance. Keep the tagged actor in a past-era fixture.
		s.phase = 4
		s.crossing_swapped = true
		s.awaiting_tanya = true
		s.past_report = true
		var target = world.AlliedFirst.site(world,"CATIME01")
		var tanya = world.spawn_unit("TANY","ally",target.position+Vector2(80,0))
		target.receive_hit(target.max_hp*10.0,"explosive")
		world.AlliedFirst.tick(world,0.0)
		expect(s.get("machine_death_era",-1)==1 and not world.ended,"过去时代附着机器被毁，有谭雅时不判负")
		orders.consume(tanya)
		if "--released-tanya" in OS.get_cmdline_user_args(): s.awaiting_tanya = false
		world.AlliedFirst.tick(world,0.0)
		if "--released-tanya" in OS.get_cmdline_user_args():
			expect(not world.ended and not s.retail_power_sequence.enabled.has("08707a2c"),"谭雅出场后关闭原图毁机失败分支")
		else:
			expect(world.ended and s.get("failure_trigger")=="08707A2C","时代、谭雅和附着对象条件共同满足才失败")
		finish()
		return
	if "--machine-loss" in OS.get_cmdline_user_args():
		var machine = world.AlliedFirst.site(world,"CATIME01")
		machine.receive_hit(machine.max_hp*10.0,"explosive")
		world.AlliedFirst.tick(world,0.0)
		expect(s.retail_power_sequence.fired.has("08a3e03c") and not s.retail_power_sequence.fired.has("08707a2c") and not world.ended and is_equal_approx(float(s.machine_failure_left),3.0),"失去时光机先通报而非立刻结算")
		world.AlliedFirst.tick(world,2.0)
		expect(not world.ended,"延时未满不结算")
		world.AlliedFirst.tick(world,1.0)
		expect(world.ended,"毁机延时到了进入失败")
		finish()
		return
	if "--save-pairs54" in OS.get_cmdline_user_args():
		orders.change_side(plants[1],"ally")
		plants[2].receive_hit(plants[2].max_hp*10.0,"explosive")
		world.AlliedFirst.update_plant_losses(world,s)
		# Serialized shape from the old loss-only slice: captured actors exist but it never ran an Entered row.
		var old = world.AlliedFirst.RetailDriver.new()
		old.start("yr_all01umd",1)
		old.state.enabled.clear()
		for row in old.definition.triggers:
			if row.name.begins_with("PP") and row.name.ends_with("_Destroyed"): old.enable(row.id)
		old.enable("04ec206c")
		s.retail_power_loss = old.snapshot()
		s.erase("plant_pair_driver_initialized")
		s.plant_external_links = {"108ea04c":true,"0baad3fc":false,"unported":true}
		expect(BattleSaves.save_slot(world,"quick").ok,"保存旧版驱动结构及待接启停")
		finish()
		return
	if "--plant-pairs" in OS.get_cmdline_user_args():
		world.AlliedFirst.tick(world,0.0)
		expect(s.retail_power_loss.locals.get("6",false) and not s.get("plant_reveals",{}).has("87"),"只占一厂不提前显露下一组")
		orders.change_side(plants[1],"ally")
		world.AlliedFirst.tick(world,0.0)
		expect(s.retail_power_loss.locals.get("7",false) and s.get("plant_reveals",{}).has("87"),"配对完成后通过原图动作显露 87 航点")
		world.AlliedFirst.tick(world,1.0)
		expect(s.get("plant_last_ping","")=="CJ" and s.retail_power_loss.fired.has("08a71f3c"),"下一组雷达事件按原图延迟触发")
		var serial: int = s.retail_power_loss.serial
		world.AlliedFirst.tick(world,1.0)
		expect(s.retail_power_loss.serial==serial,"显露与雷达不重复执行")
		orders.change_side(plants[0],"enemy")
		world.AlliedFirst.tick(world,0.0)
		expect(s.destroyed_plants.is_empty() and s.retail_power_loss.locals["6"],"被夺回的电厂保留发生过的进入事件")
		for i in [2,3,4,5]:
			orders.change_side(plants[i],"ally")
			world.AlliedFirst.tick(world,0.0)
			if i in [3,5]:
				world.AlliedFirst.tick(world,1.0)
				var code := "AR" if i==3 else "S"
				expect(s.plant_last_ping==code and s.plant_reveals.has("43" if i==3 else "18"),"下一对实际触发下一航点 "+code)
		plants[6].receive_hit(plants[6].max_hp*10.0,"explosive")
		world.AlliedFirst.tick(world,0.0)
		orders.change_side(plants[7],"ally")
		world.AlliedFirst.tick(world,0.0)
		expect(not s.retail_power_loss.fired.has("0bfca59c") and not s.retail_power_loss.enabled.has("0bfca59c"),"先毁的厂不被后续占领重新启用")
		finish()
		return
	if "--power-loss" in OS.get_cmdline_user_args():
		orders.change_side(plants[0],"enemy")
		world.AlliedFirst.tick(world,0.0)
		expect(s.destroyed_plants.is_empty() and not world.ended,"夺厂不计入物理损失")
		var easy := "--easy" in OS.get_cmdline_user_args()
		var limit := 7 if easy else 5
		for i in range(limit-1): plants[i].receive_hit(plants[i].max_hp*10.0,"explosive")
		world.AlliedFirst.tick(world,5.0)
		var locals: Dictionary = s.retail_power_loss.locals
		expect(not world.ended and locals.get("18",false) and locals.get("26" if not easy else "55",false),"物理毁坏写入原图变量，未达难度门槛不判负")
		if "--save-plant-driver" in OS.get_cmdline_user_args():
			expect(BattleSaves.save_slot(world,"quick").ok,"少毁一座时实际写档")
		plants[limit-1].receive_hit(plants[limit-1].max_hp*10.0,"explosive")
		world.AlliedFirst.tick(world,0.0)
		if not world.ended: print("PLANT TRACE: ",s.retail_power_loss," destroyed=",s.destroyed_plants)
		expect(world.ended and s.phase==1 and s.get("failure_trigger")=="06178D0C","达到原图局部变量链末端后执行失败动作")
		finish()
		return
	if "--engineer-rescue" in OS.get_cmdline_user_args():
		var barracks = world.AlliedFirst.site(world,"GAPILE")
		barracks.receive_hit(barracks.max_hp*10.0,"explosive")
		world.AlliedFirst.tick_engineer_rescue(world,s,29.0)
		expect(not s.get("engineer_drop_pending",false),"兵营与工程师均损失后先等待补援")
		world.AlliedFirst.tick_engineer_rescue(world,s,1.0)
		expect(s.get("engineer_drop_pending",false),"补援使用实际运输机")
		for i in range(1100):
			var landed: Array = world.units.filter(func(u):return world.actor_alive(u) and u.unit_id=="ENGINEER" and u.side=="ally" and not u.special.has("para_height"))
			if landed.size()>=4: break
			await tree.physics_frame
		expect(world.units.filter(func(u):return world.actor_alive(u) and u.unit_id=="ENGINEER" and u.side=="ally" and not u.special.has("para_height")).size()==4,"四名工程师真实跳伞落地")
		world.AlliedFirst.announce_engineer_rescue(world,s)
		expect(not s.get("engineer_drop_pending",false),"实际落地后才通报")
		finish()
		return
	if "--retake" in OS.get_cmdline_user_args():
		world.AlliedFirst.contest_plants(world,s,18.0)
		var pursuers: Array = world.units.filter(func(u):return world.actor_alive(u) and u.special.get("allied_first_retake")==plant.building_id)
		expect(pursuers.size()==1 and plant.side=="ally","敌方工程师接到该电厂任务，不立即转属")
		if not pursuers.is_empty():
			for i in range(7200):
				if plant.side=="enemy" or not world.actor_alive(pursuers[0]): break
				orders.tick_action(pursuers[0],1.0/60.0)
			expect(plant.side=="enemy" and world._side_power("ally").produced==0,"工程师实际到场夺厂并断开供电")
		finish()
		return
	world.AlliedFirst.tick(world,0.2)
	var expected_supply := 400 if "--easy" in OS.get_cmdline_user_args() else 200
	expect(s.phase==1 and world._side_power("ally").produced==expected_supply and world._side_power("ally").low,"一座电厂按原图难度供电，未达负载不提前推进")
	# Other captures are fixtures so the net-power gate is tested independently.
	for b in plants:
		if world._side_power("ally").low and b.side!="ally": orders.change_side(b,"ally")
	world.AlliedFirst.tick(world,5.0-float(s.retail_power_sequence.time))
	expect(s.phase==2 and not world._side_power("ally").low and not world.ended,"净供电达标后完成供电阶段，不冒充胜利")
	var machine = world.AlliedFirst.site(world,"CATIME01")
	var task_marks: Array = world.CampaignMarks.marks(world,false)
	var mark_layer: Node2D = world.campaign_mark_overlay
	expect(task_marks.size()==1 and task_marks[0].actor==machine and task_marks[0].title=="保护时光机","主战场防守目标指向时光机")
	expect(is_instance_valid(mark_layer) and mark_layer.get_parent() is CanvasLayer and mark_layer.get_parent().layer==1,"战场黄点不依赖命令预览层")
	if not task_marks.is_empty() and machine!=null and is_instance_valid(mark_layer):
		var bounds: Rect2 = machine.combat_sight_rect()
		var roof: Vector2 = world.get_canvas_transform()* (machine.global_position+RA2Art.art_dir(Vector2(bounds.get_center().x,bounds.position.y)))
		var marker: Vector2 = world.CampaignMarks.screen_point(mark_layer,world,task_marks[0])
		expect(bounds.has_area() and marker.is_equal_approx(roof-Vector2(0,48)),"黄点投影位于模型可见轮廓上方")
		expect(world.CampaignMarks.marks(world,true)[0].position==machine.position,"小地图定位仍使用地面坐标")
	expect("保护时光机" in hud.wave_label.text and "充能剩余" in hud.timer_label.text and "夺回发电厂" in hud.mission_objectives.text,"达标即刷新任务栏与情报面板")
	if "--save-legacy-charge" in OS.get_cmdline_user_args():
		s.erase("retail_power_sequence")
		s.erase("power_online_at")
		s.erase("power_sequence_new")
		s.charge = 4.0
		expect(BattleSaves.save_slot(world,"quick").ok,"写入仅含旧版充能余量的隔离战场档")
		finish()
		return
	if "--new-sequence-mainline" in OS.get_cmdline_user_args():
		await check_mainline(world)
		finish()
		return
	if "--power-sequence" in OS.get_cmdline_user_args():
		var seq: Dictionary = s.retail_power_sequence
		var radar = world.AlliedFirst.site(world,"GASPYSAT")
		expect(world.fog.explored_cells.ally.count(0)==0 and world.fog.visible_cells.ally.count(0)>0,"供电揭开全图地形，战斗视野仍按侦察单位计算")
		expect(seq.locals["49"] and seq.fired.has("0691357c") and not seq.fired.has("0be0b26c"),"实际电厂所有权与满电联合触发，雷达未提前转属")
		orders.change_side(radar,"neutral")
		world.AlliedFirst.tick(world,1.0)
		expect(radar.side=="ally" and radar.special.get("allied_first_radar_online",false) and seq.fired.has("0be0b26c"),"供电后一秒原图雷达动作执行")
		world.AlliedFirst.tick(world,2.0)
		expect(seq.fired.has("09515b9c") and not seq.fired.has("0a8e573c"),"目标一文字按三秒延迟触发")
		for b in plants: orders.change_side(b,"neutral")
		var left: float = s.charge
		world.AlliedFirst.tick(world,15.0)
		expect(s.charge==left and not seq.fired.has("0a8e573c"),"断电期间计时冻结")
		for b in plants: orders.change_side(b,"ally")
		world.AlliedFirst.tick(world,9.0)
		expect(seq.fired.has("0a8e573c") and not seq.fired.has("0a8ea21c"),"累计供电十二秒触发初段")
		var charged_film = world.get_node_or_null("HollywoodFilm")
		expect(charged_film!=null and charged_film.clip_id=="A01_P02E" and tree.paused and "准备穿越" in charged_film.subtitle.text,"供电正片在穿越前播放并暂停战场")
		if charged_film!=null:
			world.AlliedFirst.tick(world,5.0)
			expect(not seq.fired.has("0a8ea21c"),"影片期间剧情计时冻结")
			charged_film.skip.pressed.emit()
			await tree.process_frame
		world.AlliedFirst.tick(world,5.0)
		expect(seq.fired.has("0a8ea21c") and seq.enabled.has("0c6f847c") and seq.enabled.has("0a8e0e9c"),"镜头与完成计时同时启用")
	var saved := BattleSaves.save_slot(world,"quick")
	expect(saved.ok,"隔离战场可保存："+str(saved.get("message","")))
	print("ALLIED01 missing: ",s.missing,"; power:",world._side_power("ally"))
	finish()

func check_live_slot2(world) -> void:
	var state: Dictionary = world.allied_state.allied_first
	var saw_warp := false
	for i in range(160):
		if world.ended or state.get("armor_sent",false): break
		await get_tree().create_timer(1.0,true,false,true).timeout
		saw_warp = saw_warp or world.has_node("TimeVortex")
	expect(saw_warp,"正式战场自然推进到穿越")
	expect(state.phase==4 and state.get("awaiting_tanya",false) and state.get("armor_sent",false),"过去时代自然推进到装甲队，而不是直接派谭雅")

const TRANSITION_SITES = [["1028381","CAGAS01",128],["1028400","CASANF01",128],["1028434","CASANF02",256]]

func check_opening_site_health(world) -> void:
	for entry in TRANSITION_SITES:
		var sites: Array=world.buildings.filter(func(b):return world.actor_alive(b) and b.special.get("allied_first_index","")==entry[0])
		expect(sites.size()==1 and is_equal_approx(float(sites[0].hp)/sites[0].max_hp,float(entry[2])/256.0),"正式出击初始建筑血量 "+entry[1])

func fill_transition_sites(world) -> Array:
	var sites := []
	for entry in TRANSITION_SITES:
		var found: Array = world.buildings.filter(func(b):return world.actor_alive(b) and b.special.get("allied_first_index","")==entry[0])
		expect(found.size()==1,"地图结构唯一装配 "+entry[0])
		if found.size()!=1: continue
		var b = found[0]
		expect(b.building_id==entry[1] and b.data.garrison_slots==10 and not b._ra2.is_empty(),"零售建筑美术和十个驻军位 "+entry[1])
		var orders = world.AlliedFirst.Orders
		for i in 10:
			var unit = world.spawn_unit("E1","ally",b.position+Vector2(180,0))
			unit.position = orders.approach(unit,b)
			if i==0: world.fog.rebuild()
			if not orders.use(unit,"allied_garrison",b):
				print("ENTRY rejected ",[i,b.building_id,b.side,b.data.get("tags"),world.actor_visible_to("ally",b),b.is_operational()])
				break
			for frame in 180:
				if unit.embarked_in==b: break
				orders.tick_action(unit,1.0/60)
			if unit.embarked_in!=b:
				print("ENTRY approach blocked ",[b.building_id,unit.position,b.position,unit.special.get("action")])
				break
		var extra = world.spawn_unit("E1","ally",b.position+Vector2(180,0))
		expect(b.special.get("occupants",[]).size()==10 and not orders.use(extra,"allied_garrison",b),"正式驻军命令接纳十人并拒绝第十一人 "+entry[1])
		sites.append(b)
	return sites

func check_mainline(world) -> void:
	world.set_process(false)
	world.set_physics_process(false)
	var mission = world.AlliedFirst
	var s: Dictionary = world.allied_state.allied_first
	mission.tick(world,0.0)
	expect(s.phase==2 and s.charge==mission.CHARGE_SECONDS,"真实旧存档无需再占厂，直接进入充能")
	var orders = preload("res://scripts/units/allied_abilities.gd")
	var sites: Array = []
	var reactor = mission.site(world,"NANRCT")
	var batch := "--retail24" in OS.get_cmdline_user_args()
	if batch:
		# Actual map actors and damage entry point, without changing production or spawning a factory.
		var american = world.units.filter(func(u):return world.actor_alive(u) and u.special.get("allied_first_room")=="Americans").front()
		var other = world.units.filter(func(u):return world.actor_alive(u) and u.side=="enemy").front()
		var first = mission.site(world,"CAPOWR01")
		first.receive_hit(3,"bullet",{},other)
		mission.tick(world,0.0)
		expect(s.get("player_hit_plants",{}).is_empty(),"其它房号的伤害不触发美国玩家警告")
		for i in range(1,9): mission.site(world,"CAPOWR%02d"%i).receive_hit(3,"bullet",{},american)
		mission.tick(world,0.0)
		for row in mission.RetailDriver.DATA.data.yr_all01umd.triggers:
			if row.name.ends_with("_PlayerAttack") or row.name.begins_with("Start_PP") or row.name.begins_with("Change_House_PP") or row.name=="PowerAttacked":
				expect(s.retail_power_loss.fired.has(row.id),str(row.name)+" 已在正式电厂触发")
	var original_reactor_at: Vector2 = reactor.position if reactor!=null else Vector2.INF
	var repairers: Array = world.units.filter(func(u):return world.actor_alive(u) and u.side=="enemy" and u.unit_id=="ENGINEER" and u.special.get("allied_first_room")=="Confederation")
	expect(reactor!=null and repairers.size()==1 and s.get("reactor_engineer_sent",false),"供电事件只派一名原图核电站工程师")
	if reactor!=null and not repairers.is_empty():
		for i in range(1200):
			if not world.actor_alive(repairers[0]): break
			orders.tick_action(repairers[0],1.0/60.0)
		expect(is_equal_approx(float(reactor.hp),float(reactor.max_hp)),"核电站工程师实际走到门口完成维修")
		if "--reactor-loss" in OS.get_cmdline_user_args(): reactor.receive_hit(reactor.max_hp*10.0,"explosive")
	var held: Array = world.buildings.filter(func(b):return world.actor_alive(b) and b.side=="ally" and b.building_id.begins_with("CAPOWR0"))
	for b in held: orders.change_side(b,"neutral")
	mission.tick(world,9.0)
	expect(s.charge==mission.CHARGE_SECONDS and not s.get("armor_sent",false),"断电暂停充能，不提前推进")
	for b in held: orders.change_side(b,"ally")
	mission.tick(world,6.0)
	expect(mission.armor_remaining(world)==0,"充能期间不提前发送过去时代编组")
	mission.tick(world,mission.CHARGE_SECONDS)
	var charge_film = world.get_node_or_null("HollywoodFilm")
	expect(charge_film!=null and charge_film.clip_id=="A01_P02E","真实旧档供电后播放时光机准备影片")
	if charge_film!=null:
		charge_film.skip.pressed.emit()
		await get_tree().process_frame
	# Retake engineers continue moving during the film callback. Re-establish the power precondition for the transition fixture.
	for plant in world.buildings:
		if world.actor_alive(plant) and plant.building_id.begins_with("CAPOWR0") and plant.side!="ally": orders.change_side(plant,"ally")
	expect(mission.grid_ready(world),"穿越专项在真实供电达标后推进")
	if "--retail-transition" in OS.get_cmdline_user_args():
		expect(world.world_input_enabled(),"穿越锁控前由玩家下达驻军命令")
		sites = fill_transition_sites(world)
	mission.tick(world,mission.CHARGE_SECONDS)
	expect(s.phase==3 and world.has_node("TimeVortex"),"足额供电后播放穿越效果")
	if "--cannon-loss" in OS.get_cmdline_user_args():
		var gun = mission.site(world,"GTGCAN")
		if gun != null: gun.receive_hit(gun.max_hp*10.0,"explosive")
	if batch:
		for gun in world.buildings.duplicate():
			if world.actor_alive(gun) and gun.building_id=="GTGCAN": gun.receive_hit(gun.max_hp*10.0,"explosive")
	var saved := BattleSaves.save_slot(world,"slot1")
	expect(saved.ok,"穿越中真实写盘："+str(saved.get("message","")))
	var evacuees: Array = []
	for building in sites: evacuees.append_array(building.special.get("occupants",[]))
	mission.tick(world,0.75)
	if not sites.is_empty():
		expect(sites.all(func(b):return b.special.get("occupants",[]).size()==10),"一秒前仍有三组驻军")
	mission.tick(world,0.25)
	if not sites.is_empty():
		expect(sites.all(func(b):return b.special.get("occupants",[]).is_empty() and b.side=="neutral"),"三个指定标签依次撤出驻军并恢复中立")
		expect(evacuees.size()==30 and evacuees.all(func(u):return world.actor_alive(u) and u.embarked_in==null and u.visible and sites.all(func(b):return not Geometry2D.is_point_in_polygon(u.position-b.position,b.footprint_poly()))),"三十名撤出者全部存活且位于建筑地基外")
	expect(s.retail_power_sequence.fired.has("0d87303c") and not s.crossing_swapped,"疏散链完成，三秒换场前置尚未到期")
	if "--last-past" in OS.get_cmdline_user_args(): preload("res://tests/allied_first_closing.gd").damage_before_swap(world)
	mission.tick(world,3.0)
	if "--last-past" in OS.get_cmdline_user_args(): preload("res://tests/allied_first_closing.gd").verify_restore(self,world)
	if "--followup-fleet" in OS.get_cmdline_user_args():
		expect(s.retail_closing.fired.has("085159ec") and not s.retail_closing.fired.has("067dd9fc") and not s.get("followup_fleet_sent",false),"换场中点修复建筑后，舰队保留一秒创建延迟")
	expect(s.phase==3 and s.crossing_swapped and world.has_node("TimeVortex"),"漩涡中点已换场，画面尚未结束")
	expect(not world.units.any(func(u):return world.actor_alive(u) and u.special.get("allied_first_room")=="YuriCountry"),"零售房号旧尤里陆军清场")
	expect(world.units.any(func(u):return world.actor_alive(u) and u.side=="ally"),"保留玩家军队")
	if "--reactor-loss" in OS.get_cmdline_user_args():
		var rebuilt = mission.site(world,"NANRCT")
		expect(rebuilt!=null and rebuilt!=reactor and rebuilt.position.is_equal_approx(original_reactor_at) and s.retail_power_sequence.locals["48"] and s.retail_power_sequence.fired.has("0930470c"),"只在核电站失去后于 NA 重建" )
	else:
		expect(mission.site(world,"NANRCT")==reactor and not s.retail_power_sequence.fired.has("0930470c"),"完好的原核电站保持原实体且不重建")
	expect(world.units.filter(func(u):return world.actor_alive(u) and u.unit_id=="DRED" and u.special.get("allied_first_room")=="French").size()==4,"四艘过去时代无畏舰已装配")
	expect(world.buildings.filter(func(b):return world.actor_alive(b) and b.building_id=="GTGCAN").size()==4,"保留或补齐四门岸炮，不叠建")
	expect(s.get("bridge_house_restored",false) and mission.site(world,"CASANF10")==null and mission.site(world,"CASANF11")!=null,"按零售状态恢复 BridgeHouse 并保留开局断口")
	expect(not s.confederation_production and mission.site(world,"YAPPPT")==null and s.retail_dominator.enabled.has("0b8a090c"),"换场时生产触发器已启用，原图一秒未到仍未开工")
	if batch:
		for id in mission.PowerSequence.CANNON_TAGS.keys()+mission.PowerSequence.REBUILD_CANNONS:
			expect(s.retail_power_sequence.fired.has(id),"岸炮附着与重建 "+id)
		expect(s.retail_dominator.fired.has("0951879c") and mission.site(world,"YAPPET")==null,"售出原控制器后启用生产计时")
	if "--past-power" in OS.get_cmdline_user_args():
		var holder = mission.site(world,"CAPOWR01")
		var supplied: int = s.auxiliary_power
		expect(holder!=null and holder.side=="ally" and supplied>=200,"穿越后仍有原图辅助供电")
		if holder!=null: holder.receive_hit(holder.max_hp*10.0,"explosive")
		mission.tick(world,0.5)
		expect(s.auxiliary_power==supplied-200 and s.retail_power_loss.fired.has("097d840c") and not world.ended,"穿越后原厂被毁，收回对应 200 电力，不重开旧失败目标")
		return
	var later := BattleSaves.save_slot(world,"slot3")
	expect(later.ok,"交换后、漩涡结束前写盘："+str(later.get("message","")))
	mission.tick(world,1.5)
	var apocs_at_entry: Array=world.units.filter(func(u):return world.actor_alive(u) and u.unit_id=="APOC" and u.special.get("allied_first_raid",false))
	expect(apocs_at_entry.size()==(2 if int(s.retail_power_sequence.difficulty)==0 else 4),"穿越中点后一秒按难度派出完整天启队，早于抵达影片")
	expect(s.phase==4 and s.awaiting_tanya and not s.armor_sent,"穿越后先等待装甲队，不提前发谭雅")
	expect(not s.retail_power_sequence.fired.has("05e9106c") and not world.has_node("HollywoodFilm"),"原图等待两秒之前不播抵达通讯")
	mission.tick(world,0.5)
	if "--map50-past" in OS.get_cmdline_user_args(): preload("res://tests/allied_first_map50.gd").capture_roster(world)
	await get_tree().process_frame
	await get_tree().process_frame
	var radio = world.get_node_or_null("HollywoodFilm")
	var kirov := "0790df3c"
	if "--kirov" in OS.get_cmdline_user_args():
		var regular: bool = s.retail_power_sequence.difficulty!=0
		expect(s.retail_power_sequence.enabled.has(kirov)==regular,"抵达通讯依原图难度启用基洛夫报告")
		mission.tick(world,34.0)
		expect(not s.retail_power_sequence.fired.has(kirov),"抵达后第34秒基洛夫报告尚未触发")
		mission.tick(world,1.0)
		expect(not s.retail_power_sequence.fired.has(kirov) and mission.armor_remaining(world)>0,"仍有天启坦克时第35秒继续等待")
	expect(radio!=null and radio.clip_id=="A01_P03E","穿越后、谭雅到场前播放抵达过去的影片")
	expect(radio!=null and "穿越了时间" in radio.subtitle.text,"抵达过去的雷达影片已挂载对应中文字幕")
	if radio!=null: radio.skip.pressed.emit()
	await get_tree().process_frame
	expect(s.retail_dominator.fired.has("0b8a090c") and s.retail_dominator.enabled.has("0bd650ac") and s.confederation_production,"Build_Dom 启动本房生产并接通 New_Dom_Up")
	for flag in ["ORCA","BEAG","ZEP"]:
		if ("--flak-"+flag) in OS.get_cmdline_user_args():
			await preload("res://tests/allied_first_flak.gd").exercise(self,world,flag)
			return
	if "--global-ai" in OS.get_cmdline_user_args():
		preload("res://tests/allied_first_field_audit.gd").global_ai(self,world,s)
	if "--dx-bridge-production" in OS.get_cmdline_user_args():
		var dom = mission.site(world,"YAPPPT")
		expect(s.get("confederation_production",false) and dom!=null and dom.special.allied_first_room=="Confederation","仅启动原图控制器所属房的工程")
		if dom!=null:
			dom._process(5.0)
			expect(not dom.under_construction and dom.hp>dom.max_hp*0.15,"由普通建筑更新完成控制器施工")
		var end = mission.site(world,"CASANF09")
		expect(end!=null and mission.site(world,"CASANF11")!=null,"恢复后两个连接段仍存在")
		var before_hit = mission.site(world,"CASANF11")
		expect(s.retail_field.fired.has("092af4ac") and is_equal_approx(before_hit.hp,350.0),"开场断口保持缺失，过去时代检查已在BH命中两次，各扣75")
		if end!=null: end.receive_hit(end.max_hp*10.0,"explosive")
		var beam = mission.site(world,"CASANF11")
		var untouched = mission.site(world,"CASANF12")
		var untouched_hp: float = untouched.hp
		mission.tick(world,0.0)
		print("ALL01_BRIDGE_HIT ",beam.hp," untouched ",untouched.hp," original ",untouched_hp," connector ",s.get("bridge_connector_fallen",false)," step ",s.retail_power_sequence.fired.has("07a8d3ec"))
		expect(s.get("bridge_connector_fallen",false) and s.retail_power_sequence.fired.has("07a8d3ec") and world.actor_alive(beam) and is_equal_approx(beam.hp,125.0) and untouched.hp==untouched_hp,"断口 BS 六击落空，BH 三次 HE 命中木甲，连接段从350降到125且远段无损")
		mission.tick(world,0.0)
		expect(beam.hp==125.0,"断桥驱动不会重复施伤")
		var center = mission.site(world,"CASANF04")
		var far = mission.site(world,"CASANF13")
		var far_hp: float = far.hp
		expect(center!=null and not s.retail_power_sequence.fired.has("0835813c"),"连接段损坏时中央桥段保持独立")
		center.receive_hit(center.max_hp*10.0,"explosive")
		mission.tick(world,0.0)
		print("BRIDGE_CENTER ",s.retail_power_sequence.fired.has("0935a09c")," ",beam.hp," ",untouched_hp-untouched.hp," ",far_hp-far.hp)
		expect(s.retail_power_sequence.fired.has("0835813c") and s.retail_power_sequence.fired.has("0935a09c") and not world.actor_alive(beam) and is_equal_approx(untouched_hp-untouched.hp,300.0) and is_equal_approx(far_hp-far.hp,300.0),"中央桥段被毁后按原图航点连锁，剩余连接段被击毁")
		expect(BattleSaves.save_slot(world,"slot2").ok,"保存桥梁连锁后的场景")
		mission.deploy_followup_fleet(world,s)
		var dx = world.units.filter(func(u):return world.actor_alive(u) and u.special.get("allied_first_team")=="0955BB7C").front()
		var dx_target = mission.site(world,"NANRCT")
		expect(dx!=null and dx_target!=null,"DX 与核电站出现在实际战场")
		if dx==null or dx_target==null: return
		var aim: Vector2 = dx_target.position
		var reactor_hp: float = dx_target.hp
		var fired := false
		for i in range(720):
			mission.tick_dread_orders(world,s,1.0/60.0)
			fired = world.units.any(func(u):return world.actor_alive(u) and u.unit_id=="DMISL" and u.special.get("flight",{}).get("source")==dx and u.special.flight.aim==aim)
			if fired: break
			await get_tree().physics_frame
		expect(fired,"DX 从原出生点实际发射导弹瞄向核电站")
		for i in range(360):
			if not world.actor_alive(dx_target) or dx_target.hp < reactor_hp: break
			await get_tree().physics_frame
		expect(not world.actor_alive(dx_target) or dx_target.hp<reactor_hp,"DX 导弹实际命中核电站并扣血")
		return
	if "--last-past" in OS.get_cmdline_user_args():
		preload("res://tests/allied_first_closing.gd").past(self,world,s)
		return
	if "--map50-past" in OS.get_cmdline_user_args():
		await preload("res://tests/allied_first_map50.gd").past(self,world,s)
		return
	if "--map40-city" in OS.get_cmdline_user_args():
		await preload("res://tests/allied_first_map40.gd").run(self,world)
		return
	if "--followup-fleet" in OS.get_cmdline_user_args():
		mission.tick(world,0.5)
		expect(s.get("followup_fleet_sent",false) and s.retail_closing.fired.has("067dd9fc"),"抵达通讯播放前舰队已按原图创建")
		mission.tick(world,0.5)
		var scorpions: Array = world.units.filter(func(u):return world.actor_alive(u) and u.unit_id=="HYD" and u.special.has("allied_first_patrol_step"))
		var dreads: Array = world.units.filter(func(u):return world.actor_alive(u) and u.unit_id=="DRED")
		expect(scorpions.size()==6 and dreads.size()==7,"四艘常规加两艘港区海蝎，以及七艘无畏舰")
		expect(world.units.filter(func(u):return world.actor_alive(u) and u.side=="neutral" and u.unit_id in ["CRUISE","TUG"]).size()==3,"零售港区加入两艘邮轮和一艘拖船")
		for group in mission.RetailDriver.DATA.data.yr_all01umd.naval_fleet.values():
			for team in group:
				var members: Array = world.units.filter(func(u):return world.actor_alive(u) and u.special.get("allied_first_team","")==team.id and u.special.get("allied_first_room","")==team.house and u.unit_id==team.unit)
				expect(members.size()==1,"原图舰队成员与房号 "+team.id)
				if team.unit=="HYD" and members.size()==1:
					expect(members[0].special.allied_first_patrol_route.front()==team.steps[0][1],"原图巡逻起点 "+team.id)
		if scorpions.is_empty(): return
		mission.tick_scorpion_patrols(world)
		var ship = scorpions[0]
		var origin: Vector2 = ship.position
		for i in range(250):
			if ship.position.distance_to(origin)>65.0: break
			await get_tree().physics_frame
		expect(ship.position.distance_to(origin)>65.0,"海蝎按任务命令实际航行")
		expect(BattleSaves.save_slot(world,"quick").ok,"后续舰队进度和巡逻指令可存盘")
		return
	if "--dread-orders" in OS.get_cmdline_user_args():
		var fleet: Array = world.units.filter(func(u):return world.actor_alive(u) and u.unit_id=="DRED")
		var ship = fleet.filter(func(u):return u.special.get("allied_first_team")=="0956959C").front()
		expect(ship!=null,"KD 无畏舰从原图航点出场")
		if ship==null: return
		var origin: Vector2 = ship.position
		var aim: Vector2 = mission.wp(194)
		var fired := false
		for i in range(840):
			mission.tick_dread_orders(world,s,1.0/60.0)
			for missile in world.units:
				if not world.actor_alive(missile) or missile.unit_id!="DMISL": continue
				var flight: Dictionary = missile.special.get("flight",{})
				if flight.get("source")==ship and flight.get("aim")==aim: fired = true
			if fired and ship.has_move_order and ship.move_target.is_equal_approx(mission.wp(127)) and ship.position.distance_to(origin)>100.0: break
			await get_tree().physics_frame
		expect(fired,"KD 实际发射导弹瞄准陆地航点 194")
		expect(ship.move_target.is_equal_approx(mission.wp(127)) and ship.position.distance_to(origin)>100.0,"发射后转入原图水路并实际航行")
		expect(BattleSaves.save_slot(world,"quick").ok,"炮击和航行阶段可写档")
		return
	var difficulty := int(BattleRequest.skirmish_config.get("difficulty",1))
	expect(s.retail_power_sequence.fired.has("05ee7c8c" if difficulty==0 else "05ee7b9c"),"正式驱动按难度执行天启编队")
	var delay: float = mission.armor_delay(difficulty)
	if "--late-dominator" in OS.get_cmdline_user_args():
		mission.tick(world,49.0)
		expect(s.get("offmap_yard_room")=="Confederation","晚期条件启用前不转属")
		mission.tick(world,1.1)
		expect(s.get("offmap_yard_room")=="BridgeHouse" and not s.confederation_production,"活控制器触发场外建造场转属，关闭原房生产")
		var yard_save := BattleSaves.save_slot(world,"quick")
		expect(yard_save.ok,"场外建造场转属状态可写档："+str(yard_save.get("message","")))
		delay = float(s.armor_left)
	expect(mission.armor_delay(0)==90.0 and mission.armor_delay(1)==100.0 and mission.armor_delay(2)==30.0,"三档出兵延时表与原图字段一致")
	if not s.armor_sent:
		mission.tick(world,maxf(0.0,delay-1.0))
		expect(not s.armor_sent,"未到本难度触发点不出兵")
		mission.tick(world,1.0)
	else:
		expect("--late-dominator" in OS.get_cmdline_user_args() and delay==0.0,"较早的装甲队可先于晚期控制器检查出现")
	expect(s.get("retail_armor",{}).get("fired",{}).has(mission.Armor.SEND[difficulty]),"本难度装甲增援由正式驱动触发")
	var raid: Array = world.units.filter(func(u):return world.actor_alive(u) and u.special.get("allied_first_raid",false))
	expect(raid.filter(func(u):return u.special.get("allied_first_team")=="0925E45C").size()==3 and raid.filter(func(u):return u.special.get("allied_first_team")=="0925FDEC").size()==3 and apocs_at_entry.all(func(u):return not world.actor_alive(u) or raid.has(u)),"两支后续装甲各三辆，首批天启的存活实例保留原编组")
	if "--ai-contact" in OS.get_cmdline_user_args():
		var lead = raid.filter(func(u):return u.unit_id=="APOC").front()
		var victim = world.spawn_unit("MTNK","ally",lead.position+Vector2(210,0))
		victim.fire_stance = "none"
		lead.order_stop()
		world.fog.rebuild()
		mission.direct_armor(world)
		var chosen = lead.attack_target
		expect(world.actor_alive(chosen),"装甲完成移动后接到可见目标攻击命令")
		if world.actor_alive(chosen):
			var hp: float = chosen.hp
			for i in range(720):
				if not world.actor_alive(chosen) or chosen.hp < hp: break
				await get_tree().physics_frame
			expect(not world.actor_alive(chosen) or chosen.hp<hp,"AI 选中的目标在真实战斗中受损")
	mission.tick(world,10.0)
	expect(s.awaiting_tanya and is_equal_approx(float(s.tanya_left),5.0),"装甲仍然存活时不启动谭雅倒计时")
	# The retail destruction events count the Kirov alongside both original armor houses.
	if s.get("map_field_rows",false):
		for u in world.units.duplicate():
			if world.actor_alive(u) and u.special.get("allied_first_team","")=="0941632C":
				orders.consume(u)
				world.units.erase(u)
	for u in raid:
		orders.consume(u)
		world.units.erase(u)
	await get_tree().process_frame
	mission.tick(world,4.0)
	if "--kirov" in OS.get_cmdline_user_args():
		var regular: bool = difficulty!=0
		var voice: bool = Ra2Sfx.get_children().any(func(p):return p is AudioStreamPlayer and p.stream!=null and p.stream.resource_path.ends_with("/vkirsea.wav"))
		expect(s.retail_power_sequence.fired.has(kirov)==regular and voice==regular,"天启清除后按难度实际播放基洛夫原声音轨")
	expect(s.awaiting_tanya and is_equal_approx(float(s.tanya_left),1.0),"清除编组后先等五秒")
	mission.tick(world,1.0)
	var tanya = world.units.filter(func(u):return world.actor_alive(u) and u.special.get("allied_first_tanya",false)).front()
	var target = mission.site(world,"YAPPPT")
	expect(s.phase==4 and tanya!=null and tanya.is_amphibious and target!=null and target.special.allied_first_dominator,"过去阶段取得可游泳的谭雅，并挂载独立控制器")
	if tanya==null or target==null: return
	if "--map40-reminder" in OS.get_cmdline_user_args():
		var city = mission.city_driver(world,s)
		mission.tick(world,119.0)
		expect(not s.has("island_reminder_at") and city.state.enabled.has(city.TANYA_REMINDER),"谭雅在场，恶魔岛提醒等待120秒")
		mission.tick(world,1.0)
		expect(s.has("island_reminder_at") and city.state.enabled.has(city.TANYA_REMINDER),"恶魔岛目标提示按时显示，重复计时重新开始")
		tanya.hp=0
		var previous: float = s.island_reminder_at
		mission.tick(world,120.0)
		expect(s.island_reminder_at==previous and not city.state.enabled.has(city.TANYA_REMINDER),"谭雅阵亡后取消提示")
		return
	if "--carriers" in OS.get_cmdline_user_args():
		tanya.hp=0
		mission.tick(world,0.1)
		expect(world.units.filter(func(u):return world.actor_alive(u) and u.special.get("allied_first_carrier",false)).size()==3,"谭雅阵亡后走三航母替代路线，不直接失败")
		mission.tick(world,1.0)
		var fleet: Array = world.units.filter(func(u):return world.actor_alive(u) and u.special.get("allied_first_carrier",false))
		expect(fleet.size()==6 and fleet[0].has_move_order,"第二批抵达并收到集结航令")
		mission.tick(world,20.0)
		for ship in fleet:
			orders.consume(ship)
			world.units.erase(ship)
		mission.tick(world,0.1)
		expect(not world.ended and s.has("carrier_follow_left"),"舰队全损后等待补援，不判负")
		mission.tick(world,1.0)
		expect(s.carrier_waves==3,"补派第三批航母")
		if s.get("map_field_rows",false):
			expect(s.retail_power_sequence.fired.has("0993f7bc"),"原图五秒关闭四个岸炮重建检查")
			expect(s.retail_field.fired.has("089b82bc") and s.retail_field.fired.has("0ba104bc"),"谭雅阵亡和航母首援均由原始触发器执行")
	if "--swim" in OS.get_cmdline_user_args():
		# Breach the northern fence before the C4 route. Damage is a fixture; the swim and planting are real.
		for wall in world.buildings.duplicate():
			if world.actor_alive(wall) and wall.special.get("allied_first_overlay",false) and wall.building_id=="CAFNCP" and wall.position.y==26.5*55.0 and wall.position.x>=85.5*55.0 and wall.position.x<=89.5*55.0:
				wall.receive_hit(wall.max_hp*10.0,"explosive")
		await get_tree().process_frame
		world._refresh_pathing()
		var entrance: Vector2 = orders.approach(tanya,target)
		var path: PackedVector2Array = world.path_for_unit(tanya,entrance)
		expect(path.size()>1 and Array(path).any(func(point): return world.in_water_world(point)),"跨海寻路实际经过水格")
		expect(orders.use(tanya,"allied_c4",target),"谭雅接到炸毁控制器指令")
		for i in range(7200):
			if target.special.has("c4_left"): break
			orders.tick_action(tanya,1.0/60.0)
			if i%15==0 and world.fog != null: world.fog.rebuild()
		expect(target.special.has("c4_left"),"谭雅从出生地游到控制器并实际布下C4")
		if not target.special.has("c4_left"):
			for i in range(tanya.get_slide_collision_count()):
				var blocker = tanya.get_slide_collision(i).get_collider()
				print("ALLIED01 C4 blocker ",blocker, " ", [blocker.building_id,blocker.position,blocker.footprint_poly()] if blocker is Building else "")
			print("ALLIED01 C4 diagnostic ", tanya.position," goal ",entrance," target ",target.position," visible ",world.actor_visible_to("ally",target)," order ",tanya.special.get("action","")," stage ",tanya.special.get("c4_stage",""))
			return
		orders.tick_actor(target,3.0)
	else:
		# Fixture damage for the separate fallback/settlement regressions.
		target.receive_hit(target.max_hp*10.0,"explosive",{},tanya)
	if "--late-dominator" not in OS.get_cmdline_user_args():
		# This fixture has already fast-forwarded past the retail threshold to clear armor.
		# Reset only the controller driver to exercise the earlier destruction branch.
		s.erase("retail_dominator")
		s.new_dominator_check = false
		s.dominator_check_left = 1.0
	mission.tick(world,0.1)
	expect(s.phase==5 and not world.ended,"控制器毁坏进入延迟结算")
	expect(s.get("victory_trigger")==("0BD6117C" if "--late-dominator" in OS.get_cmdline_user_args() else "089EC19C"),"早、晚控制器检查记录不同来源且只进入一次结算")
	mission.tick(world,2.0)
	expect(not s.get("victory_cheer",false) and not world.ended,"庆祝和结算都不提前")
	mission.tick(world,1.0)
	expect(s.get("victory_cheer",false) and not world.ended,"控制器摧毁三秒后触发一次庆祝")
	if "--save-victory-driver" in OS.get_cmdline_user_args():
		expect(BattleSaves.save_slot(world,"quick").ok,"庆祝与结算之间真实写档")
	mission.tick(world,7.0)
	expect(world.ended,"延迟完成后进入战役胜利结算")

func finish() -> void:
	print("ALLIED01_RESULT ", checks-failures,"/",checks)
	get_tree().quit(0 if failures==0 else 1)
