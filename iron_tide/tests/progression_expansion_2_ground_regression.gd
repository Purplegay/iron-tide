extends "res://tests/progression_expansion_2_regression.gd"
const Ground=preload("res://scripts/units/expansion_2_ground.gd")

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
	await get_tree().process_frame
	MetaProgress.reset_save()
	await purchases()
	for level in 4:
		await crosses(level)
		await native_hits(level)
		await prism_boundaries(level)
		await live_ranging(level)
		await camouflage(level)
	await isolation()
	await preview_cases()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	print("EXPANSION_2_GROUND_RESULT ",checks.size()," checks, ",failed," failed")
	get_tree().quit(0 if failed==0 else 1)

func setup_rank(level:int) -> void:
	start(MatchRules.EXTENDED)
	BattleRequest.skirmish_config.fog_of_war=false
	for id in ["ap_prism_cross","ps_mirage_gap"]:BattleRequest.combat_context.card_ranks[id]=level
	BattleRequest.combat_context.unit_talents.GGI={"armor_ranging":level}
	BattleRequest.combat_context.unit_talents.SREF={"prism_guard":level}

func durable(id:String,side:String,at:Vector2) -> Unit:
	var unit:Unit=battle.spawn_unit(id,side,at)
	unit.max_hp=100000;unit.hp=100000
	return unit

func purchases() -> void:
	MetaProgress.currency.cores=100000
	for pair in [["GGI","armor_ranging"],["SREF","prism_guard"]]:
		var offer:=MetaProgress.talent_unlock_quote(pair[0],pair[1])
		check(MetaProgress.unlock_unit_talent(pair[0],pair[1],offer.get("cost",-1)),"purchase new ground talent "+pair[1])
		for level in 3:check(MetaProgress.upgrade_talent(pair[0],pair[1],level),"upgrade new ground talent "+pair[1]+str(level))
	MetaProgress.load_save()
	start(MatchRules.EXTENDED)
	check(BattleRequest.has_unit_talent("GGI","armor_ranging","ally") and BattleRequest.has_unit_talent("SREF","prism_guard","ally"),"new match restores both purchased talent snapshots")
	await finish()
	MetaProgress.reset_save()

func crosses(level:int) -> void:
	setup_rank(level)
	var prism:Unit=battle.spawn_unit("SREF","ally",Vector2(1200,1200));prism.hull_angle=0
	var at:=Vector2(1350,1200)
	var center:=durable("HTNK","enemy",at)
	var arm:=durable("HTNK","enemy",at+Vector2(0,80))
	var outside:=durable("HTNK","enemy",at+Vector2(45,45))
	var friend:=durable("HTNK","ally",at+Vector2(0,-70))
	var air:=durable("JUMPJET","enemy",at+Vector2(40,0))
	var ab:=ability(prism,"ap_prism_cross")
	check(ab.radius>0 and not X.cast(prism,ab,Vector2.INF) and ab.cd_left==0,"cross enters point targeting and rejects missing point")
	check(not X.cast(prism,ab,prism.position+Vector2(5000,0)) and ab.cd_left==0,"cross rejects range before cooldown")
	check(prism.use_ability(prism.skills.size()-1,at),"cross casts through actual unit W path "+str(level))
	check(is_equal_approx(ab.cd_left,[32,30,28,26][level]),"cross rank cooldown")
	X.tick(prism,.59);check(center.hp==100000,"cross full warning prevents early damage")
	X.tick(prism,.01)
	var loss:float=100000-center.hp
	var expected_weapon:Dictionary=prism._active_weapon().duplicate(true);expected_weapon.damage*=float([.6,.75,.9,1.1][level])
	var expected:=Ra2Damage.quantize(CombatMath.with_defense(CombatMath.full_damage(expected_weapon,center.armor,prism.bonuses,null,center.ra2_armor,0,center),center.bonuses))
	check(loss>0 and is_equal_approx(loss,expected),"cross center takes exactly one scaled native beam hit "+str(level),[loss,expected])
	check(arm.hp<100000 and outside.hp==100000 and friend.hp==100000 and air.hp==100000,"cross hits both axes without square area friendly or air damage")
	check(not Ground.state(prism).has("prism_shield"),"cross does not produce native refraction shield")
	var escaped_hp:float=arm.hp
	arm.position=at+Vector2(45,80)
	var snapshot:Dictionary=BattleSaves.Snapshot.new().capture(battle)
	BattleSaves.Snapshot.new().restore(battle,snapshot)
	for unit:Unit in battle.units:
		if unit.unit_id=="SREF" and unit.side=="ally":prism=unit
		if unit.unit_id=="HTNK" and unit.side=="enemy" and unit.position.distance_to(at)<1:center=unit
		if unit.unit_id=="HTNK" and unit.side=="enemy" and unit.position.distance_to(at+Vector2(45,80))<1:arm=unit
	check(Ground.state(prism).prism_cross.pulses==1 and is_equal_approx(Ground.state(prism).prism_cross.next,.6),"save retains exactly one remaining cross pulse")
	var hp:float=center.hp
	X.tick(prism,.6)
	check(is_equal_approx(hp-center.hp,loss) and not Ground.state(prism).has("prism_cross"),"load emits second pulse once without resetting first")
	check(arm.hp==escaped_hp,"moving out between pulses avoids second hit after snapshot restore "+str(level))
	X.tick(prism,1);check(is_equal_approx(hp-center.hp,loss),"finished cross cannot repeat damage")
	ab=prism.skills.back();ab.cd_left=0
	check(X.cast(prism,ab,at),"cross can recast when cooldown is ready")
	prism._stun_timer=2;X.tick(prism,.6)
	check(not Ground.state(prism).has("prism_cross") and ab.cd_left>0,"interruption cancels pending pulse without refund")
	await finish()

func native_hits(level:int) -> void:
	setup_rank(level)
	var guard:Unit=battle.spawn_unit("GGI","ally",Vector2(1100,1200));guard.set_deployed(true,false)
	var victim:=durable("HTNK","enemy",Vector2(1250,1200));guard.attack_target=victim
	check(X.impact(victim,guard,100,{})==100 and X.impact(victim,guard,100,{})==100,"ranging first two direct hits do not retroactively gain bonus")
	check(is_equal_approx(X.impact(victim,guard,100,{}),100*(1+[.08,.12,.16,.2][level])),"ranging subsequent direct hit uses rank bonus")
	var left:float=Ground.state(guard).ranging_left
	X.impact(victim,guard,100,{});check(Ground.state(guard).ranging_left==left,"ranging repeated hits do not extend lifetime")
	check(X.impact(victim,guard,100,{"expansion_extra":true})==100,"ranging excludes added card damage")
	X.tick(guard,4)
	check(X.impact(victim,guard,100,{})==100 and Ground.state(guard).ranging_hits==1,"ranging expires and requires two fresh hits")
	guard.set_deployed(false,false);X.tick(guard,.01);check(not Ground.state(guard).has("ranging_target"),"undeploy clears ranging target")
	guard.set_deployed(true,false);X.impact(victim,guard,100,{})
	guard.attack_target=durable("HTNK","enemy",Vector2(1280,1250));X.tick(guard,.01)
	check(not Ground.state(guard).has("ranging_target"),"retarget clears ranging immediately on next rules step")
	var replacement:Unit=guard.attack_target
	X.impact(replacement,guard,100,{});X.impact(replacement,guard,100,{})
	check(Ground.state(guard).has("ranging_left"),"new ground target earns its own two-hit window")
	replacement.hp=0;X.tick(guard,.01)
	check(not Ground.state(guard).has("ranging_target") and Ground.state(guard).ranging_hits==0,"target death clears binding and count before another impact")
	var plane:=durable("JUMPJET","enemy",Vector2(1280,1230));guard.attack_target=plane
	check(X.impact(plane,guard,100,{})==100 and X.impact(plane,guard,100,{})==100 and Ground.state(guard).ranging_hits==0 and not Ground.state(guard).has("ranging_left"),"two ordinary air impacts neither accumulate nor gain ground-vehicle ranging")
	var prism:Unit=battle.spawn_unit("SREF","ally",Vector2(1500,1500))
	var primary:=durable("E2","enemy",Vector2(1600,1500))
	var second:=durable("E2","enemy",Vector2(1640,1510))
	var third:=durable("E2","enemy",Vector2(1630,1470))
	prism._grant_veteran(2,false)
	prism._fire_shot(primary)
	check(primary.hp<100000 and second.hp<100000 and third.hp<100000,"real elite main beam and native branches damage three targets")
	var s:=Ground.state(prism)
	check(s.has("prism_shield"),"native three-target volley grants prism shield "+str(level),s.keys())
	if s.has("prism_shield"):
		var hp:float=prism.max_hp*[.03,.04,.05,.06][level]
		check(is_equal_approx(s.prism_shield.hp,hp),"prism shield scales with maximum life")
		check(is_equal_approx(Second.absorb(prism,hp+7),7) and not s.has("prism_shield"),"prism shield absorbs exact pool and passes overflow")
	prism._fire_shot(primary);check(not s.has("prism_shield"),"repeated prism volleys cannot refill shield within interval")
	X.tick(prism,12);prism._fire_shot(primary)
	check(s.has("prism_shield"),"native volley can earn shield after cooldown")
	X.tick(prism,3);check(not s.has("prism_shield"),"prism shield expires at three seconds")
	await finish()

func prism_boundaries(level:int) -> void:
	setup_rank(level)
	var prism:Unit=battle.spawn_unit("SREF","ally",Vector2(1200,1200));prism._grant_veteran(2,false)
	var first:=durable("E2","enemy",Vector2(1300,1200))
	var second:=durable("E2","enemy",Vector2(1340,1210))
	var third:=durable("E2","enemy",Vector2(2200,2200))
	prism._fire_shot(first)
	var s:=Ground.state(prism)
	check(first.hp<100000 and second.hp<100000 and third.hp==100000 and s.prism_victims.size()==2 and not s.has("prism_shield"),"native two-target volley does not grant prism shield")
	var probe:=Projectile.new()
	var bonus:Dictionary={"expansion_prism_volley":s.prism_volley}
	Ground.damaged(prism,first,bonus,probe);Ground.damaged(prism,second,bonus,probe)
	check(s.prism_victims.size()==2 and not s.has("prism_shield"),"duplicate projectile callbacks for the same two victims cannot meet three-distinct threshold")
	bonus.expansion_extra=true;Ground.damaged(prism,third,bonus,probe);probe.free()
	check(s.prism_victims.size()==2 and not s.has("prism_guard_cd"),"additional card damage cannot contribute a third native victim or start cooldown")
	first.position=Vector2(2200,2200);second.position=Vector2(2240,2210);third.position=Vector2(1300,1200)
	prism._fire_shot(third)
	check(s.prism_victims.size()==1 and not s.has("prism_shield"),"new native volley resets victim set instead of accumulating earlier two targets")
	first.position=Vector2(1340,1210);second.position=Vector2(1330,1170)
	prism._fire_shot(third)
	check(s.has("prism_shield"),"subsequent native three-target volley grants shield independently")
	if s.has("prism_shield"):
		var hp:float=prism.max_hp*[.03,.04,.05,.06][level]
		check(Second.absorb(prism,hp*.5)==0 and is_equal_approx(s.prism_shield.hp,hp*.5),"partial absorption leaves half pool without health overflow")
		X.tick(prism,1);prism._fire_shot(third)
		check(is_equal_approx(s.prism_shield.hp,hp*.5) and is_equal_approx(s.prism_shield.left,2) and is_equal_approx(s.prism_guard_cd,11),"new native volley inside cooldown neither replenishes damaged shield nor renews either timer")
	await finish()

func camouflage(level:int) -> void:
	setup_rank(level)
	var mirage:Unit=battle.spawn_unit("MGTK","ally",Vector2(1200,1200));mirage.passive=GameData.get_skill("ps_mirage_gap")
	var enemy:=durable("HTNK","enemy",Vector2(1300,1200))
	mirage.special.erase("reveal");AlliedAbilities.update_mirage_tree(mirage)
	check(mirage.special.has("mirage_tree"),"native mirage camouflage exists before attack")
	mirage._fire_shot(enemy)
	var s:=Ground.state(mirage)
	check(s.has("mirage_guard") and float(mirage.special.get("reveal",0))>0,"normal shot exits actual disguise and grants guard before reveal")
	var hp:float=mirage.hp
	mirage.receive_hit(100,"bullet",{},enemy)
	check(is_equal_approx(hp-mirage.hp,Ra2Damage.quantize(CombatMath.with_defense(100*(1-[.1,.14,.18,.22][level]),mirage.bonuses))),"actual incoming direct damage uses mirage guard "+str(level),hp-mirage.hp)
	check(Ground.defend(mirage,100,"crush",{},enemy)==100 and Ground.defend(mirage,100,"laser",{"expansion_extra":true},enemy)==100,"mirage guard does not protect crush or skill damage")
	X.tick(mirage,1);mirage._fire_shot(enemy)
	check(is_equal_approx(s.mirage_guard,1),"later shots do not extend guard")
	X.tick(mirage,1);check(not s.has("mirage_guard"),"mirage guard expires after two seconds")
	var mirror:Unit=battle.spawn_unit("MGTK","ally",Vector2(1220,1230));mirror.passive=GameData.get_skill("ps_mirage_gap")
	mirror.special.expansion_temporary={"kind":"mirror","owner":mirage}
	mirror.special.erase("reveal");AlliedAbilities.update_mirage_tree(mirror);mirror._fire_shot(enemy)
	check(not Ground.state(mirror).has("mirage_guard") and not s.has("mirage_guard"),"actual temporary mirror firing grants guard to neither mirror nor owner")
	mirage.special.erase("reveal");AlliedAbilities.update_mirage_tree(mirage);mirage._fire_shot(enemy)
	check(not s.has("mirage_guard"),"camouflage during interval cannot bypass cooldown")
	X.tick(mirage,10);mirage.special.reveal=2.;AlliedAbilities.update_mirage_tree(mirage);mirage._fire_shot(enemy)
	check(not s.has("mirage_guard"),"expired interval alone cannot make undisguised ordinary shot grant guard")
	mirage.special.erase("reveal");AlliedAbilities.update_mirage_tree(mirage);mirage._fire_shot(enemy)
	check(s.has("mirage_guard"),"fresh native camouflage can trigger after interval")
	mirage.side="enemy";X.tick(mirage,.1);check(not mirage.special.has(Second.KEY),"ownership change clears pending guard state")
	await finish()

func live_ranging(level:int) -> void:
	setup_rank(level)
	var guard:Unit=battle.spawn_unit("GGI","ally",Vector2(1100,1200));guard.set_deployed(true,false)
	var victim:=durable("HTNK","enemy",Vector2(1250,1200))
	var losses:Array=[]
	for index in 3:
		var hp:float=victim.hp
		check(normal_shot(guard,victim) and missiles(guard).size()==1,"ranging launches native missile "+str(index))
		check(victim.hp==hp,"ranging does not count missile before impact")
		fly_missiles(guard);losses.append(hp-victim.hp)
	check(losses[0]>0 and losses[0]==losses[1] and losses[2]>losses[1],"real missile third impact gains ranging bonus "+str(level),losses)
	var weapon:Dictionary=guard._active_weapon()
	var expected:=Ra2Damage.quantize(CombatMath.with_defense(CombatMath.full_damage(weapon,victim.armor,guard.bonuses,null,victim.ra2_armor,0,victim)*(1+[.08,.12,.16,.2][level]),victim.bonuses))
	check(is_equal_approx(losses[2],expected),"native boosted missile applies exact rank and defense "+str(level),[losses[2],expected])
	var remaining:float=Ground.state(guard).ranging_left
	var ab:=ability(guard,"ap_anchor_pin")
	check(guard.use_ability(guard.skills.size()-1),"direct anchor coexists with ranging")
	fly_missiles(guard)
	check(Ground.state(guard).ranging_left==remaining and Ground.state(guard).ranging_hits==2,"skill missile cannot add or refresh normal-hit ranging")
	var snapshot:Dictionary=BattleSaves.Snapshot.new().capture(battle)
	BattleSaves.Snapshot.new().restore(battle,snapshot)
	for actor in battle.units:
		if actor.unit_id=="GGI" and actor.side=="ally":guard=actor
		if actor.unit_id=="HTNK" and actor.side=="enemy":victim=actor
	check(is_same(Ground.state(guard).ranging_target,victim) and is_equal_approx(Ground.state(guard).ranging_left,remaining),"save restores ranging target identity and remaining duration")
	guard.attack_target=durable("JUMPJET","enemy",Vector2(1250,1200));X.tick(guard,.01)
	check(not Ground.state(guard).has("ranging_target"),"air retarget clears existing ground ranging")
	var plane=guard.attack_target
	check(normal_shot(guard,plane),"native anti-air missile still fires")
	fly_missiles(guard)
	check(not Ground.state(guard).has("ranging_target"),"anti-air missile never builds ground ranging")
	await finish()

func isolation() -> void:
	start(MatchRules.RA2)
	var prism:Unit=battle.spawn_unit("SREF","ally",Vector2(1200,1200))
	var ab:=ability(prism,"ap_prism_cross")
	check(not X.cast(prism,ab,Vector2(1300,1200)) and ab.cd_left==0,"classic mode excludes cross skill")
	BattleRequest.combat_context.unit_talents.GGI={"armor_ranging":3}
	var guard:Unit=battle.spawn_unit("GGI","ally",Vector2(1200,1300));guard.set_deployed(true,false)
	var target:=durable("HTNK","enemy",Vector2(1300,1300));guard.attack_target=target
	for i in 3:check(X.impact(target,guard,100,{})==100,"classic mode ignores ranging "+str(i))
	await finish()

func preview_cases() -> void:
	var preview=load("res://scripts/ui/unit_showcase.gd").new();add_child(preview)
	for id:String in {"armor_ranging":"GGI","prism_guard":"SREF"}:
		for level in 4:
			preview.show_unit({"armor_ranging":"GGI","prism_guard":"SREF"}[id],id,level)
			preview.age=2.5;preview._animate()
			check(preview.actor!=null and Demo.sample(id,level,2.5).active,"real ground talent demo "+id+str(level))
	preview.free()
