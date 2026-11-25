extends "res://tests/base_recovery_regression.gd"
const X=preload("res://scripts/units/progression_expansion.gd")
const Second=preload("res://scripts/units/progression_expansion_2.gd")
const Demo=preload("res://scripts/ui/expansion_2_demo.gd")
const Scope=preload("res://scripts/rules/skill_scope.gd")

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
	await get_tree().process_frame
	MetaProgress.reset_save()
	var pack:Dictionary=GameData.raw_docs["progression_expansion_2.json"]
	for card:Dictionary in pack.skills:
		check(GameData.get_skill(card.id).id==card.id,"registered "+card.id)
		check(MetaProgress.skill_draw_rules().rarity_weight.has(card.rarity),"canonical drawable rarity "+card.id)
		for level in 4:
			check(not MetaProgress.Academy.skill_description(card,level).contains("{"),card.id+" rank text "+str(level))
			check(not Demo.sample(card.id,level,2).text.is_empty(),card.id+" playable demonstration data "+str(level))
	for id:String in GameData.meta_config.unit_talents:check(GameData.meta_config.unit_talents[id].size()<=2,"two talent limit "+id)
	await permanent_progression()
	MetaProgress.reset_save()
	for level in 4:
		await exercise(level)
		await breather_inflight(level)
	await boundaries()
	await revised_save_boundaries()
	await classic()
	await demos()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	print("EXPANSION_2_RESULT ",checks.size()," checks, ",failed," failed")
	get_tree().quit(0 if failed==0 else 1)

func ability(unit,id:String) -> Ability:
	var ab:=Ability.new();ab.setup(GameData.get_skill(id),int(BattleRequest.combat_context.card_ranks.get(id,0)));unit.skills.append(ab)
	return ab

func breather_inflight(level:int) -> void:
	start(MatchRules.EXTENDED);BattleRequest.skirmish_config.fog_of_war=false
	BattleRequest.combat_context.card_ranks.ap_battle_breather=level
	var guard:Unit=battle.spawn_unit("GGI","ally",Vector2(1100,1200));guard.set_deployed(true,false)
	var target:Unit=battle.spawn_unit("HTNK","enemy",Vector2(1250,1200));target.hp=100000;target.max_hp=100000
	var ab:=ability(guard,"ap_battle_breather")
	check(normal_shot(guard,target) and not missiles(guard).is_empty(),"ordinary deployed missile exists before manual retreat setup")
	guard.set_deployed(false,false)
	check(guard.use_ability(guard.skills.size()-1) and not missiles(guard).is_empty(),"breather begins after manual undeploy without removing already launched missile")
	fly_missiles(guard)
	check(target.hp<100000 and not Second.can_attack(guard) and not normal_shot(guard,target),"pre-existing missile still damages while breather blocks new firing")
	X.tick(guard,3)
	check(Second.can_attack(guard) and normal_shot(guard,target),"breather ends fire lock exactly after three seconds")
	ab.cd_left=0;guard.special.chrono_left=1.
	check(not guard.use_ability(guard.skills.size()-1) and ab.cd_left==0 and not Second.state(guard).has("breather_left"),"frozen infantry cannot spend breather cooldown or receive effect")
	guard.special.erase("chrono_left");X.tick(guard,.01)
	check(not Second.state(guard).has("breather_left") and ab.cd_left==0,"thaw does not execute a previously rejected breather")
	await finish()

func normal_shot(unit,target) -> bool:
	unit.attack_target=target;unit.attack_ordered=true;unit._cd_timer=0;unit._cancel_burst()
	unit.hull_angle=unit.position.direction_to(target.position).angle();unit.turret_angle=unit.hull_angle;unit.aim_dir=Vector2.from_angle(unit.hull_angle)
	return unit._try_fire_ready()

func missiles(actor) -> Array:
	return actor._pick_projectile_parent().get_children().filter(func(node):return node is Projectile and node.shooter()==actor and not node.is_queued_for_deletion())

func fly_missiles(actor) -> void:
	# Drive the actual projectile travel and detonation, without advancing the frozen battle.
	for tick in 240:
		var flying:=missiles(actor)
		if flying.is_empty():return
		for projectile in flying:projectile._physics_process(1.0/60.0)
	check(missiles(actor).is_empty(),"all launched missiles resolved within four seconds")

func crew(carrier,passenger) -> void:
	for old in carrier.logistics.passengers:
		if is_instance_valid(old):old.set_stowed(null)
	carrier.logistics.passengers.clear()
	if passenger!=null:carrier.logistics.passengers.append(passenger);passenger.set_stowed(carrier)
	carrier._refresh_weapon_derived();AlliedAbilities.refresh_ifv_art(carrier)

func permanent_progression() -> void:
	var pool:=MetaProgress.skill_draw_candidates()
	for card:Dictionary in GameData.raw_docs["progression_expansion_2.json"].skills:
		check(pool.any(func(row):return row.id==card.id),"normal draw pool contains "+card.id)
		check(not MetaProgress.set_unit_skill(card.allowed_units[0],card.type,0,card.id),"unowned card cannot equip "+card.id)
		check(MetaProgress.unlock_skill(card.id),"acquire card through permanent unlock "+card.id)
		for id:String in card.allowed_units:check(MetaProgress.set_unit_skill(id,card.type,0,card.id),"owned shared card equips "+id+" "+card.id)
		var wrong:String="E1" if card.allowed_units.has("HTNK") else "HTNK"
		check(not MetaProgress.set_unit_skill(wrong,card.type,0,card.id),"wrong unit cannot equip "+card.id)
	MetaProgress.currency.cores=100000
	for pair in [["E1","position_rotation"],["FV","steady_seat"]]:
		var offer:=MetaProgress.talent_unlock_quote(pair[0],pair[1])
		check(not offer.is_empty() and MetaProgress.unlock_unit_talent(pair[0],pair[1],offer.get("cost",-1)),"real talent purchase "+pair[1])
		for rank in 3:check(MetaProgress.upgrade_talent(pair[0],pair[1],rank),"real talent upgrade "+pair[1]+str(rank))
		check(not MetaProgress.upgrade_talent(pair[0],pair[1],3),"talent maximum enforced "+pair[1])
	MetaProgress.load_save()
	check(MetaProgress.unit_effective_loadout("GGI").active.has("ap_battle_breather") and MetaProgress.unit_effective_loadout("FV").passive=="ps_module_shell","profile reload retains cards and equipment")
	check(MetaProgress.talent_rank("E1","position_rotation",MetaProgress.unit_talents)==3 and MetaProgress.talent_rank("FV","steady_seat",MetaProgress.unit_talents)==3,"profile reload retains both talent ranks")
	start(MatchRules.EXTENDED)
	var gi=battle.spawn_unit("E1","ally",Vector2(1000,1000))
	var fv=battle.spawn_unit("FV","ally",Vector2(1100,1000))
	check(gi.skills.any(func(ab):return ab.id=="ap_battle_breather") and fv.passive.get("id")=="ps_module_shell","real new match spawns with frozen equipment")
	check(BattleRequest.has_unit_talent("E1","position_rotation","ally") and BattleRequest.talent_upgrade("FV","steady_seat","ally").get("value")==17,"real new match freezes purchased talent ranks")
	await finish()

func exercise(level:int) -> void:
	start(MatchRules.EXTENDED)
	BattleRequest.skirmish_config.fog_of_war=false
	for card:Dictionary in GameData.raw_docs["progression_expansion_2.json"].skills:BattleRequest.combat_context.card_ranks[card.id]=level
	BattleRequest.combat_context.unit_talents.E1={"position_rotation":level}
	BattleRequest.combat_context.unit_talents.FV={"steady_seat":level}
	var target=battle.spawn_unit("HTNK","enemy",Vector2(1200,1000));target.max_hp=100000;target.hp=100000
	var gi=battle.spawn_unit("E1","ally",Vector2(1100,1000));gi.set_deployed(true,false)
	gi._cd_timer=5.0
	X.tick(gi,2.9);check(int(Second.state(gi).get("rotation_charges",0))==0,"rotation waits full three seconds "+str(level))
	X.tick(gi,.1);check(Second.state(gi).rotation_charges==3,"rotation grants exactly three "+str(level))
	check(gi._cd_timer==5.0,"earning rotation never retroactively shortens an existing reload")
	var base_reload:=CombatMath.veteran_cooldown(gi.cooldown,gi.bonuses)*Unit.YRTalents.cooldown_multiplier(gi)
	for remaining in [2,1,0]:
		check(normal_shot(gi,target),"actual GI volley fires")
		check(Second.state(gi).rotation_charges==remaining,"one charge per volley "+str(remaining))
		check(is_equal_approx(gi._cd_timer,base_reload*(1-[.1,.15,.2,.25][level])),"actual new reload shortened")
		if remaining==2:
			var prior_reload:float=gi._cd_timer
			var codec=BattleSaves.Snapshot.new();var snapshot:Dictionary=codec.capture(battle);codec.restore(battle,snapshot)
			gi=battle.units.filter(func(u):return u.unit_id=="E1" and u.side=="ally")[0]
			target=battle.units.filter(func(u):return u.unit_id=="HTNK" and u.side=="enemy")[0]
			check(codec.error.is_empty() and Second.state(gi).rotation_charges==2 and is_equal_approx(gi._cd_timer,prior_reload),"rotation save preserves two remaining rounds and active reload "+str(level))
			X.tick(gi,3.1)
			check(Second.state(gi).rotation_charges==2,"holding fire for three seconds with unused charges cannot refill them")
	X.tick(gi,2.0);check(Second.state(gi).rotation_charges==0,"no early recharge")
	X.tick(gi,8.0);check(Second.state(gi).rotation_charges==3,"rearms after idle and interval")
	gi.set_deployed(false,false);X.tick(gi,.01);check(Second.state(gi).rotation_charges==0,"standing clears charges")
	var breath=ability(gi,"ap_battle_breather")
	var speed:float=gi.move_speed
	check(gi.use_ability(gi.skills.size()-1),"real W path starts breather")
	check(is_equal_approx(gi.move_speed,speed*(1+[.15,.2,.25,.3][level])),"breather speed table")
	check(not normal_shot(gi,target),"breather prevents actual firing")
	X.tick(gi,3.0);check(is_equal_approx(gi.move_speed,speed),"speed restores when timer expires")
	check(normal_shot(gi,target),"normal fire resumes after breather")
	breath.cd_left=0;gi.set_deployed(true,false)
	check(not X.cast(gi,breath,Vector2.INF) and breath.cd_left==0,"deployed breather rejects without spending cooldown")
	var guard=battle.spawn_unit("GGI","ally",Vector2(1050,1100));var anchor=ability(guard,"ap_anchor_pin")
	check(not X.cast(guard,anchor,Vector2.INF) and anchor.cd_left==0,"anchor requires deployment")
	guard.set_deployed(true,false)
	check(not X.cast(guard,anchor,Vector2.INF) and anchor.cd_left==0,"missing target spends no cooldown")
	var plane=battle.spawn_unit("JUMPJET","enemy",Vector2(1200,1100))
	guard.attack_target=plane
	check(not X.cast(guard,anchor,Vector2.INF) and anchor.cd_left==0,"air target spends no anchor cooldown")
	guard.attack_target=target;guard._cd_timer=5.0
	var before:float=target.hp
	check(guard.use_ability(guard.skills.size()-1) and missiles(guard).size()==1,"W immediately launches exactly one real missile")
	check(guard._cd_timer==5.0 and anchor.cd_left==26 and target.hp==before,"launch spends W only and damage waits for flight")
	check(not X.cast(guard,anchor,Vector2.INF) and missiles(guard).size()==1,"cooldown prevents duplicate launch")
	guard.set_deployed(false,false)
	fly_missiles(guard)
	check(target.hp<before and is_equal_approx(target.buff_value("electric_slow"),[.2,.25,.3,.35][level]),"in-flight skill still hits and slows after undeploy "+str(level))
	check(not Second.state(guard).has("anchor_arm"),"direct launch creates no pending arm state")
	var scout=battle.spawn_unit("SNIPE","ally",Vector2(1000,1200));var observer=ability(scout,"ap_observer_line")
	var fog=load("res://scripts/world/fog_of_war.gd").new()
	var sight:float=fog.vision_radius(scout);var reach:float=scout.attack_range
	check(X.cast(scout,observer,Vector2.INF),"observer starts")
	check(is_equal_approx(fog.vision_radius(scout),sight+[1,1.5,2,2.5][level]*55) and scout.attack_range==reach,"real fog radius increases without weapon range")
	scout.velocity=Vector2(30,0);X.tick(scout,.1)
	check(is_equal_approx(fog.vision_radius(scout),sight),"movement immediately ends observer")
	check(observer.cd_left>0,"movement does not refund observer W cooldown")
	scout.velocity=Vector2.ZERO;X.tick(scout,.1)
	check(is_equal_approx(fog.vision_radius(scout),sight),"stop after cancellation does not restore observation")
	observer.cd_left=0;scout.velocity=Vector2(30,0)
	check(not scout.use_ability(scout.skills.size()-1) and observer.cd_left==0 and Second.sight(scout)==0,"actual W rejects moving observer without spending cooldown")
	scout.velocity=Vector2.ZERO;X.tick(scout,.1)
	check(Second.sight(scout)==0 and observer.cd_left==0,"stop does not auto-execute rejected observation")
	check(scout.use_ability(scout.skills.size()-1) and observer.cd_left==24,"fresh stationary W succeeds after rejected moving cast")
	fog.free()
	var fv=battle.spawn_unit("FV","ally",Vector2(1100,1300));fv.passive=GameData.get_skill("ps_module_shell")
	var first=battle.spawn_unit("E1","ally",Vector2(1100,1300));var same=battle.spawn_unit("E1","ally",Vector2(1100,1300));var engineer=battle.spawn_unit("ENGINEER","ally",Vector2(1100,1300))
	crew(fv,first)
	check(Second.state(fv).has("module_shield"),"actual IFV refresh grants changed-mode shield")
	var shield:float=fv.max_hp*[.5,.7,.9,1.2][level]
	check(is_equal_approx(Second.state(fv).module_shield.hp,shield),"shield grows with max life and card rank")
	check(Second.state(fv).module_shield.left==30 and Second.state(fv).module_cd==40,"module holds 30 seconds with 40-second trigger interval")
	var hp:float=fv.hp;fv.receive_hit(shield*.5,"bullet",{},target)
	check(fv.hp==hp and Second.state(fv).module_shield.hp<shield,"real incoming damage consumes module shield before life")
	X.tick(fv,3.9);check(is_equal_approx(X.modify_reload(fv,10),10),"seat waits four seconds")
	X.tick(fv,.1);check(is_equal_approx(X.modify_reload(fv,10),10*(1-[.08,.11,.14,.17][level])),"seat shortens actual reload modifier")
	check(Second.state(fv).has("module_shield"),"module remains after seat matures")
	X.tick(fv,25.9);check(Second.state(fv).has("module_shield"),"module still active just before 30 seconds")
	X.tick(fv,.1);check(not Second.state(fv).has("module_shield"),"module expires at 30 seconds")
	check(Second.absorb(fv,50)==50,"expired shield does not absorb")
	crew(fv,same);check(Second.state(fv).crew_age==0 and not Second.state(fv).has("module_shield"),"same-type new passenger resets seat only")
	var module_cd:float=Second.state(fv).module_cd
	crew(fv,engineer);check(not Second.state(fv).has("module_shield") and Second.state(fv).module_cd==module_cd,"mode changes during cooldown cannot refill shield or reset cooldown")
	crew(fv,same)
	X.tick(fv,9.9);crew(fv,engineer)
	check(not Second.state(fv).has("module_shield"),"type change just before 40 seconds cannot rearm")
	crew(fv,same);X.tick(fv,.1);crew(fv,engineer)
	check(AlliedAbilities.is_repair_ifv(fv) and Second.state(fv).has("module_shield"),"repair mode receives new shield")
	check(is_equal_approx(Second.absorb(fv,shield+7),7) and not Second.state(fv).has("module_shield"),"shield overflow passes exact remaining damage")
	X.tick(fv,4);check(is_equal_approx(X.modify_reload(fv,10),10),"repair never receives reload benefit")
	crew(fv,same);X.tick(fv,2.5)
	var snapshot:Dictionary=BattleSaves.Snapshot.new().capture(battle)
	BattleSaves.Snapshot.new().restore(battle,snapshot)
	var restored:Unit
	for item in battle.units:
		if item.unit_id=="FV" and item.side=="ally":restored=item
	check(restored!=null and is_equal_approx(Second.state(restored).crew_age,2.5),"snapshot retains partial seat timer")
	check(is_same(Second.state(restored).crew,restored.logistics.passengers[0]),"snapshot relinks exact passenger identity")
	var cooldown:float=Second.state(restored).module_cd;X.tick(restored,.5)
	check(is_equal_approx(Second.state(restored).crew_age,3.0) and is_equal_approx(Second.state(restored).module_cd,cooldown-.5),"reload cannot refill timer or reset module cooldown")
	check(not restored.buff_entries().is_empty(),"live status includes seat and module timing")
	await finish()

func boundaries() -> void:
	start(MatchRules.EXTENDED)
	get_tree().paused=false
	BattleRequest.skirmish_config.fog_of_war=false
	BattleRequest.combat_context.unit_talents.FV={"steady_seat":3}
	var fv=battle.spawn_unit("FV","ally",Vector2(1400,1400));fv.passive=GameData.get_skill("ps_module_shell")
	var passenger=battle.spawn_unit("E1","ally",fv.position+Vector2(20,0))
	check(passenger.logistics.request_board(fv),"real boarding command accepted")
	passenger.logistics.tick(.1)
	check(passenger.embarked_in==fv and Second.state(fv).has("module_shield") and Second.state(fv).crew_age==0,"real boarding path starts module and seat")
	fv.velocity=Vector2(30,0);X.tick(fv,4)
	check(Second.state(fv).crew_age==4,"seat matures while carrier is moving")
	fv.velocity=Vector2.ZERO
	check(fv.logistics.request_unload(),"real unloading command accepted")
	fv.logistics.tick(.1)
	check(passenger.embarked_in==null and Second.state(fv).crew==null and Second.state(fv).crew_age==0,"real unloading clears seat identity and timer")
	for id in ["E2","GGI"]:
		var runner=battle.spawn_unit(id,"ally",Vector2(1500,1500))
		var ab=ability(runner,"ap_battle_breather");var initial:float=runner.move_speed
		check(X.cast(runner,ab,Vector2.INF),"shared breather cast "+id)
		X.tick(runner,3)
		check(is_equal_approx(runner.move_speed,initial),"shared breather expiry restores cached speed "+id)
	var scout=battle.spawn_unit("SNIPE","ally",Vector2(1100,1000));var observer=ability(scout,"ap_observer_line")
	var target=battle.spawn_unit("E2","enemy",Vector2(1200,1000))
	X.cast(scout,observer,Vector2.INF)
	check(normal_shot(scout,target) and Second.sight(scout)>0,"observer allows actual shot without ending sight")
	X.tick(scout,6)
	check(Second.sight(scout)==0,"observer expires while stationary")
	BattleRequest.combat_context.loadouts.GGI={"active":["ap_anchor_pin"],"passive":""}
	var guard=battle.spawn_unit("GGI","ally",Vector2(1000,1100));guard.set_deployed(true,false)
	var tank=battle.spawn_unit("HTNK","enemy",Vector2(1200,1100))
	guard.attack_target=tank;guard.attack_ordered=true;guard.hull_angle=0;guard.turret_angle=0;guard._cd_timer=0
	const Auto=preload("res://scripts/units/auto_w.gd")
	battle.production_technology.unlock(Auto.TECH,"ally")
	check(Auto.evaluate(guard) and missiles(guard).size()==1,"Auto W immediately fires through equipped slot and deployed weapon range")
	check(not Auto.evaluate(guard) and missiles(guard).size()==1,"Auto W cannot repeat during cooldown")
	check(guard.attack_target==tank and guard.attack_ordered and guard._cd_timer==0,"Auto W preserves target orders and normal reload")
	guard.ability_at(UnitSkillLayout.index(guard,1)).cd_left=0
	X.tick(guard,5)
	guard.attack_target=battle.spawn_unit("JUMPJET","enemy",Vector2(1200,1100))
	check(not Auto.evaluate(guard),"Auto W preserves anchor cooldown against aircraft")
	check(Auto.supported("ap_observer_line") and Auto.supported("ap_battle_breather") and Auto.supported("ap_prism_cross") and not Auto.hint("ap_prism_cross").is_empty(),"observation aimed cross and conditional retreat support auto")
	await finish()

func classic() -> void:
	start(MatchRules.RA2)
	var gi=battle.spawn_unit("E1","ally",Vector2(1100,1000));gi.set_deployed(true,false)
	BattleRequest.combat_context.unit_talents.E1={"position_rotation":3}
	X.tick(gi,20);check(not gi.special.has(Second.KEY),"classic ignores expansion talents")
	var ab=ability(gi,"ap_battle_breather");check(not X.cast(gi,ab,Vector2.INF),"classic cannot cast expansion W")
	await finish()

func revised_save_boundaries() -> void:
	start(MatchRules.EXTENDED);BattleRequest.skirmish_config.fog_of_war=false
	BattleRequest.combat_context.card_ranks.ap_anchor_pin=3
	BattleRequest.combat_context.card_ranks.ps_module_shell=3
	var guard:Unit=battle.spawn_unit("GGI","ally",Vector2(1100,1200));guard.set_deployed(true,false)
	var target:Unit=battle.spawn_unit("HTNK","enemy",Vector2(1250,1200));target.max_hp=100000;target.hp=100000
	var ab:=ability(guard,"ap_anchor_pin")
	guard.attack_target=target
	for pos:Vector2 in [Vector2(1120,1200),Vector2(2200,1200)]:
		target.position=pos
		check(not X.cast(guard,ab,Vector2.INF) and ab.cd_left==0,"anchor rejects minimum and maximum weapon range")
	target.position=Vector2(1250,1200);target.embarked_in=battle.spawn_unit("LCRF","enemy",Vector2(1300,1300))
	check(not X.cast(guard,ab,Vector2.INF) and ab.cd_left==0,"anchor rejects embarked target")
	target.embarked_in=null;guard._stun_timer=1
	check(not X.cast(guard,ab,Vector2.INF) and ab.cd_left==0,"stun prevents skill launch")
	guard._stun_timer=0
	check(guard.use_ability(guard.skills.size()-1),"launch anchor before in-flight save")
	var car:Unit=battle.spawn_unit("FV","ally",Vector2(1400,1400));car.passive=GameData.get_skill("ps_module_shell")
	crew(car,battle.spawn_unit("E1","ally",car.position));X.tick(car,12.0)
	var shield:float=Second.state(car).module_shield.hp
	Second.absorb(car,shield*.25)
	var snapshot:Dictionary=BattleSaves.Snapshot.new().capture(battle)
	BattleSaves.Snapshot.new().restore(battle,snapshot)
	for actor in battle.units:
		if actor.unit_id=="GGI":guard=actor
		elif actor.unit_id=="FV":car=actor
		elif actor.unit_id=="HTNK":target=actor
	check(missiles(guard).size()==1 and guard.skills.back().cd_left==26,"in-flight save restores one anchor and spent cooldown")
	guard.set_deployed(false,false);fly_missiles(guard)
	check(target.hp<100000 and is_equal_approx(target.buff_value("electric_slow"),.35),"restored missile applies captured slow once after undeploy")
	var hp:float=target.hp;fly_missiles(guard)
	check(target.hp==hp,"restored impact cannot duplicate damage")
	var state:=Second.state(car)
	check(is_equal_approx(state.module_shield.hp,shield*.75) and state.module_shield.left==18 and state.module_cd==28,"save preserves damaged shield pool duration and interval")
	crew(car,battle.spawn_unit("ENGINEER","ally",car.position))
	check(is_equal_approx(state.module_shield.hp,shield*.75) and state.module_shield.left==18 and state.module_cd==28,"changing mode after load cannot refill or extend live shield")
	X.tick(car,18)
	check(not state.has("module_shield") and state.module_cd==10,"restored shield expires with ten seconds of interval remaining")
	await finish()

func demos() -> void:
	var stage=preload("res://scripts/ui/faction_card_stage.gd").new();add_child(stage)
	for card:Dictionary in GameData.raw_docs["progression_expansion_2.json"].skills:
		for level in 4:
			stage.configure(card.id,0,"",level)
			for clock in [0.5,2.0,6.5]:
				stage.elapsed=clock;stage.sync_caster()
				check(stage.caster_model.actor!=null and stage.duration==Demo.duration(card.id),"real card demo timeline "+card.id+" "+str(level)+" "+str(clock))
				if card.id=="ap_anchor_pin":check(stage.caster_model.actor.is_deployed(),"immediate missile demo keeps deployed launcher")
	stage.free()
	for level in 4:
		check(Demo.sample("ps_module_shell",level,30.9).active and not Demo.sample("ps_module_shell",level,31.1).active and Demo.sample("ps_module_shell",level,41.1).active,"module preview covers full 30-second shield and 40-second interval")
		var quick:float=GameData.get_unit("E1").deployed_weapon.cooldown*(1-[.1,.15,.2,.25][level])
		check(Demo.sample("position_rotation",level,3.5).charges==3 and Demo.sample("position_rotation",level,4.001).charges==2 and Demo.sample("position_rotation",level,4+2*quick+.001).charges==0,"rotation demo counts down all three at actual rank reload boundaries")
		check(not Demo.sample("steady_seat",level,3.9).active and Demo.sample("steady_seat",level,4.1).active and not Demo.sample("steady_seat",level,7).active,"seat demo has wait active and passenger change")
	var preview=load("res://scripts/ui/unit_showcase.gd").new();add_child(preview)
	for id:String in {"position_rotation":"E1","steady_seat":"FV"}:
		preview.show_unit({"position_rotation":"E1","steady_seat":"FV"}[id],id,3)
		preview.age=3.5;preview._animate();check(preview.actor!=null and preview.demo_duration()==(24 if id=="steady_seat" else 54),"real talent preview "+id)
	preview.free()
