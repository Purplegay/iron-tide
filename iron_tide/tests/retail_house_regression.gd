extends "res://tests/expedition_regression.gd"
const Retail = preload("res://scripts/world/retail_skirmish.gd")
const Planner = preload("res://scripts/world/retail_team_planner.gd")
const Orders = preload("res://scripts/world/retail_team_orders.gd")

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2)
		return
	MetaProgress.reset_save()
	audit()
	await live_yuri()
	await hunt_sequence()
	await check_stages()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	print("RETAIL HOUSE ",checks.size()," failed=",failed)
	get_tree().quit(0 if failed==0 else 1)

func check_stages() -> void:
	for stage in range(1,31):
		new_ready("美国",stage,"exp_fortress" if stage==30 else "exp_plain")
		check(Expedition.launch(0),"launch expedition "+str(stage))
		if instantiate_battle():
			var tasks=screen.expedition_runtime.tasks
			check(tasks.state.stage==stage and not battle.ended,"objective survives house decision "+str(stage))
		await finish()

func instantiate_battle() -> bool:
	if not super.instantiate_battle(): return false
	var ai=battle.skirmish_ai if battle.skirmish_ai else battle.house_controllers.enemy
	if ai.enemy_base!="swarm":
		ai.run_decisions(9)
		check(ai.ai_state.has(Planner.STATE),"house scheduled at expedition stage "+str(Expedition.state.stage))
		for u in battle.units:
			if battle.actor_alive(u) and (u.special.has("expedition_objective") or u.special.has("field_convoy")):
				check(not u.special.has(Planner.MEMBER),"objective keeps orders stage "+str(Expedition.state.stage))
	return true

func audit() -> void:
	var d:Dictionary=Retail.RULES.data
	var teams:={}
	var forces:={}
	var scripts:={}
	var ops:={}
	var second:=0
	for id in d.triggers:
		var row:Dictionary=d.triggers[id]
		if row.secondary!="": second+=1
		for t in [row.primary,row.secondary]:
			if t=="": continue
			teams[t]=true
			forces[d.teams[t].force]=true
			scripts[d.teams[t].script]=true
			for cmd in d.scripts[d.teams[t].script]: ops[int(cmd[0])]=true
		var facts:={"own":{},"enemy":{},"neutral":{},"credits":10000,"ready":{"ChronoSphere":1.0,"IronCurtain":1.0}}
		var qty:=int(row.threshold)
		if row.comparison==0: qty-=1
		if int(row.comparison) in [4,5]: qty+=1
		for k in ["own","enemy","neutral"]: facts[k][Planner.product(row.object)]=qty
		if row.condition==4: facts.credits=qty
		for difficulty in 3:
			check(Planner.eligible(row,row.side,row.country,difficulty,10,facts)==bool(row.skirmish and row.difficulty[difficulty]),"retail gate "+id+" difficulty "+str(difficulty))
	check([d.triggers.size(),teams.size(),forces.size(),scripts.size(),ops.size(),second]==[165,157,119,83,20,49],"complete retail reference graph",[teams.size(),forces.size(),scripts.size(),ops.size(),second])
	check(Planner.formation_product("V3ROCKET")=="V3" and Planner.product("V3ROCKET")=="V3ROCKET","bombard team recruits launchers without changing trigger object counts")
	for op in 6:
		var actual:=[]
		for value in [1,2,3]: actual.append(Planner.compare(value,2,op))
		check(actual==[[true,false,false],[true,true,false],[false,true,false],[false,true,true],[false,false,true],[true,false,true]][op],"32-byte trigger comparator "+str(op))

func live_yuri() -> void:
	BattleRequest.configure_skirmish(MatchRules.EXTENDED,{"enemy_country":"尤里","map_layout":"exp_plain","opening":"prebuilt","difficulty":5,"fog_of_war":false,"starting_funds":50000})
	screen=load("res://scenes/battle.tscn").instantiate()
	add_child(screen)
	screen.process_mode=Node.PROCESS_MODE_DISABLED
	battle=screen.battle
	var ai=battle.skirmish_ai
	for id in Retail.RULES.data.triggers:
		var trial:={"jobs":{},"weights":{},"serial":0}
		Planner.activate(ai,trial,id)
		var row:Dictionary=Retail.RULES.data.triggers[id]
		var expected:Array=[row.primary]
		if row.secondary!="" and (row.primary!=row.secondary or Retail.RULES.data.teams[row.secondary].max>1): expected.append(row.secondary)
		check(trial.jobs.values().map(func(j):return j.team)==expected,"primary and secondary assignment "+id)
		var j:Dictionary=trial.jobs.values()[0]
		Planner.outcome(trial,j,false)
		check(trial.weights[id]==clampf(row.weight+Retail.RULES.data.failure_delta,row.min,row.max),"failure weight bound "+id)
		Planner.outcome(trial,j,true)
		check(trial.weights[id]==clampf(clampf(row.weight+Retail.RULES.data.failure_delta,row.min,row.max)+Retail.RULES.data.success_delta,row.min,row.max),"success weight bound "+id)
	var bombard:={"team":"0CA1683C-G","members":[],"age":0.0}
	for spec in [["V3",3],["SHK",2],["HTK",2]]:
		for n in int(spec[1]): battle.spawn_unit(spec[0],"enemy",ai.rally+Vector2(n*9,0))
	check(Planner.recruit(ai,bombard,"bombard",Retail) and bombard.members.filter(func(u):return u.unit_id=="V3").size()==3,"Soviet Bombard Hard forms with three actual launchers")
	for u in bombard.members: Retail.release(u)
	ai._rng.seed=713
	ai.run_decisions(12)
	var s:Dictionary=ai.ai_state.get(Planner.STATE,{})
	check(not s.get("jobs",{}).is_empty(),"Yuri controller selects a real global trigger")
	if not s.get("jobs",{}).is_empty():
		var key:String=s.jobs.keys()[0]
		var j:Dictionary=s.jobs[key]
		var row:Dictionary=Retail.RULES.data.teams[j.team]
		var p:Vector2=ai.rally
		for part in Retail.RULES.data.formations[row.force]:
			for n in int(part.count): battle.spawn_unit(Planner.product(part.product),"enemy",p+Vector2(n*10,0))
		Retail.tick(ai,2)
		check(j.active and j.members.all(func(u):return u.special[Planner.MEMBER]==key),"Yuri paid-team ownership and script start",j.team)
		var snapshot=BattleSaves.Snapshot.new()
		snapshot.restore(battle,snapshot.capture(battle))
		s=battle.skirmish_ai.ai_state[Planner.STATE]
		check(s.jobs.has(key) and s.jobs[key].active and s.jobs[key].members.all(func(u):return battle.actor_alive(u) and u.special[Planner.MEMBER]==key),"Yuri live script and members survive save restore")
	check_air_priority(battle.skirmish_ai)
	await exercise_orders(battle.skirmish_ai)
	await finish()

func check_air_priority(ai) -> void:
	for id in ["YAPOWR","YAREFN","YABRCK","YAWEAP"]:
		if Retail.site(ai,id,ai.base_center)!=null: continue
		var point:Vector2=ai.Operations.build_spot(ai,id)
		if point.is_finite(): battle._place_building(id,"enemy",point,true)._buildup_play=-1
	battle._update_power()
	var line=Retail.site(ai,"YAWEAP",ai.base_center)
	check(line!=null,"operational Yuri war factory")
	if line==null:return
	line.production.clear()
	for i in 2: battle.spawn_unit("ZEP","ally",ai.rally+Vector2(i*40,0))
	check(ai.Tactics.visible_kirovs(battle,ai.house_id)>=2 and not Retail.buy_member(ai,"LTNK") and line.production.is_empty(),"visible Kirovs reserve factory for mobile AA")
	check(Retail.buy_member(ai,"YTNK") and line.production==["YTNK"],"same treasury admits paid anti-air Gatling tank")

# Exercise native script operands on actual actors while controlling positions and charge.
func job_for(op:int,members:Array,arg:int=-1) -> Dictionary:
	for team_id in Retail.RULES.data.teams:
		var script:Array=Retail.RULES.data.scripts[Retail.RULES.data.teams[team_id].script]
		for i in script.size():
			if int(script[i][0])!=op or (arg>=0 and int(script[i][1])!=arg): continue
			for u in members: u.special[Planner.MEMBER]="action"
			return {"team":team_id,"step":i,"members":members,"success":false}
	return {}

func exercise_orders(ai) -> void:
	var home:Vector2=battle.path_service.nearest_reachable(ai.rally,ai.base_center,false,8)
	var tank=battle.spawn_unit("LTNK","enemy",home)
	var victim=battle.spawn_unit("HARV","ally",home+Vector2(95,0))
	var j:=job_for(0,[tank],3)
	Orders.advance(ai,"action",j,1,Retail)
	check(j.get("target")==victim and tank.attack_target==victim,"0 attacks visible harvester")
	var unit=battle.spawn_unit("INIT","enemy",home+Vector2(8,5))
	j=job_for(5,[unit])
	Orders.advance(ai,"action",j,1,Retail)
	check(unit.special.has("campaign_area_guard") and j.has("elapsed"),"5 enters timed area guard")
	j.elapsed=200
	Orders.advance(ai,"action",j,1,Retail)
	check(not j.has("elapsed") and not unit.special.has("yr_flak_post"),"5 guard expires")
	j=job_for(6,[unit],1)
	Orders.advance(ai,"action",j,1,Retail)
	check(j.step==0,"6 jumps to first script line")
	j=job_for(11,[unit])
	check(Orders.advance(ai,"action",j,3,Retail) and unit.special.has("campaign_area_guard"),"11 holds area guard")
	Retail.release(unit)
	j=job_for(21,[unit])
	Orders.advance(ai,"action",j,1,Retail)
	check(unit.has_move_order,"21 issues scatter destination")
	j=job_for(49,[unit])
	Orders.advance(ai,"action",j,1,Retail)
	check(j.success,"49 marks trigger success")
	for op in [53,54]:
		j=job_for(op,[unit])
		Orders.advance(ai,"action",j,1,Retail)
		check(unit.has_move_order or not j.has("elapsed"),"gather "+str(op))
	var carrier=battle.spawn_unit("HTK","enemy",home)
	unit.position=home
	j=job_for(14,[carrier,unit])
	Orders.advance(ai,"action",j,1,Retail)
	check(unit.logistics.boarding==carrier,"14 reserves actual transport")
	unit.logistics.tick(0.5)
	j=job_for(43,[carrier,unit])
	var step:int=j.step
	Orders.advance(ai,"action",j,1,Retail)
	check(unit.embarked_in==carrier and j.step==step+1,"43 waits for actual boarding")
	j=job_for(8,[carrier,unit],2)
	Orders.advance(ai,"action",j,1,Retail)
	check(carrier.logistics.unloading,"8 requests unload")
	for n in 10: carrier.logistics.tick(0.5)
	Orders.advance(ai,"action",j,1,Retail)
	check(unit.embarked_in==null and not carrier.special.has(Planner.MEMBER) and unit in j.members,"8 detaches transport after passengers disembark")
	var chopper=battle.spawn_unit("SCHP","enemy",home+Vector2(155,75))
	j=job_for(9,[chopper])
	Orders.advance(ai,"action",j,1,Retail)
	check(chopper.is_deployed(),"9 siege chopper deploy order")
	for op in [61,62,63]:
		var id:String={61:"NATBNK",62:"YAPOWR",63:"NABNKR"}[op]
		var g=battle._place_building(id,"enemy",home+Vector2(380,180*(op-62)),true)
		g._buildup_play=-1
		var u=battle.spawn_unit("LTNK" if op==61 else ("INIT" if op==62 else "E2"),"enemy",g.position+Vector2(90,0))
		j=job_for(op,[u])
		Orders.advance(ai,"action",j,1,Retail)
		check(u.special.get("action")=="allied_garrison" and battle.actor_alive(u.special.get("target")),"garrison order "+str(op))
	for op in [46,47,58]:
		j=job_for(op,[tank])
		var cmd:Array=Retail.RULES.data.scripts[Retail.RULES.data.teams[j.team].script][int(j.step)]
		var id:String=Retail.RULES.data.buildings[int(cmd[1])&65535]
		var side: String="enemy" if op==58 else "ally"
		var b=battle._place_building(id,side,home+Vector2(-450,op*6-120),true)
		b._buildup_play=-1
		var t=Orders.choose(ai,j,op,int(cmd[1]))
		check(b!=null and battle.actor_alive(t) and t.side==side and t.building_id==id,"typed building operand "+str(op))
		var prior:int=j.step
		Orders.advance(ai,"action",j,1,Retail)
		if op==46: check(tank.attack_ordered and tank.attack_target==t,"46 attacks chosen live building")
		else: check((j.step==prior+1 or (j.get("target")==t and tank.has_move_order)),"move order or arrival at typed building "+str(op))
	for op in [55,57]:
		j=job_for(op,[tank])
		step=j.step
		Orders.advance(ai,"action",j,1,Retail)
		check(j.step==step,"superweapon waits for eligible charged launcher "+str(op))
	# Controlled firing range away from infantry and occupied landing footprints.
	var source:Vector2=Vector2.ONE*battle.map_size*0.42
	tank.position=battle.path_service.nearest_reachable(source,tank.position,false,16)
	var cell=tank.position
	var target=battle._place_building("GAPOWR","ally",cell+Vector2(570,-75),true)
	target._buildup_play=-1
	for i in 3:
		battle._place_building("NAPOWR","enemy",cell+Vector2(-460,i*100),true)._buildup_play=-1
	var iron=battle._place_building("NAIRON","enemy",cell+Vector2(-250,310),true)
	var chrono=battle._place_building("GACSPH","enemy",cell+Vector2(70,330),true)
	for launcher in [iron,chrono]:
		launcher._buildup_play=-1
		launcher._sw_charge=launcher.sw_recharge()
	battle._update_power()
	j=job_for(55,[tank])
	step=j.step
	Orders.advance(ai,"action",j,1,Retail)
	check(j.step==step+1 and tank.special.has("iron_left") and not iron.sw_ready(),"55 fires charged Iron Curtain on the team")
	j=job_for(57,[tank])
	step=j.step
	Orders.advance(ai,"action",j,1,Retail)
	check(j.step==step+1 and tank.position.distance_to(cell)>50 and not chrono.sw_ready(),"57 spends charge and teleports armour to the selected quarry")
	await get_tree().process_frame

func hunt_sequence() -> void:
	BattleRequest.configure_skirmish(MatchRules.EXTENDED,{"enemy_country":"美国","map_layout":"exp_plain","opening":"prebuilt","fog_of_war":false})
	screen=load("res://scenes/battle.tscn").instantiate()
	add_child(screen)
	screen.process_mode=Node.PROCESS_MODE_DISABLED
	battle=screen.battle
	var ai=battle.skirmish_ai
	var point:Vector2=battle.path_service.nearest_reachable(ai.rally,ai.base_center,false,8)
	for i in 3: battle.spawn_unit("MTNK","enemy",point+Vector2(i*5,0))
	var victim=battle.spawn_unit("HARV","ally",point+Vector2(65,0))
	var next=battle.spawn_unit("HTNK","ally",point+Vector2(50,0))
	Retail.tick(ai,8)
	var j:Dictionary=ai.ai_state[Retail.TEAMS].get("hunter",{})
	check(j.get("target")==victim,"hunter first selects the harvester")
	if j.get("target")==victim:
		victim._die()
		Retail.tick(ai,1)
		check(j.get("success",false) and j.step==3,"49 marks actual hunter kill and advances")
		Retail.tick(ai,1)
		check(j.get("target")==next and j.members.all(func(u):return u.attack_target==next),"surviving hunter team continues to vehicle quarry")
	await finish()
