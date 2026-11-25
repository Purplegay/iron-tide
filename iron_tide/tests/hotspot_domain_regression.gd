extends "res://tests/base_recovery_regression.gd"
const Reference=preload("res://tests/hotspot_domain_reference.gd")
const OldDistance=preload("res://tests/hotspot_distance_reference.gd")
func make(id:String,old:bool) -> Unit:
	var u:Unit=Reference.new() if old else Unit.new()
	u.setup(GameData.get_unit(id).duplicate(true),"ally",Vector2(900,900))
	u._combat_world=battle;battle.add_child(u);battle.units.append(u)
	u.set_physics_process(false);u.fire_stance="free"
	return u
func discard(u:Unit):
	battle.units.erase(u);u.free()
func _ready():
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2);return
	for mode in [MatchRules.RA2,MatchRules.EXTENDED]:
		start(mode);battle.fog=null
		var ground=make("MTNK",false);ground.side="enemy";ground.position=Vector2(950,900)
		var air=make("JUMPJET",false);air.side="enemy";air.position=Vector2(950,900);air.logistics.air_lift=1.0
		var sub=make("SUB",false);sub.side="enemy";sub.position=Vector2(950,900)
		var building=battle._place_building("GAPOWR","enemy",Vector2(1200,900),true)
		var point=ForceFirePoint.new();point.global_position=Vector2(950,900)
		for id in ["E1","GGI","MTNK","APOC","BFRT","DRED","DEST","SNIPE","GHOST","CLEG","PTROOP","SPY","ENGINEER","SQD","DRON","IVAN","DTRUCK","JUMPJET"]:
			var old=make(id,true);var now=make(id,false)
			for target in [ground,air,sub,building,point,null]:
				if target!=null:check(OldDistance.distance_to(now,target)==CommandoCombat.distance_to(now,target),"original distance including ground orders and building edges")
				for rank in [0,2]:
					for frozen in [false,true]:
						for u in [old,now]:
							u.veteran_level=rank;u._refresh_veteran_bonuses(false)
							u.special.chrono_left=1.0 if frozen else 0.0
							u.attack_target=target;u.attack_ordered=true
						for cover in [false,true]:
							check(old._weapon_domain_valid(target,cover)==now._weapon_domain_valid(target,cover),prefix+"independent original domain "+str([id,target,rank,frozen,cover]))
			discard(old);discard(now)
		point=null
		await finish()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	get_tree().quit(0 if failed==0 else 1)
