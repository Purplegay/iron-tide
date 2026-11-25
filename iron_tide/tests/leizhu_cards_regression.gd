extends "res://tests/leizhu_base_regression.gd"
const LC=preload("res://scripts/units/leizhu_cards.gd")
const Q=preload("res://scripts/rules/expansion_contracts.gd")
const Pool=preload("res://scripts/rules/hero_contract_pool.gd")

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
	await get_tree().process_frame
	for rank in 4:
		await court(rank)
		await charge(rank)
	await changing_geometry()
	await resume_cards()
	await boundaries()
	await contract()
	await slow_overlap()
	await quest_exclusions()
	await building_and_terrain()
	await purchases()
	await independent_fields_and_fog()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	print("LEIZHU_CARDS_RESULT ",checks.size()," checks, ",failed," failed")
	get_tree().quit(0 if failed==0 else 1)

func cards_hero(rank:=0,equip:=true):
	MetaProgress.reset_save();Pool.grant(MetaProgress,"leizhu_contract")
	if equip:
		MetaProgress.unlocked_skills.assign([LC.ACTIVE,LC.PASSIVE]);MetaProgress.academy.levels={LC.ACTIVE:rank,LC.PASSIVE:rank}
		Loadouts.equip(MetaProgress,"TTNK","active",LC.ACTIVE);Loadouts.equip(MetaProgress,"TTNK","passive",LC.PASSIVE)
	boot("BORIS")
	var hero=battle.spawn_unit("TTNK","ally",Vector2(1000,1000));L.promote(MetaProgress,battle,hero)
	return hero

func ability(hero):return hero.ability_at(UnitSkillLayout.find(hero,LC.ACTIVE))

func expected(hero,victim,factor:float) -> float:
	var weapon:Dictionary=hero._weapon_for_target(null).duplicate(true);weapon.damage*=factor
	return Ra2Damage.quantize(CombatMath.full_damage(weapon,victim.armor,hero.bonuses,null,victim.ra2_armor,0,victim)/float(victim.bonuses.get("defense_bonus",1)))

func court(rank:int) -> void:
	var hero=cards_hero(rank);hero.passive={}
	var center:Vector2=hero.position+Vector2(120,0);var victim=target("HTNK","enemy",center)
	var outside=target("HTNK","enemy",center+Vector2(100,0))
	var damage:=expected(hero,victim,[.2,.25,.3,.35][rank])
	check(is_equal_approx(float(GameData.get_skill(LC.ACTIVE).values.damage[rank]),[.4,.5,.6,.7][rank]),"W damage coefficient doubled at rank "+str(rank))
	check(A.skill_description(GameData.get_skill(LC.ACTIVE),rank).contains("每秒受到施放时攻击力%d%%"%[40,50,60,70][rank]),"W description reports the actual per-second damage at rank "+str(rank))
	check(hero.use_ability(UnitSkillLayout.find(hero,LC.ACTIVE),center),"native W succeeds without passive rank "+str(rank))
	var field:Dictionary=battle.allied_state[LC.FIELDS][0]
	check(field.nodes.size()==3 and ability(hero).cd_left==[48.,44.,40.,36.][rank],"three electrodes and tier cooldown")
	for node in field.nodes:
		check(is_equal_approx(node.hp,hero.max_hp*[.08,.1,.12,.15][rank]) and node.sight==0 and node.collision_layer==0 and node.weapon.is_empty(),"electrode HP scales, no vision/blocking/weapon")
	check(victim.hp==100000 and victim.move_speed<victim._base_speed,"entry immediately slows but does not deal free first tick")
	LC.world_tick(battle,.49);check(victim.hp==100000,"first tick requires continuous half second")
	LC.world_tick(battle,.01);check(is_equal_approx(100000-victim.hp,damage),"single half-share tick with actual electric armor",[100000-victim.hp,damage])
	hero._base_atk*=10;hero._recompute_bonuses()
	LC.world_tick(battle,[8.,10.,12.,14.][rank]-.5)
	check(is_equal_approx(100000-victim.hp,damage*[16,20,24,28][rank]),"full lifetime uses cast snapshot and exact tick count",[100000-victim.hp,damage])
	check(outside.hp==100000 and not battle.allied_state.has(LC.FIELDS),"outside unaffected and full-duration field retired")
	check(hero.special[L.KEY].get("charge_count",0)==0,"field DOT cannot charge passive")
	for id in [LC.ACTIVE,LC.PASSIVE]:check(not A.skill_description(GameData.get_skill(id),rank).contains("{"),"tier description resolves "+id)
	await finish()

func charge(rank:int) -> void:
	var hero=cards_hero(rank);var victim=target("HTNK","enemy",hero.position+Vector2(220,0))
	var splash=target("E2","enemy",hero.position+Vector2(-60,0))
	var radius:float=[2.,2.25,2.5,3.][rank]*55
	var edge=target("E2","enemy",hero.position+Vector2(0,radius))
	var outside=target("E2","enemy",hero.position+Vector2(0,radius+1))
	var damage:=expected(hero,splash,[.3,.4,.5,.6][rank])
	fire(hero,victim);fire(hero,victim)
	check(hero.special[L.KEY].charge_count==1,"same-second native shots earn only one charge")
	L.tick(hero,1);fire(hero,victim);check(hero.special[L.KEY].charge_count==2,"one-second boundary permits second charge")
	L.tick(hero,1);fire(hero,victim)
	check(hero.special[L.KEY].charge_count==0 and not hero.special[L.KEY].has("pending_arc"),"third main hit consumes charge after main settlement")
	check(is_equal_approx(100000-splash.hp,damage) and edge.hp<100000 and outside.hp==100000,"self-centered AOE hits nearby opposite-side target and exact radius",[100000-splash.hp,damage])
	check(is_equal_approx(hero.special[L.KEY].arc_flash.radius,radius),"passive works without a W field")
	L.tick(hero,1);fire(hero,victim);L.tick(hero,8)
	check(hero.special[L.KEY].charge_count==0,"all charge expires after eight seconds without new layer")
	hero.position+=Vector2(0,-60);victim.position=hero.position+Vector2(220,0)
	for i in 3:L.tick(hero,1);fire(hero,victim)
	check(hero.special[L.KEY].charge_count==0 and hero.special[L.KEY].has("arc_flash"),"discharge still consumes charges with distant primary")
	await finish()

func changing_geometry() -> void:
	var hero=cards_hero();var center:Vector2=hero.position+Vector2(120,0);var victim=target("HTNK","enemy",center)
	check(LC.cast(hero,ability(hero),center),"court may surround owner")
	var field:Dictionary=battle.allied_state[LC.FIELDS][0]
	var link:Vector2=(field.nodes[1].position+field.nodes[2].position)*.5
	var edge=target("E2","enemy",link)
	field.nodes[0].receive_hit(100000,"electric",{},edge)
	LC.world_tick(battle,.5)
	check(victim.hp==100000 and edge.hp<100000 and LC.vertices(field).size()==2,"destroyed electrode removes triangle interior, keeps remaining wire")
	var before:float=edge.hp;edge.position+=Vector2(0,25);LC.world_tick(battle,.49);edge.position=link;LC.world_tick(battle,.01)
	check(edge.hp==before,"leaving and reentering cannot manufacture first tick")
	LC.world_tick(battle,.49);check(edge.hp<before,"reentered target damages only after new continuous half second")
	field.nodes[1].receive_hit(100000,"electric",{},edge);before=edge.hp;LC.world_tick(battle,1)
	check(edge.hp==before and LC.vertices(field).size()==1,"one remaining electrode has no damage region")
	check(not LC.contains(LC.vertices(field),hero.position),"one electrode cannot extend passive radius")
	hero.position=center+Vector2(386,0);LC.world_tick(battle,.1)
	check(not battle.allied_state.has(LC.FIELDS),"owner beyond seven cells dissolves court")
	await finish()

func resume_cards() -> void:
	var hero=cards_hero();var center:Vector2=hero.position+Vector2(120,0);var victim=target("HTNK","enemy",center+Vector2(10,0))
	LC.cast(hero,ability(hero),center);hero.position=center;LC.world_tick(battle,.3)
	fire(hero,victim);L.tick(hero,1);fire(hero,victim)
	var codec=BattleSaves.Snapshot.new();var snapshot:Dictionary=codec.capture(battle)
	var file=FileAccess.open(output_dir.path_join("court.bin"),FileAccess.WRITE);file.store_var(snapshot,false);file.close()
	file=FileAccess.open(output_dir.path_join("court.bin"),FileAccess.READ);snapshot=file.get_var(false);file.close()
	codec.restore(battle,snapshot)
	check(codec.error.is_empty(),"actual snapshot restores electrode nodes and Node-key exposures",codec.error)
	hero=get_hero();victim=battle.units.filter(func(u):return u.side=="enemy" and u.unit_id=="HTNK")[0]
	var field:Dictionary=battle.allied_state[LC.FIELDS][0];var before:float=victim.hp
	check(field.owner==hero and field.exposure.has(victim) and LC.vertices(field).size()==3 and hero.special[L.KEY].charge_count==2,"snapshot resolves owner, all electrode identities, target timer and charge")
	LC.world_tick(battle,.2);check(victim.hp<before,"restore preserves partial exposure, no full-delay restart")
	L.tick(hero,1);fire(hero,victim)
	check(hero.special[L.KEY].charge_count==0 and is_equal_approx(hero.special[L.KEY].arc_flash.radius,2.5*55),"restored third charge extends radius only inside own live court")
	victim.free();LC.world_tick(battle,.2)
	check(field.exposure.is_empty(),"freed Node dictionary key safely discarded")
	hero._die();LC.world_tick(battle,.1);check(not battle.allied_state.has(LC.FIELDS),"hero death dissolves all remaining electrodes")
	await finish()

func quest_exclusions() -> void:
	var hero=cards_hero();var p:Dictionary=Q.progress(battle,"TTNK")
	var victim=target();victim.hp=1
	LC.damage(hero,victim,hero._weapon_for_target(null),{"expansion_extra":true,"leizhu_field":true})
	check(p.first==0,"electric field extra kill is not a direct contract vehicle kill")
	victim=target();victim.hp=1;victim.special.expansion_temporary={"kind":"reserve","left":10}
	fire(hero,victim);check(p.first==0,"temporary vehicle excluded from primary-kill task")
	var attacker=target();hero.max_hp=10000;hero.hp=10000
	var friendly=target("HTNK","ally",hero.position+Vector2(0,150))
	hero.receive_hit(100,"electric",{},friendly);check(p.second==0,"friendly HP damage excluded")
	attacker.special.expansion_temporary={"kind":"reserve","left":10}
	hero.receive_hit(100,"electric",{},attacker);check(p.second==0,"temporary attacker excluded")
	attacker.special.erase("expansion_temporary");hero.hp=3;hero.receive_hit(10000,"electric",{},attacker)
	check(p.second==3,"lethal overkill counts only remaining HP")
	p.first=25;p.second=6000;Q.settle(MetaProgress,battle,true)
	check(not MetaProgress.academy.hero_contracts.TTNK.complete and not MetaProgress.academy.hero_contracts.TTNK.win,"dead hero cannot satisfy surviving victory")
	await finish()
	hero=cards_hero();p=Q.progress(battle,"TTNK");p.first=25;p.second=6000
	Q.settle(MetaProgress,battle,false)
	check(MetaProgress.academy.hero_contracts.TTNK.first==25 and not MetaProgress.academy.hero_contracts.TTNK.win,"loss accumulates tasks but does not grant victory requirement")
	await finish()
	hero=cards_hero();p=Q.progress(battle,"TTNK");p.first=25;p.second=6000
	BattleRequest.combat_context.expedition={"stage":5}
	Q.settle(MetaProgress,battle,true)
	check(MetaProgress.academy.hero_contracts.TTNK.first==0 and not MetaProgress.academy.hero_contracts.TTNK.complete,"expedition settlement excluded from normal contract tasks")
	await finish()

func building_and_terrain() -> void:
	var hero=cards_hero();var center:Vector2=hero.position+Vector2(120,0)
	var vertex:Vector2=LC.points(center)[0]
	battle.water_rects.append(Rect2(vertex-Vector2(9,9),Vector2(18,18)))
	battle.path_service.set_water(battle.water_rects)
	battle._refresh_pathing()
	check(not LC.cast(hero,ability(hero),center) and ability(hero).cd_left==0 and not battle.allied_state.has(LC.FIELDS),"one illegal water vertex rejects entire court without spending cooldown")
	battle.water_rects.clear()
	battle.path_service.set_water([])
	battle._refresh_pathing()
	check(LC.cast(hero,ability(hero),center),"same center succeeds after terrain clears")
	var building=battle._place_building("NAPOWR","enemy",center,true);building._buildup_play=-1;building.hp=100000;building.max_hp=100000
	LC.world_tick(battle,.5)
	check(building.hp<100000,"actual building footprint takes electric DOT")
	var field:Dictionary=battle.allied_state[LC.FIELDS][0]
	var node=field.nodes[0];var attacker=target("E2","enemy",node.position+Vector2(50,0))
	attacker.attack_target=node;attacker.attack_ordered=true;attacker.aim_dir=attacker.position.direction_to(node.position);attacker.hull_angle=attacker.aim_dir.angle();attacker.turret_angle=attacker.hull_angle
	check(attacker._try_fire_ready(),"native enemy weapon can select and attack a temporary electrode")
	hero.side="enemy";LC.world_tick(battle,.1)
	check(not battle.allied_state.has(LC.FIELDS),"captured hero cannot preserve original faction court")
	await finish()

func purchases() -> void:
	MetaProgress.reset_save();MetaProgress.academy.card_shards=500;MetaProgress.save()
	var bytes:=FileAccess.get_file_as_bytes(MetaProgress.SAVE_PATH)
	DirAccess.make_dir_absolute(MetaProgress.SAVE_PATH+".tmp")
	check(not Pool.purchase(MetaProgress,"leizhu_contract") and MetaProgress.academy.card_shards==500 and not MetaProgress.academy.get("hero_contracts",{}).has("TTNK"),"failed contract persistence rolls back ownership and shards")
	check(FileAccess.get_file_as_bytes(MetaProgress.SAVE_PATH)==bytes,"failed contract purchase preserves previous disk bytes")
	DirAccess.remove_absolute(MetaProgress.SAVE_PATH+".tmp")
	check(not Loadouts.equip(MetaProgress,"TTNK","active",LC.ACTIVE),"contract cards cannot be equipped before earned")
	MetaProgress.unlocked_skills.assign([LC.ACTIVE,LC.PASSIVE])
	check(Loadouts.equip(MetaProgress,"TTNK","active",LC.ACTIVE) and Loadouts.equip(MetaProgress,"TTNK","passive",LC.PASSIVE),"earned cards equip through independent hero slots")
	check(not UnitSkillLayout.compatible("TTNK",LC.ACTIVE,false) and not UnitSkillLayout.compatible("ORCA",LC.ACTIVE,true),"ordinary Tesla tank and wrong hero cannot equip exclusive W")
	for id in [LC.ACTIVE,LC.PASSIVE]:
		for rank in 3:
			MetaProgress.currency.cores=[100,230,360][rank]
			check(A.purchase(MetaProgress,"level",id) and MetaProgress.balance("cores")==0,"ultimate rank upgrade uses real price "+id+str(rank))
	MetaProgress.load_save();check(Loadouts.effective(MetaProgress,"TTNK").passive==LC.PASSIVE and MetaProgress.academy.levels[LC.ACTIVE]==3,"equipment and card tier persist on disk")
	var panel=preload("res://scripts/ui/expansion_contract_panel.gd").new();add_child(panel);panel.refresh("TTNK")
	check(panel.visible and panel.find_child("QuickEquip_"+LC.ACTIVE,true,false)!=null,"contract tasks expose actual quick-equip reward UI")
	panel.free()

func independent_fields_and_fog() -> void:
	var hero=cards_hero(3);var center:Vector2=hero.position+Vector2(120,0)
	BattleRequest.house_teams={"ally":1,"enemy":2,"enemy2":3}
	var other=battle.spawn_unit("TTNK","enemy",hero.position+Vector2(170,0));L.promote(MetaProgress,battle,other)
	# High-life fixture keeps hostile electrodes alive through both courts' first tick.
	hero.max_hp=100000;other.max_hp=100000
	var ab=Ability.new();ab.setup(GameData.get_skill(LC.ACTIVE));other.skills.append(ab)
	var victim=target("HTNK","enemy2",center)
	var total:=expected(hero,victim,.35)+expected(other,victim,.2)
	check(LC.cast(hero,ability(hero),center) and LC.cast(other,ab,center),"two real heroes independently place overlapping courts")
	LC.world_tick(battle,.5)
	check(is_equal_approx(100000-victim.hp,total) and is_equal_approx(victim.move_speed,victim._base_speed*.65),"different courts each hit once and slow uses strongest only",[100000-victim.hp,total,victim.move_speed,victim._base_speed,victim.buffs])
	LC.clear_owner(battle,hero);victim._tick_skills(.5);LC.world_tick(battle,0)
	check(is_equal_approx(victim.move_speed,victim._base_speed*.8),"destroying stronger court leaves only weaker court slow",[victim.move_speed,victim._base_speed,battle.allied_state[LC.FIELDS].size(),victim.buffs])
	var fog=preload("res://scripts/world/fog_of_war.gd").new();battle.add_child(fog);fog.setup(battle);battle.fog=fog
	fog.visible_cells.ally.fill(0);fog.explored_cells.ally.fill(0)
	var enemy_field:Dictionary=battle.allied_state[LC.FIELDS][0]
	LC.electrode_tick(enemy_field.nodes[0],0)
	check(not enemy_field.nodes[0].visible,"enemy electrode does not render through unrevealed fog",[enemy_field.nodes[0].side,enemy_field.nodes[0].hp,enemy_field.nodes[0].visible,fog.is_visible_at("ally",enemy_field.nodes[0].position)])
	ability(hero).cd_left=0
	check(not LC.cast(hero,ability(hero),center),"unseen center rejects W without cooldown")
	fog.visible_cells.ally[fog._index(center)]=1;fog.explored_cells.ally[fog._index(center)]=1
	check(LC.cast(hero,ability(hero),center),"visible center accepts legal three-point court")
	LC.clear_owner(battle,other);var hp:float=victim.hp
	fog.visible_cells.ally.fill(0);LC.world_tick(battle,.5)
	check(victim.hp==hp and not fog.is_visible_at("ally",center),"field neither damages hidden enemy nor reveals target area")
	fog.visible_cells.ally[fog._index(center)]=1;LC.world_tick(battle,.5)
	check(victim.hp<hp,"normal visibility returning restores legal field damage")
	check(hero.special[L.KEY].get("charge_count",0)==0,"equipped passive cannot receive layers from court DOT")
	await finish()

func boundaries() -> void:
	var hero=cards_hero();var ab=ability(hero)
	check(not LC.cast(hero,ab,hero.position+Vector2(276,0)) and ab.cd_left==0,"out-of-range cast does not consume cooldown")
	check(not LC.cast(hero,ab,Vector2.INF) and ab.cd_left==0,"invalid coordinate rejected")
	hero._stun_timer=1;check(not LC.cast(hero,ab,hero.position),"stun rejects W");hero._stun_timer=0
	var normal=battle.spawn_unit("TTNK","ally",hero.position+Vector2(40,0));check(not LC.ready(normal,ab),"ordinary tank cannot activate hero W")
	var air=target("ORCA","enemy",hero.position);air.logistics.air_lift=1
	var naval=target("SUB","enemy",hero.position)
	var cloaked=target("HTNK","enemy",hero.position);cloaked.special.echo_cloaked=true
	var immune=target("HTNK","enemy",hero.position);immune.special.iron_left=10
	var friendly=target("HTNK","ally",hero.position)
	check(LC.cast(hero,ab,hero.position+Vector2(120,0)),"legal exclusion-test court actually exists")
	for unit in [air,naval,cloaked,immune,friendly]:unit.position=hero.position+Vector2(120,0)
	LC.world_tick(battle,1)
	check([air,naval,cloaked,immune,friendly].all(func(u):return u.hp==100000),"court excludes aircraft, navy, concealed, invulnerable and friendly actors")
	battle.allied_state.get_or_add("defeated_houses",{}).ally=true;LC.world_tick(battle,.1)
	check(not battle.allied_state.has(LC.FIELDS),"faction elimination dissolves court")
	await finish()

func contract() -> void:
	var hero=cards_hero(0,false);var enemy=target();var progress:Dictionary=Q.progress(battle,"TTNK")
	for i in 25:
		var victim=target();victim.hp=1;fire(hero,victim)
	check(progress.first==25,"native primary kills complete task before owning reward cards",progress)
	hero.max_hp=10000;hero.hp=10000;hero.special[L.KEY].shield={"hp":100.0,"left":6.0}
	hero.receive_hit(80,"electric",{},enemy)
	check(progress.second==0,"shield absorption excluded from actual health-loss quest")
	hero.special[L.KEY].erase("shield");hero.receive_hit(6000*hero.bonuses.defense_bonus,"electric",{},enemy)
	check(progress.second==10000-hero.hp and progress.second<6000,"quest uses defended/capped HP loss rather than requested damage",progress.second)
	hero.receive_hit(3000,"electric",{},enemy)
	check(progress.second==10000-hero.hp and progress.second>=6000 and hero.hp>0,"cumulative actual damage qualifies while hero survives",progress.second)
	Q.settle(MetaProgress,battle,true)
	check(MetaProgress.academy.hero_contracts.TTNK.complete and LC.ACTIVE in MetaProgress.unlocked_skills and LC.PASSIVE in MetaProgress.unlocked_skills,"surviving normal victory grants both cards")
	var count:int=MetaProgress.unlocked_skills.size();Q.settle(MetaProgress,battle,true);MetaProgress.save();MetaProgress.load_save()
	check(MetaProgress.unlocked_skills.size()==count and MetaProgress.academy.hero_contracts.TTNK.complete,"settlement idempotent and disk persistence retains reward")
	await finish()
	MetaProgress.reset_save();MetaProgress.academy.card_shards=500
	check(Pool.purchase(MetaProgress,"leizhu_contract") and MetaProgress.academy.card_shards==0,"real exchange costs 500 shards")
	check(Pool.entries().size()==8 and is_equal_approx(Pool.chance(),.0035) and not Pool.purchase(MetaProgress,"leizhu_contract"),"eight entries share original total chance, no duplicate purchase")

func slow_overlap() -> void:
	var hero=cards_hero();var victim=target("HTNK","enemy",hero.position+Vector2(120,0))
	LC.cast(hero,ability(hero),victim.position)
	var field:Dictionary=battle.allied_state[LC.FIELDS][0];field.slow=.35;LC.world_tick(battle,0)
	field.slow=.2;victim._tick_skills(.5);LC.world_tick(battle,0)
	check(is_equal_approx(victim.move_speed,victim._base_speed*.8),"expired strong slow does not renew indefinitely under weaker field")
	LC.world_tick(battle,0);check(is_equal_approx(victim.move_speed,victim._base_speed*.8),"repeated overlap refresh never adds slow percentages")
	await finish()
