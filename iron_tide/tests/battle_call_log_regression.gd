extends "res://tests/ground_control_regression.gd"
const Counters = preload("res://scripts/world/battle_call_counters.gd")
const CallLogger = preload("res://scripts/world/battle_call_log.gd")

func early_return() -> int:
	var scope = Counters.enter(0)
	Counters.iterations(0,7)
	return 7

func read_records(path: String) -> Array:
	var records: Array = []
	for line in FileAccess.get_file_as_string(path).split("\n",false):
		var parsed = JSON.parse_string(line)
		check(parsed is Dictionary,"complete JSONL record")
		if parsed is Dictionary: records.append(parsed)
	return records

func exercise(mode: String) -> void:
	start(mode)
	var logger = screen.call_log
	logger.set_process(false)
	var session:int = logger.session
	Counters.reset()
	seed(1729)
	var expected_random := randi()
	seed(1729)
	var returns_unchanged:=true
	for i in 1000: returns_unchanged=early_return()==7 and returns_unchanged
	check(returns_unchanged,mode+" profiled returns unchanged")
	check(randi()==expected_random,mode+" profiler does not consume gameplay RNG")
	var rows:Array = Counters.take(session)
	check(rows.size()==1 and rows[0].calls==1000,mode+" every function entry counted")
	check(rows[0].iterations==7000,mode+" exact loop work is accumulated separately from calls")
	check(rows[0].timed_calls>10 and rows[0].timed_calls<100,mode+" high frequency timing is sampled",rows)
	check(rows[0].sampled_total_ms>=0.0,mode+" early return closes timing scope")
	check(Counters.take(session).is_empty(),mode+" window counters reset")
	# Old scopes retain their old bucket, never leak into the new window/session.
	var scope = Counters.enter(0)
	Counters.take(session)
	scope=null
	check(Counters.take(session).is_empty(),mode+" late scope cannot leak into new window")
	Counters.stop(session+1)
	check(Counters.owner==session,mode+" old scene cannot stop current collector")
	for i in 94:logger.record_frame(10000)
	for i in 6:logger.record_frame(100000)
	check(logger.percentile(0.5)==10 and logger.percentile(0.95)==100,mode+" whole-window percentile histogram")
	logger.record_frame(6000000)
	check(logger.frame_overflow==1 and logger.frame_max_us==6000000,mode+" extreme frame records overflow and actual maximum")
	var began:int=logger.start_us
	var pacing=battle.frame_pacing
	pacing.take_logic_stats()
	for i in 94:pacing.record_logic_step(10000,60)
	for i in 6:pacing.record_logic_step(70000,15)
	logger.observe(began,true)
	logger.observe(began+29999999,true)
	check(logger.sequence==0,mode+" no write before 30 wall seconds")
	Engine.time_scale=3.0
	logger.observe(began+30000000,true)
	check(logger.sequence==1,mode+" 30 second write ignores battle speed")
	Engine.time_scale=1.0
	check(logger.frame_count==0,mode+" flush resets interval frame counters")
	logger.observe(began+31000000,true)
	logger.observe(began+32000000,false)
	logger.observe(began+32010000,false)
	check(logger.frame_count==1 and logger.percentile(0.95)==10,mode+" pause and first resumed frame excluded")
	# Return to real time after controlled clock assertions, then test partial tail.
	logger.window_us=Time.get_ticks_usec()
	var path:String=logger.base_path
	check(Counters.paths.json==path+".json",mode+" diagnostic snapshot exposes JSON export path")
	logger.simulated_s=90.0
	early_return()
	logger.close("test_partial_exit")
	check(logger.writer==null and logger.pending.is_empty(),mode+" exit drains background writes")
	check(Counters.owner==0,mode+" scene exit disables counting")
	var records:=read_records(path+".jsonl")
	check(records.size()==3,mode+" start plus interval plus partial tail persisted",records.size())
	check(records[1].kind=="window" and records[1].window_wall_s==30.0,mode+" exact window record")
	check(records[1].logic_steps.count==100 and records[1].logic_steps.p95_ms==70 and records[1].logic_steps.over_current_hz_budget==6,mode+" logic budget is measured per step at its actual frequency")
	check(records[-1].logic_steps.count==0,mode+" flushing resets logic measurements without changing pacing state")
	check(records[-1].kind=="test_partial_exit" and records[-1].functions[0].calls==1,mode+" partial window call retained")
	check(FileAccess.get_file_as_string(path+".log").contains("次数排名"),mode+" readable ranking written")
	var exported=JSON.parse_string(FileAccess.get_file_as_string(path+".json"))
	check(exported is Dictionary,mode+" standalone JSON document exported")
	if exported is Dictionary:
		check(exported.header.match_id==battle.match_id and exported.header.session==path.get_file(),mode+" JSON retains match and entry identity")
		check(exported.windows.size()==2 and exported.windows[-1].kind=="test_partial_exit",mode+" JSON contains complete windows and partial tail")
		check(exported.summary.export_complete and exported.summary.end_reason=="test_partial_exit" and not exported.summary.battle_ended,mode+" completed export is distinct from completed battle")
		check(exported.summary.frames.count==102 and is_equal_approx(exported.summary.frames.mean_ms,7550.0/102.0),mode+" summary weights frames instead of averaging window means")
		check(exported.summary.frames.p95_ms==100 and exported.summary.frames.p99_ms==100,mode+" complete session percentiles merge samples instead of averaging window percentiles")
		check(exported.summary.frames.over_60fps_budget==7 and exported.summary.frames.over_15fps_budget==7,mode+" full-frame budget counts retain overflow and partial tail")
		check(exported.summary.functions.size()==1 and exported.summary.functions[0].calls==1,mode+" session function counts include partial tail")
		check(exported.summary.functions[0].iterations==7,mode+" JSON exports exact loop iterations in partial tail")
		var merged := {}
		for row in [exported.summary.functions[0],exported.summary.functions[0]]: CallLogger.Export.accumulate(merged,row)
		check(merged.values()[0].iterations==14,mode+" JSON merges loop iterations across windows")
		check(exported.summary.session_sim_s==90.0 and is_equal_approx(exported.summary.effective_speed,90.0/exported.summary.session_wall_s),mode+" simulation progress is measured from entry rather than absolute save time")
	check(not FileAccess.file_exists(path+".json.tmp"),mode+" successful export leaves no temporary JSON")
	var bounds=CallLogger.new()
	bounds.frame_hist.resize(CallLogger.HISTOGRAM_MAX_MS+1)
	for elapsed in [16666,16667,66666,66667]:bounds.record_frame(elapsed)
	check(bounds.frame_over_60fps==3 and bounds.frame_over_15fps==1,mode+" exact microsecond budget checks do not use rounded histogram buckets")
	bounds.closed=true
	bounds.free()
	var bytes:=FileAccess.get_file_as_bytes(path+".jsonl")
	var json_bytes:=FileAccess.get_file_as_bytes(path+".json")
	logger.close("duplicate")
	check(FileAccess.get_file_as_bytes(path+".jsonl")==bytes,mode+" repeated close does not duplicate records")
	check(FileAccess.get_file_as_bytes(path+".json")==json_bytes,mode+" repeated close preserves JSON byte for byte")
	var second=CallLogger.new()
	add_child(second)
	second.setup(battle)
	second.set_process(false)
	check(second.base_path!=path,mode+" new session never overwrites prior log")
	check(Counters.take(second.session).is_empty(),mode+" new session starts with empty counters")
	second.close("second_session_exit")
	check(FileAccess.file_exists(second.base_path+".json") and FileAccess.get_file_as_bytes(path+".json")==json_bytes,mode+" fresh entry exports separately without replacing prior battle")
	second.free()
	var ended=CallLogger.new()
	add_child(ended)
	ended.setup(battle)
	battle.ended=true
	ended._process(0.0)
	var end_report=JSON.parse_string(FileAccess.get_file_as_string(ended.base_path+".json"))
	check(end_report is Dictionary and end_report.summary.end_reason=="battle_ended" and end_report.summary.battle_ended,mode+" battle completion exports automatically")
	battle.ended=false
	ended.free()
	var exiting=CallLogger.new()
	add_child(exiting)
	exiting.setup(battle)
	var exit_path:String=exiting.base_path
	exiting.free()
	var exit_report=JSON.parse_string(FileAccess.get_file_as_string(exit_path+".json"))
	check(exit_report is Dictionary and exit_report.summary.end_reason=="scene_exit" and exit_report.summary.frames.count==0,mode+" short scene exit exports even without sampled frames")
	var invalid:=ProjectSettings.globalize_path("user://writer_blocker")
	var file:=FileAccess.open(invalid,FileAccess.WRITE)
	file.store_string("fixture");file.close()
	check(not CallLogger.write_records(invalid+"/nested",[]).is_empty(),mode+" disk failure is reported")
	var corrupt:=ProjectSettings.globalize_path("user://corrupt_export")
	file=FileAccess.open(corrupt+".jsonl",FileAccess.WRITE)
	file.store_string(JSON.stringify(records[0])+"\n{incomplete");file.close()
	file=FileAccess.open(corrupt+".json",FileAccess.WRITE)
	file.store_string("preserve prior export");file.close()
	check(not CallLogger.Export.write(corrupt,"test").is_empty(),mode+" incomplete checkpoint rejects export")
	check(FileAccess.get_file_as_string(corrupt+".json")=="preserve prior export" and not FileAccess.file_exists(corrupt+".json.tmp"),mode+" failed export never publishes partial JSON or replaces existing file")
	# Bounded entry overhead measurement, not a claim about full game P95.
	Counters.start(987)
	var at:=Time.get_ticks_usec()
	for i in 100000: early_return()
	var enabled_us:=Time.get_ticks_usec()-at
	var counts:=Counters.take(987)
	Counters.stop(987)
	at=Time.get_ticks_usec()
	for i in 100000: early_return()
	var disabled_us:=Time.get_ticks_usec()-at
	metrics.append({"mode":mode,"calls":100000,"enabled_us":enabled_us,"disabled_us":disabled_us,"samples":counts[0].timed_calls})
	check(counts[0].calls==100000,mode+" high volume bounded aggregation")
	var leaving=CallLogger.new()
	screen.add_child(leaving)
	leaving.setup(battle)
	var scene_path:String=leaving.base_path
	await finish()
	var scene_report=JSON.parse_string(FileAccess.get_file_as_string(scene_path+".json"))
	check(scene_report is Dictionary and scene_report.summary.end_reason=="scene_exit",mode+" removing entire battle scene drains JSON export before world destruction")
