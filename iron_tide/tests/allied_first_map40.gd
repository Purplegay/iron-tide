extends RefCounted

static func actors(world) -> Array:
	return world.units.filter(func(u):return world.actor_alive(u) and u.special.has("all01_city_spawn"))

static func verify(t,world) -> void:
	var s: Dictionary = world.allied_state.allied_first
	var d = world.AlliedFirst.city_driver(world,s)
	var level := int(d.state.difficulty)
	var users := actors(world)
	var expected := {}
	for row in d.definition.triggers:
		if row.name not in ["Make_Civ_Cars1","Make_Civ_Cars2","Make_People","Create_Kirov"]: continue
		t.expect(d.state.fired.has(row.id)==row.difficulty[level],"原图难度与出场 "+row.name)
		if not row.difficulty[level]: continue
		for fields in row.actions:
			if fields[0] not in ["7","80"]: continue
			var group: Dictionary = d.definition.teams[fields[2].to_lower()]
			var unit := str(group.task_force["0"]).split(",")[1]
			var code: String = fields[7] if fields[0]=="80" else group.team.waypoint
			var wp := int(d.definition.waypoints[code].id)
			var room: String = "Soviet2House" if group.team.house=="Soviet2 Country" else group.team.house
			var members := users.filter(func(u):return u.unit_id==unit and u.special.allied_first_team==fields[2] and u.special.all01_city_spawn==wp and u.special.allied_first_room==room)
			t.expect(members.size()==1 and not members[0]._ra2.is_empty(),"小队、单位美术、房号及原出场点 "+fields[2]+" / "+code)
			expected[fields[2]]=true
	t.expect(users.size()==(23 if level==0 else 24) and expected.size()==(19 if level==0 else 20),"按原图重复出场，按唯一小队计数")
	t.expect(d.state.fired.has(d.FLEET) and d.state.fired.has(d.MOVIES) and d.state.locals["3"] and (s.city_external_links.has("08a6340c") or s.get("retail_field",{}).get("fired",{}).has("08a6340c")),"舰队接入城市触发链，保留下游链接")

static func run(t,world) -> void:
	var s: Dictionary = world.allied_state.allied_first
	t.expect(actors(world).is_empty(),"城市与基洛夫在后续舰队前均未出场")
	world.AlliedFirst.tick(world,0.5)
	t.expect(actors(world).is_empty(),"不提前半秒出场")
	world.AlliedFirst.tick(world,0.5)
	verify(t,world)
	var d = world.AlliedFirst.city_driver(world,s)
	var units := actors(world)
	for u in units:
		var group: Dictionary = d.definition.teams[u.special.allied_first_team.to_lower()]
		var first := str(group.script["0"]).split(",")
		match first[0]:
			"3":
				var at: Vector2 = world.AlliedFirst.wp(int(first[1]))
				t.expect((u.has_move_order and u.move_target.is_equal_approx(at)) or u.position.distance_to(at)<world.AlliedFirst.Places.CELL,"首段移动 "+u.special.allied_first_team)
			"42": t.expect(not u.has_move_order and is_equal_approx(u.hull_angle,Vector2.UP.rotated((int(first[1])+1)*PI/4.0).angle()),"停靠朝向 "+u.special.allied_first_team)
			"5": t.expect(u.hold_position and u.special.has("all01_guard_until"),"原地警戒 "+u.special.allied_first_team)
			"19": t.expect(u.has_move_order,"平民受惊移动 "+u.special.allied_first_team)
	if "--map40-kirov-route" in OS.get_cmdline_user_args():
		await kirov_route(t,world,d,units.filter(func(u):return u.unit_id=="ZEP").front())
		return
	var truck = units.filter(func(u):return u.unit_id=="PTRUCK").front()
	var at: Vector2 = truck.position
	for i in 240:
		if truck.position.distance_to(at)>30: break
		await world.get_tree().physics_frame
	t.expect(truck.position.distance_to(at)>30,"皮卡按原路线实际驶离起点")
	t.expect(BattleSaves.save_slot(world,"quick").ok,"城区生成与行动游标已写入隔离存档")

static func guards(t,world,s: Dictionary) -> void:
	world.set_process(false)
	var mission = world.AlliedFirst
	mission.tick(world,0)
	var d = mission.city_driver(world,s)
	t.expect(d.watches.size()==32,"八组房号条件分别接入四条原图记录")
	for row in d.watches:
		var id: String = row.events[0][2]
		var starts_owned: bool = id=="409" and row.house=="PowerHouse Country"
		t.expect(d.state.fired.has(row.id)==(row.events[0][0]=="57" and not starts_owned),"原图初始房号和建筑存在条件 "+row.name)
	var eighth=mission.site(world,"CAPOWR08")
	mission.Orders.change_side(eighth,"ally")
	d.run(world,s,0.5)
	t.expect(d.state.fired.has("095b0d4c") and d.state.fired.has("095b597c"),"第八厂被占，409 的双方原条件发生变化")
	# Absent retail building types are constructed ONLY in this isolated fixture.
	for type in d.TYPES.values():
		if type=="CAPOWR08": continue
		# Use real live building actors for the typed ownership query; these types are absent from ALL01.
		var proxy=world.buildings.filter(func(b):return world.actor_alive(b) and b.building_id=="CAPOWR01").front()
		var old_type: String=proxy.building_id
		var old_room: String=proxy.special.allied_first_room
		var old_side: String=proxy.side
		for room in ["Americans","PowerHouse"]:
			proxy.building_id=type
			proxy.special.allied_first_room=room
			proxy.side=mission.side(room)
			d.run(world,s,0.5)
			for row in d.watches:
				if d.TYPES[row.events[0][2]]!=type or row.events[0][0]!="32": continue
				if (row.house=="Americans")!=(room=="Americans"): continue
				t.expect(d.state.fired.has(row.id),"隔离建筑条件夹具 "+row.name)
		proxy.building_id=old_type
		proxy.special.allied_first_room=old_room
		proxy.side=old_side
	mission.tick(world,149.0)
	t.expect(not s.has("power_reminder_at"),"供电提醒未提前")
	mission.tick(world,1.0)
	t.expect(s.has("power_reminder_at"),"未供电时第150秒显示任务目标")

static func kirov_route(t,world,d,zeppelin) -> void:
	var mission = world.AlliedFirst
	# Start at the approach checkpoint. Weapons and target loss use real field actors.
	zeppelin.position=mission.wp(304)
	d.step_member(world,zeppelin)
	d.step_member(world,zeppelin)
	var gun=zeppelin.attack_target
	t.expect(gun is Building and gun.building_id=="GTGCAN" and gun.side=="ally","基洛夫到达304后锁定盟军岸炮")
	if not gun is Building: return
	gun.receive_hit(gun.max_hp*10.0,"explosive")
	d.step_member(world,zeppelin)
	for wp in [146,147]:
		d.step_member(world,zeppelin)
		zeppelin.position=mission.wp(wp)
		d.step_member(world,zeppelin)
		d.step_member(world,zeppelin)
		var bomb_point=zeppelin.attack_target
		t.expect(bomb_point is ForceFirePoint and bomb_point.position==mission.wp(wp),"指向原图轰炸航点 "+str(wp))
		if not bomb_point is ForceFirePoint: return
		for frame in 300:
			if zeppelin.special.get("all01_bomb_released",false): break
			await world.get_tree().physics_frame
		t.expect(zeppelin.special.get("all01_bomb_released",false),"正常武器系统在航点实际投弹 "+str(wp))
		if not zeppelin.special.get("all01_bomb_released",false): return
		d.step_member(world,zeppelin)
	d.step_member(world,zeppelin)
	zeppelin.position=mission.wp(148)
	d.step_member(world,zeppelin)
	d.step_member(world,zeppelin)
	t.expect(not world.units.has(zeppelin),"148 后执行原图移除命令")
