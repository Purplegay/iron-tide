extends RefCounted

static func members(w,id: String) -> Array:
	return w.units.filter(func(u):return w.actor_alive(u) and u.special.get("allied_first_team","")==id)

static func until(w,s: Dictionary,d,at: float) -> void:
	w.AlliedFirst.tick_opening_ggi(w,s,maxf(0.0,at-float(d.state.time)))

static func cold(t,w) -> void:
	var s: Dictionary=w.allied_state.allied_first
	var before: Dictionary=s.retail_assault.duplicate(true)
	var boat=members(w,"0A2BD90C").filter(func(u):return u.unit_id=="YHVR").front()
	w.AlliedFirst.tick(w,0.0)
	t.expect(boat!=null and boat.logistics.passengers.size()==4 and boat.logistics.passengers.all(func(u):return u.embarked_in==boat),"冷读保留首船和全部四名乘员")
	t.expect(before.fired==s.retail_assault.fired and members(w,"09F3BC1C").size()==5,"独立读档保留任务游标，接战队不重复")

static func run(t,w,s: Dictionary) -> void:
	var m=w.AlliedFirst
	var d=m.assault_driver(w,s)
	var difficulty:=int(d.state.difficulty)
	w.set_process(false)
	m.tick(w,0.0)
	t.expect(d.rows.size()==50 and d.definition.teams.size()==15,"正式首关持有50条原始触发与15支本图队伍")
	t.expect(s.assault_input_locked and not w.world_input_enabled() and int(s.assault_base_wp)==15,"开场锁定控制并设置原图基地中心")
	until(w,s,d,2.01)
	t.expect(d.state.fired.has("0b0246cc") and d.state.fired.has("0885de3c") and s.assault_input_locked,"已播过雷达简报，直接执行基地镜头和简报触发，不重复等待")
	t.expect(members(w,"096D287C").size()==(4 if difficulty==2 else 0),"BY驻军只在困难创建四人")
	if difficulty==2:
		t.expect(members(w,"096D287C").all(func(u):return u.attack_ordered and u.attack_target is Building and u.attack_target.building_id=="CASANF02"),"困难BY队在77号航点瞄准实际中立建筑")
	t.expect(not d.state.fired.has("0437e7ec"),"UT驻军保留原图禁用状态")
	until(w,s,d,6.01)
	var eng:=members(w,"0D3FA93C")
	t.expect(eng.size()==2 and eng.all(func(u):return u.special.has("allied_first_index")),"开场工程师和IFV均来自原图预置实例")
	if eng.size()==2:
		var engineer=eng.filter(func(u):return u.unit_id=="ENGINEER").front()
		var car=eng.filter(func(u):return u.unit_id=="FV").front()
		t.expect(engineer.logistics.boarding==car or engineer.embarked_in==car,"工程师实际收到IFV登车指令")
	t.expect(d.state.fired.has("08a8e55c") and d.state.fired.has("0a815afc") and members(w,"08B066CC").size()==5,"电厂闪烁、箭头、雷达与五名已有GGI教学连通")
	t.expect(members(w,"09F3BC1C").size()==5,"AP航点生成五名尤里接战步兵")
	until(w,s,d,91.01)
	t.expect(d.state.fired.has("089627fc") and not s.assault_input_locked and d.state.enabled.has("069b22fc"),"控制权交还后启动135秒AP空投计时")
	t.expect(not d.state.fired.has("0b7d4bcc"),"第一艘气垫船到时前不出现")
	until(w,s,d,150.01)
	var fleet:=members(w,"0A2BD90C")
	t.expect(fleet.size()==5,"第一队按时出场一船、一坦克、三名步兵")
	t.expect(members(w,"089B3A4C").size()==(0 if difficulty==0 else 5),"西北地面步兵只在普通及困难出场")
	if fleet.size()!=5: return
	var boat=fleet.filter(func(u):return u.unit_id=="YHVR").front()
	t.expect(boat.logistics.passengers.size()==4 and boat.logistics.passengers.all(func(u):return u.embarked_in==boat),"四名乘员实际位于气垫船舱内")
	t.expect(BattleSaves.save_slot(w,"quick").ok,"运输途中写入真实首关存档")
	var sail_start: Vector2=boat.position
	for i in 150:
		if boat.position.distance_to(sail_start)>60: break
		await w.get_tree().physics_frame
	t.expect(boat.position.distance_to(sail_start)>60,"首艘满载运输船从边界真实启航")
	var teams: Array=[["0A2BD90C","0B7D664C",11,10,4],["0A80332C","0AB4AB7C",23,24,4],["0A7F16AC","0B16493C",38,37,5]]
	for i in teams.size():
		var lane: Array=teams[i]
		if i>0: m.tick_opening_ggi(w,s,120.1)
		var ships:=members(w,lane[0]).filter(func(u):return u.unit_id=="YHVR")
		t.expect(ships.size()==1,"清场条件开启下一条运输线 "+str(lane[0]))
		if ships.is_empty(): break
		boat=ships[0]
		t.expect(boat.logistics.passengers.size()==int(lane[4]),"原编组船舱人数 "+str(lane[0]))
		# Place the actual hull at its original beach; disembark through the normal unit logistics.
		boat.position=m.wp(lane[2])
		for j in 18:
			d.Teams.step(w,d,boat)
			if boat.logistics.unloading: boat.logistics.unload_one()
			if boat.special.get("assault_return_ready",false): break
		m.tick_opening_ggi(w,s,0.0)
		t.expect(boat.logistics.passengers.is_empty() and boat.special.allied_first_team==lane[1],"真正卸空后原船被返航队招募 "+str(lane[1]))
		if boat.special.allied_first_team!=lane[1]: break
		t.expect(boat.special.has("assault_boundary_target") and boat.move_target.distance_to(boat.position)>55,"界外返航点对应实际边界航路")
		boat.position=boat.move_target
		d.Teams.step(w,d,boat)
		d.Teams.step(w,d,boat)
		t.expect(not w.actor_alive(boat),"原船到返航点后离场")
		for u in members(w,lane[0]): m.Orders.consume(u)
		m.tick_opening_ggi(w,s,0.0)
	if difficulty!=0:
		for id in ["089B3A4C","0C36E6AC","0AA2AEFC"]:
			m.tick_opening_ggi(w,s,125.0)
			var unit_list:=members(w,id)
			t.expect(unit_list.size()==(5 if id=="089B3A4C" else 4),"苏军三段援军原编组 "+id)
			for u in unit_list: m.Orders.consume(u)
			m.tick_opening_ggi(w,s,3.1)
			m.tick_opening_ggi(w,s,0.0)
	else: m.tick_opening_ggi(w,s,140.0)
	var planes: Array=w.units.filter(func(u):return w.actor_alive(u) and u.special.get("para_story_tags",{}).get("allied_first_team","")=="0D2AF91C")
	t.expect(planes.size()==1 and planes[0].side=="enemy" and planes[0].special.para_count==5,"AP空投以敌方运输机运载五名新兵")
	if planes.size()==1:
		var plane=planes[0]
		var drop=preload("res://scripts/world/american_paradrop.gd")
		for step in 900:
			if int(plane.special.para_left)==0: break
			drop.fly(plane,0.15)
		var landed:=members(w,"0D2AF91C")
		for soldier in landed:
			for step in 160:
				if not soldier.special.has("para_height"): break
				drop.descend(soldier,0.1)
		t.expect(landed.size()==5 and landed.all(func(u):return u.side=="enemy" and u.special.allied_first_room=="Africans" and not u.special.has("para_height")),"AP运输机沿真实航线投下五名所属房号步兵")
	var field=m.field_driver(w,s)
	field.run(w,s,19.0)
	var jets: Array=w.units.filter(func(u):return w.actor_alive(u) and u.special.get("allied_first_room","")=="Alliance")
	t.expect(jets.size()==2 and not d.state.fired.has("0611babc"),"战机未跨过指定竖线时两机存活")
	if jets.size()==2:
		m.tick_opening_ggi(w,s,0.0)
		var line_y: float=(int(d.definition.harrier_cell)%1000-18+0.5)*m.Places.CELL
		jets[0].position.y=line_y+m.Places.CELL*2.0
		m.tick_opening_ggi(w,s,0.0)
		if not d.state.fired.has("0611babc"):
			jets[0].position.y=line_y-m.Places.CELL*2.0
			m.tick_opening_ggi(w,s,0.0)
		t.expect(d.state.fired.has("0611babc") and jets.all(func(u):return not w.actor_alive(u)),"Alliance飞机跨过原图标签后只清理该房")
	for id in ["08b5892c","089d698c","08a8953c"]:
		t.expect(not d.state.fired.has(id),"孤立的雷达延迟在原图保持禁用 "+id)
		d.link(id,true)
	m.tick_opening_ggi(w,s,2.0)
	t.expect(s.get("assault_plant_links",{}).size()==2 and d.state.fired.has("08a8953c"),"条件启用三条雷达延迟后送入相应电厂指示")
	d.link("0437e7ec",true)
	m.tick_opening_ggi(w,s,1.0)
	t.expect(d.state.fired.has("0437e7ec") and members(w,"043998EC").size()==5,"受控启用UT后招募五名原场步兵")
