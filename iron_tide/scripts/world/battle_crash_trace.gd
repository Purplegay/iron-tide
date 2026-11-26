extends Node
## One independent file per battle. Critical boundaries flush immediately.
const DIRECTORY := "user://battle-traces"
var stream: FileAccess
var world
var next_sample := 0
var recent: Array[String] = []

func start(battle) -> void:
	world = battle
	add_to_group("battle_crash_trace")
	process_mode = Node.PROCESS_MODE_ALWAYS
	if DirAccess.make_dir_recursive_absolute(DIRECTORY) == OK:
		var stamp := Time.get_datetime_string_from_system().replace(":", "-")
		stream = FileAccess.open("%s/%s-%d-%d.jsonl" % [DIRECTORY, stamp, OS.get_process_id(), Time.get_ticks_msec()], FileAccess.WRITE)
	if stream == null:
		push_warning("无法写入战场诊断日志")
		set_process(false)
		return
	mark("battle.open", {"pid": OS.get_process_id(), "mission": BattleRequest.mission_id, "mode": BattleRequest.rules_mode})
	Events.battle_message.connect(func(text: String, _color: Color): remember(text.left(120)))
	Events.command_mode_changed.connect(func(mode: String): remember("command " + mode))
	Events.selection_changed.connect(func(selection: Array): remember("selection %d" % selection.size()))

func remember(text: String) -> void:
	if recent.size() == 12:
		recent.pop_front()
	recent.append("%d %s" % [Time.get_ticks_msec(), text])

func mark(stage: String, fields: Dictionary = {}) -> void:
	if stream == null:
		return
	fields["stage"] = stage
	fields["time"] = Time.get_datetime_string_from_system()
	fields["ms"] = Time.get_ticks_msec()
	fields["frame"] = Engine.get_process_frames()
	if not recent.is_empty():
		fields["recent"] = recent
	stream.store_line(JSON.stringify(fields))
	stream.flush()
	recent.clear()

func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	if now < next_sample or not is_instance_valid(world):
		return
	next_sample = now + 1000
	mark("heartbeat", {"units": world.units.size(), "buildings": world.buildings.size(), "kills": world.kills, "funds": world.funds, "selected": world.selected_units.size(), "paused": world.paused or get_tree().paused})

func _exit_tree() -> void:
	mark("battle.exit")
	stream = null
