extends Node
const Subject=preload("res://scripts/units/progression_expansion_2.gd")
const Reference=preload("res://tests/expansion_dispatch_reference.gd")
var checks:=0
var failed:=0
var failures:Array=[]
var positive:=0
var negative:=0
var batches:Array=[]

func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:
		failed+=1
		if failures.size()<30:failures.append(label)

func compare(unit:Unit,label:String) -> void:
	var before:Dictionary=unit.special.duplicate(true)
	var expected:bool=Reference.eligible(unit)
	var actual:bool=Subject.eligible(unit)
	check(expected==actual,label)
	check(unit.special==before,"read-only "+label)
	if actual:positive+=1
	else:negative+=1

func _ready() -> void:
	var output:=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
	await get_tree().process_frame
	var cards:Array=["","ps_module_shell","ps_mirage_gap","unknown"]
	for skill in GameData.skills:
		if str(skill.id).begins_with("ps_") and not cards.has(skill.id):cards.append(skill.id)
	var talents:Dictionary={}
	for id in GameData.meta_config.unit_talents:
		var ranks:Dictionary={}
		for key in GameData.meta_config.unit_talents[id]:ranks[key]=3
		talents[id]=ranks
	var ids:Array=["UNKNOWN"]
	for row in GameData.units:ids.append(row.id)
	var unit:=Unit.new()
	for mode in [MatchRules.RA2,MatchRules.EXTENDED]:
		BattleRequest.rules_mode=mode
		for id in ids:
			unit.unit_id=id
			for side in ["ally","enemy","ai2","neutral"]:
				unit.side=side
				for trained in [false,true]:
					BattleRequest.combat_context={"unit_talents":talents if trained else {}}
					for card in cards:
						unit.passive={} if card.is_empty() else {"id":card}
						for state in 8:
							unit.hp=0.0 if state%4==1 else 100.0
							unit._dead=state%4==2
							unit.special={"expansion_temporary":true} if state%4==3 else {}
							if state>=4:unit.special[Subject.KEY]={"side":"enemy","observer_left":1.0}
							compare(unit,"%s/%s/%s/%s/%s/%d"%[mode,id,side,trained,card,state])
	check(positive>0 and negative>0,"both outcomes exercised")
	BattleRequest.rules_mode=MatchRules.EXTENDED
	BattleRequest.combat_context={"unit_talents":talents}
	unit.side="ally";unit.hp=100;unit._dead=false;unit.special={}
	for id in ids:
		var queued:=Unit.new()
		queued.unit_id=id;queued.side="ally";queued.hp=100
		queued.queue_free()
		for card in cards:
			queued.passive={"id":card}
			compare(queued,"queued %s/%s"%[id,card])
	# Same calls and identities, alternating order to expose local cost independently
	# of nondeterministic six-house trajectories. No timing assertion in regression.
	unit.passive={}
	BattleRequest.combat_context={}
	var sample_ids:Array=["E1","E2","SNIPE","FLAKT","FV","GGI","SREF","MGTK","SHK","HTK","DRON","V3","APOC","JUMPJET","SHAD","SCHP","HYD","AEGIS","SUB","MTNK","HTNK","GHOST","TANY","BORIS","ORCA","BEAG","DRED"]
	for batch in 8:
		var row:Dictionary={}
		for original in ([true,false] if batch%2==0 else [false,true]):
			var begin:=Time.get_ticks_usec()
			var count:=0
			for repeat in 1500:
				for id in sample_ids:
					unit.unit_id=id
					if Reference.eligible(unit) if original else Subject.eligible(unit):count+=1
			row["original_us" if original else "candidate_us"]=Time.get_ticks_usec()-begin
			row["original_positive" if original else "candidate_positive"]=count
		check(row.original_positive==row.candidate_positive,"timed batch outcomes")
		batches.append(row)
	unit.free()
	FileAccess.open(output.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"check_count":checks,"failed":failed,"failures":failures,"positive":positive,"negative":negative,"batches":batches}))
	print("DISPATCH_RESULT ",checks," checks, ",failed," failed ",failures)
	get_tree().quit(0 if failed==0 else 1)
