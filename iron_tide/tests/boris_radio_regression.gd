extends "res://tests/boris_command_regression.gd"
const Radio=preload("res://scripts/units/boris_radio.gd")

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
	await get_tree().process_frame
	await radio_purchases()
	await blast_lining()
	await controls()
	await maintained_control()
	await cover()
	await supply()
	await supply_expiry()
	await last_order()
	await last_order_limits()
	await final_boundaries()
	await shared_supply_and_cap()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	print("BORIS_RADIO_RESULT ",checks.size()," checks, ",failed," failed")
	get_tree().quit(0 if failed==0 else 1)

func radio_hero(level:int,command:int=0):
	var hero=setup_boris(3);hero.special.hero_survival_rank=level;hero.special.hero_command_rank=command
	return hero

func radio_purchases() -> void:
	MetaProgress.reset_save();MetaProgress.academy.hero_builds={"BORIS":5}
	var page=load("res://scripts/ui/hero_progression.gd").new();add_child(page);page.selected="BORIS"
	for level in 5:
		var price:int=[40,120,240,400,600][level]
		MetaProgress.currency.cores=price-1;page.refresh()
		check(A.hero_talent_cost("survival",level,"BORIS")==price and page.survival.disabled,"radio level quote and insufficient UI")
		check(not A.purchase(MetaProgress,"survival","BORIS") and MetaProgress.balance("cores")==price-1,"insufficient radio purchase cannot debit")
		MetaProgress.currency.cores=price;page.refresh();page.survival.pressed.emit()
		check(MetaProgress.balance("cores")==0 and MetaProgress.academy.hero_survival_ranks.BORIS==level+1,"real radio button buys one level")
		MetaProgress.load_save();check(MetaProgress.academy.hero_survival_ranks.BORIS==level+1,"radio level persists through profile reload")
	MetaProgress.currency.cores=1000;page.refresh()
	check(page.survival.disabled and not A.purchase(MetaProgress,"survival","BORIS") and MetaProgress.balance("cores")==1000,"radio five-level hard cap")
	page.talent_demo.talent.select(1);page.talent_demo._select_talent()
	check(page.talent_demo.levels.item_count==6 and page.survival_detail.text.contains("最后电令"),"all six radio descriptions and demo levels available")
	page.free();await get_tree().process_frame
	boot("BORIS");MetaProgress.academy.hero_survival_ranks.BORIS=0
	var hero=battle.spawn_unit("BORIS","ally",Vector2(1050,1000));A.promote(MetaProgress,battle,"BORIS",hero)
	check(Radio.rank(hero)==5,"defense rank freezes at match opening")
	await finish()

func blast_lining() -> void:
	for kind in ["explosive","shell","missile"]:
		var hero=radio_hero(1);hero.bonuses={"defense_bonus":1.0};hero.hp=hero.max_hp
		var source=robust_enemy("HTNK",hero.position+Vector2(100,0))
		hero.receive_hit(100000,kind,{},source)
		check(not hero._dead and is_equal_approx(hero.hp,hero.max_hp*.5),"ordinary lethal blast capped at half max HP: "+kind)
		hero.receive_hit(100000,kind,{},source)
		check(hero._dead,"half-health hero can still die to next blast")
		await finish()
	for entry in [["bullet",{}],["explosive",{"expansion_extra":true}],["explosive",{"force_execute":true}]]:
		var hero=radio_hero(1);var source=robust_enemy("HTNK",hero.position+Vector2(100,0))
		hero.receive_hit(100000,entry[0],entry[1],source)
		check(hero._dead,"lining never limits guns, scripted extras or executions")
		await finish()

func controls() -> void:
	var hero=radio_hero(2)
	hero.stun(6)
	check(is_equal_approx(hero._stun_timer,3) and is_equal_approx(hero.buffs.filter(func(b):return b.kind=="stun")[0].left,3),"native new stun and status duration are halved together")
	hero.stun(1)
	check(is_equal_approx(hero._stun_timer,3),"new shorter stun cannot halve or erase existing duration")
	hero._stun_timer=0;hero.clear_buff("stun");hero.stun(4,"freeze")
	check(is_equal_approx(hero._stun_timer,2) and hero.buffs.filter(func(b):return b.kind=="freeze")[0].debuff,"timed freeze through control entry is halved and labeled a debuff")
	hero.add_buff("attack",8,.3)
	check(hero.buffs.filter(func(b):return b.kind=="attack")[0].left==8,"ordinary positive buff duration is unchanged")
	var enemy=robust_enemy("CLEG",hero.position+Vector2(80,0));hero.special.temporal_by=enemy;hero.special.chrono_left=8.0
	Radio.tick(hero,1)
	check(AlliedAbilities.frozen(hero) and hero.special.temporal_by==enemy and hero.special.chrono_left==8,"maintained erasure and teleport recovery are not cleared or reduced by resistance tick")
	var normal=battle.spawn_unit("BORIS","ally",hero.position+Vector2(0,70));normal.stun(4)
	check(normal._stun_timer==4,"ordinary Boris does not gain hero control resistance")
	await finish()

func maintained_control() -> void:
	var hero=radio_hero(2);hero.max_hp=100000;hero.hp=hero.max_hp
	var enemy=robust_enemy("CLEG",hero.position+Vector2(80,0))
	enemy.attack_target=hero;enemy.attack_ordered=true;enemy.hull_angle=PI;enemy.turret_angle=PI;enemy._cd_timer=0
	check(enemy._try_fire_ready() and hero.special.get("temporal_by")==enemy,"real chrono weapon establishes maintained freeze on resistant Boris")
	check(AlliedAbilities.channel(enemy,2.1) and AlliedAbilities.frozen(hero) and enemy.special.get("temporal_target")==hero,"resistance does not free Boris after two seconds of maintained channel")
	check(float(enemy.special.get("temporal_work",0))>0 and not hero._try_fire_ready(),"maintained control advances erasure and blocks hero fire")
	enemy.order_stop();AlliedAbilities.channel(enemy,.01)
	check(not AlliedAbilities.frozen(hero) and not enemy.special.has("temporal_target"),"actual stop order releases maintained freeze instead of resistance timer")
	await finish()

func cover() -> void:
	var hero=radio_hero(4)
	var soldiers:Array=[]
	for offset in [35,65,95]:soldiers.append(battle.spawn_unit("E2","ally",hero.position+Vector2(0,offset)))
	var other_hero=battle.spawn_unit("E2","ally",hero.position+Vector2(0,20));other_hero.special.academy_hero="E2"
	var vehicle=battle.spawn_unit("HTNK","ally",hero.position+Vector2(25,0))
	var source=robust_enemy("E2",hero.position+Vector2(100,0))
	var ab:Ability=hero.ability_at(UnitSkillLayout.find(hero,BF.ACTIVE))
	check(BF.cast(hero,ab,hero.position+Vector2(150,0)),"real W begins radio cover")
	check(soldiers[0].special.has(Radio.SHIELD) and soldiers[1].special.has(Radio.SHIELD) and not soldiers[2].special.has(Radio.SHIELD),"nearest two ordinary infantry receive cover")
	check(not other_hero.special.has(Radio.SHIELD) and not vehicle.special.has(Radio.SHIELD) and not hero.special.has(Radio.SHIELD),"heroes, vehicles and caster are excluded")
	var soldier=soldiers[0];soldier.bonuses={"defense_bonus":1.0}
	var shield:float=soldier.max_hp*.1;var health:float=soldier.hp
	check(is_equal_approx(soldier.special[Radio.SHIELD].hp,shield) and soldier.special[Radio.SHIELD].left==4,"cover uses recipient max HP and four-second duration")
	soldier.receive_hit(shield*.5,"bullet",{},source)
	check(soldier.hp==health and soldier.special[Radio.SHIELD].hp<shield,"real damage first consumes cover shield")
	check(not Radio.entries(soldier).is_empty(),"remaining cover shield appears in status")
	hero.has_move_order=true;BF.tick(hero,.1)
	check(not BF.calling(hero) and hero.special[Radio.KEY].radio_cover_cd==20 and ab.cd_left==0,"canceling W retains cover cooldown without spending artillery cooldown")
	hero.has_move_order=false
	var main=building(hero.position+Vector2(150,0));dispatch(hero,main)
	check(soldier.special[Radio.SHIELD].hp<shield,"native designation during same cover cooldown cannot refill shield")
	var codec=BattleSaves.Snapshot.new();var snapshot:Dictionary=codec.capture(battle);codec.restore(battle,snapshot)
	check(codec.error.is_empty(),"partial cover and cooldown snapshot restores")
	var restored:Array=battle.units.filter(func(unit):return unit.special.has(Radio.SHIELD))
	check(restored.size()==2 and restored.any(func(unit):return unit.special[Radio.SHIELD].hp<unit.max_hp*.1),"remaining shield amount persists")
	for unit in restored:Radio.shield_tick(unit,4.01)
	check(restored.all(func(unit):return not unit.special.has(Radio.SHIELD)),"cover naturally expires after four seconds")
	await finish()

func supply() -> void:
	var hero=radio_hero(3);var main=building(Vector2(1250,1000));var jets:=dispatch(hero,main)
	check(battle.allied_state[Command.WAVES][0].supply_enabled and not battle.allied_state[Command.WAVES][0].relay_enabled,"defense-only build tracks supply without granting command relay")
	jets[0].special.strike_run.outbound=true;jets[0].position=jets[0].special.strike_run.origin;Soviet.fly_mig(jets[0],.01)
	check(battle.allied_state.get(Radio.PICKUPS,[]).is_empty(),"aborted aircraft exiting without bombing gives no supply")
	var source=robust_enemy("FLAKT",Vector2(1300,1100));jets[1].receive_hit(100000,"missile",{},source)
	check(jets[1]._dead,"Boris blast lining does not cap lethal missile damage to his MiG")
	check(battle.allied_state.get(Radio.PICKUPS,[]).is_empty(),"intercepted aircraft gives no supply")
	jets[2].position=main.position-Vector2(20,0);Soviet.fly_mig(jets[2],.01)
	check(battle.allied_state.get(Radio.PICKUPS,[]).is_empty(),"dropping bomb alone is insufficient")
	hero.position=Vector2(1300,1250)
	jets[2].position=jets[2].special.strike_run.origin;Soviet.fly_mig(jets[2],.01)
	check(battle.allied_state.get(Radio.PICKUPS,[]).size()==1,"normal exit after real bomb release leaves one supply")
	var item:Dictionary=battle.allied_state[Radio.PICKUPS][0]
	check(item.point.distance_to(hero.position)<=55 and not battle.in_water_world(item.point) and not battle.path_service.is_blocked(item.point),"supply uses current hero location and legal ground")
	hero.position=item.point;Radio.world_tick(battle,.1)
	check(battle.allied_state[Radio.PICKUPS].size()==1,"full-health owner cannot consume supply")
	hero.hp=hero.max_hp*.6;hero.position+=Vector2(100,0)
	var other=battle.spawn_unit("E2","ally",item.point);other.hp=other.max_hp*.5
	Radio.world_tick(battle,.1)
	check(other.hp==other.max_hp*.5 and battle.allied_state[Radio.PICKUPS].size()==1,"other infantry cannot take hero's supply")
	var codec=BattleSaves.Snapshot.new();var snapshot:Dictionary=codec.capture(battle)
	var path:=output_dir.path_join("radio-supply.bin");var file:=FileAccess.open(path,FileAccess.WRITE);file.store_var(snapshot,false);file.close();codec.restore(battle,FileAccess.open(path,FileAccess.READ).get_var(false))
	check(codec.error.is_empty() and battle.allied_state[Radio.PICKUPS].size()==1,"supply and once-per-wing flag survive binary restore")
	item=battle.allied_state[Radio.PICKUPS][0];hero=item.owner;hero.position=item.point
	Radio.world_tick(battle,.1)
	check(is_equal_approx(hero.hp,hero.max_hp*.75) and not battle.allied_state.has(Radio.PICKUPS),"owner contact heals exactly fifteen percent once")
	var jet=hero.special.airstrike_wing[-1];main=jet.special.strike_run.target
	jet.position=main.position-Vector2(20,0);Soviet.fly_mig(jet,.01);jet.position=jet.special.strike_run.origin;Soviet.fly_mig(jet,.01)
	check(battle.allied_state.get(Radio.PICKUPS,[]).is_empty(),"later aircraft in restored wing cannot drop another consumed supply")
	await finish()

func supply_expiry() -> void:
	var hero=radio_hero(3);var main=building(Vector2(1250,1000));var jets:=dispatch(hero,main)
	jets[0].position=main.position-Vector2(20,0);Soviet.fly_mig(jets[0],.01);jets[0].position=jets[0].special.strike_run.origin;Soviet.fly_mig(jets[0],.01)
	Radio.world_tick(battle,10.01)
	check(not battle.allied_state.has(Radio.PICKUPS),"unused supply expires after ten seconds")
	await finish()

func last_order() -> void:
	var hero=radio_hero(5);earn(hero,3)
	var source=robust_enemy("HTNK",hero.position+Vector2(100,0));var bystander=robust_enemy("E2",source.position+Vector2(20,0))
	var ab:Ability=hero.ability_at(UnitSkillLayout.find(hero,BF.ACTIVE));ab.cd_left=17
	var raw:=float(hero._weapon_for_target(null).damage)*1.5
	var expected:=CombatMath.with_offense(raw,hero.bonuses)
	hero.hp=hero.max_hp*.2;hero.receive_hit(100000,"explosive",{},source)
	check(hero._dead and battle.allied_state.get(Radio.EVENTS,[]).size()==1,"real low-health combat death emits one last order without resurrection")
	var event:Dictionary=battle.allied_state[Radio.EVENTS][0]
	check(is_equal_approx(event.raw,raw) and is_equal_approx(event.damage,expected) and event.left==1.5,"order snapshots one hundred fifty percent ordinary attack without receipt bonus")
	check(ab.cd_left==17 and BF.preview(hero).count==3,"last order neither spends receipts nor changes W cooldown")
	var point:Vector2=event.point;source.position+=Vector2(150,0)
	Radio.world_tick(battle,1.49)
	check(bystander.hp==100000,"full fixed warning delay before blast")
	var codec=BattleSaves.Snapshot.new();var snapshot:Dictionary=codec.capture(battle)
	var path:=output_dir.path_join("last-order.bin");var file:=FileAccess.open(path,FileAccess.WRITE);file.store_var(snapshot,false);file.close();codec.restore(battle,FileAccess.open(path,FileAccess.READ).get_var(false))
	check(codec.error.is_empty() and battle.allied_state[Radio.EVENTS][0].point==point,"death warning fixed point and remaining delay survive binary restore")
	Radio.world_tick(battle,.011)
	var hit=battle.units.filter(func(unit):return unit.unit_id=="E2" and unit.side=="enemy")[0]
	var escaped=battle.units.filter(func(unit):return unit.unit_id=="HTNK" and unit.side=="enemy")[0]
	check(hit.hp<100000 and escaped.hp==100000 and not battle.allied_state.has(Radio.EVENTS),"fixed blast damages remaining enemy while original attacker can escape")
	var hp:float=hit.hp;Radio.world_tick(battle,2)
	check(hit.hp==hp,"completed last order never replays")
	await finish()

func last_order_limits() -> void:
	for reason in ["distant","noncombat","embarked","eliminated","air","neutral"]:
		var hero=radio_hero(5);var source=robust_enemy("ORCA" if reason=="air" else "E2",hero.position+Vector2(400 if reason=="distant" else 90,0))
		if reason=="air":source.logistics.air_lift=1.0
		if reason=="neutral":source.side="neutral"
		if reason=="eliminated":hero.special.house_eliminated=true
		if reason in ["noncombat","embarked"]:
			hero.receive_hit(1,"bullet",{},source)
			if reason=="embarked":hero.embarked_in=battle.spawn_unit("FV","ally",hero.position)
			hero.hp=0;hero._die(source)
		else:hero.receive_hit(100000,"bullet",{},source)
		check(battle.allied_state.get(Radio.EVENTS,[]).is_empty(),"last order excludes "+reason)
		await finish()

func final_boundaries() -> void:
	var hero=radio_hero(5)
	hero.skills.clear();hero.passive={}
	var source=robust_enemy("E2",hero.position+Vector2(90,0))
	hero.receive_hit(100000,"bullet",{},source)
	check(battle.allied_state.get(Radio.EVENTS,[]).size()==1,"last order works with neither contract card equipped")
	battle.allied_state.get_or_add("defeated_houses",{}).ally=true
	Radio.world_tick(battle,2)
	check(not battle.allied_state.has(Radio.EVENTS) and source.hp==100000,"owner house elimination cancels pending order")
	await finish()

	hero=radio_hero(5);source=robust_enemy("E2",hero.position+Vector2(90,0))
	var fog=preload("res://scripts/world/fog_of_war.gd").new();battle.add_child(fog);fog.setup(battle);battle.fog=fog
	fog.visible_cells.ally.fill(0);fog.explored_cells.ally.fill(1)
	hero.receive_hit(100000,"bullet",{},source)
	check(not battle.allied_state.has(Radio.EVENTS),"invisible last damage source cannot be targeted")
	await finish()
	hero=radio_hero(4);var soldier=battle.spawn_unit("E2","ally",hero.position+Vector2(35,0))
	var main=building(hero.position+Vector2(150,0));hero.attack_target=main;hero.attack_ordered=true;hero.hull_angle=0;hero._cd_timer=0
	check(hero._try_fire_ready() and soldier.special.has(Radio.SHIELD),"real native designation starts cover immediately")
	soldier.side="enemy";Radio.shield_tick(soldier,.01)
	check(not soldier.special.has(Radio.SHIELD),"captured recipient cannot keep radio cover")
	await finish()
	hero=radio_hero(2);BattleRequest.rules_mode=MatchRules.RA2;hero.stun(4)
	check(hero._stun_timer==4 and Radio.before_damage(hero,100000,"explosive",{})==100000,"classic mode excludes control resistance and blast lining")
	await finish()
	hero=radio_hero(3);main=building(Vector2(1250,1000));var jets:=dispatch(hero,main)
	var blocked:=Rect2(hero.position-Vector2(100,100),Vector2(200,200))
	battle.path_service.set_water([blocked]);battle.water_rects.assign([blocked])
	jets[0].position=main.position-Vector2(20,0);Soviet.fly_mig(jets[0],.01);jets[0].position=jets[0].special.strike_run.origin;Soviet.fly_mig(jets[0],.01)
	check(battle.allied_state.get(Radio.PICKUPS,[]).is_empty(),"no legal ground near hero cannot place supply on water")
	await finish()

func shared_supply_and_cap() -> void:
	var hero=radio_hero(3,5);var main=building(Vector2(1250,1000));building(Vector2(1350,1000))
	var jets:=dispatch(hero,main)
	check(jets.size()==6,"defense supply cooperates with six-aircraft command wing")
	for index in [4,0]:
		var jet=jets[index];jet.position=jet.special.strike_run.target.position-Vector2(20,0);Soviet.fly_mig(jet,.01)
		jet.position=jet.special.strike_run.origin;Soviet.fly_mig(jet,.01)
		check(battle.allied_state.get(Radio.PICKUPS,[]).size()==1,"secondary and main exits share one supply opportunity")
	await finish()
	hero=radio_hero(5);BattleRequest.combat_context.erase("house_training")
	BattleRequest.combat_context.final_damage_cap=2.25;BattleRequest.combat_context.final_damage_threshold=2.0
	hero.bonuses.attack_bonus=10.0
	var source=robust_enemy("HTNK",hero.position+Vector2(100,0));source.bonuses.defense_bonus=2.0
	hero.hp=1;hero.receive_hit(100000,"bullet",{},source)
	var event:Dictionary=battle.allied_state[Radio.EVENTS][0]
	var reference:float=event.raw*.65*float(event.bonus.get("veteran_attack",1))
	var curve:=2.0+.25*log(33.0)/(1.0+log(33.0))
	Radio.world_tick(battle,1.5)
	check(is_equal_approx(100000-source.hp,Ra2Damage.quantize(reference*curve/2)),"last order follows ordinary growth cap and armor/defense once",100000-source.hp)
	await finish()
