extends "res://tests/progression_expansion_2_regression.gd"
const Armor=preload("res://scripts/units/expansion_2_armor.gd")
const Native=preload("res://scripts/units/soviet_advanced.gd")

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
	await get_tree().process_frame
	MetaProgress.reset_save();await purchases()
	for level in 4:
		await archive(level);await armor_rules(level);await split(level,false);await split(level,true)
	await rocket_boundaries();await armor_boundaries();await saved_flight();await split_boundaries();await classic_armor()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	print("EXPANSION_2_ARMOR_RESULT ",checks.size()," checks, ",failed," failed")
	get_tree().quit(0 if failed==0 else 1)

func setup_rank(level:int) -> void:
	start(MatchRules.EXTENDED);BattleRequest.skirmish_config.fog_of_war=false
	BattleRequest.combat_context.card_ranks[Armor.ARCHIVE]=level;BattleRequest.combat_context.card_ranks[Armor.ARMOR]=level
	BattleRequest.combat_context.loadouts.V3={"active":[],"passive":Armor.ARCHIVE}
	BattleRequest.combat_context.loadouts.APOC={"active":[],"passive":Armor.ARMOR}
	BattleRequest.combat_context.unit_talents.V3={"launch_bulkhead":level}
	BattleRequest.combat_context.unit_talents.APOC={"split_hunt":level}

func actor(id:String,side:String,at:Vector2) -> Unit:
	var u:Unit=battle.spawn_unit(id,side,at);u.max_hp=100000;u.hp=100000;return u

func structure(at:Vector2) -> Building:
	var b:Building=battle._place_building("GAPOWR","enemy",at,true);b._buildup_play=-1;b.hp=100000;b.max_hp=100000;return b

func ready_launcher(unit) -> void:
	unit.special.missile_racks=[0.0];unit.special.launcher_rof=0.0;unit._cd_timer=0.0

func launch(unit,target):
	ready_launcher(unit)
	check(normal_shot(unit,target),"native launcher starts ordinary fire")
	return unit.special.get("raising_missile_0")

func leave_rack(missile) -> void:
	for step in 200:
		if missile.special.flight.phase!="rack":return
		Native.fly(missile,.1)
	check(false,"native rocket leaves rack before twenty seconds")

func impact(missile) -> void:
	# Put the real native flight at its terminal segment; its actual blast code remains authoritative.
	missile.special.flight.phase="dive";missile.special.flight.speed=10000
	missile.position=missile.special.flight.aim+Vector2(1,0);missile.logistics.air_lift=.1
	Native.fly(missile,.1)

func purchases() -> void:
	MetaProgress.currency.cores=100000;MetaProgress.academy.card_shards=10000;MetaProgress.academy.tickets=1000
	for attempt in 100:
		if MetaProgress.skill_unlocked(Armor.ARCHIVE):break
		MetaProgress.Academy.draw(MetaProgress,10)
	check(MetaProgress.skill_unlocked(Armor.ARCHIVE),"archive obtained through real rare draw pool")
	if not MetaProgress.skill_unlocked(Armor.ARMOR):check(MetaProgress.Academy.purchase(MetaProgress,"redeem",Armor.ARMOR),"armor real epic redemption")
	for pair in [["V3",Armor.ARCHIVE,"launch_bulkhead"],["APOC",Armor.ARMOR,"split_hunt"]]:
		for level in 3:check(MetaProgress.Academy.purchase(MetaProgress,"level",pair[1]),"upgrade owned card "+pair[1])
		check(MetaProgress.set_unit_skill(pair[0],"passive",0,pair[1]),"equip owned card "+pair[1])
		var quote:=MetaProgress.talent_unlock_quote(pair[0],pair[2])
		check(MetaProgress.unlock_unit_talent(pair[0],pair[2],quote.get("cost",-1)),"purchase talent "+pair[2])
		for level in 3:check(MetaProgress.upgrade_talent(pair[0],pair[2],level),"upgrade talent "+pair[2])
	MetaProgress.load_save();start(MatchRules.EXTENDED)
	for pair in [["V3",Armor.ARCHIVE,"launch_bulkhead"],["APOC",Armor.ARMOR,"split_hunt"]]:
		var u:=actor(pair[0],"ally",Vector2(1000,1200))
		check(u.passive.get("id")==pair[1] and BattleRequest.combat_context.card_ranks[pair[1]]==3 and BattleRequest.combat_context.unit_talents[pair[0]][pair[2]]==3,"profile reload and new match freeze rank three card and talent "+pair[0])
	await finish();MetaProgress.reset_save()

func archive(level:int) -> void:
	setup_rank(level)
	var gun:=actor("V3","ally",Vector2(700,1200));var building:=structure(Vector2(1450,1200));var splash:=structure(Vector2(1480,1200))
	var rocket=launch(gun,building)
	var base:float=rocket.special.flight.damage
	check(not Armor.state(gun).has("bulkhead_shield"),"raising rocket does not grant shield")
	leave_rack(rocket)
	var shield:float=gun.max_hp*[.04,.06,.08,.1][level]
	check(is_equal_approx(Armor.state(gun).bulkhead_shield.hp,shield) and Armor.state(gun).bulkhead_cd==12,"actual departure grants rank shield "+str(level))
	var rocket_hp:float=rocket.hp
	rocket.receive_hit(1,"flak",{},building)
	check(rocket.hp<rocket_hp and is_equal_approx(Armor.state(gun).bulkhead_shield.hp,shield),"V3 rocket takes real interception damage while vehicle departure shield remains untouched")
	gun.receive_hit(100,"bullet",{},building)
	check(gun.hp==gun.max_hp and Armor.state(gun).bulkhead_shield.hp<shield,"departure shield absorbs real incoming damage")
	X.tick(gun,3);check(not Armor.state(gun).has("bulkhead_shield"),"shield expires after three seconds")
	gun.special.launcher_rof=20.0;gun.special.missile_racks=[10.0];Native.tick_racks(gun,0)
	impact(rocket)
	var fraction:float=[.1,.15,.2,.25][level]
	check(building.hp<100000 and splash.hp<100000,"native blast damages primary building and splash building")
	check(is_equal_approx(gun.special.launcher_rof,20*(1-fraction)) and is_equal_approx(gun.special.missile_racks[0],10*(1-fraction)),"only direct target reduces current reload once "+str(level),[gun.special.launcher_rof,gun.special.missile_racks])
	check(Armor.state(gun).archive_target==building and Armor.state(gun).archive_left==8,"successful direct building hit stores eight-second same-target credit")
	var save:Dictionary=BattleSaves.Snapshot.new().capture(battle);BattleSaves.Snapshot.new().restore(battle,save)
	for u in battle.units:if u.unit_id=="V3":gun=u
	for b in battle.buildings:if b.position.is_equal_approx(Vector2(1450,1200)):building=b
	check(Armor.state(gun).archive_target==building and Armor.state(gun).bulkhead_cd==9,"snapshot restores target reference and independent talent cooldown")
	rocket=launch(gun,building)
	check(is_equal_approx(rocket.special.flight.damage,base*(1+fraction)) and not Armor.state(gun).has("archive_left"),"next same-building rocket consumes exact damage bonus at launch")
	leave_rack(rocket);check(not Armor.state(gun).has("bulkhead_shield"),"second departure inside twelve seconds cannot refresh shield")
	impact(rocket);X.tick(gun,8)
	rocket=launch(gun,building);check(rocket.special.flight.damage==base,"expired archive cannot empower next launch")
	await finish()

func armor_rules(level:int) -> void:
	setup_rank(level)
	var gun:=actor("APOC","ally",Vector2(1000,1200));var ground:=actor("HTNK","enemy",Vector2(1250,1200));var plane:=actor("JUMPJET","enemy",Vector2(1250,1200))
	gun.attack_target=ground;gun.attack_ordered=true;gun.hull_angle=0;gun.turret_angle=0
	X.tick(gun,2.99);check(not Armor.state(gun).get("armor_ready",false),"front armor waits full three seconds")
	X.tick(gun,.01);check(Armor.state(gun).get("armor_ready",false),"stationary combat arms front protection")
	var packet:Dictionary={"expansion_origin":ground.position}
	gun.receive_hit(100,"shell",packet,ground)
	check(is_equal_approx(100000-gun.hp,Ra2Damage.quantize(100*(1-[.12,.16,.2,.24][level]))),"real front direct hit reduced by rank",100000-gun.hp)
	gun.hp=100000;packet.expansion_origin=gun.position+Vector2(-100,0);gun.receive_hit(100,"shell",packet,ground)
	check(is_equal_approx(100000-gun.hp,100),"rear hit receives no front reduction")
	gun.hp=100000;packet.expansion_origin=ground.position;packet.expansion_extra=true;gun.receive_hit(100,"shell",packet,ground)
	check(is_equal_approx(100000-gun.hp,100),"additional damage receives no direct-hit reduction")
	gun.velocity=Vector2(50,0);X.tick(gun,4.99);check(Armor.state(gun).get("armor_ready",false),"moving retains protection for full five seconds")
	X.tick(gun,.01);check(not Armor.state(gun).get("armor_ready",false),"protection expires at five seconds without refreshing")
	gun.velocity=Vector2.ZERO
	X.tick(gun,2.99);check(not Armor.state(gun).get("armor_ready",false),"expired protection must prepare a fresh three seconds")
	X.tick(gun,.01);check(Armor.state(gun).get("armor_ready",false) and Armor.state(gun).armor_left==5,"fresh stationary combat grants another finite five seconds")
	check(normal_shot(gun,plane),"actual anti-air first missile fires")
	var base:float=gun._cd_timer;var cut:float=[.1,.15,.2,.25][level]
	gun._advance_valid_burst(1,gun._active_weapon());check(Armor.state(gun).armor_credit==3,"whole anti-air volley grants three credits without stacking per missile")
	X.tick(gun,120);check(Armor.state(gun).armor_credit==3 and not Armor.state(gun).get("armor_ready",false),"three credits survive long idle and defense expiry")
	for round in 3:
		gun.attack_target=ground if round%2==0 else plane;gun._cd_timer=4;gun.hull_angle=0;gun.turret_angle=0
		check(not gun._try_fire_ready() and is_equal_approx(gun._cd_timer,4*(1-cut)) and int(Armor.state(gun).get("armor_credit",0))==2-round,"successive selected weapons each consume one waiting discount "+str(round))
		var after:float=gun._cd_timer;gun._try_fire_ready();gun._try_fire_ready()
		check(gun._cd_timer==after and int(Armor.state(gun).get("armor_credit",0))==2-round,"readiness polling cannot consume more credits or cut CD again")
		gun._cd_timer=0;check(gun._try_fire_ready() and is_equal_approx(gun._cd_timer,base),"waiting credit is not applied again to subsequent new reload")
		gun._advance_valid_burst(1,gun._active_weapon())
		check(int(Armor.state(gun).get("armor_credit",0))==2-round,"discounted anti-air and multi-shot rounds never replenish credits")
	normal_shot(gun,plane);gun._advance_valid_burst(1,gun._active_weapon())
	check(Armor.state(gun).armor_credit==3,"undiscounted air volley can grant the next set of three")
	X.tick(gun,120)
	for round in 3:
		check(normal_shot(gun,ground) and is_equal_approx(gun._cd_timer,base*(1-cut)),"idle credit shortens one new reload instead of being wasted "+str(round))
		gun._advance_valid_burst(1,gun._active_weapon())
		check(int(Armor.state(gun).get("armor_credit",0))==2-round,"idle multi-shell volley consumes exactly one credit")
	check(normal_shot(gun,ground) and is_equal_approx(gun._cd_timer,base),"fourth ground volley has no discount after three uses")
	await finish()

func split(level:int,elite:bool) -> void:
	setup_rank(level)
	var gun:=actor("APOC","ally",Vector2(700,1200));var main:=actor("HTNK","enemy",Vector2(1000,1200));var other:=actor("HTNK","enemy",Vector2(960,1200))
	if elite:gun._grant_veteran(2,false)
	check(normal_shot(gun,main),"native ground volley starts")
	var count:int=gun._active_weapon().burst;var cooldown:float=gun._cd_timer
	for shot in count-1:gun._advance_valid_burst(1,gun._active_weapon())
	var shots:=missiles(gun)
	check(shots.size()==count and count==(4 if elite else 2) and gun.attack_target==main and gun._cd_timer==cooldown,"split preserves original elite/normal count cooldown and player target")
	for i in shots.size():check(shots[i].target==(main if i%2==0 else other),"native barrel alternates primary and legal secondary "+str(i))
	var shell=shots[0]
	var before:float=other.hp;var main_before:float=main.hp
	var extra:float=Ra2Damage.quantize(CombatMath.with_offense(Ra2Damage.target_damage(shell.base_damage,shell.ra2_warhead,other,0)*.1,shell.attacker_bonus))
	shell._explode()
	check(is_equal_approx(before-other.hp,extra) and main.hp<main_before,"left shell adds exact ten-percent splash to nearby ground target",[before-other.hp,extra])
	before=other.hp;Armor.finish_projectile(shell);check(other.hp==before,"one shell cannot emit a second added blast")
	var radius:float=[2,2.5,3,3.5][level]*55
	gun._burst_left=count-1;other.position=main.position-Vector2(radius,0)
	check(Armor.split_target(gun,main)==other,"secondary search includes exact rank radius")
	other.position.x-=.1;check(Armor.split_target(gun,main)==main,"outside rank radius falls back to primary")
	other.position=Vector2(960,1240);check(Armor.split_target(gun,main)==main,"secondary outside real turret firing arc is rejected")
	await finish()

func rocket_boundaries() -> void:
	for kind in ["intercept_rack","intercept_air","empowered_intercept","retarget","capture","zero_reload","raising_discount"]:
		setup_rank(3)
		var gun:=actor("V3","ally",Vector2(700,1200));var building:=structure(Vector2(1450,1200));var rocket=launch(gun,building)
		if kind=="intercept_rack":rocket.receive_hit(10000,"bullet",{},building);check(not Armor.state(gun).has("bulkhead_shield") and not Armor.state(gun).has("archive_left"),"destroyed on rack grants neither talent nor archive")
		else:
			leave_rack(rocket)
			if kind=="intercept_air":rocket.receive_hit(10000,"bullet",{},building);check(not Armor.state(gun).has("archive_left"),"intercepted airborne missile does not count as building impact")
			elif kind=="empowered_intercept":
				var base:float=rocket.special.flight.damage
				impact(rocket)
				check(Armor.state(gun).has("archive_left"),"actual hit prepares credit before intercepted follow-up")
				var next=launch(gun,building)
				check(is_equal_approx(next.special.flight.damage,base*1.25) and not Armor.state(gun).has("archive_left"),"follow-up consumes archived damage at launch")
				leave_rack(next);next.receive_hit(10000,"bullet",{},building)
				check(not AlliedAbilities.alive(next) and not Armor.state(gun).has("archive_left"),"intercepting empowered airborne rocket never refunds consumed qualification")
			elif kind=="capture":gun.side="enemy";impact(rocket);check(not Armor.state(gun).has("archive_left"),"captured launcher cannot earn old owner's impact reward")
			elif kind=="zero_reload":ready_launcher(gun);impact(rocket);check(gun._cd_timer==0 and gun.special.launcher_rof==0,"idle reload reduction is not banked")
			elif kind=="retarget":
				impact(rocket);gun.attack_target=actor("HTNK","enemy",Vector2(1350,1200));X.tick(gun,.01)
				check(not Armor.state(gun).has("archive_left"),"retargeting clears unused building damage credit")
			else:
				var next=launch(gun,building);var before:float=gun.special.missile_racks[0];impact(rocket)
				check(gun.special.missile_racks[0]<before and next.special.flight.phase=="rack","current rack receives reduction without skipping raising")
				Native.tick_racks(gun,0);check(gun.special.missile_racks[0]<before,"raising rack discount survives native timer recomputation")
				leave_rack(next);check(gun.special.missile_racks[0]<float(gun.data.rocket.reload),"current-cycle reduction persists only into this rail's reload")
		await finish()

func armor_boundaries() -> void:
	setup_rank(3)
	var gun:=actor("APOC","ally",Vector2(1000,1200));var target:=actor("JUMPJET","enemy",Vector2(1250,1200))
	normal_shot(gun,target);gun._advance_valid_burst(1,gun._active_weapon())
	var save:Dictionary=BattleSaves.Snapshot.new().capture(battle);BattleSaves.Snapshot.new().restore(battle,save)
	for u in battle.units:
		if u.unit_id=="APOC":gun=u
		elif u.unit_id=="JUMPJET":target=u
	check(Armor.state(gun).armor_credit==3,"snapshot retains three anti-air reload credits")
	gun._cd_timer=4;target.position=Vector2(2000,1200);gun._try_fire_ready()
	check(Armor.state(gun).has("armor_credit") and gun._cd_timer==4,"out-of-range target cannot consume waiting credit")
	target.position=Vector2(1250,1200);gun._stun_timer=1;gun._try_fire_ready()
	check(Armor.state(gun).has("armor_credit"),"stun does not consume waiting credit")
	gun._stun_timer=0;gun._try_fire_ready()
	save=BattleSaves.Snapshot.new().capture(battle);BattleSaves.Snapshot.new().restore(battle,save)
	for u in battle.units:if u.unit_id=="APOC":gun=u
	check(Armor.state(gun).get("armor_wait_used",false) and Armor.state(gun).armor_credit==2,"snapshot preserves pending discount and two unused credits")
	var remaining:float=gun._cd_timer;gun._try_fire_ready()
	check(gun._cd_timer==remaining and Armor.state(gun).armor_credit==2,"restored pending wait cannot consume another credit")
	X.tick(gun,3);X.tick(gun,1.25)
	save=BattleSaves.Snapshot.new().capture(battle);BattleSaves.Snapshot.new().restore(battle,save)
	for u in battle.units:if u.unit_id=="APOC":gun=u
	check(is_equal_approx(float(Armor.state(gun).get("armor_left",0)),3.75) and Armor.state(gun).armor_credit==2,"snapshot separately preserves five-second armor remaining time and permanent credits")
	gun.side="enemy";X.tick(gun,.01);check(not gun.special.has(Armor.KEY),"ownership change clears all armor state")
	await finish()

func classic_armor() -> void:
	start(MatchRules.RA2)
	var gun:=actor("APOC","ally",Vector2(700,1200));var target:=actor("HTNK","enemy",Vector2(1000,1200));actor("HTNK","enemy",Vector2(960,1200))
	normal_shot(gun,target);gun._advance_valid_burst(1,gun._active_weapon())
	check(missiles(gun).all(func(p):return p.target==target and not p.attacker_bonus.has("expansion_hunt")),"classic retains native same-target cannons without added talent damage")
	await finish()

func saved_flight() -> void:
	setup_rank(3)
	var gun:=actor("V3","ally",Vector2(700,1200));var building:=structure(Vector2(1450,1200));var rocket=launch(gun,building)
	leave_rack(rocket);X.tick(gun,.75)
	var save:Dictionary=BattleSaves.Snapshot.new().capture(battle);BattleSaves.Snapshot.new().restore(battle,save)
	for u in battle.units:
		if u.unit_id=="V3":gun=u
		elif u.unit_id=="V3ROCKET":rocket=u
	for b in battle.buildings:if b.position.is_equal_approx(Vector2(1450,1200)):building=b
	check(rocket.special.flight.source==gun and rocket.special.flight.expansion_archive_target==building and rocket.special.flight.expansion_departed,"snapshot preserves real in-flight owner target and one-time departure")
	check(is_equal_approx(Armor.state(gun).bulkhead_shield.left,2.25) and Armor.state(gun).bulkhead_cd==11.25,"snapshot preserves partly consumed shield and cooldown")
	for step in 1000:
		if not AlliedAbilities.alive(rocket):break
		Native.fly(rocket,.05);Native.tick_racks(gun,.05);X.tick(gun,.05)
	check(not AlliedAbilities.alive(rocket) and building.hp<100000 and Armor.state(gun).archive_target==building,"restored native flight naturally arrives and awards archive without scripted impact")
	check(not Armor.state(gun).has("bulkhead_shield"),"in-flight updates never regrant consumed departure shield")
	var original_hp:float=gun.hp
	Armor.state(gun).bulkhead_shield={"hp":1000.0,"left":3.0};gun.side="enemy"
	gun.receive_hit(100,"bullet",{},building)
	check(gun.hp<original_hp,"old-side departure shield cannot absorb immediately after capture before next tick")
	await finish()

func split_boundaries() -> void:
	for reason in ["air","friendly","hidden","dead","outside_weapon","freed"]:
		setup_rank(3)
		var gun:=actor("APOC","ally",Vector2(700,1200));var main:=actor("HTNK","enemy",Vector2(1000,1200));var other:=actor("HTNK","enemy",Vector2(960,1200))
		gun.attack_target=main;gun.attack_ordered=true;gun.hull_angle=0;gun.turret_angle=0;gun._burst_left=1
		match reason:
			"air":other.is_air=true;other.logistics.air_lift=40
			"friendly":other.side="ally"
			"hidden":other.special.echo_cloaked=true
			"dead":other.hp=0
			"outside_weapon":other.position=Vector2(1150,1200)
			"freed":battle.units.erase(other);other.free()
		check(Armor.split_target(gun,main)==main,"illegal secondary preserves main without extra fire: "+reason)
		await finish()
	setup_rank(3)
	var gun:=actor("APOC","ally",Vector2(700,1200));var main:=actor("HTNK","enemy",Vector2(1000,1200));var air:=actor("JUMPJET","enemy",Vector2(1000,1200))
	var friendly:=actor("HTNK","ally",Vector2(1000,1200));var outside:=actor("HTNK","enemy",Vector2(1055.1,1200));var edge:=actor("HTNK","enemy",Vector2(1055,1200))
	normal_shot(gun,main);var shell=missiles(gun)[0]
	var native_friendly:float=Ra2Damage.quantize(CombatMath.with_offense(Ra2Damage.target_damage(shell.base_damage,shell.ra2_warhead,friendly,0),shell.attacker_bonus))
	gun._die(main);shell._explode()
	check(main.hp<100000 and edge.hp<100000 and outside.hp==100000 and is_equal_approx(100000-friendly.hp,native_friendly) and air.hp==100000,"in-flight split splash survives shooter death and adds no friendly damage beyond native friendly-fire blast",[main.hp,edge.hp,outside.hp,friendly.hp,air.hp,native_friendly])
	await finish()
	setup_rank(3)
	gun=actor("APOC","ally",Vector2(700,1200));air=actor("JUMPJET","enemy",Vector2(1000,1200))
	normal_shot(gun,air);gun._advance_valid_burst(1,gun._active_weapon())
	check(missiles(gun).size()==2 and missiles(gun).all(func(p):return p.target==air and not p.attacker_bonus.has("expansion_hunt")),"talent leaves native anti-air missiles and damage metadata unchanged")
	await finish()
