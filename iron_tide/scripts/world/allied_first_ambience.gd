extends RefCounted
const SOUNDS = preload("res://data/ra2/allied_first_ambience.json")
var voices := {}

func add(s: Dictionary,sound: String,wp: int) -> bool:
	if not SOUNDS.data.has(sound): return false
	var key := sound+"/"+str(wp)
	if not s.get_or_add("field_sounds",{}).has(key):
		s.field_sounds[key]={"sound":sound,"wp":wp,"wait":0.0}
	return true

func stop_at(s: Dictionary,wp: int) -> void:
	var sources: Dictionary=s.get_or_add("field_sounds",{})
	for key in sources.keys():
		if int(sources[key].wp)!=wp: continue
		sources.erase(key)
		if voices.has(key):
			voices[key].stop()
			voices[key].queue_free()
			voices.erase(key)

func tick(world,s: Dictionary,delta: float) -> void:
	var playing := {}
	for key in voices.keys():
		var voice=voices[key]
		if not voice.playing:
			voice.queue_free()
			voices.erase(key)
		else:
			var name: String=s.field_sounds[key].sound
			playing[name]=int(playing.get(name,0))+1
	for key in s.get("field_sounds",{}):
		var src: Dictionary=s.field_sounds[key]
		if voices.has(key): continue
		src.wait=maxf(0.0,float(src.wait)-delta)
		if src.wait>0: continue
		var rule: Dictionary=SOUNDS.data[src.sound]
		var pos: Vector2=world.AlliedFirst.wp(src.wp)
		var distance: float=rule.range*world.AlliedFirst.Places.CELL
		if world.camera.global_position.distance_squared_to(pos)>distance*distance or int(playing.get(src.sound,0))>=int(rule.limit): continue
		var player:=AudioStreamPlayer2D.new()
		player.stream=load("res://assets/ra2/sfx/"+str(rule.files.pick_random())+".wav")
		player.max_distance=distance
		player.pitch_scale=1.0+randf_range(rule.pitch.front(),rule.pitch.back())/100.0
		player.volume_db=linear_to_db(maxf(0.0001,rule.volume*Ra2Sfx._master_linear))
		world.add_child(player)
		player.global_position=pos
		player.play()
		voices[key]=player
		playing[src.sound]=int(playing.get(src.sound,0))+1
		src.wait=randf_range(rule.delay.front(),rule.delay.back())/1000.0
