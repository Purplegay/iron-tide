extends "res://tests/tanya_contract_regression.gd"
const T=preload("res://scripts/units/tanya_talents.gd")
const O=preload("res://scripts/units/tanya_operations.gd")

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
	await get_tree().process_frame
	await prices_and_ui()
	await detection()
	await splitting_and_movement()
	await single_target_split()
	await swimming()
	await swim_cumulative_shields()
	await survival()
	await baseline_small_hits()
	await demolition()
	await demolition_boundaries()
	await lethal_boundaries()
	await native_dog_and_isolation()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	print("TANYA_TALENTS_RESULT ",checks.size()," checks, ",failed," failed")
	get_tree().quit(0 if failed==0 else 1)

func setup_talents(command:int,defense:int):
	MetaProgress.reset_save()
	MetaProgress.academy.hero_builds={"TANY":5}
	MetaProgress.academy.hero_escort_ranks={"TANY":command}
	MetaProgress.academy.hero_survival_ranks={"TANY":defense}
	boot("TANY")
	var hero=battle.spawn_unit("TANY","ally",Vector2(1050,1000))
	A.promote(MetaProgress,battle,"TANY",hero)
	return hero

func prices_and_ui() -> void:
	MetaProgress.reset_save();MetaProgress.academy.hero_builds={"TANY":5}
	var page=load("res://scripts/ui/hero_progression.gd").new();add_child(page);page.selected="TANY"
	for action in ["escort","survival"]:
		var key:="hero_escort_ranks" if action=="escort" else "hero_survival_ranks"
		for level in 5:
			var price:int=[40,120,240,400,600][level]
			MetaProgress.currency.cores=price-1;page.refresh()
			var button=page.escort if action=="escort" else page.survival
			check(A.hero_talent_cost(action,level,"TANY")==price and button.disabled,"new talent quote and insufficient UI "+action+str(level))
			check(not A.purchase(MetaProgress,action,"TANY") and MetaProgress.balance("cores")==price-1,"insufficient talent purchase leaves wallet unchanged")
			MetaProgress.currency.cores=price;page.refresh();button.pressed.emit()
			check(MetaProgress.balance("cores")==0 and MetaProgress.academy[key].TANY==level+1,"real UI buys functional level "+action+str(level+1))
			MetaProgress.load_save()
			check(MetaProgress.academy[key].TANY==level+1,"talent level survives profile reload")
		MetaProgress.currency.cores=1000;page.refresh()
		check(not A.purchase(MetaProgress,action,"TANY") and MetaProgress.balance("cores")==1000,"level five is hard cap")
	for track in 2:
		page.talent_demo.talent.select(track);page.talent_demo._select_talent()
		check(page.talent_demo.levels.item_count==6,"all six functional levels have demo selectors")
	page.free();await get_tree().process_frame
	boot("TANY")
	MetaProgress.academy.hero_escort_ranks.TANY=0
	var hero=battle.spawn_unit("TANY","ally",Vector2(1050,1000));A.promote(MetaProgress,battle,"TANY",hero)
	check(T.rank(hero)==5 and T.rank(hero,true)==5,"both talent paths freeze at match opening")
	await finish()

func detection() -> void:
	var hero=setup_talents(1,0)
	var spy=battle.spawn_unit("SPY","enemy",hero.position+Vector2(90,0));spy.special.disguise="E1"
	await get_tree().physics_frame
	check(not AlliedAbilities.concealed(spy,"ally"),"nearby hero identifies disguised infantry")
	spy.special.erase("disguise");spy.special.echo_cloaked=true
	check(battle.actor_visible_to("ally",spy) and not AlliedAbilities.concealed(spy,"ally"),"nearby hero exposes invisible ground target in world and targeting")
	spy.position=hero.position+Vector2(111,0);battle.neighborhood.relocate(spy)
	check(not battle.actor_visible_to("ally",spy),"detection stops beyond two cells even in same neighborhood bucket")
	spy.position=hero.position+Vector2(90,0);battle.neighborhood.relocate(spy)
	var wall:=StaticBody2D.new();var shape:=CollisionShape2D.new();var box:=RectangleShape2D.new();box.size=Vector2(12,100)
	shape.shape=box;wall.add_child(shape);wall.process_mode=Node.PROCESS_MODE_ALWAYS;battle.add_child(wall);wall.position=hero.position+Vector2(45,0);wall.collision_layer=1
	await get_tree().physics_frame
	check(not battle.actor_visible_to("ally",spy),"solid collision wall blocks close detection")
	wall.free();await get_tree().physics_frame
	var sub=battle.spawn_unit("SUB","enemy",hero.position+Vector2(50,30))
	check(not O.detects(battle,"ally",sub),"ground detection never becomes submarine sonar")
	var ship=battle.spawn_unit("DEST","enemy",hero.position+Vector2(50,20))
	check(not O.detects(battle,"ally",ship),"ground detection excludes surface ships as well")
	var carrier=battle.spawn_unit("FV","ally",hero.position)
	hero.embarked_in=carrier
	check(not O.detects(battle,"ally",spy),"embarked hero cannot detect through transport")
	hero.embarked_in=null
	await finish()

func splitting_and_movement() -> void:
	var hero=setup_talents(2,0)
	hero.process_mode=Node.PROCESS_MODE_ALWAYS;hero.set_process(false);hero.set_physics_process(false)
	await get_tree().physics_frame
	var main=robust_enemy("E2",hero.position+Vector2(110,0))
	var near=robust_enemy("E2",main.position+Vector2(30,0))
	var far=robust_enemy("E2",main.position+Vector2(56,0))
	hero.attack_target=main;hero.hull_angle=0;hero.turret_angle=0
	for volley in 3:
		hero._cancel_burst();hero._cd_timer=0
		check(hero._try_fire_ready(),"ordinary weapon starts volley "+str(volley+1))
		check((near.hp==100000)==(volley<2),"only every third volley adds the secondary shot")
	check(near.hp>99000 and far.hp==100000,"split gun is ordinary scaled damage and respects one-cell radius")
	check(int(hero.special[C.KEY].split_round)==3,"burst shots cannot advance the round counter")
	hero._cancel_burst();hero._cd_timer=0;hero.has_move_order=true;hero.move_target=hero.position+Vector2(200,0)
	check(not hero._try_fire_ready(),"rank two hero cannot fire ordinary guns while moving")
	hero.special.hero_command_rank=4
	check(hero._try_fire_ready(),"rank four enables real moving double-pistol volley")
	check(is_equal_approx(O.move_factor(hero),.7),"firing animation gives seventy-percent movement factor")
	var goal:Vector2=hero.move_target
	hero._process_combat(.05)
	check(hero.move_target==goal and hero.has_move_order,"moving fire preserves player's destination")
	hero.fire_stance="none";hero._cancel_burst();hero._cd_timer=0
	check(not hero._try_fire_ready(),"moving-fire talent still respects ceasefire")
	hero.fire_stance="free";hero.attack_target=robust_enemy("HTNK",main.position)
	check(not O.target_allowed(hero,hero.attack_target),"moving fire cannot become moving anti-vehicle sabotage")
	await finish()

func swimming() -> void:
	var hero=setup_talents(0,2)
	var enemy=robust_enemy("E2",hero.position+Vector2(180,0))
	battle.path_service.set_water([Rect2(hero.position-Vector2.ONE*60,Vector2.ONE*120)])
	C.tick(hero,1.99);check(not T.hidden(hero),"swim cloak requires two full quiet seconds")
	C.tick(hero,.01);check(T.hidden(hero) and not battle.actor_visible_to("enemy",hero),"quiet swim becomes enemy-invisible")
	var detector=battle.spawn_unit("DOG","enemy",hero.position+Vector2(70,0))
	check(battle.actor_visible_to("enemy",hero) and not AlliedAbilities.concealed(hero,"enemy"),"native detector exposes submerged Tanya without consuming her cloak")
	detector.free();battle.units.erase(detector)
	var before:float=hero.hp
	hero.receive_hit(hero.max_hp*.1,"shell",{},enemy)
	check(is_equal_approx(before-hero.hp,Ra2Damage.quantize(hero.max_hp*.1/hero.bonuses.get("defense_bonus",1)/hero.bonuses.get("veteran_defense",1))),"breaking hit is paid before swim shield")
	check(not T.hidden(hero) and is_equal_approx(hero.special[C.KEY].swim_shield.hp,hero.max_hp*.15),"surviving swim exit grants fifteen percent shield")
	C.tick(hero,2);check(T.hidden(hero),"remaining in water can conceal again")
	T.attacking(hero)
	check(not T.hidden(hero) and is_equal_approx(hero.special[C.KEY].swim_shield.left,2),"second exit during cooldown cannot refill or extend same shield")
	C.tick(hero,13);check(T.hidden(hero),"swimming resumes while exit cooldown elapses")
	battle.path_service.set_water([]);C.tick(hero,.01)
	check(not T.hidden(hero) and is_equal_approx(hero.special[C.KEY].swim_shield.hp,hero.max_hp*.15),"leaving actual water grants new shield after interval")
	await finish()

func single_target_split() -> void:
	var hero=setup_talents(2,0)
	var main=robust_enemy("E2",hero.position+Vector2(110,0))
	hero.attack_target=main;hero.hull_angle=0;hero.turret_angle=0
	var ordinary_damage:=0.0
	for i in 3:
		hero._cancel_burst();hero._cd_timer=0
		var hp:float=main.hp
		check(hero._try_fire_ready(),"single-target normal volley fires "+str(i))
		if i==0:ordinary_damage=hp-main.hp
		check(is_equal_approx(hp-main.hp,ordinary_damage),"single-target third volley does not add side damage to primary "+str(i))
	check(int(hero.special[C.KEY].split_round)==3,"missing secondary still completes third normal round")
	var next=robust_enemy("E2",main.position+Vector2(30,0))
	hero._cancel_burst();hero._cd_timer=0
	check(hero._try_fire_ready() and next.hp==100000,"secondary appearing on fourth round cannot consume deferred third-round attack")
	await finish()

func native_dog_and_isolation() -> void:
	var hero=setup_talents(5,1)
	var dog=battle.spawn_unit("DOG","enemy",hero.position)
	var weapon:Dictionary=dog._active_weapon()
	check(preload("res://scripts/units/dog_pounce.gd").start(dog,hero,weapon),"native dog starts contact leap against hero")
	preload("res://scripts/units/dog_pounce.gd").tick(dog,.01)
	check(not hero._dead and is_equal_approx(hero.hp,hero.max_hp*2.0/3.0),"native dog warhead passes through anti-hunter lethal cap")
	check(is_equal_approx(float(hero.special[C.KEY].get("shield",{}).get("hp",0)),hero.max_hp*.1),"surviving native dog cap also grants cumulative baseline injury shield")
	var ordinary=battle.spawn_unit("TANY","ally",hero.position+Vector2(90,0))
	check(T.rank(ordinary)==-1 and not A.crush_immune(ordinary),"ordinary Tanya never inherits hero talents")
	await finish()
	boot("TANY",MatchRules.RA2)
	hero=battle.spawn_unit("TANY","ally",Vector2(1050,1000))
	A.promote(MetaProgress,battle,"TANY",hero)
	check(T.rank(hero)==-1 and not hero.special.has(C.KEY),"purchased advanced ranks remain disabled in classic mode")
	await finish()

func baseline_small_hits() -> void:
	var hero=setup_talents(0,0);hero.max_hp=1000;hero.hp=1000;hero._base_max_hp=1000
	var enemy=robust_enemy("E2",hero.position+Vector2(80,0))
	var incoming_scale:=1.0/CombatMath.with_defense(1.0,hero.bonuses)
	for i in 3:
		hero.receive_hit(100*incoming_scale,"bullet",{},enemy,"RA3_PRISM")
		check(is_equal_approx(hero.hp,1000-(i+1)*100) and not hero.special[C.KEY].has("shield") and not hero.special[C.KEY].has("escape_cd"),"three separate real ten-percent injuries do not accumulate a shield "+str(i))
	await finish()

func survival() -> void:
	var hero=setup_talents(0,1)
	var enemy=robust_enemy("E2",hero.position+Vector2(80,0))
	var original:float=hero.hp
	hero.receive_hit(100000,"bullet",{"impact_weapon":"AWP"},enemy)
	check(not hero._dead and is_equal_approx(original-hero.hp,hero.max_hp/3.0),"anti-hunter limits only otherwise lethal rifle hit to one third max health")
	check(is_equal_approx(float(hero.special[C.KEY].get("shield",{}).get("hp",0)),hero.max_hp*.1),"surviving sniper cap also grants cumulative baseline injury shield")
	hero.special[C.KEY].erase("shield");hero.hp=hero.max_hp*.2
	hero.receive_hit(100000,"bullet",{"impact_weapon":"AWP"},enemy)
	check(hero._dead,"one-third cap does not rescue low-health hero")
	await finish()
	hero=setup_talents(0,4);enemy=robust_enemy("E2",hero.position+Vector2(80,0))
	var distant=robust_enemy("E2",hero.position+Vector2(111,0))
	hero.receive_hit(100000,"crush",{},enemy)
	check(hero.hp==hero.max_hp and A.crush_immune(hero),"rank three immunity applies to actual crush receive path")
	hero.hp=hero.max_hp*.3
	hero.receive_hit(hero.max_hp*.1,"shell",{},enemy)
	check(enemy.special.has("tanya_flash_left") and not distant.special.has("tanya_flash_left"),"low-health flash silences only visible infantry within two cells")
	enemy.attack_target=hero;enemy.hull_angle=PI;enemy._cd_timer=0
	check(not enemy._try_fire_ready() and not enemy.buff_entries().is_empty(),"flash blocks real next volley and exposes countdown status")
	hero.special[C.KEY].erase("shield");C.tick(hero,40)
	enemy.special.erase("tanya_flash_left")
	hero.receive_hit(1,"shell",{},enemy)
	check(not enemy.special.has("tanya_flash_left"),"flash cannot repeat without recovery above threshold")
	hero.hp=hero.max_hp*.4;C.tick(hero,.01);hero.hp=hero.max_hp*.26
	hero.receive_hit(hero.max_hp*.1,"shell",{},enemy)
	check(enemy.special.has("tanya_flash_left"),"healing rearms flash after cooldown")
	await finish()
	hero=setup_talents(0,5);enemy=robust_enemy("HTNK",hero.position+Vector2(180,0))
	hero.add_buff("electric_slow",10,.5,"ordinary slow")
	hero.receive_hit(100000,"shell",{},enemy)
	check(hero.hp==1 and T.hidden(hero) and T.locked(hero) and hero.special[C.KEY].last_used,"last stand preserves one health and grants new cloak after lethal hit")
	check(not hero.has_buff("electric_slow"),"last stand clears existing ordinary slow")
	hero.attack_target=enemy;hero._cd_timer=0
	check(not hero._try_fire_ready(),"last stand cannot attack during two-second window")
	var codec=BattleSaves.Snapshot.new();var saved:Dictionary=codec.capture(battle)
	var save_path:=output_dir.path_join("last-stand-snapshot.bin")
	var file:=FileAccess.open(save_path,FileAccess.WRITE);file.store_var(saved,false);file.close()
	file=FileAccess.open(save_path,FileAccess.READ);saved=file.get_var(false);file.close()
	codec.restore(battle,saved)
	for unit in battle.units:
		if unit.special.get("academy_hero")=="TANY":hero=unit
		if unit.unit_id=="HTNK" and unit.side=="enemy":enemy=unit
	check(codec.error.is_empty() and hero.special[C.KEY].last_used and T.locked(hero),"save retains used last stand and current attack lock")
	hero.receive_hit(100000,"explosive",{},enemy)
	check(hero._dead,"later area damage can kill last-stand hero; no immunity or second rescue")
	await finish()

func demolition() -> void:
	var hero=setup_talents(5,0)
	var primary=battle._place_building("NAPOWR","enemy",Vector2(1400,1100),true)
	var next=battle._place_building("NAPOWR","enemy",Vector2(1500,1100),true)
	var victim=robust_enemy("E2",Vector2(1400,1190))
	var heavy=robust_enemy("HTNK",victim.position)
	var light=robust_enemy("FV",victim.position)
	var outside=robust_enemy("E2",Vector2(1400,1400))
	var shock:=CombatMath.with_offense(float(CommandoCombat.weapon_for(hero,null).damage)*.6,hero.bonuses)
	primary.special.c4_left=.01;primary.special.c4_owner=hero
	AlliedAbilities.tick_actor(primary,.02)
	check(primary._dead and victim.hp<100000 and outside.hp==100000,"native C4 creates local ground-unit shockwave only")
	check(next.hp==next.max_hp,"nearby building receives no immediate shock damage from native primary C4")
	check(is_equal_approx(100000-victim.hp,Ra2Damage.quantize(shock)),"C4 shock uses sixty percent ordinary attack against infantry")
	check(is_equal_approx(100000-heavy.hp,Ra2Damage.quantize(shock*.65)),"C4 shock uses the specified heavy armor coefficient")
	check(is_equal_approx(100000-light.hp,Ra2Damage.quantize(shock*.8)),"C4 shock uses the specified light armor coefficient")
	check(next.special.get("c4_secondary",false) and next.special.c4_left==4.0,"native C4 attaches four-second charge to nearest eligible building")
	check(hero.special[C.KEY].chain_used==1 and hero.special[C.KEY].chain_cd==60,"successful attachment spends one use and cooldown")
	var codec=BattleSaves.Snapshot.new();var snapshot:Dictionary=codec.capture(battle);codec.restore(battle,snapshot)
	for unit in battle.units:
		if unit.special.get("academy_hero")=="TANY":hero=unit
		if unit.unit_id=="E2" and unit.position.is_equal_approx(Vector2(1400,1190)):victim=unit
	for building in battle.buildings:
		if building.position.is_equal_approx(Vector2(1500,1100)):next=building
	check(codec.error.is_empty() and hero.special[C.KEY].chain_used==1 and next.special.c4_secondary and is_same(next.special.c4_owner,hero),"snapshot preserves chain allowance, countdown and owner link")
	var after:float=victim.hp
	AlliedAbilities.tick_actor(next,4.0)
	check(next._dead and victim.hp==after and hero.special[C.KEY].chain_used==1,"secondary C4 cannot recursively shock or chain")
	C.tick(hero,60)
	var first=battle._place_building("NAPOWR","enemy",Vector2(1400,1600),true)
	var second=battle._place_building("NAPOWR","enemy",Vector2(1500,1600),true)
	first.special.c4_left=.01;first.special.c4_owner=hero;AlliedAbilities.tick_actor(first,.02)
	check(hero.special[C.KEY].chain_used==2 and second.special.get("c4_secondary",false),"second actual attachment uses final match allowance")
	AlliedAbilities.change_side(second,"ally");AlliedAbilities.tick_actor(second,.01)
	check(not second.special.has("c4_left") and not second._dead,"captured secondary target cancels fixed chain without refund")
	C.tick(hero,60)
	first=battle._place_building("NAPOWR","enemy",Vector2(1400,1900),true)
	second=battle._place_building("NAPOWR","enemy",Vector2(1500,1900),true)
	first.special.c4_left=.01;first.special.c4_owner=hero;AlliedAbilities.tick_actor(first,.02)
	check(not second.special.has("c4_left") and hero.special[C.KEY].chain_used==2,"third original C4 cannot exceed two chain uses")
	await finish()

func demolition_boundaries() -> void:
	var hero=setup_talents(5,0)
	var first=battle._place_building("NAPOWR","enemy",Vector2(1400,1100),true)
	var second=battle._place_building("NAPOWR","enemy",Vector2(1500,1100),true)
	first.special.c4_left=.01;first.special.c4_owner=hero;AlliedAbilities.tick_actor(first,.02)
	var engineer=battle.spawn_unit("SENGINEER","enemy",AlliedAbilities.approach(hero,second))
	check(AlliedAbilities.use(engineer,"allied_engineer",second),"real engineer accepts chained C4 disarm")
	engineer.position=AlliedAbilities.approach(engineer,second)
	AlliedAbilities.tick_action(engineer,.02)
	check(not second.special.has("c4_left") and not second.special.has("c4_secondary") and not engineer._dead,"engineer removes chain and marker without being consumed")
	check(hero.special[C.KEY].chain_used==1 and hero.special[C.KEY].chain_cd==60,"disarming does not refund consumed chain allowance")
	C.tick(hero,59.99)
	var early_primary=battle._place_building("NAPOWR","enemy",Vector2(1400,1600),true)
	var early_neighbor=battle._place_building("NAPOWR","enemy",Vector2(1500,1600),true)
	early_primary.special.c4_left=.01;early_primary.special.c4_owner=hero
	AlliedAbilities.tick_actor(early_primary,.02)
	check(early_primary._dead and not early_neighbor.special.has("c4_left") and hero.special[C.KEY].chain_used==1 and is_equal_approx(hero.special[C.KEY].chain_cd,.01),"real demolition just before sixty-second boundary cannot transfer after prior disarm")
	for protection in ["iron_left","force_shield_left","expedition_protected"]:
		second.special.c4_left=.01;second.special.c4_owner=hero;second.special.c4_secondary=true;second.special.c4_side="ally"
		second.special[protection]=true if protection=="expedition_protected" else 5.0
		AlliedAbilities.tick_actor(second,.02)
		check(not second._dead and not second.special.has("c4_left"),"chain cannot bypass active protection "+protection)
		second.special.erase(protection)
	C.tick(hero,60)
	var isolated=battle._place_building("NAPOWR","enemy",Vector2(300,1900),true)
	var neutral=battle._place_building("NAPOWR","neutral",Vector2(400,1900),true)
	isolated.special.c4_left=.01;isolated.special.c4_owner=hero;AlliedAbilities.tick_actor(isolated,.02)
	check(hero.special[C.KEY].chain_used==1 and not hero.special[C.KEY].has("chain_cd"),"no eligible secondary target spends neither cooldown nor use")
	check(not neutral.special.has("c4_left"),"neutral neighbor cannot consume chain allowance")
	await finish()

func lethal_boundaries() -> void:
	var hero=setup_talents(0,1)
	var enemy=robust_enemy("HTNK",hero.position+Vector2(100,0))
	hero.receive_hit(100000,"shell",{"impact_weapon":"120mm"},enemy)
	check(hero._dead,"rank one anti-hunter never caps ordinary tank shell")
	await finish()
	hero=setup_talents(0,5);enemy=robust_enemy("E2",hero.position+Vector2(150,0))
	hero.receive_hit(100000,"bullet",{"impact_weapon":"AWP"},enemy)
	check(not hero.special[C.KEY].get("last_used",false),"rifle cap resolves before last stand and does not consume unused rescue")
	hero.special[C.KEY].erase("shield");hero.hp=hero.max_hp
	battle.path_service.set_water([Rect2(hero.position-Vector2.ONE*50,Vector2.ONE*100)])
	C.tick(hero,2)
	hero.receive_hit(100000,"explosive",{},enemy)
	check(hero.hp==1 and hero.special[C.KEY].has("last_cloak") and not hero.special[C.KEY].has("swimming"),"swim-breaking lethal hit keeps newly granted last-stand cloak")
	check(hero.special[C.KEY].has("swim_shield"),"swim shield appears after surviving the triggering hit")
	var slot:=Ability.new();slot.setup(GameData.get_skill(B.ID));hero.skills.append(slot)
	check(not hero.ability_ready(hero.skills.size()-1) and not B.cast(hero,slot,hero.position+Vector2(80,0)),"last stand blocks both UI and direct contract cast entry")
	C.tick(hero,2)
	check(not T.locked(hero) and hero.special[C.KEY].last_used,"attack lock expires without restoring per-match rescue")
	await finish()
	hero=setup_talents(0,5);enemy=robust_enemy("E2",hero.position+Vector2(150,0))
	hero.receive_hit(100000,"execute",{},enemy)
	check(hero._dead and not hero.special[C.KEY].get("last_used",false),"explicit execution bypasses last stand without pretending ordinary damage")
	await finish()

func swim_cumulative_shields() -> void:
	var hero=setup_talents(0,2)
	var enemy=robust_enemy("E2",hero.position+Vector2(180,0))
	hero.max_hp=100;hero.hp=100;hero._base_max_hp=100
	hero.bonuses.defense_bonus=1.;hero.bonuses.veteran_defense=1.
	battle.path_service.set_water([Rect2(hero.position-Vector2.ONE*60,Vector2.ONE*120)])
	C.tick(hero,2)
	check(T.hidden(hero),"cumulative shield case really entered swim cloak")
	hero.receive_hit(20,"shell",{},enemy)
	var state:Dictionary=hero.special[C.KEY]
	check(hero.hp==80 and not T.hidden(hero),"twenty damage first removes health and swim concealment")
	check(state.shield.hp==10 and state.shield.left==3 and state.swim_shield.hp==15 and state.swim_shield.left==4,"rank-two swimming retains level-zero ten shield plus fifteen exit shield")
	check(state.escape_cd==30 and state.swim_shield_cd==15,"two shield sources retain independent trigger intervals")
	C.tick(hero,2);check(T.hidden(hero),"quiet swimming recloaks while both existing shields age")
	T.attacking(hero)
	check(state.shield.left==1 and state.swim_shield.left==2 and state.swim_shield.hp==15,"repeat exit during interval does not refresh either shield")
	C.tick(hero,1)
	check(not state.has("shield") and state.swim_shield.hp==15 and state.swim_shield.left==1,"three-second baseline expires before four-second exit shield")
	C.tick(hero,1)
	check(not state.has("swim_shield") and hero.hp==80,"exit shield expires separately without restoring health")
	await finish()
