extends Node
var errors := 0
func verify(ok:bool,label:String) -> void:
	print("YURI ",ok," ",label)
	if not ok: errors+=1

func _ready() -> void:
	await get_tree().process_frame
	var lobby=load("res://scenes/lobby.tscn").instantiate()
	add_child(lobby)
	for control in [lobby._country_opt,lobby._enemy_opt]:
		verify(range(control.item_count).any(func(i):return control.get_item_text(i)=="尤里"),"大厅可选尤里")
	lobby.queue_free()
	BattleRequest.configure_skirmish(MatchRules.RA2,{"country":"尤里","enemy_country":"尤里","map_layout":"coast","map_size":3200,"starting_funds":50000,"opening":"prebuilt","fog_of_war":false})
	var screen=load("res://scenes/battle.tscn").instantiate()
	add_child(screen)
	var w=screen.battle
	verify(w.roster_faction()=="yuri" and w.roster_faction("enemy")=="yuri","双方国家")
	verify("YACNST" in w.owned_building_ids("ally"),"建造厂")
	for b in w.buildings: b._process(10)
	for id in ["PCV", "YHVR", "BSUB", "CMISL"]:
		var art := RA2Art.art(id)
		verify(art.get("palette_lit", false) and art.get("detail_tex") != null and art.detail_scale == 2 and art.facings == 32, "原版体素高光 " + id)
	for id in ["YAYARD", "YAYARD_A", "YAYARD_C", "YAPPET", "YAPPET_A", "YAPPET_E", "YAGNTC", "YAGNTC_E", "GAFWLL", "YAPSYT", "YAPSYT_A", "YATECH", "YATECH_A", "NACLON", "NACLON_A", "CASLAB", "CASLAB_F", "SOV07_BEACON", "SOV07_NAPSYB_A"]:
		var detail: Dictionary = RA2Art.art(id).get("detail", {})
		verify(not detail.is_empty() and detail.pages.all(func(page): return RA2Art.ShpDetail.page_texture(page) != null), "原色双倍细节页 " + id)
	var ids=GameData.faction_unit_catalog("yuri")
	verify(ids.size()==16,"单位目录 "+str(ids))
	verify(GameData.buildings_for_faction("yuri").size()==16,"建筑目录")
	for id in ids: verify(not RA2Art.art(id).is_empty(),"模型 "+id)
	for b in GameData.buildings_for_faction("yuri"): verify(not RA2Art.art(b.id).is_empty(),"模型 "+b.id)
	var site=w._place_building("YAYARD","ally",Vector2(3000,1600),true)
	site._process(10)
	verify(site.buildable.has("YHVR") and site.buildable.has("BSUB"),"海军生产卡")
	verify(not site.can_queue("BSUB"),"雷鸣潜艇需要雷达")
	var radar=w._place_building("NAPSIS","ally",Vector2(650,2200),true)
	radar._process(10)
	for id in ["YHVR","BSUB"]:
		verify(site.enqueue(id),"船坞下单 "+id+" "+site.queue_block_reason(id))
		site._tick_unit_queue(1000,id)
		var ships=w.units.filter(func(u):return u.unit_id==id and u.side=="ally")
		verify(not ships.is_empty(),"船坞出厂 "+id)
		if ships.is_empty():continue
		var ship=ships[0]
		verify(w.in_water_world(ship.position),"水面出口 "+id)
		if id=="YHVR":verify(ship.logistics.capacity==12 and ship.logistics.size_limit==6,"运输舱")
		else: verify(ship._weapon_for_target(site).name=="BoomerTorpedo" and ship._weapon_for_target(radar).name=="CruiseLauncher","对海鱼雷与对岸导弹")
	var sub=w.units.filter(func(u):return u.unit_id=="BSUB")[0]
	var shore=w._place_building("NAPOWR","enemy",sub.position-Vector2(700,0),true)
	shore._process(10)
	sub.attack_target=shore
	sub._fire_shot(shore)
	var missiles=w.units.filter(func(u):return u.unit_id=="CMISL")
	verify(missiles.size()==1,"发射可拦截的巡航导弹")
	if not missiles.is_empty():
		var initial:float=shore.hp
		sub.SovietWeapons.fly(missiles[0],20.0)
		verify(shore.hp<initial,"巡航导弹命中岸上建筑")
	var ferry=w.units.filter(func(u):return u.unit_id=="YHVR")[0]
	ferry.position=Vector2(1250,1900)
	var passenger=w.spawn_unit("INIT","ally",ferry.position+Vector2(20,0))
	verify(passenger.logistics.request_board(ferry),"运输艇接受步兵")
	passenger.logistics.tick(0.1)
	verify(passenger.embarked_in==ferry,"步兵登艇")
	ferry.logistics.request_unload()
	ferry.logistics.unload_one()
	verify(passenger.embarked_in==null,"步兵登陆")
	for i in 6: w._place_building("YAPOWR","ally",Vector2(400+i*180,1400),true)._process(10)
	w._update_power()
	var vat=w._place_building("NACLON","ally",Vector2(1300,1100),true)
	vat._process(10)
	var barracks=w.buildings.filter(func(b):return b.building_id=="YABRCK" and b.side=="ally")[0]
	var before:int=w.units.size()
	verify(barracks.enqueue("INIT"),"兵营训练新兵")
	barracks._tick_unit_queue(999,"INIT")
	verify(w.units.size()==before+2,"复制中心复制训练完成的步兵")
	for id in ["YAGNTC","YAPPET"]:
		var sw=w._place_building(id,"ally",Vector2(900,1100),true)
		sw._process(10)
		sw._tick_superweapon(1000)
		var pos:=Vector2(1000,1750)
		var victim=w.spawn_unit("E2" if id=="YAGNTC" else "HTNK","enemy",pos)
		verify(sw.fire_superweapon(pos),id+" 充能释放")
		verify((victim._dead and w.units.any(func(u):return u.unit_id=="BRUTE" and u.side=="ally")) if id=="YAGNTC" else victim.side=="ally",id+" 命中效果")
	var factory=w._place_building("YAWEAP","ally",Vector2(900,800),true)
	var lab=w._place_building("YATECH","ally",Vector2(600,800),true)
	var grinder=w._place_building("YAGRND","ally",Vector2(300,800),true)
	for b in [lab,grinder,factory]: b._process(10)
	for producer in [barracks,factory,site]:
		for id in producer.data.builds: verify(producer.can_queue(id),"科技树可下单 "+id+" "+producer.queue_block_reason(id))
	var sensor=preload("res://scripts/world/yuri_support.gd")
	verify(sensor.reveals(w,"ally",radar.position+Vector2(820,0)),"感应器覆盖十五格")
	radar.under_construction=true
	verify(not sensor.reveals(w,"ally",radar.position),"未运行感应器不提供探测")
	radar.under_construction=false
	var mcv=w.spawn_unit("PCV","ally",Vector2(1100,2100))
	verify(mcv.deploy_building_id()=="YACNST","尤里基地车展开类型")
	get_tree().quit(errors)
