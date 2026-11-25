extends "res://tests/base_recovery_regression.gd"
const Before=preload("res://tests/progression_alloc_reference.gd")
const After=preload("res://scripts/units/progression_expansion.gd")
func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2);return
	start(MatchRules.EXTENDED);battle.fog=null
	var target=battle.spawn_unit("HTNK","enemy",Vector2(950,900))
	for id in ["MTNK","E1","HTNK","CMIN"]:
		var unit=battle.spawn_unit(id,"enemy",Vector2(900,900))
		var states=[null,{}, {"speed_bonus":0.3},{"move_lock":true},{"afterburn":{"speed":0.5}}, {"succession":true},{"taunt":target},{"dive":true},{"arc_count":4,"shot_idle":2.0}]
		for state in states:
			unit.special.erase("progression_v1")
			if state!=null:unit.special.progression_v1=state.duplicate(true)
			var original=unit.special.duplicate(true)
			check(Before.speed(unit)==After.speed(unit),"same speed "+str([id,state]))
			check(Before.target_allowed(unit,target)==After.target_allowed(unit,target),"same target gate")
			check(unit.special==original,"read-only queries preserve missing and existing state")
		unit.special.erase("progression_v1")
		var original=unit.special.duplicate(true)
		var result_before=Before.tick(unit,0.1)
		var expected=unit.special.duplicate(true);var expected_speed=unit.move_speed;var expected_bonus=unit.bonuses.duplicate(true)
		unit.special=original
		check(After.tick(unit,0.1)==result_before and unit.special==expected and unit.move_speed==expected_speed and unit.bonuses==expected_bonus,"same tick result and bookkeeping "+id)
		unit.free()
	await finish()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	get_tree().quit(0 if failed==0 else 1)
