extends "res://tests/base_recovery_regression.gd"
var before_candidates:=0
var after_candidates:=0
func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2);return
	start(MatchRules.EXTENDED)
	for i in 36:
		battle.spawn_unit("MTNK","ally" if i%2==0 else "enemy",Vector2(500+(i%6)*125,500+(i/6)*125))
	for phase in 5:
		var unit:Unit=battle.units[0]
		if phase==1:unit.global_position=Vector2(256,256)
		if phase==2:unit.global_position=Vector2(-0.01,1024)
		if phase==3:
			battle.remove_child(unit)
		if phase==4:
			battle.add_child(unit)
			unit.global_position=Vector2(2048,2048)
		for point in [Vector2.ZERO,Vector2(256,256),Vector2(750,750),Vector2(2400,2400)]:
			for reach in [0.0,0.01,255.0,256.0,1000.0,INF]:
				var all:Array=battle.neighborhood.nearby(point,reach)
				var actual:Array=battle.neighborhood.nearby(point,reach,true)
				var expected:Array=[]
				for actor in all:
					if actor is Unit:expected.append(actor)
				before_candidates+=all.size();after_candidates+=actual.size()
				check(actual==expected,"unit-only index preserves candidates and order %s/%s/%s"%[phase,point,reach])
	check(after_candidates<before_candidates,"movement queries omit structure visits",{"before":before_candidates,"after":after_candidates})
	await finish()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	get_tree().quit(0 if failed==0 else 1)
