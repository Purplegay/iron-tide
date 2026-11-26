extends "res://tests/special_mechanics_regression.gd"
const Reference=preload("res://tests/six_traffic_reference.gd")
var micro:Array=[]
func _ready():
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2);return
	await get_tree().process_frame
	for mode in [MatchRules.RA2,MatchRules.EXTENDED]:
		arena(mode)
		BattleRequest.house_teams={"ally":1,"enemy":2,"ai2":1}
		var unit=battle.spawn_unit("MTNK","enemy",Vector2(1100,1100))
		unit.move_target=unit.position+Vector2(500,0)
		unit.has_move_order=false
		for i in 160:
			var peer=battle.spawn_unit("E1" if i%3==0 else "MTNK",["ally","enemy","ai2"][i%3],unit.position+Vector2((i%16-8)*36,(i/16-5)*36))
			peer.order_guard()
			peer.velocity=Vector2.ZERO
		var probe=Reference.new()
		for owner in ["ally","enemy","ai2"]:
			unit.side=owner
			for speed in [0.0,30.0,150.0]:
				for angle in [0.0,1.0,3.0,5.0]:
					var velocity:Vector2=Vector2.from_angle(angle)*speed
					probe.reset();unit.velocity=velocity
					probe.original_apply(unit,1.0/15)
					var expected:Vector2=unit.velocity
					var contacts:Array=probe.nearby.duplicate()
					probe.reset();unit.velocity=velocity
					probe.apply(unit,1.0/15)
					check(unit.velocity.is_equal_approx(expected) and probe.nearby==contacts,mode+owner+str(speed)+str(angle)+" same ordered candidates and separation")
		unit.side="enemy"
		var infantry=battle.spawn_unit("E1","enemy",unit.position)
		infantry.move_target=unit.move_target
		for owner in ["ally","enemy","ai2"]:
			infantry.side=owner
			for velocity in [Vector2.ZERO,Vector2(150,0),Vector2(0,-90)]:
				probe.reset();infantry.velocity=velocity
				probe.original_apply(infantry,1.0/15)
				var expected:Vector2=infantry.velocity
				var blockers:Array=probe.stalled_blockers(infantry,infantry.move_target)
				infantry.velocity=velocity
				probe.apply(infantry,1.0/15)
				check(infantry.velocity==expected and probe.stalled_blockers(infantry,infantry.move_target)==blockers,mode+owner+str(velocity)+" infantry no-op preserves movement/blockers")
				check(probe.nearby.is_empty() and not probe.query_origin.is_finite(),mode+" infantry invalidates unused query before any role change")
		measure(probe,unit,mode,"vehicle")
		measure(probe,infantry,mode,"infantry")
		await finish()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"micro":micro}))
	get_tree().quit(0 if failed==0 else 1)

func measure(probe,unit,mode:String,kind:String):
		for pass_index in 16:
			var begin:=Time.get_ticks_usec()
			for i in 1500:
				unit.velocity=Vector2(150,0)
				if pass_index%2==0:probe.original_apply(unit,1.0/15)
				else:probe.apply(unit,1.0/15)
			micro.append({"basis":"same-engine-frame calls; not a runtime speedup estimate","mode":mode,"kind":kind,"variant":"before" if pass_index%2==0 else "after","us":Time.get_ticks_usec()-begin})
