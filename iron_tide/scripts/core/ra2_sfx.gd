extends Node
## Ra2Sfx —— RA2 音效播放服务（autoload）。
## 事实源：data/ra2/sound_specs.json（sound.ini [SoundList]）+ assets/ra2/sfx/*.wav。
## 口径：Weapon Report=<sound id> → [sound.ini] 的 <id> → Sounds=[...] → 随机取一个 wav。
## Volume= 归一为线性 0..1；Range= 单位格 → px(max_distance)。

const POOL_SIZE := 32
const PX_PER_CELL := 55.0
const COMMAND_VOICE_KINDS := ["created", "move_attack", "move_special", "select_mirage", "select_battle", "select_under_fire", "retreat", "select", "move", "attack", "attack_special", "attack_beam", "feedback", "harvest", "enter", "capture", "deploy_command", "secondary_attack", "select_deactivated", "select_enslaved"]

const CACHE_ENTRIES := 256
const CACHE_BYTES := 16 * 1024 * 1024
var _cached_sizes: Dictionary[String, int] = {}
var _cached_bytes := 0
var _cache: Dictionary = {}                 # file -> AudioStreamWAV
var _pool: Array[AudioStreamPlayer2D] = []
var _cursor := 0
var _global_pool: Array[AudioStreamPlayer] = []
var _global_cursor := 0
# A retail line can contain speech and a simultaneous psychic layer.
var _yuriko_layers: Array[Node] = []
var _yuriko_next: Dictionary = {}
var _master_linear := 1.0
var _voice_lock: Dictionary = {}            # sound id -> 上次播放 msec（语音节流）
var a_plays := 0                            # 诊断：成功播放次数
var a_misses := 0                           # 诊断：无音频/空 id 次数
var _support_ready_frame := -1
var a_voice_plays := 0                      # 诊断：成功播放的单位语音次数
var a_voice_misses := 0                     # 诊断：该单位无此语音的次数

# ---- EVA（规则事实源：eva.ini；音频 assets/ra2/eva/*.wav）----
# RA2 口径：EVA 是全局 2D 播音，逐条排队；高优先级可打断低优先级；同事件短时去重。
const EVA_PRI := {"LOW": 0, "NORMAL": 1, "IMPORTANT": 2, "CRITICAL": 3}
const EVA_VOLUME_DB := -4.0
const REINFORCEMENTS_ARRIVED := "EVA_ReinforcementsHaveArrived"
const STRATEGIC_SUPPORT_READY := "STRATEGIC_SUPPORT_READY"
const SUPPORT_READY_FILE := "irontide_support_ready.wav"
var eva_enabled := true
var _eva_player: AudioStreamPlayer
var _eva_queue: Array[Dictionary] = []      # 待播 [{event, file, pri}]
var _eva_cur_pri := -1
var _eva_last: Dictionary = {}              # event -> 上次入队 msec（去重）
var a_eva_plays := 0                        # 诊断：成功播放的 EVA 条数
var a_eva_misses := 0                       # 诊断：没有该事件/音频的次数
var a_eva_queued := 0                       # 诊断：排队次数

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL_SIZE:
		var p := AudioStreamPlayer2D.new()
		p.bus = "Master"
		p.attenuation = 1.0
		p.panning_strength = 0.6
		add_child(p)
		_pool.append(p)
		var global_player := AudioStreamPlayer.new()
		global_player.bus = "Master"
		add_child(global_player)
		_global_pool.append(global_player)
	_eva_player = AudioStreamPlayer.new()
	_eva_player.bus = "Master"
	add_child(_eva_player)

func _process(_dt: float) -> void:
	if _eva_player and not _eva_player.playing and not _eva_queue.is_empty():
		var nxt: Dictionary = _eva_queue.pop_front()
		_start_eva(nxt)

func _exit_tree() -> void:
	stop_all()
	_cache.clear()
	_cached_sizes.clear()
	_cached_bytes = 0

## A battle owns playback, while the autoload keeps reusable players and assets.
## Clear session cooldowns too: a new battle must not inherit suppressed responses.
func stop_all() -> void:
	_yuriko_next.clear()
	for layer in _yuriko_layers:
		layer.stop()
		layer.queue_free()
	_yuriko_layers.clear()
	stop_eva()
	if is_inside_tree():
		for audio in get_tree().get_nodes_in_group("spy_engine_audio"):
			audio.stop()
			audio.queue_free()
		for audio in get_tree().get_nodes_in_group("ivan_tick_audio"):
			if is_instance_valid(audio.get_parent()): stop_ivan_tick(audio.get_parent())
	for player in _pool:
		if is_instance_valid(player):
			player.stop()
			player.stream = null
	for player in _global_pool:
		if is_instance_valid(player):
			player.stop()
			player.stream = null
	if is_instance_valid(_eva_player):
		_eva_player.stream = null
	_voice_lock.clear()
	_support_ready_frame = -1
	_eva_last.clear()
	_cursor = 0
	_global_cursor = 0

# The advisor belongs to the commander, including when operating a captured factory.
const SUPERWEAPON_ALERT_VOICES := {
	"LightningStorm": "EVA_LightningStormCreated", "MultiMissile": "EVA_NuclearMissileLaunched",
	"ChronoSphere": "EVA_ChronosphereActivated", "IronCurtain": "EVA_IronCurtainActivated",
}

const SUPERWEAPON_DETECTED_VOICES := {
	"LightningStorm": "EVA_WeatherDeviceReady", "MultiMissile": "EVA_NuclearSiloDetected",
	"ChronoSphere": "EVA_ChronosphereDetected", "IronCurtain": "EVA_IronCurtainDetected",
}

const SUPPORT_READY_VOICES := {
	"LightningStorm": "EVA_LightningStormReady", "MultiMissile": "EVA_NuclearMissileReady",
	"ChronoSphere": "EVA_ChronosphereReady", "IronCurtain": "EVA_IronCurtainReady",
	"AmerParaDrop": "EVA_ReinforcementsReady",
}

func play_support_ready(world, weapon_type := "") -> void:
	if SUPPORT_READY_VOICES.has(weapon_type):
		play_player_eva(world, SUPPORT_READY_VOICES[weapon_type])
		return
	var frame := Engine.get_process_frames()
	if _support_ready_frame != frame:
		_support_ready_frame = frame
		play("SupportReady")
		if eva_enabled:
			_queue_eva(STRATEGIC_SUPPORT_READY, SUPPORT_READY_FILE, EVA_PRI.NORMAL, 1800)

func play_enemy_superweapon_alert(world, weapon_type: String) -> void:
	if SUPERWEAPON_ALERT_VOICES.has(weapon_type):
		play_player_eva(world, SUPERWEAPON_ALERT_VOICES[weapon_type], 0)
		return
	var player := _take_global_player()
	player.stream = _stream("uwarning.wav")
	player.set_meta("unit_voice", false)
	player.volume_db = _linear_to_db(maxf(0.0001, _master_linear))
	player.play()

func play_player_eva(world, event: String, min_gap_ms: int = 1200) -> bool:
	var faction: String = world.roster_faction() if is_instance_valid(world) else "allied"
	return play_eva(event, faction, min_gap_ms)

## 播放一条 EVA 语音。event 形如 "EVA_ConstructionComplete"；side 用 "allied"/"soviet" 选语言。
func play_eva(event: String, side: String = "allied", min_gap_ms: int = 1200) -> bool:
	if not eva_enabled or event.strip_edges() == "":
		a_eva_misses += 1
		return false
	var key := event.to_upper()
	if not GameData.has_ra2_eva(key):
		a_eva_misses += 1
		return false
	var spec: Dictionary = GameData.ra2_eva_spec(key)
	var id := GameData.ra2_eva_sound_id(key, side)
	var f: Dictionary = GameData.ra2_eva_file(id)
	if f.is_empty():
		a_eva_misses += 1
		return false
	var pri := int(EVA_PRI.get(str(spec.get("priority", "NORMAL")).to_upper(), 1))
	return _queue_eva(key, str(f.get("file", "")), pri, min_gap_ms)

func _queue_eva(key: String, file: String, pri: int, min_gap_ms: int) -> bool:
	var now := Time.get_ticks_msec()
	# 同事件 min_gap_ms 内去重（生产循环 / 反复受击等易刷屏）
	if now - int(_eva_last.get(key, -999999)) < min_gap_ms:
		return false
	_eva_last[key] = now
	var item := {"event": key, "file": file, "pri": pri}
	# Higher-priority alerts interrupt. Ordinary announcements of equal priority queue in order.
	if _eva_player.playing and _eva_cur_pri >= pri:
		# Keep simultaneous ordinary lines intelligible and coalesce repeats.
		if key != REINFORCEMENTS_ARRIVED.to_upper():
			for waiting in _eva_queue:
				if waiting.event == key: return false
		_eva_queue.append(item)
		a_eva_queued += 1
		return true
	# Outstanding arrival announcements each represent a distinct landed batch.
	for index in range(_eva_queue.size() - 1, -1, -1):
		if _eva_queue[index].event != REINFORCEMENTS_ARRIVED.to_upper():
			_eva_queue.remove_at(index)
	_start_eva(item)
	return true

func stop_eva() -> void:
	_eva_queue.clear()
	_eva_cur_pri = -1
	if is_instance_valid(_eva_player):
		_eva_player.stop()

func _start_eva(item: Dictionary) -> void:
	var s := _stream_eva(str(item.get("file", "")))
	if s == null:
		a_eva_misses += 1
		return
	_eva_player.stream = s
	_eva_player.volume_db = EVA_VOLUME_DB
	_eva_player.play()
	_eva_cur_pri = int(item.get("pri", 1))
	a_eva_plays += 1

func _stream_eva(file_name: String) -> AudioStreamWAV:
	if file_name == "":
		return null
	return _cached_stream("eva:" + file_name, GameData.ra2_eva_path(file_name))

func set_master_linear(v: float) -> void:
	_master_linear = clampf(v, 0.0, 2.0)

func _stream(file_name: String) -> AudioStreamWAV:
	return _cached_stream(file_name, GameData.ra2_sfx_path(file_name))

func _cached_stream(key: String, path: String) -> AudioStreamWAV:
	if _cache.has(key):
		var hit: AudioStreamWAV = _cache[key]
		_cache.erase(key)
		_cache[key] = hit
		return hit
	var stream := load(path) as AudioStreamWAV if ResourceLoader.exists(path) else null
	var bytes := stream.data.size() if stream != null else 0
	if bytes > CACHE_BYTES: return stream
	while _cache.size() >= CACHE_ENTRIES or _cached_bytes + bytes > CACHE_BYTES:
		var oldest: String = _cache.keys()[0]
		_cached_bytes -= _cached_sizes[oldest]
		_cached_sizes.erase(oldest)
		_cache.erase(oldest)
	_cache[key] = stream
	_cached_sizes[key] = bytes
	_cached_bytes += bytes
	return stream

## 播放一个 sound id（sound.ini 里的名字，如 "GrizzlyTankAttack"）。
## pos 为世界坐标；pos 传 Vector2.INF 表示全局播放（不受镜头距离影响）。
func play(id: String, pos := Vector2.INF, unit_voice: bool = false) -> bool:
	return _play_sound(id, pos, unit_voice, false)

func _play_sound(id: String, pos: Vector2, unit_voice: bool, yuriko: bool) -> bool:
	if id.strip_edges() == "":
		a_misses += 1
		return false
	var files: Array = GameData.ra2_sound_files(id)
	if files.is_empty():
		a_misses += 1
		return false
	var file_name := str(files[randi() % files.size()])
	var s := _stream(file_name)
	if s == null:
		a_misses += 1
		return false
	var spec: Dictionary = GameData.ra2_sound_spec(id)
	# 循环
	if _num(spec.get("loop", 0)) != 0.0:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = s.data.size() / (2 * (2 if s.stereo else 1))
	var volume_db := _linear_to_db(clampf(GameData.ra2_sound_volume(id) * _master_linear, 0.0001, 4.0))
	if pos.is_finite():
		var p := AudioStreamPlayer2D.new() if yuriko else _take_player()
		if yuriko:
			p.panning_strength = 0.6
			_track_yuriko_layer(p)
		p.stream = s
		p.set_meta("unit_voice", unit_voice)
		p.volume_db = volume_db
		p.max_distance = maxf(GameData.ra2_sound_range_cells(id), 0.5) * PX_PER_CELL
		p.global_position = pos
		p.play()
	else:
		var p := AudioStreamPlayer.new() if yuriko else _take_global_player()
		if yuriko: _track_yuriko_layer(p)
		p.stream = s
		p.set_meta("unit_voice", unit_voice)
		p.volume_db = volume_db
		p.play()
	a_plays += 1
	# Native RA3 Multisound is concurrent layers, not a single random pool.
	for layer in spec.get("layers", []): _play_sound(str(layer), pos, unit_voice, yuriko)
	return true

func _track_yuriko_layer(player: Node) -> void:
	add_child(player)
	_yuriko_layers.append(player)
	player.finished.connect(_on_yuriko_layer_finished.bind(player), CONNECT_ONE_SHOT)

func _on_yuriko_layer_finished(player: Node) -> void:
	if not _yuriko_layers.has(player): return
	_yuriko_layers.erase(player)
	player.queue_free()
	if _yuriko_layers.is_empty() and not _yuriko_next.is_empty():
		var next := _yuriko_next
		_yuriko_next = {}
		_start_yuriko_voice(next.id, next.pos)

func _start_yuriko_voice(id: String, pos: Vector2) -> bool:
	if not _play_sound(id, pos, true, true): return false
	a_voice_plays += 1
	return true

func _request_yuriko_voice(id: String, pos: Vector2, kind: String) -> bool:
	if _yuriko_layers.is_empty(): return _start_yuriko_voice(id, pos)
	# Keep one relevant response during rapid orders. A farewell supersedes waiting orders.
	if _yuriko_next.get("farewell", false): return false
	_yuriko_next = {"id": id, "pos": pos, "farewell": kind in ["die", "die_fire", "die_shock", "crush"]}
	return true

## Bomb owns its positional sound so removal, loading or disarm stops the loop.
func start_ivan_tick(actor) -> void:
	start_attached_loop(actor,"IvanTick","ivan_tick_audio","CrazyIvanBombTick")

func start_attached_loop(actor, node_name: String, group: String, sound: String) -> void:
	if actor.has_node(NodePath(node_name)) or get_tree().get_nodes_in_group(group).size() >= 3: return
	var files := GameData.ra2_sound_files(sound)
	if files.is_empty(): return
	var original := _stream(files.pick_random())
	if original == null: return
	var audio := AudioStreamPlayer2D.new()
	audio.name = node_name
	var loop := original.duplicate() as AudioStreamWAV
	loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	loop.loop_end = roundi(loop.get_length() * loop.mix_rate)
	audio.stream = loop
	audio.volume_db = _linear_to_db(clampf(GameData.ra2_sound_volume(sound) * _master_linear,0.0001,4.0))
	audio.max_distance = maxf(GameData.ra2_sound_range_cells(sound),0.5) * PX_PER_CELL
	actor.add_child(audio)
	audio.add_to_group(group)
	audio.play()

func stop_ivan_tick(actor) -> void:
	var audio := actor.get_node_or_null("IvanTick") as AudioStreamPlayer2D
	if audio != null:
		audio.stop()
		actor.remove_child(audio)
		audio.queue_free()

func play_weapon(weapon: Dictionary, pos := Vector2.INF) -> bool:
	return play(str(weapon.get("report", "")), pos)

## 语音 id：读取运行时单位/建筑数据的 voice 块。
## 事实源：rules.ini 的 VoiceSelect/VoiceMove/VoiceAttack/VoiceFeedback/VoiceSpecialAttack/
## DieSound/CrushSound/DeploySound/UndeploySound → data/ra2_allied.json 的 <entry>.voice。
## kind: select / move / attack / feedback / special / die / crush / deploy / undeploy
func voice_id(data: Dictionary, kind: String) -> String:
	var override: String = str(GameData.ra2_voice_overrides.get(str(data.get("id", "")), {}).get(kind, ""))
	if not override.is_empty() and not GameData.ra2_sound_files(override).is_empty():
		return override
	# Older packs have no dedicated resource command acknowledgements.
	if kind in ["harvest", "enter"]:
		var original: Dictionary = data.get("voice", {})
		if not str(original.get(kind, "")).is_empty():
			return str(original[kind])
		return voice_id(data, "move")
	var v = data.get("voice", null)
	if v == null or not (v is Dictionary):
		return ""
	return str(v.get(kind, ""))

func has_voice(data: Dictionary, kind: String) -> bool:
	return voice_id(data, kind) != ""

## 播放单位语音。throttle_ms > 0 时同一 sound id 在该毫秒窗口内只播一次
## （近似 RA2 的 Limit=，避免框选 / 群体阵亡时叠成机关枪）。
func play_voice(data: Dictionary, kind: String, pos := Vector2.INF, throttle_ms: int = 120) -> bool:
	# Command acknowledgements answer the player, regardless of camera distance.
	# Death, deploy and other world events retain their positional audio.
	var voice_pos: Vector2 = Vector2.INF if kind in COMMAND_VOICE_KINDS else pos
	var id := voice_id(data, kind)
	if id == "":
		a_voice_misses += 1
		return false
	var now := Time.get_ticks_msec()
	if throttle_ms > 0 and now - int(_voice_lock.get(id, -9999999)) < throttle_ms:
		return false
	if data.get("id", "") == "YURIKO":
		if not _request_yuriko_voice(id, voice_pos, kind): return false
	else:
		if not play(id, voice_pos, true): return false
		a_voice_plays += 1
	if throttle_ms > 0: _voice_lock[id] = now
	return true

## 播放建造/部署等 startSound（如 art/anim 数据里的 startSound）。
func play_variant(ids: Array, pos := Vector2.INF) -> bool:
	for id in ids:
		if play(str(id), pos):
			return true
	return false

func _take_player() -> AudioStreamPlayer2D:
	# 优先找一个没在播的；否则轮转
	for i in _pool.size():
		var idx := (_cursor + i) % _pool.size()
		if not _pool[idx].playing:
			_cursor = (idx + 1) % _pool.size()
			return _pool[idx]
	var p := _pool[_cursor % _pool.size()]
	_cursor = (_cursor + 1) % _pool.size()
	return p

func _take_global_player() -> AudioStreamPlayer:
	for i in _global_pool.size():
		var idx := (_global_cursor + i) % _global_pool.size()
		if not _global_pool[idx].playing:
			_global_cursor = (idx + 1) % _global_pool.size()
			return _global_pool[idx]
	var p := _global_pool[_global_cursor % _global_pool.size()]
	_global_cursor = (_global_cursor + 1) % _global_pool.size()
	return p

func _linear_to_db(v: float) -> float:
	return linear_to_db(v) if v > 0.0 else -80.0

func _num(v) -> float:
	if v == null:
		return 0.0
	if v is float or v is int:
		return float(v)
	return 0.0

## 诊断摘要（供探针使用）
func stats() -> Dictionary:
	return {"plays": a_plays, "misses": a_misses, "voice_plays": a_voice_plays,
		"voice_misses": a_voice_misses, "eva_plays": a_eva_plays, "eva_misses": a_eva_misses,
		"eva_queued": a_eva_queued, "cached": _cache.size(), "pool": _pool.size()}

## Only active tagged voices duck music; reusing a pool slot for a weapon clears it.
func unit_voice_active() -> bool:
	if not _yuriko_layers.is_empty(): return true
	for players in [_global_pool, _pool]:
		for player in players:
			if player.playing and player.get_meta("unit_voice", false):
				return true
	return false
