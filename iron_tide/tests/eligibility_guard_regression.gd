extends "res://tests/base_recovery_regression.gd"
const R=preload("res://scripts/units/expansion_rules.gd")
const Air=preload("res://scripts/units/expansion_2_air.gd")
const Fire=preload("res://scripts/units/expansion_2_naval_fire.gd")
const Infiltration=preload("res://scripts/units/expansion_2_infiltration.gd")
var positives := [0,0,0,0]

# Frozen pre-optimization predicates: all state is read live on both paths.
func reference_air(unit) -> bool:
	return R.active(unit) and (Air.observes(unit) or (unit.unit_id=="JUMPJET" and R.talent_rank(unit,Air.HOVER)>=0))

func reference_fire(unit) -> bool:
	return R.active(unit) and ((unit.unit_id=="HYD" and unit.passive.get("id")==Fire.CROSS) or (unit.unit_id=="AEGIS" and R.talent_rank(unit,Fire.GAUGE)>=0))

func reference_infiltration(unit,id:String) -> bool:
	return unit is Unit and R.active(unit) and unit.passive.get("id")==id and unit.unit_id in (["GHOST"] if id==Infiltration.SHORE else ["GHOST","TANY","BORIS"])

func compare(unit, label: String) -> void:
	var before: Dictionary = unit.special.duplicate(true) if is_instance_valid(unit) else {}
	var expected := [reference_air(unit),reference_fire(unit),reference_infiltration(unit,Infiltration.SHORE),reference_infiltration(unit,Infiltration.ESCORT)]
	var actual := [Air.eligible(unit),Fire.eligible(unit),Infiltration.equipped(unit,Infiltration.SHORE),Infiltration.equipped(unit,Infiltration.ESCORT)]
	for i in actual.size():
		if actual[i]: positives[i]+=1
	check(actual==expected,"live eligibility: "+label,[expected,actual] if actual!=expected else null)
	check(not is_instance_valid(unit) or unit.special==before,"eligibility does not mutate saved state")

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
	await get_tree().process_frame
	var unit:=Unit.new()
	for mode in [MatchRules.RA2,MatchRules.EXTENDED]:
		BattleRequest.rules_mode=mode
		compare(null,"null "+mode)
		for row in GameData.units:
			unit.unit_id=row.id
			for side in ["ally","enemy","ai2","neutral"]:
				unit.side=side
				for rank in [-1,0,1,2,3]:
					BattleRequest.combat_context={"unit_talents":{} if rank<0 else {"JUMPJET":{Air.HOVER:rank},"AEGIS":{Fire.GAUGE:rank}}}
					for card in ["",Air.OBSERVE,Fire.CROSS,Infiltration.SHORE,Infiltration.ESCORT,"ps_module_shell"]:
						unit.passive={} if card.is_empty() else {"id":card}
						for state in 4:
							unit.hp=0.0 if state==1 else 100.0
							unit._dead=state==2
							unit.special={"expansion_temporary":true} if state==3 else {}
							compare(unit,"%s/%s/%s/%d/%s/%d"%[mode,row.id,side,rank,card,state])
	unit.free()
	for id in ["JUMPJET","SHAD","SCHP","HYD","AEGIS","GHOST","TANY","BORIS"]:
		var queued:=Unit.new()
		queued.unit_id=id;queued.hp=100;queued.side="ally"
		queued.passive={"id":Air.OBSERVE};queued.queue_free()
		compare(queued,"queued "+id)
	for count in positives:check(count>0,"positive branches exercised",positives)
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"positives":positives}))
	print("ELIGIBILITY_RESULT ",checks.size()," checks, ",failed," failed")
	get_tree().quit(0 if failed==0 else 1)
