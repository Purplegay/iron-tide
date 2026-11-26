extends Node

var failures := 0

func check(ok:bool, label:String) -> void:
	print("HOLLYWOOD ", ok, " ", label)
	if not ok: failures += 1

func _ready() -> void:
	call_deferred("run")

func resident_combat(world) -> void:
	var start := Vector2.INF
	for x in range(400, int(world.map_size)-400, 300):
		for y in range(400, int(world.map_size)-400, 300):
			var p := Vector2(x,y)
			if world.in_water_world(p) or world.path_service.is_blocked(p) or world.path_service.is_blocked(p+Vector2(95,0)): continue
			if world.units.any(func(u):return u.position.distance_to(p)<800) or world.buildings.any(func(b):return b.position.distance_to(p)<500): continue
			start=p
			break
		if start.is_finite(): break
	check(start.is_finite(),"隔离街道内无其它交战目标")
	if not start.is_finite():return
	var actor = world.spawn_unit("MTNK","ally",start)
	var street = world.units.filter(func(u):return u.unit_id=="CIV2" and u.special.get("hollywood_house")=="YuriCountry")[0]
	var state:Dictionary = world.allied_state.hollywood
	state.briefing=false
	state.poll=100.0
	world.Hollywood.crowd(world,state)
	var queue = world.units.filter(func(u):return u.special.has("hollywood_civilian"))[0]
	street.position = start + Vector2(80,0)
	queue.position = start + Vector2(0,110)
	queue.order_stop(false)
	world.neighborhood.relocate(street)
	world.neighborhood.relocate(queue)
	world.fog.rebuild()
	world.select_unit(actor,false)
	var enemies := BattleRequest.foes_group("ally")
	for resident in [street,queue]:
		check(not resident.is_in_group(enemies) and not resident.is_in_group("ally_targets"),"居民不进我方敌军和伤害候选组 "+resident.unit_id)
		check(world._pick_enemy_at(resident.position)!=resident,"普通攻击光标不把居民识别为敌人")
	var old_hp:float = street.hp + queue.hp
	var acquired := false
	for step in 240:
		await get_tree().physics_frame
		acquired = acquired or actor.attack_target in [street,queue]
		if street.hp+queue.hp < old_hp: break
	check(not acquired and is_equal_approx(street.hp+queue.hp,old_hp),"我方坦克警戒锁定居民=%s，居民合计生命 %s→%s" % [acquired,old_hp,street.hp+queue.hp])
	# Reproduce a save made by a build which classified the crowd as hostile.
	street.side="enemy"
	for resident in [street,queue]:
		resident.add_to_group("enemies")
		resident.add_to_group("ally_targets")
	actor.attack_target=street
	actor.attack_ordered=true
	var codec=preload("res://scripts/save/battle_snapshot.gd").new()
	var snap:Dictionary=codec.capture(world)
	codec.restore(world,snap)
	world.paused=false
	get_tree().paused=false
	street=world.units.filter(func(u):return u.unit_id=="CIV2" and u.special.get("hollywood_house")=="YuriCountry")[0]
	queue=world.units.filter(func(u):return u.special.has("hollywood_civilian") and u.position.distance_to(start)<200)[0]
	actor=world.units.filter(func(u):return u.unit_id=="MTNK" and u.position.distance_to(start)<100)[0]
	check(street.side=="neutral" and not street.is_in_group(enemies) and not queue.is_in_group(enemies),"恢复旧快照纠正两类居民的敌我分组")
	actor._refresh_target()
	check(actor.attack_target!=street and not actor.attack_ordered,"旧快照中的普通攻击命令失效")
	var house = world.buildings.filter(func(b):return b.side=="neutral" and b.data.has("garrison_weapons"))[0]
	var infantry = world.spawn_unit("E1","ally",house._spawn_point("E1"))
	var ops=preload("res://scripts/units/civilian_orders.gd")
	ops.enter(infantry,house)
	street.position=house.position+Vector2(65,0)
	world.neighborhood.relocate(street)
	world.fog.rebuild()
	infantry._think_timer=0.0
	ops.tick(infantry,0.1)
	check(infantry.embarked_in==house and world.actor_visible_to("ally",street) and not ops.visible_enemy(house,street) and infantry.attack_target!=street,"我方驻楼步兵不向可见的近处居民开火")
	var plant = world.buildings.filter(func(b):return b.special.get("hollywood_plant")==queue.special.hollywood_civilian)[0]
	plant._die()
	world.Hollywood.plants_tick(world,world.allied_state.hollywood,[],0.5)
	check(not queue.special.has("hollywood_civilian") and not queue.is_in_group(enemies) and queue.side=="neutral","拆厂获救后居民继续保持中立")
	var hostile = world.spawn_unit("INIT","enemy",actor.position + Vector2(95,0))
	hostile.set_fire_stance("none")
	world.fog.rebuild()
	for step in 360:
		await get_tree().physics_frame
		if not world.actor_alive(hostile) or hostile.hp<hostile.max_hp: break
	check(not world.actor_alive(hostile) or hostile.hp<hostile.max_hp,"同一街区我方仍主动开火命中尤里新兵")

func facility_picture(world, building, state: String) -> void:
	world.fog._reveal("ally", building.position, world.Hollywood.BRIEFING_SIGHT, 10.0)
	world.fog.rebuild()
	get_tree().paused = true
	world.center_on(building.position)
	world.camera.force_update_scroll()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var center: Vector2 = get_viewport().get_final_transform() * building.get_global_transform_with_canvas().origin - Vector2(0,70)
	var crop := image.get_region(Rect2i(Vector2i(center) - Vector2i(200,160), Vector2i(400,320)))
	check(crop.save_png(OS.get_environment("TEMP") + "/" + building.building_id + "-facade-" + state + ".png") == OK, "保存设施实机画面 " + state)
	get_tree().paused = false

func capture_aid(world) -> void:
	world.allied_state.hollywood.briefing = false
	var airfields:Array = world.buildings.filter(func(b):return b.building_id == "CALA05")
	var hospitals:Array = world.buildings.filter(func(b):return b.building_id == "CATHOSP")
	check(airfields.size()==1 and hospitals.size()==1,"任务原图各有一座国际机场和科技医院")
	if airfields.is_empty() or hospitals.is_empty(): return
	var airport = airfields[0]
	var hospital = hospitals[0]
	check(hospital.side == "neutral" and hospital.material.get_shader_parameter("target_color").is_equal_approx(Color.GRAY), "医院开场使用中立灰色涂装")
	var wounded = world.spawn_unit("E1","ally",world.player_start())
	wounded.hp = wounded.max_hp - 35
	var before:float = wounded.hp
	hospital._process(4.0)
	check(wounded.hp == before,"中立医院不提供自愈")
	airport._tick_superweapon(250)
	check(not airport.sw_ready() and not world.owns_superweapon(airport),"占领前机场无充能或玩家支援")
	world._countries.ally = "Americans"
	var radar = world._place_building("GAAIRC","ally",world.player_start(),true)
	check(radar.superweapon.is_empty(),"本关美国空指部禁用八人空降")
	for site in [hospital,airport]:
		var start:Vector2 = site._spawn_point("ENGINEER")
		var engineer = world.spawn_unit("ENGINEER","ally",start)
		var scout = world.spawn_unit("E1","ally",start + Vector2(20,0))
		world.center_on(site.position)
		world.fog.rebuild()
		world.select_unit(engineer,false)
		check(AlliedAbilities.default_order(scout,site).is_empty(),"普通步兵无法进驻 "+site.building_id)
		var click:Vector2 = site.position
		if site == airport:
			# The original SHP canvas has transparent sky above the terminal.
			var rect := RA2Art.draw_rect(site._ra2, site.radius, [0], 0, Building.RA2_SPRITE_SCALE)
			click = site.position + RA2Art.art_dir(rect.position + Vector2(96,137) * Building.RA2_SPRITE_SCALE)
			check(site.hit_test(click) and world.support_order_target(click)==site, "机场航站楼屋顶像素可点击")
		if site == hospital and "--hospital-pictures" in OS.get_cmdline_user_args():
			await facility_picture(world,hospital,"neutral")
			click = hospital.art_center()
		world._issue_order(click)
		check(engineer.special.get("target") == site and engineer.special.get("action")=="allied_engineer","右键下达工程师占领 "+site.building_id)
		for step in 420:
			await get_tree().physics_frame
			if site.side=="ally": break
		check(site.side=="ally" and not world.actor_alive(engineer),"到达后换边并消耗工程师 "+site.building_id)
		if site.side!="ally": return
		if site == hospital and "--hospital-pictures" in OS.get_cmdline_user_args():
			await facility_picture(world,hospital,"ally")
		check(not world.building_action_reason("sell",site).is_empty(),"科技设施禁止出售 "+site.building_id)
	check(hospital.material != null and hospital.material.get_shader_parameter("paint_mode") == HouseColor.PaintMode.HOSPITAL_FACADE and hospital.material.get_shader_parameter("target_color").is_equal_approx(HouseColor.player_color()), "医院使用当前玩家涂装")
	check(airport.material != null and airport.material.get_shader_parameter("paint_mode") == HouseColor.PaintMode.CITY_RED_RAMP and airport.material.get_shader_parameter("target_color").is_equal_approx(HouseColor.player_color()), "机场屋顶使用当前玩家涂装")
	var player = world.spawn_unit("E1","ally",world.player_start())
	player.hp = player.max_hp - 40
	var enemy = world.spawn_unit("E1","enemy",world.player_start()+Vector2(400,0))
	enemy.hp = enemy.max_hp - 40
	hospital.special.hospital_elapsed = 0.0
	hospital._process(50.0 / BattleClock.RULE_TICKS_PER_SECOND)
	check(player.hp==player.max_hp-20 and enemy.hp==enemy.max_hp-40,"医院每50规则帧为远处己方步兵恢复20生命")
	var panel = world.hud._sw_sidebar
	panel.refresh()
	check(panel.buttons.has(airport.get_instance_id()) and panel.buttons[airport.get_instance_id()].icon != null,"占领机场出现带原版图标的伞兵按钮")
	world.allied_state.blackout_ally = 30.0
	airport._tick_superweapon(239)
	check(not airport.sw_ready(),"充能未满四分钟")
	airport._tick_superweapon(1)
	panel.refresh()
	check(world.side_power_low("ally") and airport.sw_ready(),"低电状态机场满四分钟仍就绪")
	world.allied_state.erase("blackout_ally")
	panel.buttons[airport.get_instance_id()].pressed.emit()
	world._issue_command_at(Vector2(-5,-5))
	check(airport.sw_ready(),"无效落点保留充能")
	var drop=preload("res://scripts/world/american_paradrop.gd")
	var target:Vector2=drop.open_ground(world,world.player_start()+Vector2(200,220))
	world.arm_superweapon(airport)
	world._issue_command_at(target)
	var planes:Array=world.units.filter(func(u): return u.unit_id=="PDPLANE" and u.side=="ally")
	check(planes.size()==1 and not airport.sw_ready(),"合法落点派出运输机并重新充能")
	if planes.size()!=1: return
	var plane=planes[0]
	check(plane.special.para_left==6,"任务支援装载六名盟军大兵")
	var codec=preload("res://scripts/save/battle_snapshot.gd").new()
	var snap:Dictionary=codec.capture(world)
	check(BattleSaves.validate(snap).is_empty(),"运输机升空后快照有效")
	codec.restore(world,snap)
	airport=world.buildings.filter(func(b):return b.building_id=="CALA05")[0]
	hospital=world.buildings.filter(func(b):return b.building_id=="CATHOSP")[0]
	plane=world.units.filter(func(u):return u.unit_id=="PDPLANE")[0]
	check(hospital.material != null and hospital.material.get_shader_parameter("paint_mode") == HouseColor.PaintMode.HOSPITAL_FACADE and hospital.material.get_shader_parameter("target_color").is_equal_approx(HouseColor.player_color()), "医院使用当前玩家涂装")
	check(airport.material != null and airport.material.get_shader_parameter("paint_mode") == HouseColor.PaintMode.CITY_RED_RAMP and airport.material.get_shader_parameter("target_color").is_equal_approx(HouseColor.player_color()), "机场屋顶使用当前玩家涂装")
	check(airport.side=="ally" and hospital.side=="ally" and airport.sw_type()=="ParaDrop" and plane.special.para_left==6,"读档保留两处归属、支援与运输机载员")
	world.paused=false
	get_tree().paused=false
	for step in 2400:
		plane._physics_process(0.1)
		if plane.special.para_left==0:break
	var troops:Array=world.units.filter(func(u):return u.side=="ally" and u.unit_id=="E1" and u.special.has("para_height"))
	check(troops.size()==6,"地图实际投下六名美国大兵，实投 %d，机上剩余 %d" % [troops.size(),plane.special.para_left])
	for soldier in troops:
		for step in 260:
			if not soldier.special.has("para_height"):break
			soldier._physics_process(1.0/60)
	check(troops.size()==6 and troops.all(func(u):return world.actor_alive(u) and not u.is_air_target()),"六人完成下降并恢复地面步兵")
	AlliedAbilities.change_side(airport,"enemy")
	panel.refresh()
	check(not panel.buttons.has(airport.get_instance_id()) and not world.owns_superweapon(airport),"丢失机场移除玩家援助")
	AlliedAbilities.change_side(hospital,"neutral")
	player=world.units.filter(func(u):return world.actor_alive(u) and u.unit_id=="E1" and u.side=="ally")[0]
	player.hp=player.max_hp-30
	hospital._process(4.0)
	check(player.hp==player.max_hp-30,"丢失医院后停止自愈")

func check_captured_product(world, factory, uid: String, icon: String, cost: int) -> void:
	var hud = world.hud
	hud._update_production_live()
	var button: Button = hud._prod_buttons.get(uid)
	check(is_instance_valid(button) and not button.disabled, "占领后可以生产 " + uid)
	if not is_instance_valid(button): return
	var texture: Texture2D = hud._prod_wipes[uid].icon.cameo_texture
	check(texture != null and texture.resource_path == "res://assets/ra2/cameo/%s.png" % icon, "生产卡加载原版图标 " + icon)
	var label: Label = hud._prod_status_labels[uid]
	var rule_seconds := cost * 0.7 * 60.0 / 1000.0
	var seconds: float = rule_seconds / factory.build_speed / factory.production_work_rate(uid)
	var caption := "%d · %.1fs" % [cost, BattleClock.real_seconds(seconds)]
	check(label.text == caption, "%s 刷新后卡面 %s，预期 %s" % [uid, label.text, caption])
	var speed: float = GM.fast_forward
	BattleClock.set_speed(2.0)
	hud._update_production_live()
	check(label.text == "%d · %.1fs" % [cost, seconds / 2.0], uid + " 二倍速刷新预计用时")
	BattleClock.set_speed(speed)
	hud._update_production_live()
	var balance: float = world.funds_for("ally")
	var count_before: int = world.units.filter(func(u): return u.side == "ally" and u.unit_id == uid).size()
	button.pressed.emit()
	check(factory.production.has(uid), "点击卡片进入占领工厂队列 " + uid)
	factory._tick_unit_queue(seconds * 0.5, uid)
	check(factory.production.has(uid) and is_equal_approx(factory.queue_progress(uid), 0.5) and is_equal_approx(balance - world.funds_for("ally"), cost * 0.5), uid + " 工时过半扣半价")
	factory._tick_unit_queue(seconds * 0.5, uid)
	var produced: int = world.units.filter(func(u): return u.side == "ally" and u.unit_id == uid and not u.special.has("hollywood_house")).size()
	check(not factory.production.has(uid) and produced == count_before + 1 and is_equal_approx(balance - world.funds_for("ally"), cost), uid + " 到时出厂并扣全价")

const BridgeDamage = preload("res://scripts/world/bridge_damage.gd")
const NativeMaps = preload("res://scripts/world/native_maps.gd")
const BRIDGE_CENTERS = [Vector2i(150,118), Vector2i(145,118), Vector2i(56,100), Vector2i(51,100), Vector2i(56,133), Vector2i(51,132)]

func bridge_disk_state(world, broken: bool, repair: bool = false) -> void:
	var native := NativeMaps.data("yr_all02umd")
	var deck = world.ground.overpass
	for center in BRIDGE_CENTERS:
		var part: Rect2 = native.bridge_section_by_cell[center]
		var huts: Array = world.buildings.filter(func(b): return world.actor_alive(b) and b.building_id == "CABHUT" and b.special.get("bridge_span", Rect2()).encloses(part))
		var label := str(center)
		var expected_huts := 1 if center == Vector2i(51,132) else 2
		check(huts.size() == expected_huts and huts.all(func(h): return h.special.get("bridge_repaired") == not broken), "桥头维修状态 " + label)
		check(BridgeDamage.health(world, part) == (0.0 if broken else BridgeDamage.strength()), "桥段血量 " + label)
		check((part in world.ground.broken_bridges) == broken, "断面从存档重建 " + label)
		for lane in range(3):
			check(deck.gaps.has(center + Vector2i.LEFT * lane) == broken, "桥面车道 " + label + " / %d" % lane)
		var edge := (Vector2(center) + Vector2(-0.5,-0.5)) * 55
		var car = world.spawn_unit("MTNK", "ally", edge)
		car.special.hollywood_on_deck = true
		car.move_with_traffic_exceptions(Vector2.DOWN * 55)
		var expected_position := edge if broken else edge + Vector2.DOWN * 55
		check(car.position.is_equal_approx(expected_position) and car.special.has("hollywood_on_deck"), "冷读后车辆通行 " + label)
		car._die()
		if not repair or huts.is_empty(): continue
		var hut = huts[0]
		var engineer = world.spawn_unit("ENGINEER", "ally", hut.position + Vector2.DOWN * 65)
		world.fog._reveal("ally", hut.position, 180.0, 2.0)
		check(engineer.order_interaction("allied_bridge", hut, false), "冷读后工程师接受维修命令 " + label)
		engineer.position = AlliedAbilities.approach(engineer, hut)
		for i in range(90):
			if not world.actor_alive(engineer): break
			AlliedAbilities.tick_action(engineer, 1.0 / 60.0)
		check(not world.actor_alive(engineer) and BridgeDamage.health(world, part) == BridgeDamage.strength(), "工程师完成维修并消耗 " + label)
		check(huts.all(func(h): return h.special.get("bridge_repaired", false)) and not deck.gaps.has(center), "桥面与两端维修小屋同步恢复 " + label)

func run() -> void:
	var tree := get_tree()
	reparent(tree.root)
	var args := OS.get_cmdline_user_args()
	if "--cold-bridge-move-queue" in args:
		var loaded := BattleSaves.load_into_scene("slot3")
		check(loaded.ok, "从磁盘冷读桥面移动及排队指令")
		if not loaded.ok:
			tree.quit(1)
			return
		await tree.scene_changed
		var restored = tree.current_scene.battle
		var actors: Array = restored.units.filter(func(u): return u.special.get("bridge_queue_fixture", false))
		check(actors.size() == 1, "冷读后仅恢复一辆测试车")
		if actors.size() != 1:
			tree.quit(1)
			return
		var tank: Unit = actors[0]
		var deck_goal := Vector2(55.5,139.5)*55
		var street_goal := Vector2(58.5,145.5)*55
		check(tank.has_move_order and tank.move_target.distance_to(deck_goal)<1.0 and tank._path_pts.size()>=4, "当前桥面命令与路线保持")
		check(tank.order_queue.size()==1 and not tank.order_queue[0].deck and tank.order_queue[0].position.distance_to(street_goal)<1.0, "排队街道命令及目标层保持")
		if restored.paused: restored.hud._toggle_pause()
		var visited_deck := false
		var queued_started_on_deck := false
		for step in 2400:
			await tree.physics_frame
			visited_deck = visited_deck or tank.special.has("hollywood_on_deck")
			if tank.order_queue.is_empty() and tank.move_target.distance_to(street_goal)<1.0:
				queued_started_on_deck = queued_started_on_deck or tank.special.has("hollywood_on_deck")
			if not tank.has_move_order and tank.order_queue.is_empty(): break
		check(visited_deck and queued_started_on_deck, "实车在桥面完成首命令后才开始下一条")
		check(tank.order_queue.is_empty() and not tank.has_move_order and tank.position.distance_to(street_goal)<12.0 and not tank.special.has("hollywood_on_deck"), "排队命令执行一次并在街道停下")
		tree.quit(int(failures>0))
		return
	if "--cold-bridge-broken" in args or "--cold-bridge-repaired" in args:
		var broken := "--cold-bridge-broken" in args
		var result := BattleSaves.load_into_scene("slot1" if broken else "slot2")
		check(result.ok, "独立进程从磁盘读取桥梁断点")
		if result.ok:
			await tree.scene_changed
			var world = tree.current_scene.battle
			check(world.paused and world.mission.id == "yr_hollywood", "冷读回到暂停的好莱坞战场")
			bridge_disk_state(world, broken, broken)
			if broken:
				check(world.ground.broken_bridges.is_empty(), "六座桥均已维修")
				if failures == 0:
					check(BattleSaves.save_slot(world, "slot2").ok, "写盘维修后的战场")
		tree.quit(int(failures > 0))
		return
	if "--cold-briefing" in args:
		var index := int(args[args.find("--cold-briefing") + 1])
		var expected: String = ["A02_F00E", "A02_P01E", "A02_P02E"][index - 1]
		var result := BattleSaves.load_into_scene("slot%d" % index)
		check(result.ok, "从磁盘读取开场断点 %d" % index)
		if not result.ok:
			tree.quit(failures)
			return
		await tree.scene_changed
		var restored = tree.current_scene.battle
		var state: Dictionary = restored.allied_state.hollywood
		check(restored.paused and state.briefing and not restored.has_node("HollywoodFilm"), "冷读档保持暂停和简报阶段")
		restored.hud._toggle_pause()
		restored.Hollywood.tick(restored, 0.1)
		var resumed = restored.get_node_or_null("HollywoodFilm")
		check(resumed != null and resumed.clip_id == expected and resumed.player.is_playing(), "继续后回到保存时的影片 " + expected)
		if resumed != null:
			resumed.skip.pressed.emit()
			await tree.process_frame
		check(not state.has("resume_briefing_clip") and not restored.has_node("HollywoodFilm"), "跳过后清除待播放状态")
		if index == 3:
			restored.Hollywood.tick(restored, 20.0)
			restored.Hollywood.tick(restored, 20.0)
			check(not state.briefing and restored.units.filter(func(u):return restored.actor_alive(u) and u.side == "ally" and u.unit_id == "AMCV").size() == 1, "回收厂简报结束后只交付一次基地车")
		tree.quit(failures)
		return
	var lobby = load("res://scenes/campaign_command.tscn").instantiate()
	tree.root.add_child(lobby)
	for btn in lobby.find_children("*","Button",true,false):
		if btn.text=="盟军战役": btn.pressed.emit(); break
	check(lobby.mission.get("id")=="yr_hollywood" and not lobby.carry,"盟军任务默认原版配置")
	for btn in lobby.find_children("*","Button",true,false):
		if btn.text=="带入我的养成" and "--growth" in OS.get_cmdline_user_args(): btn.pressed.emit()
		if btn.text=="出击": btn.pressed.emit(); break
	await tree.scene_changed
	var world = tree.current_scene.battle
	var ore_tiles := tree.get_nodes_in_group("resource_nodes")
	check(not ore_tiles.is_empty() and ore_tiles.all(func(tile): return tile.native_variant >= 0 and tile._ore_texture.resource_path.ends_with("_ubn.png")), "洛杉矶矿区使用原图矿石变体和城市图集")
	check(world.mission.id == "yr_hollywood" and world.enemy_faction == "yuri", "原战役编号进入尤里战场")
	var film = world.get_node("HollywoodFilm")
	check(tree.paused and film.player.is_playing() and film.subtitle.text.contains("指挥官"),"全屏原版简报正在播放")
	if "--write-briefing" in args: check(BattleSaves.save_slot(world, "slot1").ok, "写盘全屏简报断点")
	film.skip.pressed.emit()
	check(world.hud.field_radio.is_visible_in_tree() and world.hud.field_radio.body.text.contains("伞兵增援"),"开场机场通讯介绍工程师和伞兵增援")
	await tree.process_frame
	check(not tree.paused,"跳过影片后战场恢复")
	if "--write-broken-bridge" in args:
		var native := NativeMaps.data("yr_all02umd")
		for center in BRIDGE_CENTERS:
			BridgeDamage.damage_section(world, native.bridge_section_by_cell[center], BridgeDamage.strength())
		check(world.ground.broken_bridges.size() == BRIDGE_CENTERS.size(), "逐桥损毁六个断面")
		check(BattleSaves.save_slot(world, "slot1").ok, "写盘损毁后的战场")
		tree.quit(int(failures > 0))
		return
	if "--production-lock" in OS.get_cmdline_user_args():
		check(BattleRequest.extensions_enabled() == ("--growth" in OS.get_cmdline_user_args()), "实际规则模式与出击选择一致")
		var home: Vector2 = world.player_start()
		var barracks = world._place_building("GAPILE", "ally", home, true)
		var offset := Vector2(180, 180)
		for id in ["GACNST", "GAPOWR", "GAWEAP", "GATECH", "GAAIRC"]:
			world._place_building(id, "ally", home + offset, true)
			offset.x += 220
		var hud = world.hud
		check(not hud._unit_catalog().has("TANY") and not barracks.buildable.has("TANY"), "谭雅从指令甲板和兵营目录移除")
		hud.select_prod_tab("infantry")
		check(hud._prod_buttons.has("E1") and not hud._prod_buttons.has("TANY"), "步兵页实际显示美国大兵并隐藏谭雅")
		check(not barracks.enqueue("TANY") and barracks.enqueue("E1"), "兵营拒绝谭雅并接受美国大兵")
		check(not hud._unit_catalog().has("ROBO") and not hud._unit_catalog().has("CARRIER"), "隐藏依赖封锁建筑的机器人坦克和航母")
		var guide = preload("res://scripts/ui/unlock_guidance.gd").new(world).describe("ROBO")
		check(guide.get("steps", []).is_empty() and not str(guide.get("restriction", "")).is_empty(), "机器人坦克指引说明关卡封锁")
		for id in ["GAROBO", "GAYARD", "YAYARD", "GAWEAT"]:
			world.request_structure(id)
			world.set_build_mode(id)
			check(world.struct_queue.is_empty() and world.armed_build != id, id + " 禁止下单和选址")
		check(not GameData.unit_production_block_reason("PCV").is_empty(), "禁止生产尤里基地车")
		world.request_structure("GTGCAN")
		check(world.struct_queue.size() == 1 and world.struct_queue[0].id == "GTGCAN", "具备雷达与建造厂的美国可下单巨炮")
		var job := {"id":"GAWEAT", "cost":100.0, "time":10.0, "elapsed":0.0, "paid":0.0}
		world._tick_structure_jobs(1.0, [job], world.struct_ready, "ally")
		check(job.elapsed == 0.0 and job.paid == 0.0, "已有封锁建筑订单不推进也不扣款")
		world.struct_ready["GAWEAT"] = 1
		check(world.deliver_ready_structure("GAWEAT", "ally", home) == null and world.struct_ready.get("GAWEAT") == 1, "已就绪的封锁建筑不能交付，保留原订单")
		barracks.buildable.append("TANY")
		var codec = preload("res://scripts/save/battle_snapshot.gd").new()
		var snapshot: Dictionary = codec.capture(world)
		check(BattleSaves.validate(snapshot).is_empty(), "带生产目录和待放置建筑的战役快照有效")
		codec.restore(world, snapshot)
		barracks = world.buildings.filter(func(b): return b.building_id == "GAPILE" and b.side == "ally")[0]
		check(not barracks.buildable.has("TANY") and barracks.production.has("E1") and not barracks.enqueue("TANY"), "读档重新应用科技封锁并保留合法训练订单")
		check(world.deliver_ready_structure("GAWEAT", "ally", home) == null and world.struct_ready.get("GAWEAT") == 1, "读档后天气控制器仍不可放置")
		world._place_building("GAROBO", "ally", home + Vector2(100, 500), true)
		check(hud._unit_catalog().has("ROBO") and not hud._unit_catalog().has("TANY"), "已有控制中心可满足坦克前置，直接封锁仍有效")
		BattleRequest.configure_skirmish(MatchRules.RA2, {})
		check(GameData.unit_production_block_reason("TANY").is_empty() and GameData.building_production_block_reason("GAWEAT").is_empty(), "从本关切换遭遇战后不沿用封锁")
		BattleRequest.configure_mission("m01", {})
		check(GameData.unit_production_block_reason("TANY").is_empty() and GameData.building_production_block_reason("GAWEAT").is_empty(), "离开好莱坞后恢复普通科技")
		tree.quit(int(failures > 0))
		return
	if "--street-slope-picture" in OS.get_cmdline_user_args():
		var northwest := "--northwest" in OS.get_cmdline_user_args()
		var point := (Vector2(81.5,48.5) if northwest else Vector2(154.5,128.5))*55
		var picture := "/hollywood-northwest-slope.png" if northwest else "/hollywood-street-slope.png"
		if "--south-bank" in OS.get_cmdline_user_args():
			point = Vector2(57.5,147.5)*55
			picture = "/hollywood-south-bank.png"
		if "--hospital-cliff" in OS.get_cmdline_user_args():
			point = Vector2(75.5,48.5)*55
			picture = "/hollywood-hospital-cliff.png"
		world.spawn_unit("MTNK","ally",point)
		world.center_on(point)
		world.camera.force_update_scroll()
		world.fog.rebuild()
		tree.paused = true
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		check(get_viewport().get_texture().get_image().save_png(OS.get_environment("TEMP")+picture)==OK,"战场道路斜坡截图")
		tree.quit(int(failures>0))
		return
	if "--write-bridge-move-queue" in args:
		var deck = world.ground.overpass
		var goal := Vector2(55.5,139.5)*55
		var street := Vector2(58.5,145.5)*55
		var tank: Unit = world.spawn_unit("SREF","ally",street)
		tank.special.bridge_queue_fixture = true
		world.select_unit(tank,false)
		world._issue_order(goal + deck.RISE)
		world._issue_order(street, true)
		check(tank.has_move_order and tank.move_target.distance_to(goal)<1.0 and tank.order_queue.size()==1, "玩家发出上桥并排队下桥指令")
		check(BattleSaves.save_slot(world, "slot3").ok, "将移动中车辆及队列写入磁盘")
		tree.quit(int(failures>0))
		return
	if "--bridge-orders" in OS.get_cmdline_user_args():
		var deck = world.ground.overpass
		var goal := Vector2(55.5,139.5)*55
		var screen_point: Vector2 = goal+deck.RISE
		var prism = world.spawn_unit("SREF","ally",Vector2(58.5,145.5)*55)
		world.select_unit(prism,false)
		world._issue_order(screen_point)
		check(prism.move_target.distance_to(goal)<1.0 and prism._path_pts.size()>=4,"光棱坦克点高架路面获得桥面目标和桥头路线")
		for step in 1800:
			await tree.physics_frame
			if not prism.has_move_order: break
		check(prism.position.distance_to(goal)<12 and prism.special.has("hollywood_on_deck") and prism.z_index>deck.z_index,"光棱坦克自行开上南段桥面并停在点击处")
		var street := Vector2(58.5,145.5)*55
		world._issue_order(street)
		for step in 1800:
			await tree.physics_frame
			if not prism.has_move_order: break
		check(prism.position.distance_to(street)<12 and not prism.special.has("hollywood_on_deck"),"光棱坦克经桥头返回街道")
		var under = world.spawn_unit("SREF","ally",goal)
		world.select_unit(under,false)
		world._issue_order(screen_point)
		var left_origin := false
		var approach_point: Vector2 = under._path_pts[-4]
		var reached_approach := false
		var climb_samples := 0
		var greatest_rise := 0.0
		var last_height := 0.0
		for step in 2400:
			await tree.physics_frame
			var height := float(under.special.get("hollywood_deck_fraction",0.0))
			if not under.special.has("hollywood_on_deck") and under.position.distance_to(approach_point)<27.5: reached_approach = true
			if height>last_height and height<1.0: climb_samples += 1
			greatest_rise = maxf(greatest_rise,height-last_height)
			last_height = height
			if under.position.distance_to(goal)>110: left_origin = true
			if not under.has_move_order: break
		check(reached_approach and climb_samples>3 and greatest_rise<0.15,"车辆在地面驶到桥口外的转弯点，再沿坡连续抬升")
		check(left_origin and under.position.distance_to(goal)<12 and under.special.has("hollywood_on_deck"),"正下方点桥面也要绕到入口再返回上层")
		tree.quit(int(failures>0))
		return
	if "--bridge-tech" in OS.get_cmdline_user_args():
		var deck = world.ground.overpass
		check(deck.road.size()==297 and deck.ends.size()==22 and deck.textures.has("BRIDGE1:0"),"六段高架桥扣除边界外三格，十一处桥头各有两格入口")
		var native := preload("res://scripts/world/native_maps.gd").data("yr_all02umd")
		for spec in [[150,114,122],[145,114,122],[56,93,107],[51,93,107],[56,120,146],[51,120,144]]:
			var x := int(spec[0])
			var first := int(spec[1])
			var last := int(spec[2])
			var clipped := x==51 and first==120
			var banks: Vector2 = deck.spans[Vector2i(x,first)]
			check(deck.height_fraction(first,banks)==0 and deck.height_fraction(first+3,banks)==1 and deck.height_fraction(last+1,banks)==(1.0 if clipped else 0.0),"逐桥坡向和边界 %s" % str(spec))
			var center := Vector2i(x,(first+last)>>1)
			var part: Rect2 = native.bridge_section_by_cell[center]
			var damage = preload("res://scripts/world/bridge_damage.gd")
			damage.hit(world,(Vector2(center)+Vector2(-1.5,0.5))*55,damage.strength())
			var huts = world.buildings.filter(func(b): return b.building_id=="CABHUT" and b.special.get("bridge_span",Rect2()).encloses(part))
			check(huts.size()==(1 if clipped else 2),"原图维修小屋绑定对应桥段 %s" % str(spec))
			for lane in range(3):
				var cell := center+Vector2i.LEFT*lane
				check(deck.gaps.has(cell) and native.bridge_section_by_cell[cell]==part,"桥段断面覆盖车道 %s" % str(cell))
			if not huts.is_empty(): preload("res://scripts/world/civilian_sites.gd").repair(huts[0])
			check(deck.gaps.is_empty(),"桥面恢复 %s" % str(spec))
		var car = world.spawn_unit("MTNK","ally",Vector2(149.5,113.5)*55)
		world._update_depth_order()
		car.move_with_traffic_exceptions(Vector2.DOWN*55)
		world._update_depth_order()
		check(car._visual_lift()>0 and car._visual_lift()<30,"车辆从引道开始爬升")
		car.move_with_traffic_exceptions(Vector2.DOWN*3*55)
		world._update_depth_order()
		check(car._visual_lift()>30 and car.z_index>deck.z_index,"从桥头进入的坦克升到桥面")
		if "--deck-contact-picture" in OS.get_cmdline_user_args():
			world.select_unit(car,false)
			world.center_on(car.position)
			world.camera.force_update_scroll()
			world.fog.rebuild()
			car.queue_redraw()
			tree.paused = true
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			var rings := preload("res://scripts/world/attack_range_preview.gd").ranges(world)
			check(not rings.is_empty() and rings[0].center.is_equal_approx(car.position+car.bridge_contact_offset()),"桥面选中车辆的射程圈对准车身落点")
			check(get_viewport().get_texture().get_image().save_png(OS.get_environment("TEMP")+"/hollywood-deck-contact.png")==OK,"保存桥面车辆选中画面")
			tree.paused = false
		var bridge_y: float = car.position.y
		for attempt in 6: car.move_with_traffic_exceptions(Vector2.LEFT*55)
		check(car.special.has("hollywood_on_deck") and car.position.x>=148*55 and is_equal_approx(car.position.y,bridge_y),"桥面连续横移被护栏挡住并保持桥高")
		car.move_with_traffic_exceptions(Vector2.RIGHT*55)
		for step in 4: car.move_with_traffic_exceptions(Vector2.UP*55)
		check(not car.special.has("hollywood_on_deck") and car.position.y<114*55,"从原桥头驶离后回到地面")
		car.position=Vector2(147.5,118.5)*55
		world._update_depth_order()
		car.move_with_traffic_exceptions(Vector2.RIGHT*55)
		world._update_depth_order()
		check(car._visual_lift()<10 and car.z_index<deck.z_index,"横穿街道的坦克从桥下经过")
		var section = preload("res://scripts/world/bridge_damage.gd").section_at(world,Vector2(150.5,118.5)*55)
		if "--bridge-picture" in OS.get_cmdline_user_args():
			car.position = Vector2(150.5,117.0)*55
			world._update_depth_order()
			world.zoom_camera(2.0)
			world.hp_overlay.queue_redraw()
			world.center_on(car.position)
			world.camera.force_update_scroll()
			world.fog.rebuild()
			tree.paused = true
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(OS.get_environment("TEMP")+"/hollywood-bridge-field.png")
		world.ground.set_broken_bridges([section])
		check(deck.gaps.has(Vector2i(150,118)),"损坏的桥段从桥面图层移除")
		var edge := Vector2(149.5,117.5)*55
		for distance in [1,2]:
			car.position = edge
			car.special.hollywood_on_deck = true
			car.move_with_traffic_exceptions(Vector2.DOWN*55*distance)
			check(car.position.is_equal_approx(edge) and car.special.has("hollywood_on_deck"),"坦克停在断口前，移动步长 %s 格" % distance)
		world.ground.set_broken_bridges([])
		car.move_with_traffic_exceptions(Vector2.DOWN*55)
		check(car.position.y > 118*55 and car.special.has("hollywood_on_deck"),"桥面修复后坦克继续通行")
		for id in ["GAROBO","GAYARD","YAYARD","GAWEAT"]:
			world.set_build_mode(id)
			check(world.armed_build != id and not GameData.building_production_block_reason(id).is_empty(),id+" 禁止选址")
		for id in ["PCV","TANY"]: check(not GameData.unit_production_block_reason(id).is_empty(),id+" 禁止生产")
		check(world.country_block_reason("GTGCAN").is_empty() and GameData.production_prerequisites("GTGCAN")==["RADAR","GACNST"],"美国巨炮需要雷达和盟军建造场")
		tree.quit(int(failures>0))
		return
	if "--shop-repair" in OS.get_cmdline_user_args():
		var shop = world.buildings.filter(func(b):return b.building_id == "CAMACH")[0]
		var tank = world.spawn_unit("MTNK", "ally", world.player_start())
		var enemy = world.spawn_unit("HTNK", "enemy", world.player_start())
		var soldier = world.spawn_unit("E1", "ally", world.player_start())
		for actor in [tank, enemy, soldier]: actor.hp = 40.0
		shop._process(5.0)
		check(tank.hp == 40 and shop.side == "neutral", "中立维修厂不维修")
		var engineer = world.spawn_unit("ENGINEER", "ally", shop._spawn_point("ENGINEER"))
		world.center_on(shop.position)
		world.fog.rebuild()
		check(AlliedAbilities.use(engineer,"allied_engineer",shop), "工程师接受占领维修厂的命令")
		engineer.position = AlliedAbilities.approach(engineer,shop)
		AlliedAbilities.tick_action(engineer, 1.0/60)
		check(shop.side == "ally" and not world.actor_alive(engineer), "工程师到达后完成占领")
		shop._process(4.0)
		check(tank.hp == 40, "首个维修周期尚未到达")
		shop._process(1.0)
		check(tank.hp == 45 and tank.position.distance_to(shop.position)>500 and enemy.hp == 40 and soldier.hp == 40, "每五秒只修复远处己方机械载具五点生命")
		AlliedAbilities.change_side(shop, "enemy")
		enemy.hp = enemy.max_hp - 2
		shop._process(5.0)
		check(enemy.hp == enemy.max_hp and tank.hp == 45, "易手后只维修新主人的载具且不超出满血")
		shop._die()
		enemy.hp -= 10
		shop._process(5.0)
		check(enemy.hp == enemy.max_hp - 10, "维修厂被毁后停止维修")
		tree.quit(int(failures > 0))
		return
	if "--mine-route" in OS.get_cmdline_user_args():
		await preload("res://tests/hollywood_unit_states.gd").mine_route(self,world)
		tree.quit(failures)
		return
	if "--unit-states" in OS.get_cmdline_user_args():
		preload("res://tests/hollywood_unit_states.gd").run(self,world)
		tree.quit(failures)
		return
	if "--turret-render" in OS.get_cmdline_user_args():
		await preload("res://tests/hollywood_unit_states.gd").render_turrets(self,world)
		tree.quit(failures)
		return
	if "--dinosaur" in OS.get_cmdline_user_args():
		await preload("res://tests/hollywood_dinosaur.gd").run(self,world)
		tree.quit(int(failures > 0))
		return
	if "--resident-combat" in OS.get_cmdline_user_args():
		await resident_combat(world)
		tree.quit(int(failures > 0))
		return
	if "--capture-aid" in OS.get_cmdline_user_args():
		await capture_aid(world)
		tree.quit(int(failures > 0))
		return
	world.hud.log_btn.pressed.emit()
	var objectives:Label = world.hud.mission_objectives
	check(objectives.is_visible_in_tree() and objectives.text.contains("0/4") and objectives.text.contains("两处基地"),"展开情报可见两步总目标")
	world.hud.log_btn.pressed.emit()
	var s:Dictionary = world.allied_state.hollywood
	check(world.map_layout()=="yr_all02umd" and s.briefing,"洛杉矶原图与机场简报")
	var guards:Array = world.units.filter(func(u): return u.side == "enemy" and u.unit_id == "INIT")
	check(guards.any(func(u): return u.special.has("hollywood_patrol") and u.data.weapon.name == "PsychicJab" and not u._ra2.is_empty() and u._seq.has("FireUp")),"尤里新兵携原版武器和开火动画巡逻")
	check(world.units.any(func(u): return u.unit_id == "LTNK" and u.embarked_in != null and u.embarked_in.building_id == "NATBNK" and u._effective_native_weapon().damage > u.data.weapon.damage),"狂风坦克进驻坦克碉堡并获得火力加成")
	var expected := {"YAGRND":4,"YAGGUN":32,"YABRCK":3,"YAPOWR":20,"YAWEAP":2,"YACNST":1,"NATBNK":9,"NAPSIS":1,"CAOILD":1}
	for id in expected:
		var sites:Array = world.buildings.filter(func(b): return b.side == "enemy" and b.building_id == id and not b._ra2.is_empty())
		check(sites.size() == expected[id], "%s 原图建筑及贴图 %d/%d" % [id,sites.size(),expected[id]])
	if "--cast-media" in OS.get_cmdline_user_args():
		for actor in world.units.filter(func(u):return u.unit_id in ["ARND","CLNT","STLN"]):
			for kind in ["select","move","attack"]:
				check(world._play_group_voice([actor],kind,0) and not Ra2Sfx.voice_id(actor.data,kind).begins_with("yr_full_gi"),actor.unit_id+" 专属应答 "+kind)
		var tank=world.units.filter(func(u):return u.unit_id=="YTNK")[0]
		check(Ra2Sfx.play_weapon(tank.data.weapon,tank.position),"盖特坦克当前武器射击声")
		for stage in range(1,4):
			check(Ra2Sfx.play("GattlingGunAttackLoop"+str(stage),tank.position),"盖特射击音频 "+str(stage))
		tree.quit(failures)
		return
	if "--captured-factory" in OS.get_cmdline_user_args():
		var factory = world.buildings.filter(func(b): return b.building_id == "YAWEAP")[0]
		factory.special.hollywood_wave = 0
		AlliedAbilities.change_side(factory, "ally")
		factory._process(GameData.ra2_buildup_seconds()+0.1)
		world.credit_side("ally", 10000)
		world.select_building(factory)
		world.hud.prod_tab = "vehicle"
		world.hud._refresh_production()
		var cards: Array = world.hud._prod_buttons.keys()
		check(cards.has("LTNK") and cards.has("YTNK") and cards.find("LTNK") < cards.find("YTNK") and cards.find("YTNK") < cards.size() - 1, "占领后狂风、盖特进入基础战车区")
		check(not world.hud._unit_catalog().any(func(id: String): return id.begins_with("R3") or id == "YURIKO"), "战役生产栏隐藏红警3单位")
		if "--factory-picture" in OS.get_cmdline_user_args():
			for uid in ["LTNK", "YTNK"]:
				await get_tree().process_frame
				var card: Button = world.hud._prod_buttons[uid]
				world.hud._prod_scroll.ensure_control_visible(card)
				await RenderingServer.frame_post_draw
				var viewport := get_viewport()
				var bounds := Rect2i(viewport.get_final_transform() * card.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, card.size))
				var picture := viewport.get_texture().get_image().get_region(bounds)
				check(picture.save_png(OS.get_environment("IRON_OUT") + "/" + uid + ".png") == OK, "保存生产卡 " + uid)
		check_captured_product(world, factory, "YTNK", "YTNKICON", 600)
		check_captured_product(world, factory, "LTNK", "LTNKICON", 700)
		AlliedAbilities.change_side(factory, "enemy")
		check(not world.hud._unit_catalog().has("YTNK"), "失去工厂移除专属生产卡")
		var barracks = world.buildings.filter(func(b): return b.building_id == "YABRCK")[0]
		AlliedAbilities.change_side(barracks, "ally")
		barracks._process(GameData.ra2_buildup_seconds() + 0.1)
		world.select_building(barracks)
		world.hud.prod_tab = "infantry"
		world.hud._refresh_production()
		check_captured_product(world, barracks, "INIT", "INITICON", 200)
		world.hud._update_production_live()
		var clone_card: Button = world.hud._prod_buttons.get("YURI")
		check(is_instance_valid(clone_card) and clone_card.disabled and world.hud._prod_status_labels["YURI"].text.contains("心灵感应器"), "仅占领兵营时复制人卡片显示心灵感应器前置")
		var sensor = world.buildings.filter(func(b): return b.building_id == "NAPSIS")[0]
		var engineer = world.spawn_unit("ENGINEER", "ally", sensor.position + Vector2(110, 0))
		engineer.position = AlliedAbilities.approach(engineer, sensor)
		world.fog.rebuild()
		check(engineer.order_interaction("allied_engineer", sensor, false), "工程师接受心灵感应器占领命令")
		AlliedAbilities.tick_action(engineer, 1.0)
		check(sensor.side == "ally" and not world.actor_alive(engineer), "工程师进门并接管心灵感应器")
		check_captured_product(world, barracks, "YURI", "YCLNICON", 800)
		check_captured_product(world, barracks, "YENGINEER", "ENGNICON", 500)
		tree.quit(failures)
		return
	if "--base-orders" in OS.get_cmdline_user_args():
		for b in world.buildings:
			if b._buildup_play>=0: b._process(GameData.ra2_buildup_seconds()+0.1)
		world.credit_side("enemy",5000)
		var bases = preload("res://scripts/world/hollywood_bases.gd")
		bases.tick(world,s,91)
		for factory in world.buildings.filter(func(b):return b.building_id=="YAWEAP"):
			check(factory.production.has("YTNK"),str(factory.special.hollywood_house)+" 盖特坦克排产 "+factory.queue_block_reason("YTNK"))
			factory._tick_unit_queue(300,"YTNK")
			check(factory.production.is_empty() and factory._exit_anim_left>0,"战车出厂并触发开门")
			check(world.units.any(func(u):return u.unit_id=="YTNK" and u.special.get("hollywood_house")==factory.special.hollywood_house and u.order_queue.size()>0),"按本基地编队路线出击")
		var sensor=world.buildings.filter(func(b):return b.building_id=="NAPSIS")[0]
		var visitor=world.spawn_unit("E1","ally",sensor.position+Vector2(500,0))
		visitor.order_move(sensor.position+Vector2(30,0))
		bases.sense(world,sensor)
		check(not sensor.special.get("psychic_orders",[]).is_empty(),"心灵感应器探测范围内的敌军目的地")
		tree.quit(failures)
		return
	if "--building-animation-audit" in OS.get_cmdline_user_args():
		var reactor = world.buildings.filter(func(b): return b.building_id == "YAPOWR")[0]
		check(reactor._ra2.tex.resource_path.ends_with("/newurban/YAPOWR.png"), "好莱坞战场实例加载非雪地反应炉")
		if "--theater-picture" in OS.get_cmdline_user_args():
			reactor._process(GameData.ra2_buildup_seconds()+0.1)
			check(reactor._buildup_play < 0.0 and not reactor.under_construction, "实景取已建成的反应炉")
			world.fog._reveal("ally", reactor.position, world.Hollywood.BRIEFING_SIGHT, 10.0)
			world.fog.rebuild()
			world.zoom_camera(1.55)
			world.center_on(reactor.position)
			world.camera.force_update_scroll()
			tree.paused = true
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			var viewport := get_viewport()
			var point: Vector2 = viewport.get_final_transform() * reactor.get_global_transform_with_canvas().origin
			var image := viewport.get_texture().get_image()
			var crop := Rect2i(point - Vector2(240,300),Vector2i(480,410)).intersection(Rect2i(Vector2i.ZERO,image.get_size()))
			check(image.get_region(crop).save_png(OS.get_environment("IRON_OUT") + "/reactor-newurban.png") == OK, "保存本关反应炉实景")
			tree.paused = false
		for id in expected:
			var building = world.buildings.filter(func(b): return b.side == "enemy" and b.building_id == id)[0]
			var health_before:float = building.hp
			for fraction in [1.0, 0.4]:
				building.hp = building.max_hp * fraction
				var layers := []
				for layer in building._ra2_anim:
					var pose:Dictionary = building._anim_layer(layer)
					layers.append("%s=%s[%d..%d]/%d visible=%s" % [layer.kind, pose.image, pose.loopStart, pose.loopEnd, pose.frames, building._layer_visible(layer.kind)])
					if id != "CAOILD": check(pose.loopStart>=0 and pose.loopEnd<pose.frames and RA2Art.has_art(pose.image),"%s 工作层 %s 的贴图与前景帧" % [id,layer.kind])
				print("SITE_ANIM ", id, " hp=", fraction, " body=", building._body_damage_frame(), " make=", not building._buildup_art.is_empty(), " ", layers)
			building.hp = health_before
			if id != "CAOILD": check(building._buildup_art.get("tex")!=null and building._buildup_art.count>1,"建造序列 "+id)
			if id=="YACNST":
				building.play_production_animation()
				check(building._layer_visible("productionanim") and not building._layer_visible("idleanim"),"建造场生产替换待机层")
			if id=="YAGRND":
				building.play_special()
				check(building._layer_visible("specialanim"),"回收厂工作")
				building._tick_anim_state(30)
				check(building._layer_visible("idleanimtwo") and not building._layer_visible("specialanim"),"回收厂恢复待机")
			if id=="NATBNK":
				building._tick_anim_state(5)
				check(building._bunker_fraction==1 and building._layer_visible("specialanimtwo"),"驻车展开")
				building.special.occupants=[]
				building._tick_anim_state(0.1)
				check(building._layer_visible("specialanimfour") and building._bunker_fraction<1,"撤车收起")
		for theater in ["SNOW", "NEWURBAN"]:
			RA2Art.set_building_theater(theater)
			for id in ["YAPOWR", "YAPOWRMK", "YAPOWR_A", "YAPOWR_B", "YAPOWR_C"]:
				check(RA2Art.art(id).tex.resource_path.ends_with("/%s/%s.png" % [theater.to_lower(), id]), theater+" 反应炉分层取图 "+id)
			var light: Dictionary = RA2Art.building_anims("YACNST")[0]
			check(light.frames == (2 if theater=="SNOW" else 4), theater+" 建造场动画使用该剧场的阴影起始帧")
		tree.quit(int(failures > 0))
		return
	world.Hollywood.tick(world,0.1)
	var airport_report = world.get_node("HollywoodFilm")
	check(airport_report.clip_id=="A02_P01E" and airport_report.subtitle.text.contains("机场"),"机场短片同步显示中文字幕")
	if "--write-briefing" in args: check(BattleSaves.save_slot(world, "slot2").ok, "写盘机场简报断点")
	var sight_test := "--briefing-sight" in OS.get_cmdline_user_args()
	var airport:Vector2 = world.Hollywood.cell(116,180)
	if sight_test:
		world.fog.sight_clock += 30.0
		world.fog.rebuild()
		check(world.position_visible_to("ally",airport),"机场通讯持续期间保留机场视野")
	airport_report.skip.pressed.emit()
	await tree.process_frame
	world.Hollywood.tick(world,8)
	check(s.shot==1 and world.units.any(func(u):return u.special.has("hollywood_civilian")),"厂门前有行进中的居民")
	check(world.buildings.filter(func(b):return b.special.has("hollywood_plant") and b.special.get("campaign_flash_left",0)>0).size()==4,"简报指向回收厂时触发建筑闪烁")
	var report = world.get_node("HollywoodFilm")
	check(report.clip_id=="A02_P02E" and report.player.is_playing() and report.subtitle.text.contains("敌人"),"回收厂通讯播放")
	if "--write-briefing" in args: check(BattleSaves.save_slot(world, "slot3").ok, "写盘回收厂简报断点")
	await tree.process_frame
	var radar_rect:Rect2=world.hud.minimap.get_global_transform_with_canvas()*Rect2(Vector2.ZERO,world.hud.minimap.size)
	check(report.dock.get_global_rect().is_equal_approx(radar_rect) and radar_rect.encloses(report.skip.get_global_rect()),"通讯与跳过按钮位于右上雷达框内")
	if sight_test:
		var plant = world.buildings.filter(func(b):return b.special.get("hollywood_plant")=="0")[0]
		world.fog.sight_clock += 30.0
		world.fog.rebuild()
		check(plant.visible and world.position_visible_to("ally",plant.position),"模拟时间越过旧期限后回收厂仍可见")
		check(not world.position_visible_to("ally",s.plants["2"]),"简报没有揭开远处回收厂")
		var sampled := false
		var visible_through_line := true
		while is_instance_valid(report) and report.player.is_playing():
			if report.subtitle.text.contains("为战争筹款"):
				if not sampled:
					check(world.units.any(func(u):return world.actor_alive(u) and u.special.get("hollywood_civilian")=="0" and u.visible),"最后一句台词期间能看见首厂前的居民")
				sampled = true
				visible_through_line = visible_through_line and plant.visible and s.briefing and world.position_visible_to("ally",plant.position)
			if sampled and "--skip-report" in OS.get_cmdline_user_args():
				report.skip.pressed.emit()
				break
			await tree.process_frame
		check(sampled and visible_through_line,"伊娃说到为战争筹款时厂房持续可见")
	elif "--all-houses" in OS.get_cmdline_user_args() or "--city-house" in OS.get_cmdline_user_args() or "--shop-capture" in OS.get_cmdline_user_args(): report.skip.pressed.emit()
	else: await report.player.finished
	await tree.process_frame
	world.Hollywood.tick(world,8)
	check(not s.briefing and world.units.any(func(u):return u.unit_id=="AMCV"),"机场基地车抵达并交还控制")
	if sight_test:
		check(world.fog.is_explored_at("ally",s.plants["0"]) and not world.position_visible_to("ally",s.plants["0"]),"交还控制后首厂只留探索记录")
		tree.quit(int(failures > 0))
		return
	if "--shop-capture" in OS.get_cmdline_user_args():
		var shop = world.buildings.filter(func(b): return b.building_id == "CAMACH")[0]
		var start:Vector2 = world.path_service.nearest_reachable(shop.position + Vector2(80, 290), shop._spawn_point("ENGINEER"))
		var engineer = world.spawn_unit("ENGINEER", "ally", start)
		# Keep the capture fixture alive through nearby patrol fire.
		engineer.max_hp = 1000000.0
		engineer.hp = engineer.max_hp
		var scout = world.spawn_unit("E1", "ally", shop._spawn_point("E1"))
		world.center_on(shop.position)
		world.fog.rebuild()
		world.select_unit(engineer, false)
		check(world.actor_visible_to("ally", shop), "厂房在己方侦察视野内")
		check(shop.side == "neutral" and start.distance_to(shop.position) > 200, "工程师从厂外街道接近中立机械维修厂")
		if "--shop-pictures" in OS.get_cmdline_user_args():
			world.zoom_camera(1.4)
			await facility_picture(world,shop,"neutral")
		var click:Vector2 = shop.art_center()
		check(world.support_order_target(click) == shop, "右键厂房命中 CAMACH")
		check(AlliedAbilities.default_order(scout, shop).is_empty(), "普通步兵无法占领机械维修厂")
		shop.data.capturable = false
		check(AlliedAbilities.default_order(engineer, shop).is_empty(), "显式禁止占领的实例优先于原版规则")
		shop.data.erase("capturable")
		world._issue_order(click)
		var dispatched:bool = engineer.special.get("action", "") == "allied_engineer" and engineer.special.get("target") == shop
		check(dispatched, "右键下达工程师占领命令")
		if dispatched:
			for step in 600:
				await tree.physics_frame
				if shop.side == "ally": break
		check(shop.side == "ally" and shop.is_in_group("ally_buildings"), "厂房实际转为玩家建筑")
		check(shop.material != null and shop.material.get_shader_parameter("paint_mode") == HouseColor.PaintMode.SHOP_FACADE, "机械维修厂使用占领方外墙涂装")
		if DisplayServer.get_name() != "headless":
			var viewport := SubViewport.new()
			var sprite := Sprite2D.new()
			sprite.texture = shop._ra2.tex
			sprite.centered = false
			sprite.material = shop.material
			viewport.size = sprite.texture.get_size()
			viewport.add_child(sprite)
			add_child(viewport)
			viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
			await RenderingServer.frame_post_draw
			var source := sprite.texture.get_image()
			var rendered := viewport.get_texture().get_image()
			var painted := 0
			var wrong := 0
			for y in source.get_height():
				for x in source.get_width():
					var pixel := source.get_pixel(x, y)
					if pixel.a8 != 255 or pixel.r8 == 0 or pixel.g8 != 0 or pixel.b8 != 0: continue
					painted += 1
					var expected_paint := HouseColor.player_color() * (pixel.r8 / 252.0)
					var actual := rendered.get_pixel(x, y)
					if abs(actual.r8-expected_paint.r8) + abs(actual.g8-expected_paint.g8) + abs(actual.b8-expected_paint.b8) > 4: wrong += 1
			check(painted > 0 and wrong == 0, "实际渲染 %d 个涂装像素，%d 个色值不符" % [painted, wrong])
			viewport.queue_free()
		if "--shop-pictures" in OS.get_cmdline_user_args():
			await facility_picture(world,shop,"ally")
		check(not world.actor_alive(engineer), "占领成功消耗工程师")
		var codec = preload("res://scripts/save/battle_snapshot.gd").new()
		var saved:Dictionary = codec.capture(world)
		check(BattleSaves.validate(saved).is_empty(), "占领后的快照有效")
		codec.restore(world, saved)
		var restored = world.buildings.filter(func(b): return b.building_id == "CAMACH")[0]
		check(restored.side == "ally" and restored.is_in_group("ally_buildings"), "恢复快照后机械维修厂仍归玩家")
		tree.quit(int(failures > 0))
		return
	var reactor = world.buildings.filter(func(b): return b.building_id == "YAPOWR")[0]
	var purple := Color.from_hsv(201.0/255,201.0/255,189.0/255)
	check(reactor._col.is_equal_approx(purple) and guards[0]._col.is_equal_approx(purple) and HpBar.faction_color("enemy").is_equal_approx(purple),"尤里建筑、守军与血条使用原图紫色")
	var poses_ok := true
	var previous_hp:float = reactor.hp
	for damaged in [false,true]:
		reactor.hp = reactor.max_hp * (0.4 if damaged else 1.0)
		for layer in reactor._ra2_anim:
			var state:Dictionary = reactor._anim_layer(layer)
			var half := int(state.frames) / 2
			poses_ok = poses_ok and state.loopStart == (half if damaged else 0) and state.loopEnd == (2*half-1 if damaged else half-1)
	reactor.hp = previous_hp
	check(poses_ok and reactor._ra2_anim.back().kind == "idleanim" and reactor._layer_visible("activeanim") and not reactor._layer_visible("activeanimtwo"),"生物反应炉分别循环完好和受损帧，灯光覆盖单层炉体")
	if "--native-fields" in OS.get_cmdline_user_args():
		var inventory:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://docs/memory/HOLLYWOOD_NATIVE_FIELD_INVENTORY.json"))
		var audit := {}
		for id in inventory:
			var row:Dictionary=inventory[id]
			var definition:Dictionary=GameData.get_building(id) if "Structures" in row.origins else GameData.get_unit(id)
			var actual:Array=world.buildings.filter(func(b):return b.building_id==id) if "Structures" in row.origins else world.units.filter(func(u):return u.unit_id==id)
			if not actual.is_empty(): definition=actual[0].data
			var differences := {}
			for pair in [["strength","hp"],["armor","ra2_armor"],["cost","cost"],["power","power"],["extrapower","extra_power"],["maxnumberoccupants","garrison_slots"]]:
				if not row.rules.has(pair[0]):continue
				var value=str(row.rules[pair[0]])
				var v=definition.get(pair[1])
				if v==null or (float(value)!=float(v) if value.is_valid_float() else value!=str(v)): differences[pair[0]]=[value,v]
			audit[id]={"instances_at_start":actual.size(),"definition":not definition.is_empty(),"field_differences":differences,"runtime_weapon":definition.get("weapon",{}).get("name",""),"original_primary":row.rules.get("primary",row.rules.get("weapon1",""))}
		var audit_file:=FileAccess.open("res://docs/memory/HOLLYWOOD_RUNTIME_FIELD_AUDIT.json",FileAccess.WRITE)
		audit_file.store_string(JSON.stringify(audit," ")+"\n")
		audit_file.close()
		var ops=preload("res://scripts/units/civilian_orders.gd")
		var engineer=world.spawn_unit("ENGINEER","ally",reactor._spawn_point("ENGINEER"))
		world.fog.rebuild();world.select_unit(engineer,false);world._issue_order(reactor.position)
		for step in 300:
			await tree.physics_frame
			if reactor.side=="ally":break
		check(reactor.side=="ally","工程师实际接管反应炉")
		var first=world.spawn_unit("E1","ally",reactor._spawn_point("E1"))
		world.select_unit(first,false);world._issue_order(reactor.position)
		for step in 300:
			await tree.physics_frame
			if first.embarked_in==reactor:break
		check(first.embarked_in==reactor and reactor.installed_power()==400,"右键装人，反应炉供电增加100")
		for i in 4:
			var passenger=world.spawn_unit("E1","ally",reactor._spawn_point("E1"));ops.enter(passenger,reactor)
		world._update_power()
		var sixth=world.spawn_unit("E1","ally",reactor._spawn_point("E1"))
		check(reactor.installed_power()==800 and world.power_produced>=800 and not ops.can_enter(sixth,reactor) and reactor._layer_visible("activeanimtwo"),"满炉800电力与强化动画")
		var before:float=world.power_produced
		ops.withdraw(reactor,first);world._update_power()
		check(first.embarked_in==null and is_equal_approx(before-world.power_produced,100),"撤出一人后电网扣回100")
		var init:Dictionary=GameData.get_unit("INIT").weapon
		var attacker=world.spawn_unit("INIT","enemy",sixth.position + Vector2.RIGHT*95)
		sixth.set_fire_stance("none");world.fog.rebuild()
		var flame := false
		var fx_host=Effects._host()
		var watch=func(n):
			if n is Ra2Fx and n.anim.get("tex") != null and n.anim.tex.resource_path.ends_with("/INITFIRE.png"): n.set_meta("native_fire_seen",true)
		fx_host.child_entered_tree.connect(watch)
		for i in 240:
			await tree.physics_frame
			if fx_host.get_children().any(func(n):return n.has_meta("native_fire_seen")):
				flame=true;break
		fx_host.child_entered_tree.disconnect(watch)
		check(flame,"实际战场射击产生 INITFIRE")
		check(GameData.ra2_impact_anims(init.ra2_warhead)==["INITFIRE"] and Ra2Fx.play_impact(world.effects_root,init.ra2_warhead,25,reactor.position),"新兵心灵火焰原版命中特效播放")
		var guns:Array=GameData.get_building("YAGGUN").guns.duplicate()
		guns.append(GameData.get_unit("LTNK").weapon)
		for gun in guns:
			var muzzle:Array=GameData.ra2_muzzle_anims(gun.ra2_weapon_id)
			check(not muzzle.is_empty() and Ra2Fx.play(world.effects_root,reactor.position,muzzle[0]) and Ra2Fx.play_impact(world.effects_root,gun.ra2_warhead,gun.damage,reactor.position),gun.name+" 炮口和命中特效播放")
		tree.quit(failures);return
	if "--reactor-view" in OS.get_cmdline_user_args():
		world.fog._reveal("ally", reactor.position, world.Hollywood.BRIEFING_SIGHT, 10.0)
		world.fog.rebuild()
		world.center_on(reactor.position)
		for i in 4: await tree.process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(OS.get_environment("TEMP")+"/it-hollywood-reactor-view.png")
		reactor.hp = reactor.max_hp * 0.4
		reactor.queue_redraw()
		await tree.process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(OS.get_environment("TEMP")+"/it-hollywood-reactor-damaged.png")
		tree.quit(failures)
		return
	var studio:Array=world.units.filter(func(u): return u.special.get("hollywood_studio_patrol",false))
	check(studio.size()==2 and studio.all(func(u): return u.side=="enemy" and u.unit_id=="LTNK" and u.patrolling and u.attack_move and u.patrol_points[0].distance_to(u.move_target)>500),"片场两辆狂风坦克沿原图路线攻击移动")
	check(guards.any(func(u): return u.patrolling and u.attack_move),"守厂步兵执行往返警戒")
	if "--patrol" in OS.get_cmdline_user_args() and studio.size()==2:
		var lead=studio[0]
		var start:Vector2=lead.position
		for step in 240:
			await tree.physics_frame
			if lead.position.distance_to(start)>80: break
		check(lead.position.distance_to(start)>80,"片场巡逻实际推进")
		var scout=world.spawn_unit("MTNK","ally",lead.position+Vector2(110,0))
		scout.set_fire_stance("none")
		world.fog.rebuild()
		var engaged:=false
		for step in 360:
			await tree.physics_frame
			if lead.attack_target==scout and lead._muzzle>0: engaged=true
			if engaged and (not world.actor_alive(scout) or scout.hp<scout.max_hp): break
		check(engaged and (not world.actor_alive(scout) or scout.hp<scout.max_hp),"巡逻坦克自动向路上盟军开火并命中")
		if world.actor_alive(scout): scout._die()
		var stopped:Vector2=lead.position
		for step in 300:
			await tree.physics_frame
			if lead.position.distance_to(stopped)>80: break
		check(lead.patrolling and lead.position.distance_to(stopped)>80,"交战结束后恢复巡逻")
		tree.quit(failures)
		return
	if "--all-houses" in OS.get_cmdline_user_args():
		tree.quit(await preload("res://tests/hollywood_city_house_audit.gd").run(world,tree))
		return
	if "--city-house" in OS.get_cmdline_user_args():
		var houses:Array=world.buildings.filter(func(b):return b.side=="neutral" and b.data.get("hollywood_art",false) and b.data.get("garrison_slots",0)>0)
		houses.sort_custom(func(a,b):return a.position.distance_squared_to(world.player_start())<b.position.distance_squared_to(world.player_start()))
		var house=houses[0]
		var soldier=world.units.filter(func(u):return u.unit_id=="E1" and u.side=="ally")[0]
		soldier.position=house._spawn_point("E1")
		world.center_on(house.position)
		world.fog.rebuild()
		world.select_unit(soldier,false)
		await tree.process_frame
		world._issue_order(house.art_center())
		check(soldier.special.get("action")=="allied_garrison","右键城市建筑下达进驻命令 "+house.building_id)
		for i in 450:
			await tree.physics_frame
			if soldier.embarked_in==house:break
		check(house.side=="ally" and soldier.embarked_in==house,"步兵实际进入城市建筑")
		await RenderingServer.frame_post_draw
		check(house._art_frame==2,"驻军后实际绘制加固楼体")
		preload("res://scripts/units/civilian_orders.gd").withdraw(house,soldier)
		check(house.side=="neutral" and soldier.embarked_in==null,"驻军撤出后民房恢复中立")
		await RenderingServer.frame_post_draw
		check(house._art_frame==0,"撤空后实际绘制普通楼体")
		tree.quit(failures)
		return
	var codec = preload("res://scripts/save/battle_snapshot.gd").new()
	var snap:Dictionary=codec.capture(world)
	var issue:String=BattleSaves.validate(snap)
	check(issue.is_empty(),"洛杉矶战场快照校验 "+issue)
	if "--walk" in OS.get_cmdline_user_args():
		var line:Array=world.units.filter(func(u):return u.special.get("hollywood_civilian")=="0")
		check(line.size()==4,"第一座回收厂前有四名居民排队")
		if line.size()!=4: tree.quit(failures);return
		var first_left := false
		for i in 1800:
			await tree.physics_frame
			if not world.actor_alive(line[0]):
				first_left = true
				break
		check(first_left and world.actor_alive(line[1]),"队首进厂时第二人仍在等待")
		for i in 1800:
			await tree.physics_frame
			if not world.actor_alive(line[1]): break
		check(not world.actor_alive(line[1]) and world.actor_alive(line[2]),"第二人补位进厂，第三人仍在队列")
		tree.quit(failures)
		return
	var targets:Array=world.buildings.filter(func(b):return b.special.has("hollywood_plant"))
	check(targets.size()==4 and world.hud.minimap.campaign_radar_offline() and world.hud.minimap.objective_marks().is_empty(),"开局无雷达报点")
	var distant=targets[2]
	check(not world.fog.is_explored_at("ally",distant.position) and not distant.visible,"未侦察的回收厂被战争迷雾遮蔽")
	check(world.fog.is_explored_at("ally",targets[0].position),"简报留下第一座回收厂的位置")
	var local_marks: Array = world.CampaignMarks.marks(world, false)
	check(local_marks.any(func(mark): return mark.actor == targets[0]) and not local_marks.any(func(mark): return mark.actor == distant), "雷达离线时战场只标已侦察回收厂")
	var home:Vector2=world.player_start()
	world._place_building("GAPOWR","ally",home+Vector2(300,300),true)
	world._place_building("GAPOWR","ally",home+Vector2(300,550),true)
	var radar=world._place_building("GAAIRC","ally",home+Vector2(520,300),true)
	radar._buildup_play=-1.0
	world._update_power()
	world.Hollywood.update_radar(world,s)
	check(world.hud.minimap.objective_marks().size()==4 and world.CampaignMarks.marks(world, false).size() == 4 and not world.actor_visible_to("ally",distant),"恢复供电后两处报告四厂位置，不开视野")
	world.hud.minimap._pings.clear()
	s.radar_ping_left=0.2
	world.Hollywood.tick(world,1.0)
	check(world.hud.minimap._pings.filter(func(pg):return pg.kind=="campaign_site").size()==4,"真实任务更新推进第二轮四厂闪圈")
	radar._die()
	world.Hollywood.update_radar(world,s)
	check(world.hud.minimap.campaign_radar_offline(),"雷达被毁后关闭")
	for clip in ["xa2ev01","xa2ev02","xa2ev04","xa2ev05","xa2ev06","xa2yu01","xa2ar01","xa2sl01"]:
		var sound=Ra2Sfx._stream_eva("hollywood/"+clip)
		check(sound!=null and sound.get_length()>1,"原声 "+clip)
	var scout=world.units.filter(func(u):return u.unit_id=="E1" and u.side=="ally")[0]
	for row in world.Hollywood.VISITS:
		if row[0]=="医院":
			scout.position=world.Hollywood.cell(144,133);world.Hollywood.tick(world,1)
		scout.position=world.Hollywood.cell(row[1],row[2]);world.Hollywood.tick(world,1)
	check(world.buildings.filter(func(b):return b.building_id in ["CATHOSP","CAMACH"] and b.special.get("campaign_flash_left",0)>0).size()>=2,"医院与机械维修厂发现闪烁")
	world._place_building("GATECH","ally",home+Vector2(620,650),true)
	world.Hollywood.tick(world,1.0)
	var forts:Array=world.units.filter(func(u):return u.unit_id=="BFRT" and u.side=="ally")
	check(forts.size()==1 and forts[0].logistics.passengers.filter(func(u):return u.unit_id=="GGI").size()==3 and forts[0].logistics.passengers.filter(func(u):return u.unit_id=="E1").size()==2,"战斗要塞实际搭载三名重装大兵和两名美国大兵")
	var previous_difficulty:int=BattleRequest.skirmish_config.get("difficulty",1)
	world._place_building("GAWEAP","ally",home+Vector2(1000,650),true)
	for level in 3:
		BattleRequest.skirmish_config.difficulty=level
		s.attack_left=0.0
		s.attack_index=0
		var before:int=world.units.filter(func(u):return u.unit_id=="LTNK").size()
		world.Hollywood.tick(world,1.0)
		var after:int=world.units.filter(func(u):return u.unit_id=="LTNK").size()
		check(after-before==(3 if level==0 else 4),"尤里首批增援数量，难度 %d"%level)
	BattleRequest.skirmish_config.difficulty=previous_difficulty
	var radio = world.hud.field_radio
	# Finish earlier discovery transmissions in the order the player would see them.
	var heard := PackedStringArray()
	while radio.visible and not radio.body.text.contains("战斗要塞") and not radio.waiting.is_empty():
		heard.append(radio.speaker.text + "：" + radio.body.text)
		radio._playback.custom_step(120.0)
	var captions := "\n".join(heard)
	for phrase in ["战俘营", "复制人", "签名", "恐龙电影", "阿诺：", "史泰龙：", "医疗物资", "维修厂"]:
		check(captions.contains(phrase), "实地通讯显示对白：" + phrase)
	check(radio.is_visible_in_tree() and radio.speaker.text=="伊娃" and radio.body.text.contains("碾碎") and radio.body.text.contains("射击孔"),"战斗要塞登场介绍显示在战场通讯框")
	radio._playback.custom_step(9.0)
	check(radio.visible and radio.modulate.a==1.0 and radio.body.text.contains("车内每名士兵"),"约九秒原声播完时介绍仍可读")
	check(s.get("cameo_left",0)>0 and world.hud.prod_tab=="vehicle","战斗要塞援军切换载具页并启动图标闪烁")
	check(not world.has_node("HollywoodFilm"),"片场发现保留人物通讯")
	check(s.visited.size()==6 and world.units.filter(func(u):return u.special.has("hollywood_star") and u.side=="ally").size()==3,"片场、医院、维修厂与三人入队")
	var clint = world.units.filter(func(u): return u.special.get("hollywood_star") == "克林特")[0]
	var infantry = world.spawn_unit("INIT", "enemy", clint.position + Vector2(65,0))
	infantry.set_fire_stance("none")
	world.fog.rebuild()
	var fired := false
	var initial_hp:float = infantry.hp
	for step in 240:
		await tree.physics_frame
		if clint._muzzle > 0: fired = true
		if fired and (not world.actor_alive(infantry) or infantry.hp < initial_hp): break
	check(fired and (not world.actor_alive(infantry) or infantry.hp < initial_hp), "克林特入队后自行开枪命中敌方步兵")
	var budget:float=world.funds
	for b in targets:
		var at:Vector2=b.position
		scout.position=at
		b._die();world.Hollywood.tick(world,1)
		world.Hollywood.tick(world,1)
		check(s.crates.has(at),"资金箱出现在部队脚下后仍可留在原地")
		scout.position=at+Vector2(110,0);world.Hollywood.tick(world,1)
		check(s.crates.has(at),"距离两格不触发拾取")
		var before_pickup:float=world.funds
		scout.position=at;world.Hollywood.tick(world,1)
		world.Hollywood.tick(world,1)
		check(not s.crates.has(at) and world.funds==before_pickup+500,"走进箱子所在格只领取一次 500 资金")
	world.hud.log_btn.pressed.emit()
	check(objectives.is_visible_in_tree() and objectives.text.contains("4/4") and objectives.text.contains("进行中"),"重新展开情报可见拆厂完成与清剿目标")
	var final_lines := PackedStringArray()
	while radio.visible:
		final_lines.append(radio.speaker.text + "：" + radio.body.text)
		radio._playback.custom_step(120.0)
	var ending := "\n".join(final_lines)
	for phrase in ["增援部队已抵达", "尤里：同志", "重装大兵：谢谢您救了我们", "给您拍部电影"]:
		check(ending.contains(phrase), "增援与回收厂事件通讯：" + phrase)
	check(world.funds>=budget+2000 and s.phase==2 and s.rescued>0,"拾取、救人和第二目标")
	var cleanup: Array = world.CampaignMarks.marks(world, false)
	check(not cleanup.is_empty() and cleanup.all(func(mark): return mark.title.begins_with("摧毁") and world.position_explored_by("ally", mark.position)), "清剿阶段只标记已侦察的目标建筑")
	if "--loss" in OS.get_cmdline_user_args():
		for b in world.buildings.duplicate():
			if world.actor_alive(b) and b.side == "ally": b._die()
		world.Hollywood.tick(world,1)
		check(not world.ended,"建筑全毁但野战部队仍能作战")
		for u in world.units.duplicate():
			if world.actor_alive(u) and u.side == "ally": u._die(null,true)
	else:
		for b in world.buildings.duplicate():
			if world.actor_alive(b) and b.side == "enemy": b._die()
	var previous_stars:Dictionary=MetaProgress.academy.get("hero_builds",{}).duplicate()
	var before_wallet:Dictionary=MetaProgress.currency.duplicate(true)
	var previous_win:bool=MetaProgress.stats.get("campaign_victories",{}).has(world.mission.id)
	var results := []
	Events.battle_ended.connect(func(result): results.append(result),CONNECT_ONE_SHOT)
	world.Hollywood.tick(world,1)
	if s.phase==3:
		check(world.units.any(func(u): return world.actor_alive(u) and u.special.has("cheer_elapsed") and u.HollywoodInfantry.pose(u)=="Cheer"),"结尾获救居民播放本体欢呼序列")
		world.Hollywood.tick(world,5)
	check(results.size()==1 and results[0].win == ("--loss" not in OS.get_cmdline_user_args()),"胜负结算")
	if not results.is_empty():
		var expected_stars:=[]
		if results[0].win:
			for star in world.units:
				if world.actor_alive(star) and star.side=="ally" and star.special.has("hollywood_star") and int(previous_stars.get(star.unit_id,0))==0:
					expected_stars.append(star.unit_id)
		check(results[0].rewards.get("recruits",[])==expected_stars,"战后隐藏招募名单与获救存活者一致")
		var expected_payout:Dictionary=preload("res://scripts/rules/campaign_payout.gd").amount(world.mission,previous_win) if results[0].win else {}
		for key in ["war_points","credits","diamonds"]:
			check(MetaProgress.balance(key)==before_wallet.get(key,0)+expected_payout.get(key,0),"实发钱包 "+key)
		var paid:Dictionary=MetaProgress.currency.duplicate(true)
		var receipt=results[0].duplicate(true)
		check(preload("res://scripts/rules/battle_rewards.gd").commit(world,receipt,false) and receipt.rewards.get("already_settled",false) and MetaProgress.currency==paid,"同一局重复结算幂等")
		check(BattleRequest.extensions_enabled()==("--growth" in OS.get_cmdline_user_args()) and snap.context.config.campaign_growth==BattleRequest.extensions_enabled(),"养成选择进入战斗快照")
	tree.quit(failures)
