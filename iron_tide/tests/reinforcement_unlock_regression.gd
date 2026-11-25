extends "res://tests/leizhu_base_regression.gd"
const Peregrine=preload("res://scripts/units/peregrine.gd")

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
	await get_tree().process_frame
	await aircraft_threshold()
	await tank_threshold()
	await locked_training()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"screenshots":0},"  "))
	get_tree().quit(0 if failed==0 else 1)

func paid(producer,id:String) -> Array:
	var before:Array=battle.units.duplicate()
	var queued:bool=producer.enqueue(id)
	check(queued,"real production accepts "+id,producer.queue_block_reason(id))
	if not queued:return []
	for step in 2400:
		if producer.production.is_empty():break
		producer._process(.1)
	check(producer.production.is_empty(),"paid production completes "+id)
	return battle.units.filter(func(u):return not before.has(u))

func airport():
	var pad=battle._place_building("GAAIRC","ally",Vector2(1100,1600),true)
	pad._buildup_play=-1
	return pad

func has_plane() -> bool:
	return battle.units.any(func(u):return Peregrine.active(u))

func aircraft_threshold() -> void:
	MetaProgress.reset_save();MetaProgress.academy.hero_builds={"ORCA":3,"TTNK":0}
	boot("BORIS");var producer=factory();var pad=airport()
	check(not BattleRequest.combat_context.reinforcement_hero_unlocked.ORCA,"fresh match freezes locked aircraft eligibility")
	check(paid(producer,"SCHP").size()==1 and A.hero_build_count(MetaProgress,"ORCA")==3,"Soviet helicopter retains product without unlock credit")
	for i in 2:
		var id:="ORCA"
		var added:=paid(pad if id=="ORCA" else producer,id)
		check(added.size()==1 and not has_plane(),"first five mixed aircraft do not grant hero in unlocking match "+str(i))
		check(A.hero_build_count(MetaProgress,"ORCA")==i+4,"qualifying aircraft adds one permanent count "+str(i))
		if not added.is_empty():
			Gifts.produced(battle,pad if id=="ORCA" else producer,added[0])
			A.built(MetaProgress,battle,id,added[0],pad if id=="ORCA" else producer)
			check(A.hero_build_count(MetaProgress,"ORCA")==i+4,"duplicate production callback cannot add permanent progress")
	check(paid(producer,"SCHP").size()==1 and not has_plane(),"sixth aircraft still cannot activate this match")
	MetaProgress.load_save();check(A.hero_build_count(MetaProgress,"ORCA")==5,"five-aircraft unlock persists in actual profile")
	var codec=BattleSaves.Snapshot.new();var snap:Dictionary=codec.capture(battle)
	codec.restore(battle,snap)
	check(codec.error.is_empty() and not BattleRequest.combat_context.reinforcement_hero_unlocked.ORCA,"restoring unlocking match keeps original locked eligibility")
	producer=battle.buildings.filter(func(b):return b.building_id=="NAWEAP" and b.side=="ally")[0]
	check(paid(producer,"SCHP").size()==1 and not has_plane(),"post-restore aircraft cannot bypass frozen gate")
	await finish();boot("TANY");pad=airport()
	check(BattleRequest.combat_context.reinforcement_hero_unlocked.ORCA,"next match freezes unlocked eligibility")
	check(paid(pad,"ORCA").size()==2 and has_plane(),"next-match first aircraft retains product plus hero")
	await finish()

func tank_threshold() -> void:
	MetaProgress.reset_save();MetaProgress.academy.hero_builds={"TTNK":4,"ORCA":0}
	boot("BORIS");var producer=factory()
	for i in 3:
		check(queue_tank(producer).size()==1 and get_hero()==null,"fifth through seventh tank do not grant before next match "+str(i))
	check(A.hero_build_count(MetaProgress,"TTNK")==7,"Tesla production increments permanent progress once")
	MetaProgress.load_save();check(A.hero_build_count(MetaProgress,"TTNK")==7,"Tesla permanent unlock survives profile reload")
	var codec=BattleSaves.Snapshot.new();var snapshot:Dictionary=codec.capture(battle)
	codec.restore(battle,snapshot)
	check(codec.error.is_empty() and not BattleRequest.combat_context.reinforcement_hero_unlocked.TTNK,"battle restore preserves locked opening qualification")
	await finish();boot("BORIS");producer=factory()
	for i in 3:check(queue_tank(producer).size()==(2 if i==2 else 1),"unlocked next match still requires exact third tank "+str(i))
	check(get_hero()!=null,"third next-match tank grants LeiZhu")
	await finish()

func locked_training() -> void:
	MetaProgress.reset_save();MetaProgress.academy.hero_builds={"ORCA":4,"TTNK":4}
	MetaProgress.currency={"credits":100000,"cores":100000}
	var page=load("res://scripts/ui/hero_progression.gd").new();add_child(page)
	for id in ["ORCA","TTNK"]:
		page.selected=id;page.refresh()
		check(page.escort.disabled and page.survival.disabled and page.firepower.disabled and page.health.disabled,"locked hero cannot train or buy talents "+id)
		var wallet:Dictionary=MetaProgress.currency.duplicate()
		for action in ["escort","survival","firepower","health"]:check(not A.purchase(MetaProgress,action,id),"actual purchase enforces prerequisite "+id+action)
		check(MetaProgress.currency==wallet,"rejected upgrades charge nothing "+id)
		MetaProgress.academy.hero_builds[id]=5;page.refresh()
		check(not page.escort.disabled and not page.survival.disabled and not page.firepower.disabled and not page.health.disabled,"fifth production enables training controls "+id)
		check(A.purchase(MetaProgress,"escort",id),"unlocked hero can purchase implemented talent "+id)
	page.free();await get_tree().process_frame
