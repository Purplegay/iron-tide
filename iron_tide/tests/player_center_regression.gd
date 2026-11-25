extends "res://tests/base_recovery_regression.gd"
const Reference=preload("res://tests/player_center_reference.gd")
var micro:Array=[]
func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2);return
	for mode in [MatchRules.RA2,MatchRules.EXTENDED]:
		start(mode)
		for id in ["MTNK","E1","GGI","APOC","FV","CMIN","ORCA","SPY","MGTK","R3MIRAGE","AMCV","SMCV"]:
			var unit=Reference.new()
			unit.setup(GameData.get_unit(id),"ally",Vector2(1200,1200))
			battle.add_child(unit)
			unit.process_mode=Node.PROCESS_MODE_DISABLED
			for state in [{},{"disguise":"E1"},{"disguise":"TREE01"},{"disguise":"E1","reveal":1.0},{"mcv_repack_left":0.0},{"mcv_repack_left":1.0,"mcv_repack_image":"GACNST"}]:
				unit.special=state.duplicate(true)
				for frame in [-1,0,3]:
					unit._art_frame=frame
					unit._art_aframes=[0]
					for lift in [0.0,30.0]:
						unit._art_lift=lift
						check(unit._rest_art_center().is_equal_approx(unit.original_rest_art_center()),"center %s/%s/%s/%s"%[mode,id,state,frame])
			unit.special={};unit._art_frame=-1
			if id=="MTNK":
				for pass_index in 14:
					var began:=Time.get_ticks_usec()
					for i in 10000:
						if pass_index%2==0:unit.original_rest_art_center()
						else:unit._rest_art_center()
					micro.append({"mode":mode,"variant":"before" if pass_index%2==0 else "after","calls":10000,"us":Time.get_ticks_usec()-began})
			unit.free()
		await finish()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"micro":micro},"  "))
	get_tree().quit(0 if failed==0 else 1)
