extends "res://tests/base_recovery_regression.gd"
const Actor = preload("res://tests/voxel_renderer_actor.gd")
var metrics: Array = []
func _ready() -> void:
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2); return
	start(MatchRules.EXTENDED)
	for id in ["APOC", "MTNK", "HTNK", "HTK", "FV", "TTNK", "SREF", "ZEP", "BFRT", "CMIN", "HARV", "SHAD", "ORCA", "BEAG"]:
		var actor = Actor.new()
		actor.setup(GameData.get_unit(id), "ally", Vector2(1100,1100))
		battle.add_child(actor)
		actor.process_mode = Node.PROCESS_MODE_DISABLED
		actor.queue_redraw()
		await get_tree().process_frame
		await get_tree().process_frame
		check(actor.completed and actor.comparisons == 797, id+" completed actual draw comparisons", actor.comparisons)
		check(actor.mismatches.is_empty(), id+" body/turret/shadow/picking exact geometry", actor.mismatches)
		check(actor.VoxelRenderer.resources.size()>0,id+" shared geometry resource pool populated")
		if id in ["APOC","MTNK","HTNK","HTK","FV","ZEP","BFRT","CMIN","ORCA","BEAG"]:
			check(actor.prepared_calls>0,id+" actual drawing uses prepared submissions",actor.prepared_calls)
		metrics.append({"unit": id, "comparisons": actor.comparisons, "cache": actor.micro})
		actor.free()
	await finish()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"metrics":metrics}))
	get_tree().quit(0 if failed==0 else 1)
