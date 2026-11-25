extends "res://tests/base_recovery_regression.gd"
const Fixture=preload("res://tests/core_draw_reference.gd")
var micro:Array=[]
func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2);return
	start(MatchRules.EXTENDED)
	for id in ["E1","GGI","DESO","SHK","SPY","MTNK","HTNK","APOC","MGTK","TTNK","SREF","FV","ORCA","BEAG","DLPH","SQD","SUB","SCHP","CMIN","HARV"]:
		var unit=Fixture.new()
		unit.setup(GameData.get_unit(id),"ally",Vector2(1100,1100))
		battle.add_child(unit);unit.process_mode=Node.PROCESS_MODE_DISABLED
		unit.queue_redraw()
		await get_tree().process_frame
		await get_tree().process_frame
		check(unit.completed and unit.comparisons==24 and unit.mismatches.is_empty(),id+" actual drawing/anchor/picking geometry matches frozen renderer",unit.mismatches)
		micro.append_array(unit.micro)
		for row in unit.micro:check(row.sprites>=row.calls,"native sprite benchmark executes drawing")
		for span in [Vector4i(0,8,0,0),Vector4i(32,8,64,48),Vector4i(0,32,0,0),Vector4i(0,256,0,0),Vector4i(-1,1,0,0)]:
			var expected:Array=range(span.x,span.x+span.y)
			if span.w>0:expected.append_array(range(span.z,span.z+span.w))
			check(unit._anchor_frames(span.x,span.y,span.z,span.w)==expected,"live span switching preserves order and duplicate frames")
		if id=="MTNK":
			for span in [Vector4i(0,32,0,0),Vector4i(0,256,0,0),Vector4i(64,8,128,48)]:
				var checksum:=0
				for sample in 14:
					var begun:=Time.get_ticks_usec()
					for i in 10000:
						var frames:Array
						if sample%2==0:
							frames=range(span.x,span.x+span.y)
							if span.w>0:frames.append_array(range(span.z,span.z+span.w))
						else:frames=unit._anchor_frames(span.x,span.y,span.z,span.w)
						checksum+=frames.size()
					micro.append({"span":str(span),"variant":"before" if sample%2==0 else "after","us":Time.get_ticks_usec()-begun,"calls":10000})
				check(checksum==140000*(span.y+span.w),"benchmark consumes complete frame spans")
		unit.free()
	await finish()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"micro":micro}))
	get_tree().quit(0 if failed==0 else 1)
