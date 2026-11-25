extends "res://tests/leizhu_defense_regression.gd"
const Insulation=preload("res://scripts/units/leizhu_insulation.gd")

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
	await get_tree().process_frame
	await moving_escape()
	await blocked_and_erased()
	await controls_insulation()
	await insulation_save()
	await insulation_purchase()
	await command_inputs()
	await insulation_expedition()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	print("LEIZHU_INSULATION_RESULT ",checks.size()," checks, ",failed," failed")
	get_tree().quit(0 if failed==0 else 1)

func mover(level:=3):
	var hero=defense_hero(level);hero.position=Vector2(1500,1700)
	hero.process_mode=Node.PROCESS_MODE_ALWAYS;hero.set_process(false);hero.set_physics_process(false)
	hero.fire_stance="none";hero._think_timer=10000
	hero.hull_angle=0;hero.turret_angle=0;hero.aim_dir=Vector2.RIGHT
	return hero

func freeze(hero,distance:=100.0):
	var chrono=battle.spawn_unit("CLEG","enemy",hero.position-Vector2(distance,0))
	chrono.attack_target=hero;chrono.attack_ordered=true
	check(AlliedAbilities.special_shot(chrono,hero,chrono._active_weapon()) and hero.special.get("temporal_by")==chrono,"native chrono weapon establishes live incoming freeze")
	return chrono

func moving_escape() -> void:
	var hero=mover();hero.max_hp=10000;hero.hp=10000
	var chrono=freeze(hero);var origin:Vector2=hero.position;var speed:float=hero.move_speed
	hero.order_move(origin+Vector2(500,0))
	check(hero.has_move_order and Insulation.mobile(hero) and AlliedAbilities.frozen(hero),"frozen rank-three hero accepts move without clearing incoming channel")
	await get_tree().physics_frame
	var dt:=1.0/Engine.physics_ticks_per_second
	for i in 15:hero._physics_process(dt);AlliedAbilities.channel(chrono,dt)
	var moved:float=hero.position.distance_to(origin)
	check(is_equal_approx(moved,speed*.5*dt*15) and hero.move_speed==speed,"actual unobstructed movement uses half speed and restores base movement stat",[moved,speed*.5*dt*15,hero.move_speed])
	check(AlliedAbilities.frozen(hero) and chrono.special.temporal_work>0 and hero.special.temporal_by==chrono,"movement within legal range retains freeze and advances real erasure")
	var enemy=target("HTNK","enemy",hero.position+Vector2(100,0));hero.attack_target=enemy;hero.attack_ordered=true;hero._cd_timer=0
	check(not hero._try_fire_ready() and enemy.hp==100000,"frozen mover cannot fire native main weapon")
	hero._load_equipped_skills({"active":[LC.ACTIVE],"passive":""})
	var slot:=UnitSkillLayout.find(hero,LC.ACTIVE)
	check(slot>=0 and not hero.use_ability(slot,hero.position+Vector2(100,0)) and not battle.allied_state.has(LC.FIELDS),"frozen mover cannot place its W field")
	hero.order_move(origin+Vector2(500,0))
	var progressed:float=chrono.special.temporal_work
	for i in 600:
		hero._physics_process(dt);AlliedAbilities.channel(chrono,dt)
		if not AlliedAbilities.frozen(hero):break
	check(not AlliedAbilities.frozen(hero) and not chrono.special.has("temporal_target") and hero.position.distance_to(chrono.position)>chrono.attack_range,"moving out of native weapon range releases both sides of channel")
	check(hero.hp==10000 and progressed>0,"escape is release before erasure, not lethal protection or damage repair")
	var after:Vector2=hero.position
	for i in 10:hero._physics_process(dt)
	check(is_equal_approx(hero.position.distance_to(after),speed*dt*10),"normal native movement speed resumes after channel releases")
	await finish()

func blocked_and_erased() -> void:
	var hero=mover();var chrono=freeze(hero)
	var wall:=StaticBody2D.new();wall.process_mode=Node.PROCESS_MODE_ALWAYS;wall.collision_layer=1;wall.position=hero.position+Vector2(55,0)
	var shape:=RectangleShape2D.new();shape.size=Vector2(20,240)
	var collision:=CollisionShape2D.new();collision.shape=shape;wall.add_child(collision);battle.add_child(wall)
	hero.order_move(hero.position+Vector2(300,0));await get_tree().physics_frame;await get_tree().physics_frame
	var origin:Vector2=hero.position;var dt:=1.0/Engine.physics_ticks_per_second
	for i in 90:hero._physics_process(dt)
	check(hero.position.x<wall.position.x-10 and hero.position.distance_to(origin)>0,"half-speed movement still collides with a real blocking body")
	check(AlliedAbilities.frozen(hero) and hero.special.temporal_by==chrono,"blocked movement never drops the freeze source")
	var needed:float=hero.max_hp/preload("res://scripts/units/temporal_visual.gd").erase_rate(chrono)
	AlliedAbilities.channel(chrono,needed+.01)
	check(not AlliedAbilities.alive(hero) and hero.hp==0 and not chrono.special.has("temporal_target"),"remaining within range still undergoes native complete temporal erasure")
	await finish()

func controls_insulation() -> void:
	for kind in ["rank_two","emp","shutdown","timed_only","classic","lost_source"]:
		var hero=mover(2 if kind=="rank_two" else 3);var chrono=freeze(hero);var origin:Vector2=hero.position
		match kind:
			"emp":hero._stun_timer=3
			"shutdown":hero.special[L.KEY].shutdown_left=3
			"timed_only":AlliedAbilities.release_temporal(chrono);hero.special.chrono_left=3
			"classic":BattleRequest.rules_mode=MatchRules.RA2
			"lost_source":AlliedAbilities.release_temporal(chrono)
		check(not Insulation.mobile(hero),"insulation eligibility excludes "+kind)
		if kind!="lost_source":
			hero.order_move(origin+Vector2(200,0));hero._physics_process(1.0/Engine.physics_ticks_per_second)
			check(hero.position==origin and AlliedAbilities.frozen(hero),"ineligible frozen mover stays frozen and stationary: "+kind)
		else:
			hero.order_move(origin+Vector2(200,0));await get_tree().physics_frame;hero._physics_process(1.0/Engine.physics_ticks_per_second)
			check(not AlliedAbilities.frozen(hero) and hero.has_move_order,"normal movement remains available when caster releases channel")
		await finish()

func insulation_save() -> void:
	var hero=mover();var chrono=freeze(hero);hero.order_move(hero.position+Vector2(300,0));AlliedAbilities.channel(chrono,.5)
	var work:float=chrono.special.temporal_work;var destination:Vector2=hero.move_target
	var codec=BattleSaves.Snapshot.new();var snapshot:Dictionary=codec.capture(battle)
	var file=FileAccess.open(output_dir.path_join("insulation.bin"),FileAccess.WRITE);file.store_var(snapshot,false);file.close();file=FileAccess.open(output_dir.path_join("insulation.bin"),FileAccess.READ);snapshot=file.get_var(false);file.close()
	codec.restore(battle,snapshot);hero=get_hero();chrono=hero.special.temporal_by
	check(codec.error.is_empty() and Insulation.mobile(hero) and chrono.special.temporal_target==hero and chrono.special.temporal_work==work and hero.move_target==destination,"binary snapshot restores both live freeze links, erasure progress and movement order")
	var origin:Vector2=hero.position
	hero.process_mode=Node.PROCESS_MODE_ALWAYS;hero.set_physics_process(false);await get_tree().physics_frame
	hero._physics_process(1.0/Engine.physics_ticks_per_second)
	check(hero.position!=origin and AlliedAbilities.frozen(hero),"restored hero resumes movement without clearing incoming freeze")
	await finish()

func insulation_purchase() -> void:
	MetaProgress.reset_save();MetaProgress.academy.hero_builds={"TTNK":5};MetaProgress.academy.hero_survival_ranks={"TTNK":2};MetaProgress.currency.cores=240
	var page=preload("res://scripts/ui/hero_progression.gd").new();add_child(page);page.selected="TTNK";page.refresh();page.survival.pressed.emit();MetaProgress.load_save();page.refresh()
	page.talent_demo.talent.select(1);page.talent_demo._select_talent();page.talent_demo.levels.select(3);page.talent_demo.refresh_caption()
	check(MetaProgress.academy.hero_survival_ranks.TTNK==3 and MetaProgress.balance("cores")==0 and page.survival.disabled,"third rank actual UI purchase persists exact 240-core price")
	check(page.talent_demo.levels.item_count==6 and page.talent_demo.caption.text.contains("绝缘缓行") and page.talent_demo.duration()==12,"new level exposes correct description and twelve-second demo")
	MetaProgress.currency.cores=10000
	check(A.purchase(MetaProgress,"survival","TTNK") and MetaProgress.academy.hero_survival_ranks.TTNK==4 and MetaProgress.balance("cores")==9600,"fourth defense rank opens after insulation at its normal price")
	check(A.purchase(MetaProgress,"survival","TTNK") and MetaProgress.academy.hero_survival_ranks.TTNK==5 and MetaProgress.balance("cores")==9000 and not A.purchase(MetaProgress,"survival","TTNK"),"fifth defense rank opens once and rejects further purchase")
	page.free()

func command_inputs() -> void:
	var hero=mover();var chrono=freeze(hero);var origin:Vector2=hero.position
	battle.select_unit(hero,false);battle._command_move(origin+Vector2(200,0))
	check(hero.has_move_order and hero._path_pts.size()>=2 and hero.special.temporal_by==chrono,"actual battle move command assigns native route while retaining incoming freeze")
	check(battle.formation_gesture.available(battle,hero),"formation drag accepts mobile frozen hero")
	await get_tree().physics_frame
	for i in 10:hero._physics_process(1.0/Engine.physics_ticks_per_second)
	check(hero.position!=origin and AlliedAbilities.frozen(hero),"battle-issued route drives actual frozen movement")
	var text:String=preload("res://scripts/ui/battle_effect_details.gd").describe(hero)
	check(text.contains("过载保险") and text.contains("绝缘缓行") and text.contains("不能开火") and not text.contains("随行护卫"),"live details show actual Leizhu talents and frozen movement restrictions")
	hero._stun_timer=2
	check(not battle.formation_gesture.available(battle,hero),"EMP removes formation availability while frozen")
	await finish()

func insulation_expedition() -> void:
	MetaProgress.reset_save();MetaProgress.academy.hero_survival_ranks={"TTNK":3}
	check(Expedition.start("苏俄","",909) and Expedition.choose(0),"start expedition with insulation profile")
	var next:Dictionary=Expedition.state.duplicate(true);next.stage=5
	check(preload("res://scripts/expedition/heroes.gd").recruit(next,"TTNK") and Expedition.commit(next) and Expedition.launch(0),"recruit insulation hero into real expedition")
	screen=load("res://scenes/battle.tscn").instantiate();add_child(screen);screen.process_mode=Node.PROCESS_MODE_DISABLED;battle=screen.battle
	var hero=get_hero();var chrono=freeze(hero);hero.order_move(hero.position+Vector2(200,0))
	battle.fog.rebuild()
	check(chrono._weapon_target_valid(hero),"expedition caster has legal native continuation",[hero.position,chrono.position,chrono.attack_range,chrono.special,hero.special])
	AlliedAbilities.channel(chrono,.5)
	if not chrono.special.has("temporal_work"):await finish();return
	var work:float=chrono.special.temporal_work;var destination:Vector2=hero.move_target
	check(Expedition.checkpoint(battle),"actual expedition checkpoint captures frozen moving hero")
	await finish()
	check(Expedition.load_run() and Expedition.prepare_battle(),"reload actual insulation checkpoint")
	screen=load("res://scenes/battle.tscn").instantiate();add_child(screen);screen.process_mode=Node.PROCESS_MODE_DISABLED;battle=screen.battle;hero=get_hero();chrono=hero.special.temporal_by
	check(Defense.rank(hero)==3 and Insulation.mobile(hero) and hero.has_move_order and hero.move_target==destination and chrono.special.temporal_work==work,"checkpoint retains frozen movement, rank, route and original erasure progress")
	AlliedAbilities.channel(chrono,.1);check(chrono.special.temporal_work>work and AlliedAbilities.frozen(hero),"restored expedition continues native erase work without immunity")
	await finish()
