extends "res://tests/base_recovery_regression.gd"
const Reference=preload("res://tests/skill_eligibility_reference.gd")
var micro:Array=[]
func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2);return
	var ids:Array=GameData.unit_index.keys()+GameData.building_index.keys()+["unknown"]
	var cards:Array=["","unknown","ap_deploy"]
	for card in GameData.skills:cards.append(card.id)
	for id in ids:
		for card in cards:
			for hero in [false,true]:
				check(UnitSkillLayout.equippable(id,card,hero)==Reference.equippable(id,card,hero),"W eligibility %s/%s/%s"%[id,card,hero])
	for pass_index in 14:
		var began:=Time.get_ticks_usec()
		for i in 10000:
			for pair in [["E1","allied_deploy"],["GGI","ggi_guard"],["GGI","ggi_deploy"],["E1","ap_focus_fire"],["MTNK","ap_tracer_mark"],["SHK","ap_tesla_chain"]]:
				if pass_index%2==0:Reference.equippable(pair[0],pair[1])
				else:UnitSkillLayout.equippable(pair[0],pair[1])
		micro.append({"variant":"before" if pass_index%2==0 else "after","calls":60000,"us":Time.get_ticks_usec()-began})
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"micro":micro}))
	get_tree().quit(0 if failed==0 else 1)
