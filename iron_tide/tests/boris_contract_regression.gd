extends "res://tests/tanya_contract_regression.gd"
const BF=preload("res://scripts/units/boris_fire_control.gd")
const Soviet=preload("res://scripts/units/soviet_specials.gd")

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
	await get_tree().process_frame
	for rank in 4:
		await corridor(rank)
		await mig(rank)
	await channels()
	await receipts()
	await resume()
	await mig_resume()
	await fog_and_boundaries()
	await standalone_and_quest_limits()
	await capped_damage()
	await rewards()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	print("BORIS_CONTRACT_RESULT ",checks.size()," checks, ",failed," failed")
	get_tree().quit(0 if failed==0 else 1)

func setup_boris(rank:int=0):
	MetaProgress.reset_save();MetaProgress.academy.hero_builds={"BORIS":5}
	MetaProgress.unlocked_skills.assign([BF.ACTIVE,BF.PASSIVE])
	MetaProgress.academy.levels={BF.ACTIVE:rank,BF.PASSIVE:rank}
	Loadouts.equip(MetaProgress,"BORIS","active",BF.ACTIVE)
	Loadouts.equip(MetaProgress,"BORIS","passive",BF.PASSIVE)
	Pool.grant(MetaProgress,"boris_contract")
	boot("BORIS")
	var hero=battle.spawn_unit("BORIS","ally",Vector2(1050,1000));A.promote(MetaProgress,battle,"BORIS",hero)
	return hero

func earn(hero,count:int) -> void:
	var target=robust_enemy("HTNK",hero.position+Vector2(80,0))
	var primary:Dictionary=hero._weapon_for_target(null)
	for i in count:
		if i>0:BF.tick(hero,2)
		target.receive_hit(1,"bullet",{"impact_weapon":primary.ra2_weapon_id},hero)
	battle.units.erase(target);target.free()

func corridor(rank:int) -> void:
	var hero=setup_boris(rank)
	var ab:Ability=hero.ability_at(UnitSkillLayout.find(hero,BF.ACTIVE))
	for id in [BF.ACTIVE,BF.PASSIVE]:
		check(GameData.get_skill(id).rarity=="ultimate" and not A.skill_description(GameData.get_skill(id),rank).contains("{"),"Boris card rarity and resolved rank "+id+str(rank))
	earn(hero,3)
	var at:=Vector2(1200,1000)
	var targets:Array=[]
	for point in BF.points(hero,at):targets.append(robust_enemy("E2",point))
	var heavy=robust_enemy("HTNK",at+Vector2(0,10))
	var light=robust_enemy("FV",at+Vector2(0,-10))
	var expanded=robust_enemy("E2",at+Vector2(0,60))
	var outside=robust_enemy("E2",at+Vector2(0,98))
	var air=robust_enemy("ORCA",at);air.logistics.air_lift=1.0
	var friendly=battle.spawn_unit("E2","ally",at);var hp:float=friendly.hp
	var raw:=CombatMath.with_offense(float(hero._weapon_for_target(null).damage)*[.8,1.,1.2,1.5][rank],hero.bonuses)
	var damage:float=raw*(1+3*[.04,.06,.08,.1][rank])
	check(hero.use_ability(UnitSkillLayout.find(hero,BF.ACTIVE),at),"real W slot begins static call "+str(rank))
	check(ab.cd_left==0 and BF.preview(hero).count==3 and not battle.allied_state.has(BF.EVENTS),"channel has no early cooldown, receipt spend or event")
	BF.tick(hero,.59);check(BF.calling(hero),"channel persists before .6 seconds")
	BF.tick(hero,.011)
	var event:Dictionary=battle.allied_state[BF.EVENTS][0]
	check(is_equal_approx(ab.cd_left,[55.,50.,45.,40.][rank]) and BF.preview(hero).count==0,"success spends all receipts and rank cooldown")
	check(is_equal_approx(event.damage,damage) and is_equal_approx(event.radius,55*(1+3*[.1,.15,.2,.25][rank])),"one firepower snapshot and receipt radius rank "+str(rank))
	hero.bonuses.attack_bonus=20
	BF.world_tick(battle,1.19);check(targets[0].hp==100000,"warning lasts full 1.2 seconds after success")
	BF.world_tick(battle,.011)
	check(is_equal_approx(100000-targets[0].hp,Ra2Damage.quantize(damage)) and targets[1].hp==100000,"first fixed coordinate explodes exactly once with frozen damage")
	check(is_equal_approx(100000-heavy.hp,Ra2Damage.quantize(damage*.65)) and is_equal_approx(100000-light.hp,Ra2Damage.quantize(damage*.8)),"W uses specified heavy and light armor once")
	check(expanded.hp<100000 and outside.hp==100000 and air.hp==100000 and friendly.hp==hp,"receipt expands blast with exact radius, excludes air and friends")
	BF.world_tick(battle,.8);check(targets[1].hp<100000 and targets[2].hp==100000,"second coordinate follows .8 seconds later")
	BF.world_tick(battle,.8);check(targets[2].hp<100000 and not battle.allied_state.has(BF.EVENTS),"third explosion retires event without refreshing native airstrike")
	check(not hero.special.has("airstrike_cd") and Q.progress(battle,"BORIS").get("sorties",0)==0,"W is separate from native MiG cooldown and sortie tasks")
	await finish()

func mig(rank:int) -> void:
	var hero=setup_boris(rank);earn(hero,3)
	var target=battle._place_building("NAPOWR","enemy",Vector2(1200,1000),true)
	target._buildup_play=-1;target.max_hp=100000;target.hp=100000;target.bonuses={"defense_bonus":1.0}
	hero.attack_target=target;hero.attack_ordered=true
	Soviet.designate(hero,target)
	var jets:Array=hero.special.airstrike_wing
	check(jets.size()==4 and BF.preview(hero).count==0,"elite native four-jet departure consumes receipts once "+str(rank))
	var ab:Ability=hero.ability_at(UnitSkillLayout.find(hero,BF.ACTIVE))
	check(BF.cast(hero,ab,hero.position+Vector2(120,0)),"W call can begin while native wing is travelling")
	check(not hero._try_fire_ready(),"static artillery channel pauses ordinary firing")
	Soviet._advance_mark(target,.1)
	check(target.special.has("airstrike_mark") and not jets[0].special.strike_run.outbound,"W channel does not invalidate existing native MiG guidance")
	hero.has_move_order=true;BF.tick(hero,.1);hero.has_move_order=false
	var jet=jets[0]
	check(is_equal_approx(jet.special.strike_run.boris_receipt.damage,1+3*[.04,.06,.08,.1][rank]),"each jet retains shared receipt snapshot")
	BF.tick(hero,2);earn(hero,1)
	check(BF.preview(hero).count==1 and int(jet.special.strike_run.boris_receipt.count)==3,"later rifle receipts never change the outgoing wing")
	jet.position=target.position-Vector2(20,0);Soviet.fly_mig(jet,.01)
	var shots:Array=battle.projectiles_root.get_children().filter(func(shot):return shot is Projectile and shot.attacker_bonus.get("boris_mig",false))
	var gun:Dictionary=jet._active_weapon()
	check(shots.size()==int(gun.burst) and Q.progress(battle,"BORIS").get("sorties",0)==1,"actual native burst counts one flown sortie")
	var radius:=Ra2Damage.cells(str(gun.ra2_warhead))*55
	check(is_equal_approx(shots[0].aoe,radius*(1+3*[.1,.15,.2,.25][rank])) if radius>0 else shots[0].aoe==0,"native blast radius expands only if original warhead has spread")
	var extra=robust_enemy("E2",target.position+Vector2(24,0))
	var outside=robust_enemy("E2",target.position+Vector2(42,0))
	var splash:float=CombatMath.with_offense(Ra2Damage.target_damage(float(gun.damage),str(gun.ra2_warhead),extra,24.0/(1+3*[.1,.15,.2,.25][rank])),jet.bonuses)
	var expected:float=CombatMath.with_offense(Ra2Damage.target_damage(float(gun.damage),str(gun.ra2_warhead),target,0),jet.bonuses)*(1+3*[.04,.06,.08,.1][rank])
	shots[0]._explode()
	check(is_equal_approx(100000-target.hp,Ra2Damage.quantize(expected)),"one native bomb applies building receipt bonus once",100000-target.hp)
	check(is_equal_approx(100000-extra.hp,Ra2Damage.quantize(splash)) and outside.hp==100000,"expanded native blast reaches extra ground target but building damage bonus does not spread to infantry")
	for member in jets:
		member.position=target.position-Vector2(20,0);Soviet.fly_mig(member,.01)
	check(Q.progress(battle,"BORIS").get("sorties",0)==1,"remaining wing cannot count another sortie")
	var before:float=hero.special.airstrike_cd;Soviet.advance_sortie_reload(hero,10)
	check(hero.special.airstrike_cd==before,"living outbound aircraft still occupy native recharge")
	var surviving=battle.projectiles_root.get_children().filter(func(shot):return shot is Projectile and not shot.is_queued_for_deletion() and shot.attacker_bonus.get("boris_mig",false))
	var killer=surviving[0];var source=killer.shooter()
	battle.units.erase(source);source.free();target.hp=1
	killer._explode()
	check(Q.progress(battle,"BORIS").second==1,"native bomb still credits building task after aircraft object is freed")
	await finish()

func channels() -> void:
	var hero=setup_boris(0);earn(hero,3)
	var ab:Ability=hero.ability_at(UnitSkillLayout.find(hero,BF.ACTIVE))
	var at:Vector2=hero.position+Vector2(150,0)
	check(not BF.cast(hero,ab,hero.position+Vector2(331,0)),"call rejects start beyond six cells")
	for kind in ["move","stun","freeze","embark"]:
		check(BF.cast(hero,ab,at),"begin interruption case "+kind)
		match kind:
			"move":hero.has_move_order=true
			"stun":hero._stun_timer=1.0
			"freeze":hero.special.chrono_left=1.0
			"embark":hero.embarked_in=battle.spawn_unit("FV","ally",hero.position)
		BF.tick(hero,.7)
		check(not BF.calling(hero) and ab.cd_left==0 and BF.preview(hero).count==3,"interrupted call preserves cooldown and receipts "+kind)
		hero.has_move_order=false;hero._stun_timer=0;hero.special.erase("chrono_left");hero.embarked_in=null
	check(not battle.allied_state.has(BF.EVENTS),"cancelled calls create no delayed blasts")
	await finish()

func receipts() -> void:
	var hero=setup_boris(3);var enemy=robust_enemy("HTNK",hero.position+Vector2(100,0))
	var gun:Dictionary=hero._weapon_for_target(null)
	for i in 4:enemy.receive_hit(1,"bullet",{"impact_weapon":gun.ra2_weapon_id},hero)
	check(BF.preview(hero).count==1,"two-second receipt interval rejects rapid hits")
	BF.tick(hero,2);enemy.receive_hit(1,"bullet",{"impact_weapon":gun.ra2_weapon_id,"expansion_extra":true},hero)
	check(BF.preview(hero).count==1,"extra attacks cannot produce receipts")
	for key in ["expansion_scatter","equipment_secondary"]:
		enemy.receive_hit(1,"bullet",{"impact_weapon":gun.ra2_weapon_id,key:true},hero)
		check(BF.preview(hero).count==1,"secondary rifle packet cannot farm receipt "+key)
	earn(hero,5);check(BF.preview(hero).count==3,"receipts cap at three")
	BF.tick(hero,11.9);check(BF.preview(hero).count==3,"receipt expiry waits twelve seconds without damage exchange")
	var hp:float=hero.hp
	hero.receive_hit(10,"shell",{},enemy)
	check(hero.hp<hp,"incoming exchange fixture deals real health damage")
	BF.tick(hero,11.9)
	check(BF.preview(hero).count==3,"actual hostile damage renews combat quiet timer")
	BF.tick(hero,.11);check(BF.preview(hero).count==0,"twelve quiet seconds clear all receipts")
	await finish()

func mig_resume() -> void:
	var hero=setup_boris(3);earn(hero,3)
	var target=battle._place_building("NAPOWR","enemy",Vector2(1200,1000),true)
	target._buildup_play=-1;target.max_hp=100000;target.hp=100000
	hero.attack_target=target;hero.attack_ordered=true;Soviet.designate(hero,target)
	var jet=hero.special.airstrike_wing[0];jet.position=target.position-Vector2(20,0);Soviet.fly_mig(jet,.01)
	var codec=BattleSaves.Snapshot.new();var snapshot:Dictionary=codec.capture(battle)
	var file:=FileAccess.open(output_dir.path_join("mig-wing.bin"),FileAccess.WRITE);file.store_var(snapshot,false);file.close()
	file=FileAccess.open(output_dir.path_join("mig-wing.bin"),FileAccess.READ);snapshot=file.get_var(false);file.close();codec.restore(battle,snapshot)
	for unit in battle.units:
		if unit.special.get("academy_hero")=="BORIS":hero=unit
	var wing:Array=hero.special.airstrike_wing;jet=wing[1];target=jet.special.strike_run.target
	check(codec.error.is_empty() and wing.size()==4 and wing[0].special.strike_run.boris_counted and BF.preview(hero).count==0,"disk restores whole wing, receipt spend and sortie count flags")
	check(is_equal_approx(jet.special.strike_run.boris_receipt.radius,1.75),"inbound aircraft retains frozen receipt radius after restore")
	jet.position=target.position-Vector2(20,0);Soviet.fly_mig(jet,.01)
	check(Q.progress(battle,"BORIS").get("sorties",0)==1,"remaining aircraft after load cannot duplicate sortie progress")
	await finish()

func fog_and_boundaries() -> void:
	var hero=setup_boris(3);earn(hero,3)
	var ab:Ability=hero.ability_at(UnitSkillLayout.find(hero,BF.ACTIVE))
	var at:Vector2=hero.position+Vector2(150,0)
	var fog=preload("res://scripts/world/fog_of_war.gd").new();battle.add_child(fog);fog.setup(battle);battle.fog=fog
	fog.visible_cells.ally.fill(0);fog.explored_cells.ally.fill(0)
	check(not BF.cast(hero,ab,at),"unseen corridor start cannot cast")
	fog.visible_cells.ally[fog._index(at)]=1;fog.explored_cells.ally[fog._index(at)]=1
	check(not BF.cast(hero,ab,at),"visible start is insufficient when distant fixed points are unexplored")
	for point in BF.points(hero,at):fog.explored_cells.ally[fog._index(point)]=1
	check(BF.cast(hero,ab,at),"explored but not currently visible later points are legal")
	fog.visible_cells.ally.fill(0);BF.tick(hero,.601)
	check(ab.cd_left>0 and battle.allied_state.has(BF.EVENTS),"fog returning during valid call does not retarget confirmed coordinates")
	check(not fog.is_visible_at("ally",at),"corridor call never adds sight or reveals fog")
	await finish()
	hero=setup_boris(0)
	var ordinary=battle.spawn_unit("BORIS","ally",hero.position+Vector2(0,80))
	ab=hero.ability_at(UnitSkillLayout.find(hero,BF.ACTIVE))
	check(not BF.ready(ordinary,ab),"ordinary Boris cannot use hero W")
	var enemy=robust_enemy("E2",hero.position+Vector2(100,0));hero.attack_target=enemy;hero.hull_angle=0;hero._cd_timer=0
	check(hero._try_fire_ready(),"native Boris rifle fires through real ordinary weapon route")
	for shot in battle.projectiles_root.get_children():
		if shot is Projectile and shot.target==enemy:shot._explode()
	check(BF.preview(hero).count==1,"real native rifle packet earns a receipt")
	BF.dispatched(hero,[]);check(BF.preview(hero).count==1,"failed empty aircraft dispatch cannot consume receipt")
	var victim=battle.spawn_unit("E2","enemy",hero.position+Vector2(90,0));victim.special.expansion_temporary={"kind":"test"}
	victim.receive_hit(100000,"bullet",{"impact_weapon":hero._weapon_for_target(null).ra2_weapon_id},hero)
	check(Q.progress(battle,"BORIS").first==0,"temporary victims cannot farm rifle contract")
	await finish()

func resume() -> void:
	var hero=setup_boris(3);earn(hero,3)
	var at:Vector2=hero.position+Vector2(150,0)
	BF.cast(hero,hero.ability_at(UnitSkillLayout.find(hero,BF.ACTIVE)),at);BF.tick(hero,.2)
	var codec=BattleSaves.Snapshot.new();var snapshot:Dictionary=codec.capture(battle);codec.restore(battle,snapshot)
	for unit in battle.units:
		if unit.special.get("academy_hero")=="BORIS":hero=unit
	check(codec.error.is_empty() and BF.calling(hero) and BF.preview(hero).count==3,"mid-call snapshot preserves unspent receipts and channel")
	BF.tick(hero,.401)
	var victim=robust_enemy("E2",at+Vector2(110,0))
	BF.world_tick(battle,1.2)
	snapshot=codec.capture(battle)
	var file:=FileAccess.open(output_dir.path_join("corridor.bin"),FileAccess.WRITE);file.store_var(snapshot,false);file.close()
	file=FileAccess.open(output_dir.path_join("corridor.bin"),FileAccess.READ);snapshot=file.get_var(false);file.close();codec.restore(battle,snapshot)
	for unit in battle.units:
		if unit.special.get("academy_hero")=="BORIS":hero=unit
		if unit.unit_id=="E2" and unit.side=="enemy":victim=unit
	var event:Dictionary=battle.allied_state[BF.EVENTS][0]
	check(codec.error.is_empty() and event.index==1 and BF.preview(hero).count==0,"disk save retains next fixed explosion and consumed receipts")
	var expected:=Ra2Damage.quantize(float(event.damage));hero._die();battle.units.erase(hero);hero.free()
	BF.world_tick(battle,.8)
	check(is_equal_approx(100000-victim.hp,expected),"confirmed corridor survives owner death and object removal with frozen damage")
	battle.allied_state.get_or_add("defeated_houses",{}).ally=true;BF.world_tick(battle,1)
	check(not battle.allied_state.has(BF.EVENTS),"eliminated owner cancels remaining corridor")
	await finish()

func rewards() -> void:
	var hero=setup_boris(0)
	MetaProgress.unlocked_skills.clear()
	var p:=Q.progress(battle,"BORIS")
	var enemy=battle.spawn_unit("E2","enemy",hero.position+Vector2(100,0))
	enemy.receive_hit(100000,"bullet",{"impact_weapon":hero._weapon_for_target(null).ra2_weapon_id},hero)
	check(p.first==1,"actual native rifle kill advances Boris infantry task")
	p.first=60;p.second=10;p.sorties=1
	Q.settle(MetaProgress,battle,true)
	check(not MetaProgress.academy.hero_contracts.BORIS.complete,"one actual sortie cannot complete survival victory task")
	await finish();boot("BORIS")
	hero=battle.spawn_unit("BORIS","ally",Vector2(1050,1000));A.promote(MetaProgress,battle,"BORIS",hero)
	p=Q.progress(battle,"BORIS");p.sorties=2
	Q.settle(MetaProgress,battle,true)
	check(MetaProgress.academy.hero_contracts.BORIS.complete and BF.ACTIVE in MetaProgress.unlocked_skills and BF.PASSIVE in MetaProgress.unlocked_skills,"second qualifying match awards both contract cards")
	var count:=MetaProgress.unlocked_skills.size();Q.settle(MetaProgress,battle,true)
	check(MetaProgress.unlocked_skills.size()==count,"contract settlement cannot award cards twice")
	MetaProgress.save();MetaProgress.load_save()
	check(MetaProgress.academy.hero_contracts.BORIS.complete and Pool.candidates(MetaProgress).all(func(row):return row.hero_id!="BORIS"),"completed contract persists and leaves draw pool")
	for id in [BF.ACTIVE,BF.PASSIVE]:
		for level in 3:
			MetaProgress.currency.cores=[100,230,360][level]
			check(A.purchase(MetaProgress,"level",id) and MetaProgress.balance("cores")==0,"Boris contract rank purchase exact cost "+id+str(level))
	var panel=preload("res://scripts/ui/expansion_contract_panel.gd").new();add_child(panel);panel.refresh("BORIS")
	check(panel.visible and panel.find_child("QuickEquip_"+BF.ACTIVE,true,false)!=null,"Boris contract UI exposes real reward equipment")
	panel.free();await finish()

func standalone_and_quest_limits() -> void:
	var hero=setup_boris(3)
	hero.passive={}
	var at:Vector2=hero.position+Vector2(150,0)
	check(BF.cast(hero,hero.ability_at(UnitSkillLayout.find(hero,BF.ACTIVE)),at),"W alone starts without receipt passive")
	BF.tick(hero,.601)
	var event:Dictionary=battle.allied_state[BF.EVENTS][0]
	check(event.receipt.count==0 and event.radius==55,"W alone retains ordinary radius without passive bonus")
	await finish()
	hero=setup_boris(0);hero.skills.clear();earn(hero,2)
	var target=battle._place_building("NAPOWR","enemy",Vector2(1200,1000),true);target._buildup_play=-1
	hero.attack_target=target;hero.attack_ordered=true;Soviet.designate(hero,target)
	check(BF.preview(hero).count==0 and hero.special.airstrike_wing[0].special.strike_run.boris_receipt.count==2,"passive alone powers native MiGs without contract W")
	var plain=battle.spawn_unit("BPLN","ally",Vector2(300,300));plain.special.strike_run={"boris_hero":true,"boris_receipt":{"damage":1.3,"radius":1.75}}
	var gun:Dictionary=plain._active_weapon();var shot:=Projectile.new();shot.setup(plain.position,target,gun,1,{},"ally",plain);BF.prepare_mig(shot,plain)
	check(Ra2Damage.cells(str(gun.ra2_warhead))==0 and shot.aoe==0 and not shot.splinters.has("spread_scale"),"original non-elite single-target MiG warhead never acquires splash")
	shot.free()
	BattleRequest.combat_context.expedition={"stage":5}
	var jet=hero.special.airstrike_wing[0];jet.position=target.position-Vector2(20,0);Soviet.fly_mig(jet,.01)
	var victim=battle.spawn_unit("E2","enemy",hero.position+Vector2(90,0));victim.receive_hit(100000,"bullet",{"impact_weapon":hero._weapon_for_target(null).ra2_weapon_id},hero)
	check(Q.progress(battle,"BORIS").first==0 and Q.progress(battle,"BORIS").get("sorties",0)==0,"expedition combat does not advance permanent Boris tasks")
	await finish()
	for condition in ["loss","dead","easy"]:
		hero=setup_boris(0);var p:=Q.progress(battle,"BORIS");p.first=60;p.second=10;p.sorties=2
		if condition=="dead":hero._die()
		if condition=="easy":
			BattleRequest.skirmish_config.difficulty=0
			for house in BattleRequest.skirmish_config.get("houses",[]):house.difficulty=0
		Q.settle(MetaProgress,battle,condition!="loss")
		check(not MetaProgress.academy.hero_contracts.BORIS.complete,"win task rejects nonqualifying match "+condition)
		check(MetaProgress.academy.hero_contracts.BORIS.first==60 and MetaProgress.academy.hero_contracts.BORIS.second==10,"cumulative tasks still settle on nonqualifying match "+condition)
		await finish()
	MetaProgress.reset_save();MetaProgress.academy.hero_builds={"BORIS":5};boot("BORIS")
	Pool.grant(MetaProgress,"boris_contract")
	hero=battle.spawn_unit("BORIS","ally",Vector2(1050,1000));A.promote(MetaProgress,battle,"BORIS",hero)
	var enemy=battle.spawn_unit("E2","enemy",hero.position+Vector2(90,0));enemy.receive_hit(100000,"bullet",{"impact_weapon":hero._weapon_for_target(null).ra2_weapon_id},hero)
	check(Q.progress(battle,"BORIS").first==0,"contract opened during a match cannot backfill its task progress")
	await finish();boot("BORIS",MatchRules.RA2)
	hero=battle.spawn_unit("BORIS","ally",Vector2(1050,1000));A.promote(MetaProgress,battle,"BORIS",hero)
	check(not BF.active(hero),"classic mode never enables Boris hero contract rules")
	await finish()

func capped_damage() -> void:
	var hero=setup_boris(3);earn(hero,3)
	BattleRequest.combat_context.erase("house_training")
	BattleRequest.combat_context.final_damage_cap=2.25;BattleRequest.combat_context.final_damage_threshold=2.0
	hero.bonuses.attack_bonus=10.0
	var at:Vector2=hero.position+Vector2(150,0)
	var victim=robust_enemy("HTNK",at);victim.bonuses.defense_bonus=2.0
	BF.cast(hero,hero.ability_at(UnitSkillLayout.find(hero,BF.ACTIVE)),at);BF.tick(hero,.601)
	var event:Dictionary=battle.allied_state[BF.EVENTS][0]
	var reference:float=event.raw*.65*float(event.bonus.get("veteran_attack",1))
	var curve:=2.0+.25*log(45.0)/(1.0+log(45.0))
	BF.world_tick(battle,1.2)
	check(is_equal_approx(100000-victim.hp,Ra2Damage.quantize(reference*curve/2)) ,"W offense plus receipt passes through growth cap and defense once",100000-victim.hp)
	await finish()
	hero=setup_boris(3);earn(hero,3)
	BattleRequest.combat_context.erase("house_training")
	BattleRequest.combat_context.final_damage_cap=2.25;BattleRequest.combat_context.final_damage_threshold=2.0
	var target=battle._place_building("NAPOWR","enemy",Vector2(1200,1000),true)
	target._buildup_play=-1;target.hp=100000;target.max_hp=100000;target.bonuses={"defense_bonus":2.0}
	hero.attack_target=target;hero.attack_ordered=true;Soviet.designate(hero,target)
	var jet=hero.special.airstrike_wing[0];jet.bonuses.attack_bonus=10.0
	jet.position=target.position-Vector2(20,0);Soviet.fly_mig(jet,.01)
	var gun:Dictionary=jet._active_weapon()
	reference=Ra2Damage.target_damage(float(gun.damage),str(gun.ra2_warhead),target,0)*float(jet.bonuses.get("veteran_attack",1))
	var shot=battle.projectiles_root.get_children().filter(func(node):return node is Projectile and node.attacker_bonus.get("boris_mig",false))[0]
	shot._explode()
	check(is_equal_approx(100000-target.hp,Ra2Damage.quantize(reference*curve/2)),"native MiG receipt cannot bypass final damage curve",100000-target.hp)
	await finish()
