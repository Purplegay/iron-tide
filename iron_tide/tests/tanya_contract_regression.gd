extends "res://tests/commando_hero_regression.gd"
const B=preload("res://scripts/units/tanya_breach.gd")
const Q=preload("res://scripts/rules/expansion_contracts.gd")
const CQ=preload("res://scripts/rules/commando_contracts.gd")
const Pool=preload("res://scripts/rules/hero_contract_pool.gd")
const Demo=preload("res://scripts/ui/commando_card_demo.gd")

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
	await get_tree().process_frame
	for level in 4:await blast(level)
	for level in 4:await structure_damage(level)
	for level in 4:await passive_boundaries(level)
	await cancellation_and_restore()
	await disk_resume_and_freed_owner()
	await legal_points_and_cap()
	await contract_boundaries()
	await contract_events()
	await purchase_and_settlement()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	print("TANYA_CONTRACT_RESULT ",checks.size()," checks, ",failed," failed")
	get_tree().quit(0 if failed==0 else 1)

func setup_hero(level:int=0):
	MetaProgress.reset_save()
	MetaProgress.academy.hero_builds={"TANY":5}
	MetaProgress.unlocked_skills.assign([B.ID,CQ.PASSIVE])
	MetaProgress.academy.levels={B.ID:level,CQ.PASSIVE:level}
	Loadouts.equip(MetaProgress,"TANY","active",B.ID)
	Loadouts.equip(MetaProgress,"TANY","passive",CQ.PASSIVE)
	Pool.grant(MetaProgress,"tanya_contract")
	boot("TANY")
	var hero=battle.spawn_unit("TANY","ally",Vector2(1050,1000))
	A.promote(MetaProgress,battle,"TANY",hero)
	return hero

func bombs() -> Array:
	return battle.units.filter(func(unit):return AlliedAbilities.alive(unit) and unit.special.has(B.PAYLOAD))

func robust_enemy(id:String,at:Vector2):
	var unit=battle.spawn_unit(id,"enemy",at)
	unit.max_hp=100000;unit.hp=100000;unit._base_max_hp=100000
	unit._base_def=1;unit.bonuses={"defense_bonus":1.0}
	return unit

func blast(level:int) -> void:
	var hero=setup_hero(level)
	var at:=Vector2(1200,1000)
	var ab:Ability=hero.skills[UnitSkillLayout.find(hero,B.ID)]
	check(GameData.get_skill(B.ID).rarity=="ultimate" and GameData.get_skill(CQ.PASSIVE).rarity=="ultimate","ultimate contract card rarity "+str(level))
	for card in [B.ID,CQ.PASSIVE]:check(not A.skill_description(GameData.get_skill(card),level).contains("{"),"resolved four-rank description "+card+str(level))
	check(not B.cast(hero,ab,hero.position+Vector2(221,0)) and ab.cd_left==0,"out-of-range cast does not spend cooldown")
	var normal=battle.spawn_unit("TANY","ally",hero.position+Vector2(0,100))
	check(not B.ready(normal,ab),"ordinary Tanya cannot use hero contract W")
	var infantry=robust_enemy("E2",at)
	var heavy=robust_enemy("HTNK",at)
	var light=robust_enemy("FV",at)
	var air=robust_enemy("ORCA",at)
	air.logistics.air_lift=1.0
	var ratio:float=[.6,.8,1.0,1.2][level]
	var expected:=CombatMath.with_offense(float(CommandoCombat.weapon_for(hero,null).damage)*ratio,hero.bonuses)
	check(hero.use_ability(UnitSkillLayout.find(hero,B.ID),at),"actual W slot casts three-point breach "+str(level))
	check(bombs().size()==1 and is_equal_approx(ab.cd_left,[40.0,37.0,34.0,30.0][level]),"first throw is immediate with rank cooldown")
	var first=bombs()[0]
	check(is_equal_approx(first.hp,hero.max_hp*.03) and is_equal_approx(first.special[B.PAYLOAD].damage,expected),"snapshot includes elite and training once")
	hero.add_buff("attack",5,.5,"test attack change")
	B.tick(hero,.35)
	check(bombs().size()==2 and is_equal_approx(bombs()[1].special[B.PAYLOAD].damage,expected*1.5),"next throw uses current attack, not initial cast snapshot")
	B.tick(hero,.35)
	check(bombs().size()==3 and not hero.special[C.KEY].has("breach_throw"),"third throw completes .7-second sequence")
	for bomb in bombs():check(is_equal_approx(bomb.position.x,at.x) and absf(bomb.position.y-at.y)<=44.001,"three drops lie perpendicular at fixed points")
	ab.cd_left=0
	check(not B.ready(hero,ab),"only one group survives even with reset cooldown")
	var original:float=infantry.hp
	B.charge_tick(first,1.89)
	check(infantry.hp==original,".4 flight plus 1.5 fuse not finished early")
	B.charge_tick(first,.01)
	check(is_equal_approx(original-infantry.hp,Ra2Damage.quantize(expected)),"infantry blast is attack percentage without execution",original-infantry.hp)
	check(is_equal_approx(100000-heavy.hp,Ra2Damage.quantize(expected*.65)),"heavy armor factor .65")
	check(is_equal_approx(100000-light.hp,Ra2Damage.quantize(expected*.8)),"light armor factor .8")
	check(air.hp==100000,"ground charges cannot hit airborne target")
	var remaining:=bombs()
	for bomb in remaining:B.charge_tick(bomb,1.9)
	var total:=Ra2Damage.quantize(expected)+2*Ra2Damage.quantize(expected*1.5)
	check(is_equal_approx(original-infantry.hp,total),"same target takes each charge exactly once")
	B.charge_tick(first,1.0)
	check(is_equal_approx(original-infantry.hp,total),"spent charge cannot deal damage again")
	check(B.ready(hero,ab),"resolved group frees group gate")
	var state:=Demo.sample(B.ID,level,2)
	check(is_equal_approx(state.damage,200*ratio) and state.cooldown==[40,37,34,30][level],"demo uses rank attack ratio and cooldown")
	check(Demo.sample(CQ.PASSIVE,level,1.2).active and not Demo.sample(CQ.PASSIVE,level,4.1).active,"passive demo expires at rank duration")
	await finish()

func cancellation_and_restore() -> void:
	var hero=setup_hero(3)
	var ab:Ability=hero.skills[UnitSkillLayout.find(hero,B.ID)]
	var at:=Vector2(1200,1000)
	var target=robust_enemy("E2",at)
	B.cast(hero,ab,at)
	var first=bombs()[0]
	first.receive_hit(100000,"bullet",{},target)
	B.charge_tick(first,5)
	check(first._dead and first.is_queued_for_deletion() and target.hp==100000,"destroyed charge vanishes without explosion")
	hero.special.chrono_left=2.0;B.tick(hero,.7)
	check(not hero.special[C.KEY].has("breach_throw") and bombs().is_empty(),"freeze cancels unthrown charges")
	hero.special.erase("chrono_left");ab.cd_left=0
	B.cast(hero,ab,at)
	B.charge_tick(bombs()[0],.7)
	var stored_damage:float=bombs()[0].special[B.PAYLOAD].damage
	var codec=BattleSaves.Snapshot.new()
	var snapshot:Dictionary=codec.capture(battle)
	check(codec.error.is_empty(),"pending throw and live charge snapshot captures")
	codec.restore(battle,snapshot)
	check(codec.error.is_empty(),"pending throw and live charge snapshot restores")
	for unit in battle.units:
		if unit.special.get("academy_hero")=="TANY":hero=unit
		if unit.side=="enemy" and unit.unit_id=="E2":target=unit
	check(bombs().size()==1 and is_equal_approx(bombs()[0].special[B.PAYLOAD].age,.7) and is_equal_approx(bombs()[0].special[B.PAYLOAD].damage,stored_damage),"save preserves consumed fuse and exact attack snapshot")
	check(is_same(bombs()[0].special[B.PAYLOAD].owner,hero) and is_same(hero.special[C.KEY].breach_charges[0],bombs()[0]),"save relinks both owner and group references")
	hero._die();B.tick(hero,1.0)
	check(not hero.special[C.KEY].has("breach_throw"),"death cancels remaining throws")
	B.charge_tick(bombs()[0],1.2)
	check(target.hp<100000 and bombs().is_empty(),"already thrown charge still detonates after owner death")
	await finish()

func contract_events() -> void:
	var hero=setup_hero(3)
	var p:=Q.progress(battle,"TANY")
	var target=battle.spawn_unit("E2","enemy",hero.position+Vector2(80,0))
	var speed:float=hero.move_speed
	hero._fire_shot(target)
	for shot in hero._pick_projectile_parent().get_children():
		if shot is Projectile and shot.shooter()==hero:shot._physics_process(1.0)
	check(target._dead and p.first==1,"real ordinary double-pistol kill counts one infantry")
	check(hero.special[C.KEY].has("rhythm_left") and is_equal_approx(hero.move_speed,speed*1.25),"ordinary kill activates passive speed")
	var enemy=robust_enemy("E2",hero.position+Vector2(100,100))
	check(is_equal_approx(C.defend(hero,100,"bullet",{},enemy),75) and C.defend(hero,100,"explosive",{},enemy)==100,"passive protects ordinary ranged hits only")
	C.tick(hero,1.0)
	var left:float=hero.special[C.KEY].rhythm_left
	var extra=battle.spawn_unit("E2","enemy",hero.position+Vector2(70,0))
	extra.receive_hit(100000,"bullet",{"impact_weapon":"DoublePistolsE","expansion_extra":true},hero)
	check(p.first==1 and hero.special[C.KEY].rhythm_left==left,"extra gun attack neither counts nor refreshes rhythm")
	var temp=battle.spawn_unit("E2","enemy",hero.position+Vector2(75,0));temp.special.expansion_temporary={"kind":"reserve"}
	temp.receive_hit(100000,"bullet",{"impact_weapon":"DoublePistolsE"},hero)
	check(p.first==1,"temporary infantry cannot farm contract")
	var victim=battle._place_building("NAPOWR","enemy",Vector2(1500,1400),true)
	victim.special.c4_left=.01;victim.special.c4_owner=hero
	AlliedAbilities.tick_actor(victim,.02)
	check(victim._dead and p.second==1,"native C4 building death counts independently")
	check(hero.special[C.KEY].rhythm_left==left,"kill during interval cannot extend rhythm")
	C.tick(hero,7)
	check(not hero.special[C.KEY].has("rhythm_left") and not hero.special[C.KEY].has("rhythm_cd") and is_equal_approx(hero.move_speed,speed),"passive expires without permanent speed stacking")
	var building=battle._place_building("GAPILL","enemy",Vector2(1400,1100),true)
	building._buildup_play=-1.0;building.hp=1
	# The melee approach can still lie in the foundation's blocked path cell.
	# Pick open ground independently, within the charge's real splash radius.
	var point:=open_blast_point(building)
	check(point.is_finite(),"fixture has open ground within building splash radius")
	if not point.is_finite():await finish();return
	hero.position=point-Vector2(100,0)
	var ab:Ability=hero.skills[UnitSkillLayout.find(hero,B.ID)];ab.cd_left=0
	check(B.cast(hero,ab,point),"breach may target legal ground beside a defense building",{"point":point,"valid":B.GROUND.valid_zone(battle,point),"ready":B.ready(hero,ab),"gap":building.closest_footprint_point(point).distance_to(point)})
	if not bombs().is_empty():B.charge_tick(bombs()[0],1.9)
	check(building._dead and p.second==1 and p.defenses==1,"charge defense kill qualifies victory task, not native C4 task")
	check(hero.special[C.KEY].has("rhythm_left"),"own charge building kill triggers passive")
	await finish()

func purchase_and_settlement() -> void:
	MetaProgress.reset_save()
	check(is_equal_approx(Pool.chance(),.0035) and Pool.for_hero("TANY").cards.size()==2,"new contract shares total .35 percent pool")
	MetaProgress.academy.card_shards=499
	check(not Pool.purchase(MetaProgress,"tanya_contract"),"targeted contract requires 500 shards")
	MetaProgress.academy.card_shards=500
	check(Pool.purchase(MetaProgress,"tanya_contract") and MetaProgress.academy.card_shards==0,"contract may open before permanent hero unlock")
	check(not Pool.candidates(MetaProgress).any(func(row):return row.hero_id=="TANY") and not Pool.purchase(MetaProgress,"tanya_contract"),"owned contract cannot draw or buy again")
	MetaProgress.academy.hero_builds={"TANY":5}
	boot("TANY")
	var hero=battle.spawn_unit("TANY","ally",Vector2(1200,1000));A.promote(MetaProgress,battle,"TANY",hero)
	var p:=Q.progress(battle,"TANY");p.first=60;p.second=8;p.defenses=1
	Q.settle(MetaProgress,battle,false)
	var quest:Dictionary=MetaProgress.academy.hero_contracts.TANY
	check(quest.first==60 and quest.second==8 and not quest.win and not quest.complete,"loss settles cumulative goals but cannot satisfy victory")
	Q.settle(MetaProgress,battle,true)
	check(not quest.complete,"same match settlement cannot be replayed as victory")
	await finish()
	boot("TANY")
	hero=battle.spawn_unit("TANY","ally",Vector2(1200,1000));A.promote(MetaProgress,battle,"TANY",hero)
	p=Q.progress(battle,"TANY");p.defenses=1
	Q.settle(MetaProgress,battle,true)
	check(quest.complete and MetaProgress.skill_unlocked(B.ID) and MetaProgress.skill_unlocked(CQ.PASSIVE),"normal victory with living hero grants both Lv0 cards")
	MetaProgress.save();MetaProgress.load_save()
	check(MetaProgress.academy.hero_contracts.TANY.complete and A.card_rank(MetaProgress,B.ID)==0,"contract and Lv0 rewards persist")
	for id in [B.ID,CQ.PASSIVE]:
		for rank in 3:
			var cost:int=[100,230,360][rank];MetaProgress.currency.cores=cost
			check(A.purchase(MetaProgress,"level",id) and MetaProgress.balance("cores")==0 and A.card_rank(MetaProgress,id)==rank+1,"ultimate rank price "+id+str(rank))
	await finish()

func passive_boundaries(level:int) -> void:
	var hero=setup_hero(level)
	var speed:float=hero.move_speed
	var target=battle.spawn_unit("E2","enemy",Vector2(1200,1000))
	target.receive_hit(100000,"bullet",{"impact_weapon":"DoublePistolsE"},hero)
	var state:Dictionary=hero.special[C.KEY]
	var life:float=[1.5,2.0,2.5,3.0][level]
	check(is_equal_approx(state.get("rhythm_left",0),life) and is_equal_approx(hero.move_speed,speed*1.25),"passive rank duration and single speed multiplier "+str(level))
	var enemy=robust_enemy("E2",Vector2(1300,1000))
	check(is_equal_approx(C.defend(hero,100,"bullet",{},enemy),[90,85,80,75][level]),"passive rank ordinary ranged reduction "+str(level))
	check(C.defend(hero,100,"bullet",{"expansion_extra":true},enemy)==100 and C.defend(hero,100,"crush",{},enemy)==100,"extra and crush bypass passive reduction")
	C.tick(hero,life)
	check(not state.has("rhythm_left") and state.has("rhythm_cd") and is_equal_approx(hero.move_speed,speed),"actual timer removes movement bonus before cooldown ends")
	var next=battle.spawn_unit("E2","enemy",Vector2(1200,1000))
	next.receive_hit(100000,"bullet",{"impact_weapon":"DoublePistolsE"},hero)
	check(not state.has("rhythm_left"),"kills during passive cooldown do not restart expired window")
	C.tick(hero,8-life)
	next=battle.spawn_unit("E2","enemy",Vector2(1200,1000))
	next.receive_hit(100000,"bullet",{"impact_weapon":"DoublePistolsE"},hero)
	check(is_equal_approx(state.get("rhythm_left",0),life),"passive retriggers at exact eight-second interval")
	await finish()

func legal_points_and_cap() -> void:
	var hero=setup_hero(3)
	var ab:Ability=hero.skills[UnitSkillLayout.find(hero,B.ID)]
	for point in [Vector2.INF,Vector2(-1,1000),battle.buildings[0].position]:
		check(not B.cast(hero,ab,point) and ab.cd_left==0 and bombs().is_empty(),"invalid or blocked cast creates no charge and spends no cooldown")
	var at:=Vector2(1200,1000)
	battle.water_rects.append(Rect2(at-Vector2.ONE*10,Vector2.ONE*20))
	battle.path_service.set_water(battle.water_rects)
	check(not B.cast(hero,ab,at) and ab.cd_left==0,"water center cannot accept breach charges")
	battle.water_rects.clear()
	battle.path_service.set_water([])
	B.cast(hero,ab,at)
	var carrier=battle.spawn_unit("FV","ally",hero.position)
	hero.embarked_in=carrier;B.tick(hero,.7)
	check(not hero.special[C.KEY].has("breach_throw") and bombs().size()==1,"embarking cancels only unthrown charges")
	hero.embarked_in=null
	var unaffected=robust_enemy("E2",at)
	battle.water_rects.append(Rect2(at-Vector2.ONE*10,Vector2.ONE*20))
	battle.path_service.set_water(battle.water_rects)
	B.charge_tick(bombs()[0],2)
	check(bombs().is_empty() and unaffected.hp==100000,"landing becoming invalid dissolves charge without explosion")
	battle.water_rects.clear();ab.cd_left=0
	battle.path_service.set_water([])
	# High attack must still pass through the established final-damage curve.
	BattleRequest.combat_context.erase("house_training")
	BattleRequest.combat_context.final_damage_cap=2.25
	BattleRequest.combat_context.final_damage_threshold=2.0
	hero.bonuses.attack_bonus=10.0
	var enemy=robust_enemy("HTNK",at);enemy.bonuses.defense_bonus=2.0
	var friendly=battle.spawn_unit("E2","ally",at)
	var neutral=battle.spawn_unit("E2","neutral",at)
	var friend_hp:float=friendly.hp;var neutral_hp:float=neutral.hp
	B.cast(hero,ab,at)
	var bomb=bombs()[0]
	var reference:float=bomb.special[B.PAYLOAD].raw*.65*float(hero.bonuses.get("veteran_attack",1))
	var curved:float=2.0+.25*log(33.0)/(1.0+log(33.0))
	var expected:=Ra2Damage.quantize(reference*curved/2.0)
	B.charge_tick(bomb,1.9)
	check(is_equal_approx(100000-enemy.hp,expected),"blast custom armor and defense feed final damage cap exactly once",100000-enemy.hp)
	check(friendly.hp==friend_hp and neutral.hp==neutral_hp,"blast excludes friendly and neutral actors")
	await finish()

func contract_boundaries() -> void:
	MetaProgress.reset_save();MetaProgress.academy.hero_builds={"TANY":5}
	boot("TANY")
	Pool.grant(MetaProgress,"tanya_contract")
	var hero=battle.spawn_unit("TANY","ally",Vector2(1050,1000));A.promote(MetaProgress,battle,"TANY",hero)
	var enemy=battle.spawn_unit("E2","enemy",Vector2(1200,1000))
	enemy.receive_hit(100000,"bullet",{"impact_weapon":"DoublePistolsE"},hero)
	check(Q.progress(battle,"TANY").first==0,"contract opened mid-match cannot backfill that match")
	await finish()
	hero=setup_hero(0)
	var p:=Q.progress(battle,"TANY")
	for side in ["ally","neutral"]:
		var target=battle.spawn_unit("E2",side,Vector2(1200,1000))
		target.receive_hit(100000,"bullet",{"impact_weapon":"DoublePistolsE"},hero)
	check(p.first==0 and not hero.special[C.KEY].has("rhythm_left"),"friendly and neutral kills cannot farm contract or passive")
	BattleRequest.combat_context.expedition={"stage":5}
	enemy=battle.spawn_unit("E2","enemy",Vector2(1200,1000))
	enemy.receive_hit(100000,"bullet",{"impact_weapon":"DoublePistolsE"},hero)
	check(p.first==0 and hero.special[C.KEY].has("rhythm_left"),"expedition keeps passive combat effect but excludes permanent tasks")
	await finish()
	hero=setup_hero(0)
	p=Q.progress(battle,"TANY");p.first=60;p.second=8;p.defenses=1
	hero._die()
	Q.settle(MetaProgress,battle,true)
	check(not MetaProgress.academy.hero_contracts.TANY.win and not MetaProgress.academy.hero_contracts.TANY.complete,"victory with dead Tanya cannot satisfy survival task")
	await finish()

func disk_resume_and_freed_owner() -> void:
	var hero=setup_hero(3)
	var at:=Vector2(1200,1000)
	var enemy=robust_enemy("E2",at)
	B.cast(hero,hero.skills[UnitSkillLayout.find(hero,B.ID)],at)
	B.tick(hero,.35)
	var codec=BattleSaves.Snapshot.new()
	var snapshot:Dictionary=codec.capture(battle)
	var path:=output_dir.path_join("partial-breach-snapshot.bin")
	var file:=FileAccess.open(path,FileAccess.WRITE)
	file.store_var(snapshot,false);file.close()
	file=FileAccess.open(path,FileAccess.READ)
	var restored:Dictionary=file.get_var(false);file.close()
	codec.restore(battle,restored)
	check(codec.error.is_empty() and bombs().size()==2,"disk snapshot restores two existing charges")
	for unit in battle.units:
		if unit.special.get("academy_hero")=="TANY":hero=unit
		if unit.side=="enemy" and unit.unit_id=="E2":enemy=unit
	B.tick(hero,.34)
	check(bombs().size()==2,"restored throw keeps remaining interval")
	B.tick(hero,.01)
	check(bombs().size()==3 and not hero.special[C.KEY].has("breach_throw"),"restore produces only outstanding third charge")
	var expected:=0.0
	for bomb in bombs():expected+=Ra2Damage.quantize(float(bomb.special[B.PAYLOAD].damage))
	hero._die();hero.free()
	for bomb in bombs():B.charge_tick(bomb,1.9)
	check(is_equal_approx(100000-enemy.hp,expected),"all damage snapshots remain valid after owner object is freed")
	await finish()

func open_blast_point(building) -> Vector2:
	for x in range(-80,81,10):
		for y in range(-80,81,10):
			var candidate:Vector2=building.position+Vector2(x,y)
			if B.GROUND.valid_zone(battle,candidate) and building.closest_footprint_point(candidate).distance_to(candidate)<49.5:return candidate
	return Vector2.INF

func structure_damage(level:int) -> void:
	var hero=setup_hero(level)
	var structure=battle._place_building("GAPILL","enemy",Vector2(1400,1100),true)
	structure._buildup_play=-1;structure.max_hp=100000;structure.hp=100000
	structure.bonuses={"defense_bonus":2.0}
	var point:=open_blast_point(structure)
	check(point.is_finite(),"building armor fixture has a legal blast point")
	if not point.is_finite():await finish();return
	hero.position=point-Vector2(100,0)
	var expected:=CombatMath.with_offense(float(CommandoCombat.weapon_for(hero,null).damage)*[.6,.8,1.0,1.2][level],hero.bonuses)
	check(B.cast(hero,hero.skills[UnitSkillLayout.find(hero,B.ID)],point),"cast beside structure for building armor rank "+str(level))
	if not bombs().is_empty():B.charge_tick(bombs()[0],1.9)
	check(is_equal_approx(100000-structure.hp,Ra2Damage.quantize(expected*.6/2.0)),"building factor .6 then current defense once "+str(level),100000-structure.hp)
	await finish()
