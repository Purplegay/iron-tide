extends AudioStreamPlayer2D

var files: Array
var report := ""
var remaining := 0.0
var releasing := false

static func shot(actor, gun: Dictionary, reload: float) -> void:
	var player = actor.get_node_or_null("GatlingReport")
	if player == null:
		player = new()
		player.name = "GatlingReport"
		actor.add_child(player)
	player.sustain(str(gun.report), reload)

const TRACKS := [preload("res://assets/ra2/sfx/hollywood/gatling_sustain_1.wav"), preload("res://assets/ra2/sfx/hollywood/gatling_sustain_2.wav"), preload("res://assets/ra2/sfx/hollywood/gatling_sustain_3.wav")]

func sustain(id: String, reload: float) -> void:
	remaining = maxf(reload,0.1) + 0.15
	if id == report and not releasing: return
	releasing = false
	report = id
	files = GameData.ra2_sound_files(id)
	if files.size() < 3:
		queue_free()
		return
	if not finished.is_connected(_advance): finished.connect(_advance)
	volume_db = linear_to_db(maxf(0.0001,GameData.ra2_sound_volume(id)*Ra2Sfx._master_linear))
	max_distance = GameData.ra2_sound_range_cells(id)*Ra2Sfx.PX_PER_CELL
	var next_track: AudioStreamWAV = TRACKS[id.right(1).to_int()-1]
	if playing and stream != next_track:
		# Start the new layer while the current positional player is still mixing.
		var next_voice = new()
		var actor = get_parent()
		name = "GatlingFade"
		next_voice.name = "GatlingReport"
		next_voice.bus = bus
		actor.add_child(next_voice)
		next_voice.sustain(id,reload)
		set_process(false)
		var fade := create_tween()
		fade.tween_interval(0.10)
		fade.tween_property(self,"volume_db",-60.0,0.10)
		fade.tween_callback(queue_free)
		return
	stream = next_track
	play()

func _process(delta: float) -> void:
	if releasing: return
	remaining -= delta
	var actor = get_parent()
	if remaining <= 0 or actor.hp <= 0 or not is_instance_valid(actor.attack_target) or actor.attack_target.hp <= 0 or (actor is Building and not actor.is_operational()):
		releasing = true
		_clip(files.size()-1)

func _advance() -> void:
	if releasing: queue_free()


func _clip(index: int) -> void:
	stream = Ra2Sfx._stream(files[index])
	if stream == null: queue_free()
	else: play()
