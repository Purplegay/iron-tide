extends "res://tests/leizhu_command_regression.gd"
const Station=preload("res://scripts/units/leizhu_station.gd")

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
	await get_tree().process_frame
	await penetration()
	await penetration_cover()
	await penetration_growth_and_exclusions()
	await grid_power()
	await power_exclusions()
	await power_owners_and_repack()
	await station_save()
	await station_purchases()
	await station_expedition()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	print("LEIZHU_STATION_RESULT ",checks.size()," checks, ",failed," failed")
	get_tree().quit(0 if failed==0 else 1)

func line_targets(hero) -> Array:
	var main=target("HTNK","enemy",hero.position+Vector2(245,0))
	var a=target("HTNK","enemy",hero.position+Vector2(60,0))
	var b=target("HTNK","enemy",hero.position+Vector2(120,0))
	var c=target("HTNK","enemy",hero.position+Vector2(180,0))
	return [main,a,b,c]

func penetration() -> void:
	var hero=command_hero(4);var targets:=line_targets(hero)
	var loss:Array=[]
	fire(hero,targets[0])
	for victim in targets:loss.append(100000-victim.hp);victim.hp=100000
	check(not hero.special[L.KEY].has("pierce_cd"),"immediate ordinary shot cannot trigger unprepared penetration")
	L.tick(hero,3)
	var extra:=expected(hero,targets[1],.3)
	fire(hero,targets[0])
	check(is_equal_approx(100000-targets[1].hp,float(loss[1])+extra) and is_equal_approx(100000-targets[2].hp,float(loss[2])+extra),"native prepared main adds exactly thirty percent to nearest two line targets",[loss,extra,100000-targets[1].hp,100000-targets[2].hp])
	check(is_equal_approx(100000-targets[3].hp,loss[3]),"third secondary receives only original weapon splash, no penetration")
	check(hero.special[L.KEY].pierce_cd==12 and hero.special[L.KEY].pierce_flash.points.size()==2,"prepared shot consumes one twelve-second interval and records two arc endpoints")
	check(hero.special[L.KEY].get("charge_count",0)==0 and not hero.special[L.KEY].has("stolen"),"extra penetration does not fabricate charge or stolen shield")
	L.tick(hero,3);fire(hero,targets[0]);check(hero.special[L.KEY].pierce_cd==9,"firing while trigger interval active cannot reset it")
	L.tick(hero,9);fire(hero,targets[0]);check(hero.special[L.KEY].pierce_cd==12,"quiet and interval both satisfied enables next penetration")
	await finish()

func penetration_cover() -> void:
	var hero=command_hero(4);var targets:=line_targets(hero)
	var wall:=StaticBody2D.new();wall.process_mode=Node.PROCESS_MODE_ALWAYS;wall.collision_layer=1;wall.position=hero.position+Vector2(90,0)
	var collision:=CollisionShape2D.new();var shape:=RectangleShape2D.new();shape.size=Vector2(10,60);collision.shape=shape;wall.add_child(collision);battle.add_child(wall)
	await get_tree().physics_frame;await get_tree().physics_frame
	L.tick(hero,3);fire(hero,targets[0])
	check(hero.special[L.KEY].pierce_flash.points.size()==1 and hero.special[L.KEY].pierce_flash.points[0]==targets[1].position,"real blocker cuts off line beyond first target")
	wall.free();hero.special[L.KEY].erase("pierce_cd")
	targets[1].special.echo_cloaked=true;targets[1].position+=Vector2(0,50)
	var air=target("ORCA","enemy",hero.position+Vector2(35,0));air.logistics.air_lift=1
	var friendly=target("E2","ally",hero.position+Vector2(30,0))
	var behind=target("E2","enemy",hero.position-Vector2(30,0))
	L.tick(hero,3);fire(hero,targets[0])
	check(hero.special[L.KEY].pierce_flash.points==[targets[2].position,targets[3].position],"line selects only forward visible ground enemies, excluding air, friendly and off-line actors")
	check(behind.hp==100000,"penetration never extends behind hero")
	await finish()

func power_setup(hero) -> Array:
	for building in battle.buildings:building.free()
	battle.buildings.clear();battle._refresh_pathing()
	var yard=battle._place_building("GACNST","ally",Vector2(1250,1250),true)
	var plant=battle._place_building("NAPOWR","ally",Vector2(1650,1250),true)
	var tower=battle._place_building("TESLA","ally",Vector2(1800,1500),true)
	for building in [yard,plant,tower]:building._buildup_play=-1
	yard.power=0;plant.power=50;tower.power=-120
	hero.position=yard.position+Vector2(200,0);battle._update_power()
	return [yard,plant,tower]

func penetration_growth_and_exclusions() -> void:
	var hero=cards_hero(3);hero.special.hero_command_rank=4;Command.install(hero)
	var targets:=line_targets(hero)
	hero._base_atk*=2;hero._recompute_bonuses()
	var amount:=expected(hero,targets[1],.3)
	var hidden=target("E2","enemy",hero.position+Vector2(30,0));hidden.special.echo_cloaked=true
	var behind=target("E2","enemy",hero.position+Vector2(300,0))
	fire(hero,targets[0])
	var baseline_beyond:float=100000-behind.hp
	for victim in targets+[hidden,behind]:victim.hp=100000
	give_shield(targets[1],10000);give_shield(targets[2],10000)
	L.tick(hero,8);fire(hero,targets[0])
	check(is_equal_approx(10000-shield_amount(targets[1]),amount) and is_equal_approx(10000-shield_amount(targets[2]),amount),"penetration scales with doubled attack and absorbs into actual secondary shields")
	check(not hero.special[L.KEY].has("stolen") and hero.special[L.KEY].charge_count==1 and not hero.special[L.KEY].has("arc_flash"),"secondary shield damage never steals or adds charge beyond the one primary contact")
	check(hero.special[L.KEY].marks.size()==1 and hero.special[L.KEY].marks.has(targets[0]),"extra victims gain no high-pressure mark")
	check(hidden.hp==100000 and is_equal_approx(100000-behind.hp,baseline_beyond) and hero.special[L.KEY].pierce_flash.points==[targets[1].position,targets[2].position],"concealed on-line infantry excluded; beyond endpoint receives only original weapon splash",[hidden.hp,100000-behind.hp,baseline_beyond])
	hero.special[L.KEY].erase("pierce_cd")
	battle.water_rects=[Rect2(hero.position+Vector2(85,-20),Vector2(20,40))];battle.path_service.set_water(battle.water_rects)
	L.tick(hero,3);fire(hero,targets[0])
	check(hero.special[L.KEY].pierce_flash.points==[targets[1].position],"ground discharge stops at intervening water")
	await finish()

func grid_power() -> void:
	var hero=command_hero(5);var buildings:=power_setup(hero)
	check(battle.power_produced==150 and battle.power_drain==120 and not battle.power_low,"emergency power changes actual whole-base produced total")
	check(battle.power_stats().hero_bonus==100 and hero.special[L.KEY].power_active,"HUD and hero state expose actual hundred-power contribution")
	check(battle.power_build_factor()==1 and not battle.side_power_low("ally"),"real production penalty consumer sees restored grid")
	check(buildings[2].is_operational(),"actual powered Tesla defense operates after hero restores power")
	for i in 10:battle._update_power()
	check(battle.power_produced==150 and not battle.power_low,"building-only deficit test prevents supply oscillation after covering shortfall")
	var second=battle._place_building("GACNST","ally",buildings[0].position+Vector2(300,0),true);second.power=0
	battle._update_power();check(battle.power_produced==150,"overlapping construction-yard areas do not duplicate one hero output")
	buildings[2].power=-250;battle._update_power()
	check(battle.power_produced==150 and battle.power_low and battle.power_build_factor()<1,"insufficient hundred-power boost leaves genuine deficit and production penalty")
	check(not buildings[2].is_operational(),"actual powered defense stays offline when hero output cannot cover deficit")
	buildings[1].power=300;battle._update_power()
	check(battle.power_produced==300 and not hero.special[L.KEY].power_active and battle.power_stats().hero_bonus==0,"natural base recovery turns hero supply off without adding fake power")
	check(battle._side_power("ally").produced==300,"independent per-side power query agrees with actual grid")
	buildings[1].power=50;battle._update_power()
	check(battle._side_power("ally").produced==150,"per-side query also counts eligible emergency generator")
	var hud=screen.get_node_or_null("HUD")
	if hud==null:hud=screen.get("hud")
	if hud!=null:
		hud._refresh_top();check(hud.power_sub.text.contains("英雄供电 +100"),"live HUD names hero generator separately")
	else:check(false,"live battle HUD located")
	await finish()

func power_exclusions() -> void:
	var hero=command_hero(5);var buildings:=power_setup(hero);var yard=buildings[0]
	for kind in ["far","stun","freeze","embarked","construction","lost_yard","shutdown","house_out"]:
		match kind:
			"far":hero.position=yard.position+Vector2(441,0)
			"stun":hero._stun_timer=1
			"freeze":hero.special.chrono_left=1
			"embarked":hero.embarked_in=battle.spawn_unit("FV","ally",hero.position)
			"construction":yard.under_construction=true
			"lost_yard":yard.side="enemy"
			"shutdown":hero.special[L.KEY].shutdown_left=3.0
			"house_out":battle.allied_state.get_or_add("defeated_houses",{}).ally=true
		battle._update_power()
		check(battle.power_produced==50 and not hero.special[L.KEY].power_active,"supply ends immediately for "+kind)
		hero.position=yard.position+Vector2(200,0);hero._stun_timer=0;hero.special.erase("chrono_left");hero.embarked_in=null;yard.under_construction=false;yard.side="ally";hero.special[L.KEY].erase("shutdown_left");battle.allied_state.erase("defeated_houses")
	hero.position=yard.position+Vector2(440,0);battle._update_power();check(battle.power_produced==150,"eight-cell center distance is inclusive")
	hero._die();battle._update_power();check(battle.power_produced==50 and not battle.allied_state.has("leizhu_power"),"hero death removes all emergency output")
	await finish()
	hero=command_hero(4);power_setup(hero)
	check(battle.power_produced==50 and battle.power_low,"rank four does not supply electricity")
	await finish()

func station_save() -> void:
	var hero=command_hero(5);power_setup(hero)
	L.tick(hero,3);hero.special[L.KEY].pierce_cd=7.5
	var codec=BattleSaves.Snapshot.new();var snapshot:Dictionary=codec.capture(battle)
	var file=FileAccess.open(output_dir.path_join("station.bin"),FileAccess.WRITE);file.store_var(snapshot,false);file.close();file=FileAccess.open(output_dir.path_join("station.bin"),FileAccess.READ);snapshot=file.get_var(false);file.close()
	codec.restore(battle,snapshot);hero=get_hero();battle._update_power()
	check(codec.error.is_empty() and hero.special[L.KEY].quiet==3 and hero.special[L.KEY].pierce_cd==7.5,"binary restore retains quiet preparation and penetration interval")
	check(battle.power_produced==150 and battle.power_stats().hero_bonus==100,"restored power recalculates once without duplicate contribution")
	await finish()

func power_owners_and_repack() -> void:
	var hero=command_hero(5);var buildings:=power_setup(hero)
	check(preload("res://scripts/world/construction_repack.gd").execute(battle,buildings[0]),"actual construction yard converts to MCV")
	check(battle.power_produced==50 and not hero.special[L.KEY].power_active,"packing last covering yard immediately withdraws output")
	await finish()
	hero=command_hero(5);buildings=power_setup(hero)
	for building in buildings:building.side="enemy"
	hero.side="enemy";L.tick(hero,.01);battle._update_power()
	check(battle.enemy_power.produced==150 and not battle.enemy_power.low and battle.power_produced==0,"hero supplies only its actual owner grid")
	check(battle._side_power("enemy").produced==150 and battle.power_build_factor("enemy")==1,"enemy power query and production agree")
	BattleRequest.rules_mode=MatchRules.RA2;battle._update_power()
	check(battle.enemy_power.produced==50 and battle.enemy_power.low and not hero.special[L.KEY].power_active,"classic mode excludes even imported hero state")
	await finish()

func station_purchases() -> void:
	MetaProgress.reset_save();MetaProgress.academy.hero_builds={"TTNK":5};MetaProgress.currency.cores=10000
	for rank in 5:
		check(A.purchase(MetaProgress,"escort","TTNK"),"actual command upgrade "+str(rank+1))
	MetaProgress.load_save()
	var page=preload("res://scripts/ui/hero_progression.gd").new();add_child(page);page.selected="TTNK";page.refresh()
	check(MetaProgress.academy.hero_escort_ranks.TTNK==5 and page.escort.disabled and page.talent_demo.levels.item_count==6,"full five-level command progression persists and previews all six nodes")
	check(page.escort_detail.text.contains("实际供电+100") and not page.survival.disabled,"full command description and separate implemented defense remain available")
	page.free()

func station_expedition() -> void:
	MetaProgress.reset_save();MetaProgress.academy.hero_escort_ranks={"TTNK":5}
	check(Expedition.start("苏俄","",907) and Expedition.choose(0),"start command-five expedition through actual entry")
	var roster=preload("res://scripts/expedition/heroes.gd")
	var next:Dictionary=Expedition.state.duplicate(true);next.stage=5
	check(roster.recruit(next,"TTNK") and Expedition.commit(next) and Expedition.launch(0),"recruit and launch full-command Leizhu")
	screen=load("res://scenes/battle.tscn").instantiate();add_child(screen);screen.process_mode=Node.PROCESS_MODE_DISABLED;battle=screen.battle
	var hero=get_hero();check(hero!=null and Command.rank(hero)==5,"expedition deploys frozen command-five hero")
	if hero!=null:
		power_setup(hero);hero.special[L.KEY].quiet=3.0;hero.special[L.KEY].pierce_cd=7.5
		check(Expedition.checkpoint(battle),"checkpoint writes live station power and penetration interval")
	await finish()
	check(Expedition.load_run() and Expedition.prepare_battle(),"reload actual expedition station checkpoint")
	screen=load("res://scenes/battle.tscn").instantiate();add_child(screen);screen.process_mode=Node.PROCESS_MODE_DISABLED;battle=screen.battle;hero=get_hero();battle._update_power()
	check(hero!=null and Command.rank(hero)==5 and hero.special[L.KEY].get("pierce_cd",0)==7.5 and hero.special[L.KEY].quiet==3,"checkpoint retains command rank and timers without granting new shot")
	check(battle.power_produced==150 and battle.power_stats().hero_bonus==100,"checkpoint rebuilds real power once")
	await finish()
