extends Node
const TimerProbe=preload("res://timer.gd")
var out:String
var result={}
var logic_started_us := 0
var logic_samples: Array = []
var logic_over_budget := 0
var logic_rates := {}
var frame_logic_us := 0
var frame_logic_steps := 0
var process_started_us := 0
var process_us := 0
var traced_frames: Array = []
var graphics_samples: Array = []

func _begin_process() -> void:
	process_started_us=Time.get_ticks_usec()

func _process(_delta: float) -> void:
	if process_started_us>0:process_us=Time.get_ticks_usec()-process_started_us

func _begin_logic_step() -> void:
	logic_started_us=Time.get_ticks_usec()

func _physics_process(_delta: float) -> void:
	if logic_started_us==0:return
	var elapsed := Time.get_ticks_usec()-logic_started_us
	frame_logic_us+=elapsed
	frame_logic_steps+=1
	logic_samples.append(elapsed/1000.0)
	var rate := Engine.physics_ticks_per_second
	logic_rates[rate]=int(logic_rates.get(rate,0))+1
	if elapsed>1000000.0/rate:logic_over_budget+=1
func _ready():
	process_mode=Node.PROCESS_MODE_ALWAYS
	out=OS.get_environment("IRON_OUT")
	if (DisplayServer.get_name()!="headless" and OS.get_environment("IRON_ISOLATED_DESKTOP")!="1") or not OS.get_user_data_dir().contains("CodexIronTideValidation") or out.is_empty():
		get_tree().quit(2)
		return
	get_tree().current_scene=null
	run.call_deferred()
func run():
	var cpu_placement = get_node_or_null("/root/RuntimeCPU")
	if cpu_placement != null and cpu_placement.report.get("status") == "pending":
		await cpu_placement.completed
	var load_begin := Time.get_ticks_usec()
	var game := 0
	seed(713)
	var screen
	var saved_source := OS.get_environment("IRON_SAVE")
	if not saved_source.is_empty():
		DirAccess.make_dir_recursive_absolute(BattleSaves.DIRECTORY)
		if DirAccess.copy_absolute(saved_source,ProjectSettings.globalize_path(BattleSaves.slot_path("slot1")))!=OK:
			get_tree().quit(2)
			return
		if not BattleSaves.load_into_scene("slot1").ok:
			get_tree().quit(2)
			return
		while get_tree().current_scene==null: await get_tree().process_frame
		screen=get_tree().current_scene
	else:
		var rows=[]
		for i in 6: rows.append({"country":"美国" if i%2==0 else "苏俄","team":1 if i%2==0 else 2,"difficulty":6})
		rows[0].erase("difficulty")
		BattleRequest.configure_skirmish(MatchRules.EXTENDED,{"houses":rows,"map_layout":"yr_isleland","difficulty":6,"starting_funds":12000,"fog_of_war":true})
		if BattleRequest.house_teams.size()!=6:
			push_error("Six-house configuration rejected")
			get_tree().quit(2)
			return
		screen=load("res://scenes/battle.tscn").instantiate()
		add_child(screen)
	var world=screen.battle
	if OS.get_environment("IRON_HIDE_EFFECTS")=="1":
		world.effects_root.hide()
		world.projectiles_root.hide()
	var expected_map := OS.get_environment("IRON_EXPECT_MAP")
	if not expected_map.is_empty() and world.map_layout()!=expected_map:
		push_error("Checkpoint map differs from requested map: "+world.map_layout())
		get_tree().quit(2)
		return
	if OS.get_environment("IRON_PRESERVE_PLAYER")!="1":
		# Test-only autopilot for the player's seat: all six sides use real AI production.
		if not world.allied_state.house_ai.has("ally"): world.allied_state.house_ai.ally={"center":world.player_start(),"think":0.5,"attack":20.0}
		var pilot=preload("res://scripts/world/house_ai.gd").new()
		pilot.house_id="ally"
		pilot.homes={}
		for side in world.allied_state.house_ai: pilot.homes[side]=world.allied_state.house_ai[side].center
		pilot.setup(world,6,world.roster_faction("ally"),world.player_start())
		pilot.rally=pilot.base_center.move_toward(Vector2.ONE*world.map_size*0.5,180.0)
		world.house_controllers.ally=pilot
		world.add_child(pilot)
	for ai in world.house_controllers.values(): ai._rng.seed=713+game*17+str(ai.house_id).hash()
	world.paused=false
	get_tree().paused=false
	GM.fast_forward=float(OS.get_environment("IRON_SPEED"))
	Engine.time_scale=GM.fast_forward
	var load_ms := (Time.get_ticks_usec()-load_begin)/1000.0
	var duration := float(OS.get_environment("IRON_SECONDS"))
	var fixed_workload := OS.get_environment("IRON_FIXED_WORKLOAD")=="1"
	var frame_limit := roundi(duration*30.0) if fixed_workload else 0
	if fixed_workload: world.frame_pacing.tier=3
	TimerProbe.costs.clear()
	TimerProbe.calls.clear()
	TimerProbe.samples.clear()
	preload("res://unit_call_probe.gd").take()
	var sim_begin: float = world.fog.sight_clock
	var initial_state := {"map":world.map_layout(),"sim_clock_s":sim_begin,"units":world.units.size(),"buildings":world.buildings.size(),"ai_count":world.house_controllers.size()}
	var native_profile := OS.get_environment("IRON_NATIVE_PROFILE")=="1"
	var previous_stdout := Engine.print_to_stdout
	if native_profile:
		if not EngineDebugger.is_active() or not EngineDebugger.has_profiler("scripts"):
			push_error("Native scripts profiler unavailable; run a debug-capable Godot with --debug")
			get_tree().quit(2)
			return
		EngineDebugger.profiler_enable("scripts",true)
		# LocalDebugger otherwise dumps every function each second. Keep timing
		# active, suppress only stdout, then emit the accumulated table once.
		Engine.print_to_stdout=false
	var graphical := OS.get_environment("IRON_ISOLATED_DESKTOP")=="1"
	var frame_only := OS.get_environment("IRON_FRAME_ONLY")=="1"
	if graphical and not frame_only: RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(),true)
	var begin := Time.get_ticks_usec()
	var measurement_unix_start := Time.get_unix_time_from_system()
	process_physics_priority=2000
	process_priority=2000000
	if frame_only:
		set_process(false)
		set_physics_process(false)
	else:
		get_tree().physics_frame.connect(_begin_logic_step)
		get_tree().process_frame.connect(_begin_process)
	var last := begin
	var next_report := 30.0
	var samples: Array = []
	var all_samples: Array = []
	var windows: Array = []
	var peak_units := 0
	print("START houses=",world.house_controllers.keys()," speed=",Engine.time_scale," load_ms=",load_ms)
	while not world.ended and (all_samples.size()<frame_limit if fixed_workload else (Time.get_ticks_usec()-begin)/1000000.0 < duration):
		await get_tree().process_frame
		if graphical and not frame_only:
			graphics_samples.append([RenderingServer.viewport_get_measured_render_time_cpu(get_viewport().get_viewport_rid()),RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid()),Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
		var now := Time.get_ticks_usec()
		var frame_ms := (now-last)/1000.0
		if not frame_only:
			traced_frames.append({"frame_ms":frame_ms,"logic_ms":frame_logic_us/1000.0,"logic_steps":frame_logic_steps,
				"previous_process_ms":process_us/1000.0,"other_ms":frame_ms-(frame_logic_us+process_us)/1000.0,
				"units":world.units.size(),"paths":world.path_service.stats_paths,"physics_hz":Engine.physics_ticks_per_second})
		frame_logic_us=0
		frame_logic_steps=0
		samples.append((now-last)/1000.0)
		all_samples.append((now-last)/1000.0)
		peak_units=maxi(peak_units,world.units.size())
		last=now
		var wall := (now-begin)/1000000.0
		if not frame_only and (wall >= next_report or (not fixed_workload and wall >= duration) or (fixed_workload and all_samples.size()==frame_limit)):
			samples.sort()
			var counts := {}
			for u in world.units:
				if world.actor_alive(u): counts[u.side]=int(counts.get(u.side,0))+1
			peak_units=maxi(peak_units,world.units.size())
			var win := {"sim":world.fog.sight_clock-sim_begin,"wall":wall,"p50":samples[ceili(samples.size()*.50)-1],"p95":samples[ceili(samples.size()*.95)-1],"p99":samples[ceili(samples.size()*.99)-1],"max":samples.back(),"frames":samples.size(),"units":world.units.size(),"buildings":world.buildings.size(),"counts":counts,"paths":world.path_service.stats_paths,"hz":Engine.physics_ticks_per_second,"speed":Engine.time_scale,"unit_behaviors":preload("res://unit_call_probe.gd").take(),"costs":TimerProbe.costs.duplicate(),"calls":TimerProbe.calls.duplicate(),"samples":TimerProbe.samples.duplicate()}
			windows.append(win)
			print("WINDOW wall=",roundi(wall)," sim=",roundi(win.sim)," p95=",win.p95," units=",win.units," buildings=",win.buildings)
			FileAccess.open(out.path_join("progress.json"),FileAccess.WRITE).store_string(JSON.stringify(windows))
			samples.clear()
			TimerProbe.costs.clear()
			TimerProbe.calls.clear()
			TimerProbe.samples.clear()
			next_report+=30.0
	var elapsed := (Time.get_ticks_usec()-begin)/1000000.0
	var measurement_unix_end := Time.get_unix_time_from_system()
	if native_profile:
		Engine.print_to_stdout=true
		print("IRON_FUNCTION_PROFILE_END_BEGIN")
		EngineDebugger.profiler_enable("scripts",false)
		print("IRON_FUNCTION_PROFILE_END_DONE")
		Engine.print_to_stdout=previous_stdout
	result={"completed":all_samples.size()==frame_limit if fixed_workload else elapsed>=duration,"fixed_workload":fixed_workload,"wall":elapsed,"sim":world.fog.sight_clock-sim_begin,"ai_count":world.house_controllers.size(),"speed":Engine.time_scale,"load_ms":load_ms,"ended":world.ended,"peak_units":peak_units,"windows":windows}
	result.measurement_unix_start_s=measurement_unix_start
	result.measurement_unix_end_s=measurement_unix_end
	result.initial_state=initial_state
	result.observation={"frame_only":frame_only,"injected_unit_counters":not frame_only,"phase_callbacks":not frame_only,"viewport_timing_queries":graphical and not frame_only,"native_profile":native_profile}
	if graphical:
		result.graphics={"display":DisplayServer.get_name(),"adapter":RenderingServer.get_video_adapter_name(),"actual_size":get_window().size,
			"sample_fields":["viewport_render_cpu_ms","viewport_render_gpu_ms","draw_calls"],"samples":graphics_samples,"effects_hidden":OS.get_environment("IRON_HIDE_EFFECTS")=="1",
			"scope":"Viewport render timings, not full-frame CPU; private desktop presentation differs from the user's active desktop.",
			"render_thread_model":ProjectSettings.get_setting("rendering/driver/threads/thread_model"),"last_frame_draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)}
	result.runtime={"editor":OS.has_feature("editor"),"engine":Engine.get_version_info().string,
		"physics_hz":Engine.physics_ticks_per_second,"max_physics_steps_per_frame":Engine.max_physics_steps_per_frame}
	if cpu_placement != null: result.runtime.cpu_policy = cpu_placement.report.duplicate(true)
	result.meta_profile={"cosmetics":MetaProgress.unit_cosmetics.duplicate(true),"attachment_positions":MetaProgress.attachment_positions.duplicate(true)}
	FileAccess.open(out.path_join("frame-components.json"),FileAccess.WRITE).store_string(JSON.stringify(traced_frames))
	all_samples.sort()
	if not all_samples.is_empty():
		var total_ms := 0.0
		for sample in all_samples: total_ms+=float(sample)
		result.frame_stats={"frames":all_samples.size(),"mean_ms":total_ms/all_samples.size(),"p50_ms":all_samples[ceili(all_samples.size()*.50)-1],"p95_ms":all_samples[ceili(all_samples.size()*.95)-1],"p99_ms":all_samples[ceili(all_samples.size()*.99)-1],"max_ms":all_samples.back()}
	logic_samples.sort()
	if not logic_samples.is_empty():
		var total_logic_ms := 0.0
		for sample in logic_samples:total_logic_ms+=float(sample)
		result.logic_stats={"steps":logic_samples.size(),"mean_ms":total_logic_ms/logic_samples.size(),"p95_ms":logic_samples[ceili(logic_samples.size()*.95)-1],"p99_ms":logic_samples[ceili(logic_samples.size()*.99)-1],"max_ms":logic_samples.back(),"over_current_hz_budget":logic_over_budget,"rates":logic_rates,"scope":"physics callbacks through priority 2000; excludes later physics-server work and process/render callbacks"}
	FileAccess.open(out.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify(result))
	var saved = BattleSaves.save_slot(world,"quick")
	if saved.ok: DirAccess.copy_absolute(ProjectSettings.globalize_path(BattleSaves.slot_path("quick")),out.path_join("end.itsave"))
	screen.call_log.close("soak_complete")
	screen.free()
	get_tree().paused=false
	get_tree().quit()
