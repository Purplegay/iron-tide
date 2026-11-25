extends "res://tests/ra3_riot_regression.gd"
const Aim=preload("res://scripts/units/ra3_gunship_aim.gd")

func exercise_mode(mode: String) -> void:
	if mode==MatchRules.RA2:return
	setup_logistics_scene(mode,"美国")
	for node in battle.units+battle.buildings:node.free()
	battle.units.clear();battle.buildings.clear()
	if battle.fog!=null:battle.fog.free();battle.fog=null
	GM.god_mode=false;GM.one_shot_kill=false
	var source=actor("R3FUTURE","ally",Vector2(1200,1200))
	var shot=beam(source,Vector2(1500,1200))
	# Independent goldens: native SweepDistance 40/2 * world scale 1.5.
	for row in [[0.0,Vector2(1470,1230),Vector2(1470,1170)],[0.25,Vector2(1485,1215),Vector2(1485,1185)],[0.5,Vector2(1500,1200),Vector2(1500,1200)],[1.0,Vector2(1530,1170),Vector2(1530,1230)]]:
		var ends=Riot.endpoints(shot,row[0])
		check(ends[0].is_equal_approx(row[1]) and ends[1].is_equal_approx(row[2]),"native diagonal crisscross endpoints at "+str(row[0]),str(ends))
	shot.target_point=Vector2(1200,1500)
	check(Riot.endpoints(shot,0.0)==[Vector2(1170,1470),Vector2(1230,1470)],"sweep rotates with facing instead of map axes")
	clear_shots()
	var target=actor("R3FUTURE","enemy",Vector2(1470,1170))
	target.radius=0;target.hp=100000;target.max_hp=100000
	shot=beam(source,Vector2(1500,1200))
	Ra3Expansion.tick_shot(shot,0.001)
	var initial: float=100000-target.hp
	check(initial>0,"real line hits native first endpoint")
	if DisplayServer.get_name()!="headless":
		var fx=get_tree().get_nodes_in_group("ra3_future_beams")[-1]
		fx.set_process(false);fx._process(0.8)
		check(is_equal_approx(fx.age,0.001),"beam render cannot outrun damage clock")
	source._stun_timer=2.0
	Ra3Expansion.tick_shot(shot,0.8)
	check(is_equal_approx(float(shot.splinters.age),0.001) and is_equal_approx(100000-target.hp,initial),"disabled caster suspends beam clock and damage together")
	if DisplayServer.get_name()!="headless":
		var fx=get_tree().get_nodes_in_group("ra3_future_beams")[-1];fx._process(0.8)
		check(fx.beams.all(func(b):return not b.visible),"disabled caster hides both beams")
	source._stun_timer=0
	Ra3Expansion.tick_shot(shot,0.05)
	check(not shot.splinters.riot_suspended and shot.splinters.riot_next==1,"resume keeps cursor without catching up disabled time")
	# Real death path, then drain the one already fired delayed endpoint.
	source.receive_hit(100000,"cannon",{},target,"RA3_EXPANSION")
	Ra3Expansion.tick_shot(shot,0.2)
	check(shot.splinters.riot_stopped and shot.splinters.riot_next==1 and shot.splinters.riot_tip==1,"caster death stops future pulses and drains only fired tips")
	check(is_equal_approx(100000-target.hp,initial*3.0),"one 25 line plus one delayed 50 endpoint after death",100000-target.hp)
	check(shot.is_queued_for_deletion(),"interrupted payload ends after delayed hits drain")
	clear_shots()
	var plane=actor("R3HARBINGER","ally",Vector2(1800,1800))
	plane.logistics.air_lift=1.0;plane.hull_angle=0
	target.position=Vector2(2100,1800);plane.attack_target=target
	Aim.tick(plane,1.0)
	check(not plane._weapon_aligned(target),"side cannon cannot shoot outside native deflection even if generic turret points at target")
	target.position=Vector2(1800,1500)
	Aim.tick(plane,0.01)
	check(not plane._weapon_aligned(target),"side cannon waits for actual 180 degree per second turn")
	Aim.tick(plane,1.0)
	check(plane._weapon_aligned(target),"side cannon fires when physical turret reaches allowed target")
	var before: float=plane.sight
	check(plane.command_voice_kind("attack")=="attack","cannon uses ordinary attack voice")
	Ra3Expansion.use(plane,Vector2.ZERO)
	check(is_equal_approx(plane.sight,570.0) and is_equal_approx(plane.attack_range,450.0),"gun mode consumes official VISION 76 percent")
	check(plane.command_voice_kind("attack")=="attack_special" and Ra2Sfx.has_voice(plane.data,"attack_special"),"gun mode routes extracted original special attack voice")
	check(plane.command_voice_kind("move")=="move","voice override does not change other orders")
	var fog=preload("res://scripts/world/fog_of_war.gd").new()
	check(is_equal_approx(fog.vision_radius(plane),570.0),"fog sees changed sight while retaining range floor")
	plane._grant_veteran(3,false)
	check(is_equal_approx(plane.sight,712.5) and is_equal_approx(plane.attack_range,562.5),"heroic 125 percent stacks with gun mode vision")
	check(fog.vision_radius(plane)>=plane.attack_range,"heroic attack remains visible under confirmed fog policy")
	fog.free()
	var codec=preload("res://scripts/save/battle_snapshot.gd").new()
	var snapshot=codec.capture(battle);codec.restore(battle,snapshot)
	plane=battle.units.filter(func(u):return u.unit_id=="R3HARBINGER")[0]
	check(is_equal_approx(plane.sight,712.5) and plane.command_voice_kind("attack")=="attack_special","snapshot restores mode/rank vision and voice")
	Ra3Expansion.use(plane,Vector2.ZERO)
	check(is_equal_approx(plane.sight,before*1.25) and plane.command_voice_kind("attack")=="attack","switch back restores cannon vision without accumulated scaling")
	check(plane.special.has("ra3_aim_side"),"snapshot preserves simulation turret pose")
	var speaker=actor("R3FUTURE","ally",Vector2(1600,1600))
	var enemy=actor("R3FUTURE","enemy",Vector2(1700,1600))
	check(speaker.command_voice_kind("select")=="select","future idle voice state")
	speaker.attack_target=enemy
	check(speaker.command_voice_kind("select")=="select_battle","future fighting selection voice")
	speaker.receive_hit(1,"cannon",{},enemy,"RA3_EXPANSION")
	check(speaker.command_voice_kind("select")=="select_under_fire","real hit selects under-fire voice")
	Ra3Expansion.tick(speaker,3.1)
	check(speaker.command_voice_kind("select")=="select_battle","under-fire override expires")
	speaker.special.ra3_riot_point=enemy.position
	check(speaker.command_voice_kind("attack")=="attack_beam" and Ra2Sfx.has_voice(speaker.data,"attack_beam"),"future beam attack routes original acknowledgement")
	var spec: Dictionary=GameData.ra2_sound_spec(Ra2Sfx.voice_id(speaker.data,"select"))
	check(spec.get("layers",[]).size()==1,"official selection Multisound keeps mechanical layer separate from voice variants")
	var plays:=Ra2Sfx.a_plays
	check(Ra2Sfx.play_voice(speaker.data,"select",Vector2.INF,0) and Ra2Sfx.a_plays==plays+2,"original selection voice and mechanical layer both play")
	check("attack_beam" in Ra2Sfx.COMMAND_VOICE_KINDS and "attack_special" in Ra2Sfx.COMMAND_VOICE_KINDS,"new command acknowledgements remain audible away from camera")
	screen.free();await get_tree().process_frame
