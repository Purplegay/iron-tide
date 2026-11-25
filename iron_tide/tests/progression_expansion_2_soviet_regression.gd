extends "res://tests/progression_expansion_2_regression.gd"
const Soviet=preload("res://scripts/units/expansion_2_soviet.gd")

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
	await get_tree().process_frame
	MetaProgress.reset_save()
	for level in 4:
		await links(level)
		await flak(level)
	await link_boundaries()
	await link_snapshot()
	await link_visibility()
	await independent_links()
	await flak_boundaries()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	print("EXPANSION_2_SOVIET_RESULT ",checks.size()," checks, ",failed," failed")
	get_tree().quit(0 if failed==0 else 1)

func setup_rank(level:int) -> void:
	start(MatchRules.EXTENDED);BattleRequest.skirmish_config.fog_of_war=false
	BattleRequest.combat_context.card_ranks.ps_polar_link=level
	BattleRequest.combat_context.card_ranks.ap_flak_fan=level

func durable(id:String,side:String,at:Vector2) -> Unit:
	var actor:Unit=battle.spawn_unit(id,side,at);actor.max_hp=100000;actor.hp=100000
	return actor

func links(level:int) -> void:
	setup_rank(level)
	var shk:=durable("SHK","ally",Vector2(1100,1200));shk.passive=GameData.get_skill("ps_polar_link")
	var first:=durable("HTNK","enemy",Vector2(1200,1200))
	var second:=durable("HTNK","enemy",Vector2(1230,1230))
	var middle:=durable("HTNK","enemy",Vector2(1215,1215))
	check(normal_shot(shk,first) and first.hp<100000,"first native electric shot damages enemy")
	check(Soviet.state(shk).get("polar_first")==first and not Soviet.state(shk).has("polar_link"),"first main hit opens window without chain")
	X.tick(shk,2.9)
	check(normal_shot(shk,second) and Soviet.state(shk).has("polar_link"),"different native hit inside window creates chain "+str(level))
	var first_hp:float=first.hp;var second_hp:float=second.hp
	X.tick(shk,.49)
	check(first.hp==first_hp and second.hp==second_hp,"chain waits half a second before first pulse")
	X.tick(shk,.01)
	var loss:float=first_hp-first.hp
	var weapon:Dictionary=shk._active_weapon().duplicate(true);weapon.damage*=float([.1,.15,.2,.25][level])*.5
	var expected:=Ra2Damage.quantize(CombatMath.with_defense(CombatMath.full_damage(weapon,first.armor,shk.bonuses,null,first.ra2_armor,0,first),first.bonuses))
	check(loss>0 and is_equal_approx(loss,expected) and is_equal_approx(second_hp-second.hp,loss),"both endpoints receive one exact scaled pulse "+str(level),[loss,expected])
	check(middle.hp==100000,"enemy crossing electric line is not a third damage target")
	var saved:Dictionary=BattleSaves.Snapshot.new().capture(battle);BattleSaves.Snapshot.new().restore(battle,saved)
	for actor in battle.units:
		if actor.unit_id=="SHK":shk=actor
		elif actor.position.is_equal_approx(Vector2(1200,1200)):first=actor
		elif actor.position.is_equal_approx(Vector2(1230,1230)):second=actor
	check(Soviet.state(shk).polar_link.a==first and Soviet.state(shk).polar_link.b==second and Soviet.state(shk).polar_link.ticks==1,"save restores two endpoint identities and consumed pulse")
	first_hp=first.hp;X.tick(shk,2.5)
	check(is_equal_approx(first_hp-first.hp,loss*5) and not Soviet.state(shk).has("polar_link"),"loaded chain emits exactly remaining five pulses then ends")
	normal_shot(shk,first);normal_shot(shk,second)
	check(not Soviet.state(shk).has("polar_link"),"eight-second generation interval prevents immediate new chain")
	X.tick(shk,5.01);normal_shot(shk,first);normal_shot(shk,second)
	check(Soviet.state(shk).has("polar_link"),"new pair can form after full generation interval")
	await finish()

func link_boundaries() -> void:
	for ending in ["distance","friendly","embarked","death","air"]:
		setup_rank(3)
		var shk:=durable("SHK","ally",Vector2(1100,1200));shk.passive=GameData.get_skill("ps_polar_link")
		var first:=durable("HTNK","enemy",Vector2(1200,1200));var second:=durable("HTNK","enemy",Vector2(1230,1230))
		normal_shot(shk,first);normal_shot(shk,second)
		check(Soviet.state(shk).has("polar_link"),"prepare chain boundary "+ending)
		match ending:
			"distance":second.position=first.position+Vector2(221,0)
			"friendly":second.side="ally"
			"embarked":second.set_stowed(durable("LCRF","enemy",Vector2(1350,1350)))
			"death":second.hp=0
			"air":second.is_air=true
		var hp:float=first.hp;X.tick(shk,1)
		check(first.hp==hp and not Soviet.state(shk).has("polar_link"),"chain breaks before pulse on "+ending)
		await finish()
	setup_rank(3)
	var shk:=durable("SHK","ally",Vector2(1100,1200));shk.passive=GameData.get_skill("ps_polar_link")
	var first:=durable("HTNK","enemy",Vector2(1200,1200));var second:=durable("HTNK","enemy",Vector2(1230,1230));durable("HTNK","enemy",Vector2(1210,1220))
	normal_shot(shk,first);normal_shot(shk,first)
	check(not Soviet.state(shk).has("polar_link"),"two hits on same target never form chain")
	X.tick(shk,3.01);normal_shot(shk,second)
	check(not Soviet.state(shk).has("polar_link") and Soviet.state(shk).polar_first==second,"expired first hit cannot pair with later second")
	shk.special.erase(Second.KEY)
	var chain=ability(shk,"ap_tesla_chain")
	check(shk.use_ability(shk.skills.size()-1),"existing legendary W equips alongside new passive")
	normal_shot(shk,first)
	check(second.hp<100000 and not Soviet.state(shk).has("polar_link"),"real W branches damage neighbors without counting as new main hits")
	normal_shot(shk,second)
	check(Soviet.state(shk).has("polar_link"),"second actual main attack still creates passive chain with W active")
	shk.side="enemy";X.tick(shk,.1)
	check(not shk.special.has(Second.KEY),"control change clears electric chain and timers")
	await finish()
	start(MatchRules.RA2)
	shk=durable("SHK","ally",Vector2(1100,1200));shk.passive=GameData.get_skill("ps_polar_link")
	first=durable("HTNK","enemy",Vector2(1200,1200));second=durable("HTNK","enemy",Vector2(1230,1230))
	normal_shot(shk,first);normal_shot(shk,second)
	check(not shk.special.has(Second.KEY),"classic mode does not create passive electric state")
	await finish()

func link_snapshot() -> void:
	setup_rank(3)
	const Reserve=preload("res://scripts/units/tesla_reserve.gd")
	BattleRequest.combat_context.unit_talents={"SHK":{Reserve.ID:3}}
	var shk:=durable("SHK","ally",Vector2(1100,1200));shk.passive=GameData.get_skill("ps_polar_link")
	var first:=durable("HTNK","enemy",Vector2(1200,1200));var second:=durable("E1","enemy",Vector2(1230,1230))
	shk.add_buff("attack",20,.5)
	var weapon:Dictionary=shk._active_weapon().duplicate(true);weapon.damage*=.125
	var bonus:Dictionary=shk.bonuses.duplicate(true)
	var expected:Array=[]
	for target in [first,second]:expected.append(Ra2Damage.quantize(CombatMath.with_defense(CombatMath.full_damage(weapon,target.armor,bonus,null,target.ra2_armor,0,target),target.bonuses)))
	normal_shot(shk,first)
	Reserve.tick(shk,60)
	check(shk.special.get(Reserve.STACKS,0)>0,"prepare real reserve stacks for second main hit")
	normal_shot(shk,second)
	check(not shk.special.has(Reserve.STACKS) and Soviet.state(shk).has("polar_link"),"charged main hit consumes reserve and forms ordinary chain")
	var before:Array=[first.hp,second.hp]
	shk.add_buff("attack",20,2.0)
	shk.weapon=shk.weapon.duplicate(true);shk.weapon.damage*=3
	X.tick(shk,.5)
	check(is_equal_approx(before[0]-first.hp,expected[0]) and is_equal_approx(before[1]-second.hp,expected[1]),"pulse freezes formation offense excludes charged hit and resolves each armor",[before[0]-first.hp,before[1]-second.hp,expected])
	var elapsed:float=Soviet.state(shk).polar_link.elapsed
	normal_shot(shk,first)
	check(Soviet.state(shk).polar_link.elapsed==elapsed and Soviet.state(shk).polar_link.ticks==1,"further real fire cannot refresh chain or consumed pulse")
	first.special.echo_cloaked=true
	before=[first.hp,second.hp];X.tick(shk,.5)
	check(is_equal_approx(before[0]-first.hp,expected[0]) and not battle.actor_visible_to("ally",first),"established chain persists through lost visibility without revealing endpoint")
	second.position=first.position+Vector2(221,0);X.tick(shk,.01)
	second.position=first.position+Vector2(30,30);before=[first.hp,second.hp];X.tick(shk,1)
	check(first.hp==before[0] and second.hp==before[1] and not Soviet.state(shk).has("polar_link"),"broken chain never returns when endpoints approach again")
	await finish()

func link_visibility() -> void:
	setup_rank(3)
	var shk:=durable("SHK","ally",Vector2(1100,1200));shk.passive=GameData.get_skill("ps_polar_link")
	var first:=durable("HTNK","enemy",Vector2(1200,1200));var second:=durable("HTNK","enemy",Vector2(1230,1230))
	normal_shot(shk,first);first.special.echo_cloaked=true
	normal_shot(shk,second)
	check(not Soviet.state(shk).has("polar_link") and Soviet.state(shk).polar_first==second,"first endpoint must still be visible at second real hit")
	first.special.erase("echo_cloaked");normal_shot(shk,first)
	check(Soviet.state(shk).has("polar_link"),"new visible pair forms chain normally")
	await finish()

func independent_links() -> void:
	setup_rank(3)
	var left:=durable("SHK","ally",Vector2(1100,1200));left.passive=GameData.get_skill("ps_polar_link")
	var right:=durable("SHK","ally",Vector2(1100,1230));right.passive=GameData.get_skill("ps_polar_link")
	var first:=durable("HTNK","enemy",Vector2(1200,1200));var second:=durable("HTNK","enemy",Vector2(1230,1230))
	normal_shot(left,first);normal_shot(left,second);normal_shot(right,first);normal_shot(right,second)
	check(Soviet.state(left).has("polar_link") and Soviet.state(right).has("polar_link"),"different troopers independently chain the same two endpoints")
	var before:float=first.hp;X.tick(left,.5);var one:float=before-first.hp;X.tick(right,.5)
	check(one>0 and is_equal_approx(before-first.hp,one*2),"each independent owner contributes exactly one half-second pulse")
	left.hp=0;before=first.hp;X.tick(left,.5);X.tick(right,.5)
	check(is_equal_approx(before-first.hp,one),"dead owner cannot pulse while living owner's chain continues")
	await finish()

func flak(level:int) -> void:
	setup_rank(level)
	var gun:=durable("HTK","ally",Vector2(1100,1200))
	var main:=durable("JUMPJET","enemy",Vector2(1250,1200))
	var neighbor:=durable("JUMPJET","enemy",Vector2(1275,1200))
	var ground:=durable("HTNK","enemy",Vector2(1250,1200))
	var friend:=durable("JUMPJET","ally",Vector2(1250,1220))
	var far:=durable("JUMPJET","enemy",Vector2(1320,1200))
	seed(61);check(normal_shot(gun,main),"native flak reference shot")
	fly_missiles(gun)
	var base_loss:float=100000-main.hp;var neighbor_base:float=100000-neighbor.hp
	var excluded_base:Array=[100000-ground.hp,100000-friend.hp,100000-far.hp]
	main.hp=100000;neighbor.hp=100000
	ground.hp=100000;friend.hp=100000;far.hp=100000
	var ab:=ability(gun,"ap_flak_fan")
	check(gun.use_ability(gun.skills.size()-1) and ab.cd_left==24 and Soviet.state(gun).flak_arm==5,"manual flak immediately starts five-second effect with 24-second cooldown")
	seed(61);check(normal_shot(gun,main),"armed native flak shot")
	fly_missiles(gun)
	var weapon:Dictionary=gun._active_weapon().duplicate(true);weapon.damage*=float([.2,.25,.3,.35][level])
	var expected:=Ra2Damage.quantize(CombatMath.with_defense(CombatMath.full_damage(weapon,main.armor,gun.bonuses,null,main.ra2_armor,0,main),main.bonuses))
	check(is_equal_approx(100000-main.hp,base_loss+expected),"main target receives native hit plus exactly one scaled burst "+str(level),[100000-main.hp,base_loss,expected])
	check(is_equal_approx(100000-neighbor.hp,neighbor_base+expected),"nearby enemy aircraft receives exactly one added burst")
	check([100000-ground.hp,100000-friend.hp,100000-far.hp]==excluded_base,"added flak excludes ground friendly and out-of-radius targets beyond unchanged native splash",{"native":excluded_base,"armed":[100000-ground.hp,100000-friend.hp,100000-far.hp]})
	check(Soviet.state(gun).flak_arm==5,"successful anti-air hit neither consumes nor extends effect")
	for dt:float in [2.5,2.49]:
		X.tick(gun,dt)
		main.hp=100000;neighbor.hp=100000;seed(61);normal_shot(gun,main);fly_missiles(gun)
		check(is_equal_approx(100000-main.hp,base_loss+expected) and is_equal_approx(100000-neighbor.hp,neighbor_base+expected),"each later shot inside five seconds adds exactly one splash "+str(dt))
	# Native HTK flak is Inviso: it detonates on spawn rather than remaining in flight.
	X.tick(gun,.01);main.hp=100000;seed(61);normal_shot(gun,main);fly_missiles(gun)
	check(not Soviet.state(gun).has("flak_arm") and is_equal_approx(100000-main.hp,base_loss),"native shot at exactly five seconds has no added splash")
	main.hp=100000;seed(61);normal_shot(gun,main);fly_missiles(gun)
	check(is_equal_approx(100000-main.hp,base_loss),"subsequent normal shots have no leftover splash")
	check(not gun.use_ability(gun.skills.size()-1) and ab.cd_left==24,"expiry does not refund W cooldown")
	check(Demo.sample("ap_flak_fan",level,4.99).active and not Demo.sample("ap_flak_fan",level,5.0).active,"demo matches continuous five-second effect")
	await finish()

func flak_boundaries() -> void:
	setup_rank(3)
	BattleRequest.combat_context.loadouts.HTK={"active":["ap_flak_fan"],"passive":""}
	var gun:=durable("HTK","ally",Vector2(1100,1200));var main:=durable("JUMPJET","enemy",Vector2(1250,1200))
	var ground:=durable("HTNK","enemy",Vector2(1250,1250))
	var ab:Ability=gun.ability_at(UnitSkillLayout.index(gun,1))
	check(gun.use_ability(UnitSkillLayout.index(gun,1)),"equip and cast actual W slot")
	normal_shot(gun,ground);fly_missiles(gun)
	check(Soviet.state(gun).flak_arm==5,"ordinary ground shot does not consume or extend continuous effect")
	X.tick(gun,2)
	var saved:Dictionary=BattleSaves.Snapshot.new().capture(battle);BattleSaves.Snapshot.new().restore(battle,saved)
	for actor in battle.units:
		if actor.unit_id=="HTK":gun=actor
		elif actor.unit_id=="JUMPJET":main=actor
		elif actor.unit_id=="HTNK":ground=actor
	ab=gun.ability_at(UnitSkillLayout.index(gun,1))
	check(Soviet.state(gun).flak_arm==3 and ab.cd_left==24,"save preserves remaining effect and W cooldown")
	var before:float=main.hp
	seed(61);normal_shot(gun,main);fly_missiles(gun)
	var loaded_loss:float=before-main.hp
	check(Soviet.state(gun).flak_arm==3 and loaded_loss>0,"loaded active effect survives first hit")
	main.hp=before;seed(61);normal_shot(gun,main);fly_missiles(gun)
	check(is_equal_approx(before-main.hp,loaded_loss) and Soviet.state(gun).flak_arm==3,"loaded active effect also applies to second hit without consuming timer")
	X.tick(gun,3)
	check(not Soviet.state(gun).has("flak_arm"),"unused arm expires after five seconds without refund")
	ab.cd_left=0
	const Auto=preload("res://scripts/units/auto_w.gd")
	battle.production_technology.unlock(Auto.TECH,"ally")
	check(not Auto.evaluate(gun),"restored paused battle suppresses Auto W")
	battle.paused=false;get_tree().paused=false
	gun.attack_target=ground;gun.attack_ordered=true;gun._cd_timer=0;gun._cancel_burst();gun.hull_angle=0;gun.turret_angle=0
	check(not Auto.evaluate(gun) and ab.cd_left==0,"Auto W never arms for ground target")
	gun.attack_target=main
	check(Auto.evaluate(gun) and Soviet.state(gun).has("flak_arm") and gun.attack_target==main and gun._cd_timer==0,"Auto W uses real cast without changing main target or reload")
	check(not Auto.evaluate(gun),"Auto W cannot double arm")
	gun.side="enemy";X.tick(gun,.01)
	check(not gun.special.has(Second.KEY),"ownership change removes pending flak")
	await finish()
