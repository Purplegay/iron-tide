extends "res://tests/expedition_regression.gd"

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2);return
	MetaProgress.reset_save()
	check_folding()
	check_services()
	await check_combat_growth()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	print("EXPEDITION GROWTH checks=",checks.size()," failed=",failed)
	get_tree().quit(0 if failed==0 else 1)

func check_folding() -> void:
	var expected:=[0,0,1,1,1,1,2,2,2,2,3,3,3,3,4,4,4,4,5,5,5]
	for raw in 21:check(Growth.folded(raw)==expected[raw],"round local level / 4: "+str(raw))
	MetaProgress.unit_levels={"E1":{"atk":12,"def":20},"GGI":{"atk":20,"def":20},"MTNK":{"atk":3,"def":0}}
	new_ready("美国")
	check(Growth.level(Expedition.state,"E1","atk")==3 and Growth.level(Expedition.state,"E1","def")==3,"12 and 20 both start at three")
	check(Growth.level(Expedition.state,"GGI","atk")==5 and not Growth.can_upgrade(Expedition.state,"GGI"),"20 starts at cap without extra upgrades")
	check(Growth.level(Expedition.state,"MTNK","atk")==0 and Growth.level(Expedition.state,"MTNK","def")==0,"lower zero sets both tracks to zero")
	MetaProgress.unit_levels.E1={"atk":20,"def":20}
	check(Growth.level(Expedition.state,"E1","atk")==3,"outside changes do not alter frozen run level")
	var legacy:Dictionary=Expedition.state.duplicate(true)
	legacy.frozen.erase("expedition_unit_levels")
	check(Growth.level(legacy,"E1","atk")==3,"existing frozen stat bonus derives the same level")
	var invalid:Dictionary=Expedition.state.duplicate(true);invalid.unit_growth.E1={"atk":6,"def":2}
	check(not Expedition.valid(invalid),"reject above-five growth")
	invalid.unit_growth.E1.atk=3.5
	check(not Expedition.valid(invalid),"reject fractional growth")
	var next:Dictionary=Expedition.state.duplicate(true)
	var before:=Growth.level(next,"E1","atk")
	Army.add_unit(next,"E1",1)
	check(Growth.level(next,"E1","atk")==before,"duplicate recruitment grants no hidden training")

func check_services() -> void:
	var special_only:Dictionary=Expedition.state.duplicate(true)
	special_only.licenses.erase("CLEG")
	special_only.special_squads.append({"id":"CLEG","tier":2,"count":1})
	special_only.unit_growth["CLEG"]={"atk":0,"def":0}
	check(Growth.can_upgrade(special_only,"CLEG"),"special-only chronolegionnaire can buy growth without ordinary license")
	Growth.upgrade(special_only,"CLEG")
	check(Growth.level(special_only,"CLEG","atk")==1 and Growth.level(special_only,"CLEG","def")==1,"special-only growth increases both shared tracks")
	special_only.unit_growth.CLEG={"atk":5,"def":5}
	check(Growth.upgrade_problem(special_only,"CLEG")=="攻防已满 5 级","capped special unit reports cap explicitly")
	special_only.unit_growth.CLEG={"atk":3,"def":5}
	special_only.frozen.get_or_add("expedition_growth_disabled",{})["CLEG:atk"]=true
	special_only.frozen.expedition_growth_disabled["CLEG:def"]=true
	check(Growth.can_upgrade(special_only,"CLEG"),"legacy disabled attack can train")
	Growth.upgrade(special_only,"CLEG")
	check(special_only.unit_growth.CLEG=={"atk":4,"def":5},"legacy 3/5 upgrades to 4/5")
	var next:Dictionary=Expedition.state.duplicate(true);next.supplies=1000
	Expedition.commit(next)
	var permanent:Dictionary=MetaProgress.unit_levels.duplicate(true)
	check(Expedition.service("relic"),"buy persistent manual")
	check(Expedition.state.supplies==960 and Growth.free_available(Expedition.state),"manual costs 40 and grants current-stage use")
	check(not Expedition.service("relic") and Expedition.state.supplies==960,"duplicate relic cannot charge or reset allowance")
	check(not Expedition.service("training","GGI","a",0) and Growth.free_available(Expedition.state),"capped unit does not consume free allowance")
	check(Expedition.service("training","E1","a",0),"free attack and defense upgrade")
	check(Growth.level(Expedition.state,"E1","atk")==4 and Growth.level(Expedition.state,"E1","def")==4 and Expedition.state.supplies==960,"one free upgrade raises both tracks by one")
	check(not Expedition.service("training","MTNK","a",0) and Expedition.state.supplies==960,"stale free button cannot silently charge another unit")
	check(Expedition.load_run() and not Growth.free_available(Expedition.state),"used free allowance persists across reload")
	check(Expedition.service("training","E1","a",Growth.PRICE) and Expedition.state.supplies==960-Growth.PRICE,"additional upgrade charges training price")
	check(Growth.level(Expedition.state,"E1","atk")==5 and Growth.level(Expedition.state,"E1","def")==5,"attack does not exceed five while defense finishes")
	var balance:int=Expedition.state.supplies
	check(not Expedition.service("training","E1") and Expedition.state.supplies==balance,"capped upgrade charges nothing")
	next=Expedition.state.duplicate(true);next.stage=2;Expedition.ready(next);Expedition.commit(next)
	check(Growth.free_available(Expedition.state) and Expedition.service("training","MTNK","a",0),"next stage replenishes exactly one free use")
	next=Expedition.state.duplicate(true);Expedition.ready(next);Expedition.commit(next)
	check(not Growth.free_available(Expedition.state),"reopening current camp does not reset free use")
	next=Expedition.state.duplicate(true);next.stage=4;Expedition.ready(next);Expedition.commit(next)
	check(Expedition.service("training","MTNK","a",0) and not Growth.free_available(Expedition.state),"unused stages do not accumulate extra uses")
	for item:Dictionary in Market.relic_pool(Expedition.state):check(item.id!=Growth.RELIC,"owned manual removed from expanded random pool")
	for item:Dictionary in Market.growth_pool(Expedition.state):check(item.id!="E1" and item.id!="GGI","capped unit removed from upgrade candidates")
	check(MetaProgress.unit_levels==permanent,"upgrades and relic never write permanent levels")
	next=Expedition.state.duplicate(true)
	next.frozen.expedition_growth_disabled["MTNK:atk"]=true
	var attack_before:=Growth.level(next,"MTNK","atk")
	Growth.upgrade(next,"MTNK")
	check(Growth.level(next,"MTNK","atk")==mini(5,attack_before+1),"outside switch permits expedition upgrade")
	var offers:=Market.bonus_rewards(next)
	check(offers==Market.bonus_rewards(next),"additional relic candidate remains deterministic")

func check_combat_growth() -> void:
	MetaProgress.unit_levels={"E1":{"atk":10,"def":10},"GGI":{"atk":0,"def":0}}
	MetaProgress.unit_talents={"E1":{"native_deploy_def":3}}
	new_ready("美国",16)
	Expedition.state.unit_growth["AMCV"]={"atk":0,"def":3}
	var frozen:Dictionary=Expedition.state.frozen.duplicate(true)
	check(Expedition.launch(0),"launch folded growth battle")
	if not instantiate_battle():await finish();return
	var soldier=battle.spawn_unit("E1","ally",battle.player_start()+Vector2(400,100))
	var normal=battle.spawn_unit("GGI","ally",battle.player_start()+Vector2(450,100))
	var mcv=battle.spawn_unit("AMCV","ally",battle.player_start()+Vector2(600,300))
	var expected_yard_defense:float=BattleRequest.combat_bonuses().defense_bonus*Growth.actor_factor(mcv,"def")
	check(is_equal_approx(BattleRequest.unit_bonus("E1").attack_bonus,1.09) and is_equal_approx(BattleRequest.unit_bonus("E1").defense_bonus,1.075),"folded 3/5 consumes twelve outside levels")
	check(is_equal_approx(soldier.bonuses.attack_bonus,1.09) and is_equal_approx(soldier.bonuses.defense_bonus,1.075),"actual spawned unit consumes folded attack and defense")
	check(is_equal_approx(Training.scale(soldier),2.2),"native rank three remains independent")
	check(is_equal_approx(mcv.bonuses.defense_bonus,BattleRequest.combat_bonuses().defense_bonus*Growth.actor_factor(mcv,"def")),"base vehicle receives its own expedition defense level")
	battle.select_unit(mcv,false);battle._emit_selection()
	check(mcv.deploy(),"growth-trained base vehicle deploys into a building")
	var grown_yard=battle.selected_building
	check(is_instance_valid(grown_yard) and is_equal_approx(grown_yard.bonuses.defense_bonus,expected_yard_defense),"deployed construction yard retains unit-specific expedition defense")
	if is_instance_valid(grown_yard):grown_yard.special.growth_test_yard=true
	var hp_before:float=normal.max_hp
	Rules.apply_variant(normal,{"token":"growth-test","tier":3,"native_rank":2})
	check(Growth.actor_level(normal,"atk")==5 and is_equal_approx(normal.bonuses.attack_bonus,1.15) and is_equal_approx(normal.bonuses.defense_bonus,1.125),"special III uses same five-level attack and defense cap")
	check(is_equal_approx(normal.max_hp,hp_before),"removed training no longer adds a hidden HP multiplier")
	var statuses:Array=[];Rules.append_status(soldier,statuses)
	var rows:=0
	for status:Dictionary in statuses:
		if str(status.id).begins_with("expedition_growth_"):
			rows+=1;check(status.stacks==3 and status.limit==5,"HUD uses five-level track")
	check(rows==2,"HUD shows separate attack and defense levels")
	soldier.special.growth_test=true
	var prior_attack:float=soldier.bonuses.attack_bonus
	check(Expedition.checkpoint(battle),"checkpoint captures folded growth")
	await finish()
	MetaProgress.unit_levels.E1={"atk":20,"def":20}
	check(Expedition.load_run() and Expedition.prepare_battle(),"resume folded growth snapshot")
	if not instantiate_battle():await finish();return
	var restored=null
	for unit in battle.units:
		if unit.special.get("growth_test",false):restored=unit;break
	check(restored!=null and is_equal_approx(restored.bonuses.attack_bonus,prior_attack),"restore does not apply folded bonus twice")
	var restored_yard=null
	for building in battle.buildings:
		if building.special.get("growth_test_yard",false):restored_yard=building;break
	check(restored_yard!=null and is_equal_approx(restored_yard.bonuses.defense_bonus,expected_yard_defense),"saved deployed yard retains trained defense without stacking it twice")
	var produced=battle.spawn_unit("E1","ally",battle.player_start()+Vector2(550,100))
	check(is_equal_approx(produced.bonuses.attack_bonus,prior_attack),"units produced after restore use frozen levels")
	check(Expedition.state.frozen==frozen,"combat growth leaves source snapshot intact")
	await finish()
	MetaProgress.unit_levels.E1={"atk":10,"def":10}
	BattleRequest.configure_skirmish(MatchRules.EXTENDED,{"difficulty":1});BattleRequest.freeze_combat_context()
	check(is_equal_approx(BattleRequest.unit_bonus("E1").attack_bonus,1.075),"ordinary skirmish still consumes unrounded outside level")
