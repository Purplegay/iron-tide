extends "res://tests/base_recovery_regression.gd"
const Fixture=preload("res://tests/next_sprite_actor.gd")
var micro:Array=[]
func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
	start(MatchRules.EXTENDED)
	for id in ["MTNK","HTNK","APOC","TTNK","SREF","FV","MGTK","BFRT","E1","E2","GGI","SHK","ORCA","BEAG","DEST","CARRIER"]:
		var unit=Fixture.new();unit.setup(GameData.get_unit(id),"ally",Vector2(1100,1100));battle.add_child(unit);unit.process_mode=Node.PROCESS_MODE_DISABLED
		unit.queue_redraw();await get_tree().process_frame;await get_tree().process_frame
		check(unit.completed and unit.mismatches.is_empty(),id+" complete draw preserves pose, selection and hit geometry",unit.mismatches)
		for row in unit.micro:check(row.sprites>=row.calls,id+" measures real sprite draws")
		micro.append_array(unit.micro);unit.free()
	await finish()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"micro":micro}))
	get_tree().quit(0 if failed==0 else 1)
