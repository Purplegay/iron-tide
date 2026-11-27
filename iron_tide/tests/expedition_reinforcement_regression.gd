extends "res://tests/base_recovery_regression.gd"
const Plan=preload("res://scripts/expedition/reinforcement_plan.gd")
const Runtime=preload("res://scripts/expedition/runtime.gd")

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or (not ProjectSettings.get_setting("application/config/use_custom_user_dir",false) and OS.get_environment("IRON_TIDE_TEST_PROFILE")!=OS.get_user_data_dir()):get_tree().quit(2);return
	var run:Dictionary={"stage":1,"active_roster":["E1","MTNK"],"reinforcements":[{"id":"MTNK","count":2},{"id":"E1","count":3}],"special_squads":[],"heroes":[],"survivors":[],"frozen":{"hero_training":{"E1":{"firepower":3,"health":5}},"expedition_hero_profile":{"academy":{"hero_builds":{"E1":999}}}}}
	check(Plan.delay_for("E1","",run)==Plan.unit_cost("E1")*0.3,"price / 100 / 2 minutes")
	check(Plan.delay_for("E1","E1",run)==Plan.delay_for("E1","",run),"hero uses the same cost-based arrival timer as ordinary units despite high training")
	var plan:Array=Plan.build(run)
	check(plan.size()==5 and float(plan[0].due)>0,"all new units wait, including first of each type")
	check(plan[0].id=="E1" and plan[-1].id=="MTNK","cheap reinforcements precede expensive units")
	run.heroes=["E1"];run.wounded_heroes=[]
	check(Plan.build(run).size()==6,"healthy hero queued")
	run.survivors=[{"id":"E1","hero":"E1","variant":"","hp":0.7,"rank":2,"xp":11.0}]
	check(Plan.build(run).size()==6,"surviving hero queues again without duplication")
	run.survivors=[];run.wounded_heroes=["E1"]
	check(Plan.build(run).size()==5,"wounded hero not queued")
	run.special_squads=[{"id":"E1","count":1,"token":"test"}]
	check(Plan.build(run).size()==6,"special squad participates in timed plan")
	# Survivors must wait again and retain their progression in the queue.
	run.survivors=[{"id":"MTNK","hero":"","variant":"","hp":0.6,"rank":2,"xp":15.0}]
	var survivors_plan:=Plan.build(run)
	check(survivors_plan.size()==7,"survivors join timed queue alongside new recruits")
	var base:=Plan.base_delay("MTNK","",run)
	run.chrono_discounts={"MTNK::":base*0.9}
	check(is_equal_approx(Plan.delay_for("MTNK","",run),base*0.5),"ordinary carry reduction capped at 50 percent")
	run.relics={"chrono_anchor":true}
	check(is_equal_approx(Plan.delay_for("MTNK","",run),base*0.2),"anchor carry reduction capped at 80 percent")
	run.chrono_discounts={};run.relics={}
	start(MatchRules.EXTENDED)
	BattleRequest.combat_context.expedition={"task":"capture","stage":1,"licenses":[]}
	var tasks=preload("res://scripts/expedition/objectives.gd").new()
	check(tasks.setup(battle,false),"objective setup succeeds with no licenses or deployed troops")
	check(tasks.state.points.size()==3 and battle.path_service.zone_at(tasks.state.origin)>0,"base provides walkable origin for all three task points")
	tasks.free()
	BattleRequest.combat_context.erase("expedition")
	var initial:=[{"id":"MTNK","hero":"","variant":"","due":base},{"id":"MTNK","hero":"","variant":"","due":base}]
	battle.allied_state.expedition_legion_initial=initial
	battle.allied_state.expedition_reinforcement_clock=base
	var carry:=Plan.carry(run,battle,initial)
	check(is_equal_approx(float(carry["MTNK::"]),base*0.5),"completed prior timer carries only half, never instant arrival")
	carry=Plan.carry(run,battle,[initial[0]])
	check(is_equal_approx(float(carry["MTNK::"]),base*0.25),"50 percent legion losses restore half of reduction")
	run.chrono_discounts={"MTNK::":base*0.5}
	carry=Plan.carry(run,battle,[initial[0]])
	check(is_equal_approx(float(carry["MTNK::"]),base*0.25),"loss penalty applies after cap even with existing maximum reduction")
	run.chrono_discounts={}
	battle.allied_state.expedition_reinforcement_clock=base*0.4
	carry=Plan.carry(run,battle,initial)
	check(is_equal_approx(float(carry["MTNK::"]),base*0.2),"unfinished prior countdown carries half elapsed time")
	var runtime=Runtime.new()
	add_child(runtime);runtime.set_process(false);runtime.world=battle
	Expedition.state={"special_squads":[]}
	runtime.reinforcement_plan=plan.duplicate(true)
	runtime.reinforcement_clock=float(plan[0].due)-0.01
	Ra2Sfx.stop_all()
	runtime._process_reinforcements()
	check(not Ra2Sfx._eva_player.playing,"no arrival announcement before deployment")
	check(battle.units.is_empty() and runtime.reinforcement_plan.size()==5,"no early arrivals")
	runtime.reinforcement_clock=float(plan[0].due)
	runtime._process_reinforcements()
	check(battle.units.size()==3 and runtime.reinforcement_plan.size()==2,"exact threshold deploys all cheap units in real battle")
	check(battle.effects_root.get_child_count()>=3,"arrivals create real chrono effects")
	check(Ra2Sfx._eva_player.playing and Ra2Sfx._eva_player.stream.resource_path.ends_with("ceva038.wav") and Ra2Sfx._eva_queue.is_empty(),"three simultaneous arrivals play one allied recording")
	var saved:Array=runtime.reinforcement_plan.duplicate(true)
	runtime.reinforcement_plan=saved.duplicate(true)
	runtime._process_reinforcements()
	check(battle.units.size()==3,"restored pending queue does not repeat arrived batch")
	check(Ra2Sfx._eva_queue.is_empty(),"restored pending queue does not replay arrival audio")
	Expedition.state={"catalog":["E1","MTNK"],"active_roster":["E1","MTNK"],"special_squads":[],"survivors":[],"reinforcements":[],"trait_buffs":{}}
	var local=battle.spawn_unit("E1","ally",Vector2(1500,1500))
	check(not local.special.get(Plan.MEMBER,false),"factory/local spawn lacks legion origin")
	var collected:=Expedition.collect(battle,false)
	check(collected.size()==5,"collect retains three legion arrivals and two pending, excludes local unit")
	battle.units.erase(local);local.free()
	# Naval transport without a shipyard cannot land in this dry arena.
	runtime.reinforcement_plan.push_front({"id":"SAPC","due":0.0})
	runtime.reinforcement_clock=float(plan[-1].due)
	runtime._process_reinforcements()
	check(battle.units.size()==5 and runtime.reinforcement_plan.size()==1,"failed landing retains pending row without dropping other due units")
	check(runtime.reinforcement_plan[0].id=="SAPC","failed unit remains available for retry")
	check(Ra2Sfx._eva_queue.size()==1 and Ra2Sfx._eva_queue[0].file=="ceva038.wav","next successful wave queues one line")
	runtime._process_reinforcements()
	check(Ra2Sfx._eva_queue.size()==1,"blocked landing retry stays silent")
	runtime.reinforcement_plan.append({"id":"E1","due":0.0})
	runtime._process_reinforcements()
	check(Ra2Sfx._eva_queue.size()==2,"close consecutive waves retain separate announcements")
	Ra2Sfx.stop_all()
	check(Ra2Sfx.play_eva(Ra2Sfx.REINFORCEMENTS_ARRIVED,"soviet",0) and Ra2Sfx._eva_player.stream.resource_path.ends_with("csof038.wav"),"Soviet commander receives Soviet recording")
	runtime.free()
	await finish()
	await check_local_replacements()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	print("REINFORCEMENTS checks=",checks.size()," failed=",failed)
	get_tree().quit(0 if failed==0 else 1)

func check_local_replacements() -> void:
	start(MatchRules.EXTENDED)
	BattleRequest.combat_context.expedition={"stage":1,"catalog":["E1","MTNK"],"licenses":["E1","MTNK"],"buffs":{},"condition":"","trait_buffs":{}}
	var e1:Dictionary={"id":"E1","hero":"","variant":"","hp":1.0,"rank":0,"xp":0.0,"due":30.0}
	var tank:Dictionary=e1.duplicate();tank.id="MTNK"
	Expedition.state={"stage":1,"catalog":["E1","MTNK"],"active_roster":["E1"],"special_squads":[],"survivors":[e1.duplicate(),e1.duplicate()],"reinforcements":[],"trait_buffs":{}}
	battle.allied_state.expedition_legion_initial=[e1.duplicate(),e1.duplicate(),tank.duplicate()]
	battle.allied_state.expedition_reinforcement_plan=[e1.duplicate()]
	battle.allied_state.expedition_reinforcement_clock=30.0
	var base_pos:Vector2=battle.player_start()
	var barracks=battle._place_building("GAPILE","ally",base_pos+Vector2(280,0),true)
	barracks._buildup_play=-1.0
	var accepted:bool=barracks.enqueue("E1") and barracks.enqueue("E1")
	check(accepted,"real barracks can queue two local infantry",barracks.queue_block_reason("E1"))
	barracks._tick_unit_queue(1000.0,"E1")
	var locals:Array=battle.units.filter(func(unit):return unit.special.get(Plan.LOCAL_PRODUCTION,false))
	if not locals.is_empty():
		locals[0].position=base_pos+Vector2(0,400)
		locals[0]._grant_veteran(1,false)
	barracks._tick_unit_queue(1000.0,"E1")
	locals=battle.units.filter(func(unit):return unit.special.get(Plan.LOCAL_PRODUCTION,false))
	check(locals.size()==2,"real queue completion marks both units as locally produced")
	var map_tank=battle.spawn_unit("MTNK","ally",base_pos+Vector2(0,480))
	check(not map_tank.special.get(Plan.LOCAL_PRODUCTION,false),"non-queue map spawn is not local production")
	var next:=Expedition.state.duplicate(true)
	Expedition.settle_legion(next,battle,false)
	check(next.survivors.size()==2 and next.survivors.all(func(row):return row.id=="E1"),"one pending infantry and one replacement return; no second local or map tank")
	check(next.survivors.any(func(row):return row.rank==1),"veteran local gets the only replacement slot")
	check(is_equal_approx(float(next.chrono_discounts.get("E1::",-1)),5.0),"original loss ratio is calculated before backfill")
	check(Plan.build(next).size()==2,"the replacement joins next stage timed plan")
	check(Expedition.excess_sale(next).count==0,"replacement does not produce sellable excess")
	for i in 8:Expedition.state.survivors.append(e1.duplicate())
	Expedition.state.deployment_counts={"E1":2}
	Expedition.settle_legion(next,battle,false)
	var sale:=Expedition.excess_sale(next)
	check(next.survivors.size()==9 and sale.count==1,"already-owned excess is preserved, local production adds none")
	Expedition.state.survivors=[e1.duplicate(),e1.duplicate()]
	for id in ["GGI","SNIPE","SENGINEER"]:
		for i in 8:
			var reserve:=e1.duplicate();reserve.id=id
			Expedition.state.survivors.append(reserve)
	Expedition.settle_legion(next,battle,false)
	check(next.survivors.size()==25 and next.survivors.filter(func(row):return row.id=="E1").size()==1,"chapter population cap prevents local backfill without removing reserves")
	await finish()
