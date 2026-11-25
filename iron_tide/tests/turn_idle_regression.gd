extends "res://tests/base_recovery_regression.gd"
const Reference=preload("res://tests/turn_idle_reference.gd")
func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2);return
	start(MatchRules.EXTENDED);battle.fog=null
	for id in ["MTNK","HTNK","E1","DRED","SCHP","ORCA"]:
		var before=Reference.new();before.setup(GameData.get_unit(id),"enemy",Vector2(900,900));battle.add_child(before);before.set_physics_process(false)
		var after=Unit.new();after.setup(GameData.get_unit(id),"enemy",Vector2(900,900));battle.add_child(after);after.set_physics_process(false)
		for angle in [-TAU,-PI,-0.1,0.0,0.1,PI,TAU]:
			for change in [0.0,-0.00001,0.00001,-PI,PI]:
				for drive in [NAN,angle,angle+0.2]:
					for delta in [0.0,1.0/15.0,0.2]:
						for actor in [before,after]:
							actor._hull_prev=angle;actor._turret_prev=-angle
							actor.hull_angle=angle+change;actor.turret_angle=-angle-change
							actor._drive_heading=drive;actor._limit_turn(delta)
						check(before.hull_angle==after.hull_angle and before.turret_angle==after.turret_angle,"exact ROT output "+str([id,angle,change,drive,delta]))
		before.free();after.free()
	await finish()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	get_tree().quit(0 if failed==0 else 1)
