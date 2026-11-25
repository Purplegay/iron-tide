extends "res://tests/peregrine_base_regression.gd"
const PC=preload("res://scripts/units/peregrine_cards.gd")
const PQ=preload("res://scripts/rules/peregrine_contracts.gd")
const Q=preload("res://scripts/rules/expansion_contracts.gd")
const Pool=preload("res://scripts/rules/hero_contract_pool.gd")

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
	await get_tree().process_frame
	for rank in 4:
		await damage(rank)
		await rearm(rank)
	await locks_and_resume()
	await eligibility()
	await native_tasks_and_rewards()
	await quest_boundaries()
	await final_cap()
	await auto_and_air_defense()
	await partial_resume()
	await near_full_resume()
	await invalid_locks()
	await settlement_exclusions()
	await ordinary_cycle_separation()
	await direct_kill_credit()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	print("PEREGRINE_CARDS_RESULT ",checks.size()," checks, ",failed," failed")
	get_tree().quit(0 if failed==0 else 1)

func cards_hero(rank:=0,with_cards:=true):
	MetaProgress.reset_save();Pool.grant(MetaProgress,"peregrine_contract")
	if with_cards:
		MetaProgress.unlocked_skills.assign([PC.ACTIVE,PC.PASSIVE])
		MetaProgress.academy.levels={PC.ACTIVE:rank,PC.PASSIVE:rank}
		Loadouts.equip(MetaProgress,"ORCA","active",PC.ACTIVE)
		Loadouts.equip(MetaProgress,"ORCA","passive",PC.PASSIVE)
	boot("TANY")
	var hero=battle.spawn_unit("ORCA","ally",Vector2(1000,1000));P.promote(MetaProgress,battle,hero)
	return hero

func near_full_resume() -> void:
	var hero=cards_hero();var target=victim("HTNK",hero.position+Vector2(150,0))
	var shield:float=hero.special[P.KEY].rearm_shield
	hero.logistics.consume_volley(target);P.tick(hero,7.6)
	check(hero.logistics.ammo==3 and is_equal_approx(hero.special[P.KEY].progress,.95),"baseline reload reaches actual 95 percent before checkpoint")
	var codec=BattleSaves.Snapshot.new();var snapshot:Dictionary=codec.capture(battle)
	var path:=output_dir.path_join("reload-95-percent.bin")
	var file=FileAccess.open(path,FileAccess.WRITE);file.store_var(snapshot,false);file.close()
	file=FileAccess.open(path,FileAccess.READ);snapshot=file.get_var(false);file.close();codec.restore(battle,snapshot);hero=get_hero()
	check(codec.error.is_empty() and is_equal_approx(hero.special[P.KEY].progress,.95) and hero.logistics.ammo==3,"binary restore preserves the last five percent and missing round")
	P.tick(hero,.39)
	check(hero.logistics.ammo==3 and is_equal_approx(hero.special[P.KEY].rearm_shield,shield),"restored final fraction cannot complete or add shield early")
	P.tick(hero,.011)
	check(hero.logistics.ammo==4 and hero.special[P.KEY].cycle==1 and is_equal_approx(hero.special[P.KEY].rearm_shield,shield*2),"last fraction completes exactly one cycle and one shield gain")
	P.tick(hero,10)
	check(hero.special[P.KEY].cycle==1 and is_equal_approx(hero.special[P.KEY].rearm_shield,shield*2),"full idle after restore cannot replay completion")
	await finish()

func victim(id:String,at:Vector2):
	var unit=battle.spawn_unit(id,"enemy",at)
	unit.hp=100000;unit.max_hp=100000;unit.bonuses.defense_bonus=1.0
	return unit

func ability(hero):
	return hero.ability_at(UnitSkillLayout.find(hero,PC.ACTIVE))

func damage(rank:int) -> void:
	var hero=cards_hero(rank)
	for id in [PC.ACTIVE,PC.PASSIVE]:
		check(GameData.get_skill(id).rarity=="ultimate" and not A.skill_description(GameData.get_skill(id),rank).contains("{"),"ultimate rank description resolves "+id+str(rank))
	var main=victim("HTNK",hero.position+Vector2(150,0))
	var secondary=victim("E2",main.position+Vector2(0,30))
	var outside=victim("E2",main.position+Vector2(0,55*[1.,1.2,1.4,1.6][rank]+1))
	var air=victim("ORCA",main.position);air.logistics.air_lift=1
	var friendly=battle.spawn_unit("E2","ally",main.position);var hp:float=friendly.hp
	var raw:=CombatMath.with_offense(float(hero._weapon_for_target(null).damage)*[.4,.5,.6,.75][rank],hero.bonuses)
	var child_count:int=battle.projectiles_root.get_child_count()
	check(hero.use_ability(UnitSkillLayout.find(hero,PC.ACTIVE),main.position),"actual W fires at legal selected target "+str(rank))
	check(hero.logistics.ammo==2 and is_equal_approx(ability(hero).cd_left,[38.,35.,32.,29.][rank]),"four missiles spend two shared ammo and one rank cooldown")
	check(battle.allied_state[PC.EVENTS][0].missiles.size()==4 and battle.projectiles_root.get_child_count()==child_count,"all four launched records exist without attackable projectile actors")
	PC.world_tick(battle,.1)
	check(main.hp==100000 and battle.allied_state[PC.EVENTS][0].missiles[0].point!=hero.position and battle.allied_state[PC.EVENTS][0].missiles[1].point==hero.position,"two-wing spread precedes spaced tracking")
	hero.bonuses.attack_bonus=30;hero.stun(5)
	PC.world_tick(battle,3)
	check(is_equal_approx(100000-main.hp,4*Ra2Damage.quantize(raw*.65)),"main takes four full snapshots and no duplicate half splash",100000-main.hp)
	check(is_equal_approx(100000-secondary.hp,4*Ra2Damage.quantize(raw*.5)),"secondary takes four half-damage explosions")
	check(outside.hp==100000 and air.hp==100000 and friendly.hp==hp,"exact blast boundary excludes air and friendly units")
	check(not battle.allied_state.has(PC.EVENTS) and hero.special[P.KEY].hits and not hero.special[P.KEY].get("normal_hit",false),"completed W retires records and marks valid combat but not ordinary refill task")
	await finish()

func rearm(rank:int) -> void:
	var hero=cards_hero(rank)
	var chunk:float=hero.max_hp*[.04,.06,.08,.1][rank]
	var cap:float=hero.max_hp*[.2,.3,.4,.5][rank]
	check(is_equal_approx(hero.special[P.KEY].rearm_shield,chunk),"initial full magazine grants one shield portion "+str(rank))
	P.tick(hero,100)
	check(is_equal_approx(hero.special[P.KEY].rearm_shield,chunk),"full idle never adds more shield")
	hero.bonuses.defense_bonus=1;hero.bonuses.veteran_defense=1
	var source=victim("E2",hero.position+Vector2(150,0));var hp:float=hero.hp
	hero.receive_hit(2,"bullet",{},source)
	check(hero.hp==hp and is_equal_approx(hero.special[P.KEY].rearm_shield,chunk-2),"shield consumes actual incoming damage before health")
	hero.logistics.consume_volley(source);P.tick(hero,7.9)
	check(is_equal_approx(hero.special[P.KEY].rearm_shield,chunk-2),"partial refill never adds shield")
	P.tick(hero,.10001)
	check(is_equal_approx(hero.special[P.KEY].rearm_shield,chunk*2-2),"true fill adds onto remaining shield")
	for i in 8:hero.logistics.consume_volley(source);P.tick(hero,8)
	check(is_equal_approx(hero.special[P.KEY].rearm_shield,cap),"repeated real fills stop at rank shield cap")
	var pad=airport();battle.power_low=false
	var plane=battle.spawn_unit("ORCA","ally",pad.position,pad)
	check(PC.parked(hero),"real own parked aircraft activates linkage")
	hero.logistics.consume_volley(source);P.tick(hero,4*(1-[.1,.15,.2,.25][rank]))
	check(is_equal_approx(hero.special[P.KEY].progress,.5),"airport linkage shortens hero interval at rank "+str(rank))
	var parked_progress:float=plane.logistics.reload_elapsed
	plane.logistics.air_state="flying";plane.logistics.air_lift=1
	P.tick(hero,2)
	check(is_equal_approx(hero.special[P.KEY].progress,.75) and plane.logistics.reload_elapsed==parked_progress,"departure cancels linkage immediately, preserves fraction, never speeds parked plane")
	plane.logistics.air_state="parked";plane.logistics.air_lift=0
	battle.power_low=true
	check(not PC.parked(hero) and PC.reload_factor(hero)==1,"power loss cancels airport linkage")
	battle.power_low=false;plane.side="enemy"
	check(not PC.parked(hero),"another owner parked plane cannot grant linkage")
	plane.side="ally";plane.special.expansion_temporary={"kind":"test"}
	check(not PC.parked(hero),"temporary aircraft cannot grant linkage")
	plane.special.erase("expansion_temporary");plane.logistics.air_lift=.2
	check(not PC.parked(hero),"descending but not settled plane cannot grant linkage")
	plane.logistics.air_lift=0;pad._die()
	check(not PC.parked(hero),"destroyed airport cancels linkage immediately")
	hero._die()
	check(not hero.special[P.KEY].has("rearm_shield"),"actual death clears rearm shield")
	await finish()

func locks_and_resume() -> void:
	var hero=cards_hero(3);var target=victim("HTNK",hero.position+Vector2(150,0))
	PC.cast(hero,ability(hero),target.position)
	PC.world_tick(battle,.31)
	target.position+=Vector2(90,70);target.special.echo_cloaked=true
	var fog=load("res://scripts/world/fog_of_war.gd").new();battle.add_child(fog);fog.setup(battle);battle.fog=fog
	hero.sight=0
	for side in fog.visible_cells:fog.visible_cells[side].fill(0)
	PC.world_tick(battle,.2)
	check(battle.allied_state[PC.EVENTS][0].missiles[0].last==target.position,"existing lock tracks movement and cloak without visibility requirement")
	var codec=BattleSaves.Snapshot.new();var snapshot:Dictionary=codec.capture(battle)
	var file=FileAccess.open(output_dir.path_join("hunters.bin"),FileAccess.WRITE);file.store_var(snapshot,false);file.close()
	file=FileAccess.open(output_dir.path_join("hunters.bin"),FileAccess.READ);snapshot=file.get_var(false);file.close();codec.restore(battle,snapshot)
	hero=get_hero();target=battle.units.filter(func(u):return u.side=="enemy" and u.unit_id=="HTNK")[0]
	check(codec.error.is_empty() and hero.logistics.ammo==2 and battle.allied_state[PC.EVENTS][0].missiles.size()==4,"binary save retains in-flight lock and spent ammo")
	var shield:float=hero.special[P.KEY].rearm_shield
	check(is_equal_approx(shield,hero.max_hp*.1),"loading does not grant extra initial shield")
	hero._die();battle.units.erase(hero);hero.free()
	PC.world_tick(battle,2)
	check(target.hp<100000 and not battle.allied_state.has(PC.EVENTS),"four released missiles survive hero death and object removal")
	await finish()
	hero=cards_hero();target=victim("HTNK",hero.position+Vector2(150,0))
	var other=victim("E2",target.position+Vector2(0,20));var at:Vector2=target.position
	PC.cast(hero,ability(hero),at);PC.world_tick(battle,.1)
	target.side="ally";target.position+=Vector2(500,0)
	PC.world_tick(battle,3)
	check(target.hp==100000 and other.hp<100000,"captured target breaks lock, missiles fall at last valid point without retarget")
	await finish()

func eligibility() -> void:
	var hero=cards_hero();var target=victim("HTNK",hero.position+Vector2(150,0))
	var ab=ability(hero)
	for kind in ["ammo","stun","freeze","far","immune","concealed"]:
		match kind:
			"ammo":hero.logistics.ammo=1
			"stun":hero._stun_timer=1
			"freeze":hero.special.chrono_left=1
			"far":target.position=hero.position+Vector2(hero.attack_range+30,0)
			"immune":target.special.iron_left=1
			"concealed":target.special.echo_cloaked=true
		var ammo:int=hero.logistics.ammo
		check(not PC.cast(hero,ab,target.position) and hero.logistics.ammo==ammo and ab.cd_left==0,"invalid cast leaves ammo and cooldown untouched "+kind)
		hero.logistics.ammo=4;hero._stun_timer=0;hero.special.erase("chrono_left");target.special.erase("iron_left");target.special.erase("echo_cloaked");target.position=hero.position+Vector2(150,0)
	var normal=battle.spawn_unit("ORCA","ally",hero.position+Vector2(0,100))
	check(not PC.ready(normal,ab),"ordinary ORCA cannot use hero-only W")
	hero.passive={};hero.special[P.KEY].erase("rearm_shield")
	check(PC.cast(hero,ab,target.position),"W works without dedicated passive")
	P.tick(hero,16)
	check(hero.logistics.ammo==4 and not hero.special[P.KEY].has("rearm_shield"),"W-only build auto reloads without passive shield")
	battle.allied_state.get_or_add("defeated_houses",{}).ally=true;PC.world_tick(battle,5)
	check(not battle.allied_state.has(PC.EVENTS) and target.hp==100000,"owner faction elimination cancels outstanding missiles")
	await finish()

func normal_shot(hero,target) -> void:
	hero.attack_target=target;hero.attack_ordered=true;hero.has_move_order=false;hero._cd_timer=0;hero._burst_left=0;hero.hull_angle=hero.position.direction_to(target.position).angle();hero.turret_angle=hero.hull_angle
	check(hero._try_fire_ready(),"native ordinary hero shot accepted")
	for shot in battle.projectiles_root.get_children():
		if shot is Projectile and is_same(shot.shooter(),hero) and not shot._detonated:shot._explode()

func native_tasks_and_rewards() -> void:
	var hero=cards_hero(0,false)
	var progress:Dictionary=Q.progress(battle,"ORCA")
	check(progress.first==0 and progress.second==0,"initial full magazine has no contract progress")
	for i in 20:
		var target=victim("HTNK",hero.position+Vector2(150,0));target.hp=1
		normal_shot(hero,target);P.tick(hero,8)
	check(progress.first==20 and progress.second==20 and progress.targets.size()==20,"native attacks and real fills complete tasks without either reward card")
	Q.settle(MetaProgress,battle,true)
	check(MetaProgress.academy.hero_contracts.ORCA.complete and PC.ACTIVE in MetaProgress.unlocked_skills and PC.PASSIVE in MetaProgress.unlocked_skills,"normal victory and surviving native hero unlock both cards")
	var before:int=MetaProgress.unlocked_skills.size();Q.settle(MetaProgress,battle,true)
	check(MetaProgress.unlocked_skills.size()==before,"duplicate settlement cannot duplicate rewards")
	MetaProgress.save();MetaProgress.load_save()
	check(MetaProgress.academy.hero_contracts.ORCA.complete and Pool.candidates(MetaProgress).all(func(row):return row.hero_id!="ORCA"),"completed contract survives disk and leaves shared draw pool")
	for id in [PC.ACTIVE,PC.PASSIVE]:
		for rank in 3:
			MetaProgress.currency.cores=[100,230,360][rank]
			check(A.purchase(MetaProgress,"level",id) and MetaProgress.balance("cores")==0,"actual ultimate card upgrade price "+id+str(rank))
	var panel=preload("res://scripts/ui/expansion_contract_panel.gd").new();add_child(panel);panel.refresh("ORCA")
	check(panel.visible and panel.find_child("QuickEquip_"+PC.ACTIVE,true,false)!=null,"contract UI exposes live reward quick equipment")
	panel.free();await finish()

func quest_boundaries() -> void:
	var hero=cards_hero();var target=victim("HTNK",hero.position+Vector2(150,0))
	PC.cast(hero,ability(hero),target.position);PC.world_tick(battle,3);P.tick(hero,16)
	check(Q.progress(battle,"ORCA").second==0 and Q.progress(battle,"ORCA").targets.size()==1,"W contact counts unique target but never substitutes ordinary-hit refill task")
	for i in 3:PQ.contact(battle,"ally",target)
	check(Q.progress(battle,"ORCA").targets.size()==1,"same target cannot inflate different-target objective")
	var codec=BattleSaves.Snapshot.new();var snapshot:Dictionary=codec.capture(battle);codec.restore(battle,snapshot)
	target=battle.units.filter(func(u):return u.unit_id=="HTNK" and u.side=="enemy")[0]
	PQ.contact(battle,"ally",target)
	check(codec.error.is_empty() and Q.progress(battle,"ORCA").targets.size()==1,"stable target identity survives save and restore")
	hero=get_hero();hero.logistics.spend_ammo(1,false);P.tick(hero,8)
	check(Q.progress(battle,"ORCA").second==0,"empty-ground ammo consumption cannot earn valid refill")
	Q.progress(battle,"ORCA").first=20;Q.progress(battle,"ORCA").second=12
	Q.settle(MetaProgress,battle,true)
	check(not MetaProgress.academy.hero_contracts.ORCA.complete,"single target cannot qualify three-target victory")
	await finish()
	MetaProgress.reset_save();MetaProgress.academy.card_shards=500
	check(Pool.purchase(MetaProgress,"peregrine_contract") and MetaProgress.academy.card_shards==0,"real contract exchange costs 500 shared shards")
	check(not Pool.purchase(MetaProgress,"peregrine_contract"),"owned contract cannot be exchanged twice")
	check(is_equal_approx(Pool.chance(),.0035),"adding hero preserves shared 0.35 percent pool chance")

func final_cap() -> void:
	var hero=cards_hero(3)
	BattleRequest.combat_context.final_damage_cap=2.25;BattleRequest.combat_context.final_damage_threshold=2.0
	hero.bonuses.attack_bonus=10
	var target=victim("HTNK",hero.position+Vector2(150,0));target.bonuses.defense_bonus=2
	PC.cast(hero,ability(hero),target.position)
	var event:Dictionary=battle.allied_state[PC.EVENTS][0]
	var reference:float=event.raw*.65*float(event.bonus.get("veteran_attack",1))
	var curve:=2.0+.25*log(33.0)/(1.0+log(33.0))
	PC.world_tick(battle,3)
	check(is_equal_approx(100000-target.hp,4*Ra2Damage.quantize(reference*curve/2)),"W snapshots offense and applies ordinary damage cap/armor/defense once")
	await finish()

func auto_and_air_defense() -> void:
	const Auto=preload("res://scripts/units/auto_w.gd")
	var hero=cards_hero();var target=victim("HTNK",hero.position+Vector2(150,0))
	hero.attack_target=target;hero.attack_ordered=true
	check(not Auto.evaluate(hero),"automatic W needs actual researched technology")
	battle.production_technology.unlock(Auto.TECH,"ally")
	battle.allied_state.auto_w_preferences={"ORCA":true}
	check(not Auto.evaluate(hero),"paused game cannot auto cast")
	get_tree().paused=false
	hero.logistics.ammo=1
	check(not Auto.evaluate(hero) and ability(hero).cd_left==0,"automatic W preserves insufficient magazine")
	hero.logistics.ammo=4;target.position+=Vector2(1000,0)
	check(not Auto.evaluate(hero) and not hero.has_move_order,"automatic W cannot invent pursuit of out-of-range target")
	target.position=hero.position+Vector2(150,0)
	hero.fire_stance="none";hero.attack_ordered=false
	check(not Auto.evaluate(hero),"automatic W respects hold fire")
	hero.fire_stance="free";hero.attack_ordered=true
	hero.has_move_order=true;hero.move_target=hero.position+Vector2(0,200)
	check(Auto.evaluate(hero) and hero.has_move_order and hero.move_target==hero.position+Vector2(0,200),"automatic W preserves existing movement and current target",{"enabled":Auto.enabled(hero),"ready":hero.ability_ready(UnitSkillLayout.find(hero,PC.ACTIVE)),"target":PC.target_in_range(hero,target),"paused":battle.paused,"ended":battle.ended,"tree_paused":get_tree().paused,"slot":battle.cast_slot,"mode":battle.command_mode,"cd":ability(hero).cd_left})
	var aa=victim("FLAKT",hero.position+Vector2(120,0))
	aa.attack_target=hero;aa.attack_ordered=true;aa._cd_timer=0;aa.hull_angle=PI;aa.turret_angle=PI
	var before:float=hero.hp+float(hero.special[P.KEY].get("rearm_shield",0))
	check(aa._try_fire_ready(),"real native anti-air still fires at the hero body")
	for shot in battle.projectiles_root.get_children():
		if shot is Projectile and is_same(shot.shooter(),aa) and not shot._detonated:shot._explode()
	check(hero.hp+float(hero.special[P.KEY].get("rearm_shield",0))<before,"non-interceptable W does not make hero immune to anti-air")
	check(battle.allied_state.get(PC.EVENTS,[]).size()==1 and battle.allied_state[PC.EVENTS][0].missiles.size()==4,"anti-air attack leaves four independent W missiles intact")
	get_tree().paused=true
	await finish()

func partial_resume() -> void:
	var hero=cards_hero();var target=victim("HTNK",hero.position+Vector2(150,0))
	PC.cast(hero,ability(hero),target.position)
	for i in 15:
		PC.world_tick(battle,.05)
		if battle.allied_state[PC.EVENTS][0].missiles.size()<4:break
	var remaining:int=battle.allied_state[PC.EVENTS][0].missiles.size()
	check(remaining>0 and remaining<4,"save boundary occurs after some but not all missiles hit")
	var raw:float=battle.allied_state[PC.EVENTS][0].damage*.65
	var pad=airport();battle.power_low=false;battle.spawn_unit("ORCA","ally",pad.position,pad)
	P.tick(hero,3.6)
	var shield:float=hero.special[P.KEY].rearm_shield
	check(PC.absorb(hero,-5)==-5 and hero.special[P.KEY].rearm_shield==shield,"healing cannot manufacture rearm shield")
	PC.absorb(hero,1)
	var codec=BattleSaves.Snapshot.new();var snap:Dictionary=codec.capture(battle)
	var file=FileAccess.open(output_dir.path_join("partial.bin"),FileAccess.WRITE);file.store_var(snap,false);file.close()
	file=FileAccess.open(output_dir.path_join("partial.bin"),FileAccess.READ);snap=file.get_var(false);file.close();codec.restore(battle,snap)
	hero=get_hero();target=battle.units.filter(func(u):return u.side=="enemy" and u.unit_id=="HTNK")[0]
	var hp:float=target.hp
	check(codec.error.is_empty() and is_equal_approx(hero.special[P.KEY].progress,.5) and is_equal_approx(hero.special[P.KEY].rearm_shield,shield-1),"binary recovery preserves partial reload and damaged shield")
	PC.world_tick(battle,3)
	check(is_equal_approx(hp-target.hp,remaining*Ra2Damage.quantize(raw)),"recovery executes only remaining missiles, never replaying impacts")
	check(PC.parked(hero),"restored airport membership restores real linkage")
	P.tick(hero,3.6)
	check(hero.logistics.ammo==3 and is_zero_approx(hero.special[P.KEY].progress),"saved half interval completes exactly one round")
	var second=airport();battle.spawn_unit("ORCA","ally",second.position,second)
	check(is_equal_approx(PC.reload_factor(hero),.9),"multiple parked aircraft never stack reload reduction")
	await finish()

func invalid_locks() -> void:
	for cause in ["death","embarked","immune","removed"]:
		var hero=cards_hero();var target=victim("HTNK",hero.position+Vector2(150,0))
		var other=victim("E2",target.position+Vector2(0,20));var point:Vector2=target.position
		PC.cast(hero,ability(hero),point);PC.world_tick(battle,.1)
		match cause:
			"death":target._die()
			"embarked":target.embarked_in=hero
			"immune":target.special.iron_left=5
			"removed":battle.units.erase(target);target.free()
		PC.world_tick(battle,.1)
		check(battle.allied_state[PC.EVENTS][0].missiles.all(func(m):return m.target==null and m.last==point),"invalid lock keeps final point and cannot select a replacement "+cause)
		PC.world_tick(battle,3)
		check(other.hp<100000 and not battle.allied_state.has(PC.EVENTS),"invalid lock still produces one half-damage area per missile "+cause)
		if cause=="embarked":target.embarked_in=null
		await finish()

func settlement_exclusions() -> void:
	for cause in ["easy","loss","dead","expedition","no_opening_contract"]:
		var hero=cards_hero(0,false)
		var p:Dictionary=Q.progress(battle,"ORCA");p.first=20;p.second=12;p.targets={"a":true,"b":true,"c":true}
		match cause:
			"easy":
				BattleRequest.skirmish_config.difficulty=0
				for house in BattleRequest.skirmish_config.get("houses",[]):house.difficulty=0
			"dead":hero._die()
			"expedition":BattleRequest.combat_context.expedition={"stage":5}
			"no_opening_contract":BattleRequest.combat_context.hero_contracts={}
		Q.settle(MetaProgress,battle,cause!="loss")
		check(not MetaProgress.academy.hero_contracts.ORCA.complete and PC.ACTIVE not in MetaProgress.unlocked_skills,"contract cannot be completed by excluded settlement "+cause)
		if cause in ["expedition","no_opening_contract"]:
			check(MetaProgress.academy.hero_contracts.ORCA.first==0 and MetaProgress.academy.hero_contracts.ORCA.second==0,"excluded mode also grants no cumulative tasks "+cause)
		await finish()

func ordinary_cycle_separation() -> void:
	const Aircraft=preload("res://scripts/units/expansion_2_aircraft.gd")
	var hero=cards_hero();var target=victim("HTNK",hero.position+Vector2(150,0))
	BattleRequest.combat_context.get_or_add("unit_talents",{}).ORCA={Aircraft.FIRST:3}
	BattleRequest.combat_context.get_or_add("card_ranks",{})[Aircraft.LAST]=3
	hero.passive=GameData.get_skill(Aircraft.LAST).duplicate(true)
	PC.cast(hero,ability(hero),target.position)
	check(not Aircraft.state(hero).air_first and Aircraft.state(hero).air_last and not Aircraft.state(hero).has("air_pending"),"real W spends first qualification without receiving ordinary bonus")
	var packet:Dictionary=battle.allied_state[PC.EVENTS][0].bonus
	check(not packet.has("expansion_air_cycle") and is_equal_approx(packet.attack_bonus,hero.bonuses.attack_bonus),"all four W missiles snapshot no first or last bonus")
	PC.world_tick(battle,3);ability(hero).cd_left=0
	PC.cast(hero,ability(hero),target.position)
	check(hero.logistics.ammo==0 and not Aircraft.state(hero).air_last and not Aircraft.state(hero).has("air_pending"),"W emptying shared magazine consumes last qualification without extra attack")
	PC.world_tick(battle,3);P.tick(hero,8)
	normal_shot(hero,target)
	check(not Aircraft.state(hero).air_shot.first and not Aircraft.state(hero).air_shot.last and Aircraft.state(hero).air_shot.damage==0,"single partial refill cannot restore either ordinary qualification")
	P.tick(hero,32)
	check(Aircraft.state(hero).air_first and Aircraft.state(hero).air_last,"only real full magazine restores both ordinary qualifications")
	await finish()

func direct_kill_credit() -> void:
	var hero=cards_hero();var main=victim("HTNK",hero.position+Vector2(150,0));main.hp=1
	var splash=victim("HTNK",main.position+Vector2(0,20));splash.hp=1
	PC.cast(hero,ability(hero),main.position)
	hero._die();battle.units.erase(hero);hero.free()
	PC.world_tick(battle,3)
	check(not AlliedAbilities.alive(main) and not AlliedAbilities.alive(splash) and Q.progress(battle,"ORCA").first==1,"released W credits direct combat vehicle kill after owner removal but never splash kill")
	await finish()
	const Aircraft=preload("res://scripts/units/expansion_2_aircraft.gd")
	hero=cards_hero();main=victim("HTNK",hero.position+Vector2(150,0))
	hero.passive=GameData.get_skill(Aircraft.BURN).duplicate(true)
	for i in 3:normal_shot(hero,main)
	check(battle.allied_state.get(Aircraft.FIELDS,[]).size()==1,"actual third normal missile creates ordinary burning field on hero")
	splash=victim("HTNK",main.position+Vector2(0,20));splash.hp=1
	Aircraft.world_tick(battle,.5)
	check(not AlliedAbilities.alive(splash) and Q.progress(battle,"ORCA").first==0,"burning field cannot inherit direct missile contract kill credit")
	await finish()
