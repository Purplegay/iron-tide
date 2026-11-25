extends "res://tests/leizhu_cards_regression.gd"
const Command=preload("res://scripts/units/leizhu_command.gd")

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
	await get_tree().process_frame
	await theft()
	await drive_lock()
	await detectors()
	await command_save()
	await command_purchase()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	print("LEIZHU_COMMAND_RESULT ",checks.size()," checks, ",failed," failed")
	get_tree().quit(0 if failed==0 else 1)

func command_hero(level:int):
	MetaProgress.reset_save();MetaProgress.academy.hero_escort_ranks={"TTNK":level};boot("BORIS")
	var hero=battle.spawn_unit("TTNK","ally",Vector2(1000,1000));L.promote(MetaProgress,battle,hero)
	return hero

func give_shield(victim,amount:float) -> void:
	victim.special.get_or_add("progression_v2",{}).module_shield={"hp":amount,"left":20.0}

func shield_amount(victim) -> float:
	return float(victim.special.get("progression_v2",{}).get("module_shield",{}).get("hp",0))

func theft() -> void:
	var hero=command_hero(1);var victim=target();var hp:float=hero.hp
	give_shield(victim,20);var before:float=victim.hp;fire(hero,victim)
	check(shield_amount(victim)==0 and victim.hp<before and hero.special[L.KEY].stolen.hp==10,"ordinary primary steals half actual shield lost, never HP overflow")
	check(hero.hp==hp,"theft produces shield rather than healing health")
	L.tick(hero,2);fire(hero,victim)
	check(hero.special[L.KEY].stolen.hp==10 and hero.special[L.KEY].stolen.left==4,"unshielded hit neither adds shield nor refreshes duration")
	give_shield(victim,40);fire(hero,victim)
	check(is_equal_approx(hero.special[L.KEY].stolen.hp,minf(hero.max_hp*.2,30)) and hero.special[L.KEY].stolen.left==6,"effective theft adds to residual shield and refreshes six seconds")
	give_shield(victim,10000)
	for i in 4:fire(hero,victim)
	check(is_equal_approx(hero.special[L.KEY].stolen.hp,hero.max_hp*.2),"stolen shield capped at twenty percent max HP")
	hero.special[L.KEY].erase("shield");hero.special[L.KEY].stolen.hp=5;hp=hero.hp
	hero.receive_hit(60,"electric",{},victim)
	check(not hero.special[L.KEY].has("stolen") and hero.hp<hp,"real receive-hit consumes stolen shield then passes overflow")
	give_shield(victim,20);fire(hero,victim);L.tick(hero,6)
	check(not hero.special[L.KEY].has("stolen"),"stolen shield expires at six-second boundary")
	hero.special[L.KEY].erase("shield");give_shield(victim,20)
	LC.damage(hero,victim,hero._weapon_for_target(null),{"expansion_extra":true})
	check(not hero.special[L.KEY].has("stolen"),"extra electric damage cannot steal shields")
	var building=battle._place_building("NAPOWR","enemy",hero.position+Vector2(160,0),true);building._buildup_play=-1;building.special.brutal_shield=10.0
	fire(hero,building)
	check(building.special.brutal_shield==0 and hero.special[L.KEY].stolen.hp==5,"native main hit steals actual finite building shield")
	hero.side="enemy";L.tick(hero,.1)
	check(not hero.special[L.KEY].has("stolen"),"ownership change clears prior owner's stolen shield")
	await finish()
	hero=command_hero(0);victim=target();give_shield(victim,20);fire(hero,victim)
	check(not hero.special[L.KEY].has("stolen"),"baseline hero cannot steal shield")
	await finish()

func drive_lock() -> void:
	var hero=command_hero(3);var victim=target();victim.order_move(victim.position+Vector2(0,100))
	for i in 2:fire(hero,victim);check(not Command.controlled(victim),"first two main hits do not lock movement")
	fire(hero,victim)
	check(Command.controlled(victim) and victim.move_speed==0 and victim.has_move_order,"third hit blocks actual speed but preserves move order")
	check(fire(victim,hero)>0,"locked victim can still fire native weapon")
	var point:Vector2=victim.position;victim.attack_target=null;victim.fire_stance="none"
	victim._physics_process(.25)
	check(victim.position.is_equal_approx(point) and is_equal_approx(victim.special[Command.CONTROL].left,.75),"native physics keeps movement order stationary and advances lock timer")
	Command.control_tick(victim,.75)
	check(not Command.controlled(victim) and victim.move_speed>0 and victim.special[Command.CONTROL].cd==7,"one-second lock expires independently from shared target interval")
	for i in 3:fire(hero,victim)
	check(not Command.controlled(victim),"next triple during target interval cannot relock")
	Command.control_tick(victim,7)
	fire(hero,victim);L.tick(hero,4);fire(hero,victim);fire(hero,victim)
	check(not Command.controlled(victim),"four seconds without hits resets streak")
	var infantry=target("E2","enemy",hero.position+Vector2(170,50));fire(hero,infantry);fire(hero,victim)
	check(hero.special[L.KEY].drive_count==1,"switching to infantry clears vehicle streak")
	fire(hero,victim);fire(hero,victim);check(Command.controlled(victim),"three new direct hits trigger after interval")
	var before:float=victim.special[Command.CONTROL].cd
	LC.damage(hero,victim,hero._weapon_for_target(null),{"expansion_extra":true})
	check(victim.special[Command.CONTROL].cd==before and hero.special[L.KEY].drive_count==0,"extra electric damage never changes lock count or interval")
	victim.side="ally";Command.control_tick(victim,.1)
	check(not victim.special.has(Command.CONTROL) and victim.move_speed>0,"target ownership change clears obsolete movement lock")
	var harvester=target("HARV","enemy",hero.position+Vector2(150,0))
	for i in 3:fire(hero,harvester)
	check(Command.controlled(harvester),"ground-vehicle lock also applies to unarmed harvesters")
	await finish()

func detectors() -> void:
	var hero=command_hero(2);var victim=target("MGTK","enemy",hero.position+Vector2(160,0));victim.special.echo_cloaked=true
	check(Command.detects(battle,"ally",victim) and battle.actor_visible_to("ally",victim),"level two real visibility path reveals cloaked ground vehicle within three cells")
	victim.position.x+=6
	check(not Command.detects(battle,"ally",victim) and not battle.actor_visible_to("ally",victim),"leaving three-cell radius immediately restores cloak")
	victim.position.x-=6
	victim.special.erase("echo_cloaked");victim.special.disguise="TREE"
	check(not AlliedAbilities.concealed(victim,"ally"),"shared concealment consumer reveals disguised ground vehicle")
	victim.special.erase("disguise");victim.special.echo_cloaked=true
	for id in ["E1","ORCA","SUB"]:
		var excluded=target(id,"enemy",hero.position+Vector2(100,40))
		if id=="ORCA":excluded.logistics.air_lift=1
		check(not Command.detects(battle,"ally",excluded),"scanner excludes "+id)
	hero._stun_timer=1;check(not Command.detects(battle,"ally",victim),"EMP/stun suppresses scanner");hero._stun_timer=0
	hero.special.chrono_left=1;check(not Command.detects(battle,"ally",victim),"frozen hero cannot scan");hero.special.erase("chrono_left")
	var wall:=StaticBody2D.new();wall.process_mode=Node.PROCESS_MODE_ALWAYS;wall.collision_layer=1;wall.position=hero.position+Vector2(80,0)
	var collision:=CollisionShape2D.new();var rect:=RectangleShape2D.new();rect.size=Vector2(10,100);collision.shape=rect;wall.add_child(collision);battle.add_child(wall)
	await get_tree().physics_frame;await get_tree().physics_frame
	check(not Command.detects(battle,"ally",victim),"real physics blocker prevents scanner revealing through solid cover")
	wall.free()
	hero._die();check(not Command.detects(battle,"ally",victim),"dead detector grants no reveal")
	await finish()

func command_save() -> void:
	var hero=command_hero(3);var victim=target();give_shield(victim,20)
	fire(hero,victim);fire(hero,victim);L.tick(hero,.25)
	var codec=BattleSaves.Snapshot.new();var snapshot:Dictionary=codec.capture(battle)
	var file=FileAccess.open(output_dir.path_join("command.bin"),FileAccess.WRITE);file.store_var(snapshot,false);file.close()
	file=FileAccess.open(output_dir.path_join("command.bin"),FileAccess.READ);snapshot=file.get_var(false);file.close();codec.restore(battle,snapshot)
	hero=get_hero();victim=battle.units.filter(func(u):return u.side=="enemy" and u.unit_id=="HTNK")[0]
	check(codec.error.is_empty() and hero.special[L.KEY].drive_target==victim and hero.special[L.KEY].drive_count==2 and hero.special[L.KEY].stolen.left==5.75,"binary save restores target reference, two-hit streak and stolen shield duration")
	L.tick(hero,0);check(hero.is_in_group(Command.GROUP),"restored hero registers local scanner again")
	fire(hero,victim);Command.control_tick(victim,.3)
	snapshot=codec.capture(battle);codec.restore(battle,snapshot)
	hero=get_hero();victim=battle.units.filter(func(u):return u.side=="enemy" and u.unit_id=="HTNK")[0]
	check(is_equal_approx(victim.special[Command.CONTROL].left,.7) and is_equal_approx(victim.special[Command.CONTROL].cd,7.7),"active movement lock and common target interval survive restoration")
	Command.control_tick(victim,.7);check(not Command.controlled(victim),"restored lock expires without reapplying")
	await finish()

func command_purchase() -> void:
	MetaProgress.reset_save();MetaProgress.academy.hero_builds={"TTNK":5};MetaProgress.currency.cores=10000
	var page=preload("res://scripts/ui/hero_progression.gd").new();add_child(page);page.selected="TTNK";page.refresh()
	for level in 5:
		var cost:=A.hero_talent_cost("escort",level,"TTNK");var before:int=MetaProgress.balance("cores")
		check(not page.escort.disabled and A.purchase(MetaProgress,"escort","TTNK") and MetaProgress.balance("cores")==before-cost,"real tier purchase charges exact core price "+str(level+1))
		MetaProgress.load_save();page.refresh()
	check(MetaProgress.academy.hero_escort_ranks.TTNK==5 and page.escort.disabled and not page.survival.disabled,"level five persists; capped command and separately available defense")
	check(not A.purchase(MetaProgress,"escort","TTNK"),"capped command cannot consume currency")
	check(page.talent_demo.levels.item_count==6 and page.escort_detail.text.contains("应急供电"),"UI exposes all six implemented command nodes")
	page.free();boot("BORIS");MetaProgress.academy.hero_escort_ranks.TTNK=0
	var hero=battle.spawn_unit("TTNK","ally",Vector2(1000,1000));L.promote(MetaProgress,battle,hero)
	check(Command.rank(hero)==5,"hero rank uses opening combat snapshot, not mutable lobby profile")
	await finish()
	MetaProgress.reset_save();MetaProgress.currency.cores=10000;MetaProgress.save()
	var bytes:=FileAccess.get_file_as_bytes(MetaProgress.SAVE_PATH)
	DirAccess.make_dir_absolute(MetaProgress.SAVE_PATH+".tmp")
	check(not A.purchase(MetaProgress,"escort","TTNK") and MetaProgress.balance("cores")==10000 and MetaProgress.academy.get("hero_escort_ranks",{}).get("TTNK",0)==0,"failed command upgrade save rolls back currency and rank")
	check(FileAccess.get_file_as_bytes(MetaProgress.SAVE_PATH)==bytes,"failed upgrade preserves previous profile bytes")
	DirAccess.remove_absolute(MetaProgress.SAVE_PATH+".tmp")
