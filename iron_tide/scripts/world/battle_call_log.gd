extends Node
## Append-only checkpoints plus one JSON export per battle entry. Never per-call disk writes.
const Counters = preload("res://scripts/world/battle_call_counters.gd")
const Snapshot = preload("res://scripts/world/performance_snapshot.gd")
const Export = preload("res://scripts/world/battle_call_export.gd")
const DIRECTORY := "user://performance_calls"
const INTERVAL_US := 30000000
const MAX_PENDING := 4
const HISTOGRAM_MAX_MS := 5000
var world
var session := 0
var base_path := ""
var writer: Thread
var pending: Array = []
var closed := false
var failed := false
var sequence := 0
var start_us := 0
var simulated_s := 0.0
var window_us := 0
var next_flush_us := 0
var last_us := 0
var last_active := false
var frame_hist := PackedInt64Array()
var frame_count := 0
var frame_sum_us := 0
var frame_max_us := 0
var frame_overflow := 0
var frame_over_60fps := 0
var frame_over_15fps := 0
var paused_us := 0
var last_paths := 0
var last_failures := 0

func setup(battle) -> void:
	world = battle
	session = get_instance_id()
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 10000
	# Diagnostic scaffolding, not gameplay. Ship with it off unless explicitly requested:
	# the per-step counters it drives cost ~2.5% of the logic frame (measured) and every
	# match also writes a JSONL to the player's profile. Probe runs pass "1".
	var flag := OS.get_environment("IRON_TIDE_CALL_LOG")
	if flag != "1":
		closed = true
		set_process(false)
		return
	start_us = Time.get_ticks_usec()
	window_us = start_us
	next_flush_us = start_us+INTERVAL_US
	var stamp := Time.get_datetime_string_from_system().replace(":","-")
	base_path = ProjectSettings.globalize_path(DIRECTORY.path_join("%s_%d_%d_%s" % [stamp,OS.get_process_id(),start_us,str(world.match_id).left(12)]))
	Counters.start(session)
	Counters.paths = {"log":base_path+".log","jsonl":base_path+".jsonl","json":base_path+".json"}
	frame_hist.resize(HISTOGRAM_MAX_MS+1)
	frame_hist.fill(0)
	last_paths = world.path_service.stats_paths
	last_failures = world.path_service.stats_path_fail
	var header := context("start",start_us)
	header.points = Counters.POINTS
	header.interval_wall_seconds = 30
	header.measurement = "Exact counts at registered entrypoints; sampled inclusive CPU time. Estimated totals overlap; do not sum. Not an all-function or GPU profiler."
	enqueue(header)
	print("Battle call log: ",base_path+".log")

func _process(delta: float) -> void:
	if closed or failed: return
	poll_writer()
	if Counters.owner != session: return
	if not is_instance_valid(world):
		close("world_removed")
		return
	if world.ended:
		close("battle_ended")
		return
	var paused: bool=world.paused or get_tree().paused
	if not paused and world.can_process() and world.is_processing():
		simulated_s+=maxf(0.0,delta)
		world.bridge_traffic.sample(world,delta)
	observe(Time.get_ticks_usec(),paused)

func observe(now: int, paused: bool) -> void:
	if closed or failed: return
	if last_us>0:
		var elapsed := maxi(0,now-last_us)
		if not paused and last_active:
			record_frame(elapsed)
		else:
			paused_us += elapsed
	last_us = now
	last_active = not paused
	if now>=next_flush_us:
		if pending.size()<MAX_PENDING:
			flush_window("window",now)
			next_flush_us = now+INTERVAL_US
		else:
			# A slow disk stretches the window; keep counts instead of dropping data.
			next_flush_us = now+1000000

func record_frame(elapsed: int) -> void:
	frame_count += 1
	frame_sum_us += elapsed
	frame_max_us = maxi(frame_max_us,elapsed)
	if elapsed*60>1000000: frame_over_60fps+=1
	if elapsed*15>1000000: frame_over_15fps+=1
	if elapsed>HISTOGRAM_MAX_MS*1000: frame_overflow+=1
	var bin := mini(HISTOGRAM_MAX_MS,ceili(float(elapsed)/1000.0))
	frame_hist[bin] += 1

func percentile(fraction: float) -> float:
	if frame_count==0: return 0.0
	var required := ceili(frame_count*fraction)
	var seen := 0
	for i in frame_hist.size():
		seen += frame_hist[i]
		if seen>=required: return float(i)
	return float(HISTOGRAM_MAX_MS)

func sparse_histogram() -> Array:
	var bins: Array = []
	for i in frame_hist.size():
		if frame_hist[i]>0: bins.append([i,frame_hist[i]])
	return bins

func context(kind: String, now: int) -> Dictionary:
	return {"schema":1,"kind":kind,"sequence":sequence,"version":ProjectSettings.get_setting("application/config/version"),
		"local_time":Time.get_datetime_string_from_system(),"session":base_path.get_file(),"match_id":world.match_id,
		"map":world.map_layout(),"difficulty":world.skirmish_difficulty,"speed":Engine.time_scale,
		"session_wall_s":float(now-start_us)/1000000.0,"engine":Engine.get_version_info().string,
		"session_sim_s":simulated_s,"simulation_clock":"active_process_delta","ai_count":world.house_controllers.size(),"battle_ended":world.ended,
		"ai_strategy":world.ai_strategy_budget.diagnostics(),
		"renderer":DisplayServer.get_name(),"pid":OS.get_process_id(),"window_focused":world._window_focused,
		"paused":world.paused or world.get_tree().paused}

func flush_window(kind: String, now: int) -> void:
	if Counters.owner!=session or not is_instance_valid(world): return
	sequence += 1
	var collection_started := Time.get_ticks_usec()
	var report := context(kind,now)
	report.window_wall_s = float(now-window_us)/1000000.0
	report.paused_or_transition_s = float(paused_us)/1000000.0
	report.frames = {"count":frame_count,"p50_ms":percentile(0.50),"p95_ms":percentile(0.95),"p99_ms":percentile(0.99),
		"mean_ms":float(frame_sum_us)/maxi(1,frame_count)/1000.0,"max_ms":frame_max_us/1000.0,
		"histogram_bucket_ms":1,"histogram_cap_ms":HISTOGRAM_MAX_MS,"over_cap_frames":frame_overflow,
		"histogram":sparse_histogram(),"over_60fps_budget":frame_over_60fps,"over_15fps_budget":frame_over_15fps,
		"scope":"Complete active process-to-process intervals; includes intervening physics, process, drawing and scheduling. Not a GPU timer."}
	report.functions = Counters.take(session)
	report.units = Snapshot.roster(world,world.units,"unit_id")
	report.buildings = Snapshot.roster(world,world.buildings,"building_id")
	report.selected = world.selected_units.size()
	report.effects = world.effects_root.get_child_count()
	report.projectiles = world.projectiles_root.get_child_count()
	report.physics_hz = Engine.physics_ticks_per_second
	report.path_requests = world.path_service.stats_paths-last_paths
	report.path_failures = world.path_service.stats_path_fail-last_failures
	report.bridge_traffic = world.bridge_traffic.take()
	report.draw_calls = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	report.memory_bytes = OS.get_static_memory_usage()
	report.scene_nodes = get_tree().get_node_count()
	if is_instance_valid(world.frame_pacing):
		report.refresh_tier=world.frame_pacing.tier
		report.logic_steps=world.frame_pacing.take_logic_stats()
	last_paths = world.path_service.stats_paths
	last_failures = world.path_service.stats_path_fail
	report.collection_cpu_us = Time.get_ticks_usec()-collection_started
	window_us = now
	frame_hist.fill(0)
	frame_count = 0
	frame_sum_us = 0
	frame_max_us = 0
	frame_overflow = 0
	frame_over_60fps = 0
	frame_over_15fps = 0
	paused_us = 0
	enqueue(report)

func enqueue(report: Dictionary) -> void:
	pending.append(report)
	poll_writer()

func poll_writer() -> void:
	if writer!=null and not writer.is_alive():
		var error: String = writer.wait_to_finish()
		writer = null
		if not error.is_empty():
			failed=true
			Counters.stop(session)
			push_warning("调用统计日志停止写入："+error)
	if writer==null and not pending.is_empty() and not failed:
		var records: Array = pending
		pending=[]
		writer=Thread.new()
		if writer.start(write_records.bind(base_path,records))!=OK:
			writer=null
			failed=true
			Counters.stop(session)
			push_warning("无法启动调用统计日志写入任务。")

func close(reason: String) -> void:
	if closed: return
	if not failed and is_instance_valid(world): flush_window(reason,Time.get_ticks_usec())
	Counters.stop(session)
	closed=true
	set_process(false)
	if not failed: pending.append({"kind":"export","end_reason":reason})
	# Only scene exit/result waits for outstanding I/O, never the 30-second update.
	while writer!=null or (not pending.is_empty() and not failed):
		if writer!=null:
			var error: String = writer.wait_to_finish()
			writer=null
			if not error.is_empty():
				failed=true
				push_warning("调用统计日志未完整保存："+error)
		poll_writer()
	if not failed: print("Battle JSON log: ",base_path+".json")

func _exit_tree() -> void:
	close("scene_exit")

static func append_text(path: String, text: String) -> String:
	var mode := FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE
	var file := FileAccess.open(path,mode)
	if file==null: return path+": "+error_string(FileAccess.get_open_error())
	file.seek_end()
	var written := file.store_string(text)
	file.flush()
	var error := file.get_error()
	file.close()
	return "" if written and error==OK else path+": "+error_string(error)

static func write_records(path: String, records: Array) -> String:
	var error := DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if error!=OK: return path.get_base_dir()+": "+error_string(error)
	var jsonl := ""
	var readable := ""
	var export_reason := ""
	for record: Dictionary in records:
		if record.kind=="export":
			export_reason=str(record.end_reason)
			continue
		if record.kind=="start":
			readable += "对局调用统计 | %s | %s | %s\n每 30 秒墙钟汇总；次数完整计数，耗时抽样，含子调用，不能相加。仅涵盖登记的入口。P95/P99 按 1ms 向上分桶，超过 5000ms 的百分位只显示下限；最大帧保留实值。\n" % [record.version,record.map,record.match_id]
		else:
			var by_calls: Array = record.functions.duplicate()
			by_calls.sort_custom(func(a,b):return a.calls>b.calls)
			var by_time: Array = record.functions.duplicate()
			by_time.sort_custom(func(a,b):return a.estimated_inclusive_ms>b.estimated_inclusive_ms)
			record.top_calls = by_calls.slice(0,20).map(func(row):return row.name)
			record.top_estimated_time = by_time.slice(0,20).map(func(row):return row.name)
			readable += "\n[%s #%d] %s | 窗口 %.2fs | 单位 %d 建筑 %d 弹体 %d 特效 %d | P95 %.0fms P99 %.0fms 最大 %.2fms | 寻路 %d\n" % [record.kind,record.sequence,record.local_time,record.window_wall_s,record.units.total,record.buildings.total,record.projectiles,record.effects,record.frames.p95_ms,record.frames.p99_ms,record.frames.max_ms,record.path_requests]
			readable += "次数排名：\n"+ranking(by_calls,record.window_wall_s)
			readable += "估算累计耗时排名（含子调用）：\n"+ranking(by_time,record.window_wall_s)
		jsonl += JSON.stringify(record)+"\n"
	var result := append_text(path+".jsonl",jsonl)
	if not result.is_empty(): return result
	result=append_text(path+".log",readable)
	if not result.is_empty(): return result
	return Export.write(path,export_reason) if not export_reason.is_empty() else ""

static func ranking(rows: Array, seconds: float) -> String:
	var result := ""
	for row: Dictionary in rows.slice(0,20):
		result += "%s | 调用 %d (%.1f/s) | 估算累计 %.2fms | 抽样 %d | 样本均值 %.2fus | 样本最大 %.2fms\n" % [row.name,row.calls,row.calls/maxf(0.001,seconds),row.estimated_inclusive_ms,row.timed_calls,row.sampled_mean_us,row.sampled_max_ms]
	return result
