extends "res://tests/expedition_regression.gd"

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2)
		return
	new_ready("美国",22)
	check(Expedition.launch(0),"launch control mission")
	if instantiate_battle():await exercise_control()
	new_ready("美国",20)
	check(Expedition.launch(0),"launch mobile command mission")
	if instantiate_battle():await exercise_hidden_clear()
	print("CONTROL POINTS checks=",checks.size()," failed=",failed)
	get_tree().quit(0 if failed==0 else 1)

func exercise_hidden_clear() -> void:
	var tasks=screen.expedition_runtime.tasks
	var command=tasks.actor("command")
	var targets:Array=battle.buildings.filter(func(b):return battle.actor_alive(b) and BattleRequest.is_ai_house(b.side) and not BattleRequest.friendly("ally",b.side))
	var last=targets.pop_back()
	for b in targets:b._die()
	tasks.tick(0.1)
	check(battle.actor_alive(command) and not battle.ended,"one remaining hostile structure blocks hidden victory")
	last._die()
	tasks.tick(0.1)
	check(tasks.state.outcome==1 and battle.ended,"clearing all hostile structures wins the mission")
	check(not battle.actor_alive(command),"victory eliminates the remaining hostile command vehicle")
	await finish()

func exercise_control() -> void:
	var tasks=screen.expedition_runtime.tasks
	check(tasks.state.kind=="control" and tasks.state.control_scores==[0.0,0.0,0.0],"three empty counters")
	var points:Array=tasks.state.points
	# Park starting troops outside the objective zones and isolate the scoring clock.
	for unit in battle.units:
		unit.position=tasks.state.origin
	tasks.state.next_wave=99999.0
	battle.spawn_unit("E1","ally",points[0])
	tasks.tick(1)
	check(tasks.state.progress == 1, "one defender scores one point per second")
	var extra = battle.spawn_unit("E1", "ally", points[0])
	tasks.tick(1)
	check(is_equal_approx(tasks.state.progress, 1.0 + 60.0/54.0), "two defenders take 54 seconds")
	var third = battle.spawn_unit("MTNK", "ally", points[0])
	var fourth = battle.spawn_unit("E1", "ally", points[0])
	tasks.tick(1)
	var saved_state:Dictionary=tasks.state
	for kind:String in ["research","rescue"]:
		tasks.state=saved_state.duplicate(true)
		tasks.state.kind=kind
		tasks.state.rescued=[]
		tasks.tick(1.0)
		var earned:=float(tasks.state.labs[0]) if kind=="research" else float(tasks.state.rescue0)
		check(is_equal_approx(earned,1.25),kind+" gains 1.25 seconds with four troops")
		tasks.state=saved_state
	var ops=screen.expedition_runtime.field_ops
	var task:Dictionary={"id":"curve_test","kind":"quiet","position":points[0],"progress":0.0,"phase":"open","done":false,"failed":false}
	ops.missions.tick(task,ops.data,1.0)
	check(is_equal_approx(task.progress,1.25),"four listeners advance the recording together")
	var four_total := 1.0 + 60.0/54.0 + 60.0/48.0
	check(is_equal_approx(tasks.state.progress, four_total), "four defenders take 48 seconds")
	third.position = tasks.state.origin
	fourth.position = tasks.state.origin
	extra.position = tasks.state.origin
	tasks.tick(1)
	check(is_equal_approx(tasks.state.progress, four_total+1.0), "leaving the circle immediately reduces the rate")
	for amount in [0,1,2,3]:
		check(is_equal_approx(60.0/tasks.capture_rate(8,amount),42.0-6.0*amount), "eight-unit cap at relic level " + str(amount))
		check(tasks.capture_rate(8,amount)==tasks.capture_rate(15,amount), "extra troops respect the cap")
	tasks.tick(200.0)
	check(tasks.state.control_scores==[60.0,0.0,0.0] and tasks.state.progress==60 and not battle.ended,"holding just one point stops at sixty")
	check(battle.skirmish_ai.Tactics.attack_position(battle.skirmish_ai,[])==points[0],"attack formation prioritizes occupied flank")
	var raider=battle.spawn_unit("E2","enemy",points[0])
	tasks.state.stage=6
	tasks.tick(120)
	check(tasks.state.control_scores[0]==60 and tasks.summary().contains("据点争夺"),"early mission retains full credit even late in battle")
	tasks.state.stage=22
	tasks.state.elapsed=0.0
	tasks.tick(3)
	check(tasks.summary().contains("三线反夺"),"late recapture mission has distinct name")
	check(tasks.state.control_scores[0]==57 and tasks.minimap_markers()[0].status=="active","contesting a completed point reopens it")
	raider.position=tasks.state.origin
	tasks.tick(3)
	check(tasks.minimap_markers()[0].status=="done" and tasks.minimap_markers()[1].status=="active","minimap distinguishes full and unfinished points")
	battle.spawn_unit("E1","ally",points[1])
	var scout=battle.spawn_unit("E1","ally",points[2])
	tasks.tick(10.5)
	check(tasks.state.control_scores==[60.0,10.5,10.5],"two occupied points advance together")
	var rival=battle.spawn_unit("E2","enemy",points[1])
	scout.position=tasks.state.origin
	tasks.tick(20)
	check(tasks.state.control_scores==[60.0,0.0,10.5],"contested point drains to zero while empty point keeps credit")
	rival.position=tasks.state.origin
	tasks.tick(15.5)
	check(Expedition.checkpoint(battle),"write partial checkpoint")
	await finish()
	check(Expedition.load_run() and Expedition.prepare_battle(),"read checkpoint from disk")
	if not instantiate_battle():return
	tasks=screen.expedition_runtime.tasks
	check(tasks.state.control_scores==[60.0,15.5,10.5] and tasks.state.progress==86,"restore distinct point totals")
	check(tasks.summary().contains("2号 15/60") and tasks.point_title(0).contains("60/60"),"HUD and map expose individual scores")
	tasks.state.erase("control_scores")
	check(Expedition.checkpoint(battle),"write pooled-score checkpoint fixture")
	await finish()
	check(Expedition.load_run() and Expedition.prepare_battle(),"open pooled-score checkpoint")
	if not instantiate_battle():return
	tasks=screen.expedition_runtime.tasks
	check(tasks.state.control_scores==[60.0,26.0,0.0] and tasks.state.progress==86,"pooled checkpoint keeps all previously earned credit")
	tasks.tick(100)
	check(tasks.state.progress==120 and not battle.ended,"two capped points cannot finish the mission")
	battle.spawn_unit("E1","ally",tasks.state.points[2])
	tasks.tick(100)
	check(tasks.state.control_scores==[60.0,60.0,60.0] and tasks.state.progress==180 and tasks.state.outcome==1 and battle.ended,"third point completes the objective exactly at 180")
	await finish()
