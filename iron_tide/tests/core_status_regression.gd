extends "res://tests/base_recovery_regression.gd"
const Before=preload("res://tests/core_status_reference.gd")
var micro:Array=[]
func snapshot(actor) -> Array:
	return [actor.special.duplicate(true),actor.hp,actor.side,actor._dead]
func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2);return
	for mode in [MatchRules.RA2,MatchRules.EXTENDED]:
		start(mode)
		var target=battle.spawn_unit("E2","enemy",Vector2(1100,1100))
		target.process_mode=Node.PROCESS_MODE_DISABLED
		var actors:Array=[]
		for id in ["E1","GGI","MTNK","E2","MGTK"]:
			var unit=battle.spawn_unit(id,"ally",Vector2(1100,1100))
			unit.process_mode=Node.PROCESS_MODE_DISABLED;actors.append(unit)
		actors.append(battle._player_hq())
		for actor in actors:
			for state in [{},{"progression_v1":{"shot_idle":2.0}},{"blackout":0.1,"reveal":0.2,"chrono_left":0.3},{"blackout":0.0,"reveal":0.0,"chrono_left":0.0},{"controlled":null},{"controlled":target},{"temporal_by":null},{"temporal_by":target},{"controller":null,"original_side":"ally"},{"c4_left":1.0,"c4_owner":target},{"unknown_future_status":true}]:
				for dt in [0.0,0.15,0.4]:
					actor.special=state.duplicate(true);seed(111)
					Before.original_tick_actor(actor,dt)
					var expected:=snapshot(actor)
					actor.special=state.duplicate(true);seed(111)
					AlliedAbilities.tick_actor(actor,dt)
					check(snapshot(actor)==expected,"status timers/control/temporal/C4 match "+str([mode,actor.data.id,state,dt]))
		for actor in actors:actor.special={"progression_v1":{"shot_idle":2.0},"mirage_tree":"TREE01"}
		for sample in 14:
			var begun:=Time.get_ticks_usec()
			for i in 4000:
				for actor in actors:
					if sample%2==0:Before.original_tick_actor(actor,0.01)
					else:AlliedAbilities.tick_actor(actor,0.01)
			micro.append({"mode":mode,"variant":"before" if sample%2==0 else "after","us":Time.get_ticks_usec()-begun,"calls":24000})
			for actor in actors:check(actor.special.progression_v1.shot_idle==2.0 and actor.hp>0,"status timing preserves actor state")
		await finish()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"micro":micro}))
	get_tree().quit(0 if failed==0 else 1)
