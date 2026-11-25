extends "res://tests/base_recovery_regression.gd"
const Counter = preload("res://scripts/units/ai_counterfire.gd")
const Reference = preload("res://tests/counterfire_reference.gd")

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2);return
	for mode in [MatchRules.RA2,MatchRules.EXTENDED]:
		start(mode)
		battle.fog=null
		var ground:Unit=battle.spawn_unit("HTNK","ally",Vector2(1200,1000))
		var air:Unit=battle.spawn_unit("JUMPJET","ally",Vector2(1200,1000))
		var structure:Building=battle._player_hq()
		var previous:Unit=battle.spawn_unit("E1","ally",Vector2(1300,1100))
		for id in ["MTNK","E1","APOC","BFRT","DRED","CLEG"]:
			var actor:Unit=battle.spawn_unit(id,"enemy",Vector2(1000,1000))
			for target in [ground,air,structure,null]:
				for distance in [1.0,200.0,1000.0]:
					if target!=null:target.position=actor.position+Vector2(distance,0)
					for resume in [false,true]:
						for timer in [0.0,3.0]:
							var state:Dictionary={"retaliation_target":target}
							if resume:state[Counter.RESUME]={"target":previous,"ordered":true}
							actor.special=state.duplicate(true);actor.attack_target=previous;actor.attack_ordered=true;actor._return_timer=timer
							var expected:bool=Reference.update(actor)
							var expected_target=actor.attack_target
							var expected_order:=actor.attack_ordered
							var expected_state:=actor.special.duplicate(true)
							actor.special=state.duplicate(true);actor.attack_target=previous;actor.attack_ordered=true;actor._return_timer=timer
							var result:=Counter.update(actor)
							check(result==expected and actor.attack_target==expected_target and actor.attack_ordered==expected_order and actor.special==expected_state,prefix+"counterfire query reordering preserves decision and resume "+id,{"distance":distance,"timer":timer,"resume":resume})
		await finish()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	get_tree().quit(0 if failed==0 else 1)
