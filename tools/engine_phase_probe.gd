extends Node
## Diagnostic boundaries, not an engine CPU/GPU profiler. Record in memory;
## serialize only after the measured window has ended.
const LABELS := ["physics_begin", "physics_callbacks_end", "process_begin", "process_callbacks_end", "draw_begin", "draw_end"]
var events := PackedInt64Array()
var monitors: Array = []
var enabled := false

func start() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 2000001
	process_physics_priority = 2000001
	get_tree().physics_frame.connect(_physics_begin)
	get_tree().process_frame.connect(_process_begin)
	RenderingServer.frame_pre_draw.connect(_draw_begin)
	RenderingServer.frame_post_draw.connect(_draw_end)
	enabled = true

func record(kind: int) -> void:
	if not enabled: return
	events.append(kind)
	events.append(Engine.get_process_frames())
	events.append(Time.get_ticks_usec())

func _physics_begin() -> void:
	record(0)

func _physics_process(_delta: float) -> void:
	record(1)

func _process_begin() -> void:
	record(2)

func _process(_delta: float) -> void:
	record(3)
	if enabled:
		monitors.append([Engine.get_process_frames(), Performance.get_monitor(Performance.TIME_PROCESS),
			Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS),
			Performance.get_monitor(Performance.PHYSICS_2D_ACTIVE_OBJECTS),
			Performance.get_monitor(Performance.PHYSICS_2D_COLLISION_PAIRS)])

func _draw_begin() -> void:
	record(4)

func _draw_end() -> void:
	record(5)

func finish(directory: String) -> void:
	enabled = false
	get_tree().physics_frame.disconnect(_physics_begin)
	get_tree().process_frame.disconnect(_process_begin)
	RenderingServer.frame_pre_draw.disconnect(_draw_begin)
	RenderingServer.frame_post_draw.disconnect(_draw_end)
	FileAccess.open(directory.path_join("engine-phases.json"), FileAccess.WRITE).store_string(JSON.stringify({
		"labels": LABELS, "event_stride": 3, "event_fields": ["kind", "process_frame", "usec"], "events": events,
		"monitor_fields": ["process_frame", "engine_process_seconds", "engine_physics_seconds", "active_2d_objects", "collision_2d_pairs"], "monitors": monitors,
		"scope": "Main-thread wall-clock signal/callback boundaries; includes scheduling delays and later callbacks. Not native-function self time or GPU time. Engine monitors can refer to the preceding frame."}))
