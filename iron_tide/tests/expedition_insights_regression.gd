extends "res://tests/base_recovery_regression.gd"
const Insights=preload("res://scripts/expedition/insights.gd")
const Tactics=preload("res://scripts/expedition/elite_tactics.gd")
const Portraits=preload("res://scripts/ui/hero_portraits.gd")
const Plan=preload("res://scripts/expedition/reinforcement_plan.gd")

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not ProjectSettings.get_setting("application/config/use_custom_user_dir",false):get_tree().quit(2);return
	check(Expedition.start("美国","",20261120),"isolated new campaign")
	var run:=Expedition.state.duplicate(true)
	run.heroes=["E1"];run.wounded_heroes=[];run.hero="E1";run.hero_wounded=false
	run.survivors=[];run.reinforcements=[{"id":"E1","count":3},{"id":"MTNK","count":2}];run.special_squads=[];run.active_roster=["E1","MTNK"]
	run.trait_buffs={"infantry":2};run.frozen.hero_training={"E1":{"firepower":3,"health":5}}
	run.chrono_discounts={"E1:E1:":30.0}
	var benefit:=Insights.audience(run,{"kind":"trait_buff","id":"infantry"})
	check(benefit.contains("4 个受益") and benefit.contains("解锁 3 层机制"),"beneficiary count includes hero, excludes tank, unlocks node")
	check(Insights.audience(run,{"kind":"buff","id":"production"}).contains("不按军团人数"),"economy buff does not claim all units benefit")
	run.buffs.engines=1
	check(Insights.audience(run,{"kind":"buff","id":"engines","levels":1}).contains("+10% → +20%"),"reward shows actual equipment stat before and after")
	check(Insights.audience(run,{"kind":"buff","id":"engines","levels":1}).contains("上限"),"speed preview explains cap")
	var rows:=Insights.arrival_rows(run)
	var hero_rows:Array=rows.filter(func(entry):return entry.hero=="E1")
	check(hero_rows.size()==1 and is_equal_approx(hero_rows[0].due,Plan.delay_for("E1","E1",run)),"trained hero arrival preview uses cost-based planner and chrono discount")
	check(Insights.arrival_text(run).contains("全军到齐") and not Insights.arrival_text(run).contains("英雄训练"),"arrival timeline is readable without a hero-only delay")
	var hashes:Dictionary={}
	for id:String in MetaProgress.Academy.HEROES:
		var texture:=Portraits.texture(id)
		check(texture!=null,"portrait exists "+id)
		if texture!=null:
			var expected:=GameData.ra2_cameo_path(id) if id in ["TANY","BORIS"] else "res://assets/ui/heroes/%s.png"%id.to_lower()
			check(texture.resource_path==expected,"hero portrait path "+id)
			if id not in ["TANY","BORIS"]:
				check(texture.get_width()*4==texture.get_height()*5,"original cameo aspect ratio "+id)
				hashes[FileAccess.get_sha256(expected)]=true
	check(hashes.size()==6,"six distinct AI portrait assets")
	var icon:=UnitIcon.new();icon.setup(GameData.get_unit("E1"),Color.WHITE)
	var ordinary:=icon.cameo_texture;icon.set_hero("E1")
	check(icon.cameo_texture==Portraits.texture("E1"),"hero icon explicit override")
	icon.setup(GameData.get_unit("E1"),Color.WHITE)
	check(icon.cameo_texture==ordinary,"normal unit setup resets hero portrait");icon.free()
	run.stage=4
	var routes:=preload("res://scripts/expedition/campaign.gd").routes(run)
	check(not routes[0].has("elite_tactic") and Tactics.ITEMS.has(routes[1].elite_tactic),"only elite route receives public tactic")
	check(routes==preload("res://scripts/expedition/campaign.gd").routes(run),"elite tactics deterministic after reload")
	Expedition.state=run
	Expedition.state.phase="ready"
	Expedition.state.routes=routes
	check(Expedition.commit(Expedition.state.duplicate(true)),"save new run fields")
	var ui=load("res://scenes/expedition.tscn").instantiate();add_child(ui)
	await get_tree().process_frame
	var labels:Array=ui.find_children("*","Label",true,false)
	var arrival_buttons:Array=ui.find_children("*","Button",true,false)
	check(arrival_buttons.any(func(entry):return entry.text.contains("增援") and entry.text.contains("到齐")),"real camp shows collapsed reinforcement summary")
	check(labels.any(func(entry):return entry.text.contains("精英战术")),"real route UI shows tactics before launch")
	ui.tab=2;ui.build();ui.army_filter=1;ui.build()
	var board=ui.find_child("FormationBox",true,false)
	var occupied:Array=board.find_children("*","Button",true,false).filter(func(b):return b.slot_index>=0 and not b.unit_id.is_empty())
	check(occupied.size()==2 and occupied[0].unit_id=="E1" and occupied[1].unit_id=="MTNK","active filter preserves both occupied deployment slots")
	var sample={"stage":3,"win":true,"losses":{"E1":1,"MTNK":3},"hero_deaths":[]}
	var loss_run={"stage":4,"battle_reports":[sample],"wounded_heroes":[]}
	check(Insights.reward_losses(loss_run).contains("灰熊坦克 ×3") and Insights.reward_losses(loss_run).contains("合计 4"),"largest recent loss is visible before reward choice")
	sample.hero_deaths=["E1"];loss_run.wounded_heroes=["E1"]
	check(Insights.reward_losses(loss_run).contains("守望者 待救治"),"hero injury takes priority")
	loss_run.stage=5
	check(Insights.reward_losses(loss_run).is_empty(),"older report never appears as last battle")
	ui.tab=1;ui.build();ui.equipment_open=true;ui.build()
	check(ui.find_children("*","Button",true,false).any(func(entry):return entry.text.begins_with("收起战术装备")),"equipment expansion works in actual UI")
	ui.free()
	var before:=int(Expedition.state.supplies)
	check(Expedition.service("kit"),"real camp purchase")
	check(int(Expedition.state.supplies)==before-40 and Expedition.state.supply_ledger["养成与补员 · kit"].out==40,"purchase ledger saved with actual debit")
	var stored:=Expedition.read_file(Expedition.FILE)
	check(stored.supply_ledger==Expedition.state.supply_ledger,"ledger cold file read")
	check(Expedition.commit(Expedition.state.duplicate(true)) and Expedition.state.supply_ledger==stored.supply_ledger,"repeat save does not duplicate ledger")
	start(MatchRules.EXTENDED)
	var tank=battle.spawn_unit("HTNK","enemy",Vector2(1500,1500))
	var hp_before:float=tank.max_hp
	Tactics.apply(tank,"armor_column");Tactics.apply(tank,"armor_column")
	check(is_equal_approx(tank.max_hp,hp_before*1.15),"elite hp applied once")
	var infantry=battle.spawn_unit("E2","enemy",Vector2(1700,1500))
	var speed_before:float=infantry.move_speed
	Tactics.apply(infantry,"rapid_raiders");infantry._recompute_bonuses()
	check(is_equal_approx(infantry.move_speed,speed_before*1.12),"elite speed survives bonus recomputation")
	var runtime=preload("res://scripts/expedition/runtime.gd").new();add_child(runtime);runtime.set_process(false);runtime.world=battle
	BattleRequest.combat_context.expedition={"token":"review-test","task":"capture","buffs":{},"stage":4}
	Expedition.state.phase="battle";Expedition.state.token="review-test";Expedition.state.route=routes[0]
	var legion=battle.spawn_unit("E1","ally",Vector2(1400,1400));legion.special[Plan.MEMBER]=true;legion.special.academy_hero="E1"
	battle.allied_state.expedition_tally={"ore":0.0,"losses":{},"scorers":{}}
	battle.credit_income("ally",315.5,true,true)
	battle.credit_income("ally",900.0,true,false)
	preload("res://scripts/expedition/rules.gd").defeated(battle,tank,legion)
	runtime.unit_died(legion);battle.units.erase(legion);legion.free()
	battle.allied_state.expedition_reinforcement_plan=[{"id":"MTNK","hero":"","hp":1.0,"rank":0,"xp":0.0,"due":200.0}]
	battle.allied_state.expedition_task={"elapsed":125.0,"kind":"capture"}
	var report:=Insights.snapshot(Expedition.state,battle,false)
	check(report.lost==1 and report.pending==1 and report.hero_deaths==["E1"],"real death accounting excludes pending units")
	var local=battle.spawn_unit("E1","ally",Vector2(1600,1400));runtime.unit_died(local)
	check(Insights.snapshot(Expedition.state,battle,false).lost==1,"local production excluded from legion losses")
	check(Expedition.settle(battle,false),"actual failed battle settlement")
	check(Expedition.state.battle_reports[-1].lost==1 and Expedition.state.phase=="failed","failure report committed")
	check(Expedition.read_file(Expedition.FILE).battle_reports[-1].pending==1,"report survives disk read")
	var filed:Dictionary=Expedition.read_file(Expedition.FILE).battle_reports[-1]
	check(is_equal_approx(filed.tally.ore,315.5),"ore deposits exclude non-ore income")
	check(filed.tally.losses.E1==2 and filed.lost==1,"factory losses included only in overall loss count")
	check(filed.tally.scorers.E1==1 and Insights.review_text(filed).contains("击毁最多兵种"),"killer type retained on disk")
	check(Insights.headline({"win":true,"seconds":0}).contains("采矿收入 —"),"unknown legacy income not inferred")
	var result_ui=load("res://scenes/expedition.tscn").instantiate()
	add_child(result_ui)
	var toggles=result_ui.find_children("*","Button",true,false).filter(func(b):return b.text=="展开明细")
	check(toggles.size()==1,"debrief visible on result page")
	if not toggles.is_empty():
		toggles[0].pressed.emit()
		check(toggles[0].text=="收起明细","debrief expands")
	result_ui.free()
	Expedition.state.phase="battle"

	check(Expedition.settle(battle,true),"actual victory settlement")
	check(Expedition.state.battle_reports[-1].win and Expedition.state.battle_reports[-1].reward>0,"victory reward breakdown persisted")
	var legacy:=Expedition.state.duplicate(true)
	legacy.erase("battle_reports");legacy.erase("supply_ledger")
	check(Expedition.valid(legacy),"old saves without analytics remain valid")
	legacy.phase="battle";legacy.stage=4;legacy.supplies=500;legacy.route=routes[0];legacy.token="review-test";legacy.retreat_used=false
	Expedition.state=legacy
	check(Expedition.retreat(battle),"actual retreat settlement")
	check(Expedition.state.battle_reports[-1].get("retreat",false) and Expedition.state.supply_ledger["撤退"].out==80,"retreat report and cost persisted")
	var mixed:=Expedition.state.duplicate(true)
	mixed.phase="ready";mixed.stage=4;mixed.supplies-=40;mixed.supply_action="测试购买"
	mixed.survivors=[];mixed.special_squads=[];mixed.reinforcements=[{"id":"E1","count":10}];mixed.active_roster=["E1"];mixed.heroes=[];mixed.hero="";mixed.hero_wounded=false;mixed.wounded_heroes=[]
	check(Expedition.commit(mixed),"mixed purchase and automatic sale save")
	check(Expedition.state.supply_ledger["测试购买"].out==40 and Expedition.state.supply_ledger["自动出售"].get("in",0)>0,"automatic sale income separated from purchase debit")
	check(Insights.review_text(Expedition.state.battle_reports[-1]).contains("主动撤离"),"retreat review readable")
	print("ORIGINAL_CAMEOS ",GameData.ra2_cameo_path("TANY")," / ",GameData.ra2_cameo_path("BORIS"))
	runtime.free()
	await finish()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	print("EXPEDITION INSIGHTS checks=",checks.size()," failed=",failed)
	get_tree().quit(0 if failed==0 else 1)
