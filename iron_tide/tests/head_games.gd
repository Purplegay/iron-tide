extends Node

var failed := 0

func check(ok: bool, label: String) -> void:
	print("SOV07 ",ok," ",label)
	if not ok: failed += 1

func _ready() -> void:
	call_deferred("run")

func check_vat_training(world, barracks, expected: int, label: String) -> void:
	var count := func(): return world.units.filter(func(u): return world.actor_alive(u) and u.side == "ally" and u.unit_id == "E2").size()
	var before: int = count.call()
	var funds: float = world.funds_for("ally")
	check(barracks.enqueue("E2"), label + "：动员兵进入正式训练队列")
	barracks._tick_unit_queue(500.0, "E2")
	check(count.call() - before == expected, label + "：训练结束后的出兵数量")
	check(is_equal_approx(funds - world.funds_for("ally"), world.production_price(GameData.get_unit("E2"), "ally")), label + "：仅扣一名步兵的费用")

func cold_intro(slot: String) -> void:
	var tree := get_tree()
	var result := BattleSaves.load_into_scene(slot)
	check(result.ok, "从磁盘读取简报断点 " + slot)
	if not result.ok: return
	await tree.scene_changed
	var world = tree.current_scene.battle
	var state: Dictionary = world.allied_state
	check(world.paused and not world.has_node("HollywoodFilm"), "冷读保留暂停，继续前不播放")
	world.hud._toggle_pause()
	if state.has("head_brief_stage"): world.HeadGames.briefing(world)
	var film = world.get_node_or_null("HollywoodFilm")
	if slot in ["quick", "slot4"]:
		check(film == null and not state.has("head_brief_stage"), "已结束的简报不重播，旧无声导览直接收尾")
		return
	var expected := "S07_F00E" if slot == "slot1" else "S07_P01E"
	var stage := 0 if slot == "slot1" else 1
	check(film != null and film.clip_id == expected and film.player.is_playing() and state.head_brief_stage == stage, "继续后从对应片段开头恢复语音与镜头")
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
	check(state.get("head_intro_done", false) and not state.has("head_brief_stage") and not state.has("head_resume_clip"), "跳过通讯后直接返回我方，不再另播导览")

func briefing_sync(world, radio, speed: float) -> void:
	var began := Time.get_ticks_msec()
	var state: Dictionary = world.allied_state
	var last_target := Vector2.INF
	var titles := ["摧毁尤里的城堡", "摧毁盟军心灵信标", "摧毁苏军心灵信标"]
	var subtitles := ["要塞", "盟军", "苏军"]
	var visited: Array[int] = []
	var start_camera: Vector2 = world.camera.position
	BattleClock.set_speed(speed)
	check(not world.world_input_enabled() and state.head_brief_stage == 1, "通讯开始时立即对准城堡并锁定玩家镜头")
	while is_instance_valid(radio) and not radio.is_queued_for_deletion() and Time.get_ticks_msec() - began < 26000:
		var stage := int(state.get("head_brief_stage", 0))
		if stage in [1, 2, 3] and not visited.has(stage):
			visited.append(stage)
			var point: Vector2 = world.HeadGames.briefing_point(stage)
			var marks: Array = world.CampaignMarks.head_games(world)
			var seconds: float = radio.player.stream_position
			var anchor: Vector2 = world.camera.position
			world.center_on(point)
			check(anchor.is_equal_approx(world.camera.position) and (stage == 1 or not anchor.is_equal_approx(start_camera)), "镜头跟随原图航点 %d @ %.2fs" % [stage, seconds])
			check(marks.size() == 1 and marks[0].title == titles[stage - 1] and world.fog.is_visible_at("ally", marks[0].position) and marks[0].actor.visible, "只标注并揭示当前解说目标 %d：%s" % [stage, marks.map(func(mark): return [mark.title, world.fog.is_visible_at("ally", mark.position)])])
			if not marks.is_empty(): last_target = marks[0].position
			check(radio.player.is_playing() and radio.subtitle.text.contains(subtitles[stage - 1]), "原声片仍在播放且字幕已切到目标 %d" % stage)
			check(absf(seconds - world.HeadGames.BRIEFING_CUES[stage - 1]) < 0.35, "镜头切点落在对应原声句首 %d" % stage)
			start_camera = anchor
		await get_tree().process_frame
	var elapsed := (Time.get_ticks_msec() - began) / 1000.0
	check(visited == [1, 2, 3] and not state.has("head_brief_stage") and state.get("head_intro_done", false), "原声播完依次经过三个目标并直接结束简报")
	check(elapsed >= 16.5 and elapsed < 24.0, "战斗 ×%.0f 时简报仍按原声时长播放 %.2fs" % [speed, elapsed])
	var anchor: Vector2 = world.camera.position
	world.center_on(world.player_start())
	check(anchor.is_equal_approx(world.camera.position) and world.hud.minimap.objective_marks().size() == 2, "通讯结束镜头回到我方，两座信标同时标出")
	check(world.fog.is_explored_at("ally", last_target) and not world.fog.is_visible_at("ally", last_target), "简报结束后保留探索记忆，撤回简报视野")

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

func checks_residents(world,freed:String,still_held:String) -> void:
	var residents:Array=world.units.filter(func(u):return world.actor_alive(u) and u.special.get("s07_resident_area","")==freed)
	check(not residents.is_empty() and residents.all(func(u):return u.side=="neutral" and u.special.get("s07_resident_freed",false) and not u.has_move_order),"拆厂解除对应居民队伍，不并入玩家军队")
	check(not world.units.any(func(u):return world.actor_alive(u) and u.special.get("s07_resident_area","")==still_held and u.special.get("s07_resident_freed",false)),"另一处回收厂居民不提前释放")

func run() -> void:
	var tree := get_tree()
	reparent(tree.root)
	var args := OS.get_cmdline_user_args()
	if "--cold-cloning-vats" in args:
		var result := BattleSaves.load_into_scene("slot1")
		check(result.ok, "冷读模拟旧版复制中心存档")
		if result.ok:
			await tree.scene_changed
			var loaded = tree.current_scene.battle
			var vat = loaded.buildings.filter(func(b): return b.building_id == "NACLON")[0]
			var barracks = loaded.buildings.filter(func(b): return b.building_id == "NAHAND" and b.side == "ally")[0]
			check(vat.side == "ally" and vat.data.capturable and vat.data.desc.contains("免费复制"), "存档保留归属并更新旧规则和文案")
			check_vat_training(loaded, barracks, 2, "读档后继续复制")
		tree.quit(failed);return
	if "--cold-retail-column" in args:
		var result:=BattleSaves.load_into_scene("slot1")
		check(result.ok,"独立进程冷读第二批开场援军")
		if result.ok:
			await tree.scene_changed
			var w=tree.current_scene.battle
			var count:=func():return w.units.filter(func(u):return w.actor_alive(u) and u.side=="ally").size()
			var first:int=count.call()
			var left:float=w.allied_state.get("s07_second_column_left",0.0)
			check(first>0 and left>0.25,"恢复首批与待发计时")
			w.HeadGames.attackers(w,left-0.25)
			check(count.call()==first,"到点之前第二批不出现")
			w.HeadGames.attackers(w,0.3)
			var expected:=0
			for row in w.HeadGames.Orders.DRIVERS.landing["093A04FC"].members:expected+=int(row[3])
			check(count.call()==first+expected,"到点生成原图第二批编组")
			w.HeadGames.attackers(w,4.0)
			check(count.call()==first+expected,"后续不重复生成")
		tree.quit(failed);return
	if "--cold-defense-route" in args:
		var result:=BattleSaves.load_into_scene("slot1")
		check(result.ok,"独立进程冷读防守队断点")
		if result.ok:
			await tree.scene_changed
			var w=tree.current_scene.battle
			var defenders:Array=w.units.filter(func(u):return w.actor_alive(u) and u.special.has("s07_defense"))
			check(defenders.size()==1 and defenders[0].special.s07_defense.has("until"),"恢复警戒命令与倒计时")
			if defenders.size()==1 and defenders[0].special.s07_defense.has("until"):
				var u=defenders[0]
				var until:float=u.special.s07_defense.until
				w.HeadGames.Orders.advance_defender(w,u,until-0.2)
				check(u.hold_position and not u.has_move_order,"冷读后到点前不擅自开动")
				w.HeadGames.Orders.advance_defender(w,u,until)
				check(u.has_move_order and not u.special.s07_defense.has("until"),"警戒结束继续原下一站")
		tree.quit(failed);return
	if "--cold-house-economy" in args:
		var result:=BattleSaves.load_into_scene("slot1")
		check(result.ok,"独立进程读取房账存档")
		if result.ok:
			await tree.scene_changed
			var w=tree.current_scene.battle
			check(w.paused and w.funds_for("s07_yuri")==40000.0 and w.funds_for("s07_soviet")>40000.0 and w.funds_for("s07_allied")<40000.0,"冷读保留三笔不同的余额")
			check(w.buildings.any(func(b):return w.actor_alive(b) and b.building_id=="GAWEAP" and w.economy_owner(b)=="ally"),"冷读保留工厂转属后的付款方")
		tree.quit(failed);return
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
	if "--retail-ai-production-budget" in args:
		check(not tree.current_scene.get_node("BattleAutosave").is_processing(),"隔离战役测试已关自动保存")
		var orders=world.HeadGames.Orders
		var accounts:Dictionary=world.allied_state.get("s07_accounts",{})
		var ready:=0
		for id in orders.DRIVERS.production:
			var spec:Dictionary=orders.DRIVERS.production[id]
			var wing:=int(spec.wing)
			var key:String=world.HeadEconomy.account(wing)
			var budget:float=orders.production_budget(world,spec)
			check(is_finite(budget) and budget>0.0,"原编组可计算资金 "+id)
			accounts[key]=budget-1.0
			check(not orders.production_plan_ready(world,wing,spec),"本房少一元不得开队 "+id)
			accounts[key]=budget
			var members:Dictionary=orders.production_members(spec)
			var factories:bool=members.keys().all(func(uid):return orders.has_factory_for(world,wing,uid))
			var admitted:bool=orders.production_plan_ready(world,wing,spec)
			if admitted:ready+=1
			check(admitted==factories and not orders.production_plan_ready(world,((wing+2)%3)-1,spec),"预算边界及原房产线 "+id)
		print("BATCH21_FACTORIES ",ready,"/",orders.DRIVERS.production.size())
		check(ready>0 and orders.DRIVERS.production.size()==73,"真实战场存在可开队的原产线")
		tree.quit(failed);return
	if "--write-retail-column" in args:
		check(world.allied_state.has("s07_second_column_left") and BattleSaves.save_slot(world,"slot1").ok,"第二批到来之前写盘")
		tree.quit(failed);return
	if "--map-inventory" in args:
		preload("res://tests/campaign_map_inventory.gd").capture(world,"opening")
		tree.quit(failed);return
	if "--garrison-pose" in args:
		var garrison = preload("res://scripts/units/civilian_orders.gd")
		var checked := {}
		for b in world.buildings:
			if garrison.slots(b) <= 0 or checked.has(b.building_id): continue
			checked[b.building_id] = true
			print("S07 garrison ", b.building_id, " ", b.max_hp, " slots=", garrison.slots(b), " art=", b._ra2.get("key", ""))
			if not garrison.civilian_garrison(b) and b.building_id != "NABNKR": continue
			var military: bool = b.building_id == "NABNKR"
			var unit = world.spawn_unit("E2", b.side if military else "ally", b.position + Vector2(70, 45))
			var shadow: int = 4 if military else Building.CIVILIAN_GARRISON_SHADOWS.get(b.building_id, -1)
			b.hp = b.max_hp
			var empty: Array = b.fog_pose()
			garrison.enter(unit, b)
			var occupied: Array = b.fog_pose()
			var frame_ok: bool = empty.size() >= 2 and occupied.size() >= 2 and occupied[0][2] == RA2Art.src_rect(b._ra2, shadow + 2) and occupied[1][2] == RA2Art.src_rect(b._ra2, 2) and occupied[1][1] == empty[1][1]
			check(unit.embarked_in == b and b._body_damage_frame() == 2 and frame_ok, b.building_id + " 进驻后绘制原版驻军与阴影帧，建筑不挪位")
			b.hp = b.max_hp * 0.49
			check(b._body_damage_frame() == (3 if military else 2), b.building_id + " 半血仍显示驻军")
			garrison.evacuate(b)
			var damaged: Array = b.fog_pose()
			check(unit.embarked_in == null and b._body_damage_frame() == 1 and damaged.size() >= 2 and damaged[1][2] == RA2Art.src_rect(b._ra2, 1), b.building_id + " 撤出后绘制空置受损帧")
		check(checked.has("CAFARM01") and checked.has("CAEUR04") and checked.has("NABNKR"), "实际零售战场含农舍、欧式民居和战斗碉堡")
		tree.quit(int(failed > 0))
		return
	if "--bunker-transfer" in args:
		var bunker = world.buildings.filter(func(b):return world.actor_alive(b) and b.building_id=="NABNKR" and b.special.get("head_games_wing")==0)[0]
		var u = world.spawn_unit("E2","enemy",bunker.position+Vector2(70,45))
		world.HeadGames.assign_wing(u,0)
		var garrison = preload("res://scripts/units/civilian_orders.gd")
		garrison.enter(u,bunker)
		check(u.embarked_in==bunker and bunker.special.occupants.has(u),"真实碉堡有苏军驻军")
		var beacon = world.buildings.filter(func(b):return world.actor_alive(b) and b.special.get("head_games_beacon")==0)[0]
		beacon.receive_hit(100000)
		world.HeadGames.objectives(world)
		check(bunker.side=="ally" and u.side=="ally" and u.embarked_in==bunker and bunker.special.occupants.has(u),"解放时碉堡与守军一并换边，不弹到门外")
		check(not u.is_in_group("enemy_targets") and not u.visible,"堡内士兵不进入地面目标组")
		tree.quit(failed)
		return
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
		radio._update_subtitle(10.5)
		check(world.allied_state.head_brief_stage == 3 and BattleSaves.save_slot(world, "slot3").ok, "雷达通讯已切到苏军信标时写盘")
		radio.skip.pressed.emit()
		check(BattleSaves.save_slot(world, "quick").ok, "雷达通讯已结束时写盘")
		world.allied_state.head_brief_stage = 2
		world.allied_state.head_brief_left = 3.0
		check(BattleSaves.save_slot(world, "slot4").ok, "模拟旧版雷达已结束但无声导览未结束的存档")
		tree.quit(failed)
		return
	if "--briefing-sync" in args:
		await briefing_sync(world, radio, 3.0 if "--fast" in args else 1.0)
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
	if "--castle-first" in args:
		var castle=world.buildings.filter(func(b):return b.building_id==world.HeadGames.CASTLE)[0]
		var beacons:Array=world.buildings.filter(func(b):return world.actor_alive(b) and b.special.has("head_games_beacon"))
		castle._die(null,true)
		world.allied_state.head_media_clock=100.0
		world.HeadGames.objectives(world)
		check(beacons.size()==2 and beacons.all(func(b):return world.actor_alive(b)),"城堡先毁，信标保留至三秒分支")
		world.allied_state.head_media_clock=103.0
		world.HeadGames.objectives(world)
		check(beacons.all(func(b):return not world.actor_alive(b)) and world.allied_state.has("head_games_freed_0") and world.allied_state.has("head_games_freed_1"),"三秒后拆除两侧剩余信标并解放两翼")
		check(not world.ended,"拆信标时不提前结算")
		world.allied_state.head_media_clock=112.0
		world.HeadGames.objectives(world)
		check(world.ended,"欢呼后的原版胜利延迟到期")
		tree.quit(failed);return
	if "--cloning-vats" in args:
		var vat = world.buildings.filter(func(b): return b.building_id == "NACLON")[0]
		var barracks = world._place_building("NAHAND", "ally", world.player_start() + Vector2(300,300), true)
		var yard = world._place_building("NACNST", "ally", world.player_start() + Vector2(500,300), true)
		check(yard != null and barracks != null and vat.side == "enemy" and vat.data.capturable, "原图尤里复制中心允许工程师占领")
		world.credit_side("ally", 10000)
		check_vat_training(world, barracks, 1, "未占领时")
		var engineer = world.spawn_unit("SENGINEER", "ally", vat.position + Vector2(160,0))
		world.fog._reveal("ally", vat.position, 260.0, 2.0)
		check(engineer.order_interaction("allied_engineer", vat, false), "工程师接受占领复制中心命令")
		engineer.position = AlliedAbilities.approach(engineer, vat)
		for i in 100:
			if not world.actor_alive(engineer): break
			AlliedAbilities.tick_action(engineer, 0.1)
		check(vat.side == "ally" and not world.actor_alive(engineer), "工程师进门完成转属")
		check_vat_training(world, barracks, 2, "占领后")
		check(world.units.any(func(u): return u.side == "ally" and u.unit_id == "E2" and u.position.distance_to(vat.position) < 300.0), "复制品在复制中心旁出场")
		var support = preload("res://scripts/world/yuri_support.gd")
		var hero = world.spawn_unit("BORIS", "ally", world.player_start() + Vector2(700,300))
		var before_hero: int = world.units.size()
		support.clone_infantry(world, barracks, hero)
		check(world.actor_alive(hero) and world.units.size() == before_hero, "唯一英雄不绕过限额复制")
		vat.data.capturable = false
		vat.data.desc = "尤里的兵员复制设施。"
		check(BattleSaves.save_slot(world, "slot1").ok, "写入模拟旧规则的存档")
		vat.under_construction = true
		check_vat_training(world, barracks, 1, "设施未运转时")
		vat.under_construction = false
		vat.receive_hit(100000)
		check_vat_training(world, barracks, 1, "设施摧毁后")
		tree.quit(failed);return
	if "--secret-lab" in args:
		var lab=world.buildings.filter(func(b):return b.building_id=="CASLAB")[0]
		var yard=world._place_building("NACNST","ally",world.player_start()+Vector2(320,300),true)
		check(lab.side=="enemy" and lab.data.capturable and lab.data.unsellable and yard!=null,"原图尤里实验室可占领，不可出售")
		world.request_structure("GTGCAN")
		check(world.struct_queue.is_empty(),"未夺实验室不能直接请求巨炮")
		var engineer=world.spawn_unit("SENGINEER","ally",lab.position+Vector2(160,0))
		world.fog._reveal("ally",lab.position,260.0,2.0)
		check(engineer.order_interaction("allied_engineer",lab,false),"工程师接受占领命令")
		engineer.position=AlliedAbilities.approach(engineer,lab)
		for i in 100:
			if not world.actor_alive(engineer):break
			AlliedAbilities.tick_action(engineer,0.1)
		check(lab.side=="ally" and not world.actor_alive(engineer) and lab._col.is_equal_approx(HouseColor.mission_color("ally")),"进门转属、消耗工程师并刷新玩家房色")
		world.hud.prod_tab="defense"
		check(world.hud._building_catalog().has("GTGCAN") and world.hud._build_state("GTGCAN").ok,"苏军有秘密实验室时出现可用巨炮卡")
		world.request_structure("GTGCAN")
		check(world.struct_queue.any(func(j):return j.id=="GTGCAN"),"正式建造请求进入队列")
		var balance:float=world.funds_for("ally")
		world._tick_structure_jobs(1000.0,world.struct_queue,world.struct_ready,"ally")
		check(world.funds_for("ally")<balance and world.struct_ready.get("GTGCAN",0)==1,"正式队列扣费并进入可交付状态")
		var spot:Vector2=world.player_start()+Vector2(600,300)
		check(world.deliver_ready_structure("GTGCAN","ally",spot)!=null,"建造场交付巨炮")
		lab.receive_hit(100000)
		check(not world.hud._building_catalog().has("GTGCAN") and not world.structure_production_block_reason("GTGCAN").is_empty(),"失去设施撤销巨炮权限")
		world.struct_ready.GTGCAN=1
		check(world.deliver_ready_structure("GTGCAN","ally",lab.position)==null,"失厂后不能绕过权限交付已就绪巨炮")
		tree.quit(failed);return
	if "--volunteers" in args:
		var s:Dictionary=world.allied_state
		var volunteers:Array=world.units.filter(func(u):return world.actor_alive(u) and u.special.get("head_volunteer",false))
		check(volunteers.size()==5 and volunteers.all(func(u):return u.side=="neutral"),"原图五名志愿军在发现前已在战场，尚未归玩家")
		if volunteers.size()!=5: tree.quit(failed);return
		var barracks=world._place_building("NAHAND","ally",world.player_start()+Vector2(300,300),true)
		var factory=world._place_building("NAWEAP","ally",world.player_start()+Vector2(600,300),true)
		check(not barracks.can_queue("TERROR") and not factory.can_queue("DTRUCK"),"发现以前不能直接从工厂下单")
		world.HeadGames.rally_volunteers(world,s,0.0)
		check(not s.has("head_volunteers"),"志愿军未进入视野，不触发接管")
		var lost=volunteers.pop_back()
		lost._die(null,true)
		var scout=world.spawn_unit("E2","ally",volunteers[0].position+Vector2(45,0))
		world.fog.rebuild()
		check(scout!=null and world.actor_visible_to("ally",volunteers[0]),"侦察步兵实际打开志愿军位置的视野")
		world.HeadGames.rally_volunteers(world,s,1.0)
		check(s.has("head_volunteers") and volunteers.all(func(u):return u.side=="ally" and u.has_move_order),"发现后同一批幸存者转属并接到集合命令")
		check(not world.actor_alive(lost) and world.units.filter(func(u):return world.actor_alive(u) and u.special.get("head_volunteer",false)).size()==4,"不会重生已阵亡的志愿军")
		check(not barracks.can_queue("TERROR") and not factory.can_queue("DTRUCK"),"接管后仍需要雷达")
		var radar=world._place_building("NARADR","ally",world.player_start()+Vector2(100,500),true)
		check(radar!=null and barracks.can_queue("TERROR") and factory.can_queue("DTRUCK"),"苏军兵营和战车工厂保留各自前置，雷达齐备后可下单")
		var cash:float=world.funds_for("ally")
		check(barracks.enqueue("TERROR") and factory.enqueue("DTRUCK"),"通过正式队列接受两种志愿军订单")
		for _i in 8:
			barracks._tick_unit_queue(100.0,"TERROR")
			factory._tick_unit_queue(100.0,"DTRUCK")
		check(world.funds_for("ally")<cash and not barracks.production.has("TERROR") and not factory.production.has("DTRUCK"),"两种订单随进度扣款并出厂")
		world.HeadGames.rally_volunteers(world,s,2.0)
		check(s.get("head_volunteers",-1.0)==1.0,"重复发现不触发第二次接管")
		tree.quit(failed)
		return
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
	if "--battle-frame-perf" in args:
		await preload("res://tests/head_games_frame_probe.gd").new().run(self, world, args)
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
		sites.super_site(world,"csof125")
		sites.super_site(world,"csof128")
		var dominator=world.buildings.filter(func(b):return b.building_id=="YAPPET")[0]
		dominator._sw_charge=dominator.sw_recharge()-45.0
		check(dominator._layer_visible("superanimthree") and not dominator.sw_ready(),"战役脚本生成的控制器在充满前已经打开")
		var launcher=world.buildings.filter(func(b):return b.building_id=="YAGNTC")[0]
		var target=world.spawn_unit("E2","ally",launcher.position+Vector2(240,100))
		# Earlier friendly infantry can also be legal AI choices. Put the fixture
		# target first and reveal it so this assertion is deterministic.
		world.units.erase(target)
		world.units.push_front(target)
		world.fog._reveal("enemy",target.position,330.0,2.0)
		world.fog.rebuild()
		launcher._sw_charge=launcher.sw_recharge()-60.0
		check(launcher._layer_visible("superanimtwo") and not launcher.sw_ready(),"战役脚本生成的突变器在充满前开盖")
		launcher._sw_charge=launcher.sw_recharge()
		orders.tick(world,75)
		check(not world.actor_alive(target) and launcher._sw_charge==0,"敌方基因突变器充满后自动选中可见步兵并发射")
		check(launcher._layer_visible("superanimfour"),"首脑游戏敌方实际发射后进入关盖动画")
		tree.quit(failed)
		return
	if "--retail-defense-routes" in args:
		var orders=world.HeadGames.Orders
		var state:Dictionary=world.allied_state
		var u=world.spawn_unit("LTNK","enemy",world.player_start()+Vector2(100,100))
		for id in orders.DRIVERS.ai:
			orders.start_defense(world,u,id)
			var row:Dictionary=u.special.s07_defense
			check(row.get("goal",Vector2.INF).is_finite() and u.has_move_order,"逐ID执行原防守移动："+id)
			if not row.has("goal"):continue
			for i in 12:
				if not row.has("goal"):break
				u.position=row.goal
				u.order_stop()
				orders.advance_defender(world,u,10.0)
			check(row.has("until") and row.until>10 and u.hold_position,"抵达后原脚本定时警戒："+id)
			if not row.has("until"):continue
			if id=="0a2f2edc":check(BattleSaves.save_slot(world,"slot1").ok,"写盘防守队正在警戒")
			orders.advance_defender(world,u,float(row.until)-0.1)
			check(not u.has_move_order,"计时未满继续警戒："+id)
			orders.advance_defender(world,u,float(row.until))
			check(u.has_move_order,"计时满继续下一航点："+id)
		check(orders.DRIVERS.ai.size()==12,"十二条独立零售规则")
		for pair in [[-1,"csof125"],[0,"csof001"],[1,"csof010"]]:
			check(not world.HeadGames.retail_yard_disabled(world,pair[0],pair[1]),"未失建造场则保留分支")
			state["s07_no_yard_%d"%pair[0]]=true
			check(world.HeadGames.retail_yard_disabled(world,pair[0],pair[1]),"三房各自关闭超武计划")
		tree.quit(failed);return
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
		check(state.s07_routes.all(func(r):return float(r.next)>=91 and float(r.next)<=151),"九条随机生成定时均落在零售30至90秒区间")
		var route:Dictionary=state.s07_routes[0]
		var gate:Vector2=route.gate
		route.resident.position=gate
		var balance:float=world.funds_for("s07_yuri")
		orders.tick(world,62)
		check(route.resident==null and world.funds_for("s07_yuri")>balance,"到厂消耗居民并结算资金")
		route.house.receive_hit(100000)
		orders.tick(world,152)
		check(route.resident==null and state.s07_route_disabled.has("07C1C26C") and state.s07_route_disabled.has("07C1D25C"),"原图 N 房被毁关闭两条路线")
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
		var bunkers: Array = world.buildings.filter(func(b): return b.building_id=="NABNKR")
		for frame in 650:
			await tree.physics_frame
			if not plant.special.get("occupants",[]).is_empty() and bunkers.any(func(b):return not b.special.get("occupants",[]).is_empty()):break
		check(plant.special.get("occupants",[]).size()>0,"生物反应炉实际进入步兵")
		check(bunkers.any(func(b):return b.special.get("occupants",[]).any(func(u):return u.embarked_in==b)),"开局脚本队按真实移动进入战斗碉堡")
		var crypt=world.buildings.filter(func(b):return world.actor_alive(b) and b.building_id=="CATRAN02")[0]
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
		world.allied_state.head_media_clock=445
		world.HeadGames.media_events(world)
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
	if "--grinder-script" in args:
		var s:Dictionary=world.allied_state
		var plant=world.buildings.filter(func(b):return b.special.get("head_grinder")=="sw")[0]
		var scout=world.spawn_unit("E2","ally",world.player_start())
		plant.receive_hit(10,"bullet",{},scout)
		check(s.get("head_seen_sw",false),"西南回收厂遭袭唤起守队")
		plant.receive_hit(100000,"shell",{},scout)
		check(s.get("head_grinder_crates",{}).has("sw"),"拆西南回收厂在 BU 生成资金箱")
		checks_residents(world,"sw","ne")
		var other=world.buildings.filter(func(b):return b.special.get("head_grinder")=="ne")[0]
		other.receive_hit(100000,"shell",{},scout)
		check(s.get("head_grinder_crates",{}).has("ne"),"拆东北回收厂在 BV 生成资金箱")
		var cash:float=world.funds_for("ally")
		for key in s.get("head_grinder_crates",{}).keys():
			var point: Vector2 = s.head_grinder_crates[key]
			scout.position=point
			world.HeadGames.grinder_crates_tick(world)
			world.HeadGames.grinder_crates_tick(world)
			var flashes: Array = world.effects_root.get_children().filter(func(f): return f is Ra2Fx and f.anim.get("image") == "MONEY" and f.position == point)
			check(flashes.size()==1,"回收厂资金箱在原位只播放一次金色 $")
		world.HeadGames.grinder_lost(world,"sw")
		check(s.head_grinder_crates.is_empty() and world.funds_for("ally")==cash+5000,"按本关覆盖两箱各两千五，只能领一次")
		var refinery=world.buildings.filter(func(b):return b.building_id=="GAREFN" and b.side=="enemy")[0]
		var spy=world.spawn_unit("SPY","ally",world.player_start())
		var account:String=world.economy_owner(refinery)
		var before:float=world.funds_for(account)
		AlliedAbilities.resolve_infiltration(spy,refinery)
		check(is_equal_approx(world.funds_for(account),before*0.95),"间谍按本关覆盖只扣目标房百分之五")
		tree.quit(failed);return
	if "--backdoor-script" in args:
		var p:Array=world.HeadGames.FIELD.data.backdoor_cells[0]
		var dest:Array=world.HeadGames.FIELD.data.backdoor_reveal
		var marker:Vector2=(Vector2(dest[0],dest[1])+Vector2.ONE*0.5)*55.0
		var scout=world.spawn_unit("E2","ally",(Vector2(p[0],p[1])+Vector2.ONE*0.5)*55.0)
		check(scout!=null and not world.fog.is_explored_at("ally",marker),"夹具先将侦察兵放到后路格，目标仍在迷雾内")
		world.hud.minimap._pings.clear()
		var transport=world.spawn_unit("HTK","ally",scout.position+Vector2(200,0))
		scout.set_stowed(transport)
		world.HeadGames.field_events(world,1.0)
		check(not world.allied_state.has("head_backdoor"),"藏在车里的步兵不算进入后路触发格")
		scout.set_stowed(null)
		world.HeadGames.field_events(world,1.0)
		check(world.allied_state.get("head_backdoor",false) and world.hud.minimap._pings.any(func(item):return item.kind=="campaign_discovery"),"后路格触发雷达提示")
		check(not world.fog.is_explored_at("ally",marker),"原图雷达事件不替玩家开迷雾")
		world.hud.minimap._pings.clear()
		world.HeadGames.field_events(world,1.0)
		check(not world.hud.minimap._pings.any(func(item):return item.kind=="campaign_discovery"),"后路提示只发一次")
		scout.position=Vector2(68.5,107.5)*55
		scout.set_stowed(transport)
		world.HeadGames.field_events(world,1.0)
		check(not world.allied_state.has("head_hello"),"彩蛋格不接受藏在车里的步兵")
		scout.set_stowed(null)
		world.HeadGames.field_events(world,1.0)
		check(world.allied_state.get("head_hello",false),"地面步兵进入原图彩蛋格触发文字")
		tree.quit(failed);return
	if "--house-economy" in args:
		var yuri:=world.HeadEconomy.account(-1) as String
		var sov:=world.HeadEconomy.account(0) as String
		var allies:=world.HeadEconomy.account(1) as String
		check([yuri,sov,allies].all(func(key):return is_equal_approx(world.funds_for(key),40000.0)),"三敌房各自从四万起账")
		var factory=world.buildings.filter(func(b):return b.building_id=="GAWEAP" and b.side=="enemy")[0]
		check(factory.enqueue("FV"),"受控盟军工厂下单")
		factory._tick_unit_queue(1000.0,"FV")
		check(is_equal_approx(world.funds_for(allies),40000.0-float(GameData.get_unit("FV").cost)) and world.funds_for(sov)==40000.0 and world.funds_for(yuri)==40000.0,"出厂只扣盟军房资金")
		var miner=world.units.filter(func(u):return u.unit_id=="HARV" and u.side=="enemy")[0]
		var foreign=world.buildings.filter(func(b):return b.building_id=="GAREFN" and b.side=="enemy")[0]
		check(not miner.order_return_to_refinery(foreign),"苏军矿车不在受控盟军矿场卸矿")
		miner.cargo=4.0
		var value:float=miner.cargo_value()
		miner._unload_cargo(4.0)
		check(is_equal_approx(world.funds_for(sov),40000.0+value),"卸矿只入苏军房账户")
		var cash:float=world.funds_for(allies)
		check(world.transfer_drain_funds(world.economy_owner(foreign),"ally",50)==50 and world.funds_for(allies)==cash-50.0 and world.funds_for(yuri)==40000.0,"吸矿从被吸矿厂所属房扣款")
		check(not world.spend_side(allies,40001.0) and world.funds_for(sov)>40000.0,"一家余额不足时不能透支其他敌房")
		AlliedAbilities.change_side(factory,"ally")
		check(world.economy_owner(factory)=="ally" and world.funds_for(allies)==cash-50.0,"转属工厂改走玩家账户，不转走敌房余额")
		check(BattleSaves.save_slot(world,"slot1").ok,"独立房余额写盘")
		tree.quit(failed);return
	if "--retail-production-houses" in args:
		var orders=world.HeadGames.Orders
		var rules=orders.DATA.data.rules
		check(orders.DRIVERS.production.size()==73 and not orders.DRIVERS.production.has("08cf30fc"),"73非空，排除原图空编组")
		for rule in rules:
			if rule.team.is_empty():continue
			var row:Dictionary=orders.DRIVERS.production[rule.id]
			var expected:Dictionary=rule.team.duplicate()
			if expected.has("ADOG"):
				expected["DOG"]=int(expected.get("DOG",0))+int(expected.ADOG)
				expected.erase("ADOG")
			var wing:int=1 if rule.id in ["0a2f2edc","08cf608c"] else int(rule.wing)
			var live:Dictionary=orders.production_members(row)
			var same:bool=live.size()==expected.size() and expected.keys().all(func(k):return int(live.get(k,-1))==int(expected[k]))
			check(row.enabled and int(row.wing)==wing and same,"正式选队读取原房及编组："+rule.id)
		var s:Dictionary=world.allied_state
		var scout=world.spawn_unit("E2","ally",world.player_start())
		for id in ["0965013C","0965263C","0965230C"]:
			var row:Dictionary=orders.DRIVERS.extra[id]
			s.s07_hostility_flags={"15":true}
			scout.position=Vector2(int(row.cells[0][0]),int(row.cells[0][1]))*55.0+Vector2.ONE*27.5
			world.HeadGames.retail_hostility_cells(world,s)
			check(s.s07_hostility_cells.has(id) and not s.s07_hostility_flags.has("15"),"原格进入唤起对应房："+id)
		tree.quit(failed);return
	if "--retail-weight-feedback" in args:
		var orders=world.HeadGames.Orders
		var s:Dictionary=world.allied_state
		var u=world.spawn_unit("LTNK","enemy",world.player_start()+Vector2(250,200))
		var config:Dictionary=orders.DRIVERS.weightFeedback
		for id in config.rules:
			var range_row:Array=config.rules[id]
			for success in [false,true]:
				s.s07_feedback=[{"id":id,"members":[u],"success":success}]
				s.s07_retail_weights={id:range_row[0]}
				orders.settle_feedback(world)
				var expected:=clampf(float(range_row[0])+float(config.success if success else config.failure),float(range_row[1]),float(range_row[2]))
				check(is_equal_approx(s.s07_retail_weights[id],expected) and s.s07_feedback.is_empty(),"逐ID结算反馈与边界："+id)
		var id:String=config.rules.keys()[0]
		var script:Array=orders.DRIVERS.assaults[id]
		var step:=script.find_custom(func(row):return int(row[0])==49)
		u.special.s07_assault={"id":id,"step":step,"origin":u.position}
		u.special.s07_feedback_pending=true
		s.s07_feedback=[{"id":id,"members":[u],"success":false}]
		orders.advance_assault(world,u,0.0)
		check(s.s07_feedback[0].success,"原49动作提交成功给真实队伍票据")
		tree.quit(failed);return
	if "--retail-assault-ai" in args:
		var orders=world.HeadGames.Orders
		var p:Vector2=world.player_start()+Vector2(250,200)
		var u=world.spawn_unit("LTNK","enemy",p)
		var target=world.spawn_unit("E2","ally",p+Vector2(65,0))
		world._place_building("NAPOWR","ally",p+Vector2(200,200),true)
		world.fog._reveal("enemy",p,1200.0,5.0)
		for id in orders.DRIVERS.assaults:
			u.order_stop(false)
			orders.start_assault(world,u,id)
			var script:Array=orders.DRIVERS.assaults[id]
			var state:Dictionary=u.special.get("s07_assault",{})
			check(not state.is_empty() and (u.has_move_order or u.attack_ordered or state.step<script.size()),"正式AI脚本入口与状态："+id)
			for j in script.size():
				if not u.special.has("s07_assault") or u.attack_ordered:break
				if u.has_move_order:u.position=u.move_target;u.order_stop(false)
				orders.advance_assault(world,u,200.0+j)
			check((u.attack_ordered and world.actor_alive(u.attack_target) and u.attack_target.side=="ally") or u.has_move_order,"按脚本下达进攻或搜敌："+id)
		check(orders.DRIVERS.assaults.size()==41 and not orders.DRIVERS.assaults.has("08cf30fc") and world.actor_alive(target),"41个非空候选进入新命令适配，原空编组排除")
		tree.quit(failed);return
	if "--retail-force-ai" in args:
		var orders=world.HeadGames.Orders
		for id in orders.DRIVERS.forceCount:
			var row:Dictionary=orders.DRIVERS.forceCount[id]
			var t:int=row.threshold
			check(orders.force_allowed(id,{row.entity:t-1})==(int(row.op)==1) and orders.force_allowed(id,{row.entity:t})==(int(row.op)!=4) and orders.force_allowed(id,{row.entity:t+1})==(int(row.op)!=1),"零售玩家兵力边界："+id)
		check(orders.DRIVERS.forceCount.size()==29,"29条对应规则")
		tree.quit(failed);return
	if "--retail-super-chain" in args:
		var s:Dictionary=world.allied_state
		BattleRequest.skirmish_config.difficulty=1
		var silo=world._place_building("NAIRON","ally",world.player_start()+Vector2(400,250),true)
		s.head_media_clock=50.0
		world.HeadGames.superweapon_built(world,silo)
		check(s.get("s07_super_enabled",[]).size()==6,"铁幕完成启用两房四条和尤里两条分支")
		for t in [254,255,374,375,494,495,699,700]:
			s.head_media_clock=t
			world.HeadGames.media_events(world)
			check(s.get("csof001",false)==(t>=255) and s.get("csof010",false)==(t>=375) and s.get("csof125",false)==(t>=495) and s.get("csof128",false)==(t>=700),"原二段超武时间边界 %d"%t)
		check(world.buildings.filter(func(b):return world.actor_alive(b) and b.special.get("s07_launcher",false)).size()==4,"四座正式任务超武实际生成")
		tree.quit(failed);return
	if "--retail-credit-ai" in args:
		var orders=world.HeadGames.Orders
		var data:Dictionary=orders.DRIVERS.credit
		for id in data:
			var row:Dictionary=data[id]
			var threshold:float=row.threshold
			check(not orders.credit_allowed(id,threshold-1.0) and orders.credit_allowed(id,threshold+1.0) and orders.credit_allowed(id,threshold)==(int(row.op)==3),"零售资金规则边界："+id)
		check(data.size()==44,"四十四条非空资金规则")
		var id:="08cf2edc"
		var limit:float=data[id].threshold
		var player:float=world.funds_for("ally")
		if player<limit:world.credit_side("ally",limit-player+1.0,true)
		check(orders.credit_allowed(id,world.funds_for("ally")),"实战玩家钱包变化可跨越原门槛")
		tree.quit(failed);return
	if "--combine-kia" in args:
		var combo=preload("res://scripts/world/head_games_combine.gd")
		var s:Dictionary=world.allied_state
		s.head_media_clock=100.0
		var first_car=combo.recruit(world,"FV","alpha0/0car")
		var first_crew=combo.recruit(world,"SHK","alpha0/0crew")
		var second_car=world.spawn_unit("FV","enemy",combo.MEET)
		world.HeadGames.assign_wing(second_car,1)
		second_car.special.combo_slot="alpha0/1car"
		var second_crew=world.spawn_unit("SHK","enemy",combo.MEET)
		world.HeadGames.assign_wing(second_crew,0)
		second_crew.special.combo_slot="alpha0/1crew"
		first_car._die(null,true)
		second_crew._die(null,true)
		check(s.combo_retry.get("alpha0/0car")==102.0 and s.combo_retry.get("alpha0/1crew")==102.0 and s.combo_retry.size()==2,"两对各自只重派失去的先遣成员")
		check(combo.recruit(world,"FV","alpha0/0car")==null and combo.recruit(world,"SHK","alpha0/0crew")==first_crew,"两秒前不招替代车，幸存乘员保留")
		var pair:Dictionary=combo.pair_state(s,1)
		pair.merged=true;pair.sent=true
		second_car._die(null,true)
		check(pair.is_empty() and combo.pair_state(s,0).is_empty(),"已出击的合编车损失只重置对应一对")
		s.head_media_clock=102.0
		var replacement=world.spawn_unit("FV","enemy",combo.MEET+Vector2(72,0))
		world.HeadGames.assign_wing(replacement,1)
		check(combo.recruit(world,"FV","alpha0/0car")!=null,"两秒后招到替补车")
		var selected=combo.recruit(world,"FV","alpha0/0car")
		selected.position=combo.MEET+Vector2(72,0)
		first_crew.position=selected.position+Vector2(10,0)
		combo.advance_alpha(world,102.0,2)
		first_crew.logistics.tick(0.1)
		combo.advance_alpha(world,103.0,2)
		check(first_crew.embarked_in==selected and combo.pair_state(s,0).get("merged",false),"替补与原乘员走正式登车重新合编")
		selected.position=combo.FORM+Vector2(72,0)
		combo.advance_alpha(world,105.0,2)
		check(combo.pair_state(s,0).get("sent",false) and selected.has_move_order and selected.move_target!=combo.FORM+Vector2(72,0),"替补合编车重新得到出击命令")
		s.head_games_freed_0=true
		first_crew._die(null,true)
		check(not s.combo_retry.has("alpha0/0crew"),"解放任一翼后不再替补")
		tree.quit(failed);return
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
		combo.advance(world,"alpha",694,2)
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
		var state:Dictionary=world.allied_state
		state.combo_alpha_restart=900.0
		state.combo_flags={"9":true,"10":true}
		combo.advance_alpha(world,900.0,2)
		check(state.combo_alpha_cycle==1 and state.combo_alpha_due==1140.0 and state.combo_flags.is_empty() and not state.has("combo_second_due"),"Alpha收尾清旗并从零售240秒重新启用")
		check(car.special.get("combo_attack_active",false) and not car.special.has("combo_slot"),"下一波不能抢走已出击的Alpha车")
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
		world.allied_state.head_media_clock=445.0
		world.HeadGames.media_events(world)
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
	var n_before:int=world.units.size()
	castle.hp-=10
	world._check_end()
	check(not world.allied_state.has("castle_alert"),"仅改变城堡血量不触发遇袭事件")
	castle.receive_hit(120)
	check(world.allied_state.get("castle_alert",false) and world.units.any(func(u):return u.unit_id=="YENGINEER"),"城堡真实受袭立即召集守军，不等待目标轮询")
	var n_after:int=world.units.size()
	castle.receive_hit(120)
	check(n_after>n_before and world.units.size()==n_after,"连续受袭不重复派守军")
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
