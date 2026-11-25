extends "res://tests/commando_hero_regression.gd"
const Pool=preload("res://scripts/rules/hero_contract_pool.gd")
const Q=preload("res://scripts/rules/expansion_contracts.gd")
var endings:=0
var last_result:Dictionary={}
var meta_events:=0

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
	await get_tree().process_frame
	Events.battle_ended.connect(on_ended)
	Events.meta_changed.connect(on_meta_changed)
	await failed_then_retry()
	await partial_replay()
	await result_modes()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	get_tree().quit(0 if failed==0 else 1)

func on_ended(result:Dictionary) -> void:
	endings+=1
	last_result=result

func on_meta_changed() -> void:
	meta_events+=1

func prepare() -> void:
	MetaProgress.reset_save()
	for id in ["TANY","BORIS","ORCA","TTNK"]:Pool.grant(MetaProgress,str(Pool.for_hero(id).id))
	boot("TANY")
	# Combat attribution is covered by the four contract suites. This fixture
	# supplies their completed match ledgers to test the real settlement boundary.
	for id in ["TANY","BORIS","ORCA","TTNK"]:
		var hero=battle.spawn_unit(id,"ally",Vector2(1000,1000));hero.special.academy_hero=id
		battle.allied_state.get_or_add("named_heroes",{})[id]=10
		var progress:=Q.progress(battle,id);progress.first=Q.GOALS[id][0];progress.second=Q.GOALS[id][1]
		progress.defenses=1;progress.sorties=2;progress.targets={"1":true,"2":true,"3":true}
	MetaProgress.save()

func failed_then_retry() -> void:
	prepare()
	var id:String=battle.match_id;var before:=MetaProgress.to_dict().duplicate(true)
	var codec=BattleSaves.Snapshot.new();var snapshot:Dictionary=codec.capture(battle)
	var file=FileAccess.open(output_dir.path_join("before-settlement.bin"),FileAccess.WRITE);file.store_var(snapshot,false);file.close()
	var bytes:=FileAccess.get_file_as_bytes(MetaProgress.SAVE_PATH);var count:=endings
	var notifications:=meta_events
	DirAccess.make_dir_absolute(MetaProgress.SAVE_PATH+".tmp")
	battle.end_battle(true)
	check(not battle.ended and endings==count,"failed persistence does not finalize battle or publish reward UI")
	check(MetaProgress.academy==before.academy and MetaProgress.unlocked_skills==before.unlocked_skills,"failed persistence rolls back all four contracts and card grants")
	check(MetaProgress.stats==before.stats and MetaProgress.currency==before.currency and MetaProgress.settled_matches==before.settled_matches and MetaProgress.owned_cosmetics==before.owned_cosmetics,"failed persistence rolls back receipts, currency, statistics and cosmetic grants")
	check(FileAccess.get_file_as_bytes(MetaProgress.SAVE_PATH)==bytes,"failed settlement preserves original profile bytes")
	check(meta_events==notifications,"failed settlement never publishes transient reward notifications")
	DirAccess.remove_absolute(MetaProgress.SAVE_PATH+".tmp")
	battle.end_battle(true)
	check(battle.ended and endings==count+1,"same battle retries successfully once storage is writable")
	check(meta_events==notifications+1,"successful atomic settlement publishes one progression notification")
	MetaProgress.load_save()
	for hero in ["TANY","BORIS","ORCA","TTNK"]:
		check(MetaProgress.academy.hero_contracts[hero].complete,"real settlement persists contract "+hero)
		for card in Pool.for_hero(hero).cards:check(card in MetaProgress.unlocked_skills,"real settlement persists earned card "+card)
	check(MetaProgress.settled_matches.has(id) and MetaProgress.stats.player_production.settled.has(id) and MetaProgress.academy.hero_contract_settled.has(id),"all settlement receipts persist together")
	var saved:=MetaProgress.to_dict().duplicate(true)
	await finish()
	boot("TANY")
	file=FileAccess.open(output_dir.path_join("before-settlement.bin"),FileAccess.READ);snapshot=file.get_var(false);file.close()
	codec.restore(battle,snapshot)
	check(codec.error.is_empty() and battle.match_id==id,"real binary battle snapshot restores original settlement identity")
	battle.end_battle(true)
	check(MetaProgress.academy==saved.academy and MetaProgress.currency==saved.currency and MetaProgress.stats==saved.stats and MetaProgress.unlocked_skills==saved.unlocked_skills,"replayed match never duplicates progress or rewards")
	await finish()

func result_modes() -> void:
	for mode in ["loss","draw","classic","forced","midmatch"]:
		prepare()
		if mode=="classic":BattleRequest.rules_mode=MatchRules.RA2
		if mode=="midmatch":BattleRequest.combat_context.hero_contracts={}
		var funds:=MetaProgress.currency.duplicate(true);var prior:=endings
		battle.end_battle(mode!="loss",mode=="draw",mode=="forced")
		check(battle.ended and endings==prior+1,"real end emits exactly one result: "+mode)
		if mode in ["draw","classic"]:check(last_result.rewards.is_empty() and MetaProgress.currency.credits==funds.credits and MetaProgress.currency.cores==funds.cores,"no extension battle currency for "+mode)
		else:check(last_result.rewards.get("credits",0)>0 and MetaProgress.settled_matches.has(battle.match_id),"normal reward and receipt survive "+mode)
		MetaProgress.load_save()
		for hero in ["TANY","BORIS","ORCA","TTNK"]:
			check(not MetaProgress.academy.hero_contracts[hero].complete,"nonqualifying result cannot grant victory contract: "+mode+" "+hero)
		var stable:=MetaProgress.academy.duplicate(true);prior=endings;battle.end_battle(true)
		check(endings==prior and MetaProgress.academy==stable,"already ended battle ignores duplicate result: "+mode)
		await finish()

func partial_replay() -> void:
	prepare()
	# Keep progress below its cap: otherwise a duplicate addition is hidden by min().
	for id:String in ["TANY","BORIS","ORCA","TTNK"]:
		var p:=Q.progress(battle,id);p.first=1;p.second=100 if id=="TTNK" else 1
		var equipment:=Loadouts.effective(MetaProgress,id)
		check(equipment.passive.is_empty() and equipment.active.all(func(card):return str(card).is_empty()),"contract progress needs no equipped reward card "+id)
	var codec=BattleSaves.Snapshot.new();var snapshot:Dictionary=codec.capture(battle)
	var path:=output_dir.path_join("partial-before-settlement.bin")
	var file=FileAccess.open(path,FileAccess.WRITE);file.store_var(snapshot,false);file.close()
	battle.end_battle(false);MetaProgress.load_save()
	for id:String in ["TANY","BORIS","ORCA","TTNK"]:
		var quest:Dictionary=MetaProgress.academy.hero_contracts[id]
		check(quest.first==1 and quest.second==(100 if id=="TTNK" else 1) and not quest.win and not quest.complete,"loss durably adds partial progress without victory or cards "+id)
	var saved:=MetaProgress.to_dict().duplicate(true)
	await finish();boot("TANY")
	file=FileAccess.open(path,FileAccess.READ);snapshot=file.get_var(false);file.close();codec.restore(battle,snapshot)
	check(codec.error.is_empty(),"partial-progress pre-settlement binary snapshot restores")
	battle.end_battle(true);MetaProgress.load_save()
	var changes:Dictionary={}
	for key in MetaProgress.academy:
		if MetaProgress.academy[key]!=saved.academy.get(key):changes[key]={"before":saved.academy.get(key),"after":MetaProgress.academy[key]}
	check(MetaProgress.academy==saved.academy and MetaProgress.unlocked_skills==saved.unlocked_skills,"restored partial match replay neither adds counters nor upgrades loss to victory",changes)
	await finish();boot("TANY")
	for id:String in ["TANY","BORIS","ORCA","TTNK"]:
		var p:=Q.progress(battle,id);p.first=1;p.second=100 if id=="TTNK" else 1
	battle.end_battle(false);MetaProgress.load_save()
	for id:String in ["TANY","BORIS","ORCA","TTNK"]:
		var quest:Dictionary=MetaProgress.academy.hero_contracts[id]
		check(quest.first==2 and quest.second==(200 if id=="TTNK" else 2) and not quest.complete,"independent next match legitimately adds partial progress once "+id)
	await finish()
