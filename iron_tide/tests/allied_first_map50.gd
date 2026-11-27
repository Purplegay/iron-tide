extends RefCounted
const Adapter=preload("res://scripts/world/allied_first_field_driver.gd")

static func opening(t,w,s: Dictionary,standalone: bool) -> void:
	w.set_process(false)
	var d=Adapter.new() if standalone else w.get_meta("all01_field_driver",null)
	if standalone: t.expect(d.initialize(s,1),"原图驱动初始化")
	if d==null:
		t.expect(false,"正式战场加载地图驱动")
		return
	d.run(w,s,0.0)
	w.camera.global_position=w.AlliedFirst.wp(14)
	d.run(w,s,0.0)
	print("FIELD_AUDIO ",s.field_sounds.size()," ",d.ambience.voices.size())
	t.expect(s.field_sounds.size()>20 and not d.ambience.voices.is_empty(),"开场原图环境音有真实播放器")
	var testunit=w.units.filter(func(u):return w.actor_alive(u) and u.side=="ally" and u.special.get("allied_first_room")=="Americans" and not u.is_air).front()
	for id in ["0b94716c","095259ac","0b945a6c","0b94432c","0462b74c"]:
		var packed:=int(d.definition.field_cells[id][0])
		testunit.position=Vector2(157-packed/1000+0.5,packed%1000-18+0.5)*55
		d.run(w,s,0.0)
		t.expect(d.state.fired.has(id)==(id!="0b94432c"),"进入原图格标签 "+id+"（第三组保留禁用）")
	var briefing=w.get_node_or_null("AlliedFirstVoice")
	t.expect(briefing!=null and briefing.stream!=null and briefing.stream.get_length()>8.0,"机炮原声已由实际播放器载入")
	d.run(w,s,3.0)
	t.expect(s.field_arrow_clocks.size()==3 and d.state.fired.has("045a11cc"),"三处机炮箭头与教学")
	d.run(w,s,12.0)
	t.expect(not d.state.enabled.has("09610f3c") and not d.state.enabled.has("0d39599c") and not d.state.enabled.has("0973096c"),"15秒后停止机炮指示")
	d.run(w,s,4.0)
	t.expect(w.units.filter(func(u):return w.actor_alive(u) and u.special.get("allied_first_team","") in ["0780F21C","0780BC8C"] and u.special.allied_first_room=="Alliance" and u.has_move_order).size()==2,"两支盟友鹞式战机收到214航点命令")
	var pipes:=0
	for b in w.buildings:
		if w.actor_alive(b) and b.building_id=="CAMISC05": pipes+=1
	t.expect(pipes==1,"摧毁两处绑定管线，未绑定管线保留")
	if standalone:
		d.enable(d.PEOPLE)
		d.run(w,s,0.0)
		t.expect(d.state.fired.has("0692c4ac") and d.state.fired.has("04c19e5c"),"城内居民、驻军、港口和缆车完整串接")
		t.expect(w.units.filter(func(u):return w.actor_alive(u) and u.special.get("field_spawn_wp",-1)==33 and u.unit_id=="CBLC").size()==1,"原图缆车单次出场")
		d.enable(d.APOCS)
		s.armor_sent=true
		s.crossing_swapped=true
		d.run(w,s,4.0)
		t.expect(d.state.enabled.has(d.ENTER),"两房清空后等待谭雅")
		d.run(w,s,1.0)
		t.expect(d.state.fired.has(d.ENTER) and not s.awaiting_tanya,"第5秒从原图队伍派出谭雅")
		for u in w.units:
			if w.actor_alive(u) and u.unit_id=="TANY": u.hp=0
		d.run(w,s,0.0)
		d.run(w,s,1.0)
		t.expect(s.get("carrier_waves",0)==2,"阵亡后两批航母按原时间出场")

static func capture_roster(w) -> void:
	# Observe the spawned actors before the arrival film releases physics and combat resumes.
	var roster: Array=[]
	for u in w.units:
		if w.actor_alive(u) and u.special.has("field_spawn_wp"):
			roster.append([u.special.allied_first_team,u.unit_id,u.special.allied_first_room,int(u.special.field_spawn_wp)])
	w.set_meta("map50_initial_roster",roster)

static func past(t,w,s: Dictionary) -> void:
	var d=w.get_meta("all01_field_driver")
	w.AlliedFirst.tick(w,1.0)
	var new_teams: Dictionary={}
	for row in d.definition.triggers:
		if row.name not in ["Make_People2","Make_Alcatraz_Men","Start_Sounds2"]: continue
		for fields in row.actions:
			if fields[0]!="7": continue
			var group: Dictionary=d.definition.teams[fields[2].to_lower()]
			var found: Array=w.get_meta("map50_initial_roster",[]).filter(func(r):return r[0]==fields[2])
			for i in group.task_force:
				if not str(i).is_valid_int(): continue
				var force:=str(group.task_force[i]).split(",")
				t.expect(found.filter(func(r):return r[1]==force[1] and r[2]==group.team.house and r[3]==d.wp_code(group.team.waypoint)).size()==int(force[0]),"本图房号、编组与出场点 "+fields[2]+" "+force[1])
			new_teams[fields[2]]=true
	t.expect(new_teams.size()==10,"八支驻军、恶魔岛巡逻与缆车")
	var stationed=w.units.filter(func(u):return w.actor_alive(u) and u.unit_id=="E2" and u.special.has("field_spawn_wp") and u.special.allied_first_room=="French")
	for frame in 360:
		if stationed.any(func(u):return u.embarked_in is Building): break
		await w.get_tree().physics_frame
	t.expect(stationed.any(func(u):return u.embarked_in is Building),"苏军经战场驻军指令实际进楼")
	var residents=w.units.filter(func(u):return w.actor_alive(u) and u.special.get("allied_first_team","")=="068FFC5C" and u.special.has("field_spawn_wp"))
	t.expect(residents.size()==2,"原小队在两个新增航点各出现一次")
	for row in d.rows.values():
		if row.name.begins_with("Kill_Sounds") or row.name.begins_with("Traffic_Sounds") or row.name.begins_with("Bird_Sounds") or row.name in ["Make_People2","Make_Alcatraz_Men","Start_New_Sounds","Start_Sounds2","Check_BridgePiece02"]:
			t.expect(d.state.fired.has(row.id),"过去时代执行 "+row.name)
	t.expect(d.state.pending.is_empty() and not s.field_sounds.is_empty(),"城市环境音状态已完成交接")
	t.expect(BattleSaves.save_slot(w,"quick").ok,"正式写出驻军、声源与巡逻游标")

static func rescue(t,w,s: Dictionary) -> void:
	w.set_process(false)
	var m=w.AlliedFirst
	m.tick(w,0.0)
	var d=w.get_meta("all01_field_driver")
	var machine=m.site(w,"CATIME01")
	machine.receive_hit(22,"explosive")
	m.tick(w,0.0)
	t.expect(d.state.fired.has("097d15dc") and not d.state.fired.has("097d02cc"),"时光机受击，保护通讯尚未到期")
	m.tick(w,3.0)
	t.expect(d.state.fired.has("097d02cc"),"三秒后播放保护通讯")
	for u in w.units.duplicate():
		if w.actor_alive(u) and u.side=="ally" and u.unit_id=="ENGINEER":
			m.Orders.consume(u)
			w.units.erase(u)
	var barracks=m.site(w,"GAPILE")
	barracks.receive_hit(barracks.max_hp*10.0,"explosive")
	w.power_low=false
	d.run(w,s,0.0)
	t.expect(d.state.fired.has("08e56b3c") and not d.state.fired.has(d.ENGINEERS),"兵营被毁但有电时不派补援")
	w.power_low=true
	d.run(w,s,0.0)
	t.expect(s.get("engineer_drop_pending",false) and not d.state.fired.has(d.ARRIVED),"低电且无工程师时运输机起飞")
	for i in range(1500):
		var landed: Array=w.units.filter(func(u):return w.actor_alive(u) and u.special.get("allied_first_team","")=="0908B07C" and not u.special.has("para_height"))
		if landed.size()==4: break
		await w.get_tree().physics_frame
	d.run(w,s,0.0)
	var members: Array=w.units.filter(func(u):return w.actor_alive(u) and u.unit_id=="ENGINEER" and u.special.get("allied_first_team","")=="0908B07C" and u.special.allied_first_room=="Americans" and not u.special.has("para_height"))
	t.expect(members.size()==4 and d.state.fired.has(d.ARRIVED) and not s.get("engineer_drop_pending",false),"四名原房号工程师落地后才通报并重新布置检查")
	t.expect(not d.state.enabled.has(d.ARRIVED),"未重派第二架运输机")

static func cold(t,w) -> void:
	var s: Dictionary=w.allied_state.allied_first
	var previous: Dictionary=s.retail_field.fired.duplicate()
	var source_count:int=s.field_sounds.size()
	var soldiers: Array=w.units.filter(func(u):return w.actor_alive(u) and u.special.has("field_spawn_wp"))
	var count:=soldiers.size()
	w.AlliedFirst.tick(w,0.0)
	var d=w.get_meta("all01_field_driver")
	t.expect(d.state.fired==previous and s.field_sounds.size()==source_count,"声源与任务断点恢复，已执行触发未重发")
	t.expect(count>=40 and count==w.units.filter(func(u):return w.actor_alive(u) and u.special.has("field_spawn_wp")).size(),"驻军、巡逻与缆车冷读不重复")
	t.expect(soldiers.any(func(u):return u.embarked_in is Building),"独立读档恢复实际驻军")
