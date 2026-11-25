extends Node
const Probe=preload("res://tests/ai_strategy_probe.gd")
const Budget=preload("res://scripts/world/ai_strategy_budget.gd")
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
	screen.process_mode=Node.PROCESS_MODE_DISABLED;world.paused=false;get_tree().paused=false
	var scenarios:Array=[]
	for speed in [1.0,3.0]:
		Engine.time_scale=speed;GM.fast_forward=speed
		for frame_seconds in [1.0/15.0,0.1,0.2,0.25,0.5,1.0]:
			world.ai_strategy_budget=Budget.new()
			var actors:Array=[]
			for side in BattleRequest.house_teams:
				if side=="ally":continue
				var ai=Probe.new();ai.house_id=side;ai.battle=world;ai.enemy_base="swarm";ai.homes={}
				ai.ai_state.think=0.0;ai.ai_state.attack=55.0;ai.ai_state.erase("attack_dispatch");ai.ai_state.erase("brutal_alarm")
				add_child(ai);ai.set_process(false);actors.append(ai)
			for frame in 120:
				await get_tree().process_frame
				for ai in actors:ai._process(frame_seconds*speed)
			var counts:={}
			for ai in actors:counts[ai.house_id]=ai.granted
			scenarios.append({"wall_frame_seconds":frame_seconds,"speed":speed,"grants":counts})
			for ai in actors:
				check(ai.granted>=2,"real polling and decision gate reach each house "+str([speed,frame_seconds,ai.house_id]),counts)
				ai.free()
	Engine.time_scale=1;GM.fast_forward=1
	world.ai_strategy_budget=Budget.new()
	world.ai_strategy_budget.claim("enemy",-10);world.ai_strategy_budget.claim("ai2",-10)
	var retired=Probe.new();retired.battle=world;retired.house_id="ai2";add_child(retired);retired.set_process(false)
	retired.free()
	check(not world.ai_strategy_budget.waiting.has("ai2"),"controller exit cancels its pending strategy slot")
	check(world.ai_strategy_budget.claim("ai3",-9),"another house proceeds after queued controller exits")
	var context:Dictionary=screen.call_log.context("test",Time.get_ticks_usec())
	check(context.ai_strategy.grants_by_house=={"enemy":1,"ai3":1} and context.ai_strategy.pending_houses.is_empty(),"periodic battle log exposes each house's grants and pending queue")
	FileAccess.open(out.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"failed":failed,"checks":checks,"scenarios":scenarios,"boundary":"real HouseAI polling/run_decisions and budget on six-house save; economic hatch and wave payloads replaced by grant observer, not a full combat replay"},"\t"))
	get_tree().quit(0 if failed==0 else 1)
