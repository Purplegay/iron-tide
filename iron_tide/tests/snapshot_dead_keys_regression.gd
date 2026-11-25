extends "res://tests/base_recovery_regression.gd"

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
	await get_tree().process_frame
	for mode in [MatchRules.RA2,MatchRules.EXTENDED]:
		start(mode)
		var live=battle.spawn_unit("HTNK","enemy",Vector2(1100,1200))
		var attacker=battle.spawn_unit("SHK","ally",Vector2(1200,1200))
		var calls:Dictionary={}
		for i in 4:
			var dead=Node.new()
			calls[dead]={"target":attacker,"until":6.0}
			dead.free()
		calls[live]={"target":attacker,"until":3.25}
		battle.allied_state.ai_air_distress=calls
		# Exercise nested dictionaries, object values, ordinary keys and repeated aliases.
		var expired=Node.new()
		battle.allied_state.snapshot_values={"dead_value":expired,"list":[calls],7:"integer",Vector2(3,4):"vector"}
		expired.free()
		var codec=BattleSaves.Snapshot.new()
		var snapshot=codec.capture(battle)
		check(codec.error.is_empty(),prefix+"capture completes with four freed object keys")
		check(calls.size()==5,prefix+"capture does not mutate live dictionary")
		var path=output_dir.path_join("dead-keys-"+mode+".bin")
		FileAccess.open(path,FileAccess.WRITE).store_var(snapshot)
		var stored=FileAccess.open(path,FileAccess.READ).get_var()
		codec.restore(battle,stored)
		check(codec.error.is_empty(),prefix+"binary graph restores")
		var restored:Dictionary=battle.allied_state.ai_air_distress
		check(restored.size()==1,prefix+"freed actor keys omitted")
		var survivor=restored.keys()[0]
		check(survivor.unit_id=="HTNK" and battle.units.has(survivor),prefix+"live key remaps to restored actor")
		check(restored[survivor].target.unit_id=="SHK" and battle.units.has(restored[survivor].target) and restored[survivor].until==3.25,prefix+"live target and lifetime preserved")
		var values:Dictionary=battle.allied_state.snapshot_values
		check(values.dead_value==null and values.list[0].size()==1,prefix+"nested dead values null and dead keys omitted")
		check(values[7]=="integer" and values[Vector2(3,4)]=="vector",prefix+"non-object dictionary keys unchanged")
		var again=codec.capture(battle)
		codec.restore(battle,again)
		check(codec.error.is_empty() and battle.allied_state.ai_air_distress.size()==1,prefix+"repeated capture restore stays bounded")
		await finish()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	print("SNAPSHOT_DEAD_KEYS ",checks.size()," checks, ",failed," failed")
	get_tree().quit(0 if failed==0 else 1)
