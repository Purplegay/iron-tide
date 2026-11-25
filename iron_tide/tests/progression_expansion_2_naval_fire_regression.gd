extends "res://tests/progression_expansion_2_naval_regression.gd"
const Fire=preload("res://scripts/units/expansion_2_naval_fire.gd")

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
	await get_tree().process_frame
	MetaProgress.reset_save()
	for level in 4:
		await crossfire(level)
		await ranging(level)
	await cross_boundaries()
	await gauge_boundaries()
	await fog_growth_and_save()
	await save_and_ownership()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	print("EXPANSION_2_NAVAL_FIRE_RESULT ",checks.size()," checks, ",failed," failed")
	get_tree().quit(0 if failed==0 else 1)

func prepare(level:int) -> void:
	setup(level)
	BattleRequest.combat_context.card_ranks[Fire.CROSS]=level
	BattleRequest.combat_context.unit_talents.AEGIS={Fire.GAUGE:level}
	BattleRequest.combat_context.loadouts.HYD={"active":[],"passive":Fire.CROSS}

func extra(ship) -> Array:
	return missiles(ship).filter(func(p):return p.attacker_bonus.get("expansion_extra",false))

func crossfire(level:int) -> void:
	prepare(level)
	var ship:=make("HYD","ally",Vector2(1100,1200))
	var air:=make("JUMPJET","enemy",Vector2(1240,1200))
	var sea:=make("DEST","enemy",Vector2(1260,1200))
	var far:=make("HYD","enemy",Vector2(1390,1200))
	var fraction:float=[.4,.5,.6,.75][level]
	var interval:float=[4,3.5,3,2.5][level]
	ship.passive={};check(normal_shot(ship,air),"reference ordinary AA volley");var base:float=ship._cd_timer;fly_missiles(ship)
	ship.passive=GameData.get_skill(Fire.CROSS)
	ship.has_move_order=true;ship.move_target=Vector2(1800,1200)
	var before:float=sea.hp
	check(normal_shot(ship,air),"cross native AA trigger rank "+str(level))
	check(Fire.state(ship).get("cross_cd",0)==interval,"rank shared cooldown starts on discharge")
	check(ship.attack_target==air and ship._cd_timer==base and ship.has_move_order and ship.move_target==Vector2(1800,1200),"cross preserves primary reload and orders")
	var shots:=extra(ship)
	check(shots.size()==1,"one real supplementary projectile",shots.size())
	if not shots.is_empty():
		check(shots[0].target==sea and is_equal_approx(shots[0].base_damage,float(ship._weapon_for_target(sea).damage)*fraction),"nearest surface uses correct ground weapon rank damage")
		check(shots[0].attacker_bonus.expansion_extra and not shots[0].attacker_bonus.has("expansion_volley"),"supplement excludes additional-attack callbacks")
	ship._fire_shot(air);check(extra(ship).size()==1,"same-volley extra native bullet never repeats supplement")
	fly_missiles(ship)
	check(sea.hp<before and far.hp==100000,"real supplementary shell damages chosen vessel only",[before,sea.hp,far.hp])
	check(normal_shot(ship,sea) and extra(ship).is_empty(),"domain switch does not bypass shared cooldown");fly_missiles(ship)
	X.tick(ship,interval-.01);normal_shot(ship,sea);check(extra(ship).is_empty(),"interval remains closed just before expiry");fly_missiles(ship)
	X.tick(ship,.02);before=air.hp;check(normal_shot(ship,sea),"native surface volley after cooldown")
	# Native FlakProj is Inviso: it detonates in ready and is already queued for deletion.
	shots=ship._pick_projectile_parent().get_children().filter(func(p):return p is Projectile and p.shooter()==ship and p.target==air and p.attacker_bonus.get("expansion_extra",false))
	check(shots.size()==1 and shots[0].ra2_inviso and air.hp<before,"surface primary generates native instant AA supplement",[shots.size(),before,air.hp])
	if not shots.is_empty():check(is_equal_approx(shots[0].base_damage,float(ship._weapon_for_target(air).damage)*fraction),"AA supplement uses its own weapon damage")
	fly_missiles(ship)
	check(Fire.entries(ship).size()>0,"cross shared cooldown visible in status")
	await finish()

func ranging(level:int) -> void:
	prepare(level)
	var ship:=make("AEGIS","ally",Vector2(1100,1200))
	var target:=make("JUMPJET","enemy",Vector2(1240,1200))
	var base:=0.0
	for round in 3:
		check(normal_shot(ship,target),"native AEGIS acquisition "+str(level)+"/"+str(round))
		if round==0:base=ship._cd_timer
		check(ship._cd_timer==base,"three acquisition cycles retain native reload")
		ship._fire_shot(target);fly_missiles(ship)
		check(Fire.state(ship).get("gauge_hits",[]).size()==round+1 if round<2 else Fire.state(ship).get("gauge_charges",0)==2,"two missiles count once per volley",Fire.state(ship).duplicate())
	var fraction:float=[.1,.15,.2,.25][level]
	for credit in 2:
		check(normal_shot(ship,target) and is_equal_approx(ship._cd_timer,base*(1-fraction)),"both new reloads discounted "+str(level)+"/"+str(credit),[base,ship._cd_timer])
		ship._fire_shot(target);fly_missiles(ship)
		check(Fire.state(ship).get("gauge_charges",0)==1-credit and Fire.state(ship).get("gauge_hits",[]).is_empty(),"discounted salvo never precharges new cycle")
	check(normal_shot(ship,target) and ship._cd_timer==base,"third subsequent reload normal again");fly_missiles(ship)
	check(Fire.state(ship).gauge_hits.size()==1 and Fire.entries(ship).size()>0,"after credit exhausted next ordinary hit starts at one with status")
	await finish()

func cross_boundaries() -> void:
	prepare(3)
	var ship:=make("HYD","ally",Vector2(1100,1200));var air:=make("JUMPJET","enemy",Vector2(1240,1200))
	var sub:=make("SUB","enemy",Vector2(1220,1200));var land:=make("HTNK","enemy",Vector2(1210,1200))
	var sea:=make("DEST","enemy",Vector2(2100,1200));var friend:=make("DEST","ally",Vector2(1200,1200))
	check(normal_shot(ship,air) and not Fire.state(ship).has("cross_cd"),"no legal second domain excludes sub ground ally and out-of-range without consuming cooldown");fly_missiles(ship)
	sea.position=Vector2(1260,1200);sea.embarked_in=friend
	normal_shot(ship,air);check(not Fire.state(ship).has("cross_cd"),"embarked enemy target invalid without cooldown");fly_missiles(ship)
	sea.embarked_in=null
	ship.special.chrono_left=3;Fire.state(ship).erase("cross_volley");Fire.firing(ship,air)
	check(not Fire.state(ship).has("cross_cd"),"frozen firing source cannot supplement");ship.special.erase("chrono_left")
	ship._stun_timer=1;Fire.state(ship).erase("cross_volley");Fire.firing(ship,air)
	check(not Fire.state(ship).has("cross_cd"),"stunned source cannot supplement");ship._stun_timer=0
	Fire.state(ship).erase("cross_volley");Fire.firing(ship,land)
	check(not Fire.state(ship).has("cross_cd"),"shore primary cannot trigger cross-domain fire")
	ship.special.expansion_temporary={"kind":"mirror","owner":friend,"left":10};normal_shot(ship,air)
	check(not Fire.state(ship).has("cross_cd"),"temporary ship cannot inherit supplementary attacks");fly_missiles(ship);ship.special.erase("expansion_temporary")
	sea.add_buff("dodge",10,.95,"test dodge");seed(101)
	normal_shot(ship,air);check(Fire.state(ship).has("cross_cd") and extra(ship).is_empty(),"supplement can miss and still consumes trigger interval");fly_missiles(ship)
	await finish()
	start(MatchRules.RA2);battle.fog=null
	ship=make("HYD","ally",Vector2(1100,1200));ship.passive=GameData.get_skill(Fire.CROSS)
	air=make("JUMPJET","enemy",Vector2(1240,1200));sea=make("DEST","enemy",Vector2(1260,1200))
	normal_shot(ship,air);check(extra(ship).is_empty() and not ship.special.has(Fire.KEY),"classic mode never adds crossfire")
	await finish()

func gauge_boundaries() -> void:
	prepare(3)
	var ship:=make("AEGIS","ally",Vector2(1100,1200));var a:=make("JUMPJET","enemy",Vector2(1240,1200));var b:=make("JUMPJET","enemy",Vector2(1260,1200))
	normal_shot(ship,a);var projectile=missiles(ship)[0]
	var bonus:Dictionary=projectile.attacker_bonus.duplicate(true)
	for field in ["expansion_extra","equipment_secondary","expansion_scatter"]:
		var excluded:=bonus.duplicate(true);excluded[field]=true;Fire.damaged(ship,a,projectile,10,excluded)
		check(Fire.state(ship).get("gauge_hits",[]).is_empty(),"excluded gauge source "+field)
	Fire.damaged(ship,b,projectile,10,bonus);Fire.damaged(ship,a,projectile,0,bonus)
	check(Fire.state(ship).get("gauge_hits",[]).is_empty(),"splash and zero damage do not count")
	ship.attack_target=b;X.tick(ship,.01);fly_missiles(ship)
	check(Fire.state(ship).get("gauge_hits",[]).is_empty(),"late missiles after retarget cannot seed new chain")
	for i in 3:normal_shot(ship,b);fly_missiles(ship)
	check(Fire.state(ship).get("gauge_charges",0)==2,"new target earns its own two reloads")
	ship.attack_target=a;X.tick(ship,.01)
	check(Fire.state(ship).gauge_charges==0,"retarget clears remaining discount")
	for i in 2:normal_shot(ship,a);fly_missiles(ship)
	a.hp=0;X.tick(ship,.01)
	check(Fire.state(ship).gauge_hits.is_empty(),"target death clears acquisition")
	await finish()

func save_and_ownership() -> void:
	prepare(3)
	var ship:=make("AEGIS","ally",Vector2(1100,1200));var target:=make("JUMPJET","enemy",Vector2(1240,1200))
	for i in 2:normal_shot(ship,target);fly_missiles(ship)
	normal_shot(ship,target)
	var snapshot:Dictionary=BattleSaves.Snapshot.new().capture(battle);BattleSaves.Snapshot.new().restore(battle,snapshot)
	for unit in battle.units:
		if unit.unit_id=="AEGIS":ship=unit
		else:target=unit
	check(Fire.state(ship).gauge_hits.size()==2 and Fire.state(ship).gauge_target==target,"save restores two hits and referenced target")
	fly_missiles(ship)
	check(Fire.state(ship).gauge_charges==2,"saved in-flight third missile grants two credits")
	var base:float=ship.cooldown
	check(normal_shot(ship,target) and is_equal_approx(ship._cd_timer,base*.75),"restored third hit affects only next new reload");fly_missiles(ship)
	snapshot=BattleSaves.Snapshot.new().capture(battle);BattleSaves.Snapshot.new().restore(battle,snapshot)
	for unit in battle.units:
		if unit.unit_id=="AEGIS":ship=unit
		else:target=unit
	check(Fire.state(ship).gauge_charges==1 and is_equal_approx(ship._cd_timer,base*.75),"save preserves one remaining credit without reducing running reload twice")
	check(normal_shot(ship,target) and is_equal_approx(ship._cd_timer,base*.75),"last saved credit discounts exactly once");fly_missiles(ship)
	ship.side="enemy";X.tick(ship,.01);check(not ship.special.has(Fire.KEY),"ownership change clears targeting and credit")
	await finish()
	MetaProgress.currency.cores=100000
	var offer:=MetaProgress.talent_unlock_quote("AEGIS",Fire.GAUGE)
	check(MetaProgress.unlock_unit_talent("AEGIS",Fire.GAUGE,offer.get("cost",-1)),"new AEGIS talent actual unlock")
	for rank in 3:check(MetaProgress.upgrade_talent("AEGIS",Fire.GAUGE,rank),"actual AEGIS upgrade "+str(rank))
	MetaProgress.load_save()
	check(MetaProgress.talent_rank("AEGIS",Fire.GAUGE,MetaProgress.unit_talents)==3,"AEGIS permanent rank survives reload")

func fog_growth_and_save() -> void:
	prepare(3)
	var ship:=make("HYD","ally",Vector2(1100,1200))
	var air:=make("JUMPJET","enemy",Vector2(1240,1200))
	var sea:=make("DEST","enemy",Vector2(1340,1200))
	BattleRequest.skirmish_config.fog_of_war=true
	var fog=preload("res://scripts/world/fog_of_war.gd").new();battle.add_child(fog);fog.setup(battle);battle.fog=fog
	fog.visible_cells.ally.fill(0);fog.explored_cells.ally.fill(0)
	fog.visible_cells.ally[fog._index(air.position)]=1;fog.explored_cells.ally[fog._index(air.position)]=1
	check(normal_shot(ship,air) and not Fire.state(ship).has("cross_cd"),"real fog hides opposite-domain target without consuming trigger");fly_missiles(ship)
	fog.visible_cells.ally[fog._index(sea.position)]=1;fog.explored_cells.ally[fog._index(sea.position)]=1
	ship.veteran_level=2;ship._refresh_weapon_derived();ship._recompute_bonuses();ship.add_buff("attack",10,.25,"growth")
	check(normal_shot(ship,air),"elite vessel fires against visible primary")
	var shots:=extra(ship)
	check(shots.size()==1,"revealed secondary receives one native projectile")
	if not shots.is_empty():
		var weapon:Dictionary=ship._weapon_for_target(sea).duplicate(true);weapon.damage=float(weapon.damage)*.75
		var expected:=CombatMath.full_damage(weapon,sea.armor,ship.bonuses,null,sea.ra2_armor,0.0,sea)
		check(is_equal_approx(shots[0].damage,expected) and shots[0].attacker_bonus.get("veteran_firepower",1)==ship.bonuses.get("veteran_firepower",1),"supplement preserves current veteran and attack-buff growth",[shots[0].damage,expected])
	fly_missiles(ship)
	X.tick(ship,.75)
	var snapshot:Dictionary=BattleSaves.Snapshot.new().capture(battle);BattleSaves.Snapshot.new().restore(battle,snapshot)
	for unit in battle.units:
		if unit.unit_id=="HYD":ship=unit
		elif unit.unit_id=="JUMPJET":air=unit
		else:sea=unit
	check(is_equal_approx(float(Fire.state(ship).get("cross_cd",0)),1.75),"snapshot preserves remaining shared trigger cooldown")
	battle.fog=null
	normal_shot(ship,air);check(extra(ship).is_empty(),"restored cooldown prevents duplicate supplement");fly_missiles(ship)
	X.tick(ship,1.76);normal_shot(ship,air);check(extra(ship).size()==1,"restored cooldown eventually permits next real volley");fly_missiles(ship)
	ship.side="enemy";X.tick(ship,.01);check(not ship.special.has(Fire.KEY),"capture clears former-owner crossfire cooldown")
	await finish()
