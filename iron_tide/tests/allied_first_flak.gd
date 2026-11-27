extends RefCounted

static func decide(w,s) -> void:
	s.global_ai_left=0
	s.flak_poll=0
	w.AlliedFirst.tick(w,0.01)

static func troops(w) -> Array:
	return w.units.filter(func(u):return w.actor_alive(u) and u.unit_id=="FLAKT" and u.special.has("all01_flak_job"))

static func produce(b,n: int) -> void:
	for i in n:
		b._tick_unit_queues(100.0)

static func exercise(test,w,kind: String) -> void:
	var s: Dictionary=w.allied_state.allied_first
	var rows: Array=w.AlliedFirst.GlobalAI.TABLE.data.rows
	var row: Dictionary=rows.filter(func(r):return r.get("threat","")==kind).front()
	var origin := Vector2(22.5,104.5)*55
	var airfield: Vector2=w.AlliedFirst.wp(14)
	var at: Vector2=w.NativeMaps.find_base_site(w,origin,"NAHAND")
	var barracks=w._place_building("NAHAND","enemy",at,true)
	barracks._process(20.0)
	barracks.special.allied_first_room="Confederation"
	var gun_at: Vector2=w.NativeMaps.find_base_site(w,at+Vector2(210,0),"NAFLAK")
	var gun=w._place_building("NAFLAK","enemy",gun_at,true)
	gun._process(20.0)
	gun.special.allied_first_room="Confederation"
	w._refresh_pathing()
	var enemy_count: int=w.units.filter(func(u):return w.actor_alive(u) and u.side=="ally" and u.unit_id==kind and u.special.get("allied_first_room","Americans")=="Americans").size()
	test.expect(enemy_count<int(row.minimum),"原始出击时未达到目标机型门槛")
	for i in range(enemy_count,int(row.minimum)-1): w.spawn_unit(kind,"ally",airfield)
	decide(w,s)
	test.expect(barracks.production.is_empty(),"少一架不下单 "+kind)
	var last=w.spawn_unit(kind,"ally",airfield)
	last.special.allied_first_room="British"
	decide(w,s)
	test.expect(barracks.production.is_empty(),"友军房号的飞机不计入玩家威胁")
	last.special.allied_first_room="Americans"
	barracks.special.allied_first_room="Russians"
	decide(w,s)
	test.expect(barracks.production.is_empty(),"外房兵营不能替本房训练")
	barracks.special.allied_first_room="Confederation"
	decide(w,s)
	test.expect(barracks.production.is_empty(),"缺本房苏联雷达时不能训练防空步兵")
	var radar_at: Vector2=w.NativeMaps.find_base_site(w,at+Vector2(0,330),"NARADR")
	var radar=w._place_building("NARADR","enemy",radar_at,true)
	radar._process(20.0)
	radar.special.allied_first_room="Russians"
	decide(w,s)
	test.expect(barracks.production.is_empty(),"其他苏军房的雷达不能解锁本房产线")
	radar.special.allied_first_room="Confederation"
	decide(w,s)
	if int(s.retail_dominator.difficulty)==0:
		test.expect(barracks.production.is_empty() and s.get("flak_jobs",{}).is_empty(),"简单难度在门槛成立时仍禁用")
		return
	test.expect(barracks.production==["FLAKT"] and barracks.special.get("all01_ai_order","")==row.id,"原版阈值由相应 ID 启动真实兵营队列 "+kind)
	if barracks.production.is_empty():
		print("FLAK_QUEUE ",barracks.queue_block_reason("FLAKT"))
		return
	var before: float=w.funds_for("enemy")
	produce(barracks,2)
	barracks._tick_unit_queues(0.25)
	test.expect(troops(w).size()==2 and w.funds_for("enemy")<before and barracks.production==["FLAKT"],"已扣费交付两人，第三人继续训练")
	if "--save-flak" in OS.get_cmdline_user_args():
		test.expect(BattleSaves.save_slot(w,"slot2").ok,"保存两人出厂、第三人在产断点")
	await finish_team(test,w,barracks)
	if "--flak-limit" in OS.get_cmdline_user_args(): cap_and_cancel(test,w,s,barracks,kind)

static func resume(test,w) -> void:
	var s: Dictionary=w.allied_state.allied_first
	var makers: Array=w.buildings.filter(func(b):return w.actor_alive(b) and b.special.has("all01_flak_job"))
	test.expect(s.retail_dominator.fired.has("0b8a090c") and s.confederation_production,"冷读保留生产触发器和本房权限")
	test.expect(makers.size()==1 and troops(w).size()==2,"冷读只恢复一个在产编组与两名已出厂成员")
	if makers.size()!=1:return
	test.expect(makers[0].production==["FLAKT"] and makers[0].total_production_paid()>0,"第三人的队列及付费进度保留")
	await finish_team(test,w,makers[0])

static func finish_team(test,w,b) -> void:
	var s: Dictionary=w.allied_state.allied_first
	produce(b,4)
	var units:=troops(w)
	test.expect(units.size()==6 and b.production.is_empty() and not b.special.has("all01_ai_order"),"六名防空步兵编组完成并释放兵营")
	if units.size()!=6:return
	var job: Dictionary=s.flak_jobs[units[0].special.all01_flak_job]
	var gun=w.AlliedFirst.GlobalAI.Flak.site(w,"NAFLAK",units[0].position)
	s.global_ai_left=9999
	w.AlliedFirst.GlobalAI.tick(w,s,0.3)
	test.expect(job.phase=="rally" and units.all(func(u):return u.has_move_order and u.move_target.distance_to(gun.position)<210),"六人收到前往本房防空炮的实际移动命令")
	# Isolate this detachment's movement and weapon from the other battle formations.
	for other in w.units:
		if w.actor_alive(other) and not units.has(other): other.set_physics_process(false)
	for other in w.buildings:
		if w.actor_alive(other): other.set_process(false)
	var start: Vector2=units[0].position
	for i in 960:
		await w.get_tree().physics_frame
		w.AlliedFirst.GlobalAI.tick(w,s,1.0/60)
		if job.phase=="guard":break
	if not units.all(func(u):return w.actor_alive(u)):
		test.expect(false,"完成编队动作前仍有六人存活")
		return
	test.expect(units[0].position.distance_to(start)>12,"防空步兵在正式战场实际移动")
	test.expect(job.phase=="guard" and units.all(func(u):return not u.hold_position and u.special.has("campaign_area_guard")),"集结并分散后进入区域警戒")
	if job.phase!="guard":print("FLAK_PHASE ",job.phase," ",units.map(func(u):return [u.position.distance_to(gun.position),u.has_move_order]))
	if job.phase!="guard":return
	var target=w.spawn_unit("ZEP","ally",units[0].position+Vector2(80,0))
	target.set_physics_process(false)
	w.fog.rebuild()
	var hp: float=target.hp
	for i in 240:
		if not w.actor_alive(target) or target.hp<hp:break
		await w.get_tree().physics_frame
	test.expect(not w.actor_alive(target) or target.hp<hp,"区域警戒的防空队自动对空交火并造成伤害")

static func cap_and_cancel(test,w,s,b,kind: String) -> void:
	var other_kind := "BEAG" if kind=="ORCA" else "ORCA"
	for u in w.units:
		if w.actor_alive(u) and u.side=="ally" and u.unit_id in [kind,"ZEP"]: u.special.allied_first_room="British"
	for i in (5 if other_kind=="BEAG" else 6): w.spawn_unit(other_kind,"ally",w.AlliedFirst.wp(14))
	decide(w,s)
	var second_id: String="0ca2b06c-g" if other_kind=="BEAG" else "0ca2a04c-g"
	test.expect(s.flak_jobs.size()==2 and b.special.get("all01_ai_order","")==second_id,"另一威胁 ID 可用同一队种的第二个名额")
	var at: Vector2=w.NativeMaps.find_base_site(w,b.position+Vector2(360,0),"NAHAND")
	var spare=w._place_building("NAHAND","enemy",at,true)
	spare._process(20.0)
	spare.special.allied_first_room="Confederation"
	decide(w,s)
	test.expect(spare.production.is_empty() and s.flak_jobs.size()==2,"两个 ID 已占满同一 TeamType，空闲兵营不能开第三队")
	if b.production.has("FLAKT"):
		b._tick_unit_queues(0.25)
		w.AlliedFirst.Orders.change_side(b,"ally")
	test.expect(b.production.is_empty() and not b.special.has("all01_flak_job"),"兵营被占后普通队列取消并释放原房订单")
	decide(w,s)
	test.expect(s.flak_jobs.size()==2 and spare.production==["FLAKT"] and spare.special.get("all01_ai_order","")==second_id,"重新决策清理作废编组，剩余本房兵营可接替")
