extends "res://tests/base_recovery_regression.gd"
const Plan=preload("res://scripts/expedition/reinforcement_plan.gd")

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
	var run:Dictionary={"active_roster":["E1","MTNK","GHOST"],"licenses":["E1","MTNK","GHOST"],"reinforcements":[{"id":"E1","count":3},{"id":"MTNK","count":2}],"special_squads":[],"heroes":["GHOST"],"wounded_heroes":[],"survivors":[],"stage":10,"frozen":{"expedition_hero_profile":{"academy":{"hero_builds":{"GHOST":3}}}}}
	var plan:Array=Plan.build(run)
	check(plan.size()==6,"plan includes reserves and hero")
	var initial:=plan.filter(func(row):return bool(row.initial))
	check(initial.size()==2 and initial.all(func(row):return row.due==0.0),"one initial unit per type arrives immediately")
	check(plan[0].due<=plan[1].due and plan[-1].hero=="GHOST" and plan[-1].due==Plan.unit_cost("GHOST")/100.0*120.0+90.0,"cost order and hero level delay")
	for i in plan.size()-1:check(plan[i].due<=plan[i+1].due,"plan sorted by due time "+str(i))
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"plan":plan}))
	print("REINFORCEMENT_PLAN checks=",checks.size()," failed=",failed)
	get_tree().quit(0 if failed==0 else 1)
