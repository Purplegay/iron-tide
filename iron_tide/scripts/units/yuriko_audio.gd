extends RefCounted

const LOOPS := {"Primary":"JAP_YurikoOmega_PsyonicLoop","Shield":"JAP_Yuriko_PsychicShieldLoop","Slam":"JAP_Yuriko_PsychicSlamLoop"}

static func phase(player:AudioStreamPlayer2D, event:String, looping:bool) -> bool:
	var files:=GameData.ra2_sound_files(event)
	if files.is_empty():return false
	var stream:=Ra2Sfx._stream(files.pick_random())
	if stream==null:return false
	if looping:
		stream=stream.duplicate()
		stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin=0
		stream.loop_end=roundi(stream.get_length()*stream.mix_rate)
	player.stream=stream
	player.volume_db=linear_to_db(maxf(.0001,GameData.ra2_sound_volume(event)*Ra2Sfx._master_linear))
	player.max_distance=maxf(.5,GameData.ra2_sound_range_cells(event))*Ra2Sfx.PX_PER_CELL
	player.play()
	return true

static func start(u,kind:String,attack:=true) -> void:
	var path:=NodePath("YurikoAudio"+kind)
	if u.has_node(path):return
	var player:=AudioStreamPlayer2D.new()
	player.name=String(path)
	u.add_child(player)
	Events.battle_ended.connect(player.stop.unbind(1),CONNECT_ONE_SHOT)
	var id:String=LOOPS[kind]
	if attack and phase(player,id+"_attack",false):
		player.finished.connect(phase.bind(player,id,true),CONNECT_ONE_SHOT)
	else:phase(player,id,true)

static func stop(u,kind:String,decay:=true) -> void:
	var player=u.get_node_or_null(NodePath("YurikoAudio"+kind))
	if player==null:return
	player.stop()
	u.remove_child(player)
	player.queue_free()
	if decay:Ra2Sfx.play(LOOPS[kind]+"_decay",u.global_position)

static func sync(u) -> void:
	var active:bool=not u._dead and u.embarked_in==null and not u._battle_world().ended
	var states:Dictionary={"Primary":u.special.has("psi_fire_anim"),"Shield":u.special.has("psi_shield"),"Slam":u.special.has("psi_held") and u.special.psi_held.any(func(t):return AlliedAbilities.alive(t) and t.special.get("psi_holder")==u)}
	for kind:String in LOOPS:
		if active and states[kind]:start(u,kind,false)
		else:stop(u,kind,active)

static func hurt(u,amount:float,kind:String) -> void:
	if amount<=0:return
	if u.hp<=0:
		if kind in ["fire","flame"]:u.special.psi_death_voice="die_fire"
		elif kind in ["electric","tesla"]:u.special.psi_death_voice="die_shock"
		return
	u.special.psi_hurt_voice_left=2.0
	var fraction:float=u.hp/u.max_hp
	var reaction:="HurtLarge" if fraction<=.33 else "HurtInitial" if fraction>.75 and fraction<=.9999 else ""
	if reaction.is_empty():return
	var chapter:=2 if u.yuriko_model.outfit==1 else 1
	Ra2Sfx.play_voice(u.data,"hurt_%d_%s"%[chapter,reaction],u.global_position,5000)
