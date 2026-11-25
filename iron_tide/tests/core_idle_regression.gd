extends "res://tests/base_recovery_regression.gd"
const Before=preload("res://tests/core_idle_reference.gd")
const After=preload("res://scripts/units/unit_expansion_idle.gd")
var micro:Array=[]
func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2);return
	for mode in [MatchRules.RA2,MatchRules.EXTENDED]:
		start(mode)
		var actors:Array=[]
		for id in ["E1","GGI","MTNK","HTNK","MGTK","TTNK","APOC","SREF","FV","BEAG","DEST","CARRIER"]:
			for side in ["ally","enemy"]:
				var unit=battle.spawn_unit(id,side,Vector2(1100,1100))
				unit.process_mode=Node.PROCESS_MODE_DISABLED
				unit.passive={};actors.append(unit)
				for state in [{},{"progression_v1":{"shot_idle":3.0}},{"progression_v1":{"future_effect":true}},{"academy_hero":id},{"expansion_temporary":{}}]:
					unit.special=state.duplicate(true)
					var expected:bool=Before.try_tick(unit,0.1)
					var result:Dictionary=unit.special.duplicate(true)
					unit.special=state.duplicate(true)
					check(After.try_tick(unit,0.1)==expected and unit.special==result,"idle state equivalence "+str([mode,id,side,state]))
		var sums:Array=[]
		for sample in 14:
			for unit in actors:unit.special={"progression_v1":{"arc_count":0,"shot_idle":0.0}}
			var calls:=0
			var begun:=Time.get_ticks_usec()
			for i in 1000:
				for unit in actors:
					if Before.try_tick(unit,0.01) if sample%2==0 else After.try_tick(unit,0.01):calls+=1
			micro.append({"mode":mode,"variant":"before" if sample%2==0 else "after","us":Time.get_ticks_usec()-begun,"calls":24000})
			var total:=0.0
			for unit in actors:total+=unit.special.progression_v1.shot_idle
			sums.append([calls,total])
			check(calls>0 and total>0,"benchmark consumes updated state")
		for result in sums:check(result==sums[0],"all timings perform same bookkeeping")
		await finish()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"micro":micro}))
	get_tree().quit(0 if failed==0 else 1)
