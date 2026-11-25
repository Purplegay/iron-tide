extends "res://tests/leizhu_defense_regression.gd"
const Safety=preload("res://scripts/units/leizhu_safety.gd")

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
	await get_tree().process_frame
	await diversion()
	await eligibility_safety()
	await shutdown()
	await lethal_boundaries()
	await safety_save()
	await safety_expedition()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	print("LEIZHU_SAFETY_RESULT ",checks.size()," checks, ",failed," failed")
	get_tree().quit(0 if failed==0 else 1)

func health(actor,amount:=1000.0) -> void:
	actor.max_hp=amount;actor.hp=amount;actor._base_max_hp=amount
	actor._hero_heal_interval=100000;actor._vet_self_heal=false;actor._regen_frac=0
	actor.data=actor.data.duplicate(true);actor.data.erase("self_repair")

func hit(actor,amount:float,source,kind:="bullet",bonus:Dictionary={}) -> void:
	actor.receive_hit(amount/CombatMath.with_defense(1.0,actor.bonuses),kind,bonus,source,"RA3_PRISM")

func diversion() -> void:
	var hero=defense_hero(4);health(hero)
	var ally=target("HTNK","ally",hero.position+Vector2(80,0));health(ally)
	var farther=target("HTNK","ally",hero.position+Vector2(140,0));health(farther)
	var enemy=target("HTNK","enemy",hero.position+Vector2(250,0))
	hero.bonuses.defense_bonus=10
	check(hero.is_in_group(Safety.GROUP) and Safety.protected(hero)==ally,"rank-four promotion registers one nearest protected vehicle")
	hit(ally,100,enemy)
	check(is_equal_approx(ally.hp,920) and is_equal_approx(hero.hp,996),"final hundred splits into eighty and four without reapplying hero defense",[ally.hp,hero.hp])
	check(not hero.special[L.KEY].has("recycled"),"transferred hit never creates recovery shield")
	hit(farther,100,enemy)
	check(farther.hp==900 and is_equal_approx(hero.hp,996),"second nearby vehicle is not protected simultaneously")
	ally.hp=1000;hero.hp=1000;give_shield(ally,90);give_shield(hero,3)
	hit(ally,100,enemy,"tesla")
	check(ally.hp==1000 and is_equal_approx(ally.special.progression_v2.module_shield.hp,10),"diversion precedes recipient shield consumption")
	check(is_equal_approx(hero.hp,999) and not hero.special.progression_v2.has("module_shield") and not hero.special[L.KEY].has("recycled"),"transferred electric hit consumes own shield then life without electric refund")
	ally.special.progression_v2.erase("module_shield");ally.hp=1000;hero.hp=1000
	hero.special[L.KEY].stolen={"hp":1.0,"left":6.0};hero.special[L.KEY].shield={"hp":1.0,"left":6.0};hero.special[L.KEY].recycled={"hp":1.0,"left":4.0}
	hero.special.hero_command_rank=1
	hit(ally,100,enemy)
	check(is_equal_approx(hero.hp,999) and not hero.special[L.KEY].has("stolen") and not hero.special[L.KEY].has("shield") and not hero.special[L.KEY].has("recycled"),"all three native hero shields absorb transferred damage in normal order")
	ally.position=hero.position+Vector2(200,0);farther.hp=1000;hero.hp=1000
	hit(farther,100,enemy)
	check(Safety.protected(hero)==farther and farther.hp==920 and hero.hp==996,"nearest protection reselects after previous vehicle leaves range")
	hero.hp=3;hit(farther,100,enemy)
	check(hero._dead and hero.hp==0 and farther.hp==840,"rank-four hero can die from transfer while current protected hit remains split")
	await finish()

func eligibility_safety() -> void:
	for reason in ["range","hero_emp","hero_frozen","hero_embarked","hero_shutdown","target_frozen","target_embarked","target_hero","temporary","miner","infantry","air","ship","unarmed","other_side","allied_house","rank_three","classic"]:
		var hero=defense_hero(3 if reason=="rank_three" else 4);health(hero)
		var id:String={"miner":"HARV","infantry":"E2","air":"ORCA","ship":"SUB","unarmed":"SMCV"}.get(reason,"HTNK")
		var ally=target(id,"enemy" if reason in ["other_side","allied_house"] else "ally",hero.position+Vector2(80,0));health(ally)
		var enemy=target("HTNK","enemy",hero.position+Vector2(400,0))
		match reason:
			"range":ally.position=hero.position+Vector2(166,0)
			"hero_emp":hero._stun_timer=2
			"hero_frozen":hero.special.temporal_by=enemy
			"hero_embarked":hero.embarked_in=enemy
			"hero_shutdown":hero.special[L.KEY].shutdown_left=2
			"target_frozen":ally.special.temporal_by=enemy
			"target_embarked":ally.embarked_in=hero
			"target_hero":ally.special.academy_hero="HTNK"
			"temporary":ally.special.expansion_temporary={"kind":"test"}
			"classic":BattleRequest.rules_mode=MatchRules.RA2
			"allied_house":
				BattleRequest.house_teams={"ally":1,"enemy":1}
				check(BattleRequest.friendly(hero.side,ally.side),"fixture is a real allied but distinct house")
		check(Safety.protected(hero)==null,"protection selection excludes "+reason)
		check(Safety.divert(ally,100,"bullet",{},enemy)==100 and hero.hp==1000,"ineligible hit is not diverted: "+reason)
		await finish()

func shutdown() -> void:
	var hero=defense_hero(5);health(hero);hero.special.hero_command_rank=5;Command.install(hero)
	power_setup(hero)
	hero._load_equipped_skills({"active":[LC.ACTIVE],"passive":""})
	var ab=ability(hero)
	check(LC.cast(hero,ab,hero.position+Vector2(80,0)),"real W field exists before lethal hit")
	var cd:float=ab.cd_left
	var enemy=target("HTNK","enemy",hero.position+Vector2(200,0))
	var ally=target("HTNK","ally",hero.position+Vector2(100,0));health(ally)
	check(battle.power_stats().hero_bonus==100,"pre-shutdown station supplies real base power")
	hero.order_move(hero.position+Vector2(300,0));hit(hero,2000,enemy)
	check(hero.hp==1 and Safety.stopped(hero) and hero.special[L.KEY].shutdown_used and hero.special[L.KEY].emergency_shield==400,"ordinary lethal hit leaves one health and independent forty-percent emergency shield")
	check(battle.allied_state.get(LC.FIELDS,[]).is_empty() and battle.power_stats().hero_bonus==0 and battle.power_low,"shutdown immediately clears courts and real hero power")
	check(Safety.protected(hero)==null and not hero.has_move_order,"shutdown cancels motion and stops diversion")
	var position:Vector2=hero.position
	hero.order_move(position+Vector2(100,0));hero.attack_target=enemy;hero.attack_ordered=true;hero._cd_timer=0
	check(not hero.has_move_order and not hero._try_fire_ready(),"shutdown rejects movement and native firing")
	var slot:=UnitSkillLayout.find(hero,LC.ACTIVE);ab.cd_left=0
	check(not hero.ability_ready(slot) and not hero.use_ability(slot,position) and not LC.cast(hero,ab,position),"shutdown rejects both real skill input and W entry")
	ab.cd_left=cd
	hit(hero,100,enemy);check(hero.hp==1 and hero.special[L.KEY].emergency_shield==300,"subsequent hit consumes emergency shield instead of granting invulnerability")
	Safety.tick(hero,2.99);check(Safety.stopped(hero) and hero.hp==1,"recovery cannot happen before full three seconds")
	Safety.tick(hero,.01)
	check(not Safety.stopped(hero) and hero.hp==200 and hero.special[L.KEY].emergency_shield==300,"surviving shutdown restores minimum health without refilling shield")
	check(battle.power_stats().hero_bonus==100 and Safety.protected(hero)==ally and ab.cd_left==cd and battle.allied_state.get(LC.FIELDS,[]).is_empty(),"recovery resumes power and diversion but grants no free W or cooldown reset")
	hit(hero,2000,enemy)
	check(hero._dead and hero.hp==0,"second ordinary lethal hit kills instead of repeating one-per-match shutdown")
	await finish()

func lethal_boundaries() -> void:
	for reason in ["transfer","shield_break","execute","erase","forced","removal","physics","healed"]:
		var hero=defense_hero(5);health(hero);var enemy=target()
		if reason=="transfer":
			var ally=target("HTNK","ally",hero.position+Vector2(70,0));health(ally);hero.hp=3
			hit(ally,100,enemy)
			check(hero.hp==1 and Safety.stopped(hero) and ally.hp==920,"lethal transferred damage may trigger unused shutdown")
		elif reason=="shield_break":
			hit(hero,2000,enemy);hit(hero,402,enemy)
			check(hero._dead and hero.hp==0,"shield can break and hero can die inside shutdown window")
			Safety.tick(hero,3);check(hero.hp==0 and hero._dead,"expired shutdown never revives a dead hero")
		elif reason=="physics":
			hit(hero,2000,enemy);hero.attack_target=enemy;hero.attack_ordered=true;hero._cd_timer=0
			var origin:Vector2=hero.position;var enemy_hp:float=enemy.hp
			hero.has_move_order=true;hero.move_target=origin+Vector2(300,0)
			hero._physics_process(.2)
			check(hero.position==origin and hero.velocity==Vector2.ZERO and enemy.hp==enemy_hp and is_equal_approx(hero.special[L.KEY].shutdown_left,2.8),"actual physics tick advances shutdown while blocking stale movement and attack orders")
		elif reason=="healed":
			hit(hero,2000,enemy);hero.heal(349);Safety.tick(hero,3)
			check(hero.hp==350 and hero.special[L.KEY].emergency_shield==400,"recovery does not lower externally healed health or refill shield")
		elif reason=="removal":
			hero._die(enemy,true)
			check(hero._dead and not hero.special[L.KEY].has("shutdown_used"),"native temporal removal bypasses lethal-hit protection")
		else:
			hit(hero,2000,enemy,"bullet" if reason=="forced" else reason,{"force_execute":reason=="forced"})
			check(hero._dead and not hero.special[L.KEY].has("shutdown_used"),"shutdown does not intercept "+reason)
		await finish()

func safety_save() -> void:
	var hero=defense_hero(5);health(hero);var enemy=target();hit(hero,2000,enemy);hit(hero,70,enemy);Safety.tick(hero,1.25)
	var codec=BattleSaves.Snapshot.new();var snapshot:Dictionary=codec.capture(battle)
	var file=FileAccess.open(output_dir.path_join("safety.bin"),FileAccess.WRITE);file.store_var(snapshot,false);file.close()
	file=FileAccess.open(output_dir.path_join("safety.bin"),FileAccess.READ);snapshot=file.get_var(false);file.close();codec.restore(battle,snapshot);hero=get_hero()
	check(codec.error.is_empty() and hero.is_in_group(Safety.GROUP) and hero.hp==1 and hero.special[L.KEY].shutdown_left==1.75 and hero.special[L.KEY].emergency_shield==330 and hero.special[L.KEY].shutdown_used,"binary restore preserves group, spent once flag, remaining shutdown and consumed shield")
	Safety.tick(hero,1.75);check(hero.hp==200 and not Safety.stopped(hero),"restored shutdown completes only its remaining interval")
	await finish()

func safety_expedition() -> void:
	MetaProgress.reset_save();MetaProgress.academy.hero_survival_ranks={"TTNK":5}
	check(Expedition.start("苏俄","",910) and Expedition.choose(0),"start expedition for rank-five defensive hero")
	var next:Dictionary=Expedition.state.duplicate(true);next.stage=5
	check(preload("res://scripts/expedition/heroes.gd").recruit(next,"TTNK") and Expedition.commit(next) and Expedition.launch(0),"real expedition recruits and deploys defensive hero")
	screen=load("res://scenes/battle.tscn").instantiate();add_child(screen);screen.process_mode=Node.PROCESS_MODE_DISABLED;battle=screen.battle
	var hero=get_hero();var enemy=target("HTNK","enemy",hero.position+Vector2(100,0))
	hit(hero,hero.max_hp*10,enemy);Safety.tick(hero,1.0)
	check(Expedition.checkpoint(battle),"checkpoint writes active shutdown")
	await finish()
	check(Expedition.load_run() and Expedition.prepare_battle(),"reload actual expedition checkpoint")
	screen=load("res://scenes/battle.tscn").instantiate();add_child(screen);screen.process_mode=Node.PROCESS_MODE_DISABLED;battle=screen.battle;hero=get_hero()
	check(hero!=null and hero.is_in_group(Safety.GROUP) and hero.special[L.KEY].shutdown_used and hero.special[L.KEY].shutdown_left==2,"expedition restore does not replenish one-use defense or restart countdown")
	Safety.tick(hero,2);check(is_equal_approx(hero.hp,hero.max_hp*.2),"expedition restored shutdown reaches minimum recovery")
	await finish()
