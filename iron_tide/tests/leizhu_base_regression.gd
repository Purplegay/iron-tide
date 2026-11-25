extends "res://tests/commando_hero_regression.gd"
const L=preload("res://scripts/units/leizhu.gd")
const Gifts=preload("res://scripts/rules/hero_reinforcements.gd")
const LG=preload("res://scripts/rules/leizhu_reinforcements.gd")

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
	await get_tree().process_frame
	await production_case()
	await eligibility()
	await marks()
	await shields()
	await moving_shield()
	await saved_state()
	await production_save()
	await training_effects()
	await hero_ui()
	await expedition_case_leizhu()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	print("LEIZHU_BASE_RESULT ",checks.size()," checks, ",failed," failed")
	get_tree().quit(0 if failed==0 else 1)

func boot(id:String,mode:=MatchRules.EXTENDED) -> void:
	# Combat cases exercise an unlocked profile; threshold cases explicitly seed 0..4.
	MetaProgress.academy.get_or_add("hero_builds",{}).get_or_add("TTNK",5)
	super.boot(id,mode)

func factory(owner:="ally"):
	var producer=battle._place_building("NAWEAP",owner,Vector2(1400,1300),true)
	for id in ["NAPOWR","NAREFN","NAHAND","NARADR","NATECH"]:
		var building=battle._place_building(id,owner,Vector2(1700,800)+Vector2(0,["NAPOWR","NAREFN","NAHAND","NARADR","NATECH"].find(id)*180),true)
		building._buildup_play=-1
	producer._buildup_play=-1;battle._update_power()
	return producer

func get_hero(owner:="ally"):
	for unit in battle.units:
		if L.active(unit) and unit.side==owner:return unit
	return null

func queue_tank(producer) -> Array:
	var before:Array=battle.units.duplicate();var funds:float=battle.funds
	var queued:bool=producer.enqueue("TTNK")
	check(queued,"real paid TTNK production accepted",producer.queue_block_reason("TTNK"))
	if not queued:return []
	for i in 2400:
		if producer.production.is_empty():break
		producer._process(.1)
	check(producer.production.is_empty(),"real production completion")
	check(is_equal_approx(funds-battle.funds,battle.production_price(GameData.get_unit("TTNK"),producer.side)),"only ordinary Tesla tank costs funds")
	return battle.units.filter(func(u):return not before.has(u))

func production_case() -> void:
	MetaProgress.reset_save();boot("BORIS");var producer=factory()
	for i in 3:
		var added:=queue_tank(producer)
		check(added.size()==(2 if i==2 else 1),"paid products retained and gift appears on exact third tank "+str(i),added.size())
		if not added.is_empty():Gifts.produced(battle,producer,added[0])
		check(int(battle.allied_state.get(LG.KEY,{}).get("ally",{}).get("count",0))==i+1,"duplicate completion does not advance third-tank count")
	var hero=get_hero()
	check(hero!=null,"unlocked profile receives third-product hero")
	if hero!=null:
		check(hero.veteran_level==2 and hero.special.hero_command_rank==0 and hero.special.hero_survival_rank==0,"hero starts elite with independent baseline traits")
		check(not Unit.TankHero.active(hero) and not A.legacy_bonuses(hero) and A.survival_rank(hero)==-1,"new hero cannot inherit old tank or infantry survival rules")
		check(battle.units.filter(func(u):return u.unit_id=="TTNK" and not u.special.has(L.KEY)).size()==3,"all three paid Tesla tanks remain ordinary")
		hero._die()
	check(queue_tank(producer).size()==1 and get_hero()==null,"hero death does not renew gift")
	await finish()
	boot("BORIS");producer=factory()
	for i in 3:queue_tank(producer)
	check(get_hero()!=null,"new match resets production milestone")
	await finish()

func setup_hero():
	MetaProgress.reset_save();boot("BORIS")
	var hero=battle.spawn_unit("TTNK","ally",Vector2(1000,1000));L.promote(MetaProgress,battle,hero)
	return hero

func target(id:="HTNK",owner:="enemy",point:=Vector2(1150,1000)):
	var victim=battle.spawn_unit(id,owner,point);victim.hp=100000;victim.max_hp=100000
	return victim

func fire(hero,victim) -> float:
	var before:float=victim.hp
	hero.attack_target=victim;hero.attack_ordered=true;hero._cd_timer=0;hero._burst_left=0
	hero.aim_dir=hero.position.direction_to(victim.position);hero.hull_angle=hero.aim_dir.angle();hero.turret_angle=hero.hull_angle
	check(hero._try_fire_ready(),"native Tesla hero actually fires primary")
	for projectile in battle.projectiles_root.get_children():
		if projectile is Projectile and projectile.shooter()==hero and not projectile._detonated:projectile._explode()
	return before-victim.hp

func eligibility() -> void:
	for kind in ["classic","direct","temporary","ra3","enemy","pending"]:
		MetaProgress.reset_save();boot("BORIS",MatchRules.RA2 if kind=="classic" else MatchRules.EXTENDED)
		var owner:="enemy" if kind=="enemy" else "ally"
		var producer=factory(owner)
		if kind=="classic":
			for i in 3:queue_tank(producer)
			check(get_hero()==null and not battle.allied_state.has(LG.KEY),"classic actual production never grants hero")
		else:
			for i in 3:
				var unit=battle.spawn_unit("TTNK",owner,Vector2(1000,1000+i*60))
				if kind=="temporary":unit.special.expansion_temporary={"kind":"reserve","left":10}
				if kind=="ra3":unit.unit_id="R3HAMMER"
				if kind=="pending":battle.path_service.water_rects=[Rect2(Vector2.ZERO,Vector2(battle.map_size,battle.map_size))]
				if kind!="direct":Gifts.produced(battle,producer,unit)
			if kind=="enemy":check(get_hero("enemy")!=null and get_hero()==null,"independent same-owner enemy gift")
			elif kind=="pending":
				check(get_hero()==null and battle.allied_state[LG.KEY].ally.pending,"blocked terrain keeps pending gift without overlap")
				var codec=BattleSaves.Snapshot.new();var snapshot:Dictionary=codec.capture(battle);codec.restore(battle,snapshot)
				battle.path_service.water_rects.clear();LG.tick(battle,.25)
				check(codec.error.is_empty() and get_hero()!=null and not battle.allied_state[LG.KEY].ally.pending,"saved pending gift resumes when legal ground becomes available")
			else:check(get_hero()==null and not battle.allied_state.has(LG.KEY),"ineligible source cannot advance gift "+kind)
		await finish()

func marks() -> void:
	var hero=setup_hero();var victim=target()
	var first:=fire(hero,victim)
	check(first>0 and hero.special[L.KEY].marks.has(victim),"first true main hit marks enemy combat vehicle")
	var second:=fire(hero,victim)
	check(is_equal_approx(second,Ra2Damage.quantize(first*1.1)) and not hero.special[L.KEY].marks.has(victim),"second native main hit consumes mark for ten percent increase",[first,second])
	var third:=fire(hero,victim)
	check(third==first and hero.special[L.KEY].marks.has(victim),"consuming hit cannot reapply mark; third hit begins new pair")
	L.tick(hero,4);check(not hero.special[L.KEY].marks.has(victim),"mark expires after four seconds")
	for id in ["E2","HARV","SUB"]:
		var other=target(id)
		var bonus:Dictionary={"leizhu_primary":true,"leizhu_side":"ally"}
		L.impact(other,hero,100,bonus)
		check(not hero.special[L.KEY].marks.has(other),"mark excludes noncombat-ground-vehicle "+id)
	var before:float=victim.hp
	victim.receive_hit(100,"electric",{"leizhu_primary":true,"leizhu_side":"ally","expansion_extra":true},hero)
	check(victim.hp<before and not hero.special[L.KEY].marks.has(victim),"secondary electrical hit cannot mark")
	fire(hero,victim);victim.side="ally";L.tick(hero,.1)
	check(not hero.special[L.KEY].marks.has(victim),"mark drops when target becomes friendly")
	await finish()

func shields() -> void:
	var hero=setup_hero();hero.position+=Vector2(50,0);L.tick(hero,3.9)
	check(not hero.special[L.KEY].has("shield"),"no shield before full quiet period")
	L.tick(hero,.1);var amount:float=hero.max_hp*.08
	check(is_equal_approx(hero.special[L.KEY].shield.hp,amount) and is_equal_approx(hero.special[L.KEY].shield.left,6),"four quiet seconds grant exact eight-percent six-second shield")
	var enemy=target();var hp:float=hero.hp
	hero.receive_hit(10,"electric",{},enemy)
	check(hero.hp==hp and hero.special[L.KEY].shield.hp<amount,"ordinary damage consumes real hero shield first")
	var enemy_hp:float=enemy.hp
	hero.receive_hit(amount*4,"electric",{},enemy)
	check(hero.hp<hp and not hero.special[L.KEY].has("shield") and enemy.hp==enemy_hp,"breaking shield passes overflow with no legacy tank burst")
	L.tick(hero,17.9);check(not hero.special[L.KEY].has("shield"),"no regrant before eighteen-second trigger interval")
	L.tick(hero,.1);check(hero.special[L.KEY].has("shield"),"continuous quiet can trigger at interval boundary")
	L.tick(hero,6);check(not hero.special[L.KEY].has("shield"),"shield expires rather than persisting indefinitely")
	fire(hero,enemy);L.tick(hero,3)
	check(hero.special[L.KEY].quiet==3,"ordinary primary fire resets quiet preparation")
	await finish()

func saved_state() -> void:
	var hero=setup_hero();var victim=target();fire(hero,victim);L.tick(hero,2)
	var codec=BattleSaves.Snapshot.new();var snapshot:Dictionary=codec.capture(battle)
	var file=FileAccess.open(output_dir.path_join("leizhu.bin"),FileAccess.WRITE);file.store_var(snapshot,false);file.close()
	file=FileAccess.open(output_dir.path_join("leizhu.bin"),FileAccess.READ);snapshot=file.get_var(false);file.close();codec.restore(battle,snapshot)
	hero=get_hero();victim=battle.units.filter(func(u):return u.unit_id=="HTNK")[0]
	check(codec.error.is_empty() and hero.special[L.KEY].marks.has(victim) and hero.special[L.KEY].marks[victim].left==2 and hero.special[L.KEY].quiet==2,"binary snapshot preserves target reference, mark time and quiet time")
	L.tick(hero,2)
	check(hero.special[L.KEY].has("shield") and hero.special[L.KEY].marks.is_empty(),"restored timers progress without fresh promotion")
	var health:float=hero.max_hp;L.promote(MetaProgress,battle,hero)
	check(hero.max_hp==health and hero.special[L.KEY].has("shield"),"repeated promotion cannot reset state or multiply training")
	fire(hero,victim);battle.units.erase(victim);victim.free()
	snapshot=codec.capture(battle);codec.restore(battle,snapshot);hero=get_hero()
	check(codec.error.is_empty() and hero.special[L.KEY].marks.is_empty(),"snapshot safely drops freed marked-target keys without hanging or reviving target")
	await finish()

func moving_shield() -> void:
	var hero=setup_hero();var origin:Vector2=hero.position
	hero.process_mode=Node.PROCESS_MODE_ALWAYS;hero.set_process(false);hero.set_physics_process(false)
	hero.fire_stance="none";hero._think_timer=10000;hero.order_move(origin+Vector2(300,0))
	await get_tree().physics_frame
	var dt:=1.0/Engine.physics_ticks_per_second
	for i in int(4/dt):hero._physics_process(dt)
	check(hero.position.distance_to(origin)>20 and hero.special[L.KEY].has("shield"),"actual moving physics accumulates quiet time and grants shield")
	var shield:float=hero.special[L.KEY].shield.hp
	check(shield==hero.max_hp*.08,"native movement path grants only one correctly sized shield")
	await finish()

func hero_ui() -> void:
	MetaProgress.reset_save();MetaProgress.currency={"credits":10000,"cores":10000}
	MetaProgress.academy.hero_builds={"TTNK":5}
	var page=load("res://scripts/ui/hero_progression.gd").new();add_child(page);page.selected="TTNK";page.refresh()
	check(A.HEROES.get("TTNK")=="雷铸" and A.hero_requirement("TTNK")==5,"hero registry requires five Tesla tanks")
	check(page.progress_label.text.contains("第三辆") and not page.escort.disabled and not page.survival.disabled,"UI explains third product and exposes implemented command and defense ranks")
	check(A.purchase(MetaProgress,"survival","TTNK") and MetaProgress.balance("cores")==9960,"first implemented defense rank charges exact price")
	check(A.purchase(MetaProgress,"health","TTNK") and A.training_rank(MetaProgress.academy.hero_training,"TTNK","health")==1,"real independent health training purchase works")
	MetaProgress.load_save();check(A.training_rank(MetaProgress.academy.hero_training,"TTNK","health")==1,"hero training persists")
	var wallet:int=MetaProgress.balance("credits");var previous:=FileAccess.get_file_as_bytes(MetaProgress.SAVE_PATH)
	DirAccess.make_dir_absolute(MetaProgress.SAVE_PATH+".tmp")
	check(not A.purchase(MetaProgress,"firepower","TTNK") and MetaProgress.balance("credits")==wallet and A.training_rank(MetaProgress.academy.hero_training,"TTNK","firepower")==0,"training save failure rolls back rank and currency")
	check(FileAccess.get_file_as_bytes(MetaProgress.SAVE_PATH)==previous,"failed training leaves prior profile bytes unchanged")
	DirAccess.remove_absolute(MetaProgress.SAVE_PATH+".tmp")
	check(page.talent_demo.hero_id=="TTNK" and page.talent_demo.levels.item_count==6,"all implemented command ranks can be previewed")
	page.free()

func production_save() -> void:
	MetaProgress.reset_save();boot("BORIS");var producer=factory()
	for i in 2:queue_tank(producer)
	var codec=BattleSaves.Snapshot.new();var snapshot:Dictionary=codec.capture(battle)
	var file=FileAccess.open(output_dir.path_join("production-two.bin"),FileAccess.WRITE);file.store_var(snapshot,false);file.close()
	file=FileAccess.open(output_dir.path_join("production-two.bin"),FileAccess.READ);snapshot=file.get_var(false);file.close();codec.restore(battle,snapshot)
	producer=battle.buildings.filter(func(b):return b.building_id=="NAWEAP" and b.side=="ally")[0]
	check(codec.error.is_empty() and battle.allied_state[LG.KEY].ally.count==2,"binary save preserves exact two-tank production milestone")
	check(queue_tank(producer).size()==2 and get_hero()!=null,"next actual paid product after reload grants exactly one extra hero")
	var hero=get_hero()
	if hero!=null:
		hero.special[L.KEY].quiet=1;hero.special[L.KEY].shield={"hp":7.0,"left":2.5};hero.special[L.KEY].shield_cd=12.0
		snapshot=codec.capture(battle);codec.restore(battle,snapshot);hero=get_hero()
		check(hero.special[L.KEY].shield.hp==7 and hero.special[L.KEY].shield.left==2.5 and hero.special[L.KEY].shield_cd==12,"damaged shield, remaining duration and trigger interval restore exactly")
		producer=battle.buildings.filter(func(b):return b.building_id=="NAWEAP" and b.side=="ally")[0]
		var ordinary=battle.units.filter(func(u):return u.unit_id=="TTNK" and not L.active(u))[0]
		Gifts.produced(battle,producer,ordinary);LG.tick(battle,1)
		check(battle.allied_state[LG.KEY].ally.count==3 and battle.units.filter(func(u):return L.active(u)).size()==1,"restored completed product replay cannot increment count or duplicate LeiZhu")
		hero._die();snapshot=codec.capture(battle);codec.restore(battle,snapshot)
		producer=battle.buildings.filter(func(b):return b.building_id=="NAWEAP" and b.side=="ally")[0]
		check(codec.error.is_empty() and queue_tank(producer).size()==1 and get_hero()==null,"restored hero death and fourth real product do not renew LeiZhu gift")
		check(battle.allied_state[LG.KEY].ally.count==4,"post-reload fourth product advances only ordinary production count")
	await finish()

func training_effects() -> void:
	MetaProgress.reset_save();MetaProgress.academy.hero_training={"TTNK":{"health":4,"firepower":3}}
	boot("BORIS")
	var ordinary=battle.spawn_unit("TTNK","ally",Vector2(1000,1000));ordinary._grant_veteran(2,false)
	var hero=battle.spawn_unit("TTNK","ally",Vector2(1000,1100));L.promote(MetaProgress,battle,hero)
	var expected:float=1.0+.01*A.training_percent("health",4,BattleRequest.combat_context.hero_training_scale)
	check(is_equal_approx(hero.max_hp,ordinary.max_hp*expected),"frozen combat profile applies hero-only health training once")
	check(hero._base_atk>ordinary._base_atk and Loadouts.effective(MetaProgress,"TTNK").passive=="","hero firepower training applies while loadout remains independently empty")
	var hp:float=hero.max_hp;MetaProgress.academy.hero_training.TTNK.health=100
	check(hero.max_hp==hp,"changing lobby profile cannot retroactively change current hero")
	L.tick(hero,4);var hostile=target();hostile._base_atk=10
	check(hero.special[L.KEY].shield.hp==hero.max_hp*.08,"shield scales with actual trained maximum life")
	hero.side="enemy";L.tick(hero,.1)
	check(not hero.special[L.KEY].has("shield") and hero.special[L.KEY].marks.is_empty(),"owner change clears old-owner shield and target state")
	await finish()

func expedition_case_leizhu() -> void:
	MetaProgress.reset_save()
	check(Expedition.start("苏俄","",906) and Expedition.choose(0),"start real Soviet expedition")
	var roster=preload("res://scripts/expedition/heroes.gd")
	check("TTNK" not in roster.available(Expedition.state),"hero recruitment is not offered before stage five")
	var next:Dictionary=Expedition.state.duplicate(true);next.stage=5
	check(roster.recruit(next,"TTNK") and Expedition.commit(next) and Expedition.launch(0),"stage-five expedition recruits actual Leizhu")
	screen=load("res://scenes/battle.tscn").instantiate();add_child(screen);screen.process_mode=Node.PROCESS_MODE_DISABLED;battle=screen.battle
	var hero=get_hero();check(hero!=null,"expedition deploys named hero without three production requirement")
	if hero!=null:
		L.tick(hero,4);hero.special[L.KEY].shield.hp=7
		check(Expedition.checkpoint(battle),"real checkpoint writes hero shield")
	await finish()
	check(Expedition.load_run() and Expedition.prepare_battle(),"real expedition checkpoint reloads")
	screen=load("res://scenes/battle.tscn").instantiate();add_child(screen);screen.process_mode=Node.PROCESS_MODE_DISABLED;battle=screen.battle;hero=get_hero()
	check(hero!=null and hero.special[L.KEY].get("shield",{}).get("hp",0)==7,"expedition preserves existing shield rather than regranting it")
	await finish()
