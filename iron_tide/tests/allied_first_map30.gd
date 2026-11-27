extends RefCounted

# Counts are from the retail TaskForces. The last three teams only exist on normal/hard.
const TEAMS := {"0B03E84C":5,"08B03A4C":5,"0E0F469C":5,"08A006AC":2,"0BB37C5C":1,"0BB4625C":2,"089305FC":4,"0AEB68DC":4,"08934B5C":4,"096C680C":4,"096FCB5C":4,"06B9CD4C":4,"0BF1048C":2,"0C8E7A8C":4,"0AEB2EFC":4,"0AEB564C":4}
const REINFORCEMENTS := ["0C8E7A8C","0AEB2EFC","0AEB564C"]
const DEPLOY := ["0B03E84C","08B03A4C","0E0F469C"]

static func members(w,id: String) -> Array:
	return w.units.filter(func(u):return w.actor_alive(u) and u.special.get("allied_first_team","")==id)

static func run(test,w,s: Dictionary,plants: Array) -> void:
	var m = w.AlliedFirst
	var easy := "--easy" in OS.get_cmdline_user_args()
	var reactor = m.site(w,"NANRCT")
	m.tick(w,1.1)
	test.expect(s.retail_opening.fired.has("087857cc") and reactor.hp<reactor.max_hp*197.0/256.0,"NA 航点爆炸实际损伤原核电站")
	test.expect(not s.retail_opening.fired.has("0a81253c") and not s.retail_opening.fired.has("0ab41d9c"),"基地简报前不派诱饵")
	var fired: Dictionary = s.retail_opening.fired
	test.expect(fired.size()==(9 if easy else 12),"开局原图触发器数与难度一致")
	for id in TEAMS:
		if id=="0BF1048C": continue # Recruited after the camera reaches the GGI group.
		var group := members(w,id)
		var count: int = 0 if easy and id in REINFORCEMENTS else TEAMS[id]
		test.expect(group.size()==count,"编组 "+id+" 实际人数 "+str(group.size()))
		if group.is_empty(): continue
		var expected_room := "Americans" if id in DEPLOY else "YuriCountry"
		test.expect(group.all(func(u):return u.special.get("allied_first_room","")==expected_room and u.special.has("allied_first_index")==(id not in REINFORCEMENTS)),"房号与招募来源 "+id)
		if id in DEPLOY: test.expect(group.all(func(u):return u.is_deployed()),"原地部署 "+id)
	m.tick_opening_ggi(w,s,66.0-float(s.retail_assault.time))
	test.expect(s.retail_opening.fired.has("0a81253c") and members(w,"0BF1048C").size()==2,"重装教学镜头与原图两辆诱饵实际到场")
	var rd := members(w,"0BB37C5C")
	if not rd.is_empty():
		var u = rd.front()
		var start: Vector2 = u.position
		test.expect(u.attack_move and u.move_target.is_equal_approx(m.wp(472)),"RD 坦克按首个攻击巡逻航点出发")
		for frame in 300:
			if start.distance_to(u.position)>60.0: break
			await test.get_tree().physics_frame
		test.expect(start.distance_to(u.position)>60.0,"巡逻坦克在正式地图实际移动")
	for id in ["096C680C","0AEB564C"]:
		var group := members(w,id)
		if group.is_empty(): continue
		var walker = group.front()
		var opening = w.get_meta("first_opening_driver")
		opening.move_member(w,walker)
		var destination: Vector2 = walker.move_target
		test.expect(not destination.is_equal_approx(m.wp(205)) and w.path_service.native_flags(destination)!=0,"界外航点 205 解析到可玩格 "+id)
		# Arrival fixture at the real assigned destination, then run the original next command.
		walker.position = destination
		opening.move_member(w,walker)
		opening.move_member(w,walker)
		var next := 681 if id=="096C680C" else 27
		test.expect(walker.move_target.is_equal_approx(m.wp(next)),"抵达边界后继续本队下一航点 "+id)
	for i in range(1,9):
		m.Orders.change_side(m.site(w,"CAPOWR%02d"%i),"ally")
	m.tick(w,0.0)
	var prefix: String = "简单" if easy else "普通"
	var owners: Dictionary = s.get("auxiliary_plant_owners",{})
	test.expect(owners.size()==(8 if easy else 0),prefix+"难度的辅助电厂归属数量正确")
	if easy:
		for row in m.RetailDriver.DATA.data.yr_all01umd.triggers:
			if row.name.begins_with("GivePower"): test.expect(s.retail_power_loss.fired.has(row.id),row.name+" 对应界外实例获得电力")
		test.expect(s.auxiliary_power==1600 and w._side_power("ally").produced==3200 and w.power_produced==3200,"八座场内厂与八座界外厂的 HUD、电网一致")
		var eighth = m.site(w,"CAPOWR08")
		m.Orders.change_side(eighth,"enemy")
		m.tick(w,0.0)
		test.expect(s.retail_power_loss.fired.has("09b7e4dc") and w.actor_alive(eighth) and s.auxiliary_power==1400,"第八组因失去所有权收回电力，无须毁楼")
		var parity := 0 if "--even-loss" in OS.get_cmdline_user_args() else 1
		for i in range(1,8):
			if i%2!=parity: continue
			var plant = m.site(w,"CAPOWR%02d"%i)
			plant.receive_hit(plant.max_hp*10.0,"explosive")
			m.tick(w,0.0)
			var row: Dictionary = m.RetailDriver.DATA.data.yr_all01umd.triggers.filter(func(r):return r.name=="TakePower"+str(i)).front()
			var record: Dictionary = m.RetailDriver.DATA.data.yr_all01umd.auxiliary_plants[str(i)]
			test.expect(s.retail_power_loss.fired.has(row.id) and owners[record.index]=="PowerHouse",row.name+" 摧毁后收回本实例")
	test.expect(BattleSaves.save_slot(w,"quick").ok,"开局编队及辅助电力实际写盘")

static func cold(test,w) -> void:
	var s: Dictionary = w.allied_state.allied_first
	var old: Dictionary = s.retail_opening.fired.duplicate()
	var grid: float = w._side_power("ally").produced
	var count := members(w,"0BB37C5C").size()
	w.AlliedFirst.tick(w,0.25)
	test.expect(s.retail_opening.fired==old and members(w,"0BB37C5C").size()==count and count==1,"冷读保留原编组与已执行触发器")
	test.expect(s.auxiliary_power==600 and grid==w._side_power("ally").produced and grid==w.power_produced,"冷读保留界外电力及 HUD")
