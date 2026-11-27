extends CanvasLayer

const Catalog = preload("res://scripts/ui/campaign_cg_catalog.gd")
const OPENING_CLIPS := ["A01_F00E","A01_P01E","A02_F00E","A02_P01E","A02_P02E","A07_F00E","A07_P01E","S01_F00E","S07_F00E","S07_P01E"]

var player := VideoStreamPlayer.new()
var mission_audio: AudioStreamPlayer
var skip := Button.new()
var clip_id := ""
var replay := false
var media: Dictionary
var paused_world := false
var completed: Callable
var presentation_tick: Callable
var subtitle := Label.new()
var radar: Control
var dock: ColorRect
var radio_dock:Control
var previous_radio_visibility:=false
var hold_radio_frame := false
var opening_radio_deadline_ms := 0
var replay_slider: HSlider
var replay_clock: Label
var replay_still: TextureRect
var replay_dragging := false
var replay_length := 0.0
var replay_video_length := 0.0

static func show_clip(world, id: String, after := Callable(), on_time := Callable()) -> void:
	if not _open(world,id,after,false,on_time) and after.is_valid(): after.call()

static func show_replay(parent: Node, id: String, after: Callable) -> bool:
	if MetaProgress.campaign_cg.get(id) != true: return false
	return _open(parent,id,after,true)

static func _open(parent: Node, id: String, after: Callable, is_replay: bool, on_time := Callable()) -> bool:
	var sources := Catalog.media(id)
	if sources.is_empty() or not ResourceLoader.exists(sources.video): return false
	var stream := load(sources.video) as VideoStream
	if stream == null: return false
	var film = load("res://scripts/ui/hollywood_film.gd").new()
	film.name = "HollywoodFilm"
	film.clip_id = id
	film.completed = after
	film.presentation_tick = on_time
	film.replay = is_replay
	film.media = sources
	film.player.stream = stream
	parent.add_child(film)
	film.start()
	if not is_replay: MetaProgress.collect_campaign_cg(id)
	return true

func start() -> void:
	var full := replay or clip_id.contains("_F")
	var opening := not replay and clip_id in OPENING_CLIPS
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	if full:
		var background := ColorRect.new()
		background.color = Color.BLACK
		add_child(background)
		background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box := AspectRatioContainer.new()
	box.ratio = 4.0/3.0 if clip_id.contains("_F") else 14.0/11.0
	add_child(box)
	if full:
		box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	else:
		radar = get_parent().hud.minimap
		dock = ColorRect.new()
		dock.color = Color.BLACK
		# The small film is visual only; the radar beneath it still owns the mouse.
		dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		player.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(dock)
		box.reparent(dock, false)
		box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_align_radar()
	box.add_child(player)
	player.expand = true
	add_child(skip)
	skip.text = "返回收藏" if replay else ("跳过简报" if opening else "跳过影片")
	skip.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT if full or opening else Control.PRESET_TOP_LEFT)
	if full or opening:
		skip.offset_left = -144
		skip.offset_right = -20
		skip.offset_top = -68
		skip.offset_bottom = -20
	else:
		skip.reparent(dock, false)
		skip.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT,Control.PRESET_MODE_MINSIZE,3)
	if replay:
		skip.grab_focus()
	elif full or clip_id in ["A01_P01E","A01_P02E"]:
		paused_world = not get_tree().paused
		get_tree().paused = true
	skip.pressed.connect(finish)
	player.finished.connect(_video_finished)
	add_child(subtitle)
	subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	subtitle.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	subtitle.anchor_right = 1.0 if full else 0.74
	subtitle.offset_left = 12
	subtitle.offset_right = -12
	subtitle.offset_top = -146 if replay else (-118 if full else -110)
	subtitle.offset_bottom = subtitle.offset_top + 78
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size",27 if full else 24)
	subtitle.add_theme_color_override("font_outline_color",Color.BLACK)
	subtitle.add_theme_constant_override("outline_size",6)
	if not media.audio.is_empty() and ResourceLoader.exists(media.audio):
		mission_audio = AudioStreamPlayer.new()
		add_child(mission_audio)
		mission_audio.stream = load(media.audio)
		player.volume = 0.0
		player.speed_scale = 1.0 / Engine.time_scale
		mission_audio.play()
	if opening or presentation_tick.is_valid(): player.speed_scale = 1.0 / Engine.time_scale
	player.play()
	if replay:
		_add_replay_timeline()
	if opening:
		# Even a backend that never emits finished must eventually release the mission.
		var duration := mission_audio.stream.get_length() if mission_audio != null and mission_audio.stream != null else 0.0
		var video_length := player.get_stream_length()
		if video_length <= 0.0: video_length = 120.0 if full else 30.0
		# The audio clock is authoritative for the two separately timed radar briefs.
		if _has_radio_audio() and duration > 0.0: video_length = 0.0
		opening_radio_deadline_ms = Time.get_ticks_msec() + int(1000.0 * (maxf(3.0, maxf(duration, video_length)) + 3.0))
	_update_subtitle()

func _add_replay_timeline() -> void:
	replay_video_length = player.get_stream_length()
	replay_length = replay_video_length
	if _has_radio_audio():
		replay_length = maxf(replay_length, mission_audio.stream.get_length())
		mission_audio.finished.connect(_replay_audio_finished)
	if replay_video_length <= 0.0:
		return
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 12)
	add_child(bar)
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_left = 20
	bar.offset_right = -160
	bar.offset_top = -59
	bar.offset_bottom = -29
	replay_slider = HSlider.new()
	replay_slider.name = "ReplayTimeline"
	replay_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	replay_slider.max_value = replay_length
	replay_slider.step = 0.01
	replay_slider.scrollable = false
	replay_slider.tooltip_text = "拖动进度条跳转播放位置"
	bar.add_child(replay_slider)
	replay_clock = Label.new()
	replay_clock.add_theme_color_override("font_outline_color", Color.BLACK)
	replay_clock.add_theme_constant_override("outline_size", 6)
	bar.add_child(replay_clock)
	replay_slider.drag_started.connect(_replay_drag_start)
	replay_slider.drag_ended.connect(_replay_drag_end)
	replay_slider.value_changed.connect(_replay_slider_changed)
	_update_replay_timeline(0.0)

func _has_radio_audio() -> bool:
	return mission_audio != null and clip_id in ["A01_P01E", "A07_P01E"]

func _replay_audio_finished() -> void:
	if replay_still != null:
		finish()

func _replay_drag_start() -> void:
	replay_dragging = true
	player.paused = true
	if mission_audio != null:
		mission_audio.stream_paused = true

func _replay_drag_end(_changed: bool) -> void:
	replay_dragging = false
	_seek_replay(replay_slider.value)

func _replay_slider_changed(value: float) -> void:
	if replay_dragging:
		_update_replay_timeline(value)
	else:
		_seek_replay(value)

func _seek_replay(seconds: float) -> void:
	# Theora rejects timestamps at or beyond EOF; the last playable instant is enough.
	var target := clampf(seconds, 0.0, maxf(0.0, replay_length - 0.05))
	if _has_radio_audio() and target >= replay_video_length:
		player.paused = true
		_show_replay_still()
	else:
		if replay_still != null:
			replay_still.hide()
			replay_still.queue_free()
			replay_still = null
		if not player.is_playing():
			player.play()
		player.stream_position = minf(target, maxf(0.0, replay_video_length - 0.05))
		player.paused = false
	if mission_audio != null:
		mission_audio.stream_paused = false
		if target < mission_audio.stream.get_length():
			mission_audio.play(target)
		else:
			mission_audio.stop()
	_update_replay_timeline(target)
	_update_subtitle(target)

func _show_replay_still() -> void:
	if replay_still == null:
		replay_still = _add_radio_still()

func _update_replay_timeline(seconds: float) -> void:
	replay_slider.set_value_no_signal(seconds)
	replay_clock.text = "%s / %s" % [_clock_time(seconds), _clock_time(ceilf(replay_length))]

func _clock_time(seconds: float) -> String:
	var whole := int(seconds)
	return "%02d:%02d" % [floori(whole / 60.0), whole % 60]

func _input(event: InputEvent) -> void:
	if replay and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		finish()

func _process(_delta: float) -> void:
	if opening_radio_deadline_ms > 0 and Time.get_ticks_msec() >= opening_radio_deadline_ms:
		finish()
		return
	if mission_audio != null or presentation_tick.is_valid() or (not replay and clip_id in OPENING_CLIPS): player.speed_scale = 1.0 / Engine.time_scale
	if (clip_id.begins_with("S01_") or clip_id in ["A01_P01E","A07_P01E"]) and is_instance_valid(radar) and not is_instance_valid(radio_dock):
		radio_dock=get_parent().hud._radio_dock
		if is_instance_valid(radio_dock):previous_radio_visibility=radio_dock.visible;radio_dock.hide()
	if is_instance_valid(radar): _align_radar()
	if replay_slider != null and not replay_dragging:
		_update_replay_timeline(_playback_seconds())
	if player.is_playing() or hold_radio_frame or replay_still != null: _update_subtitle()

func _video_finished() -> void:
	if clip_id in ["A01_P01E","A07_P01E"] and mission_audio!=null and mission_audio.playing:
		if replay:
			_show_replay_still()
		else:
			hold_radio_frame = true
			_add_radio_still()
			mission_audio.finished.connect(finish,CONNECT_ONE_SHOT)
		return
	finish()

func _add_radio_still() -> TextureRect:
	var still := TextureRect.new()
	still.texture = load(str(media.video).get_basename() + "_hold.png")
	still.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	still.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	still.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player.add_child(still)
	still.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return still

func _playback_seconds() -> float:
	if _has_radio_audio() and (not replay or mission_audio.playing):
		return mission_audio.get_playback_position()
	return player.stream_position

func _update_subtitle(seconds := -1.0) -> void:
	var position := _playback_seconds() if seconds < 0.0 else seconds
	subtitle.text = preload("res://scripts/ui/hollywood_subtitles.gd").at(clip_id, position)
	if presentation_tick.is_valid(): presentation_tick.call(position)

func _align_radar() -> void:
	var rect := radar.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, radar.size)
	if clip_id in OPENING_CLIPS and (not radar.is_visible_in_tree() or rect.size.x < 48.0 or rect.size.y < 48.0):
		# A collapsed radar must not hide a briefing that has locked the field.
		var bounds := get_viewport().get_visible_rect()
		var extent := Vector2(210,165).min(bounds.size * 0.35)
		rect = Rect2(bounds.end - extent - Vector2(20,82),extent)
	dock.position = rect.position
	dock.size = rect.size

func finish() -> void:
	if is_queued_for_deletion(): return
	if mission_audio != null: mission_audio.stop()
	player.stop()
	queue_free()
	if paused_world:
		get_tree().paused = false
		paused_world = false
	if completed.is_valid(): completed.call()

func _exit_tree() -> void:
	if is_instance_valid(radio_dock):radio_dock.visible=previous_radio_visibility
	if paused_world: get_tree().paused = false
