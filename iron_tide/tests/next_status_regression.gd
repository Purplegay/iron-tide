extends "res://tests/base_recovery_regression.gd"
const Fixture=preload("res://tests/next_status_actor.gd")
const Status=preload("res://scripts/ui/unit_status.gd")
var micro:Array=[]
func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
	start(MatchRules.EXTENDED)
	var actors:Array=[]
	for id in ["E1","GGI","MTNK","APOC","TTNK","SHK","DESO","R3REAPER","CARRIER","MGTK"]:
		var unit=Fixture.new();unit.setup(GameData.get_unit(id),"ally",Vector2(1100,1100));battle.add_child(unit);unit.process_mode=Node.PROCESS_MODE_DISABLED
		for state in [{},{"progression_v1":{"shot_idle":2}},{"chrono_left":0.3,"iron_left":2.0},{"controller":null,"parasite":null},{"hero_stationary_shield":{"hp":30,"left":1}},{"unknown_status":true},{"blackout":0,"reveal":0}]:
			for held in [false,true]:
				unit.hold_position=held
				unit.buffs=[{"kind":"defense","value":0.2,"left":2.0,"name":"防护"},{"kind":"defense","value":0.1,"left":1.0,"name":"防护"},{"kind":"regen","left":0.0,"value":0.1}]
				unit.special=state.duplicate(true)
				var expected:Array=unit.original_entries()
				unit.special=state.duplicate(true)
				check(unit.buff_entries()==expected,id+" complete status entries/order/duplicate IDs/timers match "+str([state,held]))
		unit.special={};unit.hold_position=true;actors.append(unit)
	var input:Array=[{"kind":"defense","name":"same"},{"kind":"defense","name":"same"}]
	var backup:=input.duplicate(true);var result:=Status.normalize(input)
	check(input==backup and result[1].id=="defense_1","public normalize still preserves caller data and unique IDs")
	for sample in 18:
		var total:=0;var begun:=Time.get_ticks_usec()
		for i in 300:
			for unit in actors:total+=(unit.original_entries() if sample%2==0 else unit.buff_entries()).size()
		micro.append({"variant":"before" if sample%2==0 else "after","us":Time.get_ticks_usec()-begun,"calls":3000,"entries":total})
	for unit in actors:unit.free()
	await finish()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"micro":micro}))
	get_tree().quit(0 if failed==0 else 1)
