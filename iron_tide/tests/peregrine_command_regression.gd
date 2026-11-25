extends "res://tests/peregrine_contract_regression.gd"
const Cmd=preload("res://scripts/units/peregrine_command.gd")

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
	await get_tree().process_frame
	await magazines()
	await anti_air()
	await anti_air_cycle_qualifications()
	await global_speed()
	await scanning()
	await submunitions()
	await purchases()
	await split_boundaries()
	await split_damage_cap()
	await expedition_command()
	await aircraft_movement()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	print("PEREGRINE_COMMAND_RESULT ",checks.size()," checks, ",failed," failed")
	get_tree().quit(0 if failed==0 else 1)

func command_hero(rank:int):
	MetaProgress.reset_save();MetaProgress.academy.hero_escort_ranks={"ORCA":rank}
	Pool.grant(MetaProgress,"peregrine_contract")
	MetaProgress.unlocked_skills.assign([PC.ACTIVE,PC.PASSIVE])
	Loadouts.equip(MetaProgress,"ORCA","active",PC.ACTIVE)
	Loadouts.equip(MetaProgress,"ORCA","passive",PC.PASSIVE)
	boot("TANY")
	var hero=battle.spawn_unit("ORCA","ally",Vector2(1000,1000));P.promote(MetaProgress,battle,hero)
	return hero

func magazines() -> void:
	for rank in 6:
		var hero=command_hero(rank)
		var capacity:=4 if rank==0 else 5
		check(Cmd.rank(hero)==rank and hero.logistics.ammo==capacity and hero.logistics.ammo_max==capacity,"real promotion uses frozen rank and actual capacity "+str(rank))
		var target=victim("HTNK",hero.position+Vector2(150,0))
		normal_shot(hero,target)
		check(hero.logistics.ammo==capacity-1,"normal missile spends one of actual expanded magazine")
		P.tick(hero,(8-rank)-.01)
		check(hero.logistics.ammo==capacity-1,"rank reload waits full interval "+str(rank))
		P.tick(hero,.010001)
		check(hero.logistics.ammo==capacity and hero.special[P.KEY].cycle==1,"rank reload completes without airport "+str(rank))
		var codec=BattleSaves.Snapshot.new();var snap:Dictionary=codec.capture(battle);codec.restore(battle,snap);hero=get_hero()
		check(codec.error.is_empty() and hero.logistics.ammo==capacity and Cmd.rank(hero)==rank and hero.is_in_group(Cmd.GROUP),"saved expanded magazine and group membership restore "+str(rank))
		await finish()

func anti_air() -> void:
	var hero=command_hero(2);var air=victim("ORCA",hero.position+Vector2(150,0));air.logistics.air_lift=1
	air.bonuses.defense_bonus=1;air.bonuses.veteran_defense=1
	hero.logistics.ammo=0
	battle.select_unit(hero,false);battle.force_attack(air)
	check(hero.attack_domain_valid(air) and hero.attack_ordered and hero.attack_target==air,"real selected-unit attack command accepts visible air target")
	hero._refresh_weapon_derived();hero.hull_angle=0;hero.turret_angle=0;hero._cd_timer=0
	var weapon:Dictionary=hero._active_weapon();var expected:=Ra2Damage.quantize(CombatMath.full_damage(weapon,air.armor,hero.bonuses,null,air.ra2_armor,0,air))
	var hp:float=air.hp
	check(weapon.get("peregrine_aa",false) and weapon.range==165 and weapon.damage==hero._weapon_for_target(null).damage*.2,"AA uses ground primary attack percentage and own range")
	check(hero._try_fire_ready() and is_equal_approx(hp-air.hp,expected) and hero._cd_timer==1,"real AA gun hits with exactly one-second interval",[hp-air.hp,expected,hero._cd_timer])
	check(hero.logistics.ammo==0 and not hero.special[P.KEY].get("normal_hit",false) and not hero.special[P.KEY].hits,"AA fires empty without consuming or satisfying ground cycle")
	check(not hero._try_fire_ready(),"second AA shot waits actual shared cooldown")
	hero._cd_timer=0;air.position=hero.position+Vector2(166,0)
	check(not hero._try_fire_ready(),"AA cannot use longer ground-weapon range")
	air.position=hero.position+Vector2(165,0)
	check(hero._try_fire_ready(),"AA includes exact three-cell boundary")
	hero._cd_timer=0;air.special.echo_cloaked=true;hero.attack_ordered=false
	check(not hero._try_fire_ready(),"AA cannot acquire concealed air targets")
	air.special.erase("echo_cloaked");hero.attack_ordered=true
	var ground=victim("HTNK",hero.position+Vector2(190,0))
	check(PC.target_in_range(hero,ground),"W retains normal ground primary range while AA weapon is selected")
	hero.attack_target=ground;hero._refresh_weapon_derived();hero._cd_timer=0
	check(not hero._try_fire_ready(),"switching back to ground still requires ground ammunition")
	P.tick(hero,6);normal_shot(hero,ground)
	check(hero.logistics.ammo==0 and hero.special[P.KEY].normal_hit,"ground switch consumes reloaded round and records ordinary hit")
	hero.special.hero_command_rank=1;hero.attack_target=air
	check(not Cmd.anti_air(hero,air) and not hero._weapon_target_valid(air),"rank one cannot use anti-air")
	await finish()

func anti_air_cycle_qualifications() -> void:
	const Aircraft=preload("res://scripts/units/expansion_2_aircraft.gd")
	for remaining in [5,1,0]:
		var hero=command_hero(5);var target=victim("HTNK",hero.position+Vector2(150,0))
		hero.passive=GameData.get_skill(Aircraft.LAST).duplicate(true);Aircraft.new_cycle(hero)
		for i in 5-remaining:normal_shot(hero,target)
		var first:bool=hero.special[Aircraft.KEY].air_first;var last:bool=hero.special[Aircraft.KEY].air_last
		var bombs:int=battle.allied_state.get(Cmd.BOMBS,[]).size()
		var air=victim("ORCA",hero.position+Vector2(150,0));air.logistics.air_lift=1
		hero.attack_target=air;hero.attack_ordered=true;hero._refresh_weapon_derived();hero._cd_timer=0;hero.hull_angle=0;hero.turret_angle=0
		check(hero._try_fire_ready() and hero.logistics.ammo==remaining,"real AA preserves ground magazine at "+str(remaining))
		check(hero.special[Aircraft.KEY].air_first==first and hero.special[Aircraft.KEY].air_last==last and battle.allied_state.get(Cmd.BOMBS,[]).size()==bombs,"real AA neither consumes first/last qualification nor creates submunitions at "+str(remaining))
		await finish()

func purchases() -> void:
	MetaProgress.reset_save();MetaProgress.academy.hero_builds={"ORCA":5}
	var page=load("res://scripts/ui/hero_progression.gd").new();add_child(page);page.selected="ORCA"
	for rank in 5:
		var price:int=[40,120,240,400,600][rank]
		MetaProgress.currency.cores=price-1;page.refresh()
		check(A.hero_talent_cost("escort",rank,"ORCA")==price and page.escort.disabled and page.escort.text.contains(str(price)),"command upgrade price and insufficient UI "+str(rank))
		check(not A.purchase(MetaProgress,"escort","ORCA") and MetaProgress.balance("cores")==price-1,"insufficient purchase has no debit")
		MetaProgress.currency.cores=price;page.refresh()
		check(not page.escort.disabled and A.purchase(MetaProgress,"escort","ORCA"),"real five-level command purchase succeeds "+str(rank))
		MetaProgress.load_save()
		check(MetaProgress.academy.hero_escort_ranks.ORCA==rank+1 and MetaProgress.balance("cores")==0,"purchase and exact debit survive disk "+str(rank))
	page.refresh()
	check(page.escort.disabled and page.escort.text=="已满级" and page.escort_detail.text.contains("末弹分束") and page.escort_detail.text.contains("3 秒/发"),"max-rank UI includes all functional nodes and new reload time")
	check(page.survival.disabled and A.hero_talent_cost("survival",0,"ORCA")==40 and A.hero_talent_cost("survival",5,"ORCA")==0,"survival requires cores and stops at rank five")
	page.talent_demo.talent.select(0);page.talent_demo._select_talent()
	check(page.talent_demo.levels.item_count==6,"all six command levels previewable")
	for rank in 6:
		page.talent_demo.levels.select(rank);page.talent_demo.refresh_caption()
		check(page.talent_demo.caption.text.contains(Cmd.COMMAND[rank]),"correct unique level description "+str(rank))
	page.free()
	boot("TANY")
	var hero=battle.spawn_unit("ORCA","ally",Vector2(1000,1000));P.promote(MetaProgress,battle,hero)
	check(Cmd.rank(hero)==5 and hero.logistics.ammo==5,"next match consumes actual purchased rank")
	MetaProgress.academy.hero_escort_ranks.ORCA=0
	check(Cmd.rank(hero)==5,"mid-match profile changes do not mutate frozen rank")
	await finish()
	MetaProgress.academy.hero_escort_ranks.ORCA=4;MetaProgress.currency.cores=600;MetaProgress.save()
	var previous:=FileAccess.get_file_as_bytes(MetaProgress.SAVE_PATH)
	DirAccess.make_dir_absolute(MetaProgress.SAVE_PATH+".tmp")
	check(not A.purchase(MetaProgress,"escort","ORCA") and MetaProgress.academy.hero_escort_ranks.ORCA==4 and MetaProgress.balance("cores")==600,"failed profile replacement rolls back rank and currency")
	check(FileAccess.get_file_as_bytes(MetaProgress.SAVE_PATH)==previous,"failed purchase preserves profile bytes")
	DirAccess.remove_absolute(MetaProgress.SAVE_PATH+".tmp")
	check(A.purchase(MetaProgress,"escort","ORCA"),"retry purchase succeeds once")

func split_boundaries() -> void:
	const Aircraft=preload("res://scripts/units/expansion_2_aircraft.gd")
	var hero=command_hero(5);var target=victim("HTNK",hero.position+Vector2(150,0))
	hero.passive=GameData.get_skill(Aircraft.LAST).duplicate(true)
	BattleRequest.combat_context.get_or_add("card_ranks",{})[Aircraft.LAST]=3
	for i in 4:normal_shot(hero,target)
	hero.attack_target=target;hero._cd_timer=0;hero._burst_left=0
	check(hero._try_fire_ready(),"real final round starts before in-flight save")
	var missile=battle.projectiles_root.get_children().filter(func(p):return p is Projectile and not p._detonated)[0]
	check(missile.attacker_bonus.has("peregrine_split") and missile.attacker_bonus.peregrine_split.bonus.attack_bonus==hero.bonuses.attack_bonus and missile.attacker_bonus.attack_bonus>hero.bonuses.attack_bonus,"split snapshot excludes ordinary last-shot bonus while parent receives it")
	var codec=BattleSaves.Snapshot.new();var snap:Dictionary=codec.capture(battle);codec.restore(battle,snap)
	hero=get_hero();missile=battle.projectiles_root.get_children().filter(func(p):return p is Projectile and not p._detonated)[0]
	hero._die();battle.units.erase(hero);hero.free();missile._explode()
	check(codec.error.is_empty() and battle.allied_state.get(Cmd.BOMBS,[]).size()==2,"saved last projectile still splits after owner is destroyed")
	Cmd.finish(missile)
	check(battle.allied_state[Cmd.BOMBS].size()==2,"repeated impact-finish notification cannot duplicate children")
	battle.allied_state.get_or_add("defeated_houses",{}).ally=true;Cmd.world_tick(battle,1)
	check(not battle.allied_state.has(Cmd.BOMBS),"faction elimination cancels pending children")
	await finish()

func global_speed() -> void:
	var hero=command_hero(4)
	var orca=battle.spawn_unit("ORCA","ally",Vector2(3000,3000))
	var eagle=battle.spawn_unit("BEAG","ally",Vector2(3200,3000))
	var ordinary=battle.spawn_unit("SCHP","ally",Vector2(3400,3000))
	var hostile=battle.spawn_unit("ORCA","enemy",Vector2(3600,3000))
	for unit in [hero,orca,eagle]:
		unit._recompute_bonuses()
		check(is_equal_approx(Cmd.speed_bonus(unit),.15) and is_equal_approx(unit.move_speed,unit._base_speed*1.15),"global same-owner aircraft speed applies far from hero "+unit.unit_id,[unit.move_speed,unit._base_speed])
	check(Cmd.speed_bonus(ordinary)==0 and Cmd.speed_bonus(hostile)==0,"non-plane and enemy exclusions")
	var extra=battle.spawn_unit("ORCA","ally",Vector2(1700,1000));extra.special=hero.special.duplicate(true);Cmd.install(extra)
	check(Cmd.speed_bonus(orca)==.15,"multiple same-name leader sources never stack")
	extra._die()
	orca.side="ally2";BattleRequest.house_teams.ally2=BattleRequest.house_teams.get("ally",0)
	check(Cmd.speed_bonus(orca)==0,"allied other-owner aircraft are excluded")
	orca.side="ally"
	orca.special.expansion_temporary={"kind":"test"}
	check(Cmd.speed_bonus(orca)==0,"temporary copy gets no global speed")
	orca.special.erase("expansion_temporary")
	hero.logistics.spend_ammo(hero.logistics.ammo,false)
	check(is_equal_approx(hero.move_speed,hero._base_speed*1.35),"leader plus empty speed stack additively",[hero.move_speed,hero._base_speed])
	hero.special.hero_wreck={};orca._recompute_bonuses()
	check(Cmd.speed_bonus(orca)==0,"wreck immediately stops providing global speed")
	hero.special.erase("hero_wreck");hero._die();orca._recompute_bonuses()
	check(Cmd.speed_bonus(orca)==0,"actual death stops global speed")
	await finish()

func scanning() -> void:
	var hero=command_hero(3);var hidden=victim("SPY",hero.position+Vector2(100,0));hidden.special.disguise="E1"
	check(Cmd.detects(battle,"ally",hidden) and not AlliedAbilities.concealed(hidden,"ally"),"real shared concealment query sees nearby disguised ground target")
	hidden.position=hero.position+Vector2(111,0)
	check(not Cmd.detects(battle,"ally",hidden) and AlliedAbilities.concealed(hidden,"ally"),"two-cell scan has exact range boundary")
	hidden.position=hero.position+Vector2(100,0);hidden.special.erase("disguise");hidden.special.echo_cloaked=true
	check(not AlliedAbilities.concealed(hidden,"ally"),"scan also reveals actual cloak")
	hero.logistics.air_lift=0
	check(not Cmd.detects(battle,"ally",hidden),"grounded maintenance stance cannot scan")
	hero.logistics.air_lift=1;hero._stun_timer=1
	check(not Cmd.detects(battle,"ally",hidden),"controlled scout cannot scan")
	hero._stun_timer=0
	var sub=victim("SUB",hero.position+Vector2(50,0));var air=victim("ORCA",hero.position+Vector2(50,0));air.logistics.air_lift=1
	check(not Cmd.detects(battle,"ally",sub) and not Cmd.detects(battle,"ally",air),"scan is neither sonar nor airborne detection")
	var wall:=StaticBody2D.new();wall.process_mode=Node.PROCESS_MODE_ALWAYS;wall.collision_layer=1;wall.collision_mask=0
	var collision:=CollisionShape2D.new();var shape:=RectangleShape2D.new();shape.size=Vector2(12,50);collision.shape=shape;wall.add_child(collision);battle.add_child(wall);wall.position=hero.position+Vector2(50,0)
	await get_tree().physics_frame;await get_tree().physics_frame
	check(not Cmd.detects(battle,"ally",hidden) and AlliedAbilities.concealed(hidden,"ally"),"physical terrain blocker prevents scan through cover")
	wall.free();await finish()

func submunitions() -> void:
	var hero=command_hero(5);var target=victim("HTNK",hero.position+Vector2(150,0))
	var left=victim("E2",target.position+Vector2(0,44));var right=victim("E2",target.position-Vector2(0,44))
	for i in 4:normal_shot(hero,target)
	check(not battle.allied_state.has(Cmd.BOMBS),"first four ordinary rounds cannot split")
	normal_shot(hero,target)
	check(hero.logistics.ammo==0 and battle.allied_state.get(Cmd.BOMBS,[]).size()==2,"actual final fifth missile creates exactly two submunitions",[hero.special[P.KEY],battle.projectiles_root.get_children().filter(func(p):return p is Projectile).map(func(p):return {"split":p.attacker_bonus.get("peregrine_split",{}),"markers":p.splinters})])
	if not battle.allied_state.has(Cmd.BOMBS):await finish();return
	var bombs:Array=battle.allied_state[Cmd.BOMBS]
	check(bombs.all(func(b):return is_equal_approx(b.point.distance_to(target.position),44) and is_equal_approx(b.left,.5)),"submunitions use fixed two-side offset and half-second warning")
	var damage:float=bombs[0].damage;var main_hp:float=target.hp;var hp:float=left.hp;var other_hp:float=right.hp
	Cmd.world_tick(battle,.49)
	check(left.hp==hp and right.hp==other_hp,"warning deals no early damage")
	var codec=BattleSaves.Snapshot.new();var snap:Dictionary=codec.capture(battle)
	var file=FileAccess.open(output_dir.path_join("split.bin"),FileAccess.WRITE);file.store_var(snap,false);file.close()
	file=FileAccess.open(output_dir.path_join("split.bin"),FileAccess.READ);snap=file.get_var(false);file.close();codec.restore(battle,snap)
	hero=get_hero();target=battle.units.filter(func(u):return u.unit_id=="HTNK")[0]
	left=battle.units.filter(func(u):return u.unit_id=="E2" and u.position.y>1000)[0];right=battle.units.filter(func(u):return u.unit_id=="E2" and u.position.y<1000)[0]
	Cmd.world_tick(battle,.010001)
	check(codec.error.is_empty() and is_equal_approx(hp-left.hp,Ra2Damage.quantize(damage)) and is_equal_approx(other_hp-right.hp,Ra2Damage.quantize(damage)),"binary warning resumes once and each side receives exact 35 percent snapshot")
	check(target.hp==main_hp and not battle.allied_state.has(Cmd.BOMBS),"split radius excludes central point and does not recurse")
	P.tick(hero,3);normal_shot(hero,target)
	check(not battle.allied_state.has(Cmd.BOMBS),"partial refill cannot renew split qualification")
	P.tick(hero,15)
	for i in 3:normal_shot(hero,target)
	check(hero.logistics.ammo==2 and PC.cast(hero,ability(hero),target.position),"W legally consumes remaining two rounds after three real shots")
	PC.world_tick(battle,3)
	check(not hero.special[P.KEY].last_ready and not battle.allied_state.has(Cmd.BOMBS),"W consumes final qualification but produces no split")
	P.tick(hero,3);normal_shot(hero,target)
	check(not hero.special[P.KEY].last_ready and not battle.allied_state.has(Cmd.BOMBS),"one round reloaded after W cannot renew submunition qualification")
	await finish()

func split_damage_cap() -> void:
	var hero=command_hero(5)
	BattleRequest.combat_context.final_damage_cap=2.25;BattleRequest.combat_context.final_damage_threshold=2.0
	hero._base_atk=10;hero._recompute_bonuses()
	var target=victim("HTNK",hero.position+Vector2(150,0));var flank=victim("E2",target.position+Vector2(0,44));flank.bonuses.defense_bonus=2
	for i in 5:normal_shot(hero,target)
	var event:Dictionary=battle.allied_state[Cmd.BOMBS][0]
	var hp:float=flank.hp
	var reference:float=event.raw*float(event.bonus.get("veteran_attack",1))
	var curve:=2.0+.25*log(33.0)/(1.0+log(33.0))
	Cmd.world_tick(battle,.5)
	check(is_equal_approx(hp-flank.hp,Ra2Damage.quantize(reference*curve/2)),"submunition offense, armor, defense and final cap apply once",[hp-flank.hp,reference])
	await finish()

func expedition_command() -> void:
	MetaProgress.reset_save();MetaProgress.academy.hero_escort_ranks={"ORCA":5}
	check(Expedition.start("美国","",903) and Expedition.choose(0),"start expedition with trained commander")
	var prepared:Dictionary=Expedition.state.duplicate(true);prepared.stage=5
	check(preload("res://scripts/expedition/heroes.gd").recruit(prepared,"ORCA") and Expedition.commit(prepared) and Expedition.launch(0),"actual expedition recruits trained Peregrine")
	screen=load("res://scenes/battle.tscn").instantiate();add_child(screen);screen.process_mode=Node.PROCESS_MODE_DISABLED;battle=screen.battle
	var hero=get_hero()
	check(hero!=null and Cmd.rank(hero)==5 and hero.logistics.ammo_max==5 and hero.logistics.ammo==5,"expedition deploys actual high-rank magazine and command abilities")
	if hero==null:await finish();return
	hero.logistics.spend_ammo(2,false);P.tick(hero,1.5)
	check(Expedition.checkpoint(battle),"trained commander checkpoint writes")
	await finish()

	check(Expedition.load_run() and Expedition.prepare_battle(),"trained commander checkpoint loads")
	screen=load("res://scenes/battle.tscn").instantiate();add_child(screen);screen.process_mode=Node.PROCESS_MODE_DISABLED;battle=screen.battle;hero=get_hero()
	check(hero!=null and Cmd.rank(hero)==5 and hero.logistics.ammo==3 and hero.logistics.ammo_max==5 and is_equal_approx(hero.special[P.KEY].progress,.5) and Cmd.speed_bonus(hero)==.15,"expedition preserves rank, partial reload and re-registers global command")
	await finish()

func aircraft_movement() -> void:
	for mode in [MatchRules.RA2,MatchRules.EXTENDED]:
		for id in ["ORCA","BEAG"]:
			MetaProgress.reset_save();MetaProgress.academy.hero_escort_ranks={"ORCA":4};boot("TANY",mode)
			var leader=battle.spawn_unit("ORCA","ally",Vector2(800,800));P.promote(MetaProgress,battle,leader)
			var plane=battle.spawn_unit(id,"ally",Vector2(2100,1800))
			plane.process_mode=Node.PROCESS_MODE_ALWAYS;plane.set_process(false);plane.set_physics_process(false)
			plane.fire_stance="none";plane._think_timer=10000;plane.hull_angle=0;plane.logistics.air_lift=1
			await get_tree().physics_frame
			var destination:=Vector2.INF
			for offset in 12:
				var candidate:=Vector2(1450,1950)-Vector2(0,offset*55)
				if plane.flight.can_land_at(candidate):destination=candidate;break
			check(destination.is_finite(),"real terrain provides a legal reverse-flight landing point "+mode+id,destination)
			if not destination.is_finite():await finish();continue
			plane.order_move(destination)
			var dt:=1.0/Engine.physics_ticks_per_second
			for i in int(40/dt):
				plane._physics_process(dt)
				if not plane.has_move_order:break
			check(not plane.has_move_order and plane.position.distance_to(destination)<=8,"real physics step reverses and reaches destination "+mode+id,plane.position)
			check(is_equal_approx(Cmd.speed_bonus(plane),.15 if mode==MatchRules.EXTENDED else 0.0),"flight receives only extended same-owner leadership "+mode+id)
			for i in int(7/dt):plane._physics_process(dt)
			check(plane.logistics.air_lift<.01,"ordinary landable aircraft still lands at destination "+mode+id,{"lift":plane.logistics.air_lift,"can_land":plane.flight.can_land(),"blocked":battle.path_service.is_blocked(plane.position),"water":battle.in_water_world(plane.position),"state":plane.logistics.air_state,"pos":plane.position,"map":battle.map_size,"order":plane.has_move_order,"target":str(plane.attack_target)})
			await finish()
