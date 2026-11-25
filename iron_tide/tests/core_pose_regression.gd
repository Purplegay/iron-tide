extends "res://tests/base_recovery_regression.gd"
const Fixture=preload("res://tests/core_pose_reference.gd")
var micro:Array=[]
func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2);return
	start(MatchRules.EXTENDED)
	for id in ["MTNK","E1","GGI","SPY","MGTK","AMCV","SMCV"]:
		var unit=Fixture.new()
		unit.setup(GameData.get_unit(id),"ally",Vector2(1100,1100))
		battle.add_child(unit);unit.process_mode=Node.PROCESS_MODE_DISABLED
		unit.queue_redraw()
		await get_tree().process_frame
		await get_tree().process_frame
		check(unit.completed and unit.comparisons==14 and unit.mismatches.is_empty(),id+" draw dispatch preserves real sprite/selection/picking/state",unit.mismatches)
		micro.append_array(unit.micro)
		for row in unit.micro:check(row.sprites>=row.calls,"benchmark executes real sprite drawing")
		unit.free()
	await finish()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"micro":micro}))
	get_tree().quit(0 if failed==0 else 1)
