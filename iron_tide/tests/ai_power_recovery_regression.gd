extends "res://tests/base_recovery_regression.gd"

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2)
		return
	GM.infinite_funds=false
	GM.infinite_power=false
	GM.no_build_time=false
	for mode in [MatchRules.RA2,MatchRules.EXTENDED]:
		for country in ["美国","苏俄"]:
			for multiple in [false,true]: await exercise(mode,country,multiple)
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	print("AI POWER checks=",checks.size()," failed=",failed)
	get_tree().quit(0 if failed==0 else 1)

func exercise(mode:String,country:String,multiple:bool) -> void:
	var config={"map_layout":"yr_crctbrd","opening":"prebuilt","enemy_country":country,"difficulty":3,"fog_of_war":false,"starting_funds":12000}
	if multiple: config.houses=[{"country":"美国","team":1},{"country":"美国","team":2},{"country":country,"team":1,"difficulty":3}]
	BattleRequest.configure_skirmish(mode,config)
	screen=load("res://scenes/battle.tscn").instantiate()
	add_child(screen)
	screen.process_mode=Node.PROCESS_MODE_DISABLED
	battle=screen.battle
	battle.mission.map_layout="coast" # Controlled land arena; native map rules are tested separately.
	battle.paused=false
	get_tree().paused=false
	prefix=mode+country+(" team " if multiple else " duel ")
	for u in battle.units: u.free()
	battle.units.clear()
	for b in battle.buildings: b.free()
	battle.buildings.clear()
	for group in ["obstacles","resource_nodes","native_ore_drills"]:
		for node in get_tree().get_nodes_in_group(group): node.free()
	battle.path_service.native_map_id=""
	battle.path_service._native_base.clear()
	battle.water_rects.clear()
	battle.path_service.water_rects.clear()
	battle.path_service.bridge_decks.clear()
	battle._refresh_pathing()
	var owner="ai2" if multiple else "enemy"
	var ai=battle.house_controllers[owner] if multiple else battle.skirmish_ai
	ai.base_center=Vector2(1500,1500)
	var power_id:String=battle.roster_id("GAPOWR",owner)
	var plant=place(ai,power_id,Vector2(-240,0))
	plant.hp=1.0
	place(ai,battle.roster_id("GACNST",owner),Vector2.ZERO)
	var barracks=place(ai,battle.roster_id("GAPILE",owner),Vector2(240,0))
	place(ai,"NARADR" if country=="苏俄" else "GAAIRC",Vector2(0,300))
	place(ai,battle.roster_id("GAREFN",owner),Vector2(500,0))
	if battle.fog!=null: battle.fog.rebuild()
	battle._update_power()
	check(battle.side_power_low(owner),prefix+"damaged generator causes real owner shortage")
	var pending=null
	if multiple:
		pending=battle._place_building("NATECH" if country=="苏俄" else "GATECH",owner,Vector2(1500,2100),false)
	var player_money:float=battle.funds
	decide(ai,multiple)
	check(power_orders(owner,power_id)==1,prefix+"power takes priority over unfinished tech or missing factory")
	decide(ai,multiple)
	check(power_orders(owner,power_id)==1,prefix+"repeated decisions do not duplicate pending generator")
	var money:float=battle.funds_for(owner)
	if multiple:
		var before:int=battle.buildings.size()
		ai.advance_construction(0.05)
		ai.place_ready_construction([])
		check(battle.buildings.size()==before and battle.funds_for(owner)<money,prefix+"partial payment has no map foundation")
		ai.advance_construction(1000.0)
		ai.place_ready_construction([])
		check(battle.buildings.size()==before+1 and not battle.buildings.back().under_construction,prefix+"ready generator appears completed")
	else:
		battle._tick_structure_queue(1000.0)
		ai._try_build()
	battle._update_power()
	check(not battle.side_power_low(owner),prefix+"paid generator completion restores power",{"grid":battle._side_power(owner),"jobs":battle.enemy_struct_queue.duplicate(true),"ready":battle.enemy_struct_ready.duplicate(),"site":str(ai.Operations.build_spot(ai,power_id))})
	check(is_equal_approx(money-battle.funds_for(owner),float(GameData.get_building(power_id).cost)),prefix+"restoring power charges exactly one generator")
	check(battle.funds==player_money,prefix+"AI recovery never spends player treasury")
	if pending!=null:
		check(pending.under_construction and pending.build_elapsed==0,prefix+"existing construction is preserved")
		battle.buildings.erase(pending)
		pending.free()
		battle._refresh_pathing()
	# Lose all generator output between strategy ticks: fast infantry refill must save power cash.
	for b in battle.buildings:
		if b.side==owner and b.power>0: b.hp=1.0
	battle.enemy_struct_queue.clear()
	battle.enemy_struct_ready.clear()
	for b in battle.buildings: b.production.clear()
	# Keep replacement-miner reserves from masking the power-budget assertion.
	for i in 2: battle.spawn_unit(battle.roster_id("CMIN",owner),owner,Vector2(2200,2200)+Vector2(i*100,0))
	battle._update_power()
	battle.spend_side(owner,battle.funds_for(owner))
	battle.credit_side(owner,float(GameData.get_building(power_id).cost),true)
	ai._try_train()
	check(barracks.production.is_empty(),prefix+"fast refill reserves replacement power money immediately")
	if multiple:
		ai.train_army(battle.buildings.filter(func(b):return b.side==owner),[],{})
		check(barracks.production.is_empty(),prefix+"regular refill also preserves power cash without a cached decision")
	var Power=preload("res://scripts/world/skirmish_power.gd")
	var balance:float=Power.margin(ai)
	var other=place(ai,power_id,Vector2(-500,0))
	other.side="ally"
	check(is_equal_approx(Power.margin(ai),balance),prefix+"another owner's power cannot cover the deficit")
	for b in battle.buildings:
		if b.side==owner and b.power>0: b.hp=b.max_hp
	battle._update_power()
	battle.allied_state["blackout_"+owner]=10.0
	check(not Power.needed(ai),prefix+"temporary spy blackout does not cause needless generators")
	battle.allied_state.erase("blackout_"+owner)
	var margin:float=Power.margin(ai)
	barracks.power-=margin
	check(Power.before_build(ai,"NATECH" if country=="苏俄" else "GATECH")==power_id,prefix+"future high-drain tech gets power first")
	check(Power.before_build(ai,power_id)==power_id,prefix+"a generator never recursively requires another generator")
	# The deficit can require several plants; finish and re-evaluate each real order.
	barracks.power=-float(GameData.get_building(power_id).power)*3.0
	battle.credit_side(owner,12000.0,true)
	var built=0
	for i in 8:
		battle._update_power()
		if not battle.side_power_low(owner): break
		decide(ai,multiple)
		if multiple:
			var before:int=battle.buildings.size()
			ai.advance_construction(1000.0)
			ai.place_ready_construction([])
			built+=battle.buildings.size()-before
		else:
			battle._tick_structure_queue(1000.0)
			built+=int(battle.enemy_struct_ready.get(power_id,0))
			ai._try_build()
	check(not battle.side_power_low(owner) and built>=2,prefix+"large deficit is recovered with successive paid generators",{"built":built,"grid":battle._side_power(owner)})
	# No yard: do not lock money away from MCV/miner recovery for an impossible order.
	for b in battle.buildings:
		if b.side==owner and b.is_hq: b.hp=0
	barracks.power=-10000.0
	check(Power.reserve(ai)==0.0,prefix+"lost yard leaves base-recovery money available")
	await finish()

func place(ai,id:String,offset:Vector2):
	var site=battle._place_building(id,ai.house_id,ai.base_center+offset,true)
	site._buildup_play=-1.0
	return site

func decide(ai,multiple:bool) -> void:
	if multiple:
		ai.ai_state.ops_left=1000.0
		ai._manage_base(ai.ai_state,battle.buildings.filter(func(b):return b.side==ai.house_id),[])
	else: ai._try_build()

func power_orders(owner:String,id:String) -> int:
	var count=0
	for job in battle.ai_decisions(owner).get("construction_jobs",[]):
		if job.id==id: count+=1
	for b in battle.buildings:
		if b.side==owner and b.building_id==id and b.under_construction: count+=1
	if owner=="enemy":
		for job in battle.enemy_struct_queue:
			if job.id==id: count+=1
		count+=int(battle.enemy_struct_ready.get(id,0))
	return count
