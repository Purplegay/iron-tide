extends "res://tests/base_recovery_regression.gd"
const Reference=preload("res://tests/unit_pick_reference.gd")
var micro:=[]
func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2);return
	start(MatchRules.EXTENDED)
	battle.fog=null
	for id in ["MTNK","E1","GGI","APOC","FV","CMIN","ORCA","SPY","MGTK"]:
		var unit=Reference.new()
		unit.setup(GameData.get_unit(id),"ally",Vector2(1200,1200))
		battle.add_child(unit)
		unit._art_frame=-1
		for state in ["normal","dead","cargo","rocking"]:
			unit._dead=state=="dead";unit.embarked_in=unit if state=="cargo" else null
			unit._rock_t=0.1 if state=="rocking" else 0.0
			unit._rock_amp=0.3;unit._rock_dir=Vector2.RIGHT
			for displacement in [Vector2.ZERO,Vector2(20,30),Vector2(-100,70),Vector2(10000,-10000)]:
				unit.motion_pose.previous_position=unit.position-displacement
				for origin in [unit.position,unit.presentation_position(),unit.motion_pose.previous_position]:
					for distance in [0.0,unit.radius+9.999,unit.radius+10.0,unit.radius+10.001,500.0]:
						for direction in [Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN,Vector2(0.6,0.8)]:
							var point:Vector2=origin+direction*distance
							check(unit.hit_test(point)==unit.original_hit_test(point),"pick bound %s/%s/%s/%s"%[id,state,displacement,distance])
		unit._dead=false;unit.embarked_in=null;unit._rock_t=0.0
		if id=="MTNK":
			unit.motion_pose.capture(unit)
			for pass_index in 6:
				var began:=Time.get_ticks_usec()
				for i in 10000:
					if pass_index%2==0:unit.original_hit_test(Vector2.ZERO)
					else:unit.hit_test(Vector2.ZERO)
				micro.append({"variant":"before" if pass_index%2==0 else "after","calls":10000,"us":Time.get_ticks_usec()-began})
		unit.free()
	await finish()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"micro":micro},"  "))
	get_tree().quit(0 if failed==0 else 1)
