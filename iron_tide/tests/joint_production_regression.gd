extends "res://tests/special_mechanics_regression.gd"
const Joint = preload("res://scripts/rules/joint_ra2_production.gd")
const Parallel = preload("res://scripts/buildings/parallel_production.gd")
const TreeView = preload("res://scripts/ui/technology_tree.gd")

func _ready() -> void:
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2); return
	if "--cold" in OS.get_cmdline_user_args():
		await cold_load()
		write_result("cold-result.json"); return
	MetaProgress.reset_save()
	GM.unlock_production_tech=false; GM.no_build_time=false; GM.infinite_funds=false
	var ui=TreeView.new(); add_child(ui)
	MetaProgress.currency.cores=39; ui.refresh()
	check(not MetaProgress.research_technology(Joint.ID),"insufficient funds reject research")
	MetaProgress.currency.cores=80; ui.refresh()
	ui.cards[Joint.ID].button.pressed.emit()
	check(MetaProgress.technology_active(Joint.ID) and MetaProgress.balance("cores")==40,"existing technology ID purchases parallel production for 40 cores")
	check(not MetaProgress.research_technology(Joint.ID) and MetaProgress.balance("cores")==40,"already purchased record cannot charge twice")
	check(MetaProgress.technology_definition(Joint.ID).name=="空地并行生产","technology explains parallel queues")
	ui.free()
	for soviet in [false,true]:
		arena(MatchRules.EXTENDED)
		exercise(soviet)
		await finish()
	MetaProgress.set_effect_enabled("tech",Joint.ID,"",false)
	var child_output:Array=[]
	var code:=OS.execute(OS.get_executable_path(),["--headless","--path",ProjectSettings.globalize_path("res://"),"res://tests/joint_production_regression.tscn","--","--cold"],child_output,true)
	check(code==0,"fresh process restores both paid lanes",child_output if code!=0 else null)
	for mode in [MatchRules.EXTENDED,MatchRules.RA2]:
		arena(mode)
		var factory=prepare_factory(false)
		check(not Parallel.enabled(factory),mode+" disabled/classic uses original queue")
		factory.enqueue("MTNK"); factory.enqueue("SHAD"); factory._process(1.0)
		check(factory.progress>0 and not factory.special.has(Parallel.KEY),mode+" original single queue remains")
		check(not factory.buildable.has("HTNK"),mode+" no foreign catalogue")
		await finish()
	write_result("result.json")

func prepare_factory(soviet: bool):
	battle._countries.ally="Russians" if soviet else "Americans"
	battle.funds=100000
	add("NACNST" if soviet else "GACNST","ally",Vector2(300,300))
	add("NAREFN" if soviet else "GAREFN","ally",Vector2(650,300))
	add("NARADR" if soviet else "GAAIRC","ally",Vector2(1500,450))
	add("NATECH" if soviet else "GATECH","ally",Vector2(1900,450))
	var factory=add("NAWEAP" if soviet else "GAWEAP","ally",AIM)
	battle._refresh_pathing();battle.power_low=false
	return factory

func clear_orders(factory) -> void:
	while not factory.production.is_empty(): factory.cancel_at(0)

func exercise(soviet: bool) -> void:
	var label: String="Soviet " if soviet else "Allied "
	var tank: String="HTNK" if soviet else "MTNK"
	var aircraft: String="ZEP" if soviet else "SHAD"
	var foreign: String="MTNK" if soviet else "HTNK"
	var factory=prepare_factory(soviet)
	check(Parallel.enabled(factory),label+"purchased technology enables parallel lanes")
	check(not factory.buildable.has(foreign) and not factory.enqueue(foreign),label+"native factory rejects foreign tank")
	check(not battle.country_block_reason("TNKD").is_empty() and not battle.country_block_reason("BEAG").is_empty(),label+"country-exclusive units stay locked")
	check(not GameData.ra2_prereq_ok(foreign,battle.owned_building_ids(),{},"ally"),label+"no cross-faction prerequisite aliases")
	check(not screen.hud._unit_catalog().has(foreign),label+"foreign tank absent from sidebar")
	if soviet:
		check(not screen.hud._building_catalog().has("GAAIRC") and not screen.hud._building_catalog().has("GAROBO"),"Soviet support catalogue remains Soviet")
		check(not battle.owns_production_yard("GAAIRC","ally"),"Soviet yard cannot build allied airport")
	screen.hud.select_prod_tab("vehicle")
	screen.hud._prod_buttons[tank].pressed.emit()
	screen.hud.select_prod_tab("air")
	screen.hud._prod_buttons[aircraft].pressed.emit()
	check(factory.production.has(tank) and factory.production.has(aircraft),label+"real sidebar queues own tank and aircraft")
	var balance: float=battle.funds
	factory._process(1.0)
	check(factory.queue_elapsed(tank)>0 and factory.queue_elapsed(aircraft)>0,label+"same factory advances both lanes in one frame")
	check(is_equal_approx(balance-battle.funds,factory.total_production_paid()),label+"both lanes pay only actual work")
	check(screen.hud._queue_uid(factory)==aircraft and screen.hud._queue_runs(factory).size()==1,label+"air tab shows its own active queue")
	check(screen.hud._queue_caption(factory).contains(GameData.get_unit(aircraft).name),label+"air caption reports aircraft")
	var air_progress:float=factory.queue_elapsed(aircraft)
	var ground_progress:float=factory.queue_elapsed(tank)
	factory.production_right_click(aircraft)
	factory._process(1.0)
	check(factory.queue_elapsed(aircraft)==air_progress and factory.queue_elapsed(tank)>ground_progress,label+"pausing air leaves tank advancing")
	check(factory.resume_production(aircraft),label+"resume targets air lane")
	ground_progress=factory.queue_elapsed(tank)
	factory.production_right_click(tank)
	factory._process(1.0)
	check(factory.queue_elapsed(tank)==ground_progress and factory.queue_elapsed(aircraft)>air_progress,label+"pausing tank leaves air advancing")
	factory.resume_production(tank)
	var air_paid:float=Parallel.state(factory,aircraft).paid
	balance=battle.funds
	ground_progress=factory.queue_elapsed(tank)
	factory.cancel_at(factory.production.find(aircraft))
	check(is_equal_approx(battle.funds-balance,air_paid) and factory.queue_elapsed(tank)==ground_progress,label+"cancelling air refunds only its paid work")
	check(factory.enqueue(aircraft),label+"requeue aircraft")
	factory._process(1.0)
	air_progress=factory.queue_elapsed(aircraft);ground_progress=factory.queue_elapsed(tank)
	var money:float=battle.funds; battle.funds=0
	factory._process(1.0)
	check(factory.queue_elapsed(aircraft)==air_progress and factory.queue_elapsed(tank)==ground_progress,label+"zero funds stalls both lanes")
	battle.funds=money
	if soviet:
		var lab=battle.buildings.filter(func(b):return b.building_id=="NATECH")[0]
		lab.under_construction=true;factory._process(1.0)
		check(factory.queue_elapsed(aircraft)==air_progress and factory.queue_elapsed(tank)>ground_progress,"missing air prerequisite stalls only air")
		lab.under_construction=false
	factory._process(10000.0)
	check(factory.production.is_empty(),label+"both lanes finish")
	check(battle.units.filter(func(u):return u.unit_id==tank).size()==1 and battle.units.filter(func(u):return u.unit_id==aircraft).size()==1,label+"one native tank and one native aircraft delivered")
	for u in battle.units: u.free()
	battle.units.clear()
	for i in factory.queue_capacity(): check(factory.enqueue(tank),label+"ground reservation "+str(i))
	check(not factory.enqueue(tank) and factory.enqueue(aircraft),label+"full ground queue leaves air reservation available")
	clear_orders(factory)
	factory.enqueue(aircraft);factory.enqueue(tank);factory.enqueue(aircraft)
	screen.hud.select_prod_tab("air")
	var runs:Array=screen.hud._queue_runs(factory)
	check(runs.size()==2 and runs[0].start==0 and runs[1].start==2,label+"interleaved queue tiles retain true cancellation indices")
	factory._process(1.0)
	air_progress=factory.queue_elapsed(aircraft)
	factory.cancel_at(int(runs[1].start))
	check(factory.production==[aircraft,tank] and factory.queue_elapsed(aircraft)==air_progress,label+"cancelling waiting aircraft leaves tank and active aircraft intact")
	clear_orders(factory)
	factory.enqueue(tank);factory.enqueue(aircraft);factory._process(1.0)
	factory.production_right_click(aircraft)
	if soviet:
		check(BattleSaves.save_slot(battle,"slot1").ok,"save both independently paid lanes")
	# Remove a mistaken old mixed menu/order, refunding exactly the paid amount.
	clear_orders(factory)
	factory.special.erase(Parallel.KEY)
	factory.buildable.append(foreign);factory.production=[foreign,tank]
	factory.progress=2.0;factory.production_paid=123.0;factory.special.unit_price=900.0
	balance=battle.funds
	if soviet:
		battle.allied_state.migration_expected_funds=balance+123.0
		check(BattleSaves.save_slot(battle,"slot2").ok,"write legacy mixed queue snapshot")
	Joint.sync_catalog(factory)
	check(not factory.buildable.has(foreign) and factory.production==[tank],label+"old mixed factory menu and order cleaned")
	check(is_equal_approx(battle.funds-balance,123.0) and factory.total_production_paid()==0.0,label+"old invalid paid order refunded exactly once")
	Joint.sync_catalog(factory)
	check(is_equal_approx(battle.funds-balance,123.0),label+"migration is idempotent")
	clear_orders(factory)
	factory.enqueue(tank);factory.enqueue(aircraft);factory._process(1.0)
	var capture_refund:float=factory.total_production_paid()
	balance=battle.funds
	AlliedAbilities.change_side(factory,"enemy")
	check(not Parallel.enabled(factory) and not factory.buildable.has(foreign),label+"capture grants no opponent technology or mixed roster")
	check(factory.production.is_empty() and is_equal_approx(battle.funds-balance,capture_refund),label+"capture keeps existing rule: cancel both queues and refund original owner")
	AlliedAbilities.change_side(factory,"ally")
	check(Parallel.enabled(factory) and factory.total_production_paid()==0.0,label+"recapture restores parallel ability without resurrecting orders")
	clear_orders(factory)
	if not soviet:
		var airport=battle.buildings.filter(func(b):return b.building_id=="GAAIRC")[0]
		check(factory.enqueue(tank) and airport.enqueue("ORCA"),"own airport and factory accept own units")
		factory._process(1.0);airport._process(1.0)
		check(factory.progress>0 and airport.progress>0,"airport jet and factory tank still advance concurrently")
	clear_orders(factory)
	factory.enqueue(tank);factory.enqueue(aircraft);factory._process(1.0)
	var sale_refund:float=float(GameData.ra2_refund(int(factory.data.cost)))+factory.total_production_paid()
	balance=battle.funds
	check(battle.apply_building_action("sell",factory),label+"real sale accepts active dual-queue factory")
	check(is_equal_approx(battle.funds-balance,sale_refund),label+"sale refunds both paid lanes plus normal structure value")

func cold_load() -> void:
	check(MetaProgress.technology_owned(Joint.ID),"legacy purchase survives profile reload")
	var result:=BattleSaves.prepare_load("slot1")
	check(result.ok,"disk snapshot loads")
	if not result.ok:return
	screen=load("res://scenes/battle.tscn").instantiate();add_child(screen)
	screen.process_mode=Node.PROCESS_MODE_DISABLED;battle=screen.battle
	battle.paused=false;get_tree().paused=false;battle.power_low=false
	var factory=battle.buildings.filter(func(b):return b.building_id=="NAWEAP" and b.side=="ally")[0]
	check(Parallel.enabled(factory) and not factory.buildable.has("MTNK"),"saved technology retains concurrency without mixed catalogue")
	check(factory.queue_elapsed("HTNK")>0 and factory.queue_elapsed("ZEP")>0 and factory.production_paused("ZEP") and not factory.production_paused("HTNK"),"both paid progress and independent pause restored")
	factory.resume_production("ZEP");factory._process(10000.0)
	check(factory.production.is_empty() and battle.units.filter(func(u):return u.unit_id in ["HTNK","ZEP"]).size()==2,"loaded lanes complete exactly once")
	await finish()
	result=BattleSaves.prepare_load("slot2")
	check(result.ok,"legacy mixed snapshot loads")
	if not result.ok:return
	screen=load("res://scenes/battle.tscn").instantiate();add_child(screen)
	screen.process_mode=Node.PROCESS_MODE_DISABLED;battle=screen.battle
	factory=battle.buildings.filter(func(b):return b.building_id=="NAWEAP" and b.side=="ally")[0]
	check(not factory.buildable.has("MTNK") and factory.production==["HTNK"],"disk migration removes foreign menu/order and keeps own order")
	check(is_equal_approx(battle.funds,float(battle.allied_state.migration_expected_funds)),"disk migration refunds invalid paid order exactly")
	await finish()

func write_result(name: String) -> void:
	FileAccess.open(output_dir.path_join(name),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	get_tree().quit(0 if failed==0 else 1)
