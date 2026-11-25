extends "res://tests/progression_expansion_2_regression.gd"
const Naval=preload("res://scripts/units/expansion_2_naval.gd")
const Auto=preload("res://scripts/units/auto_w.gd")

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
	await get_tree().process_frame
	MetaProgress.reset_save()
	for level in 4:
		await water(level)
		for id in ["DEST","HYD","AEGIS"]:await ballast(level,id)
	await water_boundaries()
	await automatic()
	await carrier_cycle()
	await classic_ships()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	print("EXPANSION_2_NAVAL_RESULT ",checks.size()," checks, ",failed," failed")
	get_tree().quit(0 if failed==0 else 1)

func setup(level:int) -> void:
	start(MatchRules.EXTENDED);battle.fog=null
	BattleRequest.combat_context.card_ranks[Naval.WATER]=level;BattleRequest.combat_context.card_ranks[Naval.BALLAST]=level

func make(id:String,side:String,at:Vector2,card:="") -> Unit:
	if not card.is_empty():BattleRequest.combat_context.loadouts[id]={"active":[card],"passive":""}
	var unit:Unit=battle.spawn_unit(id,side,at);unit.max_hp=100000;unit.hp=100000
	return unit

func w(unit) -> Ability:
	return unit.ability_at(UnitSkillLayout.index(unit,1))

func cast(unit) -> bool:
	return unit.use_ability(UnitSkillLayout.index(unit,1))

func direct_loss(unit,source,bonus:Dictionary={},kind:="shell") -> float:
	var before:float=unit.hp
	unit.receive_hit(1000,kind,bonus,source)
	return before-unit.hp

func water(level:int) -> void:
	setup(level)
	var ship:=make("DEST","ally",Vector2(1100,1200),Naval.WATER)
	var close:=make("HYD","ally",Vector2(1140,1200));var next:=make("AEGIS","ally",Vector2(1180,1200));var third:=make("DRED","ally",Vector2(1200,1200))
	var enemy:=make("HTNK","enemy",Vector2(1250,1200))
	var before:float=ship.hp;check(normal_shot(enemy,ship),"native enemy gun fires at ship");fly_missiles(enemy);var base:float=before-ship.hp
	var target_before=ship.attack_target;ship._cd_timer=2;ship.has_move_order=true;ship.move_target=Vector2(1300,1400)
	check(cast(ship) and w(ship).cd_left==35,"water real W casts and starts cooldown "+str(level))
	check(ship.attack_target==target_before and ship._cd_timer==2 and ship.has_move_order and ship.move_target==Vector2(1300,1400),"water preserves weapon cycle and movement order")
	check(Naval.guard(ship)>0 and Naval.guard(close)>0 and Naval.guard(next)>0 and Naval.guard(third)==0,"water protects caster and only nearest two")
	before=ship.hp;normal_shot(enemy,ship);fly_missiles(enemy)
	var fraction:float=[.12,.16,.2,.24][level]
	check(base>0 and absf((before-ship.hp)-Ra2Damage.quantize(base*(1-fraction)))<=1,"native ordinary hit receives exact rank water reduction "+str(level),[base,before-ship.hp])
	check(is_equal_approx(direct_loss(close,enemy),1000*(1-fraction)),"recipient consumes same real damage protection")
	check(direct_loss(close,enemy,{"expansion_extra":true})==1000,"skill damage bypasses ordinary ranged water")
	close.position+=Vector2(1000,0);X.tick(close,1.5)
	check(Naval.guard(close)>0 and Naval.guard(third)==0,"chosen recipient retains effect after departure without replacement")
	var snapshot:Dictionary=BattleSaves.Snapshot.new().capture(battle);BattleSaves.Snapshot.new().restore(battle,snapshot)
	for unit in battle.units:
		if unit.unit_id=="HYD":close=unit
		elif unit.unit_id=="DEST":ship=unit
	check(is_equal_approx(float(Naval.state(close).water_guards[0].left),2.5) and w(ship).cd_left==35,"snapshot restores recipient remaining time and caster cooldown")
	X.tick(close,2.49);check(Naval.guard(close)>0,"water still active just before expiry")
	X.tick(close,.01);check(Naval.guard(close)==0,"water expires exactly at four seconds")
	await finish()

func ballast(level:int,id:String) -> void:
	setup(level)
	var ship:=make(id,"ally",Vector2(1100,1200),Naval.BALLAST)
	var target:=make("JUMPJET" if id=="AEGIS" else "DEST","enemy",Vector2(1220,1200))
	check(normal_shot(ship,target),"native ship reference volley "+id);var base:float=ship._cd_timer
	var speed:float=ship.move_speed
	ship._cd_timer=2.0
	check(cast(ship) and w(ship).cd_left==26 and ship._cd_timer==2.0,"ballast does not rewrite running reload "+id+str(level))
	check(is_equal_approx(ship.move_speed,speed*.85) and ship.attack_target==target,"ballast slows ship without changing target")
	var fraction:float=[.2,.25,.3,.35][level]
	for shot in 2:
		check(normal_shot(ship,target) and base>0 and is_equal_approx(ship._cd_timer,base*(1-fraction)),"each native volley gets new shorter reload "+id+str(level)+str(shot),[base,ship._cd_timer])
	check(direct_loss(ship,target)==1050 and direct_loss(ship,target,{"expansion_extra":true})==1000,"ballast takes five percent more ordinary damage only")
	X.tick(ship,1)
	var snapshot:Dictionary=BattleSaves.Snapshot.new().capture(battle);BattleSaves.Snapshot.new().restore(battle,snapshot)
	for unit in battle.units:
		if unit.side=="ally" and unit.unit_id==id:ship=unit
		elif unit.side=="enemy":target=unit
	check(Naval.state(ship).ballast_left==3 and w(ship).cd_left==26 and is_equal_approx(ship.move_speed,speed*.85),"snapshot restores ballast without double speed penalty")
	X.tick(ship,2.99);check(is_equal_approx(ship.move_speed,speed*.85),"ballast active at 3.99 seconds")
	X.tick(ship,.01);check(is_equal_approx(ship.move_speed,speed) and not Naval.state(ship).has("ballast_left"),"ballast speed restores at four seconds")
	check(normal_shot(ship,target) and is_equal_approx(ship._cd_timer,base) and direct_loss(ship,target)==1000,"normal reload and defense resume after expiry")
	check(Auto.supported(Naval.BALLAST) and not Auto.hint(Naval.BALLAST).is_empty(),"ballast exposes conditional automatic tradeoff policy")
	await finish()

func water_boundaries() -> void:
	setup(3)
	var ship:=make("DEST","ally",Vector2(1100,1200),Naval.WATER)
	var excluded:Array=[]
	for id in ["SUB","DLPH","SQD","LCRF","ASW","HTNK"]:excluded.append(make(id,"ally",Vector2(1110,1200)))
	var temporary:=make("HYD","ally",Vector2(1110,1200));temporary.special.expansion_temporary={"kind":"mirror","owner":ship,"left":10};excluded.append(temporary)
	var enemy:=make("HYD","enemy",Vector2(1110,1200));excluded.append(enemy)
	var far:=make("AEGIS","ally",Vector2(1211,1200));excluded.append(far)
	var healthy:=make("AEGIS","ally",Vector2(1190,1200));var hurt:=make("HYD","ally",Vector2(1190,1200));hurt.hp-=100
	var closest:=make("CARRIER","ally",Vector2(1140,1200))
	check(cast(ship),"water casts with excluded nearby units")
	check(excluded.all(func(unit):return Naval.guard(unit)==0),"water excludes submarines transports aircraft ground enemies temporary and beyond two cells")
	check(Naval.guard(closest)>0 and Naval.guard(hurt)>0 and Naval.guard(healthy)==0,"distance picks carrier and equal-distance injured companion")
	X.tick(hurt,2);BattleRequest.combat_context.card_ranks[Naval.WATER]=0;w(ship).cd_left=0;cast(ship)
	check(is_equal_approx(Naval.guard(hurt),.24),"overlapping water uses stronger effect once")
	X.tick(hurt,2);check(is_equal_approx(Naval.guard(hurt),.12),"strong water expires without extending its life through weaker cast")
	hurt.side="enemy";X.tick(hurt,.01);check(Naval.guard(hurt)==0,"capture clears recipient water")
	var ballast_ship:=make("HYD","ally",Vector2(1400,1200),Naval.BALLAST);var speed:float=ballast_ship.move_speed
	ballast_ship._stun_timer=1;check(not cast(ballast_ship) and w(ballast_ship).cd_left==0,"stun blocks ballast without consuming cooldown")
	ballast_ship._stun_timer=0;cast(ballast_ship);ballast_ship.side="enemy";X.tick(ballast_ship,.01)
	check(is_equal_approx(ballast_ship.move_speed,speed) and not ballast_ship.special.has(Second.KEY),"capture clears ballast and recomputes movement")
	await finish()

func automatic() -> void:
	setup(0)
	var ship:=make("DEST","ally",Vector2(1100,1200),Naval.WATER);var enemy:=make("HYD","enemy",Vector2(1250,1200))
	battle.production_technology.unlock(Auto.TECH,"ally");battle.paused=false;get_tree().paused=false
	check(not Auto.evaluate(ship),"Auto water does not spend cooldown while unhurt")
	direct_loss(ship,ship);check(not Auto.evaluate(ship),"friendly or self damage cannot trigger water")
	direct_loss(ship,enemy);X.tick(ship,2);check(not Auto.evaluate(ship),"damage older than two seconds cannot trigger water")
	direct_loss(ship,enemy);ship._cd_timer=3;ship.attack_target=enemy;ship.has_move_order=true;ship.move_target=Vector2(1300,1200)
	check(Auto.evaluate(ship) and w(ship).cd_left==35 and Naval.guard(ship)>0,"recent enemy damage Auto casts the actual equipped W")
	check(ship._cd_timer==3 and ship.attack_target==enemy and ship.has_move_order and ship.move_target==Vector2(1300,1200),"automatic defense preserves attack and movement orders")
	check(not Auto.evaluate(ship),"Auto cannot double cast")
	check(Auto.set_group(battle,[ship],false),"ship Auto toggle saves")
	w(ship).cd_left=0;check(not Auto.evaluate(ship),"disabled Auto cannot spend skill")
	var snapshot:Dictionary=BattleSaves.Snapshot.new().capture(battle);BattleSaves.Snapshot.new().restore(battle,snapshot)
	for unit in battle.units:if unit.unit_id=="DEST":ship=unit
	check(not Auto.enabled(ship) and Naval.guard(ship)>0,"save preserves Auto toggle and active defense independently")
	await finish()

func carrier_cycle() -> void:
	setup(3)
	var ship:=make("DEST","ally",Vector2(1100,1200),Naval.BALLAST)
	var target:=make("SUB","enemy",Vector2(1200,1200));ship.attack_target=target;ship.attack_ordered=true
	check(ship.logistics.squadron.size()==1,"destroyer retains native single osprey berth")
	var slot:Dictionary=ship.logistics.squadron[0];slot.timer=10.0
	cast(ship);ship.logistics.tick_squadron(1.0)
	check(is_equal_approx(float(slot.timer),9.0) and w(ship).cd_left==26,"ballast does not accelerate native osprey replacement or W cooldown")
	X.tick(ship,4.0);ship.logistics.tick_squadron(1.0)
	check(is_equal_approx(float(slot.timer),8.0),"osprey replacement continues normally after ballast ends")
	await finish()

func classic_ships() -> void:
	start(MatchRules.RA2)
	var ship:=make("DEST","ally",Vector2(1100,1200))
	var skill:=ability(ship,Naval.WATER)
	check(not Second.cast(ship,skill) and skill.cd_left==0 and not ship.special.has(Second.KEY),"classic mode cannot activate extension water")
	await finish()
