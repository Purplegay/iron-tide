extends "res://tests/base_recovery_regression.gd"
const Reference=preload("res://tests/search_weapon_reference.gd")

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2);return
	for mode in [MatchRules.RA2,MatchRules.EXTENDED]:
		start(mode);battle.fog=null
		for id in ["HTNK","E1","JUMPJET","E2","MTNK"]:
			var foe=battle.spawn_unit(id,"enemy",Vector2(1000+checks.size(),1000))
			foe.set_physics_process(false)
		for id in ["MTNK","HTNK","E1","GGI","SREF","BFRT","APOC","DRED","DEST","GHOST","FV","BORIS","SQD","CLEG","MGTK"]:
			var before=Reference.new();before.setup(GameData.get_unit(id),"ally",Vector2(900,900));battle.add_child(before);before.set_physics_process(false)
			var after=Unit.new();after.setup(GameData.get_unit(id),"ally",Vector2(900,900));battle.add_child(after);after.set_physics_process(false)
			for rank in [0,2]:
				for deployed in [false,true]:
					for stance in ["free","defend","return","none"]:
						for actor in [before,after]:
							actor.veteran_level=rank;actor._deployed=deployed;actor._refresh_veteran_bonuses(false)
							actor.attack_target=null;actor.attack_ordered=false;actor.fire_stance=stance
							actor._refresh_target()
						check(before.attack_target==after.attack_target,"same chosen target "+str([id,rank,deployed,stance]))
			before.free();after.free()
		await finish()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	get_tree().quit(0 if failed==0 else 1)
