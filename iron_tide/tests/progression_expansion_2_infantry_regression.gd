extends "res://tests/progression_expansion_2_regression.gd"
const Infantry=preload("res://scripts/units/expansion_2_infantry.gd")
const Reserve=preload("res://scripts/units/tesla_reserve.gd")

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
	await get_tree().process_frame
	MetaProgress.reset_save();await purchases()
	for level in 4:
		await relocate(level);await advance(level);await transfer(level);await transfer_comparison(level);await shards(level)
	await shard_boundaries();await transfer_boundaries();await movement_boundaries();await advance_boundaries();await primary_boundaries();await isolation()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	print("EXPANSION_2_INFANTRY_RESULT ",checks.size()," checks, ",failed," failed")
	get_tree().quit(0 if failed==0 else 1)

func setup_rank(level:int) -> void:
	start(MatchRules.EXTENDED);BattleRequest.skirmish_config.fog_of_war=false
	for id in Infantry.TALENTS:BattleRequest.combat_context.unit_talents[id]={Infantry.TALENTS[id]:level}
	BattleRequest.combat_context.unit_talents.SHK.tesla_reserve=3

func actor(id:String,side:String,at:Vector2) -> Unit:
	return battle.spawn_unit(id,side,at)

func durable(id:String,side:String,at:Vector2) -> Unit:
	var u:=actor(id,side,at);u.hp=100000;u.max_hp=100000;return u

func charge(unit) -> float:
	var rule:=Reserve.rule(unit);Reserve.tick(unit,rule.interval*2)
	return int(unit.special.get(Reserve.STACKS,0))*rule.damage

func damage_for(unit,target,factor:float) -> float:
	var weapon:Dictionary=unit._active_weapon().duplicate(true);weapon.damage*=factor
	return Ra2Damage.quantize(CombatMath.with_defense(CombatMath.full_damage(weapon,target.armor,unit.bonuses,null,target.ra2_armor,0,target),target.bonuses))

func rows() -> Array:
	return battle.allied_state.get(Infantry.SHARDS,[])

func purchases() -> void:
	MetaProgress.currency.cores=100000
	for id in Infantry.TALENTS:
		var tid:String=Infantry.TALENTS[id];var quote:=MetaProgress.talent_unlock_quote(id,tid)
		check(MetaProgress.unlock_unit_talent(id,tid,quote.get("cost",-1)),"purchase functional talent "+tid)
		for rank in 3:check(MetaProgress.upgrade_talent(id,tid,rank),"upgrade "+tid+str(rank))
	MetaProgress.load_save();start(MatchRules.EXTENDED)
	for id in Infantry.TALENTS:check(BattleRequest.has_unit_talent(id,Infantry.TALENTS[id],"ally") and MetaProgress.talent_rank(id,Infantry.TALENTS[id],BattleRequest.combat_context.unit_talents)==3,"saved permanent talent snapshot "+id)
	await finish();MetaProgress.reset_save()

func relocate(level:int) -> void:
	setup_rank(level)
	var gun:=actor("SNIPE","ally",Vector2(1100,1200));var target:=actor("E2","enemy",Vector2(1200,1200))
	var speed:float=gun.move_speed;var reach:float=gun.weapon.range
	var survivor:=durable("E2","enemy",Vector2(1220,1220))
	check(normal_shot(gun,survivor),"sniper actually fires nonlethal example");fly_missiles(gun)
	check(not survivor._dead and survivor.hp<100000 and not Infantry.state(gun).has("relocate_left") and not Infantry.state(gun).has("relocate_cd"),"ordinary sniper hit without a kill grants neither movement reward nor interval")
	check(normal_shot(gun,target),"real sniper fires at enemy infantry");fly_missiles(gun)
	check(target._dead and Infantry.state(gun).get("relocate_left",0)==2,"ordinary sniper kill starts two seconds "+str(level))
	check(is_equal_approx(gun.move_speed,speed*(1+[.15,.2,.25,.3][level])) and gun.weapon.range==reach,"rank movement bonus does not change sniper range")
	X.tick(gun,1)
	var other:=actor("E2","enemy",Vector2(1200,1220));normal_shot(gun,other);fly_missiles(gun)
	check(Infantry.state(gun).get("relocate_left",0)==1,"another kill inside cooldown does not refresh boost")
	X.tick(gun,1);check(is_equal_approx(gun.move_speed,speed),"speed reverts at two-second boundary")
	X.tick(gun,6);other=actor("E2","enemy",Vector2(1200,1240));normal_shot(gun,other);fly_missiles(gun)
	check(Infantry.state(gun).get("relocate_left",0)==2,"new kill may trigger after eight seconds")
	await finish()

func move_for(unit,seconds:float) -> void:
	X.tick(unit,.01)
	for frame in roundi(seconds*10):
		unit.position+=Vector2(5,0);unit.velocity=Vector2(50,0);X.tick(unit,.1)
	unit.velocity=Vector2.ZERO;X.tick(unit,.01)

func advance(level:int) -> void:
	setup_rank(level)
	var gun:=actor("E2","ally",Vector2(1100,1200));var target:=durable("HTNK","enemy",Vector2(1250,1200))
	var normal_attack:float=gun.bonuses.attack_bonus
	normal_shot(gun,target);var normal_reload:float=gun._cd_timer
	move_for(gun,2)
	var fraction:float=[.1,.15,.2,.25][level]
	check(Infantry.state(gun).get("advance_left",0)==5 and Infantry.state(gun).advance_cd==10,"two seconds real displacement then stop starts five-second buff and ten-second interval")
	check(is_equal_approx(gun._cd_timer,normal_reload),"granting advance does not retroactively shorten a pre-existing weapon reload")
	check(is_equal_approx(gun.bonuses.attack_bonus,normal_attack*(1+fraction)),"actual attack stat gains rank percent "+str(level))
	X.tick(gun,1)
	var save:Dictionary=BattleSaves.Snapshot.new().capture(battle);BattleSaves.Snapshot.new().restore(battle,save)
	for u in battle.units:
		if u.unit_id=="E2":gun=u
		if u.unit_id=="HTNK":target=u
	check(Infantry.state(gun).get("advance_left",0)==4 and Infantry.state(gun).advance_cd==9 and is_equal_approx(gun.bonuses.attack_bonus,normal_attack*(1+fraction)),"save preserves remaining buff interval and attack without multiplying twice")
	for shot in 3:
		var expected:=damage_for(gun,target,1);var hp:float=target.hp
		check(normal_shot(gun,target) and is_equal_approx(gun._cd_timer,normal_reload*(1-fraction)),"every attack inside window receives shortened reload "+str(level)+"/"+str(shot))
		fly_missiles(gun)
		check(is_equal_approx(hp-target.hp,expected) and Infantry.state(gun).advance_left==4,"each real shot deals strengthened damage without consuming the buff",[hp-target.hp,expected])
	move_for(gun,2);check(Infantry.state(gun).advance_left<2 and Infantry.state(gun).advance_left>1.9,"moving again cannot refresh or consume the active window")
	X.tick(gun,float(Infantry.state(gun).advance_left))
	check(not Infantry.state(gun).has("advance_left") and is_equal_approx(gun.bonuses.attack_bonus,normal_attack),"attack stat restores at exact five-second expiry")
	normal_shot(gun,target);check(is_equal_approx(gun._cd_timer,normal_reload),"attacks after expiry use ordinary reload")
	move_for(gun,2);check(not Infantry.state(gun).has("advance_left"),"new movement inside trigger interval cannot refresh buff")
	X.tick(gun,10);move_for(gun,2);check(Infantry.state(gun).get("advance_left",0)==5,"new complete move after cooldown grants a new full window")
	await finish()

func transfer(level:int) -> void:
	setup_rank(level)
	var gun:=actor("SHK","ally",Vector2(1100,1200));var victim:=actor("E2","enemy",Vector2(1200,1200));victim.hp=1
	var extra:=charge(gun);normal_shot(gun,victim)
	var kept:float=extra*[.2,.3,.4,.5][level]
	check(victim._dead and is_equal_approx(float(Infantry.state(gun).get("transfer_damage",0)),kept) and not Infantry.state(gun).has("transfer_left"),"charged main kill stores only rank portion of native extra "+str(level),[Infantry.state(gun),extra])
	X.tick(gun,3600)
	check(is_equal_approx(Infantry.state(gun).get("transfer_damage",0),kept),"stored charge survives one hour without firing "+str(level))
	var save:Dictionary=BattleSaves.Snapshot.new().capture(battle);BattleSaves.Snapshot.new().restore(battle,save)
	for u in battle.units:if u.unit_id=="SHK":gun=u
	X.tick(gun,3600)
	check(is_equal_approx(Infantry.state(gun).get("transfer_damage",0),kept),"carry snapshot survives save")
	var target:=durable("HTNK","enemy",Vector2(1200,1200));gun.attack_target=target
	var expected:=damage_for(gun,target,1+kept);normal_shot(gun,target)
	check(is_equal_approx(100000-target.hp,expected) and not Infantry.state(gun).has("transfer_damage"),"next actual primary consumes exact carry without multiplying twice",[100000-target.hp,expected])
	victim=actor("E2","enemy",Vector2(1200,1220));victim.hp=1;charge(gun);normal_shot(gun,victim)
	victim=actor("E2","enemy",Vector2(1200,1240));victim.hp=1;normal_shot(gun,victim)
	check(victim._dead and not Infantry.state(gun).has("transfer_damage"),"carry-powered kill cannot create another carry")
	victim=actor("E2","enemy",Vector2(1200,1260));victim.hp=1;charge(gun);normal_shot(gun,victim)
	extra=charge(gun);target.hp=100000;gun.attack_target=target;expected=damage_for(gun,target,1+extra);normal_shot(gun,target)
	check(is_equal_approx(100000-target.hp,expected),"natural new reserve and carry choose stronger instead of adding",[100000-target.hp,expected])
	await finish()

func shards(level:int) -> void:
	setup_rank(level)
	var gun:=actor("FLAKT","ally",Vector2(1100,1200));var plane:=durable("JUMPJET","enemy",Vector2(1200,1200))
	normal_shot(gun,plane);fly_missiles(gun)
	check(rows().size()==1 and Infantry.state(gun).get("shard_cd",0)==4,"ordinary anti-air hit attaches one delayed shard "+str(level))
	var old:=durable("JUMPJET","enemy",plane.position)
	plane.position+=Vector2(130,0)
	var neighbor:=durable("JUMPJET","enemy",plane.position+Vector2(40,0))
	var ground:=durable("HTNK","enemy",plane.position);var friend:=durable("JUMPJET","ally",plane.position)
	plane.hp=100000;var expected:=damage_for(gun,plane,[.25,.35,.45,.55][level])
	Infantry.world_tick(battle,.79);check(plane.hp==100000,"delayed shard waits full .8 seconds")
	var save:Dictionary=BattleSaves.Snapshot.new().capture(battle);BattleSaves.Snapshot.new().restore(battle,save)
	for u in battle.units:
		if u.unit_id=="FLAKT":gun=u
		elif u.unit_id=="HTNK":ground=u
		elif u.side=="ally":friend=u
		elif u.position.is_equal_approx(Vector2(1200,1200)):old=u
		elif u.position.is_equal_approx(Vector2(1330,1200)):plane=u
		else:neighbor=u
	check(rows().size()==1 and rows()[0].target==plane and is_equal_approx(rows()[0].left,.01),"save preserves remaining delay and moving target identity")
	Infantry.world_tick(battle,.01)
	check(is_equal_approx(100000-plane.hp,expected) and is_equal_approx(100000-neighbor.hp,expected),"main and nearby aircraft each take one exact delayed blast",[100000-plane.hp,100000-neighbor.hp,expected])
	check(old.hp==100000 and ground.hp==100000 and friend.hp==100000 and rows().is_empty(),"blast follows current position and excludes old position ground friendly recursion")
	normal_shot(gun,plane);fly_missiles(gun);check(rows().is_empty(),"four-second trigger interval prevents repeated attach")
	X.tick(gun,4);normal_shot(gun,plane);fly_missiles(gun);check(rows().size()==1,"next hit after cooldown may attach again")
	await finish()

func shard_boundaries() -> void:
	for reason in ["land","death","owner_death","friendly","rocket","secondary","temporary","land_then_death"]:
		setup_rank(3)
		var gun:=actor("FLAKT","ally",Vector2(1100,1200));var plane:=durable("JUMPJET","enemy",Vector2(1200,1200))
		var neighbor:=durable("JUMPJET","enemy",Vector2(1300,1200))
		if reason=="rocket":plane.unit_id="V3ROCKET"
		if reason=="temporary":plane.special.expansion_temporary={"kind":"twin"}
		if reason=="secondary":
			var bonus:Dictionary=gun.bonuses.duplicate();bonus.expansion_origin=gun.position;bonus.equipment_secondary=true;bonus.expansion_shard_weapon=gun._weapon_for_target(plane)
			plane.receive_hit(5,"bullet",bonus,gun)
		else:normal_shot(gun,plane);fly_missiles(gun)
		if reason in ["rocket","secondary","temporary"]:
			check(rows().is_empty(),"shard excludes "+reason);await finish();continue
		plane.position=neighbor.position
		if reason in ["land","land_then_death"]:plane.logistics.air_lift=0;plane.is_air=false
		if reason=="land_then_death":plane.receive_hit(1000000,"bullet",{},gun)
		if reason=="death":plane.receive_hit(1000000,"bullet",{},gun)
		if reason=="owner_death":gun.receive_hit(1000000,"bullet",{},neighbor)
		if reason=="friendly":plane.side="ally"
		Infantry.world_tick(battle,.8)
		check((neighbor.hp<100000)==(reason in ["death","owner_death"]) and rows().is_empty(),"pending shard lifecycle "+reason)
		await finish()

func transfer_boundaries() -> void:
	setup_rank(3)
	var gun:=actor("SHK","ally",Vector2(1100,1200));var victim:=actor("E2","enemy",Vector2(1200,1200));victim.hp=1
	var kept:=charge(gun)*.5;normal_shot(gun,victim);X.tick(gun,5)
	check(is_equal_approx(Infantry.state(gun).get("transfer_damage",0),kept),"unused transfer remains at old five-second limit")
	var statuses:=Infantry.entries(gun).filter(func(row):return row.text.contains("蓄电转储"))
	check(statuses.size()==1 and not statuses[0].timed and statuses[0].text.contains("永久储存"),"stored charge status has no expiry countdown")
	check(Demo.sample("reserve_transfer",3,6.99).active and not Demo.sample("reserve_transfer",3,7.01).active,"demo holds charge past old limit until actual next attack")
	gun.side="enemy";X.tick(gun,.01)
	check(not gun.special.has(Second.KEY),"ownership change clears reserve carry")
	await finish()

func transfer_comparison(level:int) -> void:
	for layers in [0,1,2]:
		setup_rank(level)
		var gun:=actor("SHK","ally",Vector2(1100,1200));var victim:=actor("E2","enemy",Vector2(1200,1200));victim.hp=1
		var rule:=Reserve.rule(gun)
		Reserve.tick(gun,rule.interval*rule.limit)
		check(normal_shot(gun,victim) and victim._dead,"full native charge kills through actual primary")
		var carry:float=1.5*[.2,.3,.4,.5][level]
		check(is_equal_approx(Infantry.state(gun).get("transfer_damage",0),carry),"full-charge carry equals demonstrated tier "+str(level))
		if layers>0:Reserve.tick(gun,rule.interval*layers)
		var target:=durable("HTNK","enemy",Vector2(1200,1200))
		var expected:=damage_for(gun,target,1+maxf(carry,layers*.5))
		normal_shot(gun,target)
		check(is_equal_approx(100000-target.hp,expected) and not Infantry.state(gun).has("transfer_damage"),"real primary chooses stored/new-charge maximum "+str(level)+" layers "+str(layers),[100000-target.hp,expected])
		await finish()

func movement_boundaries() -> void:
	setup_rank(3)
	var gun:=actor("E2","ally",Vector2(1100,1200))
	for frame in 30:gun.hull_angle+=.1;gun.velocity=Vector2.RIGHT*50;X.tick(gun,.1)
	gun.velocity=Vector2.ZERO;X.tick(gun,.01)
	check(not Infantry.state(gun).has("advance_left"),"turning or fake velocity without displacement cannot charge movement")
	move_for(gun,1);X.tick(gun,.1);move_for(gun,1)
	check(not Infantry.state(gun).has("advance_left"),"separated one-second moves do not combine")
	var owner:=actor("E2","ally",Vector2(1000,1200))
	gun.special.expansion_temporary={"kind":"twin","left":100.0,"owner":owner};move_for(gun,2)
	check(not Infantry.state(gun).has("advance_left"),"summoned infantry cannot inherit advance")
	await finish()

func primary_boundaries() -> void:
	setup_rank(3)
	var gun:=actor("SHK","ally",Vector2(1100,1200));var main:=durable("HTNK","enemy",Vector2(1200,1200));var branch:=actor("E2","enemy",Vector2(1220,1230));branch.hp=1
	BattleRequest.combat_context.card_ranks.ap_tesla_chain=3
	var ab:=ability(gun,"ap_tesla_chain")
	check(gun.use_ability(gun.skills.size()-1),"existing W activates alongside reserve transfer")
	charge(gun);normal_shot(gun,main)
	check(branch._dead and not Infantry.state(gun).has("transfer_damage"),"real W branch kill does not transfer native reserve")
	var extra:=charge(gun);main.hp=1;normal_shot(gun,main)
	check(is_equal_approx(Infantry.state(gun).get("transfer_damage",0),extra*.5),"W primary damage does not inflate transferred native extra")
	await finish()
	for id in ["SNIPE","SHK"]:
		for kind in ["extra","temporary","friendly","unowned"]:
			setup_rank(3)
			gun=actor(id,"ally",Vector2(1100,1200));var target:=actor("E2","enemy",Vector2(1200,1200));target.hp=1
			if id=="SHK":charge(gun)
			if kind=="temporary":target.special.expansion_temporary={"kind":"twin","left":100.0,"owner":gun}
			if kind=="friendly":target.side="ally"
			if kind=="unowned":BattleRequest.combat_context.unit_talents[id].erase(Infantry.TALENTS[id])
			if kind=="extra":target.receive_hit(1000,"bullet",{"expansion_origin":gun.position,"expansion_extra":true},gun)
			elif kind=="friendly":gun.attack_target=target;gun._fire_shot(target);fly_missiles(gun)
			else:normal_shot(gun,target);fly_missiles(gun)
			check(not Infantry.state(gun).has("transfer_damage") and not Infantry.state(gun).has("relocate_left"),"kill reward excludes "+id+" "+kind)
			await finish()

func advance_boundaries() -> void:
	setup_rank(3)
	var gun:=actor("E2","ally",Vector2(1100,1200));var companion:=actor("E2","ally",Vector2(1100,1300));var target:=durable("HTNK","enemy",Vector2(1250,1200))
	var base:float=gun.bonuses.attack_bonus
	gun.add_buff("attack",20,.2,"existing attack boost");move_for(gun,2)
	for repeat in 10:gun._recompute_bonuses()
	check(is_equal_approx(gun.bonuses.attack_bonus,base*1.2*1.25) and not Infantry.state(companion).has("advance_left"),"advance multiplies existing attack buff once and does not buff another infantry")
	X.tick(gun,4.99);normal_shot(gun,target);var reload:float=gun._cd_timer
	check(Infantry.advancing(gun),"both benefits remain active just before five seconds")
	X.tick(gun,.01)
	check(is_equal_approx(gun.bonuses.attack_bonus,base*1.2) and gun._cd_timer==reload,"expiry removes only advance attack and does not rewrite reload already started")
	X.tick(gun,5);move_for(gun,2);gun.side="enemy";X.tick(gun,.01)
	check(not Infantry.advancing(gun) and is_equal_approx(gun.bonuses.attack_bonus,base*1.2),"capture clears advance benefit without stripping independent buff")
	await finish()
	setup_rank(3)
	gun=actor("E2","ally",Vector2(1100,1200));X.tick(gun,.01)
	for step in 20:gun.position+=Vector2(5,0);X.tick(gun,.1)
	gun._stun_timer=1;X.tick(gun,.01)
	check(not Infantry.state(gun).has("advance_left"),"being stunned after movement does not count as voluntary stop activation")
	gun._stun_timer=0;X.tick(gun,.01)
	check(not Infantry.state(gun).has("advance_left"),"control expiry does not revive interrupted movement credit")
	await finish()

func isolation() -> void:
	start(MatchRules.RA2)
	for id in Infantry.TALENTS:
		BattleRequest.combat_context.unit_talents[id]={Infantry.TALENTS[id]:3}
		var gun:=actor(id,"ally",Vector2(1100,1200))
		check(not Infantry.eligible(gun),"classic isolation "+id)
	await finish()
