extends "res://tests/electric_cards_regression.gd"
const Domain=preload("res://scripts/units/domain_cards.gd")
const Scope=preload("res://scripts/rules/skill_scope.gd")
const Gallery=preload("res://scripts/ui/faction_card_gallery.gd")
const NEW_IDS=[Domain.REPAIR,Domain.ANCHOR,Domain.GUARD,Domain.SCOUT]

func loadout(id:String,active:String,passive_id:String,rank:int) -> void:
	BattleRequest.combat_context.loadouts[id]={"active":[active],"passive":passive_id}
	for card in NEW_IDS:
		BattleRequest.combat_context.card_ranks[card]=rank
		BattleRequest.combat_context.get_or_add("card_strength_overrides",{})[card]=MetaProgress.Academy.card_strength(rank,GameData.get_skill(card))

func exercise(mode:String) -> void:
	start(mode)
	BattleRequest.combat_context.bonuses=MatchRules.neutral_bonuses();BattleRequest.combat_context.unit_bonus={}
	if mode==MatchRules.RA2:
		loadout("DEST",Domain.REPAIR,Domain.ANCHOR,3)
		var ship=make("DEST","ally",Vector2(1200,1200))
		check(UnitSkillLayout.index(ship,1)==-1 and ship.passive.is_empty(),"classic excludes naval cards")
		await finish();return
	var candidates:=MetaProgress.skill_draw_candidates().map(func(c):return c.id)
	for id in NEW_IDS:
		var row:=GameData.get_skill(id)
		check(id in candidates and row.rarity=="common" and Scope.rarity_color(row)==Color.WHITE,"common draw candidate "+id)
		check(not Scope.compatible("MTNK",row) and not Scope.compatible("E1",row) and not Scope.compatible("NALASR",row),"domain excludes unrelated units "+id)
	check(Scope.compatible("DEST",GameData.get_skill(Domain.REPAIR)) and Scope.compatible("SUB",GameData.get_skill(Domain.REPAIR)) and not Scope.compatible("DLPH",GameData.get_skill(Domain.REPAIR)),"repair applies ships and submarines not dolphin")
	check(Scope.compatible("ORCA",GameData.get_skill(Domain.GUARD)) and Scope.compatible("R3HARBINGER",GameData.get_skill(Domain.GUARD)),"air applies both generations")
	check(not Scope.compatible("CARRIER",GameData.get_skill(Domain.ANCHOR)) and not Scope.compatible("LCRF",GameData.get_skill(Domain.ANCHOR)),"no useless anchor on carrier or transport")
	for rank in 4:
		loadout("DEST",Domain.REPAIR,Domain.ANCHOR,rank)
		var ship=make("DEST","ally",Vector2(1200,1200))
		var idx:=UnitSkillLayout.index(ship,1)
		check(not ship.ability_ready(1),"full health cannot waste repair "+str(rank))
		ship.hp=50000;ship.velocity=Vector2(40,0)
		check(ship.use_ability(idx) and not ship.use_ability(idx),"moving repair casts once "+str(rank))
		Domain.tick(ship,1.0)
		check(is_equal_approx(ship.hp,50000+ship.max_hp*(.03+.01*rank)/4),"gradual repair first second "+str(rank))
		Domain.tick(ship,10.0)
		check(is_equal_approx(ship.hp,50000+ship.max_hp*(.03+.01*rank)),"repair clamps total at four seconds "+str(rank))
		ship.velocity=Vector2.ZERO
		Domain.tick(ship,1.99)
		check(ship.buff_value("cooldown")==0,"anchor requires full two seconds "+str(rank))
		Domain.tick(ship,.02)
		var reduction:float=[.08,.10,.12,.15][rank]
		check(is_equal_approx(ship.buff_value("cooldown"),reduction),"anchor rank reload "+str(rank))
		var target=make("DEST","enemy",ship.position+Vector2(80,0))
		ship.attack_target=target;ship.attack_ordered=true;ship.hull_angle=0;ship.turret_angle=0
		var base:float=CombatMath.veteran_cooldown(ship.cooldown,ship.bonuses)*Unit.YRTalents.cooldown_multiplier(ship)
		check(ship._try_fire_ready() and is_equal_approx(ship._cd_timer,base*(1-reduction)),"anchor changes actual firing reload "+str(rank))
		ship._cd_timer*=.5;ship.velocity=Vector2(40,0)
		check(ship.buff_value("cooldown")==0,"anchor ends on movement "+str(rank))
		check(is_equal_approx(preload("res://scripts/ui/attack_cooldown_indicator.gd").ordinary_slot(ship,ship.weapon,"hull").fraction,.5),"movement preserves pending reload ring "+str(rank))
		clear_units()
		loadout("ORCA",Domain.GUARD,Domain.SCOUT,rank)
		var air=make("ORCA","ally",Vector2(1200,1200));idx=UnitSkillLayout.index(air,1)
		air.logistics.air_lift=0
		check(not air.use_ability(idx),"landed aircraft cannot activate guard "+str(rank))
		air.logistics.air_lift=1
		check(air.use_ability(idx) and is_equal_approx(Domain.defend(air,100),100*(1-[.20,.25,.30,.35][rank])),"air defense rank "+str(rank))
		var guarded_hp:float=air.hp
		air.receive_hit(100,"bullet",{},null,"RA3_EXPANSION")
		check(is_equal_approx(guarded_hp-air.hp,100*(1-[.20,.25,.30,.35][rank])),"actual incoming damage reduction "+str(rank))
		check(Domain.defend(air,-100)==-100,"guard never weakens repair "+str(rank))
		Domain.tick(air,3.01)
		check(Domain.defend(air,100)==100,"guard expires "+str(rank))
		air.skills[idx].cd_left=0;air.use_ability(idx);air.logistics.air_lift=0
		Domain.tick(air,.01)
		check(Domain.defend(air,100)==100,"landing cancels guard "+str(rank))
		air.logistics.air_lift=1;air.velocity=Vector2(40,0)
		var fog=preload("res://scripts/world/fog_of_war.gd").new();var sight:float=fog.vision_radius(air);var reach:float=air.attack_range
		for i in 21:air.position.x+=4;Domain.tick(air,.1)
		check(is_equal_approx(fog.vision_radius(air),sight*(1+[.15,.20,.25,.30][rank])) and air.attack_range==reach,"cruise only expands vision rank "+str(rank))
		air.velocity=Vector2.ZERO
		check(is_equal_approx(fog.vision_radius(air),sight),"stop removes scout sight immediately "+str(rank))
		fog.free()
		clear_units()
	loadout("DEST",Domain.REPAIR,Domain.ANCHOR,3)
	var ship=make("DEST","ally",Vector2(1200,1200));ship.hp=50000
	ship.use_ability(UnitSkillLayout.index(ship,1));Domain.tick(ship,1.0)
	var codec=BattleSaves.Snapshot.new();var snapshot:Dictionary=codec.capture(battle)
	check(codec.error.is_empty(),"domain cards snapshot capture")
	codec.restore(battle,snapshot)
	ship=battle.units.filter(func(u):return u.unit_id=="DEST")[0]
	activate(ship)
	check(ship.special[Domain.STATE].left==3.0,"save restore preserves remaining duration")
	var hp:float=ship.hp;Domain.tick(ship,8.0)
	check(is_equal_approx(ship.hp-hp,ship.max_hp*.06*.75),"restore heals only remaining amount")
	var gallery:=Gallery.new();add_child(gallery)
	for id in NEW_IDS:
		for rank in 4:
			gallery.select_card(gallery.ids.find(id),rank)
			check(gallery.stage.card==id and not gallery.stage.caster_model_id.is_empty() and gallery.summary.text.contains(GameData.get_skill(id).name),"dynamic model demo "+id+str(rank))
	gallery.free()
	await finish()
