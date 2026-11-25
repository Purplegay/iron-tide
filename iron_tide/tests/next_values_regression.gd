extends "res://tests/base_recovery_regression.gd"
const Before=preload("res://tests/next_values_reference.gd")
const After=preload("res://scripts/units/expansion_rules.gd")
var micro:Array=[]
func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
	start(MatchRules.EXTENDED)
	var actor=battle.spawn_unit("MTNK","ally",Vector2(1100,1100));actor.process_mode=Node.PROCESS_MODE_DISABLED
	var queries:Array=[]
	for id in GameData.skill_index:
		var keys:Array=GameData.get_skill(id).get("values",{}).keys();keys.append("unknown_value")
		for key in keys:
			for side in ["ally","enemy"]:
				actor.side=side
				for rank in [-2,0,1,2,3,7]:
					BattleRequest.combat_context.card_ranks={id:rank}
					check(After.rank(actor,id)==Before.rank(actor,id) and After.value(actor,id,key)==Before.value(actor,id,key),"live rank/value fallback "+str([id,key,side,rank]))
			if key!="unknown_value":queries.append([id,key])
	actor.side="ally"
	BattleRequest.combat_context.erase("card_ranks")
	check(After.value(actor,"missing_card","unknown_value")==0 and After.rank(actor,"missing_card")==0,"old save without rank table remains valid")
	BattleRequest.combat_context.card_ranks={}
	for pair in queries:BattleRequest.combat_context.card_ranks[pair[0]]=3
	for sample in 18:
		var total:=0.0;var begun:=Time.get_ticks_usec()
		for i in 100:
			for pair in queries:total+=Before.value(actor,pair[0],pair[1]) if sample%2==0 else After.value(actor,pair[0],pair[1])
		micro.append({"variant":"before" if sample%2==0 else "after","us":Time.get_ticks_usec()-begun,"calls":100*queries.size(),"sum":total})
	await finish()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"micro":micro}))
	get_tree().quit(0 if failed==0 else 1)
