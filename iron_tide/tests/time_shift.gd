extends Node

var failures := 0
func check(value:bool,label:String) -> void:
	print("SOV01 ",value," ",label)
	if not value:failures+=1

func _ready() -> void:
	call_deferred("run")

func engineer_planes(w) -> Array:
	return w.units.filter(func(u):return w.actor_alive(u) and u.side=="ally" and u.special.get("para_infantry")=="SENGINEER")

func engineers(w) -> Array:
	return w.units.filter(func(u):return w.actor_alive(u) and u.side=="ally" and u.unit_id=="SENGINEER")

func original_grid(w) -> Dictionary:
	var plants:Dictionary={}
	for b in w.buildings:
		if w.actor_alive(b) and b.building_id in w.TimeShift.POWER_PLANTS and b.special.get("time_shift_tag")=="Detect_Power Attacked":
			plants[b.building_id]=b
	return plants

func grid_return(w,s:Dictionary) -> void:
	var film=w.get_node_or_null("HollywoodFilm")
	if film!=null and not film.is_queued_for_deletion():film.finish()
	w.TimeShift.begin_crossing(w,s,2)
	w.TimeShift.advance_crossing(w,s,2.8)
	check(s.phase==4 and is_equal_approx(float(s.s01_grid_transfer_left),6.2),"返城旋涡结束，8+1秒的原链尚余6.2秒")

func check_grid_transfer(w,s:Dictionary,expected:int) -> void:
	var plants:=original_grid(w)
	check(plants.size()==expected and (expected==6 or not plants.has("GAPOWRF")),"只恢复实际存活的原厂")
	if plants.size()!=expected:return
	var first=plants.GAPOWRA
	check(first.side=="ally" and is_equal_approx(first.hp,first.max_hp*0.5),"返城转属前保留玩家归属和受损血量")
	var decoy=w.TimeShift.place(w,"GAPOWRA","ally",w.TimeShift.wp(71)+Vector2(400,90))
	w.TimeShift.tick(w,float(s.s01_grid_transfer_left)-0.05)
	check(first.side=="ally" and s.has("s01_grid_transfer_left"),"到期前未转属")
	w.TimeShift.tick(w,0.06)
	check(not s.has("s01_grid_transfer_left") and decoy.side=="ally","完成后撤销计时，玩家另建同型电厂不动")
	for id in plants:
		var plant=plants[id]
		check(plant.side=="enemy" and plant.special.get("time_shift_native_house")=="Americans" and not plant.special.has("s01_grid_transfer_target"),"原厂只转给 Americans "+id)

func run() -> void:
	var tree:=get_tree()
	reparent(tree.root)
	var args := OS.get_cmdline_user_args()
	if "--cold-grid-archive" in args or "--cold-grid-before" in args or "--cold-grid-after" in args:
		var archive:bool="--cold-grid-archive" in args
		var finished:bool="--cold-grid-after" in args
		var restored:=BattleSaves.load_into_scene("slot1" if archive else "slot3" if finished else "slot2")
		check(restored.ok,"独立进程读回原厂断点")
		if restored.ok:
			await tree.scene_changed
			var battle=tree.current_scene.battle
			var state:Dictionary=battle.allied_state.time_shift
			if battle.paused:battle.hud._toggle_pause()
			if archive:
				check(state.phase==3 and state.s01_grid_archive.size()==5 and original_grid(battle).is_empty(),"侏罗纪冷读只有五份原厂记录，场上无电厂")
				grid_return(battle,state)
			if archive:check_grid_transfer(battle,state,5)
			elif not finished:
				var before:=original_grid(battle)
				before.GAPOWRE.receive_hit(100000)
				check(not battle.actor_alive(before.GAPOWRE),"转属前再次摧毁 E 厂")
				check_grid_transfer(battle,state,4)
				check(not original_grid(battle).has("GAPOWRE"),"到期也不重建 E 厂")
			else:
				var plants:=original_grid(battle)
				check(plants.size()==5 and not plants.has("GAPOWRF") and not state.has("s01_grid_transfer_left"),"转属后冷读无重建、无待发动作")
				AlliedAbilities.change_side(plants.GAPOWRA,"ally")
				battle.TimeShift.tick(battle,12.0)
				check(plants.GAPOWRA.side=="ally","重新占领后不会再被旧触发器转走")
		tree.quit(failures);return
	if "--cold-dog-orders" in args:
		var restored:=BattleSaves.load_into_scene("slot1")
		check(restored.ok,"独立进程冷读首只警犬出厂存档")
		if restored.ok:
			await tree.scene_changed
			var battle=tree.current_scene.battle
			var ai=battle.ShiftEconomy
			var mission:Dictionary=battle.allied_state.time_shift
			var group:Dictionary=mission.global_ai.groups[0]
			var cost:float=battle.production_price(GameData.get_unit("DOG"),"enemy")
			var account:String=ai.ACCOUNT_PREFIX+"Americans"
			print("S01_COLD_DOG ",group.rule," members=",group.units.size()," wanted=",group.wanted," balance=%.12f cost=%.12f"%[battle.funds_for(account),cost])
			check(group.rule=="0cdf8edc-g" and group.units.size()==1 and group.wanted==["DOG"] and is_equal_approx(battle.funds_for(account),cost),"冷读保留原ID、首只警犬和余款")
			ai.tick(battle,mission,0.4)
			var producer=group.get("factory")
			check(battle.actor_alive(producer) and producer.production==["DOG"],"冷读只续训第二只")
			if failures==0:
				for frame in range(2400):
					producer._tick_unit_queue(1.0/60.0,"DOG")
					if producer.production.is_empty():break
				ai.tick(battle,mission,0.4)
				ai.tick(battle,mission,126.0)
				check(group.units.size()==2 and mission.global_ai.groups.is_empty() and producer.production.is_empty() and is_zero_approx(battle.funds_for(account)),"读档后齐员出勤，原房无重复编队或扣费")
		tree.quit(failures);return
	if "--cold-room-economy" in args:
		var restored:=BattleSaves.load_into_scene("slot3")
		check(restored.ok,"独立进程冷读原房账户")
		if restored.ok:
			await tree.scene_changed
			var battle=tree.current_scene.battle
			check(is_zero_approx(battle.funds_for("s01_house/YuriCountry")) and battle.funds_for("s01_house/Arabs")==17.0,"冷读保留已扣空账户和另一房余额")
			battle.ShiftEconomy.initialize_accounts(battle)
			check(is_zero_approx(battle.funds_for("s01_house/YuriCountry")),"恢复后不重发开局资金")
		tree.quit(failures);return
	if "--cold-batch20" in args:
		var restored:=BattleSaves.load_into_scene("slot2")
		check(restored.ok,"独立进程读取运输失败倒计时")
		if restored.ok:
			await tree.scene_changed
			var battle=tree.current_scene.battle
			var state:Dictionary=battle.allied_state.time_shift
			check(float(state.get("loss_left",0.0))>14.0 and not state.get("s01_boat_loss_armed",true),"冷读保留倒计时和已触发状态")
			battle.TimeShift.finish_loss(battle,state,15.1)
			check(battle.ended,"读档后倒计时继续结算")
		tree.quit(failures);return
	if "--cold-golden-gate" in args:
		var result:=BattleSaves.load_into_scene("slot1")
		check(result.ok,"独立进程读取金门大桥坍塌断点")
		if result.ok:
			await tree.scene_changed
			var world=tree.current_scene.battle
			var state:Dictionary=world.allied_state.time_shift
			check(world.paused and state.phase==4 and state.get("bridge_fallen",false),"冷读保留返回时代及连锁坍塌状态")
			check(not world_bridge_ids(world).any(func(id):return id in world.TimeShift.Story.BRIDGE.slice(2)),"坍塌桥段没有从地图原件复活")
		tree.quit(failures);return
	if "--cold-naval-objective" in args:
		var result:=BattleSaves.load_into_scene("slot3")
		check(result.ok,"冷读岸防完成待播存档")
		if result.ok:
			await tree.scene_changed
			var world=tree.current_scene.battle
			var state:Dictionary=world.allied_state.time_shift
			var pings:Array=[]
			Events.battle_message.connect(func(text:String,_color:Color):if text=="任务目标一已完成。":pings.append(text))
			check(state.has("naval_objective_due") and world.paused,"待播计时随存档恢复")
			world.hud._toggle_pause()
			world.TimeShift.tick(world,0.4)
			check(pings.is_empty(),"冷读后未到一秒不提前提示")
			world.TimeShift.tick(world,0.7)
			world.TimeShift.tick(world,1.0)
			check(pings.size()==1 and not state.has("naval_objective_due"),"冷读后到点只报一次")
		tree.quit(failures);return
	if "--cold-fleet-disarmed" in args:
		var result:=BattleSaves.load_into_scene("slot2")
		check(result.ok,"冷进程读取岸防已清断点")
		if result.ok:
			await tree.scene_changed
			var world=tree.current_scene.battle
			var state:Dictionary=world.allied_state.time_shift
			check(world.paused and state.phase==1 and state.fleet_disarmed and not state.has("fleet_due"),"读档恢复补援停用")
			var pings:Array[Vector2]=[]
			Events.radar_ping.connect(func(pos:Vector2,kind:String):if kind=="campaign_discovery":pings.append(pos))
			check(not state.fleet_notices.has("2") and state.fleet_notices.has("0") and state.fleet_notices.has("1"),"读档区分已发和待发通知")
			world.hud._toggle_pause()
			world.TimeShift.tick(world,20.0)
			check(pings==[world.TimeShift.wp(14),world.TimeShift.wp(25),world.TimeShift.wp(24),world.TimeShift.wp(23)],"冷读后待发通知各一次，已发乌贼和海蝎不重发")
			world.TimeShift.tick(world,20.0)
			check(pings.size()==4 and state.fleet_notices.is_empty() and not state.has("fleet_due"),"多次推进仍不再派补援或重复报点")
		tree.quit(failures);return
	if "--cold-fleet-reinforcements" in args:
		var result:=BattleSaves.load_into_scene("slot1")
		check(result.ok,"冷进程读取海战补援断点")
		if result.ok:
			await tree.scene_changed
			var world=tree.current_scene.battle
			var state:Dictionary=world.allied_state.time_shift
			var slot_count:=func(slot:int):return world.units.filter(func(u):return world.actor_alive(u) and int(u.special.get("time_shift_fleet_slot",-1))==slot).size()
			check(world.paused and state.phase==0 and state.fleet_due.has("0") and slot_count.call(14)==0,"暂停恢复无畏舰待补状态")
			check(slot_count.call(25)==1 and state.fleet_notices.has("1"),"已入场潜艇与待播提示独立恢复")
			world.hud._toggle_pause()
			world.TimeShift.tick(world,1.0)
			world.TimeShift.tick(world,1.0)
			check(slot_count.call(14)==1 and slot_count.call(25)==1 and not state.fleet_due.has("0"),"恢复后无畏舰只补一次，潜艇不重发")
		tree.quit(failures)
		return
	if "--cold-engineer-drop" in args:
		var pending := "--pending" in args
		var loaded := BattleSaves.load_into_scene("slot1" if pending else "slot2")
		check(loaded.ok,"独立进程读取工程师空投存档")
		if loaded.ok:
			await tree.scene_changed
			var world = tree.current_scene.battle
			var state: Dictionary = world.allied_state.time_shift
			check(world.paused and state.phase==2,"恢复到供电阶段暂停画面")
			world.hud._toggle_pause()
			if pending:
				check(not state.engineer_initial_sent and engineer_planes(world).is_empty(),"首批倒计时尚未结束")
				world.TimeShift.tick(world,2)
				check(engineer_planes(world).size()==1 and engineer_planes(world)[0].special.para_left==10,"继续后只派一架首批飞机")
			else:
				check(state.engineer_initial_sent and engineer_planes(world).size()==1 and engineer_planes(world)[0].special.para_left==10 and engineer_planes(world)[0].special.para_target==world.TimeShift.wp(114),"恢复在途飞机、航点和十人载荷")
				for i in 30:world.TimeShift.tick(world,0.4)
				check(engineer_planes(world).size()==1 and engineers(world).is_empty(),"恢复后飞机未到时不重复发机")
		tree.quit(failures)
		return
	if "--cold-grid-full" in args:
		var result:=BattleSaves.load_into_scene("auto")
		check(result.ok,"独立进程读取首次满电断点")
		if result.ok:
			await tree.scene_changed
			var world=get_tree().current_scene.battle
			var st:Dictionary=world.allied_state.time_shift
			var m=world.TimeShift
			check(st.has("grid_full_at") and st.get("grid_full_audio",false) and not st.get("grid_full_message",false),"恢复已播语音与未到的完成提示")
			world.hud._toggle_pause()
			m.tick(world,5.1)
			check(st.get("grid_full_message",false) and not st.has("crossing_era"),"读档后正常进入目标完成时点")
			m.tick(world,3.1)
			check(st.has("crossing_era") and not st.has("engineer_hint_due"),"后续穿越且清除旧提示")
		tree.quit(failures);return
	if "--cold-crossings" in args:
		var i := int(args[args.find("--cold-crossings") + 1])
		var result := BattleSaves.load_into_scene("slot%d" % (i + 1) if i < 3 else "auto")
		check(result.ok, "从磁盘加载旋涡断点 %d" % i)
		if not result.ok:
			tree.quit(failures)
			return
		await tree.scene_changed
		var world = tree.current_scene.battle
		var state: Dictionary = world.allied_state.time_shift
		var era := 1 + int(i >= 2)
		var after := i % 2 == 1
		var phase := era + (2 if after else 1)
		var overlay: Node = world.get_node_or_null("TimeVortex")
		var elapsed := 1.5 if after else 0.7
		check(world.paused and state.phase == phase and is_equal_approx(state.crossing_time, elapsed), "暂停读档保留阶段和计时 %d" % i)
		check(overlay != null and is_equal_approx(overlay.get_child(0).material.get_shader_parameter("progress"), elapsed / world.TimeShift.CROSSING_DURATION), "暂停画面复原旋涡进度 %d" % i)
		var area: Rect2i = Rect2i(4,29,52,67) if phase == 2 else world.TimeShift.BOUNDS[phase - 2]
		check(world.path_service.time_shift_area == area and not world.has_node("HollywoodFilm"), "阶段边界一致且未提前播放简报 %d" % i)
		world.hud._toggle_pause()
		world.TimeShift.advance_crossing(world, state, 2.2)
		check(state.phase == era + 2 and not state.has("crossing_era") and world.has_node("HollywoodFilm"), "继续后完成切换并播放简报 %d" % i)
		if after and era == 2:
			check(state.dominator.hp == state.dominator.max_hp * 0.5, "过半后的目标建筑伤害未被重复切换抹掉")
		tree.quit(failures)
		return
	if "--cold" in args:
		var loaded:=BattleSaves.load_into_scene("quick")
		check(loaded.ok,"冷进程从磁盘读取第一关 "+str(loaded.get("message","")))
		if loaded.ok:
			await tree.scene_changed
			var restored=tree.current_scene.battle
			check(restored.allied_state.time_shift.phase==3 and restored.actor_alive(restored.allied_state.time_shift.machine),"冷读档保留时代和时光机")
			check(restored.path_service.time_shift_area==restored.TimeShift.BOUNDS[1] and not restored.has_node("HollywoodFilm"),"读档恢复区域且不重播开场")
		tree.quit(failures)
		return
	var menu=load("res://scenes/campaign_command.tscn").instantiate()
	tree.root.add_child(menu)
	for b in menu.find_children("*","Button",true,false):
		if b.text=="苏军战役":b.pressed.emit();break
	check(menu.mission.id=="yr_time_shift","苏军菜单第一关")
	for b in menu.find_children("*","Button",true,false):
		if b.text=="出击":b.pressed.emit();break
	await tree.scene_changed
	var w=tree.current_scene.battle
	var m=w.TimeShift
	var s:Dictionary=w.allied_state.time_shift
	if "--seed-grid-transfer" in args or "--six-grid-transfer" in args:
		var all_six:bool="--six-grid-transfer" in args
		var plants:=original_grid(w)
		check(plants.size()==6,"出击加载六座有绑定的原厂")
		if plants.size()!=6:tree.quit(failures);return
		AlliedAbilities.change_side(plants.GAPOWRA,"ally")
		plants.GAPOWRA.hp=plants.GAPOWRA.max_hp*0.5
		var film=w.get_node_or_null("HollywoodFilm")
		if film!=null:film.finish()
		s.phase=2
		if not all_six:
			plants.GAPOWRF.receive_hit(100000)
			check(not w.actor_alive(plants.GAPOWRF),"供电阶段实际摧毁 F 厂")
		m.place(w,"GAPOWRA","ally",m.wp(71)+Vector2(400,90),"Detect_Power Attacked")
		m.begin_crossing(w,s,1)
		m.advance_crossing(w,s,2.8)
		var expected:=6 if all_six else 5
		check(s.phase==3 and s.get("s01_grid_archive",{}).size()==expected and original_grid(w).is_empty(),"换场存活数正确，侏罗纪不供电")
		if not all_six:check(BattleSaves.save_slot(w,"slot1").ok,"保存侏罗纪断点")
		await tree.process_frame
		grid_return(w,s)
		if not all_six:check(BattleSaves.save_slot(w,"slot2").ok,"保存返城转属前断点")
		check_grid_transfer(w,s,expected)
		if not all_six:check(BattleSaves.save_slot(w,"slot3").ok,"保存转属后断点")
		tree.quit(failures);return
	if "--retail-batch21" in args:
		var cleanup=m.Cleanup
		s.phase=3
		var boris=w.spawn_unit("BORIS","ally",m.wp(68))
		cleanup.queue(s,"0439F14C")
		cleanup.phase_apply(w,s,"097651DC")
		check(w.actor_alive(boris) and not s.s01_cleanup_jobs.has("0439F14C"),"在世鲍里斯停用替补")
		var arab=w.spawn_unit("INIT","enemy",m.wp(68))
		arab.special.time_shift_native_house="Arabs"
		cleanup.queue_phase(s,"096879AC")
		s.elapsed+=44.9
		cleanup.phase_tick(w,s)
		check(w.actor_alive(arab),"时代清场未满45秒不执行")
		s.elapsed+=0.2
		cleanup.phase_tick(w,s)
		check(not w.actor_alive(arab) and w.actor_alive(boris),"只清指定旧房部队")
		var machine=m.place(w,"CATIME02","ally",m.wp(68))
		s.machine=machine
		cleanup.phase_apply(w,s,"0CAAF7DC")
		check(machine.special.time_shift_native_house=="Soviet2House" and machine.side=="ally","侏罗纪旧机交还房15")
		s.phase=4
		cleanup.phase_apply(w,s,"078C97EC")
		check(s.s01_phase_links.has("079BB93C"),"只排原桥后继，不新增转属对象")
		var bridge=m.place(w,"CASANF04","ally",m.wp(68))
		s.elapsed+=1.1
		cleanup.phase_tick(w,s)
		check(bridge.side=="neutral","桥附属原类型转回中立")
		cleanup.queue_phase(s,"07F2978C")
		cleanup.phase_tick(w,s)
		check(not s.get("s01_return_friendship_check",false),"原局部旗标未满足不执行")
		s.s01_opening_squid2_lost=true
		cleanup.phase_tick(w,s)
		check(s.get("s01_return_friendship_check",false),"原局部旗标满足执行一次")
		var point:Vector2=m.wp(474)
		w.fog._reveal("ally",point,55.0)
		w.fog.rebuild()
		var cell_index:int=w.fog._index(point)
		w.fog.visible_cells.ally[cell_index]=0
		check(w.fog.is_explored_at("ally",point),"原收尾点曾被揭开")
		cleanup.phase_apply(w,s,"0937687C")
		check(not w.fog.is_explored_at("ally",point),"收尾原路点重新盖上黑幕")
		tree.quit(failures);return
	if "--retail-batch20" in args:
		var film=w.get_node_or_null("HollywoodFilm")
		if film!=null:film.finish()
		var carriers:Array=w.units.filter(func(u):return w.actor_alive(u) and u.unit_id=="CARRIER")
		check(carriers.size()==2,"零售两艘预置航母")
		m.Staging.run(w,s,"0D0E418C")
		s.elapsed+=2.9
		m.Staging.tick(w,s)
		check(not s.get("s01_encounters",{}).has("094C5E4C"),"不足三秒不接管航母")
		s.elapsed+=0.2
		m.Staging.tick(w,s)
		check(carriers.size()==2 and carriers.all(func(u):return u.special.get("s01_encounter")=="094C5E4C" and u.has_move_order and u.attack_move),"两艘预置航母接到进攻移动，不另生成")
		s.phase=1
		var boris=w.spawn_unit("BORIS","ally",m.wp(61))
		m.Story.queue_media(s,"0DE581DC",0.0)
		m.Story.media_tick(w,s)
		check(s.s01_staging_jobs.has("0D17008C"),"镜头后开启鲍里斯三秒登场")
		s.elapsed+=3.1
		m.Staging.tick(w,s)
		check(boris.special.get("s01_encounter")=="0D17008C" and boris.has_move_order,"复用当前登陆鲍里斯，尝试走到原路点")
		s.phase=4
		s.s01_boat_loss_armed=true
		var boat=w.spawn_unit("SAPC","ally",m.wp(23))
		check(not m.Story.boat_loss(w,s),"有运输艇不触发专属失败")
		AlliedAbilities.consume(boat)
		var yard=m.place(w,"NACNST","ally",m.wp(61))
		check(not m.Story.boat_loss(w,s),"无运输艇但有建造厂不触发")
		yard._die(null,true)
		check(m.Story.boat_loss(w,s) and s.loss_left==15.0,"三项缺失启动原十五秒败北")
		check(BattleSaves.save_slot(w,"slot2").ok,"写入本轮失败倒计时断点")
		m.finish_loss(w,s,14.9)
		check(not w.ended,"未满十五秒不结算")
		m.finish_loss(w,s,0.2)
		check(w.ended,"时间到确实结算失败")
		tree.quit(failures);return
	if "--retail-first-machine-return" in args:
		var old=s.machine
		AlliedAbilities.change_side(old,"ally")
		s.phase=2
		s.crossing_era=1
		s.crossing_time=0.0
		m.advance_crossing(w,s,0.9)
		check(old.side=="ally" and not s.has("s01_first_machine_returned"),"原一秒前苏军仍掌握旧机")
		m.advance_crossing(w,s,0.15)
		check(old.side=="neutral" and old.special.time_shift_native_house=="Soviet2House" and s.s01_first_machine_returned,"一秒后旧机退出玩家控制并记录原房15")
		m.advance_crossing(w,s,0.5)
		check(s.phase==3 and w.actor_alive(s.machine) and s.machine.building_id=="CATIME02" and s.machine.side=="ally","换场后新时光机仍可控")
		tree.quit(failures);return
	if "--retail-landing-teams" in args:
		for spec in [["55",false,"087D15EC"],["55",true,"082B933C"],["56",true,"082B950C"]]:
			s.phase=1
			var row:Array=m.FIELD.data.landing[0 if spec[0]=="55" else 1]
			var carrier=m.landing_transport(w,row)
			var members:Array=carrier.logistics.passengers.duplicate()
			s.landing_backup={spec[0]:{"carrier":carrier,"members":members,"replacement":spec[1]}}
			m.landing_backup_tick(w,s)
			check(members.all(func(u):return not u.special.has("s01_retail_landing_team")),"仍在船上不编队 "+spec[2])
			for u in members:u.set_stowed(null)
			carrier.logistics.passengers.clear()
			var lead=members[0]
			lead.order_move(m.wp(55),false)
			m.landing_backup_tick(w,s)
			check(members.all(func(u):return u.special.get("s01_retail_landing_team")==spec[2]) and lead.has_move_order,"原编组卸空后生效且不抢玩家命令 "+spec[2])
			AlliedAbilities.consume(carrier)
			for u in members:AlliedAbilities.consume(u)
		tree.quit(failures);return
	if "--retail-inherited-houses" in args:
		var ai=w.ShiftEconomy
		var counts:Dictionary={}
		var audited:=0
		var guard:Dictionary={}
		for row in ai.DATA.data.rows:
			var fields:PackedStringArray=row.raw.split(",")
			if fields[12]=="3":continue
			audited+=1
			var matches:Array=[]
			var correct:=true
			for house in ["Americans","Arabs","Confederation"]:
				var house_side:int=1 if house=="Americans" else 2
				var tech:int={"Americans":3,"Arabs":10,"Confederation":2}[house]
				var match_room:bool=int(fields[12])==house_side and fields[2] in ["<all>",house] and int(fields[3])<=tech
				if match_room:matches.append(house)
				for level in range(3):
					if ai.executable_house(row,house,level)!=(match_room and fields[15+level]=="1"):correct=false
			var rooms:String="/".join(matches)
			counts[rooms]=int(counts.get(rooms,0))+1
			check(correct,"阵营、房科技、三档难度 "+row.id+" "+rooms)
			if row.id=="0cdf8edc-g":guard=row
			if row.id in ["0a31295c-g","0c1245ac-g","0a44f17c-g"]:
				check(ai.members_of(row.force)==["SOV_DOG","SOV_DOG"],"苏军警犬编制 "+row.id)
			if row.id in ["0cdf8edc-g","0c1246fc-g","0a44f2cc-g"]:
				check(ai.members_of(row.force)==["DOG","DOG"],"盟军警犬编制 "+row.id)
		check(ai.DATA.data.houses.Nod.side==1 and ai.DATA.data.houses.Nod.passive and not ai.executable_house(guard,"Nod",1),"Nod 的国家为盟军侧被动房，IQ 5 不进入选队")
		check(audited==120 and counts=={"":43,"Americans":29,"Arabs":30,"Arabs/Confederation":18},"120条逐ID房筛选汇总")
		var film=w.get_node_or_null("HollywoodFilm")
		if film!=null:film.finish()
		s.phase=4
		m.change_era(w,2)
		ai.initialize_accounts(w)
		var port:Vector2=m.wp(71)
		var facility=m.place(w,"GAPILE","enemy",port)
		var power=m.place(w,"GAPOWR","enemy",port+Vector2(300,0))
		var tech_lab=m.place(w,"GATECH","enemy",port+Vector2(540,0))
		for b in [facility,power,tech_lab]:b.special.time_shift_native_house="Americans"
		w._update_power()
		if not facility.buildable.has("DOG"):facility.buildable.append("DOG")
		var account:String=ai.ACCOUNT_PREFIX+"Americans"
		var dog_cost:float=w.production_price(GameData.get_unit("DOG"),"enemy")
		w.credit_side(account,dog_cost*2.0-1.0,true)
		check(not ai.eligible_candidate(w,guard,"Americans",1),"原警戒队少一元不成队")
		w.credit_side(account,1.0)
		check(ai.eligible_candidate(w,guard,"Americans",1) and not ai.eligible_candidate(w,guard,"Americans",0),"原警戒队中等难度足额候选，简单关闭")
		if failures>0:tree.quit(failures);return
		ai.tick(w,s,126.0)
		var state:Dictionary=s.global_ai
		check(state.groups.is_empty() and facility.production.is_empty() and w.funds_for(account)==dog_cost*2.0,"设施资金齐全，房未启动时正式调度无订单无扣款")
		# Select in an explicitly activated fixture, using the production selector.
		ai.select_for_house(w,state,"Americans",1)
		check(state.groups.size()==1 and state.groups[0].rule==guard.id,"隔离启动房由正式选队器选择原版警戒队")
		if failures>0:tree.quit(failures);return
		var group:Dictionary=state.groups[0]
		for i in 2:
			ai.advance(w,group)
			if not facility.production.has("DOG"):break
			for frame in range(2400):
				facility._tick_unit_queue(1.0/60.0,"DOG")
				if facility.production.is_empty():break
			if i==0:check(group.units.size()==1 and BattleSaves.save_slot(w,"slot1").ok,"首只出厂后保存进行中的原版编组")
		check(group.units.size()==2 and group.wanted.is_empty() and is_zero_approx(w.funds_for(account)),"两只盟军警犬从本房兵营出厂并扣款")
		check(ai.advance(w,group) and group.units.all(func(u):return u.unit_id=="DOG" and ai.native_house(u)=="Americans" and u.special.shift_global_script[0][0]=="58"),"原房警犬齐员接收原版驻防脚本")
		tree.quit(failures);return
	if "--retail-room-economy" in args:
		var ai=w.ShiftEconomy
		var film=w.get_node_or_null("HollywoodFilm")
		if film!=null:film.finish()
		s.phase=4
		m.change_era(w,2)
		ai.initialize_accounts(w)
		var yuri:String=ai.ACCOUNT_PREFIX+"YuriCountry"
		var arabs:String=ai.ACCOUNT_PREFIX+"Arabs"
		check(w.funds_for(yuri)==75000.0 and w.funds_for(arabs)==0.0,"原图尤里和阿拉伯房资金分账")
		check(ai.factory(w,"INIT","YuriCountry")==null,"原返城没有尤里兵营，不凭空排产")
		var active:Dictionary=ai.active_houses(w)
		var candidates:=0
		for row in ai.DATA.data.rows:
			var levels:Array=[]
			for level in range(3):
				var rooms:Array=active.keys().filter(func(h):return ai.eligible_candidate(w,row,h,level))
				levels.append(rooms)
				if not rooms.is_empty():candidates+=1
			print("S01_RETURN_AI ",row.id," ",JSON.stringify(levels))
		check(ai.DATA.data.rows.size()==165 and candidates==0,"返城开局165条原条件在三档均无满足完整门槛的候选")
		var at:Vector2=m.wp(71)
		var site=m.place(w,"YABRCK","enemy",at)
		site.special.time_shift_native_house="YuriCountry"
		var reactor=m.place(w,"YAPOWR","enemy",at+Vector2(300,0))
		reactor.special.time_shift_native_house="YuriCountry"
		w._update_power()
		site.buildable.append("INIT") # Catalog fixture only: the original map has no such production site.
		var maker=ai.factory(w,"INIT","YuriCountry")
		check(maker==site,"测试兵营加入后具备合法产线")
		if maker==null:tree.quit(failures);return
		check(w.economy_owner(maker)==yuri and not ai.production_sites(w,"Arabs").has(maker.building_id),"产线与前置不跨房")
		var cost:float=w.production_price(GameData.get_unit("INIT"),"enemy")
		var shared:float=w.enemy_funds
		w.allied_state.s01_ai_accounts[yuri]=cost-1.0
		check(not ai.can_form(w,["INIT"],false,"YuriCountry"),"本房预算差一，不进入选队")
		w.credit_side(yuri,1.0)
		check(ai.can_form(w,["INIT"],false,"YuriCountry"),"本房足额且前置正确方可排产")
		var pair:Dictionary={"force":{"0":"1,INIT"},"secondary_force":{"0":"1,INIT"},"team":{"recruiter":"no"},"secondary":{"recruiter":"no"}}
		check(not ai.can_form_pair(w,pair,"YuriCountry"),"只够一队不能承诺两队")
		w.credit_side(yuri,cost,true)
		check(ai.can_form_pair(w,pair,"YuriCountry"),"两队足额才接受副队")
		w.spend_side(yuri,cost)
		var reserve=w.spawn_unit("INIT","enemy",at+Vector2(170,100))
		reserve.special.time_shift_native_house="YuriCountry"
		reserve.order_guard()
		pair.team.recruiter="yes"
		pair.secondary.recruiter="yes"
		w.spend_side(yuri,cost)
		check(not ai.can_form_pair(w,pair,"YuriCountry"),"两队不能重复计入同一名可招募新兵")
		AlliedAbilities.consume(reserve)
		w.credit_side(yuri,cost,true)
		ai.start_group(s.get_or_add("global_ai",{}),{"0":"1,INIT"},{"recruiter":"no"},{"0":"11,0"},"YuriCountry","fixture")
		var group:Dictionary=s.global_ai.groups[0]
		ai.advance(w,group)
		check(maker.production.has("INIT") and w.funds_for(yuri)==cost,"正式组队排入兵营，不预扣整队")
		var stray=w.spawn_unit("INIT","enemy",at+Vector2(170,100),maker)
		check(group.wanted.size()==1 and group.units.is_empty() and maker.special.has("shift_global_order"),"同工厂非排产生成不抢生产归属")
		AlliedAbilities.consume(stray)
		maker.cancel_at(0)
		ai.advance(w,group)
		check(group.get("factory")==maker and maker.production.size()==1 and maker.special.shift_global_order.id==group.id,"取消后重新排产，只保留有效票据")
		for _step in range(1800):
			maker._tick_unit_queue(1.0/60.0,"INIT")
			if group.wanted.is_empty():break
		check(group.wanted.is_empty() and group.units.size()==1 and ai.native_house(group.units[0])=="YuriCountry","固定步长扣款后实际出厂并交回原房小队")
		check(is_zero_approx(w.funds_for(yuri)) and w.funds_for(arabs)==0.0 and w.enemy_funds==shared,"仅扣尤里房余额，公共敌方与其它房不变")
		w.credit_side(arabs,17.0,true)
		check(BattleSaves.save_slot(w,"slot3").ok,"实际写盘分房账户")
		tree.quit(failures);return
	if "--retail-pcv" in args:
		var ai=preload("res://scripts/world/time_shift_global_ai.gd")
		var row:Dictionary=ai.DATA.data.rows.filter(func(r):return r.id=="043f521c-g")[0]
		check(ai.script_ready(row.script) and ai.executable_house(row,"YuriCountry",2) and not ai.executable_house(row,"YuriCountry",1),"困难专属 PCV 队原脚本可进入")
		var pcv=w.spawn_unit("PCV","enemy",m.wp(61))
		var point:Vector2=pcv.position
		if not w.construction_deploy_check(pcv).ok:point=ai.deploy_site(w,pcv)
		check(point.is_finite(),"可找到合法展开位置")
		if point.is_finite():
			pcv.position=point
			pcv.special.shift_global_house="YuriCountry"
			pcv.special.shift_global_script=[[54,0],[9,0],[49,0]]
			pcv.special.shift_global_step=1
			ai.command_tick(w)
			check(not w.actor_alive(pcv) and w.buildings.any(func(b):return w.actor_alive(b) and b.building_id=="YACNST" and ai.native_house(b)=="YuriCountry"),"执行展开后生成原房建造厂")
			check(not ai.condition_met(w,"YuriCountry",row),"已有建造厂关闭恢复条件")
		tree.quit(failures);return
	if "--retail-power-alarm" in args:
		var notices:Array=[]
		Events.battle_message.connect(func(text:String,_color:Color):if text.contains("心灵控制器已启动"):notices.append(text))
		var row:Dictionary=m.Story.FLEET.powerAlarm
		m.Story.dominator_power_alarm(w,s,3)
		check(notices.is_empty(),"少一座任务电厂不播满电警报")
		s.s01_closed_triggers={row.id:true}
		m.Story.dominator_power_alarm(w,s,4)
		check(notices.is_empty(),"已被零售后继停用则不播")
		s.s01_closed_triggers.clear()
		Ra2Sfx.stop_eva()
		var plays:=Ra2Sfx.a_plays
		m.Story.dominator_power_alarm(w,s,4)
		check(notices.size()==1 and Ra2Sfx.a_plays==plays+1,"满电播放原警笛和中文提示")
		check(Ra2Sfx._eva_player.playing and Ra2Sfx._eva_player.stream.resource_path.ends_with("/csof125.wav"),"原心灵控制器警报语音")
		m.Story.dominator_power_alarm(w,s,4)
		check(notices.size()==1,"满电警报不重复播放")
		tree.quit(failures);return
	if "--retail-tech-capture" in args:
		var ai=preload("res://scripts/world/time_shift_global_ai.gd")
		var at:Vector2=m.wp(114)
		for row in ai.DATA.data.rows:
			var fields:PackedStringArray=row.raw.split(",")
			if fields[4]!="7" or fields[12]!="3":continue
			var type:String=fields[5]
			for site in w.buildings:
				if w.actor_alive(site) and site.building_id==type:AlliedAbilities.change_side(site,"ally")
			check(not ai.condition_met(w,"YuriCountry",row),"无中立目标不满足 "+row.id)
			check(ai.executable_house(row,"YuriCountry",1) and not ai.executable_house(row,"YuriCountry",0),"零售难度边界 "+row.id)
			# Retail SOV01 does not place an airport; do not add one to the mission to force coverage.
			if type=="CAAIRP":continue
			var target=m.place(w,type,"neutral",at)
			check(target!=null,"实战可以放置科技建筑 "+type)
			if target==null:continue
			check(ai.condition_met(w,"YuriCountry",row) and ai.executable_house(row,"YuriCountry",1) and not ai.executable_house(row,"YuriCountry",0),"中立与零售难度边界 "+row.id)
			var engineer=w.spawn_unit("YENGINEER","enemy",target.position+Vector2(160,0))
			engineer.special.shift_global_house="YuriCountry"
			w.fog._reveal("enemy",target.position,240.0,3.0)
			var cmd:PackedStringArray=row.script["0"].split(",")
			check(ai.find_target(w,engineer,int(cmd[0]),int(cmd[1]))==target,"按原脚本索引找中立设施 "+row.id)
			check(engineer.order_interaction("allied_engineer",target,false) and target.side=="neutral","下令不会提前转属 "+row.id)
			engineer.position=AlliedAbilities.approach(engineer,target)
			AlliedAbilities.tick_action(engineer,1.0/60.0)
			check(target.side=="enemy" and ai.native_house(target)=="YuriCountry" and not ai.condition_met(w,"YuriCountry",row),"到门后按原房转属且条件关闭 "+row.id)
			AlliedAbilities.change_side(target,"ally")
		tree.quit(failures);return
	if "--map-inventory" in args:
		var inventory=preload("res://tests/campaign_map_inventory.gd")
		inventory.capture(w,"opening")
		m.change_era(w,1)
		inventory.capture(w,"jurassic")
		m.change_era(w,2)
		var native_yuri:Array=w.buildings.filter(func(b):return w.actor_alive(b) and b.special.get("time_shift_native_house")=="YuriCountry")
		check(native_yuri.any(func(b):return b.building_id=="NANRCT") and native_yuri.all(func(b):return b._col.is_equal_approx(HouseColor.mission_color("enemy"))),"回到现代后原尤里房全部建筑使用尤里房色，含核电站及油桶")
		inventory.capture(w,"return")
		tree.quit(failures);return
	if "--media" in OS.get_cmdline_user_args():
		for file in m.ASSETS.data.voices.values():
			var stream=load("res://assets/ra2/time_shift/"+file+".wav")
			check(stream is AudioStreamWAV and stream.get_length()>0,"原版电台录音 "+file)
		for clip in m.AFTER_FILM:
			if clip=="S01_P02E":BattleClock.set_speed(3.0)
			if clip!="S01_F00E":m.scenario_film(w,clip)
			var started := Time.get_ticks_msec()
			var film=w.get_node("HollywoodFilm")
			var full:bool=clip=="S01_F00E"
			var at:float=3.5 if clip=="S01_P02E" else 6.0 if not full else 0.35
			while film.player.is_playing() and film.player.stream_position<at:await tree.process_frame
			check(film.player.is_playing() and film.clip_id==clip and not film.subtitle.text.is_empty(),"原声影片及同步字幕 "+clip)
			if clip=="S01_P02E":
				var real_time := (Time.get_ticks_msec()-started)/1000.0
				check(absf(film.player.stream_position-real_time)<0.45 and absf(film.mission_audio.get_playback_position()-real_time)<0.45,"三倍速下影片与人声按现实时间播放")
				BattleClock.set_speed(1.0)
			if not full:check(film.player.get_global_rect().get_center().x>get_viewport().get_visible_rect().size.x*0.75,"右上雷达小窗 "+clip)
			Ra2Sfx.stop_eva()
			if clip=="S01_P01E":await film.player.finished
			else:film.skip.pressed.emit()
			var first:String={"S01_F00E":"EVA_EstablishBattlefieldControl","S01_P03E":"EVA_BattlefieldControlOnline"}.get(clip,"EVA_BattlefieldControlOnline")
			var file:String=m.ASSETS.data.voices[first]
			check(Ra2Sfx._eva_player.playing and Ra2Sfx._eva_player.stream.resource_path.ends_with("/"+file+".wav"),"片尾衔接原版电台 "+file)
			await tree.process_frame
			await tree.process_frame
		tree.quit(failures)
		return
	check(w.get_node("HollywoodFilm").player.is_playing() and not w.get_node("HollywoodFilm").subtitle.text.is_empty(),"战前简报播放")
	w.get_node("HollywoodFilm").skip.pressed.emit()
	await tree.process_frame
	if "--hospital-feature" in args:
		var hospital=w.buildings.filter(func(b):return b.building_id=="CATHOSP")[0]
		m.bounds(w,0,true)
		var troop=w.spawn_unit("E2","ally",w.player_start())
		var tank=w.spawn_unit("HTNK","ally",w.player_start())
		troop.hp=40.0;tank.hp=40.0
		hospital._process(10.0)
		check(troop.hp==40.0,"未占领医院不治疗玩家步兵")
		var engineer=w.spawn_unit("SENGINEER","ally",hospital.position+Vector2(160,0))
		w.fog._reveal("ally",hospital.position,240.0,2.0)
		check(engineer.order_interaction("allied_engineer",hospital,false),"首关医院接受工程师占领命令")
		engineer.position=AlliedAbilities.approach(engineer,hospital)
		for i in 100:
			if not w.actor_alive(engineer):break
			AlliedAbilities.tick_action(engineer,0.1)
		check(hospital.side=="ally" and hospital._col.is_equal_approx(HouseColor.mission_color("ally")),"医院转属后改用苏军房色")
		hospital._process(10.0)
		check(troop.hp>40.0 and tank.hp==40.0,"医院只治疗己方步兵，不治疗车辆")
		m.Story.facility_notice(w,s,hospital)
		check(s.has("Unit_Sofia_TechHospital") and hospital.special.has("campaign_flash_left"),"发现医院同时登记原声与设施闪烁")
		var hp:float=troop.hp
		hospital._die();hospital._process(10.0)
		check(troop.hp==hp,"医院毁坏后停止治疗")
		tree.quit(failures);return
	if "--landing-group-loss" in args:
		s.phase=1
		m.bounds(w,0,true)
		m.land(w)
		var slot:Dictionary=s.landing_backup["55"]
		var first=slot.carrier
		first.position=m.wp(55)
		first.logistics.request_unload()
		for j in 24:first.logistics.unload_one()
		m.landing_backup_tick(w,s)
		check(slot.get("done",false) and slot.members.size()==4,"首次犀牛队实卸载并保留成员关联")
		for u in slot.members:
			if w.actor_alive(u):u._die(null,true)
		m.landing_backup_tick(w,s)
		m.landing_backup_tick(w,s)
		check(slot.get("replacement",false) and s.landing_backup["56"].get("replacement",false) and w.actor_alive(first),"首批犀牛在陆上全灭、空艇还活着也同时派两组后援")
		var replacement=slot.carrier
		replacement.position=m.wp(55)
		replacement.logistics.request_unload()
		for j in 24:replacement.logistics.unload_one()
		m.landing_backup_tick(w,s)
		check(slot.get("done",false),"后援艇实际卸载完毕")
		for u in slot.members:
			if w.actor_alive(u):u._die(null,true)
		m.landing_backup_tick(w,s)
		check(slot.has("due") and slot.carrier==replacement,"后援全灭开始单组计时")
		s.elapsed=float(slot.get("due",0))
		m.landing_backup_tick(w,s)
		check(slot.carrier!=replacement,"后援全灭后只重派该组")
		tree.quit(failures);return
	if "--landing-backup" in args:
		s.phase=1
		m.bounds(w,0,true)
		m.land(w)
		var rhino:Dictionary=s.landing_backup["55"]
		var conscript:Dictionary=s.landing_backup["56"]
		check(rhino.carrier.logistics.passengers.size()==4 and conscript.carrier.logistics.passengers.size()==12,"两艘登陆艇保存各自载荷")
		rhino.carrier._die(null,true)
		conscript.carrier._die(null,true)
		s.elapsed=0.0;m.landing_backup_tick(w,s)
		s.elapsed=2.0;m.landing_backup_tick(w,s)
		check(not rhino.has("replacement") and not conscript.has("replacement"),"损失后不会立即补派")
		s.elapsed=3.0;m.landing_backup_tick(w,s)
		check(conscript.get("replacement",false) and not rhino.has("replacement"),"动员兵艇三秒先补")
		s.elapsed=9.0;m.landing_backup_tick(w,s)
		check(rhino.get("replacement",false) and rhino.carrier.has_move_order and rhino.carrier.logistics.passengers.size()==4,"犀牛艇九秒补派并驶向原滩头")
		var carrier=rhino.carrier
		carrier.position=m.wp(55)
		carrier.logistics.request_unload()
		for j in 24:carrier.logistics.unload_one()
		m.landing_backup_tick(w,s)
		check(rhino.get("done",false),"后援完成卸载后关闭该艇替补")
		carrier._die(null,true);s.elapsed=25.0;m.landing_backup_tick(w,s)
		check(not rhino.has("due"),"卸载后的空艇损失不重发")
		tree.quit(failures);return
	if "--engineer-notice-chain" in args:
		var seen:Array=[]
		Events.battle_message.connect(func(text:String,_c:Color):if text.begins_with("工程师增援") or text.begins_with("让工程师占领") or text.begins_with("任务目标：占领发电厂"):seen.append(text))
		s.engineer_arrival_due=53.0
		s.engineer_rescue_arrival_due=90.0
		for t in [52,53,72,73,89,90,104,105,106]:
			m.Story.engineer_notices(w,s,t)
			check(seen.size()==int(t>=53)+int(t>=73)+int(t>=90)+int(t>=105),"电台、占领提示与供电提醒独立计时：%d"%t)
		tree.quit(failures);return
	if "--raid-return-chain" in args:
		var matched:=0
		for row in m.FIELD.data.raids:
			var key:="%s|%s"%[row.group,int(row.route.back())]
			var lane:Dictionary=m.Story.FLEET.transportReturns.get(key,{})
			check(not lane.is_empty(),"原图卸载航线匹配："+key)
			if lane.is_empty():continue
			m.Story.raid(w,row)
			var candidates:Array=w.units.filter(func(u):return w.actor_alive(u) and u.special.get("shift_return_lane",{}).get("id")==lane.id)
			check(candidates.size()==1,"实际船只绑定卸载驱动："+str(lane.id))
			if candidates.size()!=1:continue
			var boat=candidates[0]
			boat.special.shift_return_unloading=true
			m.Story.advance_raid_return(w,boat,1.0)
			check(not boat.special.has("shift_return_step"),"仍有载员不返航："+str(lane.id))
			for rider in boat.logistics.passengers.duplicate():AlliedAbilities.consume(rider)
			boat.logistics.passengers.clear()
			m.Story.advance_raid_return(w,boat,1.0)
			if lane.flag!=lane.event_flag:
				s.erase("s01_gas_capture_unloaded")
				m.Story.advance_raid_return(w,boat,1.0)
				check(not boat.special.has("shift_return_step"),"仅卸空 Grand 不启动返航")
				s.s01_gas_capture_unloaded=true
				m.Story.advance_raid_return(w,boat,1.1)
				check(boat.special.has("shift_return_step") and s.get("s01_grand_unloaded",false),"Gas 旗标满足后启动 Grand 返航")
				m.Story.advance_raid_return(w,boat,2.2)
				check(not s.has("s01_grand_unloaded") and not boat.special.has("shift_return_reset"),"原一秒后清 Grand 旗标")
				AlliedAbilities.consume(boat);continue
			matched+=1
			check(boat.special.get("shift_return_step")==0 and boat.special.has("shift_return_reset"),"卸载后安排首段与重启计时："+str(lane.id))
			m.Story.advance_raid_return(w,boat,1.9)
			check(boat.special.has("shift_return_reset"),"重启延时未到不能清状态："+str(lane.reset))
			m.Story.advance_raid_return(w,boat,2.1)
			check(not boat.special.has("shift_return_reset"),"重启延时到清状态："+str(lane.reset))
			AlliedAbilities.consume(boat)
		check(matched==11,"十一条同旗标返航，Grand 单独核对 Gas 旗标门槛")
		tree.quit(failures);return
	if "--power-raid-chain" in args:
		var signals:Array=[]
		var at:Vector2=m.wp(496)
		Events.radar_ping.connect(func(pos:Vector2,kind:String):if pos==at and kind=="campaign_discovery":signals.append(pos))
		var level:=0 if "--easy" in args else 1
		BattleRequest.skirmish_config.difficulty=level
		for t in [4.9,5.0,64.9,65.0,67.9,68.0,82.9,83.0,98.0,158.0,173.0,188.0]:
			s.power_elapsed=t
			m.Story.power_contest(w,s)
			var expected:int=int(t>=68)+int(t>=98)+(int(t>=158)+int(t>=188) if level>0 else 0)
			check(s.get("raid_index",0)==expected and signals.size()==int(t>=83)+(int(t>=173) if level>0 else 0),"供电波次与延迟雷达 %s / 难度 %s"%[t,level])
		check(s.get("Mis_xS1_ZofiaEngineersForPower",false) and s.get("Mis_xS1_ZofiaYuriNeedsPower",false),"两条供电电台据表触发")
		tree.quit(failures);return
	if "--retail-media-chain" in args:
		var start:float=s.elapsed
		m.tick(w,4.9)
		check(not s.has("Mis_xS1_ZofiaAlcatrazIntro"),"开场语音未到五秒不播")
		m.tick(w,0.6)
		check(s.has("Mis_xS1_ZofiaAlcatrazIntro") and not s.has("Mis_xS1_ZofiaNavalAttack"),"恶魔岛先播，海战提示未到")
		m.tick(w,1.0)
		check(s.has("Mis_xS1_ZofiaNavalAttack"),"海战提示后播")
		s.phase=1;s.elapsed=start
		m.Story.queue_media(s,"0D17F50C")
		m.Story.media_tick(w,s)
		check(s.has("Mis_xS1_ZofiaBriefing01") and s.retail_media_due.has("0DD8E32C"),"登陆语音开启后继")
		s.elapsed=start+10.1
		m.Story.media_tick(w,s)
		check(s.has("Mis_xS1_ZofiaBriefing02") and s.retail_media_due.has("0DE581DC"),"第二段及镜头后继")
		var shop=w.buildings.filter(func(b):return w.actor_alive(b) and b.building_id=="CAMACH")[0]
		m.Story.facility_notice(w,s,shop)
		check(s.retail_media_due.has("05BF366C"),"盟军维修厂启用对应语音")
		s.elapsed=float(s.retail_media_due["05BF366C"].due)
		m.Story.media_tick(w,s)
		check(s.has("Unit_Sofia_TechMachShop"),"维修厂到期播报")
		m.Story.queue_media(s,"09577E1C")
		s.phase=2
		m.Story.media_tick(w,s)
		check(not s.retail_media_due.has("09577E1C"),"跨阶段撤销待播旧目标")
		tree.quit(failures);return
	if "--retail-staging" in args:
		check(s.s01_staging_jobs.has("094B2A9C") and s.s01_staging_jobs.has("0BBEFE3C"),"片尾接上零售开场镜头与飞越链")
		var fixture:Dictionary={"phase":0,"elapsed":0.0}
		m.Staging.queue(fixture,"094B2A9C")
		fixture.elapsed=4.9
		m.Staging.tick(w,fixture)
		check(fixture.s01_staging_jobs.has("094B2A9C"),"五秒前不推首个镜头")
		fixture.elapsed=5.0
		m.Staging.tick(w,fixture)
		check(fixture.s01_staging_jobs.has("094BE2BC") and is_equal_approx(fixture.s01_staging_jobs["094BE2BC"].due,40.0),"下一镜头从启用时间等35秒")
		m.Staging.run(w,fixture,"0BBEFE3C")
		check(w.units.any(func(u):return w.actor_alive(u) and u.special.has("s01_flyby")),"原图飞机实际入场")
		fixture.phase=1
		m.Staging.tick(w,fixture)
		check(fixture.s01_staging_jobs.is_empty() and not w.units.any(func(u):return w.actor_alive(u) and u.special.has("s01_flyby")),"切阶段撤销旧镜头与飞越")
		fixture.power_raid_pings=[{}]
		fixture.landing_backup={"55":{}}
		m.Staging.run(w,fixture,"0C57BA6C",false)
		m.Staging.run(w,fixture,"07FA53DC",false)
		check(not fixture.has("power_raid_pings") and not fixture.has("landing_backup"),"穿越收尾按原关闭列表清待办")
		tree.quit(failures);return
	if "--naval-reminder" in args:
		var messages:Array=[]
		Events.battle_message.connect(func(text:String,_color:Color):if text.begins_with("任务目标：消灭盟军舰队"):messages.append(text))
		check(s.naval_reminder_due-float(s.elapsed)>99.0,"接管后启动原100秒提醒")
		m.tick(w,float(s.naval_reminder_due)-float(s.elapsed)-0.5)
		check(messages.is_empty(),"未到期不提示")
		m.tick(w,1.0)
		m.tick(w,101.0)
		check(messages.size()==1 and not s.has("naval_reminder_due"),"期限到仅提醒一次")
		var ai=preload("res://scripts/world/time_shift_global_ai.gd")
		for row in ai.DATA.data.rows:
			if row.id=="0611a33c-g":
				var cmp:String=row.raw.split(",")[6]
				check(ai.compares(0,cmp) and ai.compares(1,cmp) and not ai.compares(2,cmp),"尤里矿车 AI 原条件为少于两辆")
			if row.id=="043f521c-g":
				var cmp:String=row.raw.split(",")[6]
				check(ai.compares(0,cmp) and not ai.compares(1,cmp),"尤里基地车 AI 原条件为没有建造场")
		tree.quit(failures);return
	if "--naval-objective" in args:
		var pings:Array=[]
		Events.battle_message.connect(func(text:String,_color:Color):if text=="任务目标一已完成。":pings.append(text))
		var targets:Array=(w.units+w.buildings).filter(func(u):return w.actor_alive(u) and u.special.get("time_shift_tag")=="SP2.1_Destroy_AlliedDef")
		for i in range(1,targets.size()):targets[i].receive_hit(100000)
		m.tick(w,1.1)
		check(s.phase==0 and not s.has("naval_objective_due"),"岸防尚有目标存活则不计时")
		targets[0].receive_hit(100000)
		m.tick(w,0.5)
		check(s.phase==1 and s.naval_objective_due==1.0 and pings.is_empty() and not s.has("naval_reminder_due"),"岸防全清取消旧提醒，只安排一秒后的完成报文")
		check(BattleSaves.save_slot(w,"slot3").ok,"写入尚未播报的断点")
		Ra2Sfx.stop_eva()
		m.tick(w,0.9)
		check(pings.is_empty(),"未满一秒不推任务完成文字")
		m.tick(w,0.11)
		check(pings.size()==1 and Ra2Sfx._eva_player.playing and Ra2Sfx._eva_player.stream.resource_path.ends_with("/csof124.wav"),"满一秒真实原声和中文报文")
		m.tick(w,4.0)
		check(pings.size()==1,"推进登陆雷达片期间不重复播报")
		tree.quit(failures);return
	if "--fleet-reinforcements" in args:
		var tagged:=func(slot:int):
			return w.units.filter(func(u):return w.actor_alive(u) and int(u.special.get("time_shift_fleet_slot",-1))==slot)
		for row in m.Story.FLEET.fleet:
			var ships:Array=tagged.call(int(row.slot))
			check(ships.size()==1 and ships[0].unit_id==row.type,"开局船只唯一、型号正确：%s/%s" % [row.detect,row.slot])
		var pings:Array[Vector2]=[]
		Events.radar_ping.connect(func(pos:Vector2,kind:String):if kind=="campaign_discovery":pings.append(pos))
		tagged.call(25)[0].receive_hit(100000)
		m.tick(w,0.5)
		check(tagged.call(25).is_empty(),"只损失一艘潜艇时不补援")
		for slot in [24,23,14,19,18,17,22,21]: tagged.call(slot)[0].receive_hit(100000)
		m.tick(w,0.5)
		check([25,24,23,19,18,17,22,21].all(func(slot):return tagged.call(slot).size()==1),"三艘潜艇、三艘海蝎和两只乌贼分别成组补齐")
		check(tagged.call(20).size()==1 and tagged.call(16).size()==1,"不必失去外侧两艘海蝎才触发补援")
		check(tagged.call(14).is_empty() and s.fleet_due.has("0"),"第二艘无畏舰等待独立补援计时")
		check(BattleSaves.save_slot(w,"slot1").ok,"写盘无畏舰等待及潜艇已补断点")
		m.tick(w,1.0)
		check(tagged.call(14).size()==1 and tagged.call(15).size()==1 and tagged.call(13).size()==1,"仅补回二号无畏舰，不要求另外两舰阵亡")
		check(tagged.call(14).size()==1 and tagged.call(14)[0].has_move_order and s.fleet_notices.has("0"),"补援舰从入口接令，抵达提示走独立计时")
		for target in w.units.duplicate()+w.buildings.duplicate():
			if w.actor_alive(target) and target.special.get("time_shift_tag")=="SP2.1_Destroy_AlliedDef": target.receive_hit(100000)
		m.tick(w,1.0)
		check(s.phase==1 and s.fleet_disarmed and not s.has("fleet_due"),"岸防清除后结束海战补援阶段")
		check(w.has_node("HollywoodFilm") and not w.paused,"登陆雷达片可与补援提示并行")
		pings.clear()
		tagged.call(22)[0].receive_hit(100000)
		tagged.call(25)[0].position=m.wp(14)
		var arrivals:Array=[]
		Events.battle_message.connect(func(text:String,_color:Color):if text.ends_with("增援部队已抵达。"):arrivals.append(text))
		m.tick(w,1.01) # Independent objective-complete notice has its own timer.
		m.tick(w,1.24)
		var expected_pings:Array[Vector2]=[m.wp(22),m.wp(21),m.wp(20),m.wp(19),m.wp(18),m.wp(17),m.wp(16)]
		if pings!=expected_pings:print("FLEET_PINGS ",pings," expected ",expected_pings," elapsed ",s.elapsed," pending ",s.fleet_notices," ended ",w.ended," paused ",w.paused," loss ",s.get("loss_left"))
		check(pings==expected_pings,"过岸防后乌贼与海蝎仍按原航点报告，损失舰也不改变闪点")
		check(arrivals.size()==1,"乌贼执行一次到达电台；海蝎只报点")
		check(tagged.call(22).is_empty() and s.fleet_notices.has("1") and s.fleet_notices.has("0"),"停止补援，同时保留各自未到期的提示")
		w.get_node("HollywoodFilm").skip.pressed.emit()
		check(BattleSaves.save_slot(w,"slot2").ok,"写盘已停补援、部分通知已发断点")
		tree.quit(failures)
		return
	if "--shop-capture-color" in args:
		var shops=w.buildings.filter(func(b):return w.actor_alive(b) and b.building_id=="CAMACH")
		check(shops.size()==1,"第一关载入原图机械维修厂")
		if shops.is_empty():tree.quit(failures);return
		var shop=shops[0]
		check(shop.side=="enemy" and shop._ra2.tex.resource_path.ends_with("/shp/CAMACH.png"),"维修厂初始属盟军并使用原版蓝色贴图")
		check(shop.material!=null and shop.material.get_shader_parameter("paint_mode")==HouseColor.PaintMode.SHOP_FACADE and shop.material.get_shader_parameter("target_color").is_equal_approx(HouseColor.color_for_side("enemy","#57a8ff")),"占领前使用盟军房色材质")
		w.center_on(shop.position)
		w.fog._reveal("ally",shop.position,650)
		w.fog._sync_mask()
		var engineer=w.spawn_unit("SENGINEER","ally",shop.position+Vector2(160,120))
		check(engineer.order_interaction("allied_engineer",shop,false),"工程师下达正式占领命令")
		if engineer.special.get("action")=="allied_engineer":
			engineer.position=AlliedAbilities.approach(engineer,shop)
			AlliedAbilities.tick_action(engineer,1.0)
		check(shop.side=="ally" and not w.actor_alive(engineer),"工程师进门后转属并消耗")
		check(shop.material!=null and shop.material.get_shader_parameter("paint_mode")==HouseColor.PaintMode.SHOP_FACADE and shop.material.get_shader_parameter("target_color").is_equal_approx(HouseColor.mission_color("ally")),"占领同一步刷新维修厂苏军房色")
		tree.quit(failures)
		return
	check(w.units.filter(func(u):return u.side=="ally" and u.is_naval).size()==13,"13艘苏军舰艇")
	check(w.units.filter(func(u):return u.side=="ally").all(func(u):return w.path_service.in_naval_water(u.position)),"开场舰艇实际在水面")
	if "--alcatraz-cliff" in OS.get_cmdline_user_args():
		m.bounds(w,2)
		var perimeter:Array=w.buildings.filter(func(b):
			return w.actor_alive(b) and b.building_id=="CAFNCP" and Rect2(117,27,7,7).has_point(b.position/55.0))
		var gate:=Vector2(117.5,30.5)*55
		check(perimeter.size()==23 and perimeter.all(func(b):return b.special.get("native_wall_pitch")==55),"恶魔岛按原图加载二十三段围栏")
		check(not perimeter.any(func(b):return b.position==gate),"西侧原图缺口没有被补成围栏")
		check(w.path_service.is_blocked(Vector2(117.5,29.5)*55),"邻接栏段实际阻挡普通地面寻路")
		var coast := Vector2(123.5,40.5)*55
		var cliff := Vector2(123.5,39.5)*55
		var top := Vector2(128.5,36.5)*55
		var beach := Vector2(128.5,42.5)*55
		var hover=w.spawn_unit("SAPC","ally",coast)
		var tank=w.spawn_unit("HTNK","ally",beach)
		check(hover.is_amphibious and hover._domain_ok(coast) and not hover._domain_ok(cliff),"运输艇可航行，崖壁禁止进入")
		check(not tank._domain_ok(coast) and not tank._domain_ok(cliff),"坦克不能进入水面或崖壁")
		for v in range(36,44):
			check(hover._domain_ok(Vector2(128.5,v+.5)*55) and tank._domain_ok(Vector2(128.5,v+.5)*55),"沙滩坡道可通过 %d"%v)
		hover.position = Vector2(123.5,40.02)*55
		for i in 5:
			hover.velocity = Vector2.UP*240
			hover._move_water_safe()
		check(hover.position.y >= 40*55,"运输艇从水面顶向直崖时停在崖脚")
		w.selected_units.assign([tank])
		w._command_move(top + Vector2.UP*30)
		for frame in 900:
			await tree.physics_frame
			if tank.position.distance_to(top)<23:break
		check(tank.position.distance_to(top)<23,"坦克从沙滩沿坡道抵达高地 "+str(tank.position/55))
		w.center_on(Vector2(125.5,39.5)*55)
		if OS.has_environment("S01_CLIFF_PICTURE"):
			for frame in 6:await tree.process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(OS.get_environment("S01_CLIFF_PICTURE"))
		tree.quit(failures)
		return
	if "--fence" in OS.get_cmdline_user_args():
		m.bounds(w,0,true)
		var fence=w.wall_cells.values().filter(func(b):return b.position==Vector2(97.5,125.5)*55)[0]
		var start:Vector2=fence.position+Vector2.UP*110
		var goal:Vector2=fence.position+Vector2.DOWN*110
		var tank=w.spawn_unit("HTNK","ally",start)
		var infantry=w.spawn_unit("E2","ally",start+Vector2.LEFT*110)
		check(WallArt.supported(fence.data,fence._ra2),"围栏加载连接帧")
		check(w.movement_service(infantry).is_blocked(fence.position),"步兵受完整围栏阻挡")
		check(not w.movement_service(tank).is_blocked(fence.position),"犀牛可以规划穿过轻围栏")
		var wall=w.wall_cells.values().filter(func(b):return b.building_id=="GAWALL")[0]
		check(not WallArt.crushable_fence(wall) and w.movement_service(tank).is_blocked(wall.position),"混凝土墙仍阻挡犀牛")
		var center:Vector2=fence.position
		w.selected_units.assign([tank])
		w._command_move(goal)
		for frame in 420:
			await tree.physics_frame
			if tank.position.distance_to(goal)<25:break
		check(not w.actor_alive(fence),"行驶接触后压毁栏段")
		check(tank.position.distance_to(goal)<25,"坦克越过围栏抵达命令目标 "+str(tank.position-center))
		tree.quit(failures)
		return
	if "--outline" in OS.get_cmdline_user_args():
		w.center_on(m.wp(18))
		w.attack_target_outlines.refresh(w)
		for frame in 6:await tree.process_frame
		await RenderingServer.frame_post_draw
		for ship in w.units:
			if ship.side != "ally" or not ship.is_naval:continue
			var outline = ship.get_node_or_null("SelectionOutline")
			check(outline != null and outline.visible and outline.used > 0 and outline.get_child(0).material.get_shader_parameter("outline_color").is_equal_approx(outline.OWN_COLOR),ship.unit_id+" 舰艇黄色识别描边")
		tree.quit(failures)
		return
	if OS.has_environment("S01_SCREEN_DIR"):
		var cam:Camera2D=w.camera
		w.center_on(m.wp(18))
		for frame in 6:await tree.process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(OS.get_environment("S01_SCREEN_DIR")+"/fleet.png")
	var ids=world_bridge_ids(w)
	check(ids.size()==6 and not ids.has("CASANF10"),"原图七段金门大桥保留初始断口")
	var all_sites:=true
	for row in m.FIELD.data.sites:
		if GameData.get_building(row[0]).is_empty() or not RA2Art.has_art(row[0]):all_sites=false;break
	check(all_sites,"原图155条建筑记录均有定义及贴图")
	if OS.has_environment("S01_SCREEN_DIR"):
		await portrait(w,tree)
	var stations=w.buildings.filter(func(b):return b.building_id in m.POWER_PLANTS)
	var dread=w.units.filter(func(u):return u.unit_id=="DRED" and u.side=="ally")[0]
	check(stations.size()==6,"原图六座任务电厂")
	for station in stations:
		station.receive_hit(100000,"shell",{},dread)
		check(station.hp==5000 and station.data.unsellable and not dread._weapon_domain_valid(station),"海战中电厂免伤且排除武器锁定 "+station.building_id)
	check(s.has("Mis_xS1_ZofiaDoNotKillPower"),"误伤电厂保留索菲亚提醒")
	var targets=w.units.filter(func(u):return u.special.get("time_shift_tag")=="SP2.1_Destroy_AlliedDef")+w.buildings.filter(func(b):return b.special.get("time_shift_tag")=="SP2.1_Destroy_AlliedDef")
	check(w.hud.minimap.objective_marks().size()==7 and w.CampaignMarks.marks(w, false).size()==7,"海战战场和雷达显示七个目标")
	if OS.has_environment("S01_RADAR_PNG"):
		w.hud.minimap.queue_redraw()
		await RenderingServer.frame_post_draw
		var radar=w.hud.minimap
		var rect:=Rect2i(get_viewport().get_final_transform()*radar.get_global_transform_with_canvas()*Rect2(Vector2.ZERO,radar.size))
		get_viewport().get_texture().get_image().get_region(rect).save_png(OS.get_environment("S01_RADAR_PNG"))
	check(targets.size()==7,"七个原图岸防目标")
	for target in targets:target.receive_hit(100000)
	m.tick(w,1)
	check(s.phase==1 and w.units.filter(func(u):return u.unit_id=="SAPC").size()==4,"四艘登陆艇入场")
	stations[0].receive_hit(100000)
	check(stations[0].hp==5000,"登陆排雷阶段电厂继续免伤")
	check(w.hud.minimap.objective_marks().size()==4 and w.CampaignMarks.marks(w, false).size()==4,"登陆后两处均改标四座碉堡")
	var landing_film=w.get_node("HollywoodFilm")
	if OS.has_environment("S01_SCREEN_DIR"):
		while landing_film.player.stream_position<6 and landing_film.player.is_playing():await tree.process_frame
		await RenderingServer.frame_post_draw
		check(not landing_film.subtitle.text.is_empty(),"雷达小窗续音同步显示中文字幕")
		get_viewport().get_texture().get_image().save_png(OS.get_environment("S01_SCREEN_DIR")+"/radio.png")
	landing_film.skip.pressed.emit()
	for i in 1800:
		await tree.physics_frame
		if w.units.any(func(u):return w.actor_alive(u) and u.unit_id=="BORIS" and u.embarked_in==null):break
	check(w.units.any(func(u):return w.actor_alive(u) and u.unit_id=="BORIS" and u.embarked_in==null),"鲍里斯自行登陆")
	for b in w.buildings.duplicate():
		if w.actor_alive(b) and b.special.get("time_shift_tag")=="Destroy_Time Defenses":b.receive_hit(100000)
	m.tick(w,0.5)
	check(s.phase==1 and s.has("s01_machine_takeover_due"),"守卫清除后先启用原接管延时")
	m.tick(w,1.1)
	check(s.phase==2 and s.machine.side=="ally","摧毁守卫后接管时光机")
	if "--engineer-drop" in args:
		check(engineers(w).size()==3,"登陆队原有三名工程师")
		for u in engineers(w):AlliedAbilities.consume(u)
		m.tick(w,26)
		check(engineer_planes(w).is_empty() and engineers(w).is_empty(),"首批未到触发时间不派机")
		check(BattleSaves.save_slot(w,"slot1").ok,"保存首批等待中")
		m.tick(w,2)
		check(engineer_planes(w).size()==1 and engineer_planes(w)[0].special.para_left==10,"首批一架飞机载十人")
		if engineer_planes(w).is_empty():
			tree.quit(failures)
			return
		check(BattleSaves.save_slot(w,"slot2").ok,"保存首批飞机在途")
		for i in 30:m.tick(w,0.4)
		check(engineer_planes(w).size()==1 and engineers(w).is_empty(),"跨过三十次任务扫描仍只有一架飞机")
		var drop = preload("res://scripts/world/american_paradrop.gd")
		for i in 7200:
			var planes := engineer_planes(w)
			var falling := engineers(w).filter(func(u):return u.special.has("para_height"))
			if planes.is_empty() and falling.is_empty():break
			for plane in planes:drop.fly(plane,1.0/60.0)
			for u in falling:drop.descend(u,1.0/60.0)
			m.tick(w,1.0/60.0)
		check(engineers(w).size()==10 and engineer_planes(w).is_empty(),"逐步执行飞行和降落，十名工程师落地")
		for u in engineers(w).slice(1):AlliedAbilities.consume(u)
		for i in 12:m.tick(w,0.4)
		check(engineers(w).size()==1 and engineer_planes(w).is_empty(),"有工程师存活不补援")
		for u in engineers(w):AlliedAbilities.consume(u)
		m.tick(w,0.5)
		m.tick(w,2.5)
		check(engineer_planes(w).is_empty(),"全失后等待三秒再派援军")
		m.tick(w,0.5)
		check(engineer_planes(w).size()==1 and engineer_planes(w)[0].special.para_left==6,"补援一架飞机载六人")
		for i in 30:m.tick(w,0.4)
		check(engineer_planes(w).size()==1,"补援飞机在途不重复发机")
		if engineer_planes(w).size()==1:
			AlliedAbilities.consume(engineer_planes(w)[0])
			m.tick(w,0.5)
			m.tick(w,3)
			check(engineer_planes(w).size()==1 and engineer_planes(w)[0].special.para_left==6,"补援飞机被毁后仍能再派一架")
		tree.quit(failures)
		return
	if "--raid-orders" in args:
		var p=w.buildings.filter(func(b):return w.actor_alive(b) and b.building_id=="GAPOWRA")[0]
		AlliedAbilities.change_side(p,"ally")
		var u=w.spawn_unit("INIT","enemy",p.position+Vector2(75,0))
		u.special.shift_plant=p
		m.Story.power_contest(w,s)
		check(u.special.get("shift_assault_sent",false) and u.attack_ordered and u.attack_target==p,"已上岸突击队明确攻击玩家占领的电厂")
		check(s.get("Mis_xS1_BorisReporting",false),"鲍里斯确已下船并报到")
		tree.quit(failures);return
	if "--raid-single" in args:
		var row: Dictionary = m.FIELD.data.raids.filter(func(r): return r.group == "Reinforce_Atk Group 1" and r.route.back() == 130)[0]
		m.Story.raid(w,row)
		var boat = w.units.filter(func(u): return w.actor_alive(u) and u.unit_id == "YHVR")[0]
		for frame in 1500:
			await tree.physics_frame
			if frame % 24 == 0:
				m.Story.power_contest(w,s)
				if boat.logistics.passengers.is_empty(): break
		check(boat.logistics.passengers.is_empty(), "第三艘单独自然抵达并卸载")
		print("SOV01 SINGLE end=", boat.position / 55.0, " target=", boat.special.get("shift_raid", Vector2.INF) / 55.0, " aboard=", boat.logistics.passengers.size())
		tree.quit(failures)
		return
	stations[0].receive_hit(150)
	check(not stations[0].is_protected_mission_plant() and stations[0].hp<5000,"接管时光机后恢复受击")
	if "--raid-timing" in OS.get_cmdline_user_args():
		var boats:=func():return w.units.filter(func(u):return u.unit_id=="YHVR").size()
		check(boats.call()==0,"登陆及接管期间没有尤里气垫船")
		m.tick(w,64)
		check(boats.call()==0 and not s.has("Mis_xS1_ZofiaYuriNeedsPower"),"第64秒尚未预警")
		m.tick(w,1)
		check(boats.call()==0 and s.has("Mis_xS1_ZofiaYuriNeedsPower"),"第65秒先预警")
		m.tick(w,2)
		check(boats.call()==0,"第67秒尚未出兵")
		m.tick(w,1)
		check(boats.call()==3,"第68秒三艘新兵船出发")
		if "--raid-voyage" in args:
			s.raid_index = 4 # Isolate the first wave from the next timed wave.
			var attack_boats: Array = w.units.filter(func(u): return w.actor_alive(u) and u.unit_id == "YHVR")
			var all_landed := false
			for frame in 2100:
				await tree.physics_frame
				if frame % 30 != 0: continue
				all_landed = attack_boats.all(func(u): return w.actor_alive(u) and u.logistics.passengers.is_empty())
				if all_landed: break
			check(all_landed, "第一批三艘尤里船自然驶抵并卸空")
			var infantry_ashore: Array = w.units.filter(func(u): return w.actor_alive(u) and u.unit_id == "INIT" and u.special.has("shift_plant") and u.embarked_in == null)
			check(infantry_ashore.size() == 9, "九名尤里新兵实际在岸上")
			if not all_landed or infantry_ashore.size() != 9:
				for boat in attack_boats:
					print("SOV01 VOYAGE pos=", boat.position / 55.0, " goal=", boat.move_target / 55.0, " passengers=", boat.logistics.passengers.size())
			tree.quit(failures)
			return
		m.tick(w,30)
		check(boats.call()==6,"第98秒三艘工程师船出发")
		var raiders: Array = w.units.filter(func(u): return w.actor_alive(u) and u.unit_id in ["INIT", "YENGINEER"] and u.special.has("shift_plant"))
		check(raiders.filter(func(u): return u.unit_id == "INIT").size() == 9 and raiders.filter(func(u): return u.unit_id == "YENGINEER").size() == 3, "原图三船九名尤里新兵、三船三名工程师均已装船")
		# Isolate landing and capture from the long sea crossing; the retail shore
		# and native unload/interaction logic remain unchanged.
		for boat in w.units.filter(func(u): return w.actor_alive(u) and u.unit_id == "YHVR"):
			var shore: Vector2 = boat.special.shift_raid
			boat.order_stop()
			boat.position = shore
			boat.special.erase("shift_raid_via")
			boat.special.shift_raid = shore
			boat.reset_physics_interpolation()
		m.Story.power_contest(w, s)
		var landed_inits := false
		var landed_engineers := false
		var captured := false
		for frame in 360:
			await tree.physics_frame
			if frame % 12 != 0: continue
			landed_inits = landed_inits or raiders.any(func(u): return w.actor_alive(u) and u.unit_id == "INIT" and u.embarked_in == null)
			landed_engineers = landed_engineers or raiders.any(func(u): return w.actor_alive(u) and u.unit_id == "YENGINEER" and u.embarked_in == null)
			captured = captured or w.buildings.any(func(b): return w.actor_alive(b) and b.building_id in m.POWER_PLANTS and b.special.get("yuri_power", false))
			if landed_inits and landed_engineers and captured: break
		check(landed_inits, "尤里新兵从第一批运输艇实际登岸")
		check(landed_engineers, "尤里工程师从第二批运输艇实际登岸")
		check(captured, "尤里工程师到达电厂并登记尤里归属")
		if not (landed_inits and landed_engineers and captured):
			for boat in w.units.filter(func(u): return w.actor_alive(u) and u.unit_id == "YHVR"):
				print("SOV01 RAID_DIAG pos=", boat.position / 55.0, " target=", boat.special.get("shift_raid", Vector2.INF) / 55.0, " passengers=", boat.logistics.passengers.size(), " unloading=", boat.logistics.unloading, " move=", boat.has_move_order)
		tree.quit(failures)
		return
	if "--power-ownership" in args:
		var plant = w.buildings.filter(func(b): return w.actor_alive(b) and b.building_id == "GAPOWRA")[0]
		var first = w.spawn_unit("YENGINEER", "enemy", plant.position)
		first.special.shift_plant = plant
		first.position = AlliedAbilities.approach(first, plant)
		m.Story.power_contest(w,s)
		check(plant.special.get("yuri_power", false) and not w.actor_alive(first), "首次进门后才登记尤里归属")
		var recapture = w.spawn_unit("SENGINEER", "ally", plant.position)
		recapture.position = AlliedAbilities.approach(recapture, plant)
		w.fog.rebuild()
		recapture.order_interaction("allied_engineer", plant, false)
		AlliedAbilities.tick_action(recapture, 1.0)
		check(plant.side == "ally" and not plant.special.has("yuri_power"), "苏军夺回后清除尤里归属")
		var second = w.spawn_unit("YENGINEER", "enemy", plant.position + Vector2(0, 400))
		second.special.shift_plant = plant
		m.Story.power_contest(w,s)
		check(second.special.get("action") == "allied_engineer" and not plant.special.has("yuri_power"), "抢占命令不会抢先登记归属")
		var codec = preload("res://scripts/save/battle_snapshot.gd").new()
		var snapshot = codec.capture(w)
		check(BattleSaves.validate(snapshot).is_empty(), "占领途中可保存")
		codec.restore(w, snapshot)
		s = w.allied_state.time_shift
		w.hud._toggle_pause()
		plant = w.buildings.filter(func(b): return w.actor_alive(b) and b.building_id == "GAPOWRA")[0]
		second = w.units.filter(func(u): return w.actor_alive(u) and u.unit_id == "YENGINEER" and u.special.get("shift_plant") == plant)[0]
		check(second.special.get("target") == plant and plant.side == "ally" and not plant.special.has("yuri_power"), "读档保留待完成命令而不改变归属")
		second.position = AlliedAbilities.approach(second, plant)
		AlliedAbilities.tick_action(second, 1.0)
		check(plant.side == "enemy" and plant.special.get("yuri_power", false) and not w.actor_alive(second), "读档后实际进门才登记尤里归属")
		tree.quit(failures)
		return
	if "--grid-retail" in args:
		var plants:Array=w.buildings.filter(func(b):return w.actor_alive(b) and b.building_id in m.POWER_PLANTS)
		var grid:Dictionary=m.Story.FLEET.grid
		var warnings:Array=[]
		Events.battle_message.connect(func(text:String,_c:Color):if text.begins_with("停止攻击"):warnings.append(text))
		var actor=w.spawn_unit("E2","ally",plants[0].position)
		plants[0].receive_hit(0.0,"bullet",{},actor)
		check(warnings.is_empty(),"零伤害不触发供电警告")
		for i in 2:
			plants[0].receive_hit(1.0,"bullet",{},actor)
			s.machine.receive_hit(1.0,"bullet",{},actor)
		check(warnings.size()==2,"时光机与发电厂各自只警告一次")
		for plant in plants:
			var live:Dictionary={}
			for other in plants:
				if other!=plant:live[other.building_id]=true
			var latch:Dictionary={}
			check(not m.Story.power_losses(latch,live) and latch.grid_loss.flags.has("40"),"单独毁厂仅置首档："+plant.building_id)
			for other in plants:
				if other==plant:continue
				live.erase(other.building_id)
				check(not m.Story.power_losses(latch,live) and latch.grid_loss.flags.has("41"),"第二座不失败："+other.building_id)
				break
			live.erase(live.keys()[0])
			check(m.Story.power_losses(latch,live) and latch.grid_loss.flags.has("42"),"第三座启用失败警告")
			var warning:Dictionary={"power_elapsed":10.0}
			var owned:Dictionary={plant.building_id:true,"not_a_plant_1":true,"not_a_plant_2":true}
			m.Story.tech_power_warning(w,warning,owned)
			check(warning.get("grid_warning_due")==13.0 and warning.grid_tech_disabled.has(grid.tech[plant.building_id].id),"逐厂占领检测接入且三秒后告警："+plant.building_id)
			warning.power_elapsed=13.0
			m.Story.tech_power_warning(w,warning,owned)
			check(warning.get(grid.warning.cue,false) and not warning.has("grid_warning_due"),"告警到期只执行一次")
		tree.quit(failures);return
	if "--power-loss" in args:
		var incoming=m.FIELD.data.raids.filter(func(r):return r.group=="Reinforce_Cap Group 1")[0]
		m.Story.raid(w,incoming)
		var raiders=w.units.filter(func(u):return w.actor_alive(u) and u.unit_id=="YENGINEER" and u.special.has("shift_plant"))
		check(not raiders.is_empty() and raiders.back().embarked_in!=null,"尤里工程师乘原版运输艇争夺电厂")
		var spy=raiders.back()
		var objective=spy.special.shift_plant
		spy.embarked_in.logistics.passengers.erase(spy)
		spy.set_stowed(null)
		spy.position=AlliedAbilities.approach(spy,objective)
		m.Story.power_contest(w,s)
		check(objective.special.get("yuri_power",false),"尤里工程师进入盟军厂门转属")
		for b in w.buildings:
			if w.actor_alive(b) and b.building_id in ["GAPOWRA","GAPOWRB","GAPOWRC"]:b.receive_hit(100000)
		m.tick(w,1)
		check(not w.ended and s.get("loss_warning_left",0.0)==3.0,"剩余不足四座先启动三秒警告计时")
		m.tick(w,2.9)
		check(not s.has("loss_left"),"三秒前不启动失败结算")
		m.tick(w,0.2)
		check(not w.ended and s.has("loss_left"),"播报后进入十五秒失败收尾")
		m.tick(w,15.0)
		check(w.ended,"发电厂剩余不足四座时失败")
		tree.quit(failures)
		return
	var plants=w.buildings.filter(func(b):return w.actor_alive(b) and b.building_id.begins_with("GAPOWR") and b.building_id.length()==7)
	check(plants.size()==6,"六座可占领发电厂")
	check(w.CampaignMarks.marks(w, false).size() == 6, "供电阶段仅标仍待占领的发电厂")
	for i in 4:
		check(w.hud.minimap.objective_marks().size()==6-i,"占领后撤下电厂标记")
		var plant=plants[i]
		var engineer=w.spawn_unit("SENGINEER","ally",plant.position+Vector2(110,0))
		engineer.position=AlliedAbilities.approach(engineer,plant)
		w.fog.rebuild()
		engineer.order_interaction("allied_engineer",plant,false)
		AlliedAbilities.tick_action(engineer,1.0)
		check(plant.side=="ally","工程师占领 "+plant.building_id)
	m.tick(w,1)
	check(s.has("grid_full_at") and not s.has("crossing_era"),"首次满电先锁定分镜，不直接穿越")
	var previous_raids:int=s.get("raid_index",0)
	m.tick(w,1.0)
	check(s.get("grid_full_audio",false) and not s.get("grid_full_message",false),"满电一秒播报，暂不显示完成")
	if "--write-grid-full" in args:
		s.engineer_hint_due=float(s.power_elapsed)+30.0
		check(BattleSaves.save_slot(w,"auto").ok,"写盘满电语音后、任务完成前")
		tree.quit(failures);return
	m.tick(w,5.0)
	check(s.get("grid_full_message",false) and not s.has("crossing_era") and s.get("raid_index",0)==previous_raids,"满电六秒报目标完成，旧攻势停止")
	m.tick(w,3.1)
	check(s.has("crossing_era"),"时光机开始穿越")
	m.tick(w,0.7)
	if OS.has_environment("S01_VORTEX_PNG"):
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(OS.get_environment("S01_VORTEX_PNG"))
	check(w.has_node("TimeVortex") and s.phase==2,"原时代显示旋涡")
	check(w.hud.minimap.objective_marks().is_empty() and w.CampaignMarks.marks(w, false).is_empty(), "穿越过场清除任务标记")
	if "--write-crossings" in args: check(BattleSaves.save_slot(w,"slot1").ok,"保存第一次穿越过半前")
	m.tick(w,0.8)
	check(s.phase==3 and not w.has_node("HollywoodFilm"),"旋涡中切换时代")
	if "--write-crossings" in args: check(BattleSaves.save_slot(w,"slot2").ok,"保存第一次穿越过半后")
	m.tick(w,1.5)
	check(s.phase==3 and s.machine.building_id=="CATIME02","穿越至侏罗纪")
	if "--recharge-reminder" in args:
		w.get_node("HollywoodFilm").skip.pressed.emit()
		check(s.get("recharge_reminder_left",0.0)==80.0,"侏罗纪进入时代时从零售表登记80秒提醒")
		m.tick(w,79.9)
		check(s.has("recharge_reminder_left") and s.timer>0.0,"原提醒在计时未满时不执行")
		m.tick(w,0.2)
		check(not s.has("recharge_reminder_left") and s.timer>0.0,"计时到期仅消费一次防守提醒，仍在充能")
		m.tick(w,1.0)
		check(not s.has("recharge_reminder_left"),"后续任务推进不重挂提醒")
		tree.quit(failures);return
	if "--dino-contact" in OS.get_cmdline_user_args():
		w.get_node("HollywoodFilm").skip.pressed.emit()
		var entrances := {}
		var contacted := {}
		for frame in 4200:
			await tree.physics_frame
			if s.phase != 3: break
			for rex in w.units:
				if not w.actor_alive(rex) or rex.unit_id != "DNOA" or rex.side != "enemy": continue
				var id = rex.get_instance_id()
				if not entrances.has(id):
					entrances[id] = 69 if rex.position.distance_to(m.wp(69)) < rex.position.distance_to(m.wp(70)) else 70
				if not contacted.has(entrances[id]) and w.actor_visible_to("ally",rex) and rex.hp < rex.max_hp:
					contacted[entrances[id]] = s.timer
			if contacted.size() == 2: break
		for entrance in [69,70]:
			check(contacted.has(entrance),"入口 %s 的敌对霸王龙进入守军视野并受击，充能剩余 %s 秒" % [entrance,contacted.get(entrance,"未知")])
		tree.quit(failures)
		return
	if "--loss" in OS.get_cmdline_user_args():
		if w.has_node("HollywoodFilm"):w.get_node("HollywoodFilm").skip.pressed.emit()
		s.machine.receive_hit(100000)
		m.tick(w,1)
		check(not w.ended and s.get("loss_left",0.0)==15.0,"侏罗纪时光机毁坏后先启动失败收尾")
		m.tick(w,14.9)
		check(not w.ended,"十五秒未到不弹出失败结算")
		m.tick(w,0.2)
		check(w.ended,"侏罗纪时光机毁坏后任务失败")
		tree.quit(failures)
		return
	var codec=preload("res://scripts/save/battle_snapshot.gd").new()
	var saved:=BattleSaves.save_slot(w,"quick")
	check(saved.ok,"侏罗纪战场写入隔离测试槽 "+str(saved.get("message","")))
	var snap=codec.capture(w)
	check(BattleSaves.validate(snap)=="","跨时代存档 "+BattleSaves.validate(snap))
	if w.has_node("HollywoodFilm"):w.get_node("HollywoodFilm").skip.pressed.emit()
	await tree.process_frame
	codec.restore(w,snap)
	s=w.allied_state.time_shift
	w.hud._toggle_pause()
	check(w.hud.minimap.objective_marks()[0].position==s.machine.position and w.CampaignMarks.marks(w,false)[0].actor==s.machine,"读档后战场和雷达标记时光机")
	check(s.phase==3 and w.actor_alive(s.machine) and w.path_service.time_shift_area==m.BOUNDS[1],"恢复时光机引用及侏罗纪通行边界")
	m.tick(w,15.1) # Retail randomized first wait ranges from 5 to 15 seconds.
	check(w.units.any(func(u):return w.actor_alive(u) and u.side=="enemy" and u.unit_id=="DNOA"),"敌对霸王龙增援")
	
	m.tick(w,125)
	check(s.has("crossing_era"),"时光机开始穿越")
	m.tick(w,0.7)
	check(w.has_node("TimeVortex") and s.phase==3,"原时代显示旋涡")
	if "--write-crossings" in args: check(BattleSaves.save_slot(w,"slot3").ok,"保存第二次穿越过半前")
	m.tick(w,0.8)
	check(s.phase==4 and not w.has_node("HollywoodFilm"),"旋涡中切换时代")
	if "--write-crossings" in args:
		s.dominator.hp = s.dominator.max_hp * 0.5
		check(BattleSaves.save_slot(w,"auto").ok,"保存第二次穿越过半后及建筑伤害")
	m.tick(w,1.5)
	check(s.phase==4 and w.actor_alive(s.dominator),"返回旧金山")
	var island_fences:Array=w.buildings.filter(func(b):return w.actor_alive(b) and b.building_id=="CAFNCP" and Rect2(117,27,7,7).has_point(b.position/55.0))
	check(island_fences.size()==23 and not island_fences.any(func(b):return b.position==Vector2(117.5,30.5)*55),"实际第二次穿越后恶魔岛仍保留原图二十三段围栏和缺口")
	if w.has_node("HollywoodFilm"):w.get_node("HollywoodFilm").skip.pressed.emit()
	if OS.has_environment("S01_SCREEN_DIR"):
		w.center_on(Vector2(91.5,51.5)*55)
		w.fog.hide()
		for b in w.buildings:
			if w.actor_alive(b) and b.building_id in m.Story.BRIDGE:b.show()
		for frame in 4:await tree.process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(OS.get_environment("S01_SCREEN_DIR")+"/bridge.png")
	if "--retail-late-objective" in args:
		var late=m.Story.Late
		check(w.units.any(func(u):return w.actor_alive(u) and u.special.get("s01_return_trigger")=="0905A37C"),"返回时代正式生成原图平民组")
		for lost in [false,true]:
			for level in 3:
				var fixture:Dictionary={"phase":4,"elapsed":0.0,"boris_lost":lost}
				late.start_island_objective(fixture,level)
				if lost:
					check(fixture.s01_late_due.has("0443F8AC"),"失去鲍里斯走延迟目标支路")
					fixture.elapsed=32.0
					late.tick(w,fixture)
				var base:float=fixture.elapsed
				fixture.elapsed=base+8.9
				late.tick(w,fixture)
				check(fixture.s01_late_due.has("0443F6DC"),"未到9秒不启岛上目标")
				fixture.elapsed=base+9.1
				late.tick(w,fixture)
				check(fixture.s01_late_due.has(["07A255BC","043EC4DC","07A256AC"][level]),"原图三档难度各自启用对应目标提示")
		tree.quit(failures);return
	if "--retail-cleanup" in args:
		var c=m.Cleanup
		var state:Dictionary={"phase":4,"elapsed":0.0}
		for u in w.units.duplicate():
			if w.actor_alive(u) and u.side=="ally" and u.unit_id=="BORIS":AlliedAbilities.consume(u)
		c.queue(state,"0439F14C")
		state.elapsed=8.9
		c.tick(w,state)
		check(state.s01_cleanup_jobs.has("0439F14C"),"鲍里斯补援未满九秒")
		state.elapsed=9.0
		c.tick(w,state)
		check(w.units.any(func(u):return w.actor_alive(u) and u.side=="ally" and u.unit_id=="BORIS") and state.s01_cleanup_jobs.is_empty(),"补援生成并消费原等待")
		var carrier=w.spawn_unit("SAPC","ally",m.wp(57))
		state.s01_flak_boat=carrier
		c.apply(w,state,"079F9B1C")
		state.elapsed=13.9
		c.tick(w,state)
		check(state.s01_cleanup_jobs.has("05DB7F3C"),"空艇返航未满五秒不下令")
		state.elapsed=14.0
		c.tick(w,state)
		check(carrier.has_move_order and state.s01_cleanup_jobs.is_empty(),"原第三艘空艇实际接到返航命令")
		c.apply(w,state,"044149EC")
		check(state.s01_cleanup_jobs.has("04415AFC"),"桥毁接上撤离后续")
		state.phase=3
		c.tick(w,state)
		check(state.s01_cleanup_jobs.is_empty(),"换阶段清待办")
		tree.quit(failures);return
	if "--retail-global-rally" in args:
		var ai=preload("res://scripts/world/time_shift_global_ai.gd")
		var u=w.spawn_unit("LTNK","enemy",m.wp(71))
		var count:=0
		for row in ai.DATA.data.rows:
			if not ai.uses_rally(row):continue
			count+=1
			var commands:Array=[]
			var index:=-1
			for key in row.script:
				if not str(key).is_valid_int():continue
				var data:PackedStringArray=str(row.script[key]).split(",")
				if index<0 and int(data[0]) in [53,54]:index=commands.size()
				commands.append(data)
			if index<0:continue
			u.order_stop(false)
			u.special.erase("shift_global_move")
			u.special.shift_global_script=commands
			u.special.shift_global_step=index
			u.special.shift_global_rally=m.wp(73)
			ai.command_tick(w)
			check(int(u.special.shift_global_step)==index+1 and u.has_move_order,"零售集结动作正式下令："+row.id)
		check(count==25,"25条既有全局选队规则进入本次动作改造")
		tree.quit(failures);return
	if "--island-teams" in args:
		var patrol:Array=w.units.filter(func(u):return w.actor_alive(u) and u.special.get("shift_island_loop",false))
		var marchers:Array=w.units.filter(func(u):return w.actor_alive(u) and u.unit_id=="INIT" and u.special.has("shift_island_route"))
		check(patrol.size()==6 and marchers.size()==5,"三队狂风巡逻和五名岛上守军有航点命令")
		if not patrol.is_empty():
			var vehicle=patrol[0]
			var route:PackedVector2Array=vehicle.special.shift_island_route
			for p in route:
				vehicle.position=p
				m.Story.island_patrols(w)
			check(vehicle.special.shift_island_index==0 and vehicle.has_move_order,"巡逻走完两点后折返")
		m.Story.mixed_attack(w,s,0.0)
		check(not s.has("island_mixed_attack"),"接管基地前不启动混编反击")
		s.base_found=true
		m.Story.mixed_attack(w,s,30.0)
		var raid:Dictionary=s.island_mixed_attack
		check(raid.get("primary",[]).size()==5,"接管后首批混编反击生成")
		if not raid.get("primary",[]).is_empty():
			var attacker=raid.primary[0]
			var power=w._place_building("NAPOWR","ally",m.wp(71)+Vector2(320,0),true)
			var defense=w._place_building("NALASR","ally",m.wp(71)+Vector2(480,0),true)
			check(m.Story.mixed_target(w,attacker,-1,9)==power and m.Story.mixed_target(w,attacker,7)==defense,"两支反击分别选中电厂与防御建筑")
		var global=preload("res://scripts/world/time_shift_global_ai.gd")
		global.tick(w,s,200.0)
		check(global.DATA.data.rows.size()==165 and s.global_ai.get("groups",[]).is_empty(),"零售全局表载入，敌方无生产设施时不会凭空出兵")
		var source:Dictionary=global.DATA.data.rows.filter(func(r):return r.id=="0612b11c-g")[0]
		var staging:Dictionary={}
		global.start_group(staging,source.force,source.team,source.script)
		global.start_group(staging,source.secondary_force,source.secondary,source.secondary_script)
		check(staging.groups.size()==2 and staging.groups[0].id!=staging.groups[1].id and int(staging.groups[1].commands[0][0])==62,"零售主副队各用自己的编组和反应炉脚本")
		var available=w.spawn_unit("YTNK","enemy",m.wp(138))
		available.order_guard()
		var picking:Dictionary={}
		global.start_group(picking,{"0":"1,YTNK"},{"recruiter":"yes"},{"0":"0,9"})
		var group:Dictionary=picking.groups[0]
		var balance:float=w.funds_for("enemy")
		global.advance(w,group)
		check(group.wanted.is_empty() and group.units==[available] and w.funds_for("enemy")==balance,"招现有符合条件的坦克，不扣费不复制")
		check(not global.recruitable(w,available,"YTNK"),"已招入主队的单位不能再被副队重复使用")
		m.Story.mixed_attack(w,s,60.0)
		check(raid.follow_queue.is_empty(),"后续混编反击完成派遣")
		for u in raid.get("primary",[]):
			if w.actor_alive(u):u._die(null,true)
		m.Story.mixed_attack(w,s,0.1)
		check(not raid.has("primary") and raid.primary_left>0,"首批全灭后重新计时")
		tree.quit(failures);return
	if "--reactor-fixer" in args:
		var reactors:Array=w.buildings.filter(func(b):return w.actor_alive(b) and b.special.get("shift_reactor_repair_target",false))
		var fixers:Array=w.units.filter(func(u):return w.actor_alive(u) and u.special.get("shift_reactor_fixer",false))
		check(reactors.size()==1 and fixers.size()==1,"最终时代只登记原图指定核电站与工程师")
		if reactors.size()!=1 or fixers.size()!=1:tree.quit(failures);return
		var reactor=reactors[0]
		var fixer=fixers[0]
		check(is_equal_approx(reactor.hp,reactor.max_hp*0.5),"核电站以原图半血出现")
		m.tick(w,1.0)
		check(fixer.special.get("target")==reactor and reactor.hp<reactor.max_hp,"工程师接修理命令，未到门不修复")
		for frame in 900:
			await tree.physics_frame
			if not w.actor_alive(fixer):break
		check(not w.actor_alive(fixer) and is_equal_approx(reactor.hp,reactor.max_hp),"工程师自行走到核电站并消耗，核电站恢复满血")
		tree.quit(failures);return
	check(w.hud.minimap.objective_marks()[0].position==m.wp(104) and w.CampaignMarks.marks(w,false)[0].position==m.wp(104),"返回时两处均只标待接管基地")
	var trigger:Array=m.FIELD.data.base_contact[0]
	var scout=w.units.filter(func(u):return w.actor_alive(u) and u.side=="ally" and u.unit_id=="BORIS")[0]
	scout.position=(Vector2(trigger[0],trigger[1])+Vector2.ONE*0.5)*55
	m.tick(w,1)
	check(s.get("base_found",false) and w._player_hq()!=null,"进入原版格子接管苏军基地")
	check(w.hud.minimap.objective_marks()[0].position==s.dominator.position and w.CampaignMarks.marks(w,false)[0].actor==s.dominator,"接管后两处均改标恶魔岛目标")
	var bridge=w.buildings.filter(func(b):return w.actor_alive(b) and b.building_id=="CASANF04")[0]
	bridge.receive_hit(100000)
	m.tick(w,0.5)
	check(s.has("bridge_collapse_plan") and not s.get("bridge_fallen",false),"原桥段损坏仅启用待坍塌动作")
	m.tick(w,1.1)
	check(s.get("bridge_fallen",false) and not world_bridge_ids(w).has("CASANF14"),"金门大桥指定桥段受毁后连锁坍塌")
	if "--write-golden-gate" in args:
		check(BattleSaves.save_slot(w,"slot1").ok,"记录金门大桥坍塌后的战场")
		tree.quit(failures);return
	if "--airstrike" in OS.get_cmdline_user_args():
		var target=s.dominator
		scout.position=target.position+Vector2(130,150)
		w.fog.rebuild()
		scout.order_target(target,false,false)
		for frame in 2500:
			await tree.physics_frame
			if w.ended:break
		check(w.ended,"鲍里斯指示目标后由正式空袭摧毁控制器")
	else:
		s.dominator.receive_hit(100000)
		m.tick(w,1)
		check(not w.ended and s.get("dominator_win_left",0.0)==5.0,"摧毁控制器先进入五秒收尾")
		m.tick(w,0.9)
		check(not s.get("dominator_complete_sent",false),"一秒前不提前发目标完成文字")
		m.tick(w,0.2)
		check(s.get("dominator_complete_sent",false) and not w.ended,"目标完成文字先于胜利结算")
		m.tick(w,3.8)
		check(not w.ended,"五秒未满不结算")
		m.tick(w,0.2)
	check(w.ended,"摧毁心灵控制器结算")
	tree.quit(failures)

func world_bridge_ids(w) -> Array:
	return w.buildings.filter(func(b):return w.actor_alive(b) and b.building_id in w.TimeShift.Story.BRIDGE).map(func(b):return b.building_id)

func portrait(w,tree) -> void:
	tree.paused=true
	w.hud.hide()
	w.fog.hide()
	var originals:Array=[]
	for u in w.units+w.buildings:
		if w.actor_alive(u) and u.visible:originals.append(u);u.hide()
	var cam:Camera2D=w.camera
	var old_pos:=cam.position
	var old_zoom:=cam.zoom
	cam.position=w.TimeShift.wp(18)
	cam.zoom=Vector2(1.25,0.625)
	cam.force_update_scroll()
	var models:Array=[]
	var ids:=["COP","BUS","CBLC","CRUISE","TUG","DNOB","DNOA"]
	var points:=[Vector2(250,320),Vector2(600,320),Vector2(950,320),Vector2(1300,320),Vector2(390,640),Vector2(800,640),Vector2(1210,640)]
	var overlay:=CanvasLayer.new()
	overlay.layer=55
	add_child(overlay)
	for i in ids.size():
		var actor=w.spawn_unit(ids[i],"neutral",get_viewport().get_canvas_transform().affine_inverse()*points[i])
		actor.order_stop();actor.show();actor.hull_angle=0.1;actor.turret_angle=0.1;actor.aim_dir=Vector2.from_angle(0.1);actor.queue_redraw()
		models.append(actor)
		var label:=Label.new()
		label.text=["警车","校车","有轨电车","游轮","拖船","雷龙","霸王龙"][i]
		label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		label.position=points[i]+Vector2(-120,32)
		label.size=Vector2(240,46)
		label.add_theme_font_size_override("font_size",24)
		label.add_theme_constant_override("outline_size",5)
		overlay.add_child(label)
	for i in 5:await tree.process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_environment("S01_SCREEN_DIR")+"/city-wildlife.png")
	for actor in models:AlliedAbilities.consume(actor)
	overlay.queue_free()
	for actor in originals:
		if w.actor_alive(actor):actor.show()
	cam.position=old_pos;cam.zoom=old_zoom;cam.force_update_scroll()
	w.hud.show();w.fog.show();tree.paused=false
