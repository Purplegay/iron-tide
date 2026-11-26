extends Node

var failed := 0

func check(ok: bool, label: String) -> void:
	print("SOV07 ",ok," ",label)
	if not ok: failed += 1

func _ready() -> void:
	call_deferred("run")

func cold_intro(slot: String) -> void:
	var tree := get_tree()
	var result := BattleSaves.load_into_scene(slot)
	check(result.ok, "从磁盘读取简报断点 " + slot)
	if not result.ok: return
	await tree.scene_changed
	var world = tree.current_scene.battle
	var state: Dictionary = world.allied_state
	check(world.paused and state.head_brief_stage == 0 and not world.has_node("HollywoodFilm"), "冷读保留暂停及导览阶段")
	world.hud._toggle_pause()
	world.HeadGames.briefing(world, 0.1)
	var film = world.get_node_or_null("HollywoodFilm")
	if slot == "quick":
		check(film == null and state.head_brief_stage == 1, "已播完的短片不重播，继续镜头导览")
		return
	var expected := "S07_F00E" if slot == "slot1" else "S07_P01E"
	check(film != null and film.clip_id == expected and film.player.is_playing() and state.head_brief_stage == 0, "继续后恢复对应简报且导览未提前推进")
	if film == null: return
	film.skip.pressed.emit()
	await tree.process_frame
	await tree.process_frame
	if slot == "slot1":
		film = world.get_node_or_null("HollywoodFilm")
		check(film != null and film.clip_id == "S07_P01E", "全屏结束后接到雷达通讯")
		if film == null: return
		film.skip.pressed.emit()
		await tree.process_frame
	world.HeadGames.briefing(world, 0.1)
	check(state.get("head_intro_done", false) and state.head_brief_stage == 1 and not state.has("head_resume_clip"), "通讯结束后开始导览一次")

const BridgeDamage = preload("res://scripts/world/bridge_damage.gd")

func bridge_cold_state(world, broken: bool) -> void:
	var span: Rect2 = BridgeDamage.spans(world)[0]
	var section: Rect2 = BridgeDamage.sections(world, span)[1]
	var huts: Array = world.buildings.filter(func(b): return world.actor_alive(b) and b.building_id == "CABHUT" and b.special.get("bridge_span") == span)
	check(huts.size() == 2 and huts.all(func(h): return h.special.get("bridge_repaired") == not broken), "冷读低桥两端维修小屋状态")
	check((BridgeDamage.health(world, section) <= 0.0) == broken, "冷读低桥断面血量")
	check((section in world.ground.broken_bridges) == broken, "冷读低桥视觉断面")
	check((section in world.path_service.broken_bridge_decks) == broken, "冷读低桥寻路断面")
	if not broken or huts.is_empty(): return
	var engineer = world.spawn_unit("SENGINEER", "ally", huts[0].position + Vector2.DOWN * 65)
	world.fog._reveal("ally", huts[0].position, 180.0, 2.0)
	check(engineer.order_interaction("allied_bridge", huts[0], false), "冷读后工程师接受低桥维修命令")
	engineer.position = AlliedAbilities.approach(engineer, huts[0])
	for i in range(90):
		if not world.actor_alive(engineer): break
		AlliedAbilities.tick_action(engineer, 1.0 / 60.0)
	check(not world.actor_alive(engineer) and BridgeDamage.health(world, section) == BridgeDamage.strength(), "工程师完成低桥维修并消耗")
	check(huts.all(func(h): return h.special.get("bridge_repaired", false)) and not world.ground.broken_bridges.has(section), "低桥维修后两端及地形同步")

func run() -> void:
	var tree := get_tree()
	reparent(tree.root)
	var args := OS.get_cmdline_user_args()
	if "--cold-bridge-broken" in args or "--cold-bridge-repaired" in args:
		var broken := "--cold-bridge-broken" in args
		var result := BattleSaves.load_into_scene("slot1" if broken else "slot2")
		check(result.ok, "从磁盘冷读第七关桥梁断点")
		if result.ok:
			await tree.scene_changed
			var world = tree.current_scene.battle
			check(world.paused and world.mission.id == "yr_head_games", "冷读回到暂停的第七关")
			bridge_cold_state(world, broken)
			if broken and failed == 0:
				check(BattleSaves.save_slot(world, "slot2").ok, "写盘低桥维修状态")
		tree.quit(int(failed > 0))
		return
	if "--cold-objective" in args:
		var result := BattleSaves.load_into_scene("slot2")
		check(result.ok, "从隔离目录冷读第七关存档 2：" + str(result.get("error", "")))
		if result.ok:
			await tree.scene_changed
			var world = tree.current_scene.battle
			check(world.paused and world.mission.id == "yr_head_games", "冷读回到暂停的第七关")
			check(world.allied_state.has("head_games_freed_0") and world.allied_state.has("head_games_freed_1"), "两翼解放状态已恢复")
			world.hud._refresh_timer()
			check(world.hud.wave_label.text == "摧毁尤里的城堡" and world.hud.timer_label.text.is_empty(), "读档后不再把已完成的基地进度当成当前目标")
			var castles: Array = world.buildings.filter(func(b): return world.actor_alive(b) and b.building_id == world.HeadGames.CASTLE)
			check(castles.size() == 1 and castles[0].side == "enemy", "城堡仍是存活的敌方建筑")
			if castles.size() == 1:
				var radar = world.hud.minimap
				var marks: Array = radar.objective_marks()
				check(marks.size() == 1 and marks[0].actor == castles[0] and radar._focus_point(marks[0].local).is_equal_approx(castles[0].position), "小地图只标城堡且可点中准确位置")
				check(world.CampaignMarks.marks(world, false).size() == 1, "战场同步绘制城堡目标")
				if OS.has_environment("S07_OBJECTIVE_PNG") and DisplayServer.get_name() != "headless":
					world.center_on(castles[0].position)
					for i in 4: await tree.process_frame
					await RenderingServer.frame_post_draw
					get_viewport().get_texture().get_image().save_png(OS.get_environment("S07_OBJECTIVE_PNG"))
				castles[0].receive_hit(100000)
				world._check_end()
				world.hud._refresh_timer()
				check(world.hud.wave_label.text == "尤里的城堡已摧毁" and not world.ended, "城堡被毁后显示完成，保留胜利演出")
				check(world.CampaignMarks.marks(world, false).is_empty() and radar.objective_marks().is_empty(), "城堡毁后立即撤下两处标记")
				world.allied_state.head_media_clock += 12.1
				world._check_end()
				check(world.ended, "冷读档城堡被毁后进入结算")
		tree.quit(failed)
		return
	if "--cold-intro" in args:
		var slot := args[args.find("--cold-intro") + 1]
		await cold_intro(slot)
		tree.quit(failed)
		return
	var menu = load("res://scenes/campaign_command.tscn").instantiate()
	tree.root.add_child(menu)
	for btn in menu.find_children("*","Button",true,false):
		if btn.text == "苏军战役" and not btn.disabled: btn.pressed.emit(); break
	for btn in menu.find_children("*","Button",true,false):
		if btn.text=="首脑游戏":btn.pressed.emit();break
	check(menu.mission.get("id") == "yr_head_games", "任务入口")
	var level:OptionButton=menu.find_children("*","OptionButton",true,false)[0]
	level.select(2)
	level.item_selected.emit(2)
	for btn in menu.find_children("*","Button",true,false):
		if btn.text == "出击": btn.pressed.emit(); break
	await tree.scene_changed
	var world = tree.current_scene.battle
	if "--write-broken-bridge" in args:
		var span: Rect2 = BridgeDamage.spans(world)[0]
		var section: Rect2 = BridgeDamage.sections(world, span)[1]
		BridgeDamage.damage_section(world, section, BridgeDamage.strength())
		check(BridgeDamage.health(world, section) <= 0.0, "第七关低桥中段断裂")
		check(BattleSaves.save_slot(world, "slot1").ok, "写盘第七关低桥断点")
		tree.quit(int(failed > 0))
		return
	var opening = world.get_node_or_null("HollywoodFilm")
	check(opening!=null and opening.clip_id=="S07_F00E" and opening.player.is_playing() and tree.paused,"战前全屏原片开始播放并暂停战场")
	if "--write-intro" in args:
		check(BattleSaves.save_slot(world, "slot1").ok, "全屏简报中写盘")
	opening.skip.pressed.emit()
	if "--write-intro" in args:
		check(BattleSaves.save_slot(world, "slot2").ok, "影片切换间隙写盘")
	await tree.process_frame
	await tree.process_frame
	var radio = world.get_node_or_null("HollywoodFilm")
	check(radio!=null and radio.clip_id=="S07_P01E" and radio.player.is_playing() and not tree.paused,"雷达通讯开始播放并恢复战场")
	if "--write-intro" in args:
		check(BattleSaves.save_slot(world, "slot3").ok, "雷达通讯中写盘")
		radio.skip.pressed.emit()
		check(BattleSaves.save_slot(world, "quick").ok, "雷达通讯已结束时写盘")
		tree.quit(failed)
		return
	if "--media" in OS.get_cmdline_user_args():
		while radio.player.stream_position<6 and radio.player.is_playing(): await tree.process_frame
		if DisplayServer.get_name()!="headless": await RenderingServer.frame_post_draw
		var box:Rect2=radio.player.get_global_rect()
		var size:Vector2=get_viewport().get_visible_rect().size
		check(box.get_center().x>size.x*0.75 and box.get_center().y<size.y*0.3 and box.size.y>80,"简报续音期间右上角仍显示人物")
		check(not radio.subtitle.text.is_empty() and radio.subtitle.get_global_rect().get_center().y>size.y*0.8,"简报续音带底部中文字幕")
		if OS.has_environment("S07_RADAR_SCREEN"): get_viewport().get_texture().get_image().save_png(OS.get_environment("S07_RADAR_SCREEN"))
		await radio.player.finished
		check(world.allied_state.get("head_intro_done",false),"完整通讯自然播完后继续战场")
	else: radio.skip.pressed.emit()
	if "--castle-rubble" in OS.get_cmdline_user_args():
		var target = world.buildings.filter(func(b): return b.building_id == world.HeadGames.CASTLE)[0]
		var point: Vector2 = target.position
		world.allied_state.erase("head_brief_stage")
		world.center_on(point)
		world.fog._reveal("ally", point, 2000, 8)
		target.receive_hit(100000)
		await tree.process_frame
		var ruins = tree.get_nodes_in_group("yr_building_rubble").filter(func(r): return r.position == point)
		check(ruins.size() == 1, "城堡摧毁后留下废墟")
		if not ruins.is_empty():
			await RenderingServer.frame_post_draw
			check(ruins[0].visible and ruins[0].frame == 3 and ruins[0].has_meta("shp_detail_textures"), "战场绘制城堡废墟双倍细节页")
			if OS.has_environment("S07_CASTLE_PNG"):
				get_viewport().get_texture().get_image().save_png(OS.get_environment("S07_CASTLE_PNG"))
		tree.quit(failed)
		return
	if "--release-perf" in OS.get_cmdline_user_args():
		var refreshes := [0]
		Events.selection_changed.connect(func(_units): refreshes[0] += 1)
		for beacon in world.buildings.filter(func(b): return b.building_id == world.HeadGames.BEACON):
			var wing: int = beacon.special.head_games_beacon
			var actors: Array = (world.units + world.buildings).filter(func(a): return world.actor_alive(a) and a.special.get("head_games_wing", -1) == wing and a != beacon)
			refreshes[0] = 0
			var start := Time.get_ticks_usec()
			beacon.receive_hit(100000)
			world._check_end()
			print("RELEASE wing=%d actors=%d ms=%.2f selection=%d" % [wing, actors.size(), (Time.get_ticks_usec()-start)/1000.0, refreshes[0]])
			check(refreshes[0] == 1, "整批转交只刷新一次选择面板")
			check(actors.size() > 10 and actors.all(func(a): return a.side == "ally"), "整翼单位与建筑转交玩家")
		tree.quit(failed)
		return
	if "--routes" in OS.get_cmdline_user_args():
		var orders=world.HeadGames.Orders
		var state:Dictionary=world.allied_state
		state.head_deployed=0
		state.head_media_clock=61
		orders.tick(world,61)
		var reached:=false
		for frame in 1600:
			await tree.physics_frame
			if state.s07_routes.any(func(r):return r.resident==null):reached=true;break
		check(reached,"居民自行沿地面路线进入回收厂")
		var codec=preload("res://scripts/save/battle_snapshot.gd").new()
		var snapshot:Dictionary=codec.capture(world)
		check(BattleSaves.validate(snapshot)=="","输送过程可保存")
		codec.restore(world,snapshot)
		var routes:Array=world.allied_state.s07_routes
		check(routes.size()==9 and routes.any(func(r):return world.actor_alive(r.resident) and world.actor_alive(r.plant)),"读档恢复在途居民与对应厂房")
		orders.tick(world,float(world.allied_state.head_media_clock))
		var sites=preload("res://scripts/world/head_games_sites.gd")
		sites.super_site(world,"csof128")
		var launcher=world.buildings.filter(func(b):return b.building_id=="YAGNTC")[0]
		var target=world.spawn_unit("E2","ally",launcher.position+Vector2(240,100))
		world.fog.rebuild()
		launcher._sw_charge=launcher.sw_recharge()
		orders.tick(world,75)
		check(not world.actor_alive(target) and launcher._sw_charge==0,"敌方基因突变器充满后自动选中可见步兵并发射")
		tree.quit(failed)
		return
	if "--orders" in OS.get_cmdline_user_args():
		var orders=world.HeadGames.Orders
		var state:Dictionary=world.allied_state
		state.head_deployed=0
		orders.tick(world,61)
		check(state.s07_routes.size()==9 and state.s07_routes.all(func(r):return world.actor_alive(r.house) and world.actor_alive(r.plant) and world.actor_alive(r.resident)),"九条路线由各自房屋生成居民或牛")
		if OS.has_environment("S07_COW_PNG"):
			var cow=state.s07_routes[4].resident
			check(cow.unit_id=="COW" and not cow._ra2.is_empty(),"农舍路线使用原版奶牛贴图")
			state.erase("head_brief_stage")
			world.spawn_unit("E2","ally",cow.position+Vector2(60,40))
			world.fog.rebuild()
			world.fog.hide()
			world.view_zoom=1.5
			Iso.apply_to(world.camera,world.view_zoom)
			world.center_on(cow.position)
			cow.show()
			for frame in 5: await tree.process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(OS.get_environment("S07_COW_PNG"))
		var route:Dictionary=state.s07_routes[0]
		var gate:Vector2=route.gate
		route.resident.position=gate
		var balance:float=world.enemy_funds
		orders.tick(world,62)
		check(route.resident==null and world.enemy_funds>balance,"到厂消耗居民并结算资金")
		route.house.receive_hit(100000)
		orders.tick(world,123)
		check(route.resident==null,"来源房屋被毁后停止该路线")
		for wing in [-1,0,1]:
			orders.dispatch(world,wing)
			check(state.has("s07_ai_last_%d"%wing),"房号 %d 选择原图 AI 编组"%wing)
		orders.advance_production(world)
		var factories=world.buildings.filter(func(b):return b.special.has("s07_building_unit"))
		check(not factories.is_empty(),"AI 选队后由所属工厂排产")
		if not factories.is_empty():
			var factory=factories[0]
			var product:String=factory.special.s07_building_unit
			var wing:int=factory.special.get("head_games_wing",-1)
			factory._tick_unit_queue(1000,product)
			check(state.s07_ai_jobs[wing].members.any(func(u):return world.actor_alive(u) and u.unit_id==product),"AI 工厂出兵并编入待出动队伍")
		var plant=world.buildings.filter(func(b):return b.building_id=="YAPOWR")[0]
		for frame in 450:
			await tree.physics_frame
			if plant.special.get("occupants",[]).size()>0:break
		check(plant.special.get("occupants",[]).size()>0,"生物反应炉实际进入步兵")
		var crypt=world.buildings.filter(func(b):return b.building_id=="CATRAN02")[0]
		crypt.receive_hit(100000)
		check(not world.get_node("TransylvaniaLights/CATRAN02").visible and world.get_node("TransylvaniaLights/CATRAN01").visible,"西墓室摧毁只熄灭西灯")
		var yard=orders.nearest(world,"YACNST",Vector2.ZERO,-1)
		yard.receive_hit(100000)
		state.head_super_start=0
		state.head_media_clock=900
		world.HeadGames.media_events(world)
		check(state.has("s07_no_yard_-1") and not world.buildings.any(func(b):return world.actor_alive(b) and b.building_id in ["YAGNTC","YAPPET"]),"尤里建造场被毁取消两座超武")
		check(BattleSaves.validate(preload("res://scripts/save/battle_snapshot.gd").new().capture(world))=="","路线及驻军快照通过校验")
		for u in world.units.duplicate():
			if world.actor_alive(u) and u.side=="ally" and u.unit_id=="SMCV":u.receive_hit(100000)
		world._check_end()
		check(not world.ended,"失去基地车但有部队仍能作战")
		for u in world.units.duplicate():
			if world.actor_alive(u) and u.side=="ally": AlliedAbilities.consume(u)
		world._check_end()
		check(world.ended,"部队与建筑全灭后失败")
		tree.quit(failed)
		return
	if "--nuke-voice" in OS.get_cmdline_user_args():
		var state:Dictionary=world.allied_state
		var point:Vector2=world.player_start()+Vector2(400,200)
		Ra2Sfx.stop_eva()
		var captured=world._place_building("NAMISL","enemy",point,true)
		AlliedAbilities.change_side(captured,"ally")
		world.HeadGames.media_events(world)
		check(not state.has("head_super_start"),"缴获核弹井不会提前消耗尤里台词")
		AlliedAbilities.change_side(captured,"enemy")
		world.struct_ready.NAMISL=1
		check(not state.has("head_super_start"),"核弹井待放置时尚未触发")
		var silo=world.deliver_ready_structure("NAMISL","ally",point+Vector2(350,0))
		check(silo!=null and state.has("head_super_start") and Ra2Sfx._eva_player.playing and Ra2Sfx._eva_player.stream.resource_path.ends_with("/xs7yu01.wav"),"玩家建成核弹井，播放尤里专属原声")
		var plays:int=Ra2Sfx.a_eva_plays
		world.strategic_site_completed(silo,true)
		check(plays==Ra2Sfx.a_eva_plays and Ra2Sfx._eva_queue.is_empty(),"重复落成通知不会重播")
		for scenario_level in [0,1,2]:
			for freed in 4:
				state.erase("head_super_start")
				for wing in 2:
					var key="head_games_freed_%d"%wing
					if freed & (1<<wing):state[key]=true
					else:state.erase(key)
				BattleRequest.skirmish_config.difficulty=scenario_level
				Ra2Sfx.stop_eva()
				world.strategic_site_completed(silo,true)
				check(Ra2Sfx._eva_player.playing==(scenario_level>0 and freed!=3),"难度 %d，解放状态 %d"%[scenario_level,freed])
		tree.quit(failed)
		return
	if "--sites" in OS.get_cmdline_user_args():
		var retail = preload("res://data/head_games_sites.json").data
		var native = world.NativeMaps.data("yr_sov07")
		for row in retail.sites:
			var id: String = "SOV07_BEACON" if row[0]=="NAPSYB" else row[0]
			var neutral: bool = row[4]=="Civilian House"
			var definition: Dictionary = native.site_types[id] if neutral else GameData.get_building(id)
			var dims = str(definition.get("foundation","1x1")).split("x")
			var p := Vector2(row[1],row[2])*55+Vector2(1-int(dims[1]),int(dims[0])-1)*27.5
			check(world.buildings.any(func(b):return b.building_id==id and b.position.distance_to(p)<1 and (b.side=="neutral")==neutral and is_equal_approx(b.hp/b.max_hp,float(row[3])/256) and not b._ra2.is_empty()),"原图建筑 %s %s"%[id,p])
		for row in retail.overlaySites:
			var p := Vector2(row[1],row[2])*55
			check(world.buildings.any(func(b):return b.building_id==row[0] and b.position==p and not b._ra2.is_empty()),"围栏 %s %s"%[row[0],p])
		check(world.get_node("TransylvaniaLights").get_child_count()==16,"原图16个光源")
		world.allied_state.head_super_start=0
		world.allied_state.head_media_clock=650
		world.HeadGames.media_events(world)
		for id in ["NAMISL","GAWEAT","YAPPET","YAGNTC"]:
			check(world.buildings.any(func(b):return b.building_id==id and b.side=="enemy" and not b._ra2.is_empty()),id+" 任务建造")
		if "--sites-photo" in OS.get_cmdline_user_args():
			var village := Vector2(113.5,145.5)*55
			world.allied_state.erase("head_brief_stage")
			world.center_on(village)
			world.fog._reveal("ally",village,2000,8)
			world.fog.visible=false
			if world.has_node("HollywoodFilm"): world.get_node("HollywoodFilm").skip.pressed.emit()
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(OS.get_environment("TEMP").path_join("s07-village-sites.png"))
		print("SITES_DONE ",failed)
		tree.quit(failed)
		return
	if "--building-art" in OS.get_cmdline_user_args():
		for id in ["YAPSYT", "YATECH", "CASLAB", "SOV07_BEACON", "NACLON"]:
			var sites = world.buildings.filter(func(b): return b.building_id == id)
			check(not sites.is_empty(), id + " 原图建筑")
			for site in sites:
				check(not site._ra2_anim.is_empty(), id + " 装配动画层")
				for layer in site._ra2_anim:
					var texture = RA2Art.art(layer.image).get("tex")
					check(texture != null and site._layer_visible(layer.kind), id + " 可见贴图 " + str(layer.image))
		tree.quit(failed)
		return
	if "--combine" in OS.get_cmdline_user_args():
		var combo = preload("res://scripts/world/head_games_combine.gd")
		combo.tick(world,450,2,[])
		check(world.allied_state.combo_alpha_due == 690,"困难计时启动混编")
		combo.advance(world,"alpha",690,2)
		var car = combo.recruit(world,"FV","alpha0/0car")
		var crew = combo.recruit(world,"SHK","alpha0/0crew")
		car.position = combo.MEET + Vector2(72,0)
		crew.position = car.position + Vector2(12,0)
		car.order_stop()
		combo.advance(world,"alpha",691,2)
		crew.logistics.tick(0.1)
		check(crew.embarked_in == car,"实际磁暴步兵登敌军多功能车")
		combo.advance(world,"alpha",692,2)
		var electric_id: String = car._active_weapon().get("ra2_weapon_id", "")
		check(world.allied_state.has("head_combo_voice") and electric_id.ends_with("CRElectricBolt") and GameData.ra2_beam_spec(electric_id).get("kind") == "yr_bolt", "会合播报与实装电弧 " + electric_id)
		combo.advance(world,"beta",800,2)
		for row in [["GAWEAP","FV"],["NAHAND","IVAN"]]:
			var factory = world.buildings.filter(func(b): return b.building_id == row[0])[0]
			check(factory.production.has(row[1]),"敌军工厂增产 " + row[1] + " " + factory.queue_block_reason(row[1]))
			var count: int = world.units.size()
			factory._tick_unit_queue(1000,row[1])
			check(world.units.size() == count+1 and world.units.back().unit_id == row[1] and world.units.back().special.has("head_games_wing"), "付费出厂 " + row[1])
		# Exercise truck load/unload and actual IFV transformation at the retail meeting points.
		for n in 40:
			combo.advance(world,"beta",801+n,2)
			for b in world.buildings:
				if b.side == "enemy" and not b.production.is_empty(): b._tick_unit_queue(1000,b.production[0])
			for u in world.units:
				if not str(u.special.get("combo_slot"," ")).begins_with("beta0/"): continue
				if u.embarked_in != null: continue
				if is_instance_valid(u.logistics.boarding): u.position = u.logistics.boarding.position + Vector2(10,0)
				elif u.has_move_order: u.position = u.move_target
				u.velocity = Vector2.ZERO
				u.logistics.tick(1)
			if world.allied_state.get("combo_beta_cycle",0)>0: break
		var weapons := []
		for u in world.units:
			if u.unit_id == "FV" and str(u.special.get("combo_slot"," ")).begins_with("beta0/"):
				weapons.append(str(u._active_weapon().get("ra2_weapon_id", "")).trim_prefix("YR_CAP_"))
		check(world.allied_state.get("combo_beta_cycle",0)==1 and weapons.count("CRElectricBolt")==3 and weapons.count("CRFlakGuyGun")==1 and weapons.count("CRNuke")==1,"五车完成换乘并出击 " + str(weapons))
		tree.quit(failed)
		return
	if "--media" in OS.get_cmdline_user_args():
		for id in GameData.HEAD_PRODUCTS.YABRCK+GameData.HEAD_PRODUCTS.YAWEAP:
			for cue in ["select","move","attack"]:
				check(Ra2Sfx.play_voice(GameData.get_unit(id),cue,Vector2.INF,0),id+" 应答 "+cue)
		for clip in ["xs7so04","xs7so01","xs7so02","xs7yu01","xs7yu02","s07_p01","csof120","csof016","csof001","csof010","csof125","csof128"]:
			Ra2Sfx.stop_eva()
			check(Ra2Sfx.play_head_games_line(clip) and Ra2Sfx._eva_player.playing,"任务电台播放 "+clip)
		await tree.process_frame
		world.allied_state.head_super_start=0.0
		world.allied_state.head_media_clock=700.0
		world.HeadGames.media_events(world)
		var warning = world.get_node_or_null("HollywoodFilm")
		check(warning!=null and warning.clip_id=="S07_P02E" and warning.player.is_playing(),"基因突变器通讯原片")
		warning.skip.pressed.emit()
		await tree.process_frame
		world.end_battle(true)
		for btn in tree.current_scene.result_overlay.find_children("*","Button",true,false):
			if btn.text=="查看结算":btn.pressed.emit();break
		var ending=world.get_node_or_null("HollywoodFilm")
		check(ending!=null and ending.clip_id=="S08_F00E" and ending.player.is_playing(),"胜利结算后播放苏军终章")
		ending.skip.pressed.emit()
		check(not tree.paused,"结束影片后结算界面可操作")
		tree.quit(failed)
		return

	check(world.units.any(func(u):return u.side=="ally" and u.unit_id=="SMCV") and world.map_layout()=="yr_sov07", "苏军开局")
	check(BattleRequest.skirmish_config.difficulty==2 and world.units.any(func(u):return u.unit_id=="APOC" and u.special.get("head_games_wing",-1)==0),"困难守军有天启坦克")
	check(world.units.filter(func(u):return u.side=="ally").all(func(u):return (world.NativeMaps.flags("yr_sov07",u.position)&1)!=0),"全队在可玩地面入场")
	check(world.get_node("TransylvaniaScenery").get_child_count()==773 and world.fog!=null,"地图场景物与迷雾")
	if "--contacts" in OS.get_cmdline_user_args():
		var goal:Vector2=world.player_start()
		var garrison=world.units.filter(func(u):return u.side=="enemy" and u.unit_id=="BRUTE" and u.position.distance_to(goal)<2600)
		check(not garrison.is_empty() and not garrison[0].hold_position and garrison[0].fire_stance=="free","前沿狂兽人执行区域警戒")
		var groups := []
		for wing in 3:
			var first:int=world.units.size()
			world.HeadGames.attack_team(world,wing)
			groups.append(world.units.slice(first))
			var expected:=HouseColor.mission_color("enemy",wing if wing<2 else -1)
			check(groups[wing].all(func(u):return u._col.is_equal_approx(expected) and u.material.get_shader_parameter("target_color").is_equal_approx(expected)),"进攻编组房色 %d"%wing)
			print("ROUTE ",wing," start ",groups[wing][0].position," goal ",goal," path ",groups[wing][0]._path_pts.size())
		var mcv=world.units.filter(func(u):return u.unit_id=="SMCV" and u.side=="ally")[0]
		check(mcv._col.is_equal_approx(Color.from_hsv(0,230.0/255,1)),"玩家使用零售 DarkRed")
		var near := [INF,INF,INF]
		var contact := [false,false,false]
		for step in 3600:
			await tree.physics_frame
			for wing in 3:
				for unit in groups[wing]:
					if not world.actor_alive(unit):continue
					near[wing]=minf(near[wing],unit.position.distance_to(goal))
					if world.actor_alive(unit.attack_target) and unit.attack_target.side=="ally": contact[wing]=true
			if not contact.has(false): break
		for wing in 3: check(contact[wing],"实际锁定我军 %d，距集合点最近 %.1f 格"%[wing,near[wing]/55])
		tree.quit(failed)
		return
	if "--outline" in OS.get_cmdline_user_args():
		var mcv = world.units.filter(func(u):return u.side=="ally" and u.unit_id=="SMCV")[0]
		world.center_on(mcv.position)
		world.attack_target_outlines.refresh(world)
		mcv.queue_redraw()
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var outline = mcv.get_node_or_null("SelectionOutline")
		check(mcv._col.is_equal_approx(Color.from_hsv(0,230.0/255,1)),"基地车原图红色涂装")
		check(outline != null and outline.visible and outline.used > 0 and outline.get_child(0).material.get_shader_parameter("outline_color").is_equal_approx(outline.OWN_COLOR),"基地车黄色识别描边")
		tree.quit(failed)
		return
	if "--opening" in OS.get_cmdline_user_args():
		for frame in 1100:
			await tree.physics_frame
			if frame>300 and not world.allied_state.has("head_brief_stage") and world.units.any(func(u):return u.unit_id=="SMCV" and u.position.distance_to(world.player_start())<80): break
		var mcv=world.units.filter(func(u):return u.side=="ally" and u.unit_id=="SMCV")[0]
		if OS.has_environment("HEAD_GAMES_OPENING_PNG"):
			world.center_on(mcv.position)
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(OS.get_environment("HEAD_GAMES_OPENING_PNG"))
		check(world.construction_deploy_check(mcv).ok and mcv.position.distance_to(world.player_start())<100,"自然抵达后地基可展开")
		mcv.position = Vector2(43.5,148.5)*55
		world.HeadGames.recover_entry(world)
		check(mcv.position.distance_to(world.player_start())<1,"旧档边界外基地车回到原图集合点")
		check(mcv.position.distance_to(world.player_start())<100 and world.deploy_construction_vehicle(mcv),"基地车抵达原图17号航点并实际展开")
		world.credit_side("ally",40000)
		var capture := func(site):
			var engineer = world.spawn_unit("SENGINEER", "ally", site.position + Vector2(120, 0))
			engineer.position = AlliedAbilities.approach(engineer, site)
			world.fog.rebuild()
			if not engineer.order_interaction("allied_engineer", site, false): return false
			AlliedAbilities.tick_action(engineer, 1.0)
			return site.side == "ally" and not world.actor_alive(engineer)
		var prerequisites := {"VIRUS":"GAAIRC", "YURIPR":"YATECH", "MIND":"YATECH", "TELE":"NAPSIS", "DISK":"YATECH"}
		for factory_id in ["YABRCK","YAWEAP"]:
			var factory=world.buildings.filter(func(b):return b.building_id==factory_id)[0]
			check(capture.call(factory), "苏军工程师占领 " + factory_id)
			world.select_building(factory)
			for id in GameData.HEAD_PRODUCTS[factory_id]:
				world.hud.prod_tab=world.hud._unit_cat(GameData.get_unit(id))
				world.hud._refresh_production()
				world.hud._update_production_live()
				var button=world.hud._prod_buttons.get(id)
				if prerequisites.has(id):
					var prerequisite_id: String = prerequisites[id]
					var site = world.buildings.filter(func(b): return b.building_id == prerequisite_id)[0]
					if site.side != "ally":
						check(is_instance_valid(button) and button.disabled and factory.queue_block_reason(id).contains(GameData.prereq_name(prerequisite_id)), "缺少前置时卡片锁定 " + id)
						check(capture.call(site), "工程师占领科技前置 " + prerequisite_id)
						world.select_building(factory)
						world.hud._refresh_production()
						world.hud._update_production_live()
						button = world.hud._prod_buttons.get(id)
				check(is_instance_valid(button) and not button.disabled and ResourceLoader.exists(GameData.ra2_cameo_path(id)),"可点击的原版生产卡 "+id+" "+factory.queue_block_reason(id))
				if is_instance_valid(button) and not button.disabled:
					var before:int=world.units.filter(func(u):return u.side=="ally" and u.unit_id==id).size()
					button.pressed.emit()
					factory._tick_unit_queue(500,id)
					check(world.units.filter(func(u):return u.side=="ally" and u.unit_id==id).size()==before+1,"从占领设施出兵 "+id)
			AlliedAbilities.change_side(factory,"enemy")
			check(not world.hud._unit_catalog().has(GameData.HEAD_PRODUCTS[factory_id][0]),"失去设施后撤下生产卡")
		tree.quit(failed)
		return
	for difficulty in 3:
		BattleRequest.skirmish_config.difficulty=difficulty
		world.allied_state.head_scenario_time=90.0
		world.allied_state.head_deployed=0.0
		world.allied_state.head_attack_stage=2
		world.allied_state.erase("head_attack_done")
		world.HeadGames.attackers(world,0)
		var before:int=world.units.size()
		world.HeadGames.attackers(world,75)
		check(world.units.size()-before==(22 if difficulty==2 else 0),"额外进攻困难提前，难度 %d"%difficulty)
		world.HeadGames.attackers(world,90)
		check(world.units.size()-before==(0 if difficulty==0 else 22),"第二轮进攻只出现一次，难度 %d"%difficulty)
	var backdoor:Array=world.HeadGames.FIELD.data.backdoor_cells[0]
	var scout=world.spawn_unit("E2","ally",(Vector2(backdoor[0],backdoor[1])+Vector2.ONE*0.5)*55)
	world.HeadGames.field_events(world,1.0)
	check(world.allied_state.has("head_backdoor"),"侦察进入原版后门触发格")
	var grinder=world.buildings.filter(func(b):return b.special.get("head_grinder")=="sw")[0]
	scout.position=grinder.position+Vector2(80,0)
	world.fog.rebuild()
	world.HeadGames.field_events(world,1.0)
	check(world.allied_state.has("head_seen_sw"),"发现西南回收厂调出守军")
	grinder.receive_hit(100000)
	check(world.allied_state.has("head_grinder_lost_sw"),"摧毁回收厂调出反击编组")
	var beacons = world.buildings.filter(func(b):return b.building_id == world.HeadGames.BEACON)
	var castle = world.buildings.filter(func(b):return b.building_id == world.HeadGames.CASTLE)[0]
	castle.receive_hit(120)
	world._check_end()
	check(world.allied_state.get("castle_alert",false) and world.units.any(func(u):return u.unit_id=="YENGINEER"),"城堡受袭召集原版守军")
	var bridge = preload("res://scripts/world/bridge_damage.gd")
	var span: Rect2 = bridge.spans(world)[0]
	var section: Rect2 = bridge.sections(world,span)[1]
	bridge.damage_section(world,section,100000)
	check(bridge.health(world,section)<=0,"低桥中段可被摧毁")
	var huts = world.buildings.filter(func(b):return b.building_id=="CABHUT" and b.special.get("bridge_span")==span)
	check(huts.size()==2,"两端维修小屋连接同一座桥")
	preload("res://scripts/world/civilian_sites.gd").repair(huts[0])
	check(bridge.health(world,section)>0,"低桥修复恢复耐久")
	var crossing = world.spawn_unit("HTNK","ally",Vector2(27.5,114.5)*55)
	var bank := Vector2(27.5,123.5)*55
	crossing.order_move(bank)
	var crossed := false
	for i in 900:
		await tree.physics_frame
		if crossing.position.distance_to(bank)<40:
			crossed=true
			break
	check(crossed,"犀牛坦克由一侧引道驶过修复的低桥")
	var brute = world.units.filter(func(u):return world.actor_alive(u) and u.unit_id == "BRUTE")[0]
	check(beacons.size()==2 and not brute._ra2.is_empty() and not castle._ra2.is_empty() and not beacons[0]._ra2.is_empty(),"驻军和目标贴图")
	check(brute._weapon_for_target(world.units.filter(func(u):return world.actor_alive(u) and u.unit_id=="HTNK")[0]).name == "Smash", "狂兽人攻击车辆")
	for i in world.waves.size(): world._spawn_wave(i)
	for id in ["VIRUS","YURIPR","MIND","TELE","DISK","CAOS"]:
		check(world.units.any(func(u):return world.actor_alive(u) and u.unit_id==id and not u._ra2.is_empty()),"本关单位 "+id)
	var find_unit = func(id):return world.units.filter(func(u):return world.actor_alive(u) and u.unit_id==id)[0]
	var master = find_unit.call("MIND")
	var victims = world.units.filter(func(u):return world.actor_alive(u) and u.side=="ally" and u.unit_id=="HTNK")
	for target in victims: AlliedAbilities.special_shot(master,target,master.weapon)
	check(master.special.get("mind_links",[]).size()==victims.size() and victims[0].side=="enemy", "精神控制车同时控制两辆坦克")
	master.receive_hit(100000)
	for target in victims: AlliedAbilities.tick_actor(target,0.1)
	check(victims.all(func(u):return u.side=="ally"),"控制车阵亡后恢复阵营")
	var mag = find_unit.call("TELE")
	AlliedAbilities.special_shot(mag,victims[0],mag.weapon)
	check(victims[0].special.has("magnet_source") and mag._weapon_for_target(castle).name=="MagneShake","磁力牵引与对建筑武器")
	var prime = find_unit.call("YURIPR")
	var plant = world._place_building("NAPOWR","ally",world.player_start()+Vector2(500,0),true)
	AlliedAbilities.special_shot(prime,plant,prime.weapon)
	check(plant.side=="enemy", "尤里改控制电厂")
	AlliedAbilities.release_control(prime)
	var disc = find_unit.call("DISK")
	AlliedAbilities.special_shot(disc,plant,disc._weapon_for_target(plant))
	check(world.side_power_low("ally") and plant.side=="ally", "镭射幽浮吸取电力")
	var chaos = find_unit.call("CAOS")
	AlliedAbilities.special_shot(chaos,victims[0],chaos.weapon)
	check(victims[0].special.has("chaos_seconds") and victims[0].attack_target!=null,"混乱气体促使友军互攻")
	var virus = find_unit.call("VIRUS")
	var soldier = world.spawn_unit("E2","ally",world.player_start()+Vector2(400,400))
	var neighbor = world.spawn_unit("E2","ally",soldier.position+Vector2(25,0))
	var hp:float=neighbor.hp
	AlliedAbilities.special_shot(virus,soldier,virus.weapon)
	soldier.receive_hit(100000,"bullet",{},virus)
	check(neighbor.hp<hp,"病毒狙击击杀波及邻近步兵")
	check(world.buildings.filter(func(b):return b.building_id=="YAPSYT").size()==7,"原图七座心灵控制塔")
	var snap = preload("res://scripts/save/battle_snapshot.gd").new().capture(world)
	check(BattleSaves.validate(snap)=="", "存档校验 " + BattleSaves.validate(snap))
	var brief_titles := ["摧毁尤里的城堡", "摧毁盟军心灵信标", "摧毁苏军心灵信标"]
	for i in 4:
		if world.allied_state.has("head_brief_stage"):
			world.HeadGames.briefing(world, 4.0)
			var stage := int(world.allied_state.get("head_brief_stage", -1))
			if stage >= 1:
				var marks: Array = world.hud.minimap.objective_marks()
				check(marks.size() == 1 and marks[0].title == brief_titles[stage - 1], "简报标注当前介绍的地点 %d" % stage)
	check(world.hud.minimap.objective_marks().size() == 2, "进入战斗后同时标注两座心灵信标")
	world.hud._refresh_timer()
	check(world.hud.wave_label.text.begins_with("摧毁心灵信标") and world.hud.timer_label.text == "已解放基地 0 / 2", "战场顶栏显示解放目标和初始进度")
	var freed := 0
	for beacon in beacons:
		var wing := int(beacon.special.head_games_beacon)
		beacon.receive_hit(100000)
		freed += 1
		world._check_end()
		check(world.units.filter(func(u):return world.actor_alive(u) and u.side=="ally" and u.special.get("head_games_wing",-1)==wing).size()>10 and world.buildings.any(func(b):return b.side=="ally" and b.special.get("head_games_wing",-1)==wing) and not world.ended,"解放部队 %d" % wing)
		world.hud._refresh_timer()
		if freed == 1:
			check(world.hud.timer_label.text == "已解放基地 1 / 2", "解放一翼后更新顶栏进度")
			var marks: Array = world.hud.minimap.objective_marks()
			check(marks.size() == 1 and int(marks[0].actor.special.head_games_beacon) != wing, "只保留另一座心灵信标标记")
		else:
			check(world.hud.wave_label.text == "摧毁尤里的城堡" and world.hud.timer_label.text.is_empty(), "解放两翼后顶栏切换为摧毁城堡")
			var marks: Array = world.hud.minimap.objective_marks()
			check(marks.size() == 1 and marks[0].actor == castle, "解放两翼后改标城堡")
	var results := []
	Events.battle_ended.connect(func(result):results.append(result),CONNECT_ONE_SHOT)
	castle.receive_hit(100000)
	world._check_end()
	check(results.is_empty(),"城堡被毁后保留战场收尾")
	world.allied_state.head_media_clock+=3
	world._check_end()
	world.allied_state.head_media_clock+=9.1
	world._check_end()
	check(results.size()==1 and results[0].win,"攻陷城堡结算")
	tree.quit(failed)
