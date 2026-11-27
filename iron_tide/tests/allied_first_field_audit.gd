extends RefCounted

static func field(test,world) -> void:
	var field_rows: Array = world.AlliedFirst.Field.data.structures
	var defs: Dictionary = preload("res://data/ra2/allied_first_sites.json").data.types
	var actors := {}
	for b in world.buildings:
		if not world.actor_alive(b): continue
		var id: String = b.special.get("allied_first_index","")
		if not id.is_empty(): actors.get_or_add(id,[]).append(b)
	var outside := 0
	var destroyed := 0
	var present := 0
	var neutral := 0
	var bridge := 0
	var issues := []
	for r in field_rows:
		var matches: Array = actors.get(r[0],[])
		if not r[8] or int(r[3])==0:
			if not matches.is_empty(): issues.append([r[0],"unexpected actor"])
			if not r[8]: outside+=1
			else: destroyed+=1
			continue
		present+=1
		if r[1]=="Neutral": neutral+=1
		if r[1]=="BridgeHouse": bridge+=1
		if matches.size()!=1:
			issues.append([r[0],r[2],"instances",matches.size()])
			continue
		var b = matches[0]
		var d: Dictionary = defs[r[2]]
		var xy: PackedStringArray = str(d.foundation).split("x")
		var center := Vector2(r[4]+(1-int(xy[1]))*0.5,r[5]+(int(xy[0])-1)*0.5)*55
		if not b.position.is_equal_approx(center) or b.data.foundation!=d.foundation: issues.append([r[0],r[2],"foundation"])
		if b.building_id!=r[2] or b.special.allied_first_room!=r[1] or b.side!=world.AlliedFirst.side(r[1]): issues.append([r[0],r[2],"house/type"])
		if not is_equal_approx(b.max_hp,float(d.hp)) or not is_equal_approx(b.hp/b.max_hp,float(r[3])/256.0): issues.append([r[0],r[2],"health",b.hp,b.max_hp])
		if b._ra2.is_empty(): issues.append([r[0],r[2],"art"])
		if r[1]=="Neutral" and (int(b.data.get("garrison_slots",0))!=int(d.slots) or b.data.get("capturable",false)!=d.capturable): issues.append([r[0],r[2],"occupancy"])
		if not b._col.is_equal_approx(HouseColor.first_room_color(r[1])): issues.append([r[0],r[2],"color",b._col])
		world.fog.building_memory.observe(b)
		if not world.fog.building_memory.records[b.position].radar.is_equal_approx(b._col): issues.append([r[0],r[2],"radar memory"])
	print("ALL01_FIELD present=",present," outside=",outside," destroyed=",destroyed," neutral=",neutral," bridge=",bridge," differences=",issues)
	test.expect(field_rows.size()==189 and present==157 and outside==31 and destroyed==1 and neutral==104 and bridge==5 and issues.is_empty(),"189 个原始建筑实例逐项核对")
	var layout: Dictionary = world.AlliedFirst.Places.data(world.map_layout())
	scenery(test,world)
	test.expect(layout.bridge_decks.is_empty() and layout.bridges.is_empty(),"首关普通桥覆层及通行桥面与原图空集合一致")

static func scenery(test,world) -> void:
	var src: Dictionary = world.AlliedFirst.Sites.data
	var actual := {}
	for sprite in world.get_node("AlliedFirstScenery").get_children():
		actual.get_or_add(sprite.position,[]).append(sprite.texture.resource_path)
	var problems := 0
	var drills: Dictionary = world.AlliedFirst.Places.data(world.map_layout()).drill_cells
	for row in src.props:
		var at := Vector2(row[1],row[2])
		if str(row[0]).begins_with("TIBTRE"):
			var rigs: Array = world.get_node("NativeOreDrills").get_children().filter(func(rig):return rig.position.is_equal_approx(at*55) and rig.atlas!=null)
			if not drills.has(Vector2i(at.floor())) or rigs.size()!=1: problems+=1
			continue
		var key := at*55
		if not actual.has(key) or actual[key]!=[src.textures[row[0]]]: problems+=1
		actual.erase(key)
	test.expect(src.props.size()==196 and src.outside==34 and actual.is_empty() and problems==0,"230 条原图地物按格核对，区内 195 个贴图实例与 1 个矿树格唯一")

static func global_ai(test,world,s: Dictionary) -> void:
	var mission = world.AlliedFirst
	var row: Dictionary = mission.GlobalAI.TABLE.data.rows[0]
	var regular: bool = int(BattleRequest.skirmish_config.get("difficulty",1))!=0
	mission.tick(world,0.01)
	test.expect(not world.buildings.any(func(b):return world.actor_alive(b) and b.special.has(mission.GlobalAI.ORDER)),"原图无本房车厂，AI 未下生产单")
	var origin: Vector2 = mission.wp(14)
	var factory_at: Vector2 = mission.Places.find_base_site(world,origin,"NAWEAP")
	var refinery_at: Vector2 = mission.Places.find_base_site(world,origin+Vector2(400,0),"NAREFN","HARV")
	test.expect(factory_at.is_finite() and refinery_at.is_finite(),"夹具找到正式地图可用工业地块")
	if not factory_at.is_finite() or not refinery_at.is_finite(): return
	var maker=world._place_building("NAWEAP","enemy",factory_at,true)
	var refinery=world._place_building("NAREFN","enemy",refinery_at,true)
	maker._process(20.0)
	refinery._process(20.0)
	refinery.special.allied_first_room="Confederation"
	maker.special.allied_first_room="Russians"
	s.global_ai_left=0
	mission.tick(world,0.01)
	test.expect(maker.production.is_empty(),"其他房号的车厂不能替本房生产")
	maker.special.allied_first_room="Confederation"
	s.global_ai_left=0
	mission.tick(world,0.01)
	test.expect(maker.production.has("HARV")==regular and maker.special.get(mission.GlobalAI.ORDER,"")== (str(row.id) if regular else ""),"按难度在本房车厂进入真实队列")
	if not regular or not maker.production.has("HARV"):
		if regular: print("ALL01_AI queue: ",maker.queue_block_reason("HARV")," operational=",maker.is_operational()," buildings=",world.owned_building_ids("enemy"))
		return
	s.global_ai_left=0
	mission.tick(world,0.01)
	test.expect(maker.production.count("HARV")==1,"在产队伍不会重复排单")
	if "--save-ai-queue" in OS.get_cmdline_user_args():
		maker._tick_unit_queues(0.5)
		test.expect(BattleSaves.save_slot(world,"slot2").ok,"保存已开工的 AI 矿车队列")
	var before: float = world.funds_for("enemy")
	for i in 8:
		if maker.production.is_empty(): break
		maker._tick_unit_queues(100)
	var miners: Array = world.units.filter(func(u):return world.actor_alive(u) and u.special.get("allied_first_ai","")==row.id)
	test.expect(miners.size()==1 and world.funds_for("enemy")<before and not maker.special.has(mission.GlobalAI.ORDER),"普通产线按进度扣费并交付唯一 AI 矿车")
	if not miners.is_empty():
		var u=miners[0]
		test.expect(u.special.allied_first_room=="Confederation" and u.special.allied_first_team==row.team and u.has_move_order and u.move_target.distance_to(refinery.position)<230,"出厂矿车执行原脚本 58,15 前往本房矿厂")

		s.global_ai_left=0
		mission.tick(world,0.01)
		test.expect(maker.production.is_empty(),"Max=1，已出厂队伍执行脚本时不重复选队")
		u.order_stop()
		var extra := []
		for i in 3:
			var more=world.spawn_unit("HARV","enemy",origin+Vector2(100+i*70,0))
			more.special.allied_first_room="Confederation"
			extra.append(more)
		s.global_ai_left=0
		mission.tick(world,0.01)
		test.expect(maker.production.is_empty(),"本房四辆矿车时原版条件不成立")
		extra.back().special.allied_first_room="Russians"
		s.global_ai_left=0
		mission.tick(world,0.01)
		test.expect(maker.production.count("HARV")==1,"本房三辆、外房一辆时恢复生产资格")
		if maker.production.has("HARV"): maker.cancel_at(maker.production.find("HARV"))
		test.expect(not maker.special.has(mission.GlobalAI.ORDER),"通过普通生产队列取消会释放 AI 订单")
		for member in extra:
			mission.Orders.consume(member)
			world.units.erase(member)

static func cold(test,w,ai: bool) -> void:
	var mission = w.AlliedFirst
	var state: Dictionary = w.allied_state.allied_first
	scenery(test,w)
	if ai:
		var makers: Array = w.buildings.filter(func(b):return w.actor_alive(b) and b.special.has(mission.GlobalAI.ORDER))
		test.expect(makers.size()==1,"冷读仅恢复一个 AI 生产单")
		if makers.size()!=1: return
		var b = makers[0]
		test.expect(b.production.count("HARV")==1 and b.total_production_paid()>0,"矿车已付进度及所属队伍随档恢复")
		state.global_ai_left=0
		mission.tick(w,0.01)
		test.expect(b.production.count("HARV")==1,"冷读后决策不会重复排队")
		for i in 8:
			if b.production.is_empty(): break
			b._tick_unit_queues(100)
		var units: Array = w.units.filter(func(u):return w.actor_alive(u) and u.special.has("allied_first_ai"))
		test.expect(units.size()==1 and units[0].has_move_order and not b.special.has(mission.GlobalAI.ORDER),"冷读后交付一辆矿车并接令")
	else:
		var east = mission.site(w,"CASANF12")
		var west = mission.site(w,"CASANF13")
		var complete := true
		for id in ["07a8917c","07a8ccbc","07a8d3ec","0835813c","0935a09c"]:
			complete = complete and state.retail_power_sequence.fired.has(id)
		test.expect(complete and mission.site(w,"CASANF04")==null and mission.site(w,"CASANF09")==null and mission.site(w,"CASANF11")==null,"桥梁触发器和已毁桥段随档恢复")
		if east==null or west==null: test.expect(false,"幸存桥段随档恢复"); return
		var east_hp: float = east.hp
		var west_hp: float = west.hp
		mission.tick(w,0.1)
		test.expect(is_equal_approx(east.hp,east.max_hp-300) and is_equal_approx(west.hp,west.max_hp-300) and east_hp==east.hp and west_hp==west.hp,"幸存桥段保留准确伤害，冷读后不重击")
		var tanks: Array = w.units.filter(func(u):return w.actor_alive(u) and u.unit_id=="APOC")
		var vessels: Array = w.units.filter(func(u):return w.actor_alive(u) and u.unit_id=="DRED")
		var domains: bool = not tanks.is_empty() and not vessels.is_empty()
		for id in [59,70,78,97,144]:
			var at: Vector2 = mission.wp(id)
			domains = domains and w.path_service.native_flags(at)==2 and not tanks[0]._domain_ok(at) and vessels[0]._domain_ok(at)
		test.expect(domains,"五个桥区原图水格均拒绝坦克、允许舰船，断口无跨水桥面")
