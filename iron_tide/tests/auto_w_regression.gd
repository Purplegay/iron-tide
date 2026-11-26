extends "res://tests/ground_control_regression.gd"
const Auto = preload("res://scripts/units/auto_w.gd")
const Split = preload("res://scripts/units/ra3_reaper_split.gd")
const Tesla = preload("res://scripts/buildings/tesla_pulse.gd")

func make(id:String, card:="", side:="ally", at:=Vector2(1000,1000)):
	if not card.is_empty():BattleRequest.combat_context.loadouts[id]={"active":[card],"passive":""}
	var actor=battle.spawn_unit(id,side,at)
	activate(actor);actor.max_hp=10000;actor.hp=10000
	if battle.has_meta("auto_w_contacts"):battle.remove_meta("auto_w_contacts")
	return actor

func arm(actor,target) -> void:
	actor.attack_target=target;actor.attack_ordered=true;actor.fire_stance="free"
	actor.hull_angle=actor.global_position.angle_to_point(target.global_position)
	actor.turret_angle=actor.hull_angle

func clear_actors() -> void:
	battle.clear_selection()
	for actor in battle.units:
		if is_instance_valid(actor):actor.free()
	battle.units.clear()
	if battle.has_meta("auto_w_contacts"):battle.remove_meta("auto_w_contacts")

func check_defenses() -> void:
	var u=make("E2","ap_smoke")
	var enemy=make("HTNK","","enemy",Vector2(1200,1000))
	check(not Auto.evaluate(u),"smoke idle does not waste cooldown")
	u.hp=6000;Auto.record_hit(u,100,enemy)
	check(Auto.evaluate(u) and u.ability_at(UnitSkillLayout.index(u,1)).cd_left>0,"injured under-fire smoke uses real cooldown")
	check(not Auto.evaluate(u),"active smoke cannot repeat")
	u.ability_at(UnitSkillLayout.index(u,1)).cd_left=0
	u.ability_at(UnitSkillLayout.index(u,1)).active_left=0
	u.special.auto_w_hit_left=0
	check(not Auto.evaluate(u),"old injury alone cannot retrigger smoke")
	clear_actors()
	u=make("HTNK","ap_slope");enemy=make("MTNK","","enemy",Vector2(1100,1000))
	u.hull_angle=PI;Auto.record_hit(u,1,enemy)
	check(not Auto.evaluate(u),"slope armor ignores rear threat")
	u.hull_angle=0;u.velocity=Vector2(20,0)
	check(not Auto.evaluate(u),"slope armor waits for stop")
	u.velocity=Vector2.ZERO
	check(Auto.evaluate(u) and u.special.has("slope_left"),"front threat while stopped activates slope")
	clear_actors()
	u=make("R3MIRAGE","ap_decoy");enemy=make("MTNK","","enemy",Vector2(1100,1000))
	Auto.record_hit(u,1,enemy)
	check(not Auto.evaluate(u),"decoy never invents retreat")
	u.has_move_order=true;u.move_target=Vector2(1600,1000);u.velocity=Vector2(20,0)
	var destination:Vector2=u.move_target
	check(Auto.evaluate(u) and u.special.has("decoy_origin") and u.move_target==destination,"decoy preserves player's route")
	clear_actors()

func check_offense() -> void:
	var u=make("MTNK","ap_overdrive")
	u.has_move_order=true;u.move_target=u.position+Vector2(500,0)
	check(not Auto.evaluate(u),"overdrive does not spend on blocked intent")
	u.velocity=Vector2(20,0);u.move_target=u.position+Vector2(100,0)
	check(not Auto.evaluate(u),"overdrive ignores short remaining journey")
	u.move_target=u.position+Vector2(500,0)
	check(Auto.evaluate(u),"overdrive starts for long actual movement")
	clear_actors()
	for row in [["E2","ap_focus_fire"],["R3APOC","ap_twin"]]:
		u=make(row[0],row[1]);var target=make("HTNK","","enemy",Vector2(1150,1000))
		check(not Auto.evaluate(u),row[1]+" no target no cast")
		arm(u,target)
		if row[1]=="ap_twin":
			u.special.soviet_mode=true
			check(not Auto.evaluate(u),"harpoon mode does not calibrate guns")
			u.special.soviet_mode=false
			u.special.soviet_mounts={"R3APOC":{"used":1,"left":0.0}}
			check(not Auto.evaluate(u),"twin waits for next left barrel round")
			u.special.soviet_mounts={}
		else:
			u._cd_timer=5
			check(not Auto.evaluate(u),"focus waits for weapon cooldown")
			u._cd_timer=0
		check(Auto.evaluate(u),row[1]+" cast before ready shot")
		check(u.attack_target==target and u.attack_ordered,"auto buff preserves primary")
		clear_actors()
	u=make("SHK","ap_tesla_chain");var main=make("HTNK","","enemy",Vector2(1100,1000));arm(u,main)
	check(not Auto.evaluate(u),"chain does not waste on isolated target")
	var neighbor=make("E2","","enemy",Vector2(1120,1000))
	check(Auto.evaluate(u) and u.special.has("electric_chain"),"chain uses visible neighbor and real charge state")
	clear_actors()
	for id in ["SHK","TTNK"]:
		u=make(id,"ap_shock_pulse");u.fire_stance="free"
		main=make("HTNK","","enemy",Vector2(1100,1000))
		check(not Auto.evaluate(u),"healthy pulse waits for two enemies "+id)
		u.hp=3999
		var before:float=main.hp
		check(Auto.evaluate(u) and main.hp<before,"critical pulse hits single enemy "+id)
		clear_actors()
	u=make("SHK","ap_shock_pulse");u.fire_stance="free"
	main=make("HTNK","","enemy",Vector2(1100,1000));neighbor=make("E2","","enemy",Vector2(1120,1000))
	check(Auto.evaluate(u),"healthy pulse with two enemies")
	clear_actors()
	BattleRequest.combat_context.loadouts.TESLA={"active":["ap_shock_pulse"],"passive":""}
	var tower=battle._place_building("TESLA","ally",Vector2(1000,1000),true)
	tower._buildup_play=-1;battle.power_low=false
	main=make("HTNK","","enemy",Vector2(1100,1000));neighbor=make("E2","","enemy",Vector2(1120,1000))
	battle.power_low=true
	check(not Auto.evaluate(tower),"powered building cannot auto cast during blackout")
	battle.power_low=false
	check(Auto.evaluate(tower) and tower.special.tesla_pulse.left>0,"Tesla building uses same Auto W and real cooldown")
	battle.buildings.erase(tower);tower.free();clear_actors()

func check_split() -> void:
	var u=make("R3REAPER",Split.ID)
	var main=make("HTNK","","enemy",Vector2(1120,1000));arm(u,main)
	var angle:=Split.Pose.natural_heading(Split.Pose.definitions.grenade_mounts[1])
	var point:Vector2=u.position+Vector2.RIGHT.rotated(angle)*160
	var weak=make("HTNK","","enemy",point);weak.hp=1000
	var strong=make("HTNK","","enemy",point+Vector2(2,2));strong.hp=3000
	u.hp=1999
	check(not Auto.evaluate(u),"below 80 percent and below 2x target HP cannot split")
	u.hp=2000
	check(Auto.evaluate(u) and Split.secondary(u)==weak,"2x health boundary qualifies and picks weaker target")
	check(u.attack_target==main and u.attack_ordered and battle.command_mode.is_empty(),"auto secondary keeps primary and mouse mode")
	check(not Auto.evaluate(u),"valid secondary never replaced")
	Split.clear(u);u.hp=8000;weak.hp=20000;strong.hp=30000
	check(Auto.evaluate(u) and Split.secondary(u)==weak,"80 percent health boundary qualifies regardless target HP")
	Split.clear(u);Split.assign(u,strong)
	check(not Auto.evaluate(u) and Split.secondary(u)==strong,"manual secondary has priority")
	u.order_stop()
	check(not Auto.evaluate(u) and not u.special.has("split_enemy"),"stop does not auto restart attack")
	clear_actors()

func check_guards() -> void:
	var u=make("E2","ap_smoke");u.hp=6000;Auto.record_hit(u,1,null)
	for condition in ["paused","ended","stun","repair","stationary","casting","frozen","embarked","dead"]:
		match condition:
			"paused":battle.paused=true
			"ended":battle.ended=true
			"stun":u._stun_timer=1
			"repair":u.repairing=true
			"stationary":u.special.gm_stationary=true
			"casting":battle.cast_slot=1
			"frozen":u.special.chrono_left=1.0
			"embarked":u.embarked_in=battle
			"dead":u.hp=0
		check(not Auto.evaluate(u),"guard blocks "+condition)
		battle.paused=false;battle.ended=false;u._stun_timer=0;u.repairing=false;u.special.erase("gm_stationary");battle.cast_slot=-1
		u.special.erase("chrono_left");u.embarked_in=null;u.hp=6000
	u.set_meta("auto_w_think",0.2)
	var old_scale := Engine.time_scale
	Engine.time_scale = 3.0
	var hit_left := float(u.special.auto_w_hit_left)
	Auto.tick(u,0.3)
	check(is_equal_approx(u.special.auto_w_hit_left, hit_left - 0.3),"3x damage memory follows simulation time")
	check(u.ability_at(UnitSkillLayout.index(u,1)).cd_left==0,"3x auto check is throttled in real time")
	Auto.tick(u,0.33)
	Engine.time_scale = old_scale
	check(u.ability_at(UnitSkillLayout.index(u,1)).cd_left>0,"scheduled check uses actual cast")
	clear_actors()
	u=make("DEST","ap_buoy")
	check(Auto.enabled(u) and not Auto.evaluate(u),"search buoy waits for known underwater contact")
	clear_actors()
	u=make("MTNK","ap_smoke")
	check(Auto.enabled(u) and UnitSkillLayout.index(u,0)==-1 and UnitSkillLayout.index(u,1)>=0,"explicitly equipped smoke is W, never a free native Q")
	clear_actors()
	u=make("E2","ap_focus_fire")
	var target=make("HTNK","","enemy",u.position+Vector2(100,0));arm(u,target)
	target.special.echo_cloaked=true
	check(not Auto.evaluate(u) and Auto.contacts(u,u.position,300).is_empty(),"hidden enemy cannot trigger targeted Auto W or area count")
	target.special.erase("echo_cloaked")
	u.attack_ordered=false;u.fire_stance="none"
	check(not Auto.evaluate(u),"disabled firing stance does not spend offensive buff")
	clear_actors()
	u=make("E2","ap_smoke");u.hp=6000
	var enemy=make("HTNK","","enemy",u.position+Vector2(100,0))
	u.receive_hit(1,"bullet",{},enemy)
	u.set_meta("auto_w_think",0.0)
	u._physics_process(0.016)
	check(u.ability_at(UnitSkillLayout.index(u,1)).cd_left>0,"actual damage and physics entry execute auto smoke")
	clear_actors()

func check_deployed() -> void:
	BattleRequest.combat_context.loadouts.R3REAPER={"active":[Split.ID],"passive":""}
	var tower=battle._place_building("R3REAPERTURRET","ally",Vector2(1000,1000),true)
	tower._buildup_play=-1;tower._think=99
	var main=make("HTNK","","enemy",tower.position+Vector2(120,0))
	var side=make("HTNK","","enemy",tower.position+Vector2.RIGHT.rotated(Split.Pose.natural_heading(Split.Pose.definitions.grenade_mounts[1]))*160)
	var emplacement=preload("res://scripts/buildings/ra3_reaper_emplacement.gd")
	check(emplacement.order(tower,main),"deployed turret accepts actual main-target order")
	var gun=emplacement.mount(tower);gun.set_meta("auto_w_think",0.0)
	emplacement.tick(tower,0.016)
	check(Split.secondary(gun)==side and tower.attack_target==main,"deployed tick acquires secondary without replacing main",[Auto.enabled(gun),Split.engaged(gun),gun.hp,gun.max_hp,gun.hull_angle,Split.choose_side(gun,side),Auto.card_id(gun),gun.special.get("split_enemy"),tower.position,main.position,side.position])
	battle.select_building(tower);screen.hud._rebuild_ability_bar()
	check(screen.hud.ability_box.find_child("AutoWToggle",true,false)!=null,"deployed W exposes toggle")
	battle.clear_selection();battle.buildings.erase(tower);tower.free();clear_actors()

func exercise(mode:String) -> void:
	start(mode)
	if battle.fog!=null:battle.fog.free();battle.fog=null
	for building in battle.buildings:building.free()
	battle.buildings.clear()
	battle._refresh_pathing()
	GM.god_mode=false
	BattleRequest.combat_context.bonuses=MatchRules.neutral_bonuses()
	BattleRequest.combat_context.unit_bonus={}
	var u=make("E2","ap_smoke");u.hp=5000
	check(not Auto.enabled(u) and not Auto.evaluate(u),"no research no auto")
	check(not Auto.set_all(battle,true) and screen.hud.auto_w_controls.visible and screen.hud.auto_w_controls.get_node("AutoWAllOn").disabled and screen.hud.auto_w_controls.get_node("AutoWAllOff").disabled,"unresearched global controls remain visible but unavailable")
	if mode==MatchRules.EXTENDED:
		check(u.use_ability(UnitSkillLayout.index(u,1)),"manual W remains usable without Auto research")
	battle.production_technology.unlock(Auto.TECH,"ally")
	if mode==MatchRules.RA2:
		check(not Auto.enabled(u),"classic mode rejects auto even with debug grant")
		check(not Auto.set_all(battle,true),"classic rejects global toggle")
		await finish();return
	clear_actors()
	check_defenses();check_offense();check_split();check_guards();check_deployed()
	preload("res://tests/auto_w_expansion_cases.gd").run(self)
	preload("res://tests/auto_w_tactical_cases.gd").run(self)
	preload("res://tests/auto_w_maneuvers_cases.gd").run(self)
	u=make("E2","ap_smoke");var other=make("HTNK","ap_slope")
	screen.hud.refresh_repair_all()
	var on: Button = screen.hud.auto_w_controls.get_node("AutoWAllOn")
	var off: Button = screen.hud.auto_w_controls.get_node("AutoWAllOff")
	check(on.button_pressed and not off.button_pressed, "default global selection is all on")
	battle.select_unit(u,false);battle.select_unit(other,true)
	screen.hud._rebuild_ability_bar()
	var button=screen.hud.ability_box.find_child("AutoWToggle",true,false)
	check(button!=null and button.button_pressed and button.size==Vector2(12,12),"actual skill bar exposes enabled compact Auto W badge")
	check(is_equal_approx(button.get_rect().end.x,button.get_parent().size.x) and is_zero_approx(button.position.y),"badge sits at W top right")
	check(button.get_theme_stylebox("pressed") is StyleBoxEmpty,"badge has no rectangular fill")
	button.pressed.emit()
	check(not on.button_pressed and not off.button_pressed, "per-type overrides clear both global highlights")
	check(not Auto.enabled(u) and not Auto.enabled(other),"actual UI toggles multi-selection")
	check(Auto.preferences().get("E2",true)==false and Auto.preferences().get("HTNK",true)==false,"per-type preference persists on disk")
	var reinforcement=make("E2","ap_smoke")
	check(not Auto.enabled(reinforcement),"newly produced same type inherits disabled state")
	DirAccess.make_dir_absolute(Auto.PREFS+".tmp")
	check(not Auto.set_group(battle,[u,other],true) and not Auto.enabled(u),"failed preference write leaves live switch unchanged")
	DirAccess.remove_absolute(Auto.PREFS+".tmp")
	screen.hud.refresh_repair_all()
	check(screen.hud.auto_w_controls.visible,"researched battle exposes global controls")
	battle.clear_selection()
	screen.hud.auto_w_controls.get_node("AutoWAllOn").pressed.emit()
	check(on.button_pressed and not off.button_pressed, "all on alone is selected")
	check(Auto.enabled(u) and Auto.enabled(other),"global on works without selection and clears type overrides")
	screen.hud.auto_w_controls.get_node("AutoWAllOff").pressed.emit()
	check(not on.button_pressed and off.button_pressed, "all off alone is selected")
	check(not Auto.enabled(u) and not Auto.enabled(other),"global off covers all existing types")
	var future=make("MGTK","ap_smoke")
	check(not Auto.enabled(future),"global off covers previously unbuilt types")
	Auto.set_group(battle,[u],true)
	check(Auto.enabled(u) and not Auto.enabled(other) and not Auto.enabled(future),"single type can override global off")
	screen.hud.auto_w_controls.get_node("AutoWAllOn").pressed.emit()
	check(Auto.enabled(future) and Auto.enabled(other),"global on resets individual overrides")
	DirAccess.make_dir_absolute(Auto.PREFS+".tmp")
	check(not Auto.set_all(battle,false) and Auto.enabled(future),"global save failure preserves prior settings")
	off.set_pressed_no_signal(true)
	off.pressed.emit()
	check(on.button_pressed and not off.button_pressed, "failed button action restores prior highlight")
	DirAccess.remove_absolute(Auto.PREFS+".tmp")
	screen.hud.auto_w_controls.get_node("AutoWAllOff").pressed.emit()
	check(Auto.preferences().get(Auto.DEFAULT,true)==false and Auto.preferences().size()==1,"global default persists without stale type overrides")
	check(BattleSaves.save_slot(battle,"slot1").ok,"auto toggle saved in real battle file")
	Auto.set_all(battle,true)
	check(BattleSaves.prepare_load("slot1").ok,"auto battle save staged")
	BattleSaves.restore_pending(battle);battle.paused=false;get_tree().paused=false
	screen.hud.refresh_repair_all()
	check(not on.button_pressed and off.button_pressed, "restored battle highlights its saved all-off preference")
	u=battle.units.filter(func(actor):return actor.unit_id=="E2")[0]
	check(not Auto.enabled(u),"battle restore uses saved toggle rather than later preferences")
	future=make("FV","ap_smoke")
	check(not Auto.enabled(future),"saved global default also applies to new types after restore")
	var meta=MetaProgress
	meta.unlocked_technologies.erase(Auto.TECH);meta.currency.cores=40
	check(meta.research_technology(Auto.TECH) and meta.currency.cores==0,"real permanent research costs 40 cores")
	check(not meta.research_technology(Auto.TECH),"cannot purchase research twice")
	var tree=preload("res://scripts/ui/technology_tree.gd").new()
	add_child(tree)
	check(tree.cards.has(Auto.TECH) and tree.cards[Auto.TECH].toggle.visible,"actual technology tree exposes purchased Auto W")
	tree.free()
	await finish()
	start(mode)
	u=make("E2","ap_smoke")
	check(Auto.enabled(u),"new extended match inherits purchased tech and latest per-type preference")
	await finish()
