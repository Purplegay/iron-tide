extends "res://tests/boris_sortie_regression.gd"
const Command=preload("res://scripts/units/boris_command.gd")

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
	await get_tree().process_frame
	await purchases()
	await suppression()
	await focus()
	await relay_and_save()
	await boundaries()
	await command_resume_and_cap()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	print("BORIS_COMMAND_RESULT ",checks.size()," checks, ",failed," failed")
	get_tree().quit(0 if failed==0 else 1)

func command_hero(level:int):
	var hero=setup_boris();hero.special.hero_command_rank=level
	return hero

func shots_from(unit,target) -> Array:
	unit.attack_target=target;unit.attack_ordered=true;unit.has_move_order=false
	unit.hull_angle=unit.position.direction_to(target.position).angle();unit.turret_angle=unit.hull_angle;unit._cd_timer=0;unit._burst_left=0
	check(unit._try_fire_ready(),"real ordinary fire succeeds "+unit.unit_id)
	return battle.projectiles_root.get_children().filter(func(shot):return shot is Projectile and is_same(shot.shooter(),unit) and is_same(shot.target,target) and not shot._detonated)

func fire_at(unit,target) -> void:
	for shot in shots_from(unit,target):shot._explode()

func purchases() -> void:
	MetaProgress.reset_save();MetaProgress.academy.hero_builds={"BORIS":5}
	var page=load("res://scripts/ui/hero_progression.gd").new();add_child(page);page.selected="BORIS"
	for level in 5:
		var price:int=[40,120,240,400,600][level]
		MetaProgress.currency.cores=price-1;page.refresh()
		check(A.hero_talent_cost("escort",level,"BORIS")==price and page.escort.disabled,"five-tier quote and insufficient wallet UI")
		check(not A.purchase(MetaProgress,"escort","BORIS") and MetaProgress.balance("cores")==price-1,"insufficient purchase cannot debit")
		MetaProgress.currency.cores=price;page.refresh();page.escort.pressed.emit()
		check(MetaProgress.balance("cores")==0 and MetaProgress.academy.hero_escort_ranks.BORIS==level+1,"real UI purchases next functional command level")
		MetaProgress.load_save();check(MetaProgress.academy.hero_escort_ranks.BORIS==level+1,"purchased command rank survives disk profile reload")
	MetaProgress.currency.cores=1000;page.refresh()
	check(page.escort.disabled and not A.purchase(MetaProgress,"escort","BORIS") and MetaProgress.balance("cores")==1000,"rank five hard cap cannot charge again")
	check(not page.survival.disabled and page.survival_detail.text.contains("最后电令"),"completed defense path is available independently")
	page.talent_demo.talent.select(0);page.talent_demo._select_talent()
	check(page.talent_demo.levels.item_count==6 and page.escort_detail.text.contains("双目标空袭"),"all command nodes and demo selections are available")
	page.talent_demo.talent.select(1);page.talent_demo._select_talent()
	check(page.talent_demo.levels.item_count==6,"defense preview exposes its six implemented levels")
	page.free();await get_tree().process_frame
	boot("BORIS");MetaProgress.academy.hero_escort_ranks.BORIS=0
	var hero=battle.spawn_unit("BORIS","ally",Vector2(1050,1000));A.promote(MetaProgress,battle,"BORIS",hero)
	check(Sortie.rank(hero)==5,"command rank freezes at match opening")
	await finish()

func suppression() -> void:
	var hero=command_hero(1);var enemy=robust_enemy("HTNK",hero.position+Vector2(100,0))
	var in_flight:=shots_from(enemy,hero)
	check(not in_flight.is_empty(),"native ground cannon leaves a real in-flight projectile")
	for i in 2:fire_at(hero,enemy);check(not Command.suppressed(enemy),"first two rifle hits do not suppress")
	enemy.has_move_order=true;enemy.move_target=enemy.position+Vector2(0,100)
	fire_at(hero,enemy)
	check(Command.suppressed(enemy) and not enemy._try_fire_ready(),"third direct rifle hit blocks actual firing")
	check(enemy.has_move_order and enemy.move_target==enemy.position+Vector2(0,100),"suppression keeps movement order")
	var hp:float=hero.hp
	for shot in in_flight:shot._explode()
	check(hero.hp<hp,"already launched enemy projectile still damages Boris")
	Command.tick(enemy,1.01)
	check(not Command.suppressed(enemy) and enemy.special[Command.KEY].has("suppression_cd"),"one-second fire lock ends while shared eight-second interval remains")
	for i in 3:fire_at(hero,enemy)
	check(not Command.suppressed(enemy),"repeated rifle triple cannot bypass target interval")
	Command.tick(enemy,7.0)
	var other=robust_enemy("E2",hero.position+Vector2(90,40))
	fire_at(hero,enemy);fire_at(hero,other);fire_at(hero,enemy);fire_at(hero,enemy)
	check(not Command.suppressed(enemy),"hitting another unit breaks consecutive-target streak")
	fire_at(hero,enemy);check(Command.suppressed(enemy),"three new consecutive hits suppress again")
	check(Command.entries(enemy).size()>0,"suppression is visible in status entries")
	await finish()

func focus() -> void:
	var hero=command_hero(4);var enemy=robust_enemy("HTNK",hero.position+Vector2(100,0))
	var soldier=battle.spawn_unit("E2","ally",hero.position+Vector2(0,30))
	var gun:Dictionary=soldier._weapon_for_target(enemy)
	var normal:=CombatMath.full_damage(gun,enemy.armor,soldier.bonuses,null,enemy.ra2_armor)
	fire_at(hero,enemy)
	check(enemy.special[Command.KEY].focus.charges==3,"Boris rifle attaches three-use focus mark")
	fire_at(hero,enemy)
	check(enemy.special[Command.KEY].focus.charges==3,"Boris never consumes own focus mark")
	for i in 3:
		var hp:float=enemy.hp;fire_at(soldier,enemy)
		check(is_equal_approx(hp-enemy.hp,Ra2Damage.quantize(normal*1.15)),"real nonhero infantry direct impact gets fifteen percent exactly once")
	check(not enemy.special[Command.KEY].has("focus"),"third assisted hit exhausts mark")
	var hp:float=enemy.hp;fire_at(soldier,enemy)
	check(is_equal_approx(hp-enemy.hp,Ra2Damage.quantize(normal)),"fourth direct hit returns to ordinary damage")
	fire_at(hero,enemy);check(not enemy.special[Command.KEY].has("focus"),"twelve-second cooldown prevents remarking")
	Command.tick(hero,12);fire_at(hero,enemy)
	var packet:Dictionary={"expansion_origin":soldier.position,"impact_weapon":gun.ra2_weapon_id}
	for flag in ["expansion_extra","expansion_scatter","equipment_secondary"]:
		packet[flag]=true
		check(Command.impact(enemy,soldier,100,packet)==100 and enemy.special[Command.KEY].focus.charges==3,"secondary payload cannot consume focus "+flag)
		packet.erase(flag)
	soldier.special.academy_hero="E2"
	check(Command.impact(enemy,soldier,100,packet)==100,"other infantry hero cannot consume mark")
	soldier.special.erase("academy_hero")
	Command.tick(enemy,4.01)
	check(Command.impact(enemy,soldier,100,packet)==100 and not enemy.special[Command.KEY].has("focus"),"mark expires after four seconds")
	await finish()

func relay_and_save() -> void:
	var hero=command_hero(5);var main=building(Vector2(1280,1000));building(Vector2(1380,1000))
	var soldiers:Array=[]
	for offset in [30,55,80,105,130]:soldiers.append(battle.spawn_unit("E2","ally",main.position+Vector2(0,offset)))
	var vehicle=battle.spawn_unit("HTNK","ally",main.position+Vector2(0,25))
	var temporary=battle.spawn_unit("E2","ally",main.position+Vector2(0,-25));temporary.special.expansion_temporary={"kind":"test","left":10.0,"owner":hero}
	var jets:=dispatch(hero,main)
	for jet in jets:
		jet.position=jet.special.strike_run.target.position-Vector2(20,0);Soviet.fly_mig(jet,.01)
	check(soldiers.all(func(unit):return not unit.special.has(Command.KEY)),"release alone never grants air-ground relay")
	var miss=battle.projectiles_root.get_children().filter(func(shot):return shot is Projectile and shot.attacker_bonus.has("boris_wave"))[0]
	miss.target_point=Vector2(400,400);miss._explode()
	check(soldiers.all(func(unit):return not unit.special.has(Command.KEY)) and not battle.allied_state[Command.WAVES][0].relayed,"a real missed explosion cannot grant relay")
	await get_tree().process_frame
	var codec=BattleSaves.Snapshot.new();var snapshot:Dictionary=codec.capture(battle)
	check(codec.error.is_empty(),"world wave and pending bombs can be captured before first impact")
	var path:=output_dir.path_join("relay.bin");var file:=FileAccess.open(path,FileAccess.WRITE);file.store_var(snapshot,false);file.close()
	codec.restore(battle,FileAccess.open(path,FileAccess.READ).get_var(false))
	check(codec.error.is_empty(),"binary restore retains operation metadata and pending projectile references")
	var shots:Array=battle.projectiles_root.get_children().filter(func(shot):return shot is Projectile and shot.attacker_bonus.has("boris_wave"))
	check(shots.size()==11,"after one miss all eleven remaining bombs survive restore")
	shots[0]._explode()
	var qualified:Array=battle.units.filter(func(unit):return unit.special.get(Command.KEY,{}).has("relay"))
	check(qualified.size()==4 and qualified.all(func(unit):return AlliedAbilities.infantry(unit) and unit.side=="ally" and not Command.R.temporary(unit)),"first impact grants at most four real own infantry tokens")
	check(qualified.all(func(unit):return unit.position.y<=1105),"nearest four chosen rather than farther fifth")
	var soldier=qualified[0];var target=robust_enemy("E2",soldier.position+Vector2(90,0))
	fire_at(soldier,target);var reduced:float=soldier._cd_timer
	check(not soldier.special[Command.KEY].has("relay"),"real new volley consumes one relay token")
	fire_at(soldier,target)
	check(is_equal_approx(soldier._cd_timer,reduced*2),"subsequent normal reload is full duration")
	var consumed_at:Vector2=soldier.position
	await get_tree().process_frame
	snapshot=codec.capture(battle);file=FileAccess.open(path,FileAccess.WRITE);file.store_var(snapshot,false);file.close()
	codec.restore(battle,FileAccess.open(path,FileAccess.READ).get_var(false))
	check(codec.error.is_empty() and battle.allied_state[Command.WAVES][0].relayed,"saved post-impact wave remembers relay was already granted")
	soldier=battle.units.filter(func(unit):return unit.side=="ally" and unit.unit_id=="E2" and unit.position.is_equal_approx(consumed_at))[0]
	check(not soldier.special[Command.KEY].has("relay"),"consumed token stays consumed after binary restore")
	shots=battle.projectiles_root.get_children().filter(func(shot):return shot is Projectile and shot.attacker_bonus.has("boris_wave"))
	for shot in shots:shot._explode()
	check(not soldier.special[Command.KEY].has("relay"),"other bombs including secondary group cannot regrant consumed token")
	for unit in battle.units:Command.tick(unit,5.01)
	check(battle.units.all(func(unit):return not unit.special.get(Command.KEY,{}).has("relay")),"unused tokens expire after five seconds")
	for unit in battle.units.duplicate():
		if unit.unit_id=="BPLN":battle.units.erase(unit);unit.free()
	await get_tree().process_frame
	Command.world_tick(battle)
	check(not battle.allied_state.has(Command.WAVES),"finished wings and detonated ammunition release operation bookkeeping")
	await finish()

func boundaries() -> void:
	var hero=command_hero(0);var target=robust_enemy("E2",hero.position+Vector2(90,0))
	for i in 3:fire_at(hero,target)
	check(not target.special.has(Command.KEY),"baseline hero cannot access later command effects")
	hero.special.hero_command_rank=4
	for flag in ["expansion_extra","expansion_scatter","equipment_secondary"]:
		var extra:Dictionary={"impact_weapon":"AKM"};extra[flag]=true
		for i in 3:Command.rifle_hit(target,hero,1,extra)
		check(not target.special.has(Command.KEY),"nonprimary rifle payload does not install command effects "+flag)
	var transport=battle.spawn_unit("FV","enemy",target.position);target.embarked_in=transport
	Command.rifle_hit(target,hero,1,{"impact_weapon":"AKM"})
	check(not target.special.has(Command.KEY),"embarked target cannot receive suppression or focus")
	target.embarked_in=null
	Command.state(target).relay={"left":5.0};target.side="ally";Command.tick(target,.01)
	check(not target.special.has(Command.KEY),"ownership change clears prior side's command statuses")
	var shielded=robust_enemy("HTNK",hero.position+Vector2(80,0))
	shielded.special[Unit.TankHero.Shield.KEY]={"hp":10000.0,"left":120.0,"charge":0.0,"damaged":false,"growing":false}
	for i in 3:fire_at(hero,shielded)
	check(shielded.hp==100000 and Command.suppressed(shielded) and shielded.special[Command.KEY].has("focus"),"ordinary direct hits through a fully absorbing shield still count as hits for suppression and focus")
	Command.tick(shielded,1.1)
	var second=battle.spawn_unit("BORIS","ally",hero.position+Vector2(0,-30));second.special.academy_hero="BORIS";C.install(second);second.special.hero_command_rank=1
	for i in 3:fire_at(second,shielded)
	check(not Command.suppressed(shielded),"another Boris shares the same target's eight-second suppression interval")
	BattleRequest.rules_mode=MatchRules.RA2
	for i in 3:Command.rifle_hit(target,hero,1,{"impact_weapon":"AKM"})
	check(not target.special.has(Command.KEY),"classic mode does not install command states")
	await finish()

func command_resume_and_cap() -> void:
	var hero=command_hero(4);var target=robust_enemy("HTNK",hero.position+Vector2(100,0))
	fire_at(hero,target);fire_at(hero,target)
	var soldier=battle.spawn_unit("E2","ally",hero.position+Vector2(0,30));fire_at(soldier,target)
	var codec=BattleSaves.Snapshot.new();var snapshot:Dictionary=codec.capture(battle)
	var path:=output_dir.path_join("command-state.bin");var file:=FileAccess.open(path,FileAccess.WRITE);file.store_var(snapshot,false);file.close()
	codec.restore(battle,FileAccess.open(path,FileAccess.READ).get_var(false))
	for unit in battle.units:
		if unit.special.get("academy_hero")=="BORIS":hero=unit
		if unit.side=="enemy" and unit.unit_id=="HTNK":target=unit
	check(codec.error.is_empty() and hero.special[Command.KEY].streak==2 and is_same(hero.special[Command.KEY].streak_target,target),"binary restore retains two-hit streak and real target reference")
	check(target.special[Command.KEY].focus.charges==2,"partly consumed focus charges survive restore")
	fire_at(hero,target)
	check(Command.suppressed(target) and target.special[Command.KEY].focus.charges==2,"third hit after restore suppresses without consuming or refreshing focus")
	Command.tick(target,.4)
	snapshot=codec.capture(battle);codec.restore(battle,snapshot)
	for unit in battle.units:
		if unit.side=="enemy" and unit.unit_id=="HTNK":target=unit
	check(is_equal_approx(target.special[Command.KEY].suppressed,.6) and is_equal_approx(target.special[Command.KEY].suppression_cd,7.6),"partial fire lock and shared cooldown retain remaining durations")
	await finish()
	hero=command_hero(4);target=robust_enemy("HTNK",hero.position+Vector2(100,0));fire_at(hero,target)
	BattleRequest.combat_context.erase("house_training")
	BattleRequest.combat_context.final_damage_cap=2.25;BattleRequest.combat_context.final_damage_threshold=2.0
	soldier=battle.spawn_unit("E2","ally",hero.position+Vector2(0,30));soldier.bonuses.attack_bonus=10.0
	target.bonuses.defense_bonus=2.0;target.hp=100000
	var gun:Dictionary=soldier._weapon_for_target(target)
	var reference:float=Ra2Damage.target_damage(float(gun.damage),str(gun.ra2_warhead),target,0)*float(soldier.bonuses.get("veteran_attack",1))
	var curve:=2.0+.25*log(39.0)/(1.0+log(39.0))
	fire_at(soldier,target)
	check(is_equal_approx(100000-target.hp,Ra2Damage.quantize(reference*curve/2)),"focus bonus joins attack growth before one final cap and defense application",100000-target.hp)
	await finish()
