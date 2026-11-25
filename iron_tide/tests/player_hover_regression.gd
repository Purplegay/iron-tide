extends "res://tests/base_recovery_regression.gd"
const Reference=preload("res://tests/player_hover_reference.gd")
var micro:Array=[]
func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2);return
	for mode in [MatchRules.RA2,MatchRules.EXTENDED]:
		start(mode)
		battle.fog=null
		var cursor=Reference.new();cursor.battle=battle
		for i in 96:
			battle.spawn_unit("MTNK","ally" if i%3!=0 else "enemy",Vector2(600+(i%12)*60,600+(i/12)*60))
		var tank=battle.units[1]
		var overlap=battle.spawn_unit("E1","enemy",tank.position)
		var plane=battle.spawn_unit("PDPLANE","ally",tank.position)
		for selection in [[],[tank],battle.units.filter(func(u):return u.side=="ally")]:
			battle.selected_units=selection
			for command in ["","move","attack","attack_move","patrol","repair","sell"]:
				battle.command_mode=command
				for actor in battle.units.slice(0,12)+[overlap,plane]:
					for point in [actor.position,actor.position+Vector2(0,20),Vector2(2200,2200)]:
						var before:String=cursor.original_sample_pointer(point)
						var after:String=cursor.sample_pointer(point)
						check(before==after,"hover %s/%s/%s/%s"%[mode,selection.size(),command,point])
		battle.units.erase(overlap);overlap.free();battle.units.erase(plane);plane.free()
		battle.selected_units=[];battle.command_mode=""
		for pass_index in 12:
			var began:=Time.get_ticks_usec()
			for i in 100:
				if pass_index%2==0:cursor.original_sample_pointer(tank.position)
				else:cursor.sample_pointer(tank.position)
			micro.append({"mode":mode,"variant":"before" if pass_index%2==0 else "after","samples":100,"units":96,"us":Time.get_ticks_usec()-began})
		cursor.free()
		await finish()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"micro":micro}))
	get_tree().quit(0 if failed==0 else 1)

