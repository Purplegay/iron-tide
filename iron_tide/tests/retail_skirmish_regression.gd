extends "res://tests/expedition_regression.gd"
const Retail = preload("res://scripts/world/retail_skirmish.gd")

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2)
		return
	for multi in [false,true]: await run_skirmish(multi)
	await scout_in_fog()
	await pay_for_missing_member()
	new_ready("美国",20)
	check(Expedition.launch(0),"launch real expedition stage")
	if instantiate_battle():
		var ai = battle.skirmish_ai if battle.skirmish_ai else battle.house_controllers.enemy
		ai.run_decisions(8.0)
		check(ai.ai_state.has(Retail.TEAMS),"retail controller entered from expedition launch")
		var command = screen.expedition_runtime.tasks.actor("command")
		check(battle.actor_alive(command) and not Retail.available(ai,command,command.unit_id),"mobile objective cannot be recruited")
	await finish()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	print("RETAIL SKIRMISH checks=",checks.size()," failed=",failed)
	get_tree().quit(0 if failed==0 else 1)

func run_skirmish(multi: bool) -> void:
	var country := "苏俄" if multi else "美国"
	var config := {"map_layout":"yr_crctbrd" if multi else "exp_plain","opening":"prebuilt","enemy_country":country,"difficulty":5,"fog_of_war":false,"starting_funds":50000}
	if multi: config.houses=[{"country":"美国","team":1},{"country":country,"team":2,"difficulty":5},{"country":"美国","team":1}]
	BattleRequest.configure_skirmish(MatchRules.EXTENDED,config)
	screen=load("res://scenes/battle.tscn").instantiate()
	add_child(screen)
	screen.process_mode=Node.PROCESS_MODE_DISABLED
	battle=screen.battle
	var ai = battle.house_controllers.enemy if multi else battle.skirmish_ai
	var origin: Vector2 = ai.rally
	origin = battle.path_service.nearest_reachable(origin,ai.base_center,false,12)
	if multi: exercise_soviet(ai,origin)
	else: exercise_hunter(ai,origin)
	await finish()

func exercise_hunter(ai,origin: Vector2) -> void:
	var reserve = battle.spawn_unit("MTNK","enemy",origin)
	reserve.special.field_convoy=true
	var target = battle.spawn_unit("HARV","ally",origin+Vector2(120,0))
	var team := []
	for i in 3: team.append(battle.spawn_unit("MTNK","enemy",origin+Vector2(6*i,0)))
	Retail.tick(ai,8.0)
	var jobs: Dictionary = ai.ai_state[Retail.TEAMS]
	check(jobs.has("hunter") and jobs.hunter.members.size()==3,"three Grizzlies recruited from same land region")
	if not jobs.has("hunter"):return
	check(not reserve.special.has(Retail.MEMBER) and team.all(func(u):return u.attack_ordered and u.attack_target==target),"three real attack orders on visible miner, convoy protected")
	var snapshot = BattleSaves.Snapshot.new()
	snapshot.restore(battle,snapshot.capture(battle))
	ai=battle.skirmish_ai
	jobs=ai.ai_state[Retail.TEAMS]
	check(jobs.hunter.members.size()==3 and battle.actor_alive(jobs.hunter.target),"save resolves live team and target references")
	var victim=jobs.hunter.target
	AlliedAbilities.change_side(victim,"enemy")
	Retail.tick(ai,1.0)
	check(not jobs.has("hunter"),"captured miner releases hunt")
	var miner=battle.spawn_unit("HARV","enemy",origin)
	check(not miner._mission_allows_retaliation(),"harvest suppresses retaliation")
	miner.order_patrol(origin+Vector2(110,0))
	check(miner._mission_allows_retaliation(),"patrol allows retaliation")
	var attacker=battle.spawn_unit("E1","ally",origin+Vector2(35,0))
	miner.order_stop()
	miner.receive_hit(5.0,"bullet",{},attacker)
	check(miner.special.get("retaliation_target")!=attacker,"real hit while harvesting does not interrupt job")
	var escort=battle.spawn_unit("MTNK","enemy",origin+Vector2(10,0))
	escort.order_patrol(origin+Vector2(180,0))
	escort.receive_hit(5.0,"bullet",{},attacker)
	check(escort.special.get("retaliation_target")==attacker and escort.patrolling,"real hit preserves patrol waypoints and registers attacker")

func pay_for_missing_member() -> void:
	BattleRequest.configure_skirmish(MatchRules.EXTENDED,{"map_layout":"exp_plain","opening":"prebuilt","enemy_country":"美国","difficulty":4,"fog_of_war":false,"starting_funds":50000})
	screen=load("res://scenes/battle.tscn").instantiate()
	add_child(screen)
	screen.process_mode=Node.PROCESS_MODE_DISABLED
	battle=screen.battle
	var ai=battle.skirmish_ai
	var home:Vector2=ai.base_center
	for unit in battle.units.duplicate():
		if unit.side=="enemy" and unit.unit_id=="MTNK":
			battle.units.erase(unit)
			unit.free()
	for id in ["GAPOWR","GAREFN","GAPILE","GAWEAP"]:
		if Retail.site(ai,id,home)!=null: continue
		var point:Vector2=ai.Operations.build_spot(ai,id)
		if point.is_finite(): battle._place_building(id,"enemy",point,true)._buildup_play=-1
	battle._update_power()
	var factory=Retail.site(ai,"GAWEAP",home)
	check(factory!=null,"operational factory for short squad")
	if factory==null:
		await finish()
		return
	for i in 2: battle.spawn_unit("MTNK","enemy",ai.rally+Vector2(i*8,0))
	battle.spawn_unit("MTNK","enemy",ai.rally+Vector2(18,0)).special.field_convoy=true
	Retail.tick(ai,8.0)
	check(factory.production.count("MTNK")==1 and not ai.ai_state[Retail.TEAMS].has("hunter"),"two tanks plus protected convoy request exactly one missing tank")
	var snap=BattleSaves.Snapshot.new()
	snap.restore(battle,snap.capture(battle))
	ai=battle.skirmish_ai
	factory=Retail.site(ai,"GAWEAP",home)
	Retail.tick(ai,9.0)
	check(factory.production.count("MTNK")==1,"load with pending third tank does not duplicate the order")
	var balance:float=ai.funds
	for i in 4:factory._process(GameData.ra2_build_time(GameData.get_unit("MTNK")))
	check(factory.production.is_empty() and is_equal_approx(balance-ai.funds,battle.production_price(GameData.get_unit("MTNK"),"enemy")),"production delivers missing tank at its real price")
	await finish()

func scout_in_fog() -> void:
	BattleRequest.configure_skirmish(MatchRules.EXTENDED,{"map_layout":"exp_plain","opening":"prebuilt","enemy_country":"美国","difficulty":4,"fog_of_war":true})
	screen=load("res://scenes/battle.tscn").instantiate()
	add_child(screen)
	screen.process_mode=Node.PROCESS_MODE_DISABLED
	battle=screen.battle
	var ai=battle.skirmish_ai
	var origin:Vector2=battle.path_service.nearest_reachable(ai.rally,ai.base_center,false,12)
	var scouts: Array=[]
	for i in 3: scouts.append(battle.spawn_unit("MTNK","enemy",origin+Vector2(i*5,0)))
	var hidden=battle.spawn_unit("HARV","ally",battle.player_start())
	battle.fog.rebuild()
	check(not battle.actor_visible_to("enemy",hidden),"miner starts behind fog")
	Retail.tick(ai,8.0)
	var job:Dictionary=ai.ai_state.get(Retail.TEAMS,{}).get("hunter",{})
	check(not job.is_empty(),"fog scout team recruited")
	if not job.is_empty():
		for i in 3:
			if scouts[0].has_move_order: break
			Retail.tick(ai,1.0)
		check(not job.has("target") and scouts[0].has_move_order and battle.path_service.same_zone(scouts[0].position,scouts[0].move_target),"scouts receive reachable geographic destination without discovering hidden miner")
		hidden.position=scouts[0].position+Vector2(90,0)
		battle.fog.rebuild()
		Retail.tick(ai,1.0)
		check(job.get("target")==hidden and scouts[0].attack_target==hidden,"scouts switch to miner after visual contact")
	await finish()

func exercise_soviet(ai,origin: Vector2) -> void:
	for id in ["NAPOWR","NAPOWR","NAREFN","NAWEAP","NARADR"]:
		if id!="NAPOWR" and battle.owned_building_ids("enemy").has(id): continue
		var at:Vector2=ai.building_site(GameData.get_building(id))
		if at.is_finite():
			var prerequisite=battle._place_building(id,"enemy",at,true)
			prerequisite._buildup_play=-1.0
	battle._update_power()
	var owned: Array=battle.buildings.filter(func(b):return b.side=="enemy" and battle.actor_alive(b))
	var gun=Retail.site(ai,"NAFLAK",origin)
	if gun==null:
		var loc: Vector2=ai.building_site(GameData.get_building("NAFLAK"))
		check(loc.is_finite(),"legal flak site found")
		if not loc.is_finite():return
		var cash:float=ai.funds
		ai.prepare_air_defense(owned,ai.difficulty)
		ai.advance_construction(10000.0)
		ai.place_ready_construction(owned)
		for built in owned:
			if built.building_id=="NAFLAK": built._process(10.0)
		gun=Retail.site(ai,"NAFLAK",origin)
		check(gun!=null and is_equal_approx(cash-ai.funds,float(GameData.get_building("NAFLAK").cost)),"house construction selects, pays for and places operational flak gun", [str(ai.ai_state.get("construction_jobs")),battle.structure_production_block_reason("NAFLAK","enemy"),battle.owned_building_ids("enemy"),str(battle._side_power("enemy"))])
		if gun==null:return
	origin=battle.path_service.nearest_reachable(gun.position+Vector2(120,0),ai.rally,false,12)
	for i in 2:
		var zeppelin=battle.spawn_unit("ZEP","ally",origin+Vector2(225,25*i))
		zeppelin.logistics.air_lift=1.0
	for i in 6:
		battle.spawn_unit("FLAKT","enemy",origin+Vector2(i*6,0))
		battle.spawn_unit("HTNK","ally",origin+Vector2(220,6*i))
	for i in 2: battle.spawn_unit("DRON","enemy",origin+Vector2(i*8,12))
	Retail.tick(ai,8.0)
	var jobs: Dictionary=ai.ai_state[Retail.TEAMS]
	check(jobs.has("flak") and jobs.flak.members.size()==6,"two Kirovs trigger six flak troopers")
	check(jobs.has("patrol") and jobs.patrol.members.size()==2,"six Rhinos trigger pair of patrol drones")
	if jobs.has("flak"):
		check(jobs.flak.members.any(func(u):return u.has_move_order or u.hold_position),"flak team receives site orders")
	if jobs.has("flak"):
		for i in jobs.flak.members.size():
			var member=jobs.flak.members[i]
			var offset:Vector2=Vector2.RIGHT.rotated(TAU*i/jobs.flak.members.size())*(gun.radius+60.0)
			member.position=battle.path_service.nearest_reachable(gun.position+offset,member.position,false,5)
			member.order_stop()
		Retail.tick(ai,1.0)
		check(jobs.has("flak"),"garrison survives arrival at gun")
		if not jobs.has("flak"):return
		var guard=jobs.flak.members[0]
		check(guard.special.has("yr_flak_post") and guard.special.has("campaign_area_guard") and not guard.hold_position,"flak takes mobile area guard at gun")
		var delay:float=guard._target_refresh_interval()*BattleClock.RULE_TICKS_PER_SECOND
		check(delay>=36.0 and delay<=38.001,"retail area guard scan interval")
	if jobs.has("patrol"):
		var state:Dictionary=jobs.patrol
		var ref=Retail.site(ai,"NAREFN",origin)
		if ref==null:ref=battle._place_building("NAREFN","enemy",origin+Vector2(180,40),true)
		ref._buildup_play=-1
		state.step=0
		for i in state.members.size():
			var unit=state.members[i]
			unit.position=battle.path_service.nearest_reachable(ref.position+Vector2.RIGHT.rotated(TAU*i/state.members.size())*(ref.radius+60.0),unit.position,false,5)
			unit.order_stop()
		Retail.tick(ai,1.0)
		check(state.step==1 and state.wait==30.0,"patrol holds thirty seconds before moving to the factory")
