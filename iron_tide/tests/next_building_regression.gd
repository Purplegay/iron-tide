extends "res://tests/base_recovery_regression.gd"
const Fixture=preload("res://tests/next_building_reference.gd")
var micro:Array=[]
func snapshot(actor) -> Dictionary:
	var out:Dictionary={}
	for field in BattleSaves.Schema.fields("building"):
		var value=actor.get(field)
		out[field]=value.duplicate(true) if value is Array or value is Dictionary else value
	out.modulate=actor.modulate;out.self_modulate=actor.self_modulate
	return out
func restore(actor,state:Dictionary) -> void:
	for field in state:
		var value=state[field]
		actor.set(field,value.duplicate(true) if value is Array or value is Dictionary else value)
func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
	start(MatchRules.EXTENDED)
	battle.paused=false;get_tree().paused=false
	var actors:Array=[]
	for id in ["GAPOWR","NAPOWR","GATECH","NATECH","GAWEAP","NAWEAP","GACNST","NACNST"]:
		var actor=Fixture.new();actor.setup(GameData.get_building(id),"enemy",Vector2(1100,1100),battle,true)
		battle.add_child(actor);actor.process_mode=Node.PROCESS_MODE_DISABLED
		actor._buildup_play=-1;actors.append(actor)
		for effects in [{},{"airstrike_left":0.02},{"iron_left":0.02},{"blackout":0.1},{"occupants":[]},{"force_shield_left":0.02}]:
			actor.special=effects.duplicate(true)
			var initial:=snapshot(actor);seed(123)
			actor.original_process(0.05);var expected:=snapshot(actor)
			restore(actor,initial);seed(123);actor._process(0.05)
			check(snapshot(actor)==expected,id+" building state/animation timers match "+str(effects))
		actor.special={};actor._buildup_play=-1
	for sample in 18:
		var begun:=Time.get_ticks_usec()
		for i in 500:
			for actor in actors:
				if sample%2==0:actor.original_process(0.0)
				else:actor._process(0.0)
		micro.append({"variant":"before" if sample%2==0 else "after","us":Time.get_ticks_usec()-begun,"calls":4000})
	for actor in actors:actor.free()
	await finish()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"micro":micro}))
	get_tree().quit(0 if failed==0 else 1)
