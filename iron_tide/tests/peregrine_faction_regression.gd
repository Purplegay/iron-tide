extends "res://tests/peregrine_base_regression.gd"

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
	await get_tree().process_frame
	await soviet_production()
	await ai_production()
	await pending_restore()
	await country_matrix()
	await expedition_scope()
	await actual_production()
	await gift_after_reload()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	print("PEREGRINE_FACTION_RESULT ",checks.size()," checks, ",failed," failed")
	get_tree().quit(0 if failed==0 else 1)

func paid(producer,id:String) -> Array:
	var before:Array=battle.units.duplicate();var funds:float=battle.funds_for(producer.side)
	var accepted:bool=producer.enqueue(id)
	check(accepted,"real paid production accepted: "+producer.side+"/"+id,producer.queue_block_reason(id))
	if not accepted:return []
	for i in 4000:
		if producer.production.is_empty():break
		producer._process(.1)
	check(producer.production.is_empty(),"real production completes: "+id)
	check(is_equal_approx(funds-battle.funds_for(producer.side),battle.production_price(GameData.get_unit(id),producer.side)),"ordinary aircraft charged exactly once: "+id)
	return battle.units.filter(func(u):return u not in before)

func soviet_production() -> void:
	MetaProgress.reset_save();boot("BORIS")
	var factory=battle._place_building("NAWEAP","ally",Vector2(1400,1300),true)
	for id in ["NAPOWR","NAREFN","NAHAND","NARADR","NATECH"]:
		var building=battle._place_building(id,"ally",Vector2(1700,800)+Vector2(0,["NAPOWR","NAREFN","NAHAND","NARADR","NATECH"].find(id)*180),true)
		building._buildup_play=-1
	factory._buildup_play=-1;battle._update_power()
	var added:=paid(factory,"SCHP")
	check(added.size()==1 and added[0].unit_id=="SCHP" and get_hero()==null,"Soviet helicopter production keeps paid product without gifting Peregrine")
	check(not battle.allied_state.get(Gifts.KEY,{}).has("ally"),"Soviet production cannot create a deferred Peregrine gift")
	var aircraft=battle.spawn_unit("ORCA","ally",Vector2(1000,1000))
	P.promote(MetaProgress,battle,aircraft)
	check(not aircraft.special.has("academy_hero"),"direct promotion also rejects Soviet owner of an Allied aircraft")
	await finish()

func ai_production() -> void:
	MetaProgress.reset_save();boot("TANY")
	var pad=airport("enemy");battle._update_power()
	var added:=paid(pad,"ORCA")
	check(added.size()==1 and not added[0].special.has("academy_hero"),"Allied AI paid aircraft receives no hero")
	BattleRequest.house_teams={"ally":1,"enemy":2,"ai2":1,"ai3":2,"ai4":1,"ai5":2}
	for side in ["enemy","ai2","ai3","ai4","ai5"]:
		var factory=airport(side)
		var aircraft=battle.spawn_unit("ORCA",side,Vector2(1000,1100))
		Gifts.produced(battle,factory,aircraft);P.promote(MetaProgress,battle,aircraft)
		check(not aircraft.special.has("academy_hero") and not battle.allied_state.get(Gifts.KEY,{}).has(side),"both gifting and direct promotion reject AI house: "+side)
	await finish()

func pending_restore() -> void:
	for soviet in [false,true]:
		MetaProgress.reset_save();boot("BORIS" if soviet else "TANY")
		var rows:Dictionary={}
		for side in (["ally","enemy","ai2"] if soviet else ["enemy","ai2"]):
			rows[side]={"origin":Vector2(1200,1200),"pending":true,"retry":0.0}
		battle.allied_state[Gifts.KEY]=rows
		var codec=BattleSaves.Snapshot.new();var path:=output_dir.path_join("pending-"+str(soviet)+".bin")
		var file=FileAccess.open(path,FileAccess.WRITE);file.store_var(codec.capture(battle),false);file.close()
		file=FileAccess.open(path,FileAccess.READ);var snapshot=file.get_var(false);file.close();codec.restore(battle,snapshot)
		check(codec.error.is_empty(),"pending ledger binary restore: "+str(soviet))
		var count:int=battle.units.size();Gifts.tick(battle,1)
		check(battle.units.size()==count and get_hero()==null,"restored ineligible pending entries cannot spawn a hero")
		for side in rows:check(not battle.allied_state[Gifts.KEY][side].pending,"ineligible retry is retired: "+side)
		await finish()

func country_matrix() -> void:
	boot("TANY")
	for country:Dictionary in GameData.ra2_countries:
		if country.get("side") not in ["allied","soviet"]:continue
		for label in [str(country.id),str(country.get("display",""))]:
			BattleRequest.skirmish_config.country=label;BattleRequest.skirmish_config.houses=[]
			check(P.eligible_owner(battle,"ally")== (country.side=="allied"),"country identity grants only Allied player: "+label)
	BattleRequest.skirmish_config.country="美国"
	BattleRequest.skirmish_config.houses=[{"country":"苏俄"},{"country":"美国"}]
	check(not P.eligible_owner(battle,"ally"),"multihouse player country overrides stale top-level Allied country")
	BattleRequest.skirmish_config.houses=[{"country":"美国"},{"country":"苏俄"}]
	check(P.eligible_owner(battle,"ally") and not P.eligible_owner(battle,"enemy"),"multihouse Allied player qualifies while AI does not")
	for label in ["虫群巢穴","unknown"]:
		BattleRequest.skirmish_config.houses=[];BattleRequest.skirmish_config.country=label
		check(not P.eligible_owner(battle,"ally"),"unsupported faction cannot fall back to Allied eligibility: "+label)
	await finish()

func expedition_scope() -> void:
	var roster=preload("res://scripts/expedition/heroes.gd")
	var soviet:Dictionary={"country":"苏俄","stage":5,"heroes":[]}
	check("ORCA" not in roster.available(soviet) and not roster.recruit(soviet,"ORCA"),"Soviet expedition cannot recruit Peregrine")
	var allied:Dictionary={"country":"美国","stage":5,"heroes":[]}
	check(roster.recruit(allied,"ORCA") and roster.valid(allied),"Allied stage-five expedition can still recruit Peregrine")
