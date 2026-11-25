extends "res://tests/boris_contract_regression.gd"
const Sortie=preload("res://scripts/units/boris_sortie.gd")

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
	await get_tree().process_frame
	for level in 6:await rank_cases(level)
	await retarget_cases()
	await protection_cases()
	await fog_cases()
	await restore_cases()
	await death_cases()
	await interception_and_limits()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	print("BORIS_SORTIE_RESULT ",checks.size()," checks, ",failed," failed")
	get_tree().quit(0 if failed==0 else 1)

func building(at:Vector2,side:="enemy"):
	var target=battle._place_building("NAPOWR",side,at,true)
	target._buildup_play=-1;target.max_hp=100000;target.hp=100000;target.bonuses={"defense_bonus":1.0}
	return target

func dispatch(hero,target) -> Array:
	hero.attack_target=target;hero.attack_ordered=true
	Soviet.designate(hero,target)
	return hero.special.airstrike_wing

func rank_cases(level:int) -> void:
	var hero=setup_boris(3);hero.special.hero_command_rank=level
	var main=building(Vector2(1250,1000));var other=building(Vector2(1350,1000))
	earn(hero,3)
	var jets:=dispatch(hero,main)
	check(jets.size()==(6 if level==5 else 4),"rank %d has native four plus only rank five extra two"%level)
	check(BF.preview(hero).count==0,"whole wing consumes one calibration snapshot")
	var primary_count:=0;var secondary_count:=0
	for jet in jets:
		var run:Dictionary=jet.special.strike_run
		if run.target==main:primary_count+=1
		if run.target==other:secondary_count+=1
		check(int(run.boris_receipt.count)==3 and run.ammo==1 and jet.veteran_level==2,"each native MiG keeps elite ammunition and same receipt snapshot")
	check(primary_count==4 and secondary_count==(2 if level==5 else 0),"extra aircraft never increase main allocation")
	var alternative=building(Vector2(1200,1200))
	Soviet.designate(hero,alternative)
	check(not alternative.special.has("airstrike_mark") and hero.special.airstrike_wing.size()==jets.size(),"direct second designation cannot replace occupied hero wing")
	if level>=3:
		var infantry=robust_enemy("E2",hero.position+Vector2(100,0))
		hero.attack_target=infantry;hero.has_move_order=true;hero.move_target=hero.position+Vector2(300,0)
		Soviet._advance_mark(main,.2)
		check(main.special.has("airstrike_mark"),"independent mark survives different rifle target and move order")
		hero.has_move_order=false;hero.hull_angle=0;hero._cd_timer=0
		check(hero._try_fire_ready(),"Boris really fires rifle while own MiGs remain inbound")
		hero.attack_target=null;hero.attack_ordered=false;hero.position+=Vector2(400,0)
		for jet in jets:
			var target=jet.special.strike_run.target
			jet.position=target.position-Vector2(20,0);Soviet.fly_mig(jet,.01)
			check(jet.special.strike_run.outbound and jet.special.strike_run.ammo==0,"independent aircraft drops its actual native bomb after spotter moves away")
		check(Q.progress(battle,"BORIS").get("sorties",0)==1,"main and secondary together count one contract sortie")
		var shots:Array=battle.projectiles_root.get_children().filter(func(shot):return shot is Projectile and shot.attacker_bonus.get("boris_mig",false))
		check(shots.size()==jets.size()*2,"real elite burst remains two bombs per aircraft")
		for shot in shots:shot._explode()
		check(main.hp<100000 and (other.hp<100000 if level==5 else other.hp==100000),"actual bomb impacts follow separate assigned buildings")
	else:
		hero.attack_target=null;hero.attack_ordered=false
		Soviet._advance_mark(main,.1);Soviet.fly_mig(jets[0],.01)
		check(not main.special.has("airstrike_mark") and jets[0].special.strike_run.ammo==1,"lower ranks retain native guidance cancellation")
	var cd:float=hero.special.airstrike_cd
	Soviet.advance_sortie_reload(hero,100)
	check(hero.special.airstrike_cd==cd,"outbound aircraft still occupy wave without reducing cooldown")
	for i in jets.size()-1:
		battle.units.erase(jets[i]);jets[i].free()
	Soviet.advance_sortie_reload(hero,100)
	check(hero.special.has("airstrike_wing") and hero.special.airstrike_cd==cd,"last surviving secondary or primary aircraft still blocks next wave")
	var last=jets[-1];battle.units.erase(last);last.free()
	Soviet.advance_sortie_reload(hero,.1)
	check(not hero.special.has("airstrike_wing") and is_equal_approx(hero.special.airstrike_cd,cd),"only final exit starts full native recharge")
	Soviet.advance_sortie_reload(hero,1)
	check(is_equal_approx(hero.special.airstrike_cd,cd-1),"subsequent ticks advance normal recharge")
	await finish()

func retarget_cases() -> void:
	var hero=setup_boris();hero.special.hero_command_rank=5
	var main=building(Vector2(1250,1000));var other=building(Vector2(1350,1000));var replacement=building(Vector2(1250,1140))
	var jets:=dispatch(hero,main)
	check(jets[-1].special.strike_run.target==other,"secondary selection picks nearest legal building")
	other.side="ally"
	Soviet.fly_mig(jets[-1],.01)
	check(jets[4].special.strike_run.target==replacement and jets[5].special.strike_run.target==replacement,"captured secondary retargets whole secondary group together")
	check(jets[0].special.strike_run.target==main,"secondary reassignment never changes primary group")
	replacement.special.iron_left=10.0
	Soviet.fly_mig(jets[4],.01)
	check(jets[4].special.strike_run.outbound and jets[5].special.strike_run.outbound and jets[4].special.strike_run.ammo==1,"no legal replacement aborts extras without dropping bombs on primary")
	main.side="ally";Soviet.fly_mig(jets[0],.01)
	check(jets[0].special.strike_run.outbound and jets[0].special.strike_run.ammo==1,"captured primary aborts without attacking friendly target")
	await finish()

func protection_cases() -> void:
	var hero=setup_boris();hero.special.hero_command_rank=5
	var main=building(Vector2(1250,1000));var other=building(Vector2(1350,1000))
	other.special.force_shield_left=10.0
	check(dispatch(hero,main).size()==4,"protected only secondary produces no extra aircraft")
	await finish()
	for protection in ["iron_left","force_shield_left","expedition_protected"]:
		hero=setup_boris();hero.special.hero_command_rank=3
		main=building(Vector2(1250,1000));var jets:=dispatch(hero,main)
		main.special[protection]=10.0
		jets[0].position=main.position-Vector2(20,0);Soviet.fly_mig(jets[0],.01)
		check(jets[0].special.strike_run.outbound and jets[0].special.strike_run.ammo==1,"independent guidance does not pierce "+protection)
		await finish()
	hero=setup_boris();hero.special.hero_command_rank=5;hero.veteran_level=0
	main=building(Vector2(1250,1000));other=building(Vector2(1350,1000))
	var count:=int(Soviet.Rules.type_data("BORIS").airstriketeam)
	check(dispatch(hero,main).size()==count+floori(count/2.0),"extra count uses native nonelite count rounded down")
	await finish()

func fog_cases() -> void:
	var hero=setup_boris();hero.special.hero_command_rank=5
	var main=building(Vector2(1250,1000));var other=building(Vector2(1350,1000))
	var fog=preload("res://scripts/world/fog_of_war.gd").new();battle.add_child(fog);fog.setup(battle);battle.fog=fog
	fog.visible_cells.ally.fill(0);fog.explored_cells.ally.fill(1)
	fog.visible_cells.ally[fog._index(main.position)]=1
	check(Sortie.targets(hero,main,4).size()==4,"unseen secondary cannot be selected through fog")
	fog.visible_cells.ally[fog._index(other.position)]=1
	var jets:=dispatch(hero,main)
	check(jets.size()==6,"visible secondary permits extra half wing")
	fog.visible_cells.ally.fill(0)
	var before:PackedByteArray=fog.visible_cells.ally.duplicate()
	hero.attack_target=null;hero.attack_ordered=false
	Soviet._advance_mark(main,.1)
	for jet in jets:
		jet.position=jet.special.strike_run.target.position-Vector2(20,0);Soviet.fly_mig(jet,.01)
	check(jets.all(func(jet):return jet.special.strike_run.ammo==0),"fixed enemy buildings remain independently guided after fog returns")
	check(fog.visible_cells.ally==before,"guidance and target retention do not reveal fog")
	await finish()

func restore_cases() -> void:
	var hero=setup_boris(3);hero.special.hero_command_rank=5
	var main=building(Vector2(1250,1000));building(Vector2(1350,1000));earn(hero,3)
	var jets:=dispatch(hero,main);hero.attack_target=null;hero.attack_ordered=false
	jets[0].position=main.position-Vector2(20,0);Soviet.fly_mig(jets[0],.01)
	var codec=BattleSaves.Snapshot.new();var snapshot:Dictionary=codec.capture(battle)
	check(codec.error.is_empty(),"mixed inbound/outbound two-target wing captures")
	var path:=output_dir.path_join("two-target-wing.bin")
	var file:=FileAccess.open(path,FileAccess.WRITE);file.store_var(snapshot,false);file.close()
	snapshot=FileAccess.open(path,FileAccess.READ).get_var(false);codec.restore(battle,snapshot)
	for unit in battle.units:
		if unit.special.get("academy_hero")=="BORIS":hero=unit
	jets=hero.special.airstrike_wing
	check(codec.error.is_empty() and jets.size()==6,"binary restore retains one six-aircraft occupancy group")
	for jet in jets:
		var run:Dictionary=jet.special.strike_run
		check(run.boris_independent and is_same(run.spotter,hero) and run.wing.size()==6 and run.boris_receipt.count==3,"restored aircraft keeps ownership group guidance and calibration")
	check(jets[0].special.strike_run.ammo==0 and jets[-1].special.strike_run.ammo==1,"restore never rearms an already fired member")
	var other=building(Vector2(1100,1200));Soviet.designate(hero,other)
	check(not other.special.has("airstrike_mark"),"restore cannot replace occupied wing with another call")
	for jet in jets:
		if jet.special.strike_run.ammo==0:continue
		jet.position=jet.special.strike_run.target.position-Vector2(20,0);Soviet.fly_mig(jet,.01)
	check(Q.progress(battle,"BORIS").get("sorties",0)==1,"restored secondary bombing does not duplicate sortie task")
	await finish()

func death_cases() -> void:
	var hero=setup_boris();hero.special.hero_command_rank=5
	var main=building(Vector2(1250,1000));var other=building(Vector2(1350,1000));var jets:=dispatch(hero,main)
	battle.buildings.erase(other);other.free()
	Soviet.fly_mig(jets[-1],.01)
	check(jets[-1].special.strike_run.outbound and jets[-1].special.strike_run.ammo==1,"freed secondary safely aborts when no replacement exists")
	battle.units.erase(hero);hero.free()
	for jet in jets:Soviet.fly_mig(jet,.01)
	check(jets.all(func(jet):return jet.special.strike_run.outbound and jet.special.strike_run.ammo==1),"freed spotter aborts surviving wing without issuing bombs or new wave")
	await finish()

func interception_and_limits() -> void:
	var hero=setup_boris();hero.special.hero_command_rank=5
	var main=building(Vector2(1250,1000));var other=building(Vector2(1350,1000));var jets:=dispatch(hero,main)
	var gunner=battle.spawn_unit("FLAKT","enemy",Vector2(800,1000))
	jets[-1].position=gunner.position+Vector2(70,0)
	gunner.attack_target=jets[-1];gunner.attack_ordered=true;gunner.hull_angle=0;gunner._cd_timer=0
	var before:float=jets[-1].hp
	check(gunner._try_fire_ready(),"normal native antiair can target an extra secondary MiG")
	for shot in battle.projectiles_root.get_children():
		if shot is Projectile and shot.target==jets[-1]:shot._explode()
	check(jets[-1].hp<before,"actual antiair projectile damages extra aircraft normally")
	jets[-1].receive_hit(100000,"missile",{},gunner)
	check(not AlliedAbilities.alive(jets[-1]),"extra aircraft can be shot down")
	var cd:float=hero.special.airstrike_cd;Soviet.advance_sortie_reload(hero,100)
	check(hero.special.has("airstrike_wing") and hero.special.airstrike_cd==cd,"intercepting one aircraft never prematurely frees the remaining wing")
	main.hp=0
	Soviet.fly_mig(jets[0],.01)
	jets[4].position=other.position-Vector2(20,0);Soviet.fly_mig(jets[4],.01)
	check(jets[0].special.strike_run.ammo==1 and jets[4].special.strike_run.ammo==0,"destroyed primary aborts primary planes without canceling valid secondary bombing")
	await finish()
	hero=setup_boris();hero.special.hero_command_rank=5
	main=building(Vector2(1250,1000));building(Vector2(1416,1000))
	check(Sortie.targets(hero,main,4).size()==4,"outside three-cell center radius is not a secondary candidate")
	building(Vector2(1415,1000))
	check(Sortie.targets(hero,main,4).size()==6,"exact three-cell boundary accepts the secondary")
	var ordinary=battle.spawn_unit("BORIS","ally",hero.position+Vector2(0,80));ordinary.special.hero_command_rank=5
	check(Sortie.targets(ordinary,main,4).size()==4,"ordinary Boris never gains hero upgrades from rank metadata alone")
	BattleRequest.rules_mode=MatchRules.RA2
	check(Sortie.targets(hero,main,4).size()==4 and not Sortie.independent(hero),"classic rules exclude hero sortie talents")
	await finish()
