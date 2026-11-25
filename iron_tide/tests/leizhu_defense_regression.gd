extends "res://tests/leizhu_station_regression.gd"
const Defense=preload("res://scripts/units/leizhu_defense.gd")
const Native=preload("res://scripts/units/soviet_advanced.gd")

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
	await get_tree().process_frame
	await parasites()
	await purge_controls()
	await recovery()
	await recovery_exclusions()
	await defense_save()
	await defense_purchase()
	await defense_expedition()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	print("LEIZHU_DEFENSE_RESULT ",checks.size()," checks, ",failed," failed")
	get_tree().quit(0 if failed==0 else 1)

func defense_hero(level:int):
	MetaProgress.reset_save();MetaProgress.academy.hero_survival_ranks={"TTNK":level};boot("BORIS")
	var hero=battle.spawn_unit("TTNK","ally",Vector2(1000,1000));L.promote(MetaProgress,battle,hero)
	return hero

func infest(hero):
	var drone=battle.spawn_unit("DRON","enemy",hero.position+Vector2(10,0))
	Native.contact(drone,hero)
	check(hero.special.get("parasite")==drone and drone.embarked_in==hero,"actual native infestation attaches drone")
	return drone

func parasites() -> void:
	var hero=defense_hero(1);hero.hp=10000;hero.max_hp=10000
	# Isolate parasite/countermeasure damage from the hero's elite self-repair.
	hero._hero_heal_interval=0;hero._vet_self_heal=0;hero._regen_frac=0;hero.data=hero.data.duplicate(true);hero.data.erase("self_repair")
	var drone=infest(hero)
	check(hero.special[L.KEY].purge_left==2,"native contact immediately starts two-second countermeasure")
	for i in 95:hero._physics_process(.02)
	check(hero.hp<10000 and AlliedAbilities.alive(drone) and hero.special.has("parasite"),"real physics permits parasite damage throughout preparation",[hero.hp,hero.max_hp,hero.special,drone.weapon])
	for i in 6:hero._physics_process(.02)
	check(not AlliedAbilities.alive(drone) and not hero.special.has("parasite") and not hero.special.has("parasite_timer"),"real physics discharges after two seconds and destroys attached parasite")
	check(hero.special[L.KEY].purge_cd>29.9 and hero.special[L.KEY].purge_cd<=30 and hero.hp<10000,"discharge consumes interval without healing previous damage")
	var another=infest(hero);Defense.tick(hero,2)
	check(AlliedAbilities.alive(another) and hero.special[L.KEY].purge_left==0,"new parasite is not purged while shared interval remains")
	Defense.tick(hero,28)
	check(not AlliedAbilities.alive(another) and hero.special[L.KEY].purge_cd==30,"remaining parasite can be purged after thirty-second interval")
	await finish()
	hero=defense_hero(0);drone=infest(hero);Defense.tick(hero,3)
	check(AlliedAbilities.alive(drone) and not hero.special[L.KEY].has("purge_cd"),"rank zero retains ordinary parasite behavior")
	await finish()

func purge_controls() -> void:
	for kind in ["emp","freeze","repair","escape","death","classic","owner"]:
		var hero=defense_hero(1);var drone=infest(hero)
		match kind:
			"emp":hero._stun_timer=4
			"freeze":hero.special.chrono_left=4
			"repair":Native.cleanse(hero,true)
			"escape":Native.release_drone(hero)
			"death":hero._die(drone)
			"classic":BattleRequest.rules_mode=MatchRules.RA2
			"owner":hero.side="enemy"
		L.tick(hero,2)
		if kind in ["emp","freeze"]:
			check(AlliedAbilities.alive(drone) and hero.special[L.KEY].purge_left==0,"ready discharge cannot fire during "+kind)
			hero._stun_timer=0;hero.special.erase("chrono_left");L.tick(hero,.01)
			check(not AlliedAbilities.alive(drone) and hero.special[L.KEY].purge_cd==30,"ready discharge resumes only after "+kind+" ends")
		elif kind in ["repair","escape"]:
			check(not hero.special[L.KEY].has("purge_left") and not hero.special[L.KEY].has("purge_cd"),"external parasite removal does not consume purge "+kind)
		elif kind=="owner":check(not hero.special[L.KEY].has("purge_cd"),"owner transition does not discharge old pending event")
		else:check(not hero.special[L.KEY].has("purge_cd"),"ineligible host never discharges "+kind)
		await finish()

func recovery() -> void:
	var hero=defense_hero(2);var attacker=target("SHK","enemy",hero.position+Vector2(120,0))
	var before:float=hero.hp;fire(attacker,hero);var loss:float=before-hero.hp
	check(loss>0 and is_equal_approx(hero.special[L.KEY].get("recycled",{}).get("hp",0),minf(loss*.2,hero.max_hp*.15)),"native hostile electric weapon creates twenty-percent recovery only after life loss",[loss,hero.special,attacker.weapon])
	if not hero.special[L.KEY].has("recycled"):await finish();return
	var old_shield:float=hero.special[L.KEY].recycled.hp
	before=hero.hp;hero.receive_hit(40,"electric",{},attacker)
	check(is_equal_approx(hero.special[L.KEY].recycled.hp,minf((before-hero.hp+old_shield)*.2,hero.max_hp*.15)),"next hit counts consumed old recovery shield plus actual life loss exactly once")
	Defense.tick(hero,3.9);check(hero.special[L.KEY].has("recycled"),"independent recovery shield lives full four seconds")
	Defense.tick(hero,.1);check(not hero.special[L.KEY].has("recycled"),"recovery shield expires without replacing base coil shield")
	give_shield(hero,10000);before=hero.hp
	hero.receive_hit(2000,"electric",{},attacker)
	check(hero.hp==before and hero.special[L.KEY].recycled.hp==hero.max_hp*.15,"real external shield absorption grants recovery capped at fifteen percent max life")
	var life:float=hero.hp;hero.special.get("progression_v2",{}).erase("module_shield")
	var shield:float=hero.special[L.KEY].recycled.hp
	hero.receive_hit(20,"bullet",{},attacker)
	check(hero.hp==life and hero.special[L.KEY].recycled.hp<shield and hero.special[L.KEY].recycled.left==4,"recovery absorbs other damage normally without new electric refund")
	await finish()

func recovery_exclusions() -> void:
	for kind in ["friendly","self","extra","transfer","secondary","bullet","lethal","classic","rank_one","invulnerable"]:
		var hero=defense_hero(1 if kind=="rank_one" else 2)
		var attacker=target("SHK","ally" if kind=="friendly" else "enemy",hero.position+Vector2(120,0))
		var bonus:Dictionary={}
		if kind=="self":attacker=hero
		if kind=="extra":bonus.expansion_extra=true
		if kind=="transfer":bonus.leizhu_transfer=true
		if kind=="secondary":bonus.equipment_secondary=true
		if kind=="classic":BattleRequest.rules_mode=MatchRules.RA2
		if kind=="invulnerable":hero.special.iron_left=3
		hero.receive_hit(100000 if kind=="lethal" else 20,"bullet" if kind=="bullet" else "electric",bonus,attacker)
		check(not hero.special[L.KEY].has("recycled"),"no recovery shield for "+kind)
		if kind=="lethal":check(not AlliedAbilities.alive(hero),"recovery never rescues fatal electric damage")
		await finish()

func defense_save() -> void:
	var hero=defense_hero(2);var attacker=target("SHK","enemy",hero.position+Vector2(120,0));hero.receive_hit(20,"electric",{},attacker)
	infest(hero);Defense.tick(hero,.75)
	var amount:float=hero.special[L.KEY].recycled.hp
	var codec=BattleSaves.Snapshot.new();var snapshot:Dictionary=codec.capture(battle)
	var file=FileAccess.open(output_dir.path_join("defense.bin"),FileAccess.WRITE);file.store_var(snapshot,false);file.close();file=FileAccess.open(output_dir.path_join("defense.bin"),FileAccess.READ);snapshot=file.get_var(false);file.close()
	codec.restore(battle,snapshot);hero=get_hero()
	check(codec.error.is_empty() and Defense.rank(hero)==2 and hero.special[L.KEY].purge_target==hero.special.parasite and hero.special[L.KEY].purge_left==1.25,"binary restore preserves actual parasite reference and remaining preparation")
	check(hero.special[L.KEY].recycled.hp==amount and hero.special[L.KEY].recycled.left==3.25,"binary restore preserves damaged recovery shield and duration")
	Defense.tick(hero,1.25);check(not hero.special.has("parasite") and hero.special[L.KEY].purge_cd==30,"restored countermeasure completes once without restarting delay")
	await finish()

func defense_purchase() -> void:
	MetaProgress.reset_save();MetaProgress.academy.hero_builds={"TTNK":5};MetaProgress.currency.cores=10000
	var page=preload("res://scripts/ui/hero_progression.gd").new();add_child(page);page.selected="TTNK";page.refresh()
	for level in 5:
		var before:int=MetaProgress.balance("cores");page.survival.pressed.emit();page.refresh();MetaProgress.load_save()
		check(MetaProgress.academy.hero_survival_ranks.TTNK==level+1 and MetaProgress.balance("cores")==before-[40,120,240,400,600][level],"actual defense UI purchase persists exact next-rank price "+str(level+1))
	page.talent_demo.talent.select(1);page.talent_demo._select_talent()
	check(page.survival.disabled and not A.purchase(MetaProgress,"survival","TTNK") and page.talent_demo.levels.item_count==6,"full rank-five defense cannot charge again and all six nodes preview")
	check(page.survival_detail.text.contains("电能回收") and not page.survival_detail.text.contains("应急供电"),"defense description does not claim already-open command power is unavailable")
	page.free();boot("BORIS");MetaProgress.academy.hero_survival_ranks.TTNK=0
	var hero=battle.spawn_unit("TTNK","ally",Vector2(1000,1000));L.promote(MetaProgress,battle,hero)
	check(Defense.rank(hero)==5,"defense rank uses frozen match profile")
	await finish()
	MetaProgress.reset_save();MetaProgress.currency.cores=10000;MetaProgress.save()
	var old:=FileAccess.get_file_as_bytes(MetaProgress.SAVE_PATH);DirAccess.make_dir_absolute(MetaProgress.SAVE_PATH+".tmp")
	check(not A.purchase(MetaProgress,"survival","TTNK") and MetaProgress.balance("cores")==10000 and MetaProgress.academy.get("hero_survival_ranks",{}).get("TTNK",0)==0 and FileAccess.get_file_as_bytes(MetaProgress.SAVE_PATH)==old,"failed defense save rolls back wallet and rank with previous profile bytes intact")
	DirAccess.remove_absolute(MetaProgress.SAVE_PATH+".tmp")

func defense_expedition() -> void:
	MetaProgress.reset_save();MetaProgress.academy.hero_survival_ranks={"TTNK":2}
	check(Expedition.start("苏俄","",908) and Expedition.choose(0),"start real expedition with defensive profile")
	var next:Dictionary=Expedition.state.duplicate(true);next.stage=5
	check(preload("res://scripts/expedition/heroes.gd").recruit(next,"TTNK") and Expedition.commit(next) and Expedition.launch(0),"recruit defensive hero through stage-five expedition")
	screen=load("res://scenes/battle.tscn").instantiate();add_child(screen);screen.process_mode=Node.PROCESS_MODE_DISABLED;battle=screen.battle
	var hero=get_hero();var attacker=target("SHK","enemy",hero.position+Vector2(100,0));hero.receive_hit(20,"tesla",{},attacker)
	infest(hero);Defense.tick(hero,.75)
	var amount:float=hero.special[L.KEY].recycled.hp
	check(Expedition.checkpoint(battle),"actual checkpoint writes active parasite and recovered shield")
	await finish()
	check(Expedition.load_run() and Expedition.prepare_battle(),"load actual defense checkpoint")
	screen=load("res://scenes/battle.tscn").instantiate();add_child(screen);screen.process_mode=Node.PROCESS_MODE_DISABLED;battle=screen.battle;hero=get_hero()
	check(hero!=null and Defense.rank(hero)==2 and hero.special[L.KEY].purge_left==1.25 and hero.special[L.KEY].purge_target==hero.special.parasite,"expedition restores pending parasite with original timing and profile")
	check(hero.special[L.KEY].recycled.hp==amount and hero.special[L.KEY].recycled.left==3.25,"expedition preserves recovery shield instead of granting a fresh shield")
	Defense.tick(hero,1.25);check(not hero.special.has("parasite") and hero.special[L.KEY].purge_cd==30,"restored expedition purges actual parasite only once")
	await finish()
