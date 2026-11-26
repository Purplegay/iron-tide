extends Node
const Psi=preload("res://scripts/units/yuriko.gd")
const Book=preload("res://scripts/units/yuriko_school.gd")
const Stories=preload("res://scripts/expedition/hero_field_stories.gd")
var failed:=0
var checks:=0

func check(ok:bool,msg:String) -> void:
	checks+=1
	if not ok: failed+=1
	print("PASS " if ok else "FAIL ",msg)

func _ready() -> void:
	if not ProjectSettings.get_setting("application/config/use_custom_user_dir",false):
		get_tree().quit(2)
		return
	call_deferred("run")

func press_key(hud,code:int) -> void:
	var event:=InputEventKey.new()
	event.keycode=code
	event.pressed=true
	hud._input(event)

func click_ground(command,point:Vector2,button:=MOUSE_BUTTON_LEFT) -> void:
	var event:=InputEventMouseButton.new()
	event.position=command.world.get_canvas_transform()*point
	event.button_index=button
	event.pressed=true
	command.get_viewport().push_input(event,true)
	event.pressed=false
	command.get_viewport().push_input(event,true)

func check_cooldown(strip,key:String,left:float,total:float) -> void:
	strip.refresh()
	var slot=strip.slots[key]
	var clock=slot.get_node("CooldownClock")
	var label:Label=slot.get_node("CooldownSeconds")
	var ok:bool=clock.visible==(left>0.0) and label.visible==clock.visible
	if left>0.0:
		ok=ok and slot.disabled and label.text==str(ceili(BattleClock.real_seconds(left))) and is_equal_approx(clock.progress,1.0-left/total)
	check(ok,"cooldown number and clock match %s at %.2f"%[key,left])

func exercise_guard_combat(w, hero, guard) -> void:
	var previous_hero:Vector2=hero.position
	var previous_guard:Vector2=guard.position
	var slot:=Vector2.INF
	for x in range(300,int(w.map_size)-400,200):
		for y in range(300,int(w.map_size)-300,200):
			var point:=Vector2(x,y)
			if w.path_service.is_blocked(point,false,true) or w.path_service.is_blocked(point+Vector2.RIGHT*40,false,true):continue
			var clear:=true
			for foe in get_tree().get_nodes_in_group(BattleRequest.foes_group(guard.side)):
				if Psi.Rules.enemy(guard,foe) and point.distance_to(Psi.Rules.point(guard,foe))<guard.sight+120:
					clear=false
					break
			if clear:
				slot=point
				break
		if slot.is_finite():break
	check(slot.is_finite(),"guard test has an open position without competing targets")
	if not slot.is_finite():return
	hero.position=slot-Vector2(guard.special.psi_guard_offset).rotated(hero.hull_angle)
	guard.position=slot-Vector2(36,0)
	Psi.tick(hero,0.5)
	guard.position=slot
	var enemy=w.spawn_unit("E2","enemy",slot+Vector2.RIGHT*(guard.attack_range+20.0))
	if w.fog!=null:w.fog.reveal_superweapon_impact(enemy.position,180)
	check(guard_damages(w,hero,guard,enemy),"single W guard closes on a nearby unprovoked enemy and deals weapon damage")
	enemy.position=slot+Vector2.RIGHT*(guard.sight+600.0)
	var building=w._place_building("NAPOWR","enemy",slot+Vector2.DOWN*90,true)
	if w.fog!=null:w.fog.reveal_superweapon_impact(building.position,180)
	check(guard_damages(w,hero,guard,building),"guard independently switches to a nearby hostile building and damages it")
	hero.position+=Vector2.DOWN*350.0
	Psi.tick(hero,0.5)
	var new_slot:=slot+Vector2.DOWN*350.0
	check(guard.has_move_order and not guard.attack_ordered and not guard.attack_move and guard.move_target.distance_to(new_slot)<guard.position.distance_to(new_slot)*0.5,"guard breaks combat and returns toward Yuriko's new formation position")
	hero.position=previous_hero
	guard.position=previous_guard
	w.units.erase(enemy)
	w.buildings.erase(building)
	enemy.free()
	building.free()

func guard_damages(w,hero,guard,target) -> bool:
	var initial_hp:float=target.hp
	for frame in 480:
		Psi.tick(hero,1.0/60.0)
		guard._physics_process(1.0/60.0)
		for shot in w.projectiles_root.get_children():
			if shot is Projectile and not shot.is_queued_for_deletion() and shot.shooter()==guard:
				shot._physics_process(1.0/60.0)
		if target.hp<initial_hp:return true
	return false

func run() -> void:
	MetaProgress.yuriko_school={}
	var read:Dictionary={}
	for ep in Book.episodes:read[ep.id]=0
	MetaProgress.yuriko_school.read=read
	check(not Book.learn("Shield_Rank2"),"study checks prerequisites")
	for talent in Book.talents:check(Book.learn(talent.id),"outside battle purchase "+talent.id)
	Music.enabled=true
	var camp=load("res://scenes/expedition.tscn").instantiate()
	add_child(camp)
	check(Music.stage=="camp" and Music.current_title()=="Grinder 2" and Music.player.playing,"camp opens with the full Grinder 2")
	camp.free()
	var maps:=Music.tracks.filter(func(t):return t.stage=="explore")
	check(maps.size()==10,"ten exploration tracks")
	for t in maps:
		var mp3=load(t.file)
		check(mp3 is AudioStreamMP3 and mp3.get_length()>10,t.title)
	BattleRequest.configure_skirmish(MatchRules.EXTENDED,{"country":"美国","map_size":2400,"starting_funds":8000,"fog_of_war":true})
	var screen=load("res://scenes/battle.tscn").instantiate()
	add_child(screen)
	var w=screen.battle
	check(Music.stage=="explore" and Music.player.playing,"battle map explores before contact")
	var exploration:=Music.exploration_id
	Music.play_cue("yuriko")
	Music._on_finished()
	check(Music.exploring and Music.stage=="explore" and Music.exploration_id==exploration,"theme returns to same map track before combat")
	Music.skip_or_replay()
	check(Music.exploration_id!=exploration and w.allied_state.battle_music_director.map_track==Music.exploration_id,"map skip changes and persists exploration track")
	var built=w._place_building("GAPILE","ally",Vector2(560,620),true)
	var btn=screen.hud.find_child("YurikoCommand",true,false)
	btn.pressed.emit()
	var command=btn.pressed.get_connections()[0].callable.get_object()
	check(command.popup.visible and command.popup.find_child("Shield_Rank1",true,false)==null,"battle menu contains no purchase controls")
	command.popup.find_child("Summon",true,false).pressed.emit()
	var u=Psi.hero(w)
	check(u!=null and Music.stage=="yuriko" and not Psi.summon(w),"barracks deploys unique Yuriko and plays theme")
	check(u.special.psi_support_left==180 and Psi.deployment_clock(u.special.psi_support_left)=="3:00","summoned support starts at three minutes")
	if u==null:
		get_tree().quit(1)
		return
	var enemy=w.spawn_unit("E2","enemy",u.position+Vector2(100,0))
	var sounds:Dictionary=GameData.raw_docs["ra3_yuriko_sounds.json"].sounds
	var usable:=true
	for entry in sounds.entries.values():
		var stream:=load(entry.file) as AudioStreamWAV
		usable=usable and stream!=null and stream.get_length()>0 and stream.mix_rate==int(entry.sampleRate)
	check(usable and sounds.entries.size()==193,"all 193 retail PCM clips load at native sample rates")
	check(Ra2Sfx.voice_id(u.data,"created")=="JAP_Yuriko_VoiceCreate" and GameData.ra2_sound_spec(Ra2Sfx.voice_id(u.data,"select")).layers.size()==1,"retail creation voice and simultaneous spoken/sonic selection")
	check(GameData.ra2_sound_files(Ra2Sfx.voice_id(u.data,"burst_yell")).size()==3,"Q resolves the three real psionic yells")
	var model = u.yuriko_model
	check(model.rig.get_bone_count()==52 and model.states.size()==19,"native skeleton and SDK conditions loaded by deployed unit")
	var clips:Dictionary={}
	for row in model.states.values():
		if model.animator.has_animation(row.clip): clips[row.clip]=true
	check(clips.size()==16,"all sixteen native animations resolve")
	model.sync_actor(u,.1)
	check(model.action=="USER_7","production plays mission entrance animation")
	var initial_hp:float=enemy.hp
	u._fire_shot(enemy)
	check(enemy.hp<initial_hp and is_equal_approx(u._weapon_for_target(enemy).range,112.5) and enemy._stun_timer>0,"psionic crush strips health and briefly holds a ground unit")
	Psi.crush_pose(enemy,.08)
	check(enemy.special.psi_crush.height>0,"primary attack visibly raises its ground target")
	model.sync_actor(u,.05)
	check(model.action=="FIRING_A REACT_1","real shot selects infantry attack sequence")
	w.reveal_attack(u,enemy)
	check(not Music.exploring and Music.stage=="yuriko","first exchange changes underlying score without cutting theme")
	Music._on_finished()
	check(Music.stage=="battle" and Music.tracks[Music.current_index].id==w.allied_state.battle_music_director.combat_id,"theme returns to the battle's selected faction recording")
	var hostile=w._place_building("NAMISL","enemy",Vector2(1850,1800),true)
	var specials=preload("res://scripts/units/soviet_specials.gd")
	var silo=w._place_building("NAMISL","ally",Vector2(350,1100),true)
	u._fire_shot(hostile)
	model.sync_actor(u,.1)
	check(model.action=="FIRING_A REACT_3","real shot selects structure attack sequence")
	var flyer=w.spawn_unit("ZEP","enemy",Vector2(1600,1600))
	flyer.logistics.air_lift=1.0
	u._fire_shot(flyer)
	model.sync_actor(u,.05)
	check(flyer.special.has("psi_air_pull") and model.action=="FIRING_A REACT_1" and u._weapon_for_target(flyer).range==225,"air target selects native airborne weapon and attack pose")
	Psi.carried_tick(flyer,3.0)
	check(flyer._dead,"psionic pull brings aircraft down")
	w.power_low=false
	w.enemy_power.low=false
	for site in [silo,hostile]:
		site._buildup_play=-1.
		site._sw_charge=site.sw_recharge()
	check(not silo.fire_superweapon(Vector2(-1,-1)) and Music.stage=="battle","rejected target leaves battle score alone")
	check(silo.fire_superweapon(silo.position) and Music.stage=="superweapon_used" and Music.current_title()=="American Cowboys","Allied player launches captured Soviet technology and hears American Cowboys")
	Music._on_finished()
	check(not silo.fire_superweapon(silo.position) and Music.stage=="battle","uncharged launcher stays silent")
	check(hostile.fire_superweapon(hostile.position) and Music.current_title()=="Allied - Up Yours","enemy launch away from player assets triggers Up Yours before impact")
	Music._on_finished()
	var launches:Array=w.allied_state.soviet_nukes
	launches.back().left=0.01
	specials.tick_world(w,.02)
	check(Music.stage=="battle","delayed detonation does not replay launch music")
	var profile:=Psi.training(w)
	check(profile.points==0 and not w.allied_state.has("yuriko_file") and not w.allied_state.has("yuriko_file_retry"),"summoning does not place a secret file")
	w.allied_state.yuriko_file=u.position
	Psi.tick(u,.1)
	check(profile.points==0,"legacy random file cannot grant a point")
	w.allied_state.erase("yuriko_file")
	check(profile.points==0 and profile.learned.size()==15 and Book.balance()==0,"battle consumes outside-battle training")
	var before:float=u.hp
	press_key(screen.hud,KEY_E)
	check(u.has_node("YurikoAudioShield") and u.get_node("YurikoAudioShield").playing,"shield owns its native attack/loop player")
	check(u.special.has("psi_shield"),"E starts the level three shield")
	check_cooldown(command.strip,"Shield",15,15)
	model.sync_actor(u,.01)
	check(model.shield.visible and model.action=="USER_8","deployed hero shows 3D shield and skill animation")
	u.receive_hit(40,"bullet",{},hostile)
	check(is_equal_approx(before,u.hp) and u.special.psi_shield==9,"outside shot blocked for native rank-three duration")
	u.receive_hit(12,"radiation",{},hostile)
	check(u.command_voice_kind("select")=="select_under_fire","actual damage switches selected response")
	check(u.hp<before,"radiation passes through shield")
	u.position=Vector2(800,800)
	if w.fog!=null:w.fog.rebuild()
	var soldier=w.spawn_unit("E2","enemy",u.position+Vector2(30,0))
	press_key(screen.hud,KEY_W)
	check(command.pending=="Lure","W arms mind control")
	command.pending=""
	check(Psi.order_power(u,"Lure",soldier.position) and soldier.side=="ally","lure takes control of infantry")
	check_cooldown(command.strip,"Lure",30,30)
	w.select_unit(soldier,true)
	check(not w.selected_units.has(soldier),"mind-controlled guards stay outside player selection")
	Psi.tick(u,.02)
	check(soldier.has_move_order and soldier.special.has("psi_guard_offset"),"guard follows its formation offset")
	exercise_guard_combat(w,u,soldier)
	var far:Vector2=u.position+Vector2(510,0)
	if w.fog!=null:w.fog.reveal_superweapon_impact(far,100)
	press_key(screen.hud,KEY_R)
	click_ground(command,far)
	check(command.pending==command.WAIT_FOR_LIFT and u.special.has("psi_order") and not u.special.has("psi_cd_Slam"),"out-of-range R waits for lift without charging cooldown")
	click_ground(command,far,MOUSE_BUTTON_RIGHT)
	check(command.pending.is_empty() and not u.special.has("psi_order") and not u.special.has("psi_cd_Slam"),"right click cancels approach without spending the power")
	var tank=w.spawn_unit("HTNK","enemy",u.position+Vector2(85,0))
	Psi.tick(u,2.05)
	u._fire_shot(tank)
	model.sync_actor(u,.05)
	check(u.has_node("YurikoAudioPrimary") and u.get_node("YurikoAudioPrimary").playing,"normal attack starts a native psionic loop")
	check(model.action=="FIRING_A REACT_2","real shot selects vehicle attack sequence")
	press_key(screen.hud,KEY_R)
	check(command.pending=="Slam","R arms lift")
	var tank_paint:ShaderMaterial=tank.material
	click_ground(command,tank.position)
	check(tank.side=="enemy" and tank_paint!=null and tank.material.shader==tank_paint.shader and tank.material.get_shader_parameter("target_color")==tank_paint.get_shader_parameter("target_color"),"lift keeps enemy tank house color")
	check(tank.special.has("psi_holder") and command.pending=="Throw","first ground click lifts vehicle and switches to the landing cursor")
	check_cooldown(command.strip,"Slam",0,3)
	check(not command.strip.slots["Slam"].disabled,"R remains available for the landing click during lift cooldown")
	model.sync_actor(u,.01)
	check(u.has_node("YurikoAudioSlam"),"holding starts its owned native sound")
	check(model.action=="TRANS_boredToSlam","lifting enters SDK windup")
	model.sync_actor(u,model.duration(model.action))
	check(model.action=="REACT_5","windup advances into the sustained lifted pose")
	var bystander=w.spawn_unit("HTNK","enemy",u.position+Vector2(0,90))
	var splash_hp:float=bystander.hp
	click_ground(command,Vector2(-30,-30))
	check(command.pending=="Throw" and tank.special.has("psi_holder"),"invalid landing point keeps the vehicle and landing cursor")
	click_ground(command,u.position+Vector2(0,90))
	check(command.pending.is_empty() and tank.special.has("psi_flight"),"next ground click throws stored vehicle without a second R")
	check_cooldown(command.strip,"Slam",3,3)
	check(not u.has_node("YurikoAudioSlam"),"throw releases the hold loop")
	bystander.hp=1
	var score:Dictionary=w.allied_state.battle_music_director
	var previous_kills:=int(score.get("yuriko_kills",0))
	Psi.carried_tick(tank,2.0)
	check(tank.material==tank_paint and bystander._dead and int(score.get("yuriko_kills",0))>=previous_kills+2,"throw credits both impact victim and thrown tank to Yuriko")
	check(tank._dead and not tank.special.has("psi_flight") and tank.position.distance_to(u.position+Vector2(0,90))<1,"thrown vehicle lands")
	check(bystander.hp<splash_hp,"thrown vehicle damages nearby ground targets")
	w.production_technology.unlock("auto_w","ally")
	check(not preload("res://scripts/units/auto_w.gd").evaluate(u) and not u.special.has("psi_cd_burst"),"Auto W technology never casts Yuriko's manual powers")
	check(is_instance_valid(command.strip) and command.strip.visible and command.strip.slots.size()==4,"selecting Yuriko displays four native command slots")
	for i in command.strip.KEYS.size():
		var label=command.strip.slots[command.strip.KEYS[i]].get_node("Shortcut")
		check(label.text=="QWER"[i] and label.position.x<=2 and label.position.y<=1,"native slot key at top left "+label.text)
	var outer=w.spawn_unit("E2","enemy",u.position+Vector2(240,0))
	var outer_hp:float=outer.hp
	var emp=w.spawn_unit("HTNK","enemy",u.position+Vector2(110,0))
	press_key(screen.hud,KEY_Q)
	check(emp._stun_timer==4 and outer.special.has("psi_burst_push"),"burst instantly applies EMP and the outer infantry shockwave")
	var before_push:Vector2=outer.position
	Psi.carried_tick(outer,.15)
	check(outer.position!=before_push and outer.hp==outer_hp,"outer shockwave displaces infantry beyond the damage ring")
	check(u.special.has("psi_cd_burst"),"selected unit's manual command strip activates burst from Q")
	check_cooldown(command.strip,"burst",30,30)
	tank=w.spawn_unit("HTNK","enemy",u.position+Vector2(45,0))
	var hp:float=tank.hp
	Psi.tick(u,.41)
	check_cooldown(command.strip,"burst",29.59,30)
	check(tank.hp<hp and not Psi.burst(u),"burst impact and cooldown")
	command.open()
	command._demo()
	var demo=command.popup.get_children().back()
	check(demo.KEYS.slice(0,4)==["burst","Lure","Shield","Slam"] and demo.ability.get_item_text(1).begins_with("W "),"demonstration lists the same Q W E R order as the command bar")
	for i in 7:
		demo.ability.select(i)
		demo.choose(i)
		demo.level.select(demo.level.item_count-1)
		demo.restart(demo.level.selected)
		check(demo.visible and not demo.caption.text.is_empty(),"menu demo plays "+demo.KEYS[i])
	for index in demo.motion.item_count-1:
		demo.motion.select(index+1)
		demo.restart(index+1)
		check(demo.model.action==demo.motion.get_item_metadata(index+1),"play XML action "+demo.model.action)
	demo.hide()
	var hp_before:float=u.hp
	for idx in [1,2]:
		command.outfit.select(idx)
		command.outfit.item_selected.emit(idx)
		model.sync_actor(u,.1)
		command.strip.refresh()
		check(model.outfit==idx and model.rig.get_bone_count()==36 and command.strip.face.texture_normal.resource_path.ends_with(Psi.PORTRAITS[idx]+".png"),"school outfit, native portrait and skeleton "+str(idx+1))
		check(model.hover_fx.visible and model.hover_fx.ground.visible and model.hover_fx.ring.mesh.get_surface_count()==1 and model.hover_fx.ring.material_override.get_shader_parameter("tint").is_equal_approx(Psi.COLORS[idx]),"foot aura and selected skin color "+str(idx+1))
		check(model.states.has("USER_7")==bool(idx==2) and model.states.has("REACT_5")==bool(idx==1),"chapter-specific actions match the retail actor "+str(idx+1))
		check(is_equal_approx(model.shield.position.y,20.0),"school shield uses the elevated retail pivot")
		command._demo()
		var school_demo=command.popup.get_children().back()
		school_demo.motion.select(1)
		school_demo.restart(1)
		check(school_demo.model.outfit==idx and school_demo.model.action=="STATE_bored","school demo uses matching uniform "+str(idx+1))
		school_demo.hide()
	check(u.hp==hp_before and Psi.training(w).learned.size()==15 and u.special.has("psi_cd_burst"),"outfit changes preserve stats, progression and cooldown")
	command.popup.hide()
	u.special.erase("psi_cd_Slam")
	var saved_target=w.spawn_unit("HTNK","enemy",far)
	if w.fog!=null:w.fog.reveal_superweapon_impact(far,180)
	command.strip.slots["Slam"].pressed.emit()
	click_ground(command,far)
	check(command.pending==command.WAIT_FOR_LIFT,"skill bar also starts a single two-stage R")
	u.position=u.special.psi_order.goal
	Psi.tick(u,.05)
	command._process(.05)
	check(command.pending=="Throw" and saved_target.special.has("psi_holder"),"arrival and lift automatically arm landing before saving")
	var stats:Vector3=Vector3(u.max_hp,u._base_speed,u._base_atk)
	Psi.tick_deployment(w,65.25)
	var saved_left:float=u.special.psi_support_left
	command.strip.refresh()
	check(command.strip.support_time.text=="1:55","portrait countdown follows remaining battle time")
	var save:Dictionary=BattleSaves.save_slot(w,"slot1")
	check(save.ok,"save through normal slot")
	screen.free()
	if save.ok:
		check(BattleSaves.prepare_load("slot1").ok,"stage saved slot")
	screen=load("res://scenes/battle.tscn").instantiate()
	add_child(screen)
	w=screen.battle
	check(Psi.hero(w)!=null and Psi.training(w).learned.size()==15 and not Music.exploring,"load restores hero, independent tree and combat mood")
	u=Psi.hero(w)
	check(w.yuriko_support==u and is_equal_approx(u.special.psi_support_left,saved_left),"remaining support time restores without restarting")
	check(Psi.skin(w)==2 and u.yuriko_model.outfit==2,"load restores third selection scheme and school model")
	Psi.Audio.sync(u)
	check(u.has_node("YurikoAudioSlam") and u.get_node("YurikoAudioSlam").stream.loop_mode==AudioStreamWAV.LOOP_FORWARD,"restoring a held object resumes the body loop directly")
	var stored:=Psi.held(u)
	check(stored.size()>0 and stored[0].special.psi_holder==u,"save restores the two-way link to lifted targets")
	check(not u.special.psi_guards.is_empty() and u.special.psi_guards[0].special.has("psi_guard_offset"),"save restores the mind-controlled guard formation")
	check(u!=null and stats.is_equal_approx(Vector3(u.max_hp,u._base_speed,u._base_atk)),"loaded hero retains purchased stat multipliers exactly once")
	get_tree().paused=false
	w.paused=false
	if not u.special.psi_guards.is_empty():
		exercise_guard_combat(w,u,u.special.psi_guards[0])
	var guard=u.special.psi_guards[0]
	w.paused=true
	Psi.tick_deployment(w,300)
	check(u.special.psi_support_left==saved_left,"paused battle freezes deployment")
	w.paused=false
	Psi.tick_deployment(w,saved_left-0.25)
	w._process(0.25)
	check(Psi.hero(w)==null and not Psi.summon(w) and not w.units.has(u),"support expiry withdraws the unit and spends the map summon")
	check(guard.side=="enemy" and not stored[0].special.has("psi_holder"),"withdrawal releases the guard and the held target")
	w.end_battle(true,false,true)
	check(screen.result_overlay.name=="VictoryAnnouncement" and Music.stage=="victory","real win opens victory poster")
	var next=find_button(screen.result_overlay,"查看结算")
	if next: next.pressed.emit()
	check(next!=null and find_button(screen.result_overlay,"重新挑战")!=null,"continue opens existing settlement")
	screen.free()
	Music.set_context("battle","soviet")
	Music.play_cue("enemy_superweapon")
	check(Music.current_title()=="Soviet - Up Yours","Soviet player receives Soviet cue")
	exercise_affinity_stats()
	exercise_expedition()
	var run_state:Dictionary={"country":"美国","stage":2,"heroes":[]}
	var tasks:Array=[{"kind":"intel","done":true}]
	Stories.assign(run_state,tasks)
	check(tasks[0].get("hero_lead")=="YURIKO","route intel contains Yuriko clue")
	var report:Dictionary={}
	Stories.settle(run_state,tasks,report)
	check(run_state.get("yuriko_recruited",false) and report.field_heroes==["YURIKO"],"completed intelligence and victory recruit Yuriko")
	print("YURIKO SCORE checks=",checks," failed=",failed)
	get_tree().quit(0 if failed==0 else 1)

func exercise_affinity_stats() -> void:
	var prior:=MetaProgress.yuriko_school.duplicate(true)
	var choices:=["health","health","attack","duration","duration","speed","cooldown","cooldown"]
	var profile:=prior.duplicate(true)
	profile.learned=["Shield_Rank1"]
	profile.affinity=choices.size()
	profile.affinity_choices=choices
	Book.commit(profile)
	BattleRequest.configure_skirmish(MatchRules.EXTENDED,{"country":"美国","map_size":2400})
	var screen=load("res://scenes/battle.tscn").instantiate()
	add_child(screen)
	var w=screen.battle
	var building=w._place_building("GAPILE","ally",Vector2(560,620),true)
	check(Psi.summon(w),"affinity build summons normally")
	var u=Psi.hero(w)
	var reference=w.spawn_unit(Psi.ID,"ally",u.position+Vector2(60,0),building)
	check(is_equal_approx(u.max_hp,reference.max_hp*1.02) and is_equal_approx(u.hp,u.max_hp),"two health choices add two percent")
	check(is_equal_approx(u.move_speed,reference.move_speed*1.005) and is_equal_approx(u.bonuses.attack_bonus,reference.bonuses.attack_bonus*1.01),"affinity modifies live movement and attack")
	check(Book.commit(prior) and u.special.psi_support_left==184 and Psi.deployment_duration(w)==184,"two duration choices add four seconds and remain in the battle snapshot")
	check(Psi.shield(u) and is_equal_approx(u.special.psi_cd_Shield,15*0.995) and Psi.burst(u) and is_equal_approx(u.special.psi_cd_burst,30*0.995),"cooldown choices reduce actual Q and E cooldowns")
	check(is_equal_approx(Psi.cooldown_duration(u,"Lure"),30*0.995) and is_equal_approx(Psi.cooldown_duration(u,"Slam",3),3*0.995),"W and ranked R use the same cooldown reduction")
	w.units.erase(reference)
	reference.free()
	Psi.tick_deployment(w,75)
	var expected:=Vector3(u.max_hp,u.move_speed,u.bonuses.attack_bonus)
	var save:Dictionary=BattleSaves.save_slot(w,"slot1")
	check(save.ok,"save affinity-adjusted deployment")
	screen.free()
	if save.ok and BattleSaves.prepare_load("slot1").ok:
		screen=load("res://scenes/battle.tscn").instantiate()
		add_child(screen)
		w=screen.battle
		u=Psi.hero(w)
		check(u!=null and Vector3(u.max_hp,u.move_speed,u.bonuses.attack_bonus).is_equal_approx(expected) and is_equal_approx(u.special.psi_support_left,109) and is_equal_approx(Psi.cooldown_duration(u,"burst"),29.85),"reload restores adjusted stats and remaining duration once, independently of current profile")
		screen.free()
	else:check(false,"restore affinity-adjusted battle")

func exercise_expedition() -> void:
	check(Expedition.start("美国","",121) and Expedition.choose(0),"start expedition and take opening reward")
	var plan:Dictionary=Expedition.state.duplicate(true)
	Expedition.ready(plan)
	plan.routes[0].map="exp_plain"
	var field_missions=preload("res://scripts/expedition/field_missions.gd")
	for seed_value in range(1,2000):
		if field_missions.candidate(seed_value,1,plan.routes[0],plan.cycle)=="":
			plan.seed=seed_value
			break
	check(Expedition.commit(plan),"persist deterministic intelligence route")
	var camp=load("res://scenes/expedition.tscn").instantiate()
	add_child(camp)
	camp.build_routes()
	var clue:bool=camp.find_children("*","Label",true,false).any(func(l):return l.text.contains("英雄线索 · 百合子"))
	check(clue,"campaign route preview shows Yuriko clue")
	camp.free()
	if not Expedition.launch(0):
		check(false,Expedition.error)
		return
	var screen=load("res://scenes/battle.tscn").instantiate()
	add_child(screen)
	var field=screen.expedition_runtime.field_ops
	var matches=field.data.objectives.filter(func(o):return o.get("hero_lead","")=="YURIKO")
	check(matches.size()==1 and not Psi.summon(screen.battle),"actual battle assigns locked recruit's intel")
	if not matches.is_empty():
		screen.battle.spawn_unit("E1","ally",matches[0].position)
		field.tick(20.0)
		check(matches[0].done,"ground squad recovers battlefield intelligence")
	screen.battle.end_battle(true,false,true)
	check(Expedition.state.get("yuriko_recruited",false) and screen.result_overlay.name=="VictoryAnnouncement","winning operation recruits hero and opens RA3 victory art")
	find_button(screen.result_overlay,"查看结算").pressed.emit()
	check(find_button(screen.result_overlay,"返回远征营地")!=null,"expedition settlement returns to camp")
	screen.free()
	plan=Expedition.state.duplicate(true)
	Expedition.ready(plan)
	if not Expedition.commit(plan) or not Expedition.launch(0):
		check(false,Expedition.error)
		return
	screen=load("res://scenes/battle.tscn").instantiate()
	add_child(screen)
	var w=screen.battle
	w._place_building("GAPILE","ally",w.player_start()+Vector2(145,100),true)
	check(Psi.summon(w) and Music.stage=="yuriko","recruited hero deploys from barracks on next map")
	var u=Psi.hero(w)
	if u!=null:
		check(Psi.rank(w,"Shield")==3,"new expedition reads permanent study")
		u._die()
		check(u._dead and u._dying>0 and u.yuriko_model.action=="DYING","normal death retains native skeleton through its death clip")
	w.end_battle(true,false,true)
	check("Shield_Rank1" in Book.snapshot().learned,"settlement preserves account progression after hero death")
	screen.free()

func find_button(root,text:String):
	for child in root.get_children():
		if child is Button and child.text==text:return child
		var found=find_button(child,text)
		if found:return found
	return null
