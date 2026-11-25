extends Node
var checks:Array=[]
var failed:=0
func check(ok:bool,label:String,details=null):
	checks.append({"passed":ok,"name":label,"details":details})
	if not ok:failed+=1;print("FAIL ",label," ",details)
func _ready():
	process_mode=Node.PROCESS_MODE_ALWAYS;get_tree().current_scene=null;run.call_deferred()
func run():
	var out:=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if out.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
	DirAccess.make_dir_recursive_absolute(BattleSaves.DIRECTORY)
	DirAccess.copy_absolute(OS.get_environment("IRON_SAVE"),BattleSaves.slot_path("slot1"))
	if not BattleSaves.load_into_scene("slot1").ok:get_tree().quit(2);return
	while get_tree().current_scene==null:await get_tree().process_frame
	var screen=get_tree().current_scene
	var world:Battle=screen.battle
	BattleClock.set_speed(3.0);world.paused=false;get_tree().paused=false
	var before:Dictionary=world.ai_strategy_budget.grants_by_house.duplicate()
	var start:float=world.fog.sight_clock
	for frame in 400:await get_tree().process_frame
	var stats:Dictionary=world.ai_strategy_budget.diagnostics()
	check(world.house_controllers.size()==5,"actual six-house battle retains five AI controllers")
	check(world.fog.sight_clock-start>=19.0,"actual battle simulation advances at three times speed")
	for side in world.house_controllers:
		check(int(stats.grants_by_house.get(side,0))>int(before.get(side,0)),"real economic/build/dispatch strategy executes for "+str(side),stats)
	screen.call_log.flush_window("ai_strategy_acceptance",Time.get_ticks_usec())
	var path:String=screen.call_log.base_path+".json"
	screen.call_log.close("ai_strategy_acceptance")
	var log:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	check(not log.windows.is_empty(),"exported JSON contains strategy diagnostic window")
	if not log.windows.is_empty():
		var exported:Dictionary=log.windows[-1].ai_strategy.grants_by_house
		check(exported.size()==stats.grants_by_house.size(),"exported grant roster matches runtime")
		# JSON numbers return as floats; compare integer counters explicitly.
		for side in stats.grants_by_house:
			check(exported.has(side) and int(exported[side])==int(stats.grants_by_house[side]),"exported JSON preserves actual grant count for "+str(side))
	FileAccess.open(out.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"failed":failed,"checks":checks,"ai_strategy":stats,"simulation_seconds":world.fog.sight_clock-start,"boundary":"unmodified real house policies, units, production and dispatch; background functional check, not performance measurement"},"\t"))
	get_tree().quit(0 if failed==0 else 1)
