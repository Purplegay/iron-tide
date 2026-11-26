extends RefCounted

const BRIDGE := ["CASANF09","CASANF10","CASANF11","CASANF04","CASANF12","CASANF13","CASANF14"]
const LINES := {
 "csof016":"正在建立战场控制，请稍候。", "csof038":"增援部队已抵达。", "csof120":"战场控制已上线。", "csof124":"任务目标已完成。", "csof125":"警报：发现心灵控制器。",
 "xs1so21":"这是恶魔岛。回到过去后，我们要摧毁岛上的装置。现在先夺取盟军的时光机。", "xs1so14":"先消灭盟军舰队和岸防巨炮，运输艇才能靠岸。", "xs1so01":"干得好，指挥官。带领部队夺取这里的时光机。", "xs1so02":"有了时光机，我们就能回到过去，摧毁心灵控制器。", "xs1so03":"祝你好运，长官。", "xs1so04":"这个时代的恶魔岛防守太严了。先夺取时光机，再回到他们构筑防线之前发动攻击。", "xs1so05":"停火，长官！我们还需要这些发电厂启动时光机。", "xs1so06":"时光机没有电力。占领附近的发电厂，我们正在空投工程师支援。", "xs1so07":"电力足够了，开始时空转移。", "xs1so08":"尤里快要凑够电力了。阻止他，尽快赶到时光机。", "xs1so09":"太多发电厂被摧毁了，我们必须中止任务。", "xs1so11":"时光机充能完毕。准备好，指挥官，我们要出发了。", "xs1so12":"根据记录，这个时代附近有一座苏军基地。找到它，接过指挥权。", "xs1so13":"我们已接管这座基地。集结部队，摧毁心灵控制器。", "xs1so15":"时光机被摧毁了，我们的任务失败了。", "xs1so16":"不！我们竟然又失去了鲍里斯。今天是祖国黑暗的一天。", "xs1so17":"将军同志，鲍里斯阵亡了。我们不能让他的牺牲白费。", "xs1so18":"住手，将军同志！我们还得靠这台时光机完成任务。", "xs1so20":"消灭时光机周围的所有防御设施，我们就能接管它了。", "xs1so22":"鲍里斯同志，很高兴再见到你。", "xs1so23":"没有，当然没有。只是看到你平安无事，我很高兴。", "xs1so24":"回到过去之后，我们得找到鲍里斯，改变他的命运。", "xs1so25":"尤里的工程师也在抢占发电厂。电力一旦充足，他就会启动心灵控制器。",
 "xs1bo01":"鲍里斯报到。", "xs1bo02":"我离开过吗，索菲亚同志？", "xs1bo03":"我可不打算游过去。给我从船坞调一艘两栖运输艇来。", "csofu75":"盟军的重装大兵配备了反坦克武器。让军犬去对付他们。", "csofu82":"这位是鲍里斯，将军同志。他装备精良，有权呼叫空袭，是苏维埃人民的英雄。", "csofu92":"占领战地医院，可以让前线步兵得到救治。", "csofu93":"机械维修厂能够持续修理我们的车辆。"
}

static func dialogue(world,event:String) -> void:
	var file:String=world.TimeShift.ASSETS.data.voices.get(event,"")
	if file.is_empty():return
	var speaker:="鲍里斯" if file.begins_with("xs1bo") else "战场指挥系统" if file.begins_with("csof0") or file=="csof120" or file=="csof124" or file=="csof125" else "索菲亚"
	var text:String=LINES.get(file,"")
	if not text.is_empty():world.hud.show_field_transmission(speaker,text,"")
	Ra2Sfx.play_time_shift_line(file)

static func once(world,event:String) -> void:
	var s:Dictionary=world.allied_state.time_shift
	if not s.has(event):
		s[event]=true
		dialogue(world,event)

static func props(world,s:Dictionary) -> void:
	ambience(world,s)
	for b in world.buildings:
		if not world.actor_alive(b):continue
		if b.building_id in ["CAMACH","CATHOSP"] and world.actor_visible_to("ally",b):once(world,"Unit_Sofia_TechMachShop" if b.building_id=="CAMACH" else "Unit_Sofia_TechHospital")
		if s.phase==4 and b.building_id=="YAPPPT" and world.actor_visible_to("ally",b):once(world,"Mis_xS1_BorisWantsBoat")
		if s.phase in [1,2] and world.actor_visible_to("ally",b):
			if b.building_id=="YAPPET":once(world,"Mis_xS1_ZofiaCapTimeMachine")
			if b.special.get("time_shift_tag")=="Destroy_Time Defenses":once(world,"Mis_xS1_ZofiaTimeDefenses")
	if s.phase in [1,2,3,4]:
		var boris=world.units.filter(func(u):return world.actor_alive(u) and u.unit_id=="BORIS" and u.side=="ally")
		if boris.is_empty() and s.get("boris_seen",false):once(world,"Mis_xS1_ZofiaBorisDeadAgain" if s.phase==4 else "Mis_xS1_ZofiaBorisDeadMourn")
		elif not boris.is_empty():s.boris_seen=true
		for unit in world.units:
			if not world.actor_alive(unit):continue
			if unit.special.has("shift_debut") and unit.embarked_in==null:
				unit.special.erase("shift_debut");once(world,"Mis_xS1_BorisReporting")
			if unit.unit_id=="GGI" and unit.side=="enemy" and world.actor_visible_to("ally",unit):once(world,"Unit_Sofia_GuardianGi")
			if unit.special.get("shift_rexy",false) and unit.side=="neutral" and world.actor_visible_to("ally",unit):
				if not s.has("rexy_help"):s.rexy_help=true;Events.emit_message("霸王龙被困住了。摧毁围栏，给它打开出路。")
				var fences=world.buildings.filter(func(b):return world.actor_alive(b) and b.building_id=="CAFNCP" and b.position.distance_to(unit.position)<170)
				if fences.size()<3:AlliedAbilities.change_side(unit,"ally");Events.emit_message("获救的霸王龙加入了你的部队。")
	if s.phase==4 and not s.get("base_found",false):
		for u in world.units:
			if not world.actor_alive(u) or u.side!="ally" or u.embarked_in!=null:continue
			var cell:=Vector2i((u.position/55).floor())
			if world.TimeShift.FIELD.data.base_contact.any(func(v):return Vector2i(v[0],v[1])==cell):
				s.base_found=true
				for b in world.buildings:
					if world.actor_alive(b) and b.special.get("shift_base",false):AlliedAbilities.change_side(b,"ally")
				var ref=world.buildings.filter(func(b):return world.actor_alive(b) and b.building_id=="NAREFN" and b.side=="ally")
				if not ref.is_empty():world.spawn_unit("HARV","ally",world.TimeShift.wp(140),ref[0])
				world.TimeShift.announce_radar_objectives(world)
				once(world,"Mis_xS1_ZofiaSovietCommand")
				break

static func return_city(world) -> void:
	for row in world.TimeShift.FIELD.data.city_props:
		world.TimeShift.place(world,row[0],"neutral",world.TimeShift.wp(row[1]))
	for row in world.TimeShift.FIELD.data.return_city:
		for id in row[1]:
			for i in int(row[1][id]):
				var u=world.spawn_unit(id,"neutral",world.TimeShift.wp(row[0])+Vector2(i*20,0))
				if u==null:continue
				u.set_fire_stance("none")
				for n in row[2]:u.queue_waypoint(world.TimeShift.wp(n))

static func ambience(world,s:Dictionary) -> void:
	if s.elapsed<float(s.get("ambient_due",0)):return
	s.ambient_due=s.elapsed+8.0
	var camera:Vector2=world.camera.position
	var nearest:Array=[]
	var distance:=1000.0
	for row in world.TimeShift.FIELD.data.ambience:
		if (row[2]==1)!=(s.phase==3):continue
		var d:float=world.TimeShift.wp(row[1]).distance_to(camera)
		if d<distance:distance=d;nearest=row
	if not nearest.is_empty():Ra2Sfx.play(nearest[0],world.TimeShift.wp(nearest[1]))

static func bridge(world,s:Dictionary) -> void:
	var parts:Dictionary={}
	for b in world.buildings:
		if world.actor_alive(b) and b.building_id in BRIDGE:parts[b.building_id]=b
	if not s.has("bridge_return"):
		s.bridge_return=true
		for id in ["CASANF09","CASANF11"]:
			if parts.has(id):parts[id].receive_hit(parts[id].max_hp*0.25)
		if parts.has("CASANF10"):parts.CASANF10.receive_hit(100000)
		return
	if s.has("bridge_fallen"):return
	for i in range(2,7):
		if not parts.has(BRIDGE[i]):
			s.bridge_fallen=true
			for j in range(2,7):
				if parts.has(BRIDGE[j]):parts[BRIDGE[j]].receive_hit(100000)
			Events.emit_message("金门大桥的桥段接连坍塌。")
			return

static func raid(world,row:Dictionary) -> void:
	var w=world.TimeShift
	var start:Vector2=w.wp(row.start)
	var shore:Vector2=w.wp(row.route.back())
	var entry: Vector2 = world.path_service.nearest_reachable(start,shore,false,24,true)
	# The retail entry waypoint lies outside the playable era. Projection must
	# reserve separate hull-sized slots or all three transports overlap there.
	var spawn: Vector2 = Vector2.INF
	for ring in 7:
		for slot in 16:
			var candidate: Vector2 = entry + Vector2.RIGHT.rotated(TAU * slot / 16.0) * ring * 100.0
			if world.path_service.is_blocked(candidate,false,true) or not world.in_water_world(candidate):continue
			if world.units.any(func(u):return world.actor_alive(u) and u.unit_id=="YHVR" and u.position.distance_squared_to(candidate)<90.0*90.0):continue
			spawn=candidate
			break
		if spawn.is_finite():break
	if not spawn.is_finite():return
	var boat=world.spawn_unit("YHVR","enemy",spawn)
	if boat==null:return
	boat.order_stop()
	boat.special.shift_raid=shore
	var plant=null
	var distance:=INF
	for b in world.buildings:
		if not world.actor_alive(b) or b.building_id.length()!=7 or not b.building_id.begins_with("GAPOWR"):continue
		var d:float=b.position.distance_squared_to(w.wp(row.target))
		if d<distance:distance=d;plant=b
	for id in row.cargo:
		for i in int(row.cargo[id]):
			var unit=world.spawn_unit(id,"enemy",boat.position)
			if unit==null:continue
			unit.order_stop();unit.set_stowed(boat);boat.logistics.passengers.append(unit)
			unit.special.shift_plant=plant
	var goal:Vector2=world.path_service.nearest_reachable(shore,boat.position,false,12,true)
	boat.special.shift_raid=goal
	# The third retail route approaches from waypoint 459; a direct shortcut
	# through the city road intersects parked civilian vehicles.
	if int(row.route.back())==130:
		var via: Vector2 = world.path_service.nearest_reachable(w.wp(459),boat.position,false,12,true)
		boat.special.shift_raid_via=via
		boat.order_move(via,false,null,world.path_for_unit(boat,via))
	else:
		boat.order_move(goal,false,null,world.path_for_unit(boat,goal))

static func power_contest(world,s:Dictionary) -> void:
	var stages:=["Reinforce_Atk Group 1","Reinforce_Cap Group 1","Reinforce_Atk Group 2","Reinforce_Cap Group 2"]
	var index:=int(s.get("raid_index",0))
	var elapsed:=float(s.get("power_elapsed",0.0))
	if elapsed>=5.0:once(world,"Mis_xS1_ZofiaEngineersForPower")
	if elapsed>=65.0:once(world,"Mis_xS1_ZofiaYuriNeedsPower")
	var wave_count:=2 if int(BattleRequest.skirmish_config.get("difficulty",1))==0 else 4
	if index<wave_count and elapsed>=float([68,98,158,188][index]):
		for row in world.TimeShift.FIELD.data.raids:
			if row.group==stages[index]:raid(world,row)
		s.raid_index=index+1
	for u in world.units:
		if not world.actor_alive(u):continue
		if u.special.has("shift_raid_via") and u.position.distance_to(u.special.shift_raid_via)<80:
			u.special.erase("shift_raid_via")
			var shore: Vector2 = u.special.shift_raid
			u.order_move(shore,false,null,world.path_for_unit(u,shore))
		if u.special.has("shift_raid") and not u.special.has("shift_raid_via") and u.position.distance_to(u.special.shift_raid)<80:
			u.special.erase("shift_raid");u.logistics.request_unload()
		if u.embarked_in!=null or not u.special.has("shift_plant"):continue
		var b=u.special.shift_plant
		if not world.actor_alive(b):u.special.erase("shift_plant");continue
		if u.unit_id=="YENGINEER" and not u.special.has("action"):
			if b.side=="enemy":
				# The mission tracks two owners on the same combat side.
				if b.special.get("yuri_power", false): continue
				var door:=AlliedAbilities.approach(u,b)
				if u.position.distance_to(door)<u.radius+28:
					b.special.yuri_power=true;b.refresh_house_color();AlliedAbilities.consume(u)
				elif not u.has_move_order:u.order_move(door,false,null,world.path_for_unit(u,door))
			else:
				u.order_interaction("allied_engineer", b, false)
		elif u.unit_id=="INIT" and not u.has_move_order:
			if u.position.distance_to(b.position)>260:
				var destination:=AlliedAbilities.approach(u,b)
				u.order_move(destination,true,null,world.path_for_unit(u,destination))
			else:u.order_guard()
