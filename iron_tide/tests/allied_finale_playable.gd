extends Node

var failures := 0
var checks := 0
func expect(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("FINALE ", ok, " ", label)

func button(root, title: String):
	for control in root.find_children("*", "Button", true, false):
		if control.text == title: return control
	return null

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	var tree := get_tree()
	tree.current_scene = null # Keep this runner alive while the real menus replace scenes.
	for mode in ["cold-opening-gap","cold-opening-flight","cold-ai-queue","cold-superweapons"]:
		if "--"+mode in OS.get_cmdline_user_args():
			await restore_extra_boundary(mode)
			finish()
			return
	if "--slot5-cleanup" in OS.get_cmdline_user_args():
		var result := BattleSaves.load_into_scene("slot5")
		expect(result.ok,"隔离冷读存档5："+str(result.get("message","")))
		if not result.ok: finish(); return
		await tree.scene_changed
		var w = tree.current_scene.battle
		var hud = tree.current_scene.hud
		if w.paused: hud._toggle_pause()
		var subs: Array = w.units.filter(func(u): return w.AlliedFinale.cleanup_target(w,u,w.AlliedFinale.ENEMIES) and u.unit_id=="BSUB")
		expect(subs.size()==6,"原档仍剩六艘任务潜艇")
		hud._refresh_timer()
		expect(hud.wave_label.text.contains("6 艘"),"左上明确显示剩余潜艇数量")
		var marks: Array = hud.minimap.objective_marks()
		expect(marks.any(func(m):return m.title.begins_with("搜索海峡") and m.actor==null),"雷达给出海峡区域提示而非潜艇实体坐标")
		expect(subs.all(func(u):return not w.actor_visible_to("ally",u)),"未给潜艇直接开视野")
		w.AlliedFinale.tick(w,1.0)
		expect(not w.ended,"不能绕过潜艇直接胜利")
		for u in subs: u.hp=0
		w.AlliedFinale.tick(w,1.0)
		expect(hud.minimap.objective_marks().is_empty(),"最后一艘消灭后撤销搜索标记")
		w.AlliedFinale.tick(w,10.1)
		expect(w.ended and button(tree.current_scene,"查看结算")!=null,"清空潜艇后原胜利链进入结算")
		finish()
		return
	if "--slot4-armor" in OS.get_cmdline_user_args():
		var loaded := BattleSaves.load_into_scene("slot4")
		expect(loaded.ok,"使用隔离目录中的第4槽副本冷读："+str(loaded.get("message","")))
		if not loaded.ok: finish(); return
		await tree.scene_changed
		var w = tree.current_scene.battle
		if w.paused: tree.current_scene.hud._toggle_pause()
		var s: Dictionary = w.allied_state.allied_finale
		var ai: Script = w.AlliedFinale.AI
		expect("NAWEAP" in w.owned_building_ids() and is_equal_approx(float(s.raid_clock),71.977089),"原档确有苏军车厂且步兵计时冻结")
		ai.tick(w,s,89.0)
		expect(not s.has("armor_raid_index"),"装甲队不提前刷出")
		ai.tick(w,s,1.0)
		var boats: Array = w.units.filter(func(u):return w.actor_alive(u) and u.special.get("allied_finale_raid",{}).get("team")=="08D57B5C")
		expect(boats.size()==1 and boats[0].logistics.passengers.map(func(u):return u.unit_id)==["LTNK","LTNK","BRUTE"],"真实旧档派出首支原图装甲登陆队")
		if boats.size()==1:
			var boat=boats[0]
			var cargo: Array=boat.logistics.passengers.duplicate()
			ai.tick(w,s,90.0)
			expect(s.armor_raid_index==1,"上一艇尚未卸载，第二队即使到时也不会提前出发")
			for i in 6000:
				if i%30==0: ai.tick(w,s,0.5)
				if w.actor_alive(boat): boat._physics_process(1.0/60.0)
				for u in cargo:
					if w.actor_alive(u) and u.embarked_in==null: u._physics_process(1.0/60.0)
				if boat.logistics.passengers.is_empty(): break

			expect(boat.logistics.passengers.is_empty() and cargo.all(func(u):return w.actor_alive(u) and u.embarked_in==null),"运输艇完成卸载，两辆坦克和狂兽人全部上岸")
			w.AlliedFinale.tick(w,0.5)
			w.AlliedFinale.tick(w,0.5)
			expect(s.script.fired.has("096a485c") and boat.special.allied_finale_raid.return_dispatched, "卸载后由零售返航触发器下令")
			expect(s.armor_raid_index==2 and w.units.any(func(u):return w.actor_alive(u) and u.special.get("allied_finale_raid",{}).get("team")=="08D6BA4C"),"卸载后按原图接续第二支装甲登陆队")
		finish()
		return
	if "--cold-house-colors" in OS.get_cmdline_user_args():
		var loaded := BattleSaves.load_into_scene("slot6")
		expect(loaded.ok, "独立进程恢复红蓝双基地存档")
		if loaded.ok:
			await tree.scene_changed
			check_production_colors(tree.current_scene.battle)
		finish()
		return
	if "--cold-barracks" in OS.get_cmdline_user_args():
		var loaded := BattleSaves.load_into_scene("slot2")
		expect(loaded.ok, "冷读仅苏军建造场、两方兵营并存的存档")
		if not loaded.ok: finish(); return
		await tree.scene_changed
		var hud = tree.current_scene.hud
		var w = tree.current_scene.battle
		hud.select_prod_tab("infantry")
		expect(w.campaign_deck_factions() == ["soviet"] and hud._factories.candidates().size() == 2, "旧战场结构重建出两个可切换兵营")
		var other = hud._factories.candidates().filter(func(b): return b.building_id == "GAPILE")
		if not other.is_empty(): hud._factories.buttons[other[0].get_instance_id()].button.pressed.emit()
		expect("E1" in hud._prod_buttons and "E2" not in hud._prod_buttons, "读档后点盟军兵营切换步兵目录")
		finish()
		return
	if "--cold-dual" in OS.get_cmdline_user_args():
		var loaded := BattleSaves.load_into_scene("slot1")
		expect(loaded.ok, "冷读双基地存档")
		if not loaded.ok: finish(); return
		await tree.scene_changed
		var hud = tree.current_scene.hud
		hud.select_prod_tab("defense")
		var soviet: Button = hud.find_child("CampaignBaseSoviet", true, false)
		var allied: Button = hud.find_child("CampaignBaseAllied", true, false)
		expect(soviet.visible and allied.visible, "读档后两座建造场仍各有页签")
		allied.pressed.emit()
		expect(allied.button_pressed and "GAPILL" in hud._prod_buttons and "NALASR" not in hud._prod_buttons, "读档后仍可打开盟军防御目录")
		soviet.pressed.emit()
		expect(soviet.button_pressed and "NALASR" in hud._prod_buttons and "GAPILL" not in hud._prod_buttons, "读档后仍可切回苏军防御目录")
		var world = tree.current_scene.battle
		var red: Dictionary = world.current_structure_job("building", "soviet")
		var blue: Dictionary = world.current_structure_job("building", "allied")
		var red_paid: float = red.get("paid", 0.0)
		var blue_paid: float = blue.get("paid", 0.0)
		world._tick_structure_queue(1.0)
		expect(red_paid > 0.0 and blue_paid > 0.0 and red.get("paid", 0.0) > red_paid and blue.get("paid", 0.0) > blue_paid, "冷读保留两边已付进度，恢复后继续并行建造")
		finish()
		return
	if "--cold" in OS.get_cmdline_user_args():
		var loaded := BattleSaves.load_into_scene("quick")
		expect(loaded.ok, "独立进程读取真实快速存档：" + str(loaded.get("message", "")))
		if not loaded.ok: finish(); return
		await tree.scene_changed
		var restored = tree.current_scene.battle
		var state: Dictionary = restored.allied_state.get("allied_finale", {})
		expect(state.get("phase") == 2 and "NARADR" in restored.owned_building_ids("ally"), "恢复雷达与等待阶段")
		tree.current_scene.hud._refresh_production()
		tree.current_scene.hud._refresh_timer()
		expect(tree.current_scene.hud.wave_label.text.contains("等待超时空增援") and tree.current_scene.hud.timer_label.text.contains("倒计时"), "冷读立即恢复当前目标和计时")
		var restored_soviet: Button = tree.current_scene.hud.find_child("CampaignBaseSoviet",true,false)
		var restored_allied: Button = tree.current_scene.hud.find_child("CampaignBaseAllied",true,false)
		expect(restored_soviet.visible and restored_soviet.button_pressed and not restored_allied.visible, "冷读按实际建造场重建目录，不提前解锁盟军")
		if not state.is_empty():
			if restored.paused: tree.current_scene.hud._toggle_pause()
			var opening_team := func(u): return restored.actor_alive(u) and u.special.get("finale_defense_team","") in ["08FFE99C","08FFEC1C","0900E65C","0900B27C"]
			var defenders: int = restored.units.filter(opening_team).size()
			restored.AlliedFinale.tick(restored, 120)
			restored.AlliedFinale.tick(restored, 15)
			expect(restored.units.filter(func(u): return restored.actor_alive(u) and u.unit_id == "AMCV").size() == 1, "冷恢复后基地车只生成一次")
			expect(state.script.fired.has("09197edc") and ["0955dd2c","0ee0857c","078f61fc","061bd4ec"].all(func(id):return not state.script.fired.has(id) and not state.script.enabled.has(id)),"冷读保留零动作触发，四条关闭分支不补发")
			if state.get("base_defense_driver",false):
				expect(defenders==18 and restored.units.filter(opening_team).size()==defenders and ["0960ee5c","04f32afc","090ad17c"].all(func(id):return state.script.fired.has(id)),"独立冷读保留三条开场守军触发，不再派第二批")
		finish()
		return
	tree.change_scene_to_file("res://scenes/main.tscn")
	await tree.scene_changed
	button(tree.current_scene, "战 役").pressed.emit()
	await tree.scene_changed
	button(tree.current_scene, "盟军战役").pressed.emit()
	var entry = button(tree.current_scene, "脑死")
	expect(entry != null, "真实菜单列出终关")
	if entry == null: finish(); return
	entry.pressed.emit()
	button(tree.current_scene, "原版配置").pressed.emit()
	button(tree.current_scene, "出击").pressed.emit()
	await tree.scene_changed
	var world = tree.current_scene.battle
	if "--live-opening" in OS.get_cmdline_user_args():
		await check_live_opening(world)
		finish()
		return
	world.set_process(false)
	world.set_physics_process(false)
	var s: Dictionary = world.allied_state.get("allied_finale", {})
	expect(world.map_layout() == "yr_all07smd" and not s.is_empty(), "实际战场已装配")
	if s.is_empty(): finish(); return
	var opening = world.get_node_or_null("HollywoodFilm")
	expect(opening != null and opening.clip_id == "A07_F00E" and tree.paused, "出击挂载原版全屏片头并暂停")
	if opening != null: opening.skip.pressed.emit()
	await tree.process_frame
	await tree.process_frame
	if "--seed-opening-gap" in OS.get_cmdline_user_args():
		expect(int(s.media_stage)==2 and not world.has_node("HollywoodFilm") and not world.world_input_enabled(),"片头回调已完成、雷达简报尚未挂载")
		save_extra(world)
		finish()
		return
	world.AlliedFinale.tick(world,0.2)
	var radio = world.get_node_or_null("HollywoodFilm")
	expect(radio != null and radio.clip_id == "A07_P01E" and radio.mission_audio != null and not tree.paused, "跳过后进入雷达小窗与原声")
	if radio != null:
		radio._video_finished()
		expect(radio.hold_radio_frame and not radio.is_queued_for_deletion(), "画面结束后为续音保留小窗")
		radio.skip.pressed.emit()
	await tree.process_frame
	world.AlliedFinale.tick(world,1.0)
	var flight: Array = world.units.filter(func(u):return u.special.has("para_approach"))
	expect(flight.size()==1 and flight[0].position.distance_to(world.AlliedFinale.AI.waypoint(world,104))<55 and not world.world_input_enabled(),"运输机自原图界外入口进场，空投前未交还操作")
	if "--seed-opening-flight" in OS.get_cmdline_user_args():
		for i in 4200:
			step_opening(world,i)
			if world.units.any(func(u):return world.actor_alive(u) and u.special.get("finale_opening_engineer",false) and u.special.has("para_height")): break
		expect(not world.world_input_enabled() and world.units.any(func(u):return world.actor_alive(u) and u.special.get("finale_opening_engineer",false) and u.special.has("para_height")),"运输与降落伞中途保存")
		save_extra(world)
		finish()
		return
	for i in 4200:
		step_opening(world,i)
		if s.media_stage==0: break
	expect(world.AlliedFinale.OPENING_ROWS.all(func(id):return s.script.fired.has(id)), "七条开场任务由正式驱动执行")
	expect(s.media_stage == 0 and world.CampaignMarks.marks(world,true).any(func(m): return m.title == "接管苏军建造场"), "交还控制后雷达标注建造场")
	expect(world.get_node("AlliedFinaleScenery").get_child_count() > 200 and world.buildings.any(func(b): return b.building_id == "CAMACH" and not b._ra2.is_empty()), "实际战场挂载雪地景物和维修厂美术")
	check_opening_snow_art(world)
	if "--lose-tierra" in OS.get_cmdline_user_args() or "--lose-all" in OS.get_cmdline_user_args():
		await check_defeat(world,s,"--lose-all" in OS.get_cmdline_user_args())
		finish()
		return
	if "--opening-snow-art" in OS.get_cmdline_user_args(): finish(); return
	print("FINALE missing: ", s.missing)
	var yard = world.buildings.filter(func(b): return b.building_id == "NACNST" and b.side == "neutral")[0]
	var engineers: Array = world.units.filter(func(u): return u.unit_id == "ENGINEER" and u.side == "ally")
	expect(engineers.size() == 5 and is_equal_approx(yard.hp/yard.max_hp, 0.25), "零售工程师数量及建造场血量")
	if engineers.is_empty(): finish(); return
	var engineer = engineers[0]
	var orders = world.AlliedFinale.Orders
	world.fog.rebuild()
	var scout := false
	if not world.actor_visible_to("ally",yard):
		scout = true
		engineer.order_move(orders.approach(engineer,yard) + Vector2(85,0))
		for i in range(2400):
			if world.actor_visible_to("ally",yard): break
			engineer._physics_process(1.0/60.0)
			if i % 20 == 0: world.fog.rebuild()
	expect(world.actor_visible_to("ally",yard), "工程师可从落点侦察到建造场，需移动：%s" % scout)
	var origin: Vector2 = engineer.position
	expect(orders.use(engineer, "allied_engineer", yard), "接管使用真实工程师命令")
	for i in range(2400):
		if yard.side == "ally": break
		orders.tick_action(engineer, 1.0/60.0)
	expect(yard.side == "ally" and origin.distance_to(yard.position) > 50, "工程师向建筑门口行进后转属")
	if yard.side != "ally": finish(); return
	world.AlliedFinale.tick(world, 0.2)
	expect(s.phase == 1 and "NAPOWR" not in world.owned_building_ids("ally") and "NALASR" in world.owned_building_ids("ally"), "接管建造场只带关联炮塔转属，反应炉保持中立")
	var reactor = world.buildings.filter(func(b):return b.building_id=="NAPOWR" and b.side=="neutral")[0]
	var next_engineer = engineers.filter(func(u):return world.actor_alive(u))[0]
	world.fog.rebuild()
	orders.use(next_engineer,"allied_engineer",reactor)
	for i in 3600:
		if reactor.side=="ally": break
		orders.tick_action(next_engineer,1.0/60.0)
	expect(reactor.side=="ally" and "NAPOWR" in world.owned_building_ids("ally"),"另一名工程师到门后独立接管反应炉")
	if "--house-colors" in OS.get_cmdline_user_args():
		check_house_color_production(world,tree.current_scene.hud,yard)
		finish()
		return
	if "--last-five" in OS.get_cmdline_user_args():
		last_five(world,s)
		finish()
		return
	if "--closing" in OS.get_cmdline_user_args() or "--seed-ai-queue" in OS.get_cmdline_user_args():
		closing_branches(world,s,yard)
		finish()
		return
	if "--ai-tesla-engagement" in OS.get_cmdline_user_args():
		await ai_tesla_engagement(world,s)
		finish()
		return
	if "--ai-id-matrix" in OS.get_cmdline_user_args():
		await preload("res://tests/allied_finale_ai_matrix.gd").run(world,s,self)
		finish()
		return
	if "--enemy-ai" in OS.get_cmdline_user_args():
		enemy_ai(world,s,yard)
		finish()
		return
	var hud = tree.current_scene.hud
	hud._refresh_timer()
	expect(not hud.log_panel.visible and hud.wave_label.text.contains("矿石精炼场"), "情报收起时左上仍提示先造精炼场")
	var construction_marks: Array = world.CampaignMarks.marks(world,false)
	var construction_radar: Array = hud.minimap.objective_marks()
	expect(construction_marks.any(func(m):return m.actor==yard and m.color==world.CampaignMarks.GOLD and m.get("keep_over_building",false) and m.title.contains("精炼场")) and construction_radar.any(func(m):return m.actor==yard), "建造黄标在战场、雷达都指向火地岛建造场")
	if not construction_marks.is_empty():
		var p: Vector2 = world.CampaignMarks.screen_point(world.campaign_mark_overlay,world,construction_marks[0])
		var foot: Vector2 = world.get_canvas_transform()*yard.global_position
		expect(is_finite(p.y) and p.y < foot.y, "战场黄标投影在基地上方")
	hud.log_btn.pressed.emit()
	expect(hud.log_panel.visible and hud.mission_objectives.text.contains("03 摧毁心灵控制器"), "点开情报显示本关总目标")
	hud.log_btn.pressed.emit()
	hud.select_prod_tab("building")
	hud._refresh_production()
	var soviet_tab: Button = hud.find_child("CampaignBaseSoviet",true,false)
	var allied_tab: Button = hud.find_child("CampaignBaseAllied",true,false)
	expect(soviet_tab.visible and soviet_tab.button_pressed and not allied_tab.visible and "NAPOWR" in hud._prod_buttons and "GAPOWR" not in hud._prod_buttons, "只有苏军建造场时，仅显示苏军基地页签和建筑")
	world.request_structure("GAPOWR")
	world.set_build_mode("GAPOWR")
	expect(not world.struct_queue.any(func(j): return j.id == "GAPOWR") and world.armed_build != "GAPOWR", "绕开按钮也不能下单或进入盟军建筑选址")
	for id in ["NAREFN", "NARADR"]:
		world.request_structure(id)
		var def: Dictionary = GameData.get_building(id)
		var spot := Vector2.INF
		for x in range(-9,10):
			for y in range(-9,10):
				var p: Vector2 = world.snap_build_pos(yard.position + Vector2(x,y)*55.0)
				if world.build_spot_ok(p,def,true).ok: spot = p; break
			if spot.is_finite(): break
		expect(spot.is_finite(), "地形提供选址：" + id)
		for i in range(150):
			world._tick_structure_queue(1.0)
			if int(world.struct_ready.get(id,0)) > 0: break
		expect(int(world.struct_ready.get(id,0)) == 1, "正常队列完成：" + id)
		if not spot.is_finite(): finish(); return
		world.armed_build = id
		world._try_place_building(spot)
		expect(id in world.owned_building_ids("ally"), "真实放置入口落地：" + id)
	if "--parallel-construction" in OS.get_cmdline_user_args():
		# Use the real mission and HUD, without depending on later unrelated trigger actions.
		world.funds = 20000.0
		world._place_building("GACNST", "ally", yard.position + Vector2(850, 0), true)
		world._place_building("NAHAND", "ally", yard.position + Vector2(320, 0), true)
		world._place_building("GAPILE", "ally", yard.position + Vector2(580, 0), true)
		hud._refresh_production()
		allied_tab.pressed.emit()
		hud._prod_buttons["GAPOWR"].pressed.emit()
		check_parallel_construction(world, hud, yard, soviet_tab, allied_tab)
		check_snow_oil_paint(world)
		hud._prod_buttons["GAPOWR"].pressed.emit()
		soviet_tab.pressed.emit()
		hud._prod_buttons["NAPOWR"].pressed.emit()
		world._tick_structure_queue(1.0)
		var ally_paid: float = world.current_structure_job("building", "allied").get("paid", 0.0)
		var soviet_paid: float = world.current_structure_job("building", "soviet").get("paid", 0.0)
		var funds_before_loss: float = world.funds
		var lost_yard: Building = world.buildings.filter(func(b): return world.actor_alive(b) and b.side == "ally" and b.building_id == "GACNST")[0]
		lost_yard.hp = 0.0
		world._tick_structure_queue(0.0)
		expect(ally_paid > 0.0 and soviet_paid > 0.0 and world.current_structure_job("building", "allied").is_empty() and is_equal_approx(world.funds, funds_before_loss + ally_paid), "失去盟军建造场只退款盟军工程")
		world._tick_structure_queue(1.0)
		expect(world.current_structure_job("building", "soviet").get("paid", 0.0) > soviet_paid, "另一边建造场失守不打断苏军施工")
		finish()
		return
	world.AlliedFinale.tick(world, 0.2)
	hud._refresh_timer()
	expect(hud.wave_label.text.contains("等待超时空增援") and hud.timer_label.text.contains("增援通报倒计时"), "雷达建成后收起栏显示真实计时")
	var save := BattleSaves.save_slot(world,"quick")
	expect(save.ok, "雷达建成后可保存：" + str(save.message))
	world.AlliedFinale.tick(world, 120)
	world.AlliedFinale.tick(world, 15)
	var rings: Array = world.effects_root.get_children().filter(func(e): return e is Ra2Fx and e.anim.get("image") == "WARPIN")
	var flash: Array = world.effects_root.get_children().filter(func(e): return e is Ra2Fx and e.anim.get("image") == "CHRONOTG")
	var landing := Vector2(43.5,76.5)*55.0
	var landing_points: Array = rings.map(func(e): return e.global_position)
	expect(rings.size()==9 and landing_points.has(landing) and landing_points.all(func(p): return world.units.any(func(u): return u.side=="ally" and u.global_position==p)), "基地车和八组护卫各有贴合实际落点的传入动画")
	expect(flash.size()==1 and flash[0].global_position==landing and flash[0].anim.count > 1, "基地车原图落点播放一次有帧的超时空光效")
	var mcv: Array = world.units.filter(func(u): return world.actor_alive(u) and u.unit_id == "AMCV" and u.side == "ally")
	expect(mcv.size() == 1 and s.phase == 3 and s.get("dominator_placed",false), "脚本实际生成基地车与控制器")
	expect(is_instance_valid(world.campaign_mark_overlay) and not world.campaign_mark_overlay.draw.get_connections().is_empty(), "战场绘制层接入任务菱形，不只生成小地图数据")
	var comms: Array = world.buildings.filter(func(b):return b.building_id=="CATECH01")
	expect(comms.size()==1 and comms[0].display_name=="通讯站" and is_equal_approx(comms[0].hp/comms[0].max_hp,0.25),"中立通讯站按零售名称和四分之一耐久装配")
	var sites: Array = world.buildings.filter(func(b): return world.actor_alive(b) and b.side=="enemy" and b.building_id in ["YAPPET","YAGNTC"])
	expect(sites.size()==2 and sites.all(func(b): return b.broadcasts_superweapon() and world.position_visible_to("ally",b.position)), "原图两座超武走通用广播并暴露实际视野")
	expect(sites.size()==2 and sites.all(func(b): return b.sw_recharge()==(900.0 if b.building_id=="YAPPET" else 600.0)), "控制器按可达动作充能 15 分钟，突变器按原图覆盖充能 10 分钟")
	if "--building-crew" in OS.get_cmdline_user_args():
		check_building_crew(world)
		finish()
		return
	if "--superweapons" in OS.get_cmdline_user_args():
		check_superweapons(world, s, sites)
		finish()
		return
	var room_colors := {}
	for u in world.units:
		if world.actor_alive(u) and u.side=="enemy" and u.special.get("allied_finale_room") in world.AlliedFinale.ENEMIES:
			room_colors[u.special.allied_finale_room]=u._col
	expect(room_colors.size()==3 and room_colors.values().all(func(c):return room_colors.values().count(c)==1),"三支尤里房的实际单位颜色互不相同")
	if "--third-barracks" in OS.get_cmdline_user_args():
		var ai = world.AlliedFinale.AI
		var room = world.AlliedFinale.Branches
		var barracks = world._place_building("YABRCK","enemy",Vector2(1400,6100),true)
		barracks.special.allied_finale_room="Yuri3"
		barracks._buildup_play=-1.0
		var lab = world._place_building("NAPSIS","enemy",Vector2(1490,6400),true)
		lab.special.allied_finale_room="YuriCountry"
		expect(not barracks.unit_prereqs_ok("VIRUS"),"其它房的雷达不能给第三房解锁病毒狙击手")
		lab.special.allied_finale_room="Yuri3"
		expect(barracks.unit_prereqs_ok("VIRUS"),"第三房自己的雷达满足前置")
		room.enable_third(world,74)
		s.ai_due={"Yuri3":0.0}
		ai.tick(world,s,1.0)
		expect(str(s.ai_jobs.get("Yuri3",{}).get("id","")).begins_with("092fe") and not barracks.production.is_empty(),"没有车厂时第三房仍能按原图选兵营队并排产")
		var balance: float = room.ensure_account(world).funds
		for i in 520:
			barracks._tick_unit_queues(1.0)
			ai.tick(world,s,0.5)
			if not s.ai_jobs.has("Yuri3"): break
		expect(room.ensure_account(world).funds<balance and world.units.any(func(u):return room.belongs(world,u,"Yuri3") and u.attack_move and not u.is_naval),"兵营队扣本房资金、实际出厂并接到进攻命令")
		finish()
		return
	if "--third-ai" in OS.get_cmdline_user_args():
		var retail_soviet: Array = world.owned_building_ids("ally")
		expect("NAHAND" not in retail_soviet and not s.script.fired.has("0960df3c"),"没兵营不置原版触发旗标")
		for id in ["NAHAND","NAWEAP","GAWEAP","GACNST"]:
			world._place_building(id,"ally",Vector2(1900+200*retail_soviet.size(),2000),true)
			retail_soviet.append(id)
		world.AlliedFinale.tick(world,11.0)
		expect(["0960df3c","046336ec","0f22154c","0c028afc"].all(func(id):return s.script.fired.has(id)) and ["0","1","4","10"].all(func(id):return s.script.locals[id]),"四条新增原图触发真实执行并置对应局部变量")
		# Test the third-house gate without depending on the southern rooms.
		s.south_ai_enabled=false
		var room = world.AlliedFinale.Branches
		var ai = world.AlliedFinale.AI
		var site = world._place_building("YAWEAP","enemy",Vector2(550,6400),true)
		site.special.allied_finale_room="Yuri3"
		site._buildup_play=-1
		for id in ["YATECH","YAPOWR"]:
			var prerequisite = world._place_building(id,"enemy",Vector2(700,6500),true)
			prerequisite.special.allied_finale_room="Yuri3"
		s.ai_due={"Yuri3":0.0}
		ai.tick(world,s,1.0)
		expect(site.production.is_empty(),"第三房未启用时即使有厂也不排产")
		room.enable_third(world,74)
		ai.tick(world,s,6.0)
		var job: Dictionary = s.ai_jobs.get("Yuri3",{})
		expect(not str(job.get("id", "")).is_empty() and not site.production.is_empty(),"只启用第三房即可从原图车厂编组排产")
		var before: float = room.ensure_account(world).funds
		var shared: float = world.enemy_funds
		for i in 400:
			site._tick_unit_queues(1.0)
			ai.tick(world,s,0.5)
			if not s.ai_jobs.has("Yuri3"): break
		expect(room.ensure_account(world).funds<before and world.enemy_funds==shared,"第三房编队真实扣自己资金")
		expect(world.units.any(func(u): return room.belongs(world,u,"Yuri3") and u.unit_id in ["LTNK","YTNK","TELE","MIND","DISK"] and u.attack_move),"第三房部队出厂并获攻击移动命令")
		finish()
		return
	if "--branches" in OS.get_cmdline_user_args():
		world.AlliedFinale.tick(world,2.0)
		expect(s.script.fired.has("0901213c") and world.get_children().any(func(n):return n.get_meta("allied_finale_voice","")=="ceva125"),"心灵控制器走原图延迟语音")
		world.AlliedFinale.tick(world,5.0)
		expect(s.script.fired.has("0901648c") and world.get_children().any(func(n):return n.get_meta("allied_finale_voice","")=="ceva128"),"随后播基因突变器原声")
		finale_branches(world,s)
		finish()
		return
	if "--replacement" in OS.get_cmdline_user_args():
		if mcv.size()!=1: finish(); return
		mcv[0].hp=0
		world.AlliedFinale.tick(world,0.2)
		expect(s.script.enabled.has("0908b71c"),"普通难度未建实验室时丢基地车会启用补援")
		world.AlliedFinale.tick(world,59.0)
		expect(not s.script.enabled.has("098dc46c"),"补援通报不提前")
		world.AlliedFinale.tick(world,1.0)
		expect(s.script.enabled.has("098dc46c"),"通报后才开启第二段计时")
		world.AlliedFinale.tick(world,15.0)
		expect(world.units.filter(func(u):return world.actor_alive(u) and u.side=="ally" and u.unit_id=="AMCV").size()==1 and s.script.fired.has("078bf6ac"),"替代基地车和护卫入场")
		finish()
		return
	var primary: Array = world.CampaignMarks.marks(world,false).filter(func(m): return m.title == "摧毁心灵控制器")
	expect(primary.size()==1 and primary[0].color==world.CampaignMarks.GOLD, "战场主目标为心灵控制器的黄色菱形")
	hud._enemy_alerts.refresh()
	expect(hud._enemy_alerts.timers.visible and sites.all(func(b):return hud._enemy_alerts.timers.text.contains(b.sw_label())), "战略警报栏同时显示两座超武")
	if mcv.size() == 1:
		hud._refresh_production()
		expect(not allied_tab.visible and "GAPOWR" not in hud._prod_buttons, "盟军基地车未展开仍不解锁盟军")
		expect(mcv[0].deploy(), "增援基地车能在原点展开")
		hud._refresh_production()
		await get_tree().process_frame
		expect(soviet_tab.visible and allied_tab.visible and not soviet_tab.disabled and not allied_tab.disabled and soviet_tab.get_global_rect().end.x <= allied_tab.get_global_rect().position.x, "两座基地就绪后，两个可点击页签并排显示")
		allied_tab.pressed.emit()
		expect(allied_tab.button_pressed and not soviet_tab.button_pressed and "GAPOWR" in hud._prod_buttons and "NAPOWR" not in hud._prod_buttons, "点击盟军基地，切到盟军建筑并高亮盟军页签")
		hud.select_prod_tab("defense")
		expect("GAPILL" in hud._prod_buttons and "NALASR" not in hud._prod_buttons, "盟军防御目录不混入苏军防御")
		soviet_tab.pressed.emit()
		expect(hud.prod_tab == "defense" and "NALASR" in hud._prod_buttons and "GAPILL" not in hud._prod_buttons, "切苏军时保留防御分类，刷新为苏军防御")
		var soviet_barracks = world._place_building("NAHAND", "ally", yard.position + Vector2(320, 0), true)
		var allied_barracks = world._place_building("GAPILE", "ally", yard.position + Vector2(580, 0), true)
		hud.select_prod_tab("infantry")
		expect("E2" in hud._prod_buttons and "E1" not in hud._prod_buttons and hud._factories.current() == soviet_barracks and hud._factories.candidates().size() == 2, "步兵栏并列两个兵营，默认查看苏军步兵")
		allied_tab.pressed.emit()
		expect(hud.prod_tab == "infantry" and "E1" in hud._prod_buttons and "E2" not in hud._prod_buttons and hud._factories.current() == allied_barracks and hud._factories.candidates().size() == 2, "点击盟军基地时保留步兵分类，并选中盟军兵营")
		hud.select_prod_tab("building")
		# Exercise the placement boundary with an already paid structure.
		world.struct_ready["NAPOWR"] = 1
		world.struct_ready_order.append("NAPOWR")
		hud._refresh_production()
		expect(soviet_tab.text.contains("1 就绪") and not hud.deck_tabs_btns["building"].tooltip_text.contains("就绪"), "另一座基地的就绪提示显示在其基地页签，不误亮当前建筑栏")
		soviet_tab.pressed.emit()
		hud._prod_buttons["NAPOWR"].pressed.emit()
		expect(world.armed_build == "NAPOWR", "切到苏军后可选址放置已就绪建筑")
		allied_tab.pressed.emit()
		expect(world.armed_build.is_empty() and world.struct_ready.get("NAPOWR") == 1, "切换基地退出旧选址，但保留已付费建筑")
		world.struct_ready.erase("NAPOWR")
		world.struct_ready_order.erase("NAPOWR")
		hud._refresh_production()
		hud._prod_buttons["GAPOWR"].pressed.emit()
		check_parallel_construction(world, hud, yard, soviet_tab, allied_tab)
		hud._prod_buttons["GAPOWR"].pressed.emit()
		expect(world.struct_queue.any(func(j): return j.id == "GAPOWR"), "展开后实际点卡可排盟军发电厂")
		world._tick_structure_queue(1.0)
		var paid: float = world.struct_queue.filter(func(j): return j.id == "GAPOWR")[0].paid
		soviet_tab.pressed.emit()
		expect(soviet_tab.button_pressed and "NAPOWR" in hud._prod_buttons and world.struct_queue.any(func(j): return j.id == "GAPOWR"), "切回苏军不取消盟军订单")
		allied_tab.pressed.emit()
		var funds: float = world.funds
		var allied_yard = world.buildings.filter(func(b): return world.actor_alive(b) and b.side == "ally" and b.building_id == "GACNST")[0]
		allied_yard.hp = 0
		world._tick_structure_queue(0.0)
		hud._refresh_production()
		expect(not allied_tab.visible and soviet_tab.button_pressed and "NAPOWR" in hud._prod_buttons and "GAPOWR" not in hud._prod_buttons and not world.struct_queue.any(func(j): return j.id == "GAPOWR") and is_equal_approx(world.funds,funds+paid), "当前基地失去建造场后自动切回苏军，撤下盟军页签并退款")
		hud.select_prod_tab("infantry")
		expect(hud._factories.candidates().size() == 2 and hud._factories.buttons.size() == 2, "只有苏军建造场时，两座兵营仍各有按钮")
		expect(BattleSaves.save_slot(world, "slot2").ok, "保存单建造场、双兵营状态")
		hud._factories.buttons[soviet_barracks.get_instance_id()].button.pressed.emit()
		hud._prod_buttons["E2"].pressed.emit()
		hud._factories.buttons[allied_barracks.get_instance_id()].button.pressed.emit()
		expect(hud._factories.current() == allied_barracks and "E1" in hud._prod_buttons and "E2" not in hud._prod_buttons, "点盟军兵营按钮可切换兵种，且不要求盟军建造场")
		hud._prod_buttons["E1"].pressed.emit()
		expect(soviet_barracks.production == ["E2"] and allied_barracks.production == ["E1"], "两边实际点卡，订单进入各自兵营且切换不取消")
		var balance: float = world.funds
		var before: int = world.units.size()
		for b in [soviet_barracks, allied_barracks]:
			b._buildup_play = -1.0 # Skip only the fixture's opening animation.
			b._tick_unit_queues(30.0)
		expect(world.funds < balance and world.units.size() == before + 2 and soviet_barracks.production.is_empty() and allied_barracks.production.is_empty(), "没有盟军建造场，两个兵营仍独立扣费和出兵：%s / %s，出兵 %d，扣费 %.1f" % [soviet_barracks.production, allied_barracks.production, world.units.size()-before, balance-world.funds])
		world.select_building(soviet_barracks)
		world._emit_selection()
		expect(hud._factories.current() == soviet_barracks and "E2" in hud._prod_buttons, "在战场点苏军兵营也能切回苏军步兵")
		soviet_barracks.hp = 0
		hud._refresh_production()
		expect(hud._factories.current() == allied_barracks and hud._factories.buttons.size() == 1, "当前兵营摧毁后切到剩余兵营")
	expect(not world.ended, "增援不提前结算")
	var dominator = world.buildings.filter(func(b): return world.actor_alive(b) and b.building_id == "YAPPET")[0]
	for ch in world.get_children():
		if ch.has_meta("allied_finale_voice"): ch.stop()
	world.AlliedFinale.extra_dialogue(world,s)
	expect(not s.get("extra_dialogue",{}).has("yuri"), "超武自动暴露不会提前触发尤里废案录音")
	for ch in world.get_children():
		if ch.has_meta("allied_finale_voice"): ch.stop()
	var probe = world.spawn_unit("MTNK","ally",dominator.position+Vector2(165,0))
	world.AlliedFinale.extra_dialogue(world,s)
	expect(s.get("extra_dialogue",{}).get("yuri",false) and world.get_children().any(func(ch): return ch.get_meta("allied_finale_voice","")=="xa7yu01" and ch.playing), "兵力抵达后实际挂载尤里原声并记录一次性触发")
	for ch in world.get_children():
		if ch.has_meta("allied_finale_voice"): ch.stop()
	world.AlliedFinale.extra_dialogue(world,s)
	expect(world.get_children().filter(func(ch):return ch.get_meta("allied_finale_voice","")=="xa7yu01").size()==1, "重复轮询不重播尤里录音")
	probe.queue_free()
	var target = world.buildings.filter(func(b): return world.actor_alive(b) and b.building_id == "YAPOWR" and b.side == "enemy")[0]
	var hostile = world.units.filter(func(u): return world.actor_alive(u) and u.side == "enemy" and not u.is_naval)[0]
	var marked := func(marks: Array, actor): return marks.any(func(m): return m.get("actor") == actor and m.color == Color.TOMATO)
	expect(not marked.call(world.CampaignMarks.marks(world,false),target), "控制器尚在时不进入清剿标记")
	dominator.hp = 0
	hud._refresh_timer()
	expect(hud.wave_label.text.contains("清剿") and hud.timer_label.text.is_empty(), "摧毁控制器后左上立即转清剿")
	world.fog._reveal("ally", target.position, 100)
	world.fog._reveal("ally", hostile.position, 100, 10.0)
	world.fog.rebuild()
	var field_marks: Array = world.CampaignMarks.marks(world,false)
	var radar_marks: Array = hud.minimap.objective_marks()
	expect(marked.call(field_marks,target) and marked.call(radar_marks,target), "已探明的普通尤里建筑有战场和雷达清剿标记")
	expect(marked.call(field_marks,hostile) and marked.call(radar_marks,hostile), "当前可见的剩余敌军也有清剿标记")
	var hidden: Array = world.buildings.filter(func(b): return b.side=="enemy" and not world.position_explored_by("ally",b.position) and not world.actor_visible_to("ally",b))
	expect(not hidden.is_empty() and not marked.call(radar_marks,hidden[0]), "不暴露未探索的建筑")
	target.hp = 0
	expect(not marked.call(world.CampaignMarks.marks(world,false),target), "摧毁后立即撤掉清剿标记")
	for faction in [world.units.duplicate(),world.buildings.duplicate()]:
		for actor in faction:
			if world.actor_alive(actor) and actor.side == "enemy": actor.hp = 0
	world.AlliedFinale.tick(world, 20)
	world.AlliedFinale.tick(world, 10)
	expect(world.ended, "清除敌军后进入结算")
	var proceed = button(tree.current_scene,"查看结算")
	expect(proceed != null,"胜利有查看结算入口")
	if proceed != null:
		proceed.pressed.emit()
		var ending = world.get_node_or_null("HollywoodFilm")
		expect(ending != null and ending.clip_id == "A08_F00E", "查看结算进入盟军原版片尾")
		if ending != null: ending.skip.pressed.emit()
		expect(button(tree.current_scene,"选择关卡") != null,"跳过片尾保留结算导航")
	if "--final-return" in OS.get_cmdline_user_args(): await return_to_campaign()
	finish()

func return_to_campaign() -> void:
	var tree := get_tree()
	var back = button(tree.current_scene,"选择关卡")
	expect(back!=null,"结算有选择关卡入口")
	if back==null: return
	back.pressed.emit()
	await tree.scene_changed
	expect(tree.current_scene.scene_file_path=="res://scenes/campaign_command.tscn","从结算按选择关卡实际返回战役菜单")

func check_defeat(world,s: Dictionary,wipe: bool) -> void:
	var results := []
	Events.battle_ended.connect(func(result):results.append(result),CONNECT_ONE_SHOT)
	var finale = world.AlliedFinale
	if wipe:
		for u in world.units:
			if world.actor_alive(u) and u.side=="ally": u.hp=0
		finale.tick(world,0.25)
		expect(not world.ended,"全灭不在原图检查的下一帧误判")
		finale.tick(world,3.0)
		expect(s.script.fired.has("08ed7a3c"),"全灭由 PlayerLose 判负")
	else:
		for b in world.buildings:
			if world.actor_alive(b) and b.building_id=="NACNST" and b.special.get("allied_finale_room")=="Special": b.hp=0
		finale.tick(world,0.25)
		expect(not world.ended and s.script.fired.has("0a57f46c") and s.script.enabled.has("0a57b28c"),"火地岛建造场被毁，先告警并启用延时失败")
		finale.tick(world,4.0)
		expect(not world.ended,"火地岛失败延时未到不提前结算")
		finale.tick(world,1.0)
		expect(s.script.fired.has("0a57b28c"),"火地岛建造场失败链按表执行")
	expect(world.ended and results.size()==1 and results[0].get("win",true)==false,"战场实际提交失败结算，且只提交一次")
	var proceed = button(get_tree().current_scene,"查看结算")
	if proceed!=null: proceed.pressed.emit()
	await return_to_campaign()

func last_five(world,s: Dictionary) -> void:
	var finale = world.AlliedFinale
	var d = finale.Driver.new()
	var disabled := ["0955dd2c","0ee0857c","078f61fc","061bd4ec"]
	for difficulty in 3:
		d.start("yr_all07smd",difficulty)
		expect(d.rows.size()==88 and disabled.all(func(id):return d.rows.has(id) and not d.state.enabled.has(id)) and not d.enable("078f61fc"),"难度 %d 加载 88 条，四条默认关闭且油井上游不可启用"%difficulty)
	expect(d.restore(s.script) and s.script.fired.has("09197edc") and not world.ended,"第三房最初未拥有油井时零动作触发，不结束关卡")
	# Exercise unreachable actions via the actual driver in an isolated battle.
	# The original difficulty mask remains intact; only the test enables terminal rows.
	for id in ["0955dd2c","0ee0857c","061bd4ec"]: expect(d.enable(id),"夹具单独启用原图关闭的动作："+id)
	s.script=d.snapshot()
	finale.tick(world,1.25)
	var plane = null
	for u in world.units:
		if world.actor_alive(u) and u.special.has("para_manifest"): plane=u; break
	expect(plane!=null and plane.special.para_manifest==["GGI","GGI","E1","E1","E1","E1"] and plane.position.is_equal_approx(finale.AI.waypoint(world,105)),"一架运输机从 DB 带两名重装大兵、四名美国大兵")
	for i in 5400:
		for u in world.units.duplicate():
			if world.actor_alive(u) and (u.special.has("para_manifest") or u.special.get("finale_start_gis",false) and u.special.has("para_height")): u._physics_process(1.0/60.0)
		var landed: Array = world.units.filter(func(u):return world.actor_alive(u) and u.special.get("finale_start_gis",false) and not u.special.has("para_height"))
		if landed.size()==6: break
	var squad: Array = world.units.filter(func(u):return world.actor_alive(u) and u.special.get("finale_start_gis",false) and not u.special.has("para_height"))
	expect(squad.size()==6 and squad.filter(func(u):return u.unit_id=="GGI").size()==2,"六名混编伞兵真实落地")
	expect(s.script.fired.has("0ee0857c") and is_equal_approx(float(s.get("retail_sw_recharge",{}).get("YAPPET",-1)),13500.0/BattleClock.RULE_TICKS_PER_SECOND) and is_equal_approx(float(s.get("retail_sw_recharge",{}).get("YAGNTC",-1)),9000.0/BattleClock.RULE_TICKS_PER_SECOND),"超武尚未生成时先记录两种充能周期")
	var oil_team: Array = world.units.filter(func(u):return world.actor_alive(u) and u.special.has("finale_oil_wp"))
	expect(oil_team.size()==2 and [43,44].all(func(wp):return oil_team.any(func(u):return u.special.finale_oil_wp==wp and u.special.get("target")==finale.Branches.oil(world,wp))),"油井终端动作派两名第三房工程师各自占领指定油井")
	if not oil_team.is_empty():
		var u = oil_team[0]
		var site = finale.Branches.oil(world,int(u.special.finale_oil_wp))
		u.position=finale.Orders.approach(u,site)+Vector2(60,0)
		for i in 720:
			if not world.actor_alive(u) or site.side=="enemy": break
			finale.Orders.tick_action(u,1.0/60.0)
		expect(site.side=="enemy" and site.special.get("allied_finale_room")=="Yuri3","摆位后工程师实际到门占领油井")
	expect(d.restore(s.script) and d.enable("0460bdbc"),"夹具推动正式生成超武建筑的触发")
	s.script=d.snapshot()
	finale.tick(world,0.25)
	for id in ["YAPPET","YAGNTC"]:
		expect(world.buildings.any(func(b):return world.actor_alive(b) and b.building_id==id and is_equal_approx(b.sw_recharge(),float(s.get("retail_sw_recharge",{}).get(id,-1)))),"未来生成的 %s 建筑继承动作 132 的周期"%id)

func closing_branches(world,s: Dictionary,yard) -> void:
	var ai = world.AlliedFinale.AI
	var source = world.AlliedFinale.Field.data
	var disabled := ["0955dd2c","0ee0857c","078f61fc","061bd4ec"]
	expect(disabled.all(func(id):return not s.script.fired.has(id) and not s.script.enabled.has(id)),"四条原图关闭记录不擅自启用")
	expect(["0960ee5c","04f32afc","090ad17c"].all(func(id):return s.script.fired.has(id)) and s.get("africa_hostile",false),"三条初始原图任务由正式战场推进")
	var living: Array = world.units.filter(func(u):return world.actor_alive(u))
	var defenders: Array = living.filter(func(u):return u.special.has("finale_defense_team"))
	var reenforcements: Array = defenders.filter(func(u):return u.special.finale_defense_team in ["08FFE99C","08FFEC1C","0900E65C","0900B27C"])
	var original: int = source.infantry.filter(func(r):return r[8] and r[1] in ["YuriCountry","Yuri2"] and r[2]=="INIT").size()
	expect(reenforcements.size()==18 and living.filter(func(u):return u.unit_id=="INIT").size()==original+18,"动作 4 招募不复制，动作 7 共派来 18 名尤里新兵")
	expect(reenforcements.all(func(u):return u.special.has("finale_reactor_anchor")) and defenders.any(func(u):return u.special.get("action")=="allied_garrison"),"生物反应炉队实际接到进炉命令")
	var patrol: Array = defenders.filter(func(u):return u.special.get("finale_defense_team")=="090AF55C")
	expect(not patrol.is_empty() and patrol.all(func(u):return u.special.get("finale_prism_patrol")==[41,40,39] and (u.has_move_order or not u.order_queue.is_empty())),"光棱预防队从原图脚本接到循环巡逻")
	for i in 720:
		for u in defenders:
			if world.actor_alive(u) and u.special.get("action")=="allied_garrison": world.AlliedFinale.Orders.tick_action(u,1.0/60.0)
		if defenders.any(func(u):return u.embarked_in is Building): break
	expect(defenders.any(func(u):return u.embarked_in is Building and u.embarked_in.building_id=="YAPOWR"),"至少一名新兵实际进入生物反应炉")
	world.AlliedFinale.tick(world,0.25)
	expect(world.units.filter(func(u):return world.actor_alive(u) and u.special.get("finale_defense_team", "") in ["08FFE99C","08FFEC1C","0900E65C","0900B27C"]).size()==18,"反复推进不重复生成开场守军")
	var added := ["0c576c3c","13525d8c","095192dc","0a5a71bc","05ed315c","05ed772c"]
	expect(ai.Data.data.rules.size()==84 and added.all(func(id):return ai.Data.data.rules.any(func(r):return r.id==id)),"6 条剩余地图 AI 都在正式战场选队表")
	var main_factory = world.buildings.filter(func(b):return world.actor_alive(b) and b.building_id=="YAWEAP" and b.special.get("allied_finale_room")=="YuriCountry")[0]
	var barracks = world.buildings.filter(func(b):return world.actor_alive(b) and b.building_id=="YABRCK" and b.special.get("allied_finale_room")=="YuriCountry")[0]
	expect(main_factory.queue_block_reason("CAOS").is_empty() and barracks.queue_block_reason("YENGINEER").is_empty(),"原图反光棱和工程师队使用可生产的神经突击车与尤里工程师")
	# Keep the real production system, isolate this one candidate by limiting the
	# fixture's products. A map trigger, not the fixture, still creates the job.
	for b in world.buildings:
		if not world.actor_alive(b) or b.special.get("allied_finale_room")!="YuriCountry": continue
		if b.building_id=="YAWEAP": b.buildable.clear()
		if b.building_id=="YABRCK":
			b.buildable.clear()
			b.buildable.append_array(["YURI","VIRUS","YENGINEER"])
	s.south_ai_enabled=true
	s.ai_due={"YuriCountry":0.0,"Yuri2":1000.0,"Yuri3":1000.0}
	ai.tick(world,s,0.5)
	expect(not s.ai_jobs.has("YuriCountry"),"没建盟军电厂时不会下单工程师突袭")
	var plant = world._place_building("GAPOWR","ally",yard.position+Vector2(240,180),true)
	s.ai_due.YuriCountry=0.0
	ai.tick(world,s,0.5)
	expect(s.ai_jobs.get("YuriCountry",{}).get("id")=="13525d8c","盟军电厂触发 13525D8C 正式选队")
	if "--seed-ai-queue" in OS.get_cmdline_user_args():
		for i in 140:
			barracks._tick_unit_queues(0.5)
			ai.tick(world,s,0.5)
			if s.ai_jobs.get("YuriCountry",{}).get("members",[]).size()==1 and not barracks.production.is_empty(): break
		expect(s.ai_jobs.get("YuriCountry",{}).get("members",[]).size()==1 and not barracks.production.is_empty(),"已有一人出厂、后续成员在真实队列中时保存")
		save_extra(world)
		return
	finish_engineer_team(world,s,barracks,plant)

func finish_engineer_team(world,s: Dictionary,barracks,plant) -> void:
	var ai = world.AlliedFinale.AI
	for i in 180:
		barracks._tick_unit_queues(1.0)
		ai.tick(world,s,0.5)
		if not s.ai_jobs.has("YuriCountry"): break
	world.fog._reveal("enemy",plant.position,600,60.0)
	world.fog.rebuild()
	ai.tick(world,s,0.5)
	var team: Array = world.units.filter(func(u):return world.actor_alive(u) and u.special.has("finale_engineer_rush"))
	var engineers: Array = team.filter(func(u):return u.unit_id=="YENGINEER" and u.special.get("target")==plant)
	expect(team.size()==4 and engineers.size()==2,"4 人实际出厂，两名工程师对原图类型目标下达占领指令")
	if not engineers.is_empty():
		var engineer = engineers[0]
		var ops = world.AlliedFinale.Orders
		engineer.position=ops.approach(engineer,plant)+Vector2(90,0) # Long-distance march is not part of this fixture.
		for i in 480:
			if plant.side=="enemy" or not world.actor_alive(engineer): break
			ops.tick_action(engineer,1.0/60.0)
		expect(plant.side=="enemy" and plant.special.get("allied_finale_room")=="YuriCountry","摆位到近处后，工程师实际到门并为所属房占领盟军电厂")

func save_extra(world) -> void:
	var saved := BattleSaves.save_slot(world,"slot6")
	expect(saved.ok,"写入隔离断点："+str(saved.get("message","")))

func check_live_opening(world) -> void:
	var s: Dictionary = world.allied_state.allied_finale
	var opening = world.get_node_or_null("HollywoodFilm")
	expect(opening != null and opening.clip_id=="A07_F00E", "正式出击播放全屏片头")
	if opening == null: return
	opening.skip.pressed.emit()
	var last := ""
	var saw_radio := false
	var skip_radio := "--skip-live-radio" in OS.get_cmdline_user_args()
	for i in 35:
		await get_tree().create_timer(1.0,true,false,true).timeout
		var film = world.get_node_or_null("HollywoodFilm")
		var status := "%s %s %s %s" % [s.media_stage, s.script.active, s.script.pending, film.clip_id if film!=null else "-"]
		if status!=last or i%10==0:
			print("FINALE live ",i+1," ", status," clock=",s.script.time," paused=",world.paused," tree_paused=",get_tree().paused)
			last=status
		if not saw_radio and film!=null and film.clip_id=="A07_P01E":
			saw_radio=true
			expect(not world.world_input_enabled() and film.opening_radio_deadline_ms>0,"雷达简报期间锁控，媒体结束信号有超时兜底")
			if skip_radio: film.skip.pressed.emit()
		if world.world_input_enabled() or world.ended: break
	expect(saw_radio and world.world_input_enabled(), "正常帧循环中，雷达简报结束或跳过后及时交还操作")
	expect(world.AlliedFinale.OPENING_ROWS.all(func(id):return s.script.fired.has(id)), "七条正式开场任务全部执行")
	expect(world.units.filter(func(u): return world.actor_alive(u) and u.special.get("finale_opening_engineer",false) and not u.special.has("para_height")).size()==5, "五名开场工程师已着陆")

func step_opening(world,i: int) -> void:
	for u in world.units.duplicate():
		if world.actor_alive(u) and (u.special.has("para_infantry") or u.special.has("finale_opening_engineer")): u._physics_process(1.0/60.0)
	if i%20==0: world.AlliedFinale.tick(world,20.0/60.0)

func restore_extra_boundary(mode: String) -> void:
	var result := BattleSaves.load_into_scene("slot6")
	expect(result.ok,"独立进程冷读断点："+str(result.get("message","")))
	if not result.ok: return
	await get_tree().scene_changed
	var world = get_tree().current_scene.battle
	world.set_process(false)
	world.set_physics_process(false)
	var s: Dictionary = world.allied_state.allied_finale
	if world.paused: get_tree().current_scene.hud._toggle_pause()
	if mode == "cold-superweapons":
		var sites: Array = world.buildings.filter(func(b): return world.actor_alive(b) and b.side == "enemy" and b.building_id in ["YAPPET", "YAGNTC"])
		expect(s.phase == 3 and sites.size() == 2 and not s.has("retail_superweapons_applied"), "独立进程还原旧版终关，两座超武均在场")
		if sites.size() == 2:
			var mutator = sites.filter(func(b): return b.building_id == "YAGNTC")[0]
			expect(mutator.sw_recharge() == 300.0 and mutator._sw_charge == 300.0, "旧快照确实保存旧版周期与充能")
			world.AlliedFinale.tick(world, 0.2)
			expect(mutator.sw_recharge() == 600.0 and mutator._sw_charge == 300.0 and s.retail_superweapons_applied, "读档后自动纠正周期并保留已有充能")
		return
	if mode=="cold-ai-queue":
		var job: Dictionary = s.get("ai_jobs",{}).get("YuriCountry",{})
		var members: Array = job.get("members",[])
		var factories: Array = world.buildings.filter(func(b):return world.actor_alive(b) and b.special.get("allied_finale_room")=="YuriCountry" and b.special.has("allied_finale_order"))
		var plants: Array = world.buildings.filter(func(b):return world.actor_alive(b) and b.side=="ally" and b.building_id=="GAPOWR")
		expect(job.get("id")=="13525d8c" and members.size()==1 and world.actor_alive(members[0]) and factories.size()==1 and plants.size()==1,"冷读还原 13525D8C、已出厂成员引用和在产工厂")
		if factories.size()!=1 or plants.size()!=1: return
		finish_engineer_team(world,s,factories[0],plants[0])
		return
	if mode=="cold-opening-gap":
		expect(int(s.media_stage)==2 and not world.has_node("HollywoodFilm") and not world.world_input_enabled(),"冷读间隙不重播片头")
		world.AlliedFinale.tick(world,0.2)
		var clip = world.get_node_or_null("HollywoodFilm")
		expect(clip!=null and clip.clip_id=="A07_P01E","间隙冷读继续播雷达简报")
		if clip!=null: clip.skip.pressed.emit()
		await get_tree().process_frame
	else:
		expect(not world.has_node("HollywoodFilm") and not world.world_input_enabled() and world.units.any(func(u):return world.actor_alive(u) and u.special.get("finale_opening_engineer",false) and u.special.has("para_height")),"飞行冷读恢复伞兵高度与锁控，不重开简报")
	for i in 4200:
		step_opening(world,i)
		if s.media_stage==0: break
	var engineers: Array = world.units.filter(func(u):return world.actor_alive(u) and u.side=="ally" and u.unit_id=="ENGINEER" and u.special.get("finale_opening_engineer",false))
	expect(engineers.size()==5 and engineers.all(func(u):return not u.special.has("para_height") and u.is_in_group("ground_units")),"五名工程师全部落地，不丢失或重派")
	expect(s.script.fired.has("0de1124c") and s.script.fired.has("0bb2e0fc") and world.world_input_enabled(),"按原触发交还操控，已执行的空降不重发")

func ai_tesla_engagement(world,s: Dictionary) -> void:
	var ai = world.AlliedFinale.AI
	var factory = world.buildings.filter(func(b):return world.actor_alive(b) and b.building_id=="YAWEAP" and b.special.get("allied_finale_room")=="Yuri2")[0]
	# Isolate rival candidates using the fixture's catalog. The retail selector,
	# spend and assembly here still run via the production code.
	for b in world.buildings:
		if not world.actor_alive(b) or b.special.get("allied_finale_room")!="Yuri2": continue
		b.buildable.clear()
	factory.buildable.append("TELE")
	s.south_ai_enabled=true
	s.ai_due={"YuriCountry":1000.0,"Yuri2":0.0,"Yuri3":1000.0}
	var before: float = world.enemy_funds
	var prior: Array = world.units.duplicate()
	var near := Vector2.INF
	var far := Vector2.INF
	for angle in 24:
		var delta := Vector2.from_angle(TAU*angle/24)*490.0
		var point: Vector2 = world.AlliedFinale.OpeningDrop.open_ground(world,factory.position+delta)
		if not point.is_finite() or point.distance_to(factory.position)<400: continue
		var reachable: Vector2 = world.path_service.nearest_reachable(point,factory.position,false,4)
		if not reachable.is_finite() or reachable.distance_to(point)>60: continue
		if not near.is_finite(): near=point
		elif point.distance_to(near)>190: far=point; break
	expect(near.is_finite() and far.is_finite(),"找到同岛可达目标位")
	if not near.is_finite() or not far.is_finite(): return
	var target = world._place_building("TESLA","ally",near,true)
	ai.tick(world,s,0.5)
	expect(not s.ai_jobs.has("Yuri2"),"只有一座磁暴线圈不触发 05ED315C")
	world._place_building("TESLA","ally",far,true)
	s.ai_due.Yuri2=0.0
	ai.tick(world,s,0.5)
	expect(s.ai_jobs.get("Yuri2",{}).get("id")=="05ed315c" and not factory.production.is_empty(),"两座磁暴线圈触发 05ED315C 并下单")
	for i in 180:
		factory._tick_unit_queues(1.0)
		ai.tick(world,s,0.5)
		if not s.ai_jobs.has("Yuri2"): break
	var units: Array = world.units.filter(func(u):return world.actor_alive(u) and u not in prior and u.unit_id=="TELE" and u.special.get("allied_finale_room")=="Yuri2")
	expect(units.size()==3 and world.enemy_funds<before and units.all(func(u):return u.attack_move or u.attack_ordered),"三辆磁电坦克实际扣费、出厂并接到出击命令")
	if units.is_empty(): return
	world.fog._reveal("enemy",target.position,700,90.0)
	world.fog.rebuild()
	var origins: Array = units.map(func(u):return u.position)
	var moved := false
	var hp: float = target.hp
	# Only this produced team advances. Other preplaced enemies cannot contribute damage.
	for i in 4200:
		for j in units.size():
			var u = units[j]
			if world.actor_alive(u):
				u._physics_process(1.0/60.0)
				moved=moved or u.position.distance_to(origins[j])>65
		if i%60==0: await get_tree().process_frame
		if target.hp<hp and moved: break
	expect(moved and target.hp<hp,"出厂编队实际移动、抵达射程并对磁暴线圈造成伤害")

func enemy_ai(world,s: Dictionary,yard) -> void:
	var ai = world.AlliedFinale.AI
	var factory = world.buildings.filter(func(b): return b.building_id=="YAWEAP" and b.special.get("allied_finale_room")=="YuriCountry")[0]
	var units_before: int = world.units.size()
	ai.tick(world,s,74.0)
	expect(world.units.size()==units_before,"没造兵营，不乱刷早期登陆队")
	var pos: Vector2 = yard.position
	world._place_building("NAHAND","ally",pos+Vector2(-110,110),true)
	world.AlliedFinale.tick(world,0.25)
	expect(s.script.fired.has("04e8103c") and s.get("arabs_hostile",false),"零售外交触发先于火地岛登陆生效")
	const FIRST_RAID := "0960d93c"
	# The retail row starts enabled. Elapsed Time is measured from enable,
	# not from construction of the barracks, which only unlocks its locals.
	var remaining: float = float(s.script.enabled.get(FIRST_RAID,0.0))+75.0-float(s.script.time)
	expect(s.script.enabled.has(FIRST_RAID) and remaining>1.0,"开场推进后，首批登陆仍有原图计时")
	world.AlliedFinale.tick(world,maxf(0.0,remaining-1.0))
	expect(not s.script.fired.has(FIRST_RAID) and not world.units.any(func(u):return world.actor_alive(u) and u.special.has("allied_finale_raid")),"原图计时到点前不派首批登陆队")
	s.ai_due={"YuriCountry":0.0}
	world.AlliedFinale.tick(world,1.25)
	expect(s.script.fired.has("0960d93c"),"正式战场由原图驱动派出首批步兵登陆队")
	expect(factory.production.is_empty(),"没展开盟军建造场时只跑登陆，不开启南极车厂 AI")
	s.phase=3
	world._place_building("GACNST","ally",pos+Vector2(-220,220),true)
	world.AlliedFinale.tick(world,1.0)
	expect(s.get("south_ai_enabled",false),"盟军建造场触发原图 AI 开关")
	var boats: Array = world.units.filter(func(u): return world.actor_alive(u) and u.special.has("allied_finale_raid"))
	expect(boats.size()==1 and boats[0].logistics.passengers.size()==5, "原图首批是一艘艇载五名尤里新兵")
	expect(s.ai_jobs.has("YuriCountry") and world.buildings.any(func(b):return b.special.has("allied_finale_order")),"扩充选队后，所属生产建筑真实下单")
	if boats.is_empty(): return
	var boat = boats[0]
	var start: Vector2 = boat.position
	var passengers: Array = boat.logistics.passengers.duplicate()
	var hull_before: float = yard.hp
	var finished_disk := false
	var prior: Array = world.units.duplicate()
	var reached_shore := false
	for i in range(7200):
		if i % 30 == 0:
			world.AlliedFinale.tick(world,0.5)
			world.fog.rebuild()
		if i % 6 == 0:
			for b in world.buildings:
				if b.special.has("allied_finale_order"): b._tick_unit_queues(0.5)
		if world.actor_alive(boat): boat._physics_process(1.0/60.0)
		for u in passengers:
			if world.actor_alive(u) and u.embarked_in==null: u._physics_process(1.0/60.0)
		for u in world.units:
			if world.actor_alive(u) and u not in prior and u.side=="enemy" and u.special.get("allied_finale_room")=="YuriCountry" and u.attack_move:
				finished_disk=true
		reached_shore = reached_shore or passengers.any(func(u):return u.embarked_in==null and u.has_move_order)
		if finished_disk and yard.hp<hull_before: break
	expect(not world.actor_alive(boat) or boat.position.distance_to(start)>100.0 or passengers.any(func(u):return u.embarked_in==null),"运输艇实际航行而非原地放兵")
	expect(reached_shore,"运输艇到岸实际卸载并攻击移动")
	expect(finished_disk,"原图候选编队实际出厂并接到出击命令")
	expect(yard.hp<hull_before,"登陆队实际命中火地岛建造场")
	var start_funds: float = world.enemy_funds
	for i in 4: world.spawn_unit("MTNK","ally",yard.position+Vector2(40*i,270))
	world.AlliedFinale.Orders.change_side(world.buildings.filter(func(b):return b.building_id=="NAPOWR" and b.side=="ally")[0],"neutral")
	s.ai_due.YuriCountry=0.0
	ai.tick(world,s,1.0)
	expect(s.ai_jobs.has("YuriCountry"),"前线兵力变化后可重新按地图条件排产")
	var next_wave_prior: Array = world.units.duplicate()
	for i in 400:
		for b in world.buildings:
			if b.special.has("allied_finale_order"): b._tick_unit_queues(1.0)
		ai.tick(world,s,0.5)
		if not s.ai_jobs.has("YuriCountry"): break
	expect(world.units.any(func(u):return world.actor_alive(u) and u not in next_wave_prior and u.side=="enemy" and u.special.get("allied_finale_room")=="YuriCountry" and u.has_move_order),"后续选中编队出厂且收到出击命令")
	expect(world.enemy_funds<start_funds,"AI工厂实际支付生产费用")
	africa_conscript_response(world,s,yard)

func africa_conscript_response(world,s: Dictionary,yard) -> void:
	var ai = world.AlliedFinale.AI
	var barracks = world.buildings.filter(func(b):return world.actor_alive(b) and b.building_id=="YABRCK" and b.special.get("allied_finale_room")=="Yuri2")[0]
	# Isolate the South African infantry response without fabricating a job.
	# Leave the real barracks, radar, treasury and unit queues in the loop.
	for b in world.buildings:
		if world.actor_alive(b) and b.special.get("allied_finale_room")=="Yuri2" and b.building_id=="YAWEAP": b.hp=0
	var own: Array = world.units.filter(func(u):return world.actor_alive(u) and u.side=="ally" and u.unit_id in ["E1","DOG","E2","BFRT","APOC"])
	for u in own: u.hp=0
	s.ai_due={"YuriCountry":1000.0,"Yuri2":0.0,"Yuri3":1000.0}
	ai.tick(world,s,0.5)
	expect(not s.ai_jobs.has("Yuri2"),"没有动员兵时，非洲反步兵新编队不下单")
	world.spawn_unit("E2","ally",yard.position+Vector2(110,110))
	s.ai_due.Yuri2=0.0
	var funds: float = world.enemy_funds
	var prior: Array = world.units.duplicate()
	ai.tick(world,s,0.5)
	expect(s.ai_jobs.get("Yuri2",{}).get("id")=="087ab06c" and barracks.special.get("allied_finale_order")=="VIRUS","一名动员兵触发原图 087AB06C，由非洲兵营真实下单")
	for i in 120:
		barracks._tick_unit_queues(1.0)
		ai.tick(world,s,0.5)
		if not s.ai_jobs.has("Yuri2"): break
	var team: Array = world.units.filter(func(u):return world.actor_alive(u) and u not in prior and u.special.get("allied_finale_room")=="Yuri2")
	expect(world.enemy_funds<funds and team.size()==6 and team.filter(func(u):return u.unit_id=="VIRUS").size()==2 and team.all(func(u):return u.has_move_order),"087AB06C 扣费，2 名病毒狙击手与 4 名尤里新兵实际出厂并接令")

func finale_branches(world,s: Dictionary) -> void:
	var branches = world.AlliedFinale.Branches
	var crates: Dictionary = s.get("cash_crates",{})
	var au := Vector2i(101,13)
	var av := Vector2i(10,109)
	expect(crates.size()==2 and crates.has(au) and crates.has(av),"普通难度在零售 AU/AV 生成两只资金箱")
	if crates.has(au):
		var before: float = world.funds
		var point: Vector2 = crates[au]
		var scout = world.spawn_unit("MTNK","ally",point)
		world.AlliedFinale.pick_crates(world,s)
		world.AlliedFinale.pick_crates(world,s)
		expect(not crates.has(au) and crates.has(av) and is_equal_approx(world.funds-before,5000.0),"己方地面单位拾取后仅到账一次，另一只资金箱保留")
		var flashes: Array = world.effects_root.get_children().filter(func(f): return f is Ra2Fx and f.anim.get("image") == "MONEY")
		expect(flashes.size()==1 and flashes[0].position==point,"仅领取的资金箱在原位播放原版金色 $")
		if flashes.size()==1:
			var flash: Ra2Fx = flashes[0]
			expect(flash.anim.count==23 and flash.anim.cell==Vector2(37,31) and is_equal_approx(flash.fps,400.0/60.0),"战场加载零售 23 帧动画和换算帧率")
			flash._process(22.5/flash.fps)
			expect(flash.frame==22 and not flash.is_queued_for_deletion(),"金色 $ 逐帧播到末帧")
			flash._process(1.0/flash.fps)
			expect(flash.is_queued_for_deletion(),"闪烁播完自动清理，不循环")
		scout.queue_free()
	var hard = world.AlliedFinale.Driver.new()
	hard.start("yr_all07smd",2)
	expect(not hard.state.enabled.has("04f0aacc"),"困难不启用原图资金箱事件")
	var before_boats: int = world.units.filter(func(u):return world.actor_alive(u) and u.unit_id=="YHVR").size()
	var fifth := {"raid_index":4}
	expect(world.AlliedFinale.AI.raid(world,fifth,4) and fifth.raid_index==5,"第五支陆路队可在原图入口启用")
	var overland: Array = world.units.filter(func(u):return world.actor_alive(u) and u.special.get("finale_land_raid")=="08D6A1CC")
	expect(overland.size()==5 and overland.filter(func(u):return u.unit_id=="VIRUS").size()==1 and overland.all(func(u):return u.embarked_in==null and u.has_move_order) and world.units.filter(func(u):return world.actor_alive(u) and u.unit_id=="YHVR").size()==before_boats,"四新兵一狙击手有陆路命令、不造气垫艇")
	var saucer = world.spawn_unit("DISK","enemy",Vector2(6500,6200))
	saucer.special.allied_finale_room="YuriCountry"
	expect(not s.script.fired.has("08e97bec") and not s.script.enabled.has("08e9757c") and not saucer.special.has("finale_taunt_team"),"没有超时空传送仪时不调动飞碟、不启用挑衅")
	world._place_building("GACSPH","ally",Vector2(1200,1800),true)
	world.AlliedFinale.tick(world,0.25)
	expect(s.script.fired.has("08e97bec") and s.script.fired.has("08e9757c") and saucer.special.get("finale_taunt_team",false) and world.get_children().any(func(n):return n.get_meta("allied_finale_voice","")=="xs4yu02"),"造超时空传送仪触发原声并调动现有飞碟")
	var oil = branches.oil(world,43)
	expect(oil!=null and oil.side=="neutral" and not s.script.fired.has("078f71ec"),"原图北部油井尚未发现，不提前派工程师")
	if oil==null: return
	world.fog._reveal("ally",oil.position,140,10.0)
	world.AlliedFinale.tick(world,0.25)
	var engineers: Array = world.units.filter(func(u):return world.actor_alive(u) and u.special.has("finale_oil_wp"))
	expect(engineers.size()==2 and s.script.fired.has("078f71ec"),"发现指定油井后从原图入口派两名工程师")
	for i in 4200:
		if i%20==0:
			world.fog.rebuild()
			branches.oil_orders(world)
		for u in engineers:
			if world.actor_alive(u): u._physics_process(1.0/60.0)
		if oil.side=="enemy": break
	world.AlliedFinale.tick(world,0.25)
	world.AlliedFinale.tick(world,0.25)
	expect(oil.side=="enemy" and oil.special.get("allied_finale_room")=="Yuri3", "敌工程师实际到达并转属油井")
	var ledger: Dictionary = branches.ensure_account(world)
	var frontier: Array = world.buildings.filter(func(b):return branches.belongs(world,b,"Yuri3") and b.under_construction)
	expect(ledger.build_enabled and ledger.ai_enabled and frontier.size()==1,"第三房抢油后开启自身建造、开始一个原图节点")
	if not frontier.is_empty():
		var site = frontier[0]
		var pool: float = world.enemy_funds
		var money: float = ledger.funds
		site._process(1.0)
		expect(ledger.funds<money and world.enemy_funds==pool,"第三房施工扣独立账户，不动敌方共用资金")
	var sea: Array = world.units.filter(func(u):return branches.belongs(world,u,"Yuri3") and u.unit_id=="BSUB")
	expect(not sea.is_empty() and not world.AlliedFinale.cleanup_target(world,sea[0],["Yuri2"]),"第三房实体不被查询误认为第二房")
	var tagged = world._place_building("YAPOWR","enemy",Vector2(690,7080),true)
	tagged.special.allied_finale_room="Yuri3"
	tagged.special.finale_yuri3_yard_tag=true
	for b in world.buildings:
		if b.building_id=="CAOILD" and branches.belongs(world,b,"Yuri3"): b.hp=0
	world.AlliedFinale.tick(world,0.5)
	expect(s.script.fired.has("08cba40c") and tagged.side=="neutral" and tagged.special.allied_finale_room=="French" and ledger.retired,"失去油井只转属标签对象并停第三房建造")
	expect(sea.all(func(u): return u.side=="enemy" and branches.actor_room(u)=="Yuri3"),"法国转属不带走无标签潜艇")
	var raid_state := {"raid_factory_seen":true,"raid_barracks_seen":true}
	world.AlliedFinale.AI.armor_schedule(world,raid_state,[],90.0)
	var targets: Array = world.units.filter(func(u): return world.actor_alive(u) and u.special.get("allied_finale_raid",{}).get("team")=="08D57B5C")
	expect(targets.size()==1 and not targets[0].logistics.passengers.is_empty(),"载货装甲艇符合旧联锁")
	if targets.size()==1:
		targets[0]._die()
		world.AlliedFinale.AI.armor_schedule(world,raid_state,[],1.0)
		expect(raid_state.armor_outcome=="lost" and raid_state.armor_raid_index==1,"真沉没记录损失，不伪造卸载或提前下一批")
		world.AlliedFinale.AI.armor_schedule(world,raid_state,[],89.0)
		expect(raid_state.armor_raid_index==2,"满足计时后后一批可以接续")
	var old: int = world.units.filter(func(u):return world.actor_alive(u) and u.unit_id=="BSUB").size()
	world._place_building("NAYARD","ally",Vector2(800,900),true)
	world.AlliedFinale.tick(world,0.25)
	expect(s.script.locals["17"] and not s.script.fired.has("0462be5c"),"苏军船坞只置变量，不提前触发盟军船厂反击")
	world._place_building("GAYARD","ally",Vector2(960,900),true)
	world.AlliedFinale.tick(world,0.25)
	var directed: Array = world.units.filter(func(u):return branches.belongs(world,u,"Yuri3") and u.unit_id=="BSUB" and u.special.get("finale_naval_response",false) and u.attack_move)
	expect(directed.size()==1 and world.units.filter(func(u):return world.actor_alive(u) and u.unit_id=="BSUB").size()==old,"盟军船厂触发已存在的一艘雷鸣潜艇出击，没有凭空加船")
	var survivor = world.units.filter(func(u):return branches.belongs(world,u,"Yuri2") and not u.is_naval)[0]
	var second_sites: Array = world.buildings.filter(func(b): return branches.belongs(world,b,"Yuri2"))
	var lost := 0
	for b in second_sites:
		if b.building_id in ["YACNST","YAPOWR","YABRCK"]:
			b.hp=0
			lost+=1
	for b in second_sites:
		if lost>=11: break
		if world.actor_alive(b):
			b.hp=0
			lost+=1
	world.AlliedFinale.tick(world,0.25)
	world.AlliedFinale.tick(world,3.0)
	expect(s.script.fired.has("0901606c") and survivor.attack_move,"尤里第二房关键设施失守后出售残余建筑并派兵反扑")
	expect(not world.ended and world.buildings.any(func(b):return branches.belongs(world,b,"YuriCountry") and b.building_id=="YAPPET"),"第二房反扑不会跳过另一房及控制器目标")
	for b in world.buildings:
		if branches.belongs(world,b,"YuriCountry") and b.building_id in ["YAPPET","YAGNTC","YACNST","YAPOWR","YABRCK"]: b.hp=0
	var main_sites: Array = world.buildings.filter(func(b):return branches.belongs(world,b,"YuriCountry"))
	for b in main_sites.slice(0,maxi(0,main_sites.size()-20)): b.hp=0
	world.AlliedFinale.tick(world,10.0)
	expect(s.script.fired.has("0780a03c") and world.units.any(func(u):return branches.belongs(world,u,"YuriCountry") and u.attack_move),"第一房满足关键目标及损失数量后派兵反扑")

func check_opening_snow_art(world) -> void:
	# ALL07SMD Structures 1050334–1050336, using artmd.ini foundations 3x2 / 1x1 / 1x1.
	for row in [["CAARMY01", Vector2(105,52.5), 0.25], ["CAARMY02", Vector2(103.5,50.5), 0.25], ["CARUFGL", Vector2(102.5,52.5), 1.0]]:
		var matches: Array = world.buildings.filter(func(b): return b.building_id==row[0])
		expect(matches.size()==1 and matches[0].position.is_equal_approx(row[1]*55.0) and matches[0].side=="neutral" and is_equal_approx(matches[0].hp/matches[0].max_hp,row[2]), "%s 原图坐标、数量及耐久"%row[0])
		if matches.size()!=1: continue
		var b: Building = matches[0]
		var pose := b.fog_pose()
		var frame := 1 if row[2]<1.0 else 0
		var art := b._ra2
		var path := "res://assets/maps/yr/allied_finale/%s_detail.png"%row[0]
		expect(pose.size()>=2 and pose[0][0]==path and pose[0][2]==Rect2(RA2Art.src_rect(art,3+frame).position*2.0,RA2Art.src_rect(art,3+frame).size*2.0) and pose[0][3]==Color(0,0,0,0.5) and pose[0][1]==pose[1][1], "%s 读取对应原版影子且和本体同锚"%row[0])
		if frame==1:
			var body := RA2Art.draw_rect(art,b.radius,b.body_anchor_frames(frame),0,Building.RA2_SPRITE_SCALE)
			var visible_body := RA2Art.visible_sprite_rect(art,body,RA2Art.src_rect(art,frame))
			var bar := b.hp_bar_rect()
			expect(is_equal_approx(bar.get_center().x,visible_body.get_center().x) and is_equal_approx(bar.end.y+6.0,visible_body.position.y), "%s 血条贴近实际损伤外观"%row[0])
		else:
			var flag_path := "res://assets/maps/yr/allied_finale/CARUFGL_A_detail.png"
			var old_time := b._anim_t
			b._anim_t += 0.25
			var next_pose := b.fog_pose()
			b._anim_t = old_time
			expect(pose.size()>=4 and next_pose.size()>=4 and pose[2][0]==flag_path and pose[3][0]==flag_path and pose[2][3]==Color(0,0,0,0.5) and pose[3][2]!=next_pose[3][2], "旗帜雪地动画、原版投影及换帧")

func has_paint(actor, expected: Color) -> bool:
	return is_instance_valid(actor) and actor._col.is_equal_approx(expected) and actor.material is ShaderMaterial and actor.material.get_shader_parameter("target_color").is_equal_approx(expected)

func color_actor(actors: Array, id: String):
	for a in actors:
		if a.side=="ally" and a.hp>0.0 and (a.building_id if a is Building else a.unit_id)==id: return a
	return null

func check_production_colors(world) -> void:
	var red := Color.from_hsv(0.0,230.0/255,1.0)
	var blue := Color.from_hsv(153.0/255,214.0/255,212.0/255)
	for id in ["NACNST","NALASR","NAPOWR","NAREFN","NARADR","NAHAND"]:
		expect(has_paint(color_actor(world.buildings,id),red), "%s 归玩家且为苏军红"%id)
	for id in ["GACNST","GAPOWR"]:
		expect(has_paint(color_actor(world.buildings,id),blue), "%s 归玩家且为盟军蓝"%id)
	for row in [["E2",red],["HARV",red],["SREF",blue]]:
		expect(has_paint(color_actor(world.units,row[0]),row[1]), "%s 实体房色及材质一致"%row[0])

func check_parallel_construction(world, hud, yard: Building, soviet_tab: Button, allied_tab: Button) -> void:
	soviet_tab.pressed.emit()
	var soviet_card: Button = hud._prod_buttons["NAPOWR"]
	expect(not soviet_card.disabled, "盟军建筑在造时，苏军同类建筑卡仍可点击")
	soviet_card.pressed.emit()
	world._tick_structure_queue(1.0)
	var red: Dictionary = world.current_structure_job("building", "soviet")
	var blue: Dictionary = world.current_structure_job("building", "allied")
	expect(red.get("paid", 0.0) > 0.0 and blue.get("paid", 0.0) > 0.0, "同一次生产步推进并扣费两个阵营的建筑")
	expect(BattleSaves.save_slot(world, "slot1").ok, "两座建造场同时施工时可保存")
	world.structure_right_click("GAPOWR")
	var paused_elapsed: float = blue.get("elapsed", 0.0)
	world._tick_structure_queue(60.0)
	expect(world.structure_is_paused("GAPOWR") and blue.get("elapsed") == paused_elapsed and int(world.struct_ready.get("NAPOWR", 0)) == 1, "暂停盟军只暂停该阵营，苏军照常就绪")
	allied_tab.pressed.emit()
	hud._prod_buttons["GAPOWR"].pressed.emit()
	soviet_tab.pressed.emit()
	world._tick_structure_queue(60.0)
	hud._update_ready_tabs(0.2)
	expect(soviet_tab.button_pressed and soviet_tab.text.contains("1 就绪") and allied_tab.text.contains("1 就绪") and allied_tab.draw.is_connected(hud._draw_campaign_base_ready.bind(allied_tab, "allied")), "双方建筑都待放置时分别亮起，后台盟军页签已接入闪烁绘制")
	expect(int(world.struct_ready.get("GAPOWR", 0)) == 1 and int(world.struct_ready.get("NAPOWR", 0)) == 1, "苏军建筑未放置也不阻塞盟军继续建造并就绪")
	allied_tab.pressed.emit()
	var new_allied_yard: Building = world.buildings.filter(func(b): return world.actor_alive(b) and b.side == "ally" and b.building_id == "GACNST")[0]
	expect(order_color_structure(world, hud, new_allied_yard.position, "GAPOWR") != null and int(world.struct_ready.get("NAPOWR", 0)) == 1, "放置盟军就绪建筑不消耗苏军就绪建筑")
	soviet_tab.pressed.emit()
	expect(order_color_structure(world, hud, yard.position, "NAPOWR") != null, "切回苏军后可独立放置苏军建筑")
	hud._update_ready_tabs(0.2)
	expect(hud._ready_tab_phase == 0.0 and not soviet_tab.text.contains("就绪") and not allied_tab.text.contains("就绪"), "两座基地的就绪建筑放置完毕后提示消失")
	hud.select_prod_tab("defense")
	hud._prod_buttons["NALASR"].pressed.emit()
	allied_tab.pressed.emit()
	hud._prod_buttons["GAPILL"].pressed.emit()
	world._tick_structure_queue(1.0)
	expect(world.current_structure_job("defense", "soviet").get("paid", 0.0) > 0.0 and world.current_structure_job("defense", "allied").get("paid", 0.0) > 0.0, "两个阵营的防御队列也独立推进")
	world.structure_right_click("NALASR")
	soviet_tab.pressed.emit()
	hud._update_ready_tabs(0.0)
	expect(hud._ready_tab_phase == 0.0 and not allied_tab.text.contains("就绪"), "正在施工时基地页签不闪")
	world._tick_structure_queue(60.0)
	hud._update_ready_tabs(0.2)
	expect(soviet_tab.button_pressed and not allied_tab.button_pressed and not soviet_tab.text.contains("就绪") and allied_tab.text.contains("1 就绪"), "停在苏军目录时，只有盟军基地收到就绪提示")
	expect(int(hud._campaign_base_ready.get("allied", 0)) == 1 and hud._ready_tab_phase > 0.0 and not hud.deck_tabs_btns.defense.tooltip_text.contains("就绪"), "未选中的盟军基地驱动闪烁，苏军防御分类不误闪")
	var phase: float = hud._ready_tab_phase
	hud._update_ready_tabs(0.2)
	expect(hud._ready_tab_phase > phase, "只剩后台基地有待放置建筑时，闪烁仍持续推进")
	hud.select_prod_tab("building")
	hud.set_production_collapsed(true, false)
	allied_tab.pressed.emit()
	expect(hud.prod_tab == "defense" and not hud.production_collapsed and hud.deck_tabs_btns.defense.button_pressed and hud.deck_tabs_btns.defense.tooltip_text.contains("1 项建造就绪"), "点击后台闪烁基地，展开甲板并直接跳到盟军就绪防御页")
	expect(world.armed_build.is_empty() and int(world.struct_ready.get("GAPILL", 0)) == 1, "跳转不自动选址，不消耗就绪项")
	hud.select_prod_tab("building")
	allied_tab.pressed.emit()
	expect(hud.prod_tab == "defense" and allied_tab.button_pressed, "已在盟军基地时再点闪烁页签也能快速跳转")
	world.cancel_structure("GAPILL")
	hud._update_ready_tabs(0.2)
	expect(hud._ready_tab_phase == 0.0 and not allied_tab.text.contains("就绪"), "取消最后一项待放置防御后停止闪烁")
	world.request_structure("NALASR")
	world._tick_structure_queue(60.0)
	hud._update_ready_tabs(0.2)
	expect(allied_tab.button_pressed and soviet_tab.text.contains("1 就绪") and hud._ready_tab_phase > 0.0 and not allied_tab.text.contains("就绪"), "停在盟军时，苏军完工也独立闪烁")
	hud.select_prod_tab("building")
	soviet_tab.pressed.emit()
	expect(hud.prod_tab == "defense" and soviet_tab.button_pressed and "NALASR" in hud._prod_buttons, "反向点击闪烁苏军基地，也直接打开待放置防御")
	world.cancel_structure("NALASR")
	allied_tab.pressed.emit()
	hud.select_prod_tab("building")

func check_snow_oil_paint(world) -> void:
	var oil: Building = world.AlliedFinale.Branches.oil(world, 43)
	expect(oil != null and oil.side == "neutral", "检查原图北部中立油井")
	if oil == null: return
	var body: Texture2D = oil._ra2.get("tex")
	var detail: Texture2D = oil._ra2.get("detail_tex")
	expect(body != null and body.resource_path == "res://assets/maps/yr/allied_finale/CAOILD.png" and detail != null and detail.get_size() == body.get_size() * 2.0, "战场实际加载雪地油井及其双倍细节")
	if body == null or detail == null: return
	var pixels := body.get_image()
	var hd := detail.get_image()
	for sample in [Vector2i(53, 73), Vector2i(166 + 56, 70)]:
		var paint := pixels.get_pixelv(sample)
		expect(paint.b > 0.8 and absf(paint.r - paint.b * 87.0/255.0) < 0.01 and absf(paint.g - paint.b * 168.0/255.0) < 0.01 and hd.get_pixelv(sample * 2).is_equal_approx(paint), "完好／受损油井房色在原图与双倍图一致：" + str(sample))
	var flag: Texture2D = oil._structure_anim_art("CAOILD_F").get("tex")
	expect(flag != null and flag.resource_path.ends_with("/shp/CAOILD_F.png"), "仍使用已支持房色的原旗帜动画")
	expect(int(oil.material.get_shader_parameter("paint_mode")) == HouseColor.PaintMode.NEUTRAL_OIL, "中立油井继续用中立灰材质")
	preload("res://scripts/units/allied_abilities.gd").change_side(oil, "ally")
	expect(oil.side == "ally" and int(oil.material.get_shader_parameter("paint_mode")) == HouseColor.PaintMode.NONE and oil.material.get_shader_parameter("target_color").is_equal_approx(HouseColor.finale_color("ally", "", "civilian")), "占领后同一材质将油井主体和旗帜映射到盟军房色")

func order_color_structure(world, hud, origin: Vector2, id: String) -> Building:
	hud.select_prod_tab("building")
	hud._refresh_production()
	var card: Button = hud._prod_buttons.get(id)
	if card==null or card.disabled: return null
	card.pressed.emit()
	for i in 160:
		if int(world.struct_ready.get(id,0))>0: break
		world._tick_structure_queue(1.0)
	if int(world.struct_ready.get(id,0))<=0: return null
	var def := GameData.get_building(id)
	for x in range(-9,10):
		for y in range(-9,10):
			var p: Vector2 = world.snap_build_pos(origin+Vector2(x,y)*55.0)
			if not world.build_spot_ok(p,def,true).ok: continue
			hud._refresh_production()
			hud._prod_buttons[id].pressed.emit()
			var before: int = world.buildings.size()
			world._try_place_building(p)
			return world.buildings.back() if world.buildings.size()>before else null
	return null

func check_house_color_production(world, hud, yard: Building) -> void:
	# Keep this art regression independent of mission budgets; the real queues still charge costs.
	world.funds = 20000.0
	for id in ["NAREFN","NARADR","NAHAND"]:
		var building := order_color_structure(world,hud,yard.position,id)
		expect(building != null, "点生产卡、付费并放置："+id)
		if building==null: return
		# Advance the real buildup before checking refinery handoff or barracks output.
		for i in 100:
			if building.is_operational(): break
			building._process(0.2)
		if id=="NAREFN":
			for i in 40:
				if color_actor(world.units,"HARV")!=null: break
				building._tick_construction_free_unit(0.25)
			expect(color_actor(world.units,"HARV")!=null,"苏军精炼厂落成后赠送矿车")
	var barracks: Building = color_actor(world.buildings,"NAHAND")
	hud.select_prod_tab("infantry")
	hud._refresh_production()
	var infantry: Button = hud._prod_buttons.get("E2")
	if infantry!=null and not infantry.disabled: infantry.pressed.emit()
	expect("E2" in barracks.production, "点苏军步兵卡进入兵营队列")
	for i in 100:
		barracks._tick_unit_queues(1.0)
		if not "E2" in barracks.production: break
	expect(color_actor(world.units,"E2")!=null,"苏军步兵实际从兵营出厂")
	world.AlliedFinale.tick(world,0.2)
	world.AlliedFinale.tick(world,120.0)
	world.AlliedFinale.tick(world,15.0)
	var mcv: Unit = color_actor(world.units,"AMCV")
	expect(has_paint(mcv,Color.from_hsv(153.0/255,214.0/255,212.0/255)), "超时空盟军基地车保持蓝色")
	if mcv==null or not mcv.deploy(): expect(false,"展开盟军基地车"); return
	hud._refresh_production()
	var allied: Button = hud.find_child("CampaignBaseAllied",true,false)
	allied.pressed.emit()
	var allied_yard: Building = color_actor(world.buildings,"GACNST")
	expect(allied.button_pressed and order_color_structure(world,hud,allied_yard.position,"GAPOWR")!=null,"切换盟军甲板后实际生产并放置盟军电厂")
	check_production_colors(world)
	# Deliberately persist one obsolete cached paint value; restore must derive it again.
	barracks._col = Color.BLUE
	expect(BattleSaves.save_slot(world,"slot6").ok,"保存双基地与旧蓝色缓存夹具")

func check_superweapons(world, s: Dictionary, sites: Array) -> void:
	if sites.size() != 2: return
	var mutator = sites.filter(func(b): return b.building_id == "YAGNTC")[0]
	var dominator = sites.filter(func(b): return b.building_id == "YAPPET")[0]
	mutator.superweapon.recharge_seconds = 300.0
	mutator._sw_charge = 300.0
	mutator.powered = false
	dominator.powered = false
	s.erase("retail_superweapons_applied")
	save_extra(world)
	world.AlliedFinale.tick(world, 0.2)
	expect(mutator.sw_recharge() == 600.0 and mutator._sw_charge == 300.0 and not mutator.sw_ready(), "旧快照兼容保留已充 300 秒，不继续使用旧周期")
	expect(mutator.powered and dominator.powered, "旧快照补回两栋建筑的原版供电要求")
	var at := Vector2(43.5, 76.5) * 55.0
	var soldier = world.spawn_unit("E1", "ally", at)
	var tank = world.spawn_unit("MTNK", "ally", at + Vector2(500, 0))
	var shots: Array[String] = []
	world.enemy_superweapon_launched.connect(func(label: String): shots.append(label))
	var enemy_sight: PackedByteArray = world.fog.visible_cells["enemy"]
	enemy_sight.fill(0)
	world.fog.visible_cells["enemy"] = enemy_sight
	world._update_power()
	expect(not world.side_power_low("enemy"), "正式战场的尤里电网可带动两座超武")
	mutator._tick_superweapon(300.0)
	dominator._tick_superweapon(900.0)
	expect(mutator.sw_ready() and dominator.sw_ready(), "两座超武经建筑正常充能入口就绪")
	world.AlliedFinale.tick(world, 0.2)
	expect(shots.is_empty() and mutator.sw_ready() and dominator.sw_ready(), "无敌方视野时不空放，保留就绪")
	world.fog._reveal("enemy", tank.position, 25.0)
	world.enemy_power.low = true
	world.AlliedFinale.tick(world, 0.2)
	expect(shots.is_empty(), "就绪后断电也不发射")
	world.enemy_power.low = false
	world.AlliedFinale.tick(world, 0.2)
	expect(shots == [dominator.sw_label()] and tank.side == "enemy" and dominator._sw_charge == 0.0 and mutator.sw_ready(), "心灵控制器夺取坦克并重置充能，突变器不对坦克空放")
	world.fog._reveal("enemy", soldier.position, 25.0)
	world.AlliedFinale.tick(world, 0.2)
	expect(shots == [dominator.sw_label(), mutator.sw_label()] and not world.actor_alive(soldier) and mutator._sw_charge == 0.0, "突变器获得步兵目标后触发警报、命中并重新充能")
	expect(world.units.any(func(u): return world.actor_alive(u) and u.side == "enemy" and u.unit_id == "BRUTE" and u.position.is_equal_approx(at)), "命中位置实际生成尤里狂兽人")

func check_building_crew(world) -> void:
	var crew = preload("res://scripts/buildings/building_crew.gd")
	var crewed := ["NACLON", "NAPSIS", "YABRCK", "YACNST", "YAGNTC", "YAGRND", "YAPOWR", "YAPPET", "YATECH", "YAWEAP"]
	var uncrewed := ["YAGGUN", "YAPSYT"]
	var rooms := ["YuriCountry", "Yuri2", "Yuri3"]
	var live: Array = world.buildings.filter(func(b): return world.actor_alive(b) and b.side == "enemy" and b.special.get("allied_finale_room") in rooms)
	var rng := RandomNumberGenerator.new()
	world.allied_state.crew_rng = rng
	for id in crewed + uncrewed:
		var candidates: Array = live.filter(func(b): return b.building_id == id)
		expect(not candidates.is_empty(), "%s 在实战地图已装配" % id)
		if candidates.is_empty(): continue
		var building = candidates[0]
		var room: String = building.special.allied_finale_room
		expect(candidates.all(func(b): return crew.faction(b) == "third" and (crew.count(b) > 0) == crewed.has(id)), "%s 原图全部实例按尤里归属、遵守 Crewed" % id)
		var start: int = world.units.size()
		rng.seed = 42
		building.receive_hit(100000.0, "blast")
		var result: Array = world.units.slice(start).filter(func(u): return u.special.get("escaped_crew", false))
		var allowed := ["INIT", "ENGINEER"] if id == "YACNST" else ["INIT"]
		expect(building.is_dead() and (not result.is_empty() if crewed.has(id) else result.is_empty()) and result.all(func(u): return u.unit_id in allowed and u.side == "enemy" and u.special.get("allied_finale_room") == room and u._col == building._col), "%s 真实受击摧毁：%s" % [id, str(result.map(func(u): return u.unit_id))])
	var reactors: Array = live.filter(func(b): return world.actor_alive(b) and b.building_id == "YAPOWR" and b.special.get("allied_finale_room") == "Yuri2")
	expect(reactors.size() >= 3, "第二房保有反应炉用于占领及摧毁测试")
	if reactors.size() < 3: return
	var captured = reactors[0]
	AlliedAbilities.change_side(captured, "ally")
	expect(captured.special.has_been_captured and captured.special.allied_finale_room == "Yuri2" and crew.faction(captured) == "allied", "转属后旧尤里标签不覆盖玩家当前所属")
	var start: int = world.units.size()
	rng.seed = 42
	var sold: bool = world.apply_building_action("sell", captured)
	var result: Array = world.units.slice(start).filter(func(u): return u.special.get("escaped_crew", false))
	expect(sold and not result.is_empty() and result.all(func(u): return u.unit_id == "E1" and u.side == "ally" and not u.special.has("allied_finale_room")), "占领后出售生成己方美国大兵")
	for i in [1, 2]:
		var site = reactors[i]
		var room := "Yuri2" if i == 1 else "Yuri3"
		if i == 2: # Fixture for the third house's conditional construction / takeover.
			AlliedAbilities.change_side(site, "ally")
			site.special.allied_finale_room = room
			AlliedAbilities.change_side(site, "enemy")
			site.refresh_house_color()
		start = world.units.size()
		rng.seed = 42
		site.receive_hit(100000.0, "blast")
		result = world.units.slice(start).filter(func(u): return u.special.get("escaped_crew", false))
		expect(site.is_dead() and not result.is_empty() and result.all(func(u): return u.unit_id == "INIT" and u.side == "enemy" and u.special.get("allied_finale_room") == room and u._col == site._col), "%s 反应炉摧毁时生成该房尤里新兵" % room)

func finish() -> void:
	print("FINALE playable ",checks-failures,"/",checks)
	get_tree().quit(1 if failures else 0)
