extends "res://tests/ground_control_regression.gd"
const Keys=preload("res://scripts/ui/battle_hotkeys.gd")
const Details=preload("res://scripts/ui/battle_effect_details.gd")
const Editor=preload("res://scripts/ui/battle_hotkey_editor.gd")

func key(code:int,ctrl:=false) -> InputEventKey:
	var event:=InputEventKey.new();event.keycode=code;event.pressed=true;event.ctrl_pressed=ctrl
	return event

func check_adaptive_refresh(pacer) -> void:
	pacer.observe_frame(900000)
	for i in 40: pacer.observe_frame(10000)
	check(pacer.tier == 0, prefix+"an isolated stall does not slow down scouting")
	for expected in [1, 2, 3, 3]:
		for i in 10: pacer.observe_frame(50000)
		check(pacer.tier == expected, prefix+"sustained slow frames back off one tier "+str(expected))
	var hunter = battle.spawn_unit("MTNK","enemy",Vector2(1000,1000))
	var prey = battle.spawn_unit("E2","ally",Vector2(1800,1100))
	hunter.start_target_order(prey,false,false)
	check(hunter.has_move_order and hunter._path_pts.size() >= 2 and hunter._chase_repath_left >= 1.1,prefix+"first attack plots a route immediately at maximum backoff")
	var previous: Vector2 = hunter._chase_goal
	hunter._chase_target(previous + Vector2(100,0), 0.2)
	check(hunter._chase_goal == previous,prefix+"moving target reuses its route during backoff")
	hunter._chase_target(previous + Vector2(100,0), 1.1)
	check(hunter._chase_goal != previous,prefix+"moving target eventually gets a fresh route")
	var player = battle.spawn_unit("MTNK","ally",Vector2(1800,1200))
	player.start_target_order(hunter,false,false)
	check(is_equal_approx(player._chase_retry_interval,0.35),prefix+"player chase stays responsive at maximum backoff")
	var new_goal: Vector2 = player._chase_goal + Vector2(100,0)
	player._chase_target(new_goal,0.36)
	check(player._chase_goal == new_goal,prefix+"player updates chase before computer retry window")
	player._tick_path_stuck(0.01)
	player._tick_path_stuck(1.0)
	check(is_zero_approx(player._nav_stuck_t) and not pacer._retry_waiting.has(player.get_instance_id()),prefix+"blocked player replans without joining slow-frame retry queue")
	for actor in [hunter,prey,player]:
		battle.units.erase(actor)
		actor.free()
	var added_fog: bool = battle.fog == null
	if added_fog:
		battle.fog = preload("res://scripts/world/fog_of_war.gd").new()
		battle.add_child(battle.fog)
		battle.fog.setup(battle)
	var fog = battle.fog
	fog.rebuild()
	var count_before: int = fog.rebuild_count
	fog._process(0.11)
	check(fog.rebuild_count == count_before,prefix+"regular sight refresh respects backoff")
	fog._process(0.22)
	check(fog.rebuild_count == count_before+1,prefix+"regular sight refresh is bounded")
	fog.firing_positions[123] = {"side":"ally","position":Vector2.ZERO,"remaining":0.01}
	fog._process(0.02)
	check(fog.rebuild_count == count_before+2,prefix+"shot reveal expiry bypasses backoff")
	if added_fog:
		battle.fog.free()
		battle.fog = null
	for i in 20: pacer.observe_frame(25000)
	check(pacer.tier == 3,prefix+"intermediate frame times hold current tier")
	for expected in [2, 1, 0]:
		for i in 200: pacer.observe_frame(10000)
		check(pacer.tier == expected,prefix+"sustained recovery restores one tier "+str(expected))

func exercise(mode:String) -> void:
	start(mode)
	var legacy := ConfigFile.new()
	legacy.set_value("keys","stop",KEY_F8)
	legacy.save(Keys.PATH)
	Keys.loaded=false
	Keys.ensure()
	check(Keys.bindings.stop==KEY_F8 and Keys.bindings.snapshot==KEY_F7,prefix+"legacy F8 binding preserved")
	Keys.save(Keys.defaults())
	battle.spawn_unit("E1","ally",Vector2(1000,1200))
	var sampler = screen.hud._performance_snapshot
	var pacer = screen.frame_pacing
	var limit := Engine.max_physics_steps_per_frame
	var base_hz := Engine.physics_ticks_per_second
	var speed := Engine.time_scale
	check(base_hz == 15 and limit == 8,prefix+"battle uses fifteen wall ticks with at most seven catchup steps")
	for multiplier in [1.0,2.0,3.0]:
		BattleClock.set_speed(multiplier)
		for work in [9000,90000]:
			pacer._steps = 1
			pacer._work_us = work
			pacer._process(0)
			check(Engine.physics_ticks_per_second==15 and Engine.max_physics_steps_per_frame==8 and Engine.time_scale==multiplier,prefix+"load preserves fixed cadence and requested speed "+str(multiplier))
	BattleClock.set_speed(speed)
	pacer.tier=0
	check_adaptive_refresh(pacer)
	var retries := preload("res://scripts/world/battle_frame_pacing.gd").new()
	retries.tier = 3
	var pending: Array = range(12)
	for id in pending: retries.allow_stuck_retry(id)
	for batch in 3:
		while Engine.get_process_frames() == retries._retry_frame: await get_tree().process_frame
		var allowed: Array = []
		for id in pending:
			if retries.allow_stuck_retry(id): allowed.append(id)
		check(allowed == range(batch*4,batch*4+4),prefix+"stalled route retries share a frame budget in FIFO order")
		for id in allowed: pending.erase(id)
	retries.tier = 0
	check(retries.allow_stuck_retry(20),prefix+"normal load allows immediate stuck retry")
	retries.free()
	for i in 320: sampler.sample_frame()
	screen.hud._input(key(KEY_F8))
	var captured:Dictionary = sampler.finish()
	check(captured.get("ok",false),prefix+"F8 writes a performance snapshot",captured)
	if captured.get("ok",false):
		var data = JSON.parse_string(FileAccess.get_file_as_string(captured.path))
		check(data.frames.count==300 and data.frames.interval_us.size()==300 and data.frames.physics_steps.size()==300 and data.frames.max_steps_per_frame==limit and data.frames.p95_ms<=data.frames.max_ms,prefix+"bounded recent frame intervals and physics counts")
		check(data.pid==OS.get_process_id() and data.match_id==battle.match_id and data.units.by_type.get("E1",0)>0 and data.scene_nodes>0 and data.has("effects") and data.has("projectiles") and data.adaptive_refresh.tier == 0,prefix+"snapshot describes this running battle")
		if OS.get_name()=="Windows":check(data.memory_bytes.get("working_set",0)>0 and data.memory_bytes.get("private_bytes",0)>0,prefix+"actual Windows process memory")
		screen.hud._input(key(KEY_F8))
		var second:Dictionary = sampler.finish()
		check(second.get("ok",false) and second.path!=captured.path and FileAccess.file_exists(captured.path),prefix+"successive snapshots coexist")
	check(Keys.assign("stop",KEY_B).is_empty(),prefix+"assign unused single key")
	check(Keys.translate(key(KEY_B)).keycode==KEY_S and Keys.translate(key(KEY_S))==null,prefix+"new key maps canonical command and old key inactive")
	check(not Keys.assign("attack",KEY_B).is_empty() and Keys.label("attack")=="A",prefix+"duplicate binding rejected")
	for reserved in [KEY_1,KEY_F11,KEY_ESCAPE,KEY_LEFT]:
		check(not Keys.assign("stop",reserved).is_empty(),prefix+"reserved key rejected "+str(reserved))
	Keys.loaded=false;Keys.ensure()
	check(Keys.label("stop")=="B",prefix+"disk reload keeps assignment")
	DirAccess.make_dir_absolute(Keys.PATH+".tmp")
	check(not Keys.assign("stop",KEY_U).is_empty() and Keys.label("stop")=="B",prefix+"write failure preserves binding")
	DirAccess.remove_absolute(Keys.PATH+".tmp")
	check(Keys.hint("停止 (S)；Ctrl+G；全选 F2")=="停止 (B)；Ctrl+G；全选 F2",prefix+"tooltip key substitution preserves reserved chord")
	var malformed:=ConfigFile.new();malformed.set_value("keys","stop",KEY_Q);malformed.save(Keys.PATH)
	Keys.loaded=false;Keys.ensure()
	check(Keys.bindings==Keys.defaults(),prefix+"malformed duplicate file safely falls back to defaults")
	Keys.assign("stop",KEY_B)
	var u=battle.spawn_unit("E1","ally",Vector2(1100,1100));activate(u)
	battle.select_unit(u,false)
	u.order_move(Vector2(1600,1100));screen.hud._input(key(KEY_S))
	check(u.has_move_order,prefix+"old stop no longer orders actual unit")
	screen.hud._input(key(KEY_B))
	check(not u.has_move_order,prefix+"remapped stop orders actual unit")
	screen.hud._input(key(KEY_1,true))
	check(battle.control_groups.get("1",[]).has(u),prefix+"Ctrl digit group assignment retained")
	screen.hud._refresh_selection()
	screen.hud._refresh_hotkey_labels()
	check(screen.hud.cmd_buttons.stop.get_meta("hotkey_label").text=="B",prefix+"command corner label refreshed")
	var editor=Editor.new();add_child(editor)
	check(Keys.modal_count==1 and not battle.world_input_enabled(),prefix+"editor blocks world input")
	u.order_move(Vector2(1600,1100));screen.hud._input(key(KEY_B))
	check(u.has_move_order,prefix+"editor blocks combat shortcuts")
	editor.buttons.skill_w.pressed.emit();editor._input(key(KEY_J))
	check(Keys.label("skill_w")=="J" and editor.waiting.is_empty(),prefix+"actual key editor saves captured key")
	editor.buttons.attack.pressed.emit();editor._input(key(KEY_B))
	check(not editor.waiting.is_empty(),prefix+"conflict remains in capture mode")
	editor._input(key(KEY_ESCAPE))
	check(editor.waiting.is_empty() and is_instance_valid(editor),prefix+"escape cancels capture without closing")
	editor.free();check(Keys.modal_count==0,prefix+"close releases input lock")
	BattleRequest.combat_context.native_training_version=4
	BattleRequest.combat_context.unit_talents={"E1":{"native_deploy_def":3}}
	var description:=Details.describe(u)
	if mode==MatchRules.EXTENDED:
		check(description.contains("Lv.3") and description.contains("卧倒防御系数"),prefix+"battle talent rank and current native values displayed",description)
		MetaProgress.unit_talents={"E1":{"native_deploy_def":0}}
		check(Details.describe(u)==description,prefix+"later account change cannot rewrite battle rank")
	else:check(not description.contains("本局已启用天赋"),prefix+"classic mode excludes progression talents")
	BattleRequest.combat_context.loadouts={"MTNK":{"active":[],"passive":"ps_armor_plating"}}
	# Use a real equipped passive rather than synthesizing description text.
	var card_id:="ps_armor_plating"
	BattleRequest.combat_context.card_ranks={card_id:2}
	var equipped=battle.spawn_unit("MTNK","ally",Vector2(1300,1100));activate(equipped)
	if mode==MatchRules.EXTENDED:
		check(not equipped.passive.is_empty() and Details.describe(equipped).contains(equipped.passive_desc()),prefix+"passive uses actual runtime description")
		for unit_id in GameData.unit_index:
			var options:=MetaProgress.talent_options(unit_id)
			if options.is_empty():continue
			var subject=battle.spawn_unit(unit_id,"ally",Vector2(1500,1500));activate(subject)
			for talent in options:
				for rank in [0,options[talent].get("ranks",[]).size()]:
					BattleRequest.combat_context.unit_talents={unit_id:{talent:rank}}
					var text:=Details.describe(subject)
					check(text.contains(options[talent].name) and text.contains("Lv.%d"%rank),"every current talent readable "+unit_id+talent+str(rank))
			battle.units.erase(subject);subject.free()
		BattleRequest.combat_context.unit_talents={"E1":{"native_deploy_def":3}}
		var tower=battle._place_building("TESLA","ally",Vector2(1700,1700),true)
		tower.special.card_armor=0.14;tower.special.card_armor_rank=2
		check(Details.describe(tower).contains("复合装甲板"),"building runtime passive readable")
		battle.buildings.erase(tower);tower.free()
		tower=battle._place_building("R3REAPERTURRET","ally",Vector2(1700,1700),true)
		preload("res://scripts/buildings/ra3_reaper_emplacement.gd").mount(tower)
		BattleRequest.combat_context.unit_talents.R3REAPER={"reaper_fire_control":3}
		check(Details.describe(tower).contains("协同瞄准"),"deployed reaper retains unit talent details")
		battle.buildings.erase(tower);tower.free()
		equipped.special.academy_hero="MTNK";equipped.special.hero_command_rank=2;equipped.special.hero_survival_rank=2
		check(Details.describe(equipped).contains(Unit.TankHero.COMMAND[2]) and Details.describe(equipped).contains(Unit.TankHero.DEFENSE[1]),"hero cumulative talents readable")
		equipped.buffs.append({"kind":"cooldown","value":0.2,"name":"测试冷却","left":3.0,"dur":5.0})
		check(Details.describe(equipped).contains("冷却-20%"),"live temporary effect uses actual values")
		BattleRequest.combat_context.loadouts.E2={"active":["ap_smoke"],"passive":""}
		var caster=battle.spawn_unit("E2","ally",Vector2(1200,1300));activate(caster)
		battle.select_unit(caster,false);screen.hud._refresh_selection()
		var ab=caster.ability_at(UnitSkillLayout.index(caster,1))
		screen.hud._input(key(KEY_W))
		check(ab.cd_left==0,"old W no longer casts")
		screen.hud._input(key(KEY_J))
		check(ab.cd_left>0 and screen.hud._ability_btns[1].get_meta("key")=="J","remapped W casts actual skill and displays current key")
	battle.select_unit(u,false);screen.hud._rebuild_ability_bar()
	var button=screen.hud.ability_box.find_child("EffectDetails",true,false)
	check(button!=null,prefix+"skill bar exposes details even with no passive card")
	get_tree().paused=false;battle.paused=false
	button.pressed.emit()
	var panel
	for child in screen.hud.get_children():
		if child.get_script()==Details:panel=child
	check(is_instance_valid(panel) and panel.body.text==Details.describe(u),prefix+"actual button opens current actor details")
	check(get_tree().paused and battle.paused and panel.can_process() and screen.hud.pause_btn.text=="继续",prefix+"details pauses simulation while modal remains responsive")
	Details.open(screen.hud,u)
	check(Keys.modal_count==1,prefix+"duplicate open cannot stack pause ownership")
	u._dead=true;panel.refresh()
	check(panel.body.text=="该单位已离场。",prefix+"death updates open details safely")
	panel.free();check(Keys.modal_count==0,prefix+"details close releases input")
	check(not get_tree().paused and not battle.paused and screen.hud.pause_btn.text=="暂停",prefix+"closing resumes previously running match")
	u._dead=false
	for previous in [[true,true],[false,true],[true,false]]:
		get_tree().paused=previous[0];battle.paused=previous[1]
		Details.open(screen.hud,u)
		for child in screen.hud.get_children():
			if child.get_script()==Details:panel=child
		check(get_tree().paused and battle.paused,prefix+"details pauses both flags from "+str(previous))
		panel._input(key(KEY_ESCAPE))
		await get_tree().process_frame
		check(get_tree().paused==previous[0] and battle.paused==previous[1] and Keys.modal_count==0,prefix+"Esc restores original flags "+str(previous))
	get_tree().paused=false;battle.paused=false

	var discarded=Unit.new();discarded.free()
	check(Details.describe(discarded)=="该单位已离场。",prefix+"freed actor safe")
	Keys.save(Keys.defaults());MetaProgress.unit_talents={}
	await finish()
