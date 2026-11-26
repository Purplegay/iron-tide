extends Node
## A battle keeps one faction recording and follows the director's combat mood.
signal changed
const SETTINGS := "user://audio_settings.cfg"
const BUS := "Music"
const CROSSFADE := 1.5
const SUPERWEAPON_CUES := ["superweapon_used", "enemy_superweapon"]
const COMBAT_SEGMENTS := {
	"battle": Vector2(0, 77),
	"disadvantage": Vector2(78, 142),
	"victory": Vector2(143, 248),
}
var tracks: Array[Dictionary] = []
var faction := "allied"
var stage := "battle"
var _expected_title := ""
var current_index := -1
var context := ""
var enabled := true
var volume := 0.28
var player: AudioStreamPlayer
var outgoing: AudioStreamPlayer
var _last_tick := 0
var _resume_position := 0.0
var _mix := 1.0
var _gain := 0.0
var _requested_stage := "battle"
var combat_id := ""
var _segment := Vector2.ZERO
var _outgoing_end := 0.0
var _music_random := RandomNumberGenerator.new()
var uprising_triggered := false
var _red_alert := false
var _results := false
var exploring := false
var _yuriko_quiet := false
var exploration_id := ""
var cue := ""
var _pending_superweapon := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if AudioServer.get_bus_index(BUS) < 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, BUS)
		AudioServer.set_bus_send(AudioServer.get_bus_index(BUS), "Master")
	player = _make_player()
	outgoing = _make_player()
	player.finished.connect(_on_finished)
	load_settings()
	load_tracks()
	_last_tick = Time.get_ticks_msec()

func _make_player() -> AudioStreamPlayer:
	var node := AudioStreamPlayer.new()
	node.bus = BUS
	node.volume_linear = 0.0
	add_child(node)
	return node

func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS) == OK:
		enabled = bool(config.get_value("music", "enabled", true))
		volume = clampf(float(config.get_value("music", "volume", 0.28)), 0.0, 1.0)

func _save_settings() -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS)
	config.set_value("music", "enabled", enabled)
	config.set_value("music", "volume", volume)
	config.save(SETTINGS)

func load_tracks() -> void:
	tracks.clear()
	_expected_title = ""
	var value = JSON.parse_string(FileAccess.get_file_as_string("res://data/music.json"))
	if not value is Dictionary: return
	for item in value.get("tracks", []):
		if not item is Dictionary: continue
		var track_faction: String = item.get("faction", "allied")
		var yuri_win: bool = faction == "yuri" and track_faction == "japan" and item.get("stage") == "match_win"
		if track_faction not in [faction, "shared"] and not yuri_win: continue
		if _expected_title.is_empty(): _expected_title = str(item.get("title", ""))
		if ResourceLoader.exists(str(item.get("file", ""))): tracks.append(item)

func set_context(next: String, player_faction := "", start_exploring := false, map_track := "", saved_combat := "", mood := "battle", yuriko_quiet := false) -> void:
	var reset := context != "battle" or (not player_faction.is_empty() and faction != player_faction)
	if not player_faction.is_empty() and faction != player_faction:
		_halt()
		faction = player_faction
		load_tracks()
	if context != next or reset:
		cue = ""
		_pending_superweapon = ""
	context = next
	if next == "battle":
		if reset:
			_requested_stage = mood if COMBAT_SEGMENTS.has(mood) else "battle"
			combat_id = _choose_combat(saved_combat)
			uprising_triggered = false
			_red_alert = false
			_results = false
			exploring = start_exploring
			exploration_id = map_track
			_yuriko_quiet = yuriko_quiet
			stage = _base_stage()
			current_index = -1
		if enabled and (reset or not player.playing): next_track()
	elif next == "camp":
		exploring = false
		_results = false
		_apply_stage("camp")
	else:
		_halt()
		exploring = false
		current_index = -1
		_red_alert = false
	changed.emit()

func _choose_combat(saved: String) -> String:
	var choices: Array[String] = []
	for track in tracks:
		if track.stage == "battle":
			if track.id == saved: return saved
			choices.append(track.id)
	return "" if choices.is_empty() else choices[_music_random.randi_range(0, choices.size() - 1)]

func set_battle_stage(next_stage: String) -> void:
	if not COMBAT_SEGMENTS.has(next_stage) or context != "battle" or _results: return
	_requested_stage = next_stage
	if cue == "uprising" and next_stage != "battle": cue = ""
	if cue.is_empty(): _apply_stage(_base_stage())

func _base_stage() -> String:
	if _yuriko_quiet and _requested_stage == "battle": return "yuriko_tension"
	return "explore" if exploring else _requested_stage

func set_yuriko_quiet(quiet: bool) -> void:
	if context != "battle" or _results or _yuriko_quiet == quiet: return
	_yuriko_quiet = quiet
	if cue.is_empty(): _apply_stage(_base_stage())

func end_yuriko_music() -> void:
	if context != "battle" or _results: return
	_yuriko_quiet = false
	if cue in ["yuriko", "yuriko_tension"]: cue = ""
	if cue.is_empty() and stage in ["yuriko", "yuriko_tension"]:
		_apply_stage(_base_stage())

func engage() -> void:
	if context != "battle" or not exploring or _results: return
	exploring = false
	if cue.is_empty(): _apply_stage(_requested_stage)

func play_cue(kind: String) -> void:
	if context != "battle" or _results: return
	if kind not in SUPERWEAPON_CUES and kind not in ["yuriko","yuriko_tension","uprising"]: return
	if cue in SUPERWEAPON_CUES:
		if kind in SUPERWEAPON_CUES and kind != cue: _pending_superweapon = kind
		return
	cue = kind
	_apply_stage(kind)

func set_red_alert(active: bool) -> void:
	# Red Alert gameplay and the PathMusic state machine are independent.
	if context != "battle" or _results: return
	_red_alert = active

func finish_battle(win: bool) -> void:
	_red_alert = false
	cue = ""
	_pending_superweapon = ""
	exploring = false
	if win:
		_results = true
		_requested_stage = "victory"
		_apply_stage("victory")
	else:
		set_context("results")

func _apply_stage(next: String) -> void:
	var changed_stage := stage != next
	stage = next
	if enabled and (changed_stage or not player.playing or current_index != _desired_index()): next_track()
	changed.emit()

func _desired_index() -> int:
	var wanted := stage
	if _results and wanted == "victory":
		for index in tracks.size():
			if tracks[index].stage == "match_win": return index
	if wanted == "victory" and not combat_id.is_empty():
		for index in tracks.size():
			if tracks[index].get("combat_id") == combat_id and tracks[index].stage == wanted:
				return index
	if COMBAT_SEGMENTS.has(stage) and not _results:
		for index in tracks.size():
			if tracks[index].id == combat_id: return index
		return -1
	var choices: Array[int] = []
	for index in tracks.size():
		if str(tracks[index].get("stage", "battle")) == wanted: choices.append(index)
	if choices.is_empty(): return -1
	if wanted == "explore":
		for index in choices:
			if tracks[index].id == exploration_id: return index
		var picked: int = choices.pick_random()
		exploration_id = tracks[picked].id
		return picked
	if wanted == "victory" and uprising_triggered and choices.size() > 1: return choices[1]
	return choices[0]

func next_track() -> void:
	if not enabled or context not in ["battle","camp"]: return
	var index := _desired_index()
	if index < 0: return
	var segment: Vector2 = COMBAT_SEGMENTS[stage] if tracks[index].stage == "battle" else Vector2.ZERO
	if current_index == index and _segment == segment and player.playing: return
	var stream := load(str(tracks[index].file)) as AudioStreamMP3
	if stream == null or stream.get_length() <= 0.0: return
	stream.loop = false
	# The old score keeps playing while the new score fades in; no silent gap.
	outgoing.stop()
	_outgoing_end = _segment.y
	if player.playing:
		outgoing.stream = player.stream
		outgoing.play(player.get_playback_position())
		outgoing.volume_linear = player.volume_linear
	player.stop()
	player.stream = stream
	player.volume_linear = 0.0
	_segment = segment
	player.play(_segment.x)
	current_index = index
	if stage == "explore" and has_meta("director_state"): get_meta("director_state").map_track = exploration_id
	_resume_position = _segment.x
	_mix = 0.0
	changed.emit()

func _on_finished() -> void:
	if _results or context not in ["battle","camp"]: return
	if not cue.is_empty():
		if not _pending_superweapon.is_empty():
			cue = _pending_superweapon
			_pending_superweapon = ""
			_apply_stage(cue)
			return
		cue = ""
		stage = _base_stage()
	elif stage == "explore": rotate_exploration()
	next_track()

func rotate_exploration() -> void:
	if stage == "explore":
		var alternatives := tracks.filter(func(track): return track.stage == "explore" and track.id != exploration_id)
		if not alternatives.is_empty(): exploration_id = alternatives.pick_random().id

func skip_or_replay() -> void:
	if not enabled or context not in ["battle","camp"]: return
	if stage == "explore":
		rotate_exploration()
		next_track()
	elif player.playing: player.seek(_segment.x)
	else: next_track()

func _halt() -> void:
	player.stop()
	outgoing.stop()
	player.volume_linear = 0.0
	outgoing.volume_linear = 0.0
	_resume_position = 0.0
	_segment = Vector2.ZERO
	_mix = 1.0

func stop() -> void:
	context = ""
	_halt()
	changed.emit()

func set_enabled(value: bool) -> void:
	if enabled == value: return
	enabled = value
	if not enabled:
		_resume_position = player.get_playback_position()
		player.stop()
		outgoing.stop()
	elif context in ["battle","camp"]:
		if player.stream != null and current_index == _desired_index() and current_index >= 0 and (_segment == Vector2.ZERO or _segment == COMBAT_SEGMENTS.get(stage)):
			player.play(_resume_position)
			_mix = 0.0
		else: next_track()
	_save_settings()
	changed.emit()

func set_volume(value: float) -> void:
	volume = clampf(value, 0.0, 1.0)
	if volume == 0.0:
		_gain = 0.0
		player.volume_linear = 0.0
		outgoing.volume_linear = 0.0
	_save_settings()
	changed.emit()

func current_title() -> String:
	if current_index >= 0 and current_index < tracks.size(): return str(tracks[current_index].get("title", "背景音乐"))
	return "待放入 " + _expected_title if not _expected_title.is_empty() else "该阵营未配置战斗音乐"

func target_gain() -> float:
	if not enabled or context not in ["battle","camp"]: return 0.0
	var gain := volume * 0.8
	if get_tree().paused: gain *= 0.55
	if Ra2Sfx._eva_player.playing or Ra2Sfx.unit_voice_active(): gain *= 0.35
	return gain

func _process(_delta: float) -> void:
	if _segment.y > 0.0 and player.playing and player.get_playback_position() >= _segment.y:
		player.seek(_segment.x)
	if _outgoing_end > 0.0 and outgoing.playing and outgoing.get_playback_position() >= _outgoing_end:
		outgoing.stop()
	var now := Time.get_ticks_msec()
	var elapsed := clampf((now - _last_tick) / 1000.0, 0.0, 0.1)
	_last_tick = now
	var target := target_gain()
	_gain = move_toward(_gain, target, elapsed * (2.0 if target < _gain else 0.4))
	_mix = minf(1.0, _mix + elapsed / CROSSFADE)
	player.volume_linear = _gain * _mix
	outgoing.volume_linear = _gain * (1.0 - _mix)
	if _mix >= 1.0 and outgoing.playing: outgoing.stop()
