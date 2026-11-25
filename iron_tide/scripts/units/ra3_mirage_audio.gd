class_name Ra3MirageAudio
extends Node2D
## Battle-owned native samples; SDK event values are exported, not RA2 sound.ini.
const ROOT := "res://assets/ra3/mirage/uprising/"
static var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT+"field.json"))
static var streams: Dictionary = {}
var actor: Unit
var loop_player: AudioStreamPlayer2D
var loop_gain := 0.0
var events_started: Array[String] = []

static func ensure(unit: Unit) -> Ra3MirageAudio:
	var audio := unit.get_node_or_null("Ra3MirageAudio") as Ra3MirageAudio
	if audio == null:
		audio=Ra3MirageAudio.new(); audio.actor=unit; audio.name="Ra3MirageAudio"
		audio.process_mode=Node.PROCESS_MODE_PAUSABLE
		unit.add_child(audio)
	return audio

func audible() -> bool:
	if not is_instance_valid(actor) or actor._dead or actor.embarked_in != null: return false
	var world = actor._battle_world()
	return world != null and world.actor_visible_to("ally",actor)

func play_event(event: String, looping := false) -> AudioStreamPlayer2D:
	if not audible(): return null
	var spec: Dictionary=source.audio[event]
	var group := "ra3_native_"+event
	if get_tree().get_nodes_in_group(group).size()>=int(spec.limit): return null
	var file: String=spec.sounds.pick_random()
	if not streams.has(file): streams[file]=load(ROOT+"audio/"+file)
	var stream: AudioStreamWAV=streams[file]
	if looping:
		stream=stream.duplicate()
		stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin=0; stream.loop_end=stream.data.size()/(2*(2 if stream.stereo else 1))
	var player := AudioStreamPlayer2D.new()
	player.stream=stream; player.max_distance=float(spec.max_range)*Ra3Mirage.WORLD_SCALE
	player.panning_strength=0.6
	player.pitch_scale=1.0+randf_range(float(spec.PitchShift[0]),float(spec.PitchShift[1]))/100.0
	var gain := maxf(0.0001,(float(spec.volume)+randf_range(float(spec.volume_shift),0.0))/100.0)
	player.set_meta("native_gain",gain)
	player.volume_db=linear_to_db(gain*maxf(0.0001,Ra2Sfx._master_linear))
	add_child(player); player.add_to_group(group)
	if not looping: player.finished.connect(player.queue_free)
	var delay := randf_range(float(spec.Delay[0]),float(spec.Delay[1]))/1000.0
	if delay>0:
		var timer := Timer.new(); timer.one_shot=true; player.add_child(timer)
		timer.timeout.connect(func():
			if audible(): player.play(); events_started.append(event)
			else: player.queue_free()
			timer.queue_free())
		timer.start(delay)
	else:
		player.play(); events_started.append(event)
	# Diagnostics are bounded even during a long match.
	if events_started.size()>16: events_started.pop_front()
	return player

func fire() -> void:
	play_event("ALL_Mirage_WeaponFire1")
	play_event("ALL_Mirage_WeaponFire2")

func toggled() -> void:
	var active := Ra3Mirage.field_active(actor)
	var event := "ALL_MirageField_Start" if active else "ALL_MirageField_Stop"
	# SDK PLAYER and ALLIES/ENEMIES are observer partitions, not doubled owner audio.
	if actor.side=="ally": event+="Player"
	play_event(event)

func advance(delta: float) -> void:
	var active := Ra3Mirage.field_active(actor) and audible()
	if not audible():
		for child in get_children():
			if child is AudioStreamPlayer2D: child.queue_free()
		loop_player=null; loop_gain=0.0
		return
	if active and not is_instance_valid(loop_player):
		loop_player=play_event("ALL_MirageField_StartAndEndLoop",true)
		loop_gain=1.0
	elif active:
		loop_gain=1.0
	elif not active:
		loop_gain=maxf(0.0,loop_gain-delta/float(source.adapter.loop_stop_fade_seconds))
	if is_instance_valid(loop_player):
		if loop_gain<=0.0: loop_player.queue_free(); loop_player=null
		else: loop_player.volume_db=linear_to_db(maxf(0.0001,float(loop_player.get_meta("native_gain"))*loop_gain*Ra2Sfx._master_linear))
