extends RefCounted
## Keep only wall-clock frame intervals during play. Inspect the scene on demand.
const DIRECTORY := "user://performance_snapshots"
const CAPACITY := 300
var intervals := PackedInt64Array()
var physics_steps := PackedInt32Array()
var last_physics := 0
var next := 0
var count := 0
var last_us := 0
var writer: Thread

func _init() -> void:
	intervals.resize(CAPACITY)
	physics_steps.resize(CAPACITY)

func sample_frame() -> void:
	var now := Time.get_ticks_usec()
	var physics := Engine.get_physics_frames()
	if last_us > 0:
		intervals[next] = now - last_us
		physics_steps[next] = physics - last_physics
		next = (next + 1) % CAPACITY
		count = mini(count + 1, CAPACITY)
	last_us = now
	last_physics = physics
	if writer != null and not writer.is_alive():
		var result: Dictionary = finish()
		Events.emit_message(result.message)

func finish() -> Dictionary:
	if writer == null: return {}
	var result: Dictionary = writer.wait_to_finish()
	writer = null
	return result

func frame_report() -> Dictionary:
	var samples := PackedInt64Array()
	var steps := PackedInt32Array()
	samples.resize(count)
	steps.resize(count)
	for i in count:
		var index := posmod(next - count + i, CAPACITY)
		samples[i] = intervals[index]
		steps[i] = physics_steps[index]
	var report := {"count":count, "interval_us":samples, "physics_steps":steps, "current_physics_hz":Engine.physics_ticks_per_second, "max_steps_per_frame":Engine.max_physics_steps_per_frame}
	if count > 0:
		var sorted := samples.duplicate()
		sorted.sort()
		report.p50_ms = sorted[ceili(count * 0.50) - 1] / 1000.0
		report.p95_ms = sorted[ceili(count * 0.95) - 1] / 1000.0
		report.p99_ms = sorted[ceili(count * 0.99) - 1] / 1000.0
		report.max_ms = sorted[count - 1] / 1000.0
	return report

static func roster(world, actors: Array, id_key: String) -> Dictionary:
	var ids := {}
	var owners := {}
	var total := 0
	for actor in actors:
		if not world.actor_alive(actor): continue
		var id: String = actor.get(id_key)
		ids[id] = int(ids.get(id,0)) + 1
		owners[actor.side] = int(owners.get(actor.side,0)) + 1
		total += 1
	return {"total":total, "by_type":ids, "by_owner":owners}

static func effect_counts(root: Node) -> Dictionary:
	var by_type := {}
	for child in root.get_children():
		var script: Script = child.get_script()
		var type := script.resource_path.get_file() if script != null else child.get_class()
		by_type[type] = int(by_type.get(type,0)) + 1
	return {"direct_children":root.get_child_count(), "by_type":by_type}

func capture(world) -> Dictionary:
	if writer != null: return {"ok":false, "message":"上一份性能快照正在写入。"}
	var stamp := Time.get_datetime_string_from_system()
	var pid := OS.get_process_id()
	var name := "%s_%d_%d.json" % [stamp.replace(":","-"), pid, Time.get_ticks_usec()]
	var report := {
		"version":ProjectSettings.get_setting("application/config/version"), "local_time":stamp,
		"pid":pid, "uptime_ms":Time.get_ticks_msec(), "match_id":world.match_id,
		"map":world.map_layout(), "difficulty":world.skirmish_difficulty,
		"paused":world.paused or world.get_tree().paused, "speed":Engine.time_scale,
		"frames":frame_report(), "engine_physics_frames":Engine.get_physics_frames(),
		"memory_bytes":{"engine_static":OS.get_static_memory_usage(),"engine_static_peak":OS.get_static_memory_peak_usage()},
		"units":roster(world,world.units,"unit_id"), "buildings":roster(world,world.buildings,"building_id"),
		"selected_units":world.selected_units.size(), "scene_nodes":world.get_tree().get_node_count(),
		"orphan_nodes":Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
		"resources":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
		"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"call_log":preload("res://scripts/world/battle_call_counters.gd").paths.duplicate(),
		"effects":effect_counts(world.effects_root), "projectiles":effect_counts(world.projectiles_root),
		"path_requests":world.path_service.stats_paths, "path_failures":world.path_service.stats_path_fail
	}
	if world.frame_pacing != null:
		report.ai_strategy = world.ai_strategy_budget.diagnostics()
		# Keep the old diagnostic key for existing readers; it counts rejections.
		report.ai_strategy.deferred_frames = world.ai_strategy_budget.deferred
		report.ai_dispatch = {"unit_limit":world.ai_dispatch.limit,"admitted":world.ai_dispatch.admitted.size(),"waiting":world.allied_state.get("ai_dispatch_waiting",{}).size()}
		var pacing = world.frame_pacing
		report.adaptive_refresh = {"tier":pacing.tier, "chase_interval_s":pacing.CHASE_SECONDS[pacing.tier],
			"fog_interval_s":pacing.FOG_SECONDS[pacing.tier], "chase_replans":pacing.chase_replans,
			"fog_rebuilds":world.fog.rebuild_count if world.fog != null else 0}
	var path := ProjectSettings.globalize_path(DIRECTORY.path_join(name))
	writer = Thread.new()
	if writer.start(_write.bind(report,path)) != OK:
		writer = null
		return {"ok":false, "message":"无法启动性能快照写入任务。"}
	return {"ok":true, "message":"正在保存性能快照…"}

static func _write(report: Dictionary, path: String) -> Dictionary:
	# Godot allocator counters and process memory cover different allocations.
	# Query Windows off the render thread; restricted systems still get a report.
	if OS.get_name() == "Windows":
		var output := []
		var exe := OS.get_environment("SystemRoot").path_join("System32/WindowsPowerShell/v1.0/powershell.exe")
		var cmd := "$p=[Diagnostics.Process]::GetProcessById(%d); [Console]::WriteLine($p.WorkingSet64); [Console]::WriteLine($p.PrivateMemorySize64)" % report.pid
		var status := OS.execute(exe, ["-NoProfile","-NonInteractive","-WindowStyle","Hidden","-Command",cmd],output,false,false)
		var values := "\n".join(output).strip_edges().split("\n",false)
		if status == 0 and values.size() == 2 and values[0].strip_edges().is_valid_int() and values[1].strip_edges().is_valid_int():
			report.memory_bytes.working_set = values[0].to_int()
			report.memory_bytes.private_bytes = values[1].to_int()
			report.process_memory_sample_delay_ms = Time.get_ticks_msec() - int(report.uptime_ms)
		else: report.process_memory_status = "unavailable"
	if DirAccess.make_dir_recursive_absolute(path.get_base_dir()) == OK:
		var tmp := path + ".tmp"
		var file := FileAccess.open(tmp, FileAccess.WRITE)
		if file != null:
			var written := file.store_string(JSON.stringify(report,"\t"))
			file.flush()
			var valid := written and file.get_error() == OK
			file.close()
			if valid and DirAccess.rename_absolute(tmp,path) == OK:
				return {"ok":true, "message":"性能快照已保存："+path, "path":path}
			DirAccess.remove_absolute(tmp)
	return {"ok":false, "message":"性能快照写入失败，请检查目录和剩余空间："+path.get_base_dir()}
