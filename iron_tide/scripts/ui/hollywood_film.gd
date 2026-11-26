extends CanvasLayer

const Catalog = preload("res://scripts/ui/campaign_cg_catalog.gd")

var player := VideoStreamPlayer.new()
var mission_audio: AudioStreamPlayer
var skip := Button.new()
var clip_id := ""
var replay := false
var media: Dictionary
var paused_world := false
var completed: Callable
var subtitle := Label.new()
var radar: Control
var dock: ColorRect
var radio_dock:Control
var previous_radio_visibility:=false

static func show_clip(world, id: String, after := Callable()) -> void:
	if not _open(world,id,after,false) and after.is_valid(): after.call()

static func show_replay(parent: Node, id: String, after: Callable) -> bool:
	if MetaProgress.campaign_cg.get(id) != true: return false
	return _open(parent,id,after,true)

static func _open(parent: Node, id: String, after: Callable, is_replay: bool) -> bool:
	var sources := Catalog.media(id)
	if sources.is_empty() or not ResourceLoader.exists(sources.video): return false
	var stream := load(sources.video) as VideoStream
	if stream == null: return false
	var film = load("res://scripts/ui/hollywood_film.gd").new()
	film.name = "HollywoodFilm"
	film.clip_id = id
	film.completed = after
	film.replay = is_replay
	film.media = sources
	film.player.stream = stream
	parent.add_child(film)
	film.start()
	if not is_replay: MetaProgress.collect_campaign_cg(id)
	return true

func start() -> void:
	var full := replay or clip_id in ["A02_F00E","S01_F00E","S07_F00E","S08_F00E"]
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	if full:
		var background := ColorRect.new()
		background.color = Color.BLACK
		add_child(background)
		background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box := AspectRatioContainer.new()
	box.ratio = 4.0/3.0 if clip_id in ["A02_F00E","S01_F00E","S07_F00E","S08_F00E"] else 14.0/11.0
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
	skip.text = "返回收藏" if replay else "跳过影片"
	skip.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT if full else Control.PRESET_TOP_LEFT)
	if full:
		skip.offset_left = -144
		skip.offset_right = -20
		skip.offset_top = -68
		skip.offset_bottom = -20
		if not replay:
			paused_world = not get_tree().paused
			get_tree().paused = true
		else:
			skip.grab_focus()
	else:
		skip.reparent(dock, false)
		skip.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT,Control.PRESET_MODE_MINSIZE,3)
	skip.pressed.connect(finish)
	player.finished.connect(finish)
	add_child(subtitle)
	subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	subtitle.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	subtitle.anchor_right = 1.0 if full else 0.74
	subtitle.offset_left = 12
	subtitle.offset_right = -12
	subtitle.offset_top = -118 if full else -110
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
	player.play()
	_update_subtitle()

func _input(event: InputEvent) -> void:
	if replay and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		finish()

func _process(_delta: float) -> void:
	if mission_audio != null: player.speed_scale = 1.0 / Engine.time_scale
	if clip_id.begins_with("S01_") and is_instance_valid(radar) and not is_instance_valid(radio_dock):
		radio_dock=get_parent().hud._radio_dock
		if is_instance_valid(radio_dock):previous_radio_visibility=radio_dock.visible;radio_dock.hide()
	if is_instance_valid(radar): _align_radar()
	if player.is_playing(): _update_subtitle()

func _update_subtitle() -> void:
	subtitle.text = preload("res://scripts/ui/hollywood_subtitles.gd").at(clip_id,player.stream_position)

func _align_radar() -> void:
	var rect := radar.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, radar.size)
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
