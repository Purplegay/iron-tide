extends "res://tests/peregrine_defense_regression.gd"
const S=preload("res://scripts/units/peregrine_service.gd")

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
	await get_tree().process_frame
	await maintenance()
	await maintenance_boundaries()
	await crash()
	await descent_damage()
	await engineers()
	await automatic_repair_race()
	await late_engineer()
	await destruction()
	await lethal_damage_kinds()
	await service_saves()
	await last_second_save()
	await real_clocks()
	await maintenance_timing()
	await expedition_service()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	print("PEREGRINE_SERVICE_RESULT ",checks.size()," checks, ",failed," failed")
	get_tree().quit(0 if failed==0 else 1)

func service_hero(rank:=5):
	var hero=defense_hero(rank);hero.passive={}
	return hero

func place_service(hero):
	var pad=airport();battle._update_power()
	var found:=false
	for angle in 32:
		hero.position=pad.position+Vector2.from_angle(TAU*angle/32)*180
		if S.airport_valid(hero,pad) and S.ground_clear(hero,hero.position):found=true;break
	check(found,"actual airport has a legal nearby maintenance position",[hero.position,battle.side_power_low(hero.side)])
	return pad

func make_wreck(hero):
	var normal_max:float=hero.max_hp
	var enemy=victim("HTNK",hero.position+Vector2(150,0))
	hero.special[P.KEY].erase("rearm_shield")
	hero.receive_hit(hero.max_hp*100,"shell",{},enemy)
	check(hero.special.has("hero_wreck") and hero.hp==normal_max*10 and hero.max_hp==normal_max*10 and not hero._dead,"ordinary lethal hit immediately grants full tenfold durability before descent")
	return enemy

func binary_restore(name:String) -> void:
	var codec=BattleSaves.Snapshot.new();var snap:Dictionary=codec.capture(battle)
	var f=FileAccess.open(output_dir.path_join(name+".bin"),FileAccess.WRITE);f.store_var(snap,false);f.close()
	f=FileAccess.open(output_dir.path_join(name+".bin"),FileAccess.READ);snap=f.get_var(false);f.close();codec.restore(battle,snap)
	check(codec.error.is_empty(),"binary restore "+name,codec.error)

func last_second_save() -> void:
	var hero=service_hero();var normal_max:float=hero.max_hp
	make_wreck(hero);P.tick(hero,180)
	check(hero.special.has("hero_wreck") and is_equal_approx(hero.special.hero_wreck.left,1) and hero.max_hp==normal_max*10,"one descent second plus 179 grounded seconds leaves exactly one recovery second")
	await binary_restore("grounded-second-179");hero=get_hero()
	check(hero.special.has("hero_wreck") and is_equal_approx(hero.special.hero_wreck.left,1) and hero.max_hp==normal_max*10,"binary restore at grounded second 179 preserves final second and tenfold wreck durability")
	P.tick(hero,.5);check(hero.special.has("hero_wreck") and is_equal_approx(hero.special.hero_wreck.left,.5),"loaded wreck cannot recover half a second early")
	P.tick(hero,.5)
	check(not hero.special.has("hero_wreck") and hero.max_hp==normal_max and hero.hp==normal_max and hero.logistics.ammo==0,"loaded final second restores normal full life and empty magazine once")
	hero.hp=normal_max*.6;P.tick(hero,.5)
	check(is_equal_approx(hero.hp,normal_max*.6) and Unit.TankHero.revival_used(hero),"after completion no second full heal or refreshed survival allowance occurs")
	await finish()

func maintenance() -> void:
	var hero=service_hero(4);var pad=place_service(hero)
	hero.hp=hero.max_hp*.5;var hp:float=hero.hp
	hero.logistics.spend_ammo(2,false)
	var slots:int=battle.aircraft_population("ally")
	battle.select_unit(hero,false);battle.deploy_selected()
	check(S.busy(hero) and hero.logistics.air_lift==1,"real J command begins one-second descent")
	P.tick(hero,.5)
	check(is_equal_approx(hero.logistics.air_lift,.5) and not hero.special[P.KEY].has("maintenance_shield"),"half-descent has real half altitude and no early shield")
	P.tick(hero,.5)
	check(hero.logistics.air_lift==0 and not hero.is_air_target() and hero.collision_layer==1 and hero.collision_mask==7,"landed maintenance has ground targeting and collision")
	check(is_equal_approx(hero.special[P.KEY].maintenance_shield.hp,hero.max_hp*.2) and hero.logistics.home==null and hero.logistics.dock_slot==-1 and battle.aircraft_population("ally")==slots,"landing grants 20-percent shield without airport berth")
	var target=victim("HTNK",hero.position+Vector2(150,0))
	hero.attack_target=target;hero.attack_ordered=true;hero._cd_timer=0
	check(not hero._try_fire_ready() and not hero.use_ability(UnitSkillLayout.find(hero,PC.ACTIVE),target.position),"landed maintenance cannot fire or cast W")
	hero.attack_target=null;hero.attack_ordered=false
	P.tick(hero,3)
	check(hero.hp==hp,"first three peaceful seconds produce no maintenance healing")
	P.tick(hero,1)
	check(is_equal_approx(hero.hp,hp+hero.max_hp*.02),"one eligible second heals exactly two percent")
	var shield:float=hero.special[P.KEY].maintenance_shield.hp;hp=hero.hp
	hero.receive_hit(10,"shell",{},target)
	check(hero.hp==hp and hero.special[P.KEY].maintenance_shield.hp<shield and hero.special[P.KEY].maintenance.quiet==0,"actual shield damage resets quiet window without fictitious health loss")
	P.tick(hero,3);check(hero.hp==hp,"incoming fire restarts entire three-second wait")
	P.tick(hero,4)
	check(hero.logistics.ammo==hero.logistics.ammo_max and not hero.special[P.KEY].has("maintenance_shield"),"single native hero reload continues and maintenance shield expires")
	check(hero.deploy() and not S.busy(hero),"second J exits maintenance")
	check(hero.deploy(),"repeat descent is permitted during shield cooldown")
	P.tick(hero,1)
	check(not hero.special[P.KEY].has("maintenance_shield"),"repeat landing cannot bypass thirty-second shield interval")
	hero.order_move(hero.position+Vector2(100,0))
	check(not S.busy(hero) and hero.has_move_order,"move order exits maintenance and keeps player destination")
	hero.process_mode=Node.PROCESS_MODE_ALWAYS;hero.set_process(false);hero.set_physics_process(false)
	await get_tree().physics_frame
	for i in 75:hero._physics_process(1.0/Engine.physics_ticks_per_second)
	check(hero.is_air_target() and hero.collision_layer==8 and hero.logistics.home==null,"real physics takes off into airborne collision without airport")
	await finish()

func maintenance_boundaries() -> void:
	for kind in ["rank3","no_airport","water","occupied","enemy_airport","power_loss","destroyed","out_of_range"]:
		var hero=service_hero(3 if kind=="rank3" else 4);var pad=place_service(hero)
		if kind=="rank3":check(not hero.can_deploy() and not hero.deploy(),"rank three cannot enter maintenance")
		elif kind=="no_airport":pad._die();check(not hero.deploy(),"no valid airport refuses maintenance")
		elif kind=="water":
			battle.path_service.water_rects=[Rect2(hero.position-Vector2(60,60),Vector2(120,120))]
			check(not hero.deploy(),"water landing is rejected")
		elif kind=="occupied":
			battle.spawn_unit("MTNK","ally",hero.position)
			check(not hero.deploy(),"ground unit occupancy rejects maintenance")
		elif kind=="enemy_airport":pad.side="enemy";check(not hero.deploy(),"enemy airport cannot host maintenance")
		else:
			check(hero.deploy(),"valid maintenance before boundary "+kind);P.tick(hero,1)
			if kind=="power_loss":battle.allied_state.blackout_ally=10.0
			elif kind=="destroyed":pad._die()
			else:hero.position+=Vector2(500,0)
			P.tick(hero,.1)
			check(not S.busy(hero) and not hero.special[P.KEY].has("maintenance_shield"),"invalid airport state ends maintenance and shield "+kind)
		await finish()

func crash() -> void:
	var hero=service_hero();var health:float=hero.max_hp
	hero.special.hero_command_rank=4
	var follower=battle.spawn_unit("ORCA","ally",hero.position+Vector2(700,0))
	check(Cmd.speed_bonus(follower)==.15,"distant follower receives formation before real crash")
	hero.special[P.KEY].decoy_ready=false;hero.special[P.KEY].control_ready=false;ability(hero).cd_left=240
	make_wreck(hero)
	if not hero.special.has("hero_wreck"):await finish();return
	check(Cmd.speed_bonus(follower)==0,"real crash removes distant follower formation bonus")
	check(hero.max_hp==health*10 and hero.special.hero_wreck.health==health and hero.logistics.ammo==0 and not hero.special[P.KEY].has("rearm_shield"),"transition grants tenfold cap and retains normal recovery cap while clearing ammo and shield")
	P.tick(hero,.5)
	check(hero.hp==health*10 and hero.special.hero_wreck.left==180 and is_equal_approx(hero.logistics.air_lift,.5),"half-transition keeps tenfold durability and repair timer has not started")
	P.tick(hero,.5)
	check(hero.hp==health*10 and hero.max_hp==health*10 and not hero.is_air_target(),"landing preserves tenfold durability and changes to ground domain")
	var at:Vector2=hero.position;hero.order_move(at+Vector2(100,0));hero.order_target(victim("HTNK",at+Vector2(150,0)),false,false)
	check(not hero.has_move_order and not hero.attack_ordered and not hero.deploy() and not hero._try_fire_ready() and not Cmd.speed_bonus(hero)>0,"wreck cannot move, target, deploy, fire or lead")
	hero.receive_hit(50,"shell",{},battle.units.filter(func(u):return u.side=="enemy")[0])
	var damaged:float=hero.hp;P.tick(hero,179)
	check(hero.hp==damaged and hero.max_hp==health*10 and is_equal_approx(hero.special.hero_wreck.left,1) and hero.logistics.ammo==0,"wreck takes real damage, never regenerates or reloads during 179 seconds")
	await binary_restore("wreck-179");hero=get_hero()
	check(hero.max_hp==health*10 and hero.hp==damaged and is_equal_approx(hero.special.hero_wreck.left,1),"saved durability and final second are exact")
	P.tick(hero,1)
	check(not hero.special.has("hero_wreck") and hero.max_hp==health and hero.hp==health and hero.logistics.ammo==0 and hero.special[P.KEY].progress==0,"automatic recovery restores normal 100-percent life and zero ammo")
	follower=battle.units.filter(func(unit):return unit.unit_id=="ORCA" and unit!=hero and not unit.special.has("academy_hero"))[0]
	check(Cmd.speed_bonus(follower)==.15,"automatic recovery restores formation to distant follower after save restore")
	check(ability(hero).cd_left==240 and not hero.special[P.KEY].decoy_ready and not hero.special[P.KEY].control_ready and Unit.TankHero.revival_used(hero),"recovery never refreshes W, quotas or once-per-match charge")
	P.tick(hero,30)
	check(hero.logistics.ammo==5 and hero.special[P.KEY].decoy_ready and hero.special[P.KEY].control_ready,"only subsequent real full reload renews defensive quotas")
	hero.special[P.KEY].erase("rearm_shield");hero.receive_hit(health*100,"shell",{},battle.units.filter(func(u):return u.side=="enemy")[0])
	check(hero._dead,"second lethal hit permanently destroys recovered hero")
	await finish()

func engineers() -> void:
	var hero=service_hero();hero.special.hero_command_rank=4
	battle.spawn_unit("ORCA","ally",hero.position+Vector2(700,0))
	make_wreck(hero);P.tick(hero,1)
	var engineer=battle.spawn_unit("ENGINEER","ally",hero.position+Vector2(30,0))
	var other=battle.spawn_unit("SENGINEER","ally",hero.position-Vector2(30,0))
	check(AlliedAbilities.default_order(engineer,hero)=="allied_engineer" and engineer.order_interaction("allied_engineer",hero,false),"real right-click interaction recognizes landed hero wreck")
	AlliedAbilities.tick_action(engineer,3)
	check(is_equal_approx(hero.special.hero_wreck.repair_elapsed,3),"engineer channels actual three seconds")
	check(other.order_interaction("allied_engineer",hero,false),"second friendly engineer can receive same task")
	AlliedAbilities.tick_action(other,2)
	check(is_equal_approx(hero.special.hero_wreck.repair_elapsed,3),"two engineers cannot stack progress")
	engineer.stun(1);P.tick(hero,.1)
	check(hero.special.hero_wreck.repair_elapsed==0 and is_equal_approx(hero.special.hero_wreck.left,179.9),"engineer control resets five seconds but not automatic clock")
	engineer._stun_timer=0;engineer.buffs.clear();other.order_stop()
	AlliedAbilities.tick_action(engineer,2)
	engineer.position+=Vector2(200,0);P.tick(hero,.1)
	check(hero.special.hero_wreck.repair_elapsed==0,"leaving repair range resets progress")
	engineer.position=hero.position+Vector2(30,0);AlliedAbilities.tick_action(engineer,4)
	await binary_restore("engineer-four");hero=get_hero();engineer=battle.units.filter(func(u):return u.unit_id=="ENGINEER")[0]
	check(hero.special.hero_wreck.get("engineer")==engineer and hero.special.hero_wreck.repair_elapsed==4,"snapshot restores exact engineer identity and progress")
	hero.special.hero_wreck.left=.1
	AlliedAbilities.tick_action(engineer,1);P.tick(hero,.1)
	check(not hero.special.has("hero_wreck") and AlliedAbilities.alive(engineer) and engineer.special.get("action","")=="" and hero.hp==hero.max_hp,"engineer recovery wins same-time completion once without consuming engineer")
	check(hero.max_hp==hero._base_max_hp and Unit.TankHero.revival_used(hero),"simultaneous timers cannot leave ten-times maximum or grant another charge")
	var follower=battle.units.filter(func(unit):return unit.unit_id=="ORCA" and unit!=hero and not unit.special.has("academy_hero"))[0]
	check(Cmd.speed_bonus(follower)==.15,"engineer recovery restores formation to real distant follower")
	await finish()

func automatic_repair_race() -> void:
	var hero=service_hero();var health:float=hero.max_hp
	make_wreck(hero);P.tick(hero,1)
	var engineer=battle.spawn_unit("ENGINEER","ally",hero.position+Vector2(30,0))
	check(engineer.order_interaction("allied_engineer",hero,false),"automatic-first race starts through real engineer interaction")
	AlliedAbilities.tick_action(engineer,4.9)
	check(is_equal_approx(hero.special.hero_wreck.repair_elapsed,4.9),"engineer and automatic recovery both have one tenth second remaining")
	hero.special.hero_wreck.left=.1
	P.tick(hero,.1)
	check(not hero.special.has("hero_wreck") and hero.max_hp==health and hero.hp==health,"automatic recovery resolves first with normal health cap")
	AlliedAbilities.tick_action(engineer,.1)
	check(AlliedAbilities.alive(engineer) and engineer.special.get("action","")=="","stale engineer action cancels after automatic recovery without consuming engineer")
	check(hero.max_hp==health and hero.hp==health and hero.logistics.ammo==0 and hero.special[P.KEY].progress==0 and Unit.TankHero.revival_used(hero),"second completion cannot duplicate recovery, ammunition or once-per-match charge")
	await finish()

func late_engineer() -> void:
	var hero=service_hero();var health:float=hero.max_hp
	make_wreck(hero);P.tick(hero,180)
	check(hero.special.has("hero_wreck") and hero.special.hero_wreck.left==1 and hero.max_hp==health*10,"179 grounded seconds preserve ten-times wreck with one second left")
	var engineer=battle.spawn_unit("ENGINEER","ally",hero.position+Vector2(30,0))
	check(engineer.order_interaction("allied_engineer",hero,false),"engineer can begin real repair at grounded second 179")
	AlliedAbilities.tick_action(engineer,.5);P.tick(hero,.5)
	check(hero.special.hero_wreck.repair_elapsed==.5 and hero.special.hero_wreck.left==.5,"late repair progress does not extend automatic deadline")
	P.tick(hero,.5);AlliedAbilities.tick_action(engineer,4.5)
	check(not hero.special.has("hero_wreck") and hero.max_hp==health and hero.hp==health and hero.logistics.ammo==0,"automatic completion wins before late engineer's five seconds without a second recovery")
	check(AlliedAbilities.alive(engineer) and engineer.special.get("action","")=="" and Unit.TankHero.revival_used(hero),"late engineer is retained and cancels obsolete repair while revival stays used")
	await finish()

func destruction() -> void:
	for phase in ["transition","landed","erasure","removed","no_land"]:
		var hero=service_hero();var enemy=victim("HTNK",hero.position+Vector2(150,0))
		if phase in ["erasure","removed"]:
			hero.hp=0;hero._die(enemy,phase=="erasure")
		elif phase=="no_land":
			battle.path_service.water_rects=[Rect2(hero.position-Vector2(400,400),Vector2(800,800))]
			hero.receive_hit(hero.max_hp*100,"shell",{},enemy)
		else:
			make_wreck(hero)
			if phase=="landed":P.tick(hero,1)
			hero.receive_hit(hero.max_hp*100,"shell",{},enemy);P.tick(hero,200)
		check(hero._dead,"no revival after "+phase)
		await finish()

func service_saves() -> void:
	var hero=service_hero(4);place_service(hero);hero.deploy();P.tick(hero,.4)
	await binary_restore("maintenance-descent");hero=get_hero()
	check(is_equal_approx(hero.logistics.air_lift,.6) and is_equal_approx(hero.special[P.KEY].maintenance.descent,.6),"snapshot cannot jump maintenance descent to full flight")
	P.tick(hero,.6);hero.special[P.KEY].maintenance_shield.hp=7;P.tick(hero,2)
	await binary_restore("maintenance-shield");hero=get_hero()
	check(hero.logistics.air_lift==0 and hero.special[P.KEY].maintenance_shield.hp==7 and is_equal_approx(hero.special[P.KEY].maintenance.quiet,2),"save retains ground stance, damaged shield and quiet time without regrant")
	await finish()
	hero=service_hero();make_wreck(hero);P.tick(hero,.4)
	await binary_restore("crash-descent");hero=get_hero()
	check(hero.hp==hero._base_max_hp*10 and hero.max_hp==hero._base_max_hp*10 and is_equal_approx(hero.logistics.air_lift,.6) and hero.special.hero_wreck.left==180,"save retains descent and immediate tenfold durability without starting repair timer")
	P.tick(hero,.6)
	check(hero.hp==hero.max_hp and hero.max_hp==hero._base_max_hp*10,"restored landing preserves existing durability without multiplying cap again")
	await finish()

func real_clocks() -> void:
	var hero=service_hero();var enemy=make_wreck(hero)
	hero.process_mode=Node.PROCESS_MODE_ALWAYS;hero.set_process(false);hero.set_physics_process(false)
	hero.fire_stance="none";hero._think_timer=10000;ability(hero).cd_left=240
	await get_tree().physics_frame
	var dt:=1.0/Engine.physics_ticks_per_second
	for i in int(2/dt):hero._physics_process(dt)
	check(hero.special.has("hero_wreck") and is_equal_approx(hero.special.hero_wreck.left,179),"real physics lands once then advances only the remaining automatic repair time")
	check(is_equal_approx(ability(hero).cd_left,238),"real wreck physics preserves and normally ticks W cooldown")
	check(hero.logistics.ammo==0 and hero.special[P.KEY].progress==0 and hero.max_hp==hero._base_max_hp*10,"native physics cannot run ordinary regeneration or reload inside wreck")
	check(enemy._weapon_target_valid(hero),"real ground weapon may target landed wreck")
	hero.process_mode=Node.PROCESS_MODE_PAUSABLE
	get_tree().paused=true
	var remaining:float=hero.special.hero_wreck.left
	await get_tree().process_frame;await get_tree().process_frame
	check(hero.special.hero_wreck.left==remaining,"scene-tree pause does not advance repair countdown")
	get_tree().paused=false
	hero.process_mode=Node.PROCESS_MODE_ALWAYS;hero.set_physics_process(false)
	hero.special.hero_wreck.left=dt
	hero._physics_process(dt)
	for i in int(4/dt):hero._physics_process(dt)
	check(not S.busy(hero) and hero.is_air_target() and hero.collision_layer==8 and hero.logistics.home==null,"real automatic recovery takes off with no airport")
	check(hero.hp==hero.max_hp and hero.max_hp==hero._base_max_hp and hero.logistics.ammo==0 and hero.special[P.KEY].progress>0,"native repaired hero has normal health and one ongoing reload stream")
	await finish()

func maintenance_timing() -> void:
	for expired_at_landing in [false,true]:
		var hero=service_hero(4);place_service(hero)
		hero.special[P.KEY].maintenance_cd=.5 if expired_at_landing else 5.0
		hero.deploy();P.tick(hero,6)
		check(hero.special[P.KEY].has("maintenance_shield")==expired_at_landing,"large step checks shield eligibility at landing rather than at end of step "+str(expired_at_landing))
		if expired_at_landing:
			check(is_equal_approx(hero.special[P.KEY].maintenance_shield.left,5) and is_equal_approx(hero.special[P.KEY].maintenance_cd,25),"post-landing remainder advances both shield duration and its cooldown")
		await finish()
	var hero=service_hero(4);place_service(hero);hero.deploy();P.tick(hero,1)
	hero.special[P.KEY].control_ready=false;hero.stun(20);P.tick(hero,10)
	check(not hero.special[P.KEY].has("maintenance_shield") and hero.special[P.KEY].maintenance.quiet==0,"stun never prolongs ten-second shield or advances peaceful healing")
	hero._stun_timer=0;hero.hp=0;hero._die(null,true)
	P.tick(hero,30)
	check(hero._dead and hero.hp==0,"dead maintenance actor cannot regenerate through service timer")
	await finish()

func expedition_service() -> void:
	MetaProgress.reset_save();MetaProgress.academy.hero_survival_ranks={"ORCA":5}
	check(Expedition.start("美国","",905) and Expedition.choose(0),"start expedition with full service training")
	var prepared:Dictionary=Expedition.state.duplicate(true);prepared.stage=5
	check(preload("res://scripts/expedition/heroes.gd").recruit(prepared,"ORCA") and Expedition.commit(prepared) and Expedition.launch(0),"recruit actual service hero into expedition")
	screen=load("res://scenes/battle.tscn").instantiate();add_child(screen);screen.process_mode=Node.PROCESS_MODE_DISABLED;battle=screen.battle
	var hero=get_hero()
	check(hero!=null and D.rank(hero)==5,"expedition receives full purchased service rank")
	if hero==null:await finish();return
	var ground:=Vector2.INF
	for x in range(100,battle.map_size-100,55):
		for y in range(100,battle.map_size-100,55):
			var point:=Vector2(x,y)
			if S.ground_clear(hero,point):ground=point;break
		if ground.is_finite():break
	check(ground.is_finite(),"expedition has legal actual crash terrain",[battle.map_size,hero.position,hero.radius,ground])
	if not ground.is_finite():await finish();return
	hero.position=ground;hero.passive={};make_wreck(hero);P.tick(hero,1.5)
	var health:float=hero.max_hp
	check(Expedition.checkpoint(battle),"actual expedition checkpoint records damaged hero lifecycle")
	await finish()
	check(Expedition.load_run() and Expedition.prepare_battle(),"actual expedition checkpoint can resume wreck")
	screen=load("res://scenes/battle.tscn").instantiate();add_child(screen);screen.process_mode=Node.PROCESS_MODE_DISABLED;battle=screen.battle;hero=get_hero()
	check(hero!=null and hero.special.has("hero_wreck"),"expedition restores existing wreck instead of granting replacement hero")
	if hero!=null and hero.special.has("hero_wreck"):
		check(hero.max_hp==health and hero.logistics.air_lift==0 and is_equal_approx(hero.special.hero_wreck.left,179.5) and Unit.TankHero.revival_used(hero),"expedition preserves ten-times cap, ground stance, exact timer and used charge")
		P.tick(hero,179.5)
		check(hero.hp==hero.max_hp and is_equal_approx(hero.max_hp,health/10) and hero.logistics.ammo==0,"resumed expedition wreck recovers to normal health and empty ammo")
	await finish()

func lethal_damage_kinds() -> void:
	for reason in ["crush","erase","execute","forced","ordinary"]:
		var hero=service_hero()
		var enemy=victim("HTNK",hero.position+Vector2(150,0))
		if reason=="crush":
			place_service(hero)
			check(hero.deploy(),"crush boundary starts real ground maintenance")
			P.tick(hero,1)
			check(not hero.is_air_target(),"crush boundary uses landed maintenance target")
		var kind:String="bullet" if reason=="forced" else "shell" if reason=="ordinary" else reason
		hero.receive_hit(hero.max_hp*100,kind,{"force_execute":true} if reason=="forced" else {},enemy)
		if reason=="ordinary":
			check(not hero._dead and hero.hp==hero.max_hp and hero.max_hp==hero.special.hero_wreck.health*10 and Unit.TankHero.revival_used(hero),"ordinary lethal damage consumes one emergency landing and establishes tenfold durability")
		else:
			check(hero._dead and not hero.special.has("hero_wreck"),"nonordinary lethal hit cannot start emergency landing "+reason)
			check(not Unit.TankHero.revival_used(hero),"excluded lethal hit does not spend emergency landing allowance "+reason)
		await finish()

func descent_damage() -> void:
	var hero=service_hero();var normal_max:float=hero.max_hp
	var enemy=make_wreck(hero)
	hero.receive_hit(50,"shell",{},enemy)
	var damaged:float=hero.hp
	check(damaged>0 and damaged<normal_max*10 and not hero._dead and hero.special.hero_wreck.descent==1,"same-frame follow-up damage consumes new durability and survives")
	P.tick(hero,.4)
	check(hero.hp==damaged and hero.special.hero_wreck.left==180,"descent does not heal or start repair timer")
	await binary_restore("damaged-descent");hero=get_hero()
	check(hero.hp==damaged and hero.max_hp==normal_max*10 and hero.special.hero_wreck.health==normal_max,"binary reload preserves damaged transition and original recovery cap")
	P.tick(hero,.6)
	check(hero.hp==damaged and hero.max_hp==normal_max*10 and hero.special.hero_wreck.descent==0 and hero.special.hero_wreck.left==180,"landing neither refills damage nor reapplies tenfold cap")
	P.tick(hero,179.9)
	check(hero.hp==damaged and hero.special.has("hero_wreck"),"landed damaged wreck waits full recovery duration")
	P.tick(hero,.1)
	check(hero.hp==normal_max and hero.max_hp==normal_max and hero.logistics.ammo==0 and not hero.special.has("hero_wreck"),"recovery restores normal full health once after early durability grant")
	await finish()
	hero=service_hero();enemy=make_wreck(hero)
	hero.receive_hit(hero.max_hp*100,"shell",{},enemy)
	check(hero._dead and Unit.TankHero.revival_used(hero),"sufficient follow-up damage still destroys descending aircraft without another rescue")
	await finish()
	const Demo=preload("res://scripts/ui/peregrine_crash_demo.gd")
	for case_id in 5:
		check(Demo.sample(1,case_id).hp==1000 and Demo.sample(1,case_id).max_hp==1000,"demo grants tenfold durability at trigger "+str(case_id))
	check(Demo.sample(1.5,2).hp==800 and Demo.sample(2,2).hp==800,"demo retains descent damage at landing")
