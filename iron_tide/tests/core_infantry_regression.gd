extends "res://tests/base_recovery_regression.gd"
const Before=preload("res://tests/core_infantry_reference.gd")
const After=preload("res://scripts/units/infantry_idle.gd")
var micro:Array=[]
func state(pose) -> Array:
	return [pose.wait_left,pose.elapsed,pose.clip,pose.previous,pose.appearance,pose.frame,pose.wet,pose.rng.state]
func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2);return
	start(MatchRules.EXTENDED)
	var carrier=battle.spawn_unit("BFRT","ally",Vector2(1100,1100))
	carrier.process_mode=Node.PROCESS_MODE_DISABLED
	var target=battle.spawn_unit("E2","enemy",Vector2(1110,1100))
	target.process_mode=Node.PROCESS_MODE_DISABLED
	for id in ["E1","GGI","E2","SHK","SPY","DESO","TANY","CLEG","ENGINEER"]:
		var unit:Unit=battle.spawn_unit(id,"ally",Vector2(1100,1100))
		unit.process_mode=Node.PROCESS_MODE_DISABLED
		var a=Before.new(1234);var b=After.new(1234)
		for i in 600:
			unit.attack_target=target if i%2==0 else null
			unit._dead=i%89==0
			unit._deployed=i%83==0
			unit.embarked_in=carrier if i%79==0 else null
			unit.velocity=Vector2(10,0) if i%73==0 else Vector2.ZERO
			unit.has_move_order=i%71==0
			unit.patrolling=i%67==0
			unit.attack_ordered=i%61==0
			unit._stun_timer=1.0 if i%59==0 else 0.0
			unit._fire_anim_time=0.0 if i%53==0 else -1.0
			unit._muzzle=1.0 if i%47==0 else 0.0
			unit.special={"chrono_left":1.0} if i%43==0 else ({"pounce":{}} if i%41==0 else ({"disguise":"E2"} if i%37==0 else {}))
			a.tick(unit,0.1);b.tick(unit,0.1)
			check(state(a)==state(b),"idle clip/RNG/state equivalence "+id+" "+str(i))
		unit._dead=false;unit._deployed=false;unit.embarked_in=null;unit.velocity=Vector2.ZERO
		unit.has_move_order=false;unit.patrolling=false;unit.attack_ordered=false;unit._stun_timer=0;unit._fire_anim_time=-1;unit._muzzle=0;unit.special={}
		if id in ["E1","GGI","E2"]:
			unit.attack_target=target
			unit._fire_anim_time=0.1
			var captured:Array=[]
			for sample in 14:
				var pose=Before.new(777) if sample%2==0 else After.new(777)
				var begun:=Time.get_ticks_usec()
				for i in 20000:pose.tick(unit,0.001)
				micro.append({"id":id,"variant":"before" if sample%2==0 else "after","us":Time.get_ticks_usec()-begun,"calls":20000})
				captured.append(state(pose))
			for value in captured:check(value==captured[0] and value[7]!=777,"timed idle clips consume identical RNG and state")
	await finish()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"micro":micro}))
	get_tree().quit(0 if failed==0 else 1)
