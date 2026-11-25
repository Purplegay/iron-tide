extends "res://tests/ground_control_regression.gd"
const Cards = preload("res://scripts/units/electric_cards.gd")
const Reserve = preload("res://scripts/units/tesla_reserve.gd")
const IDS := [Cards.CHAIN,Cards.PULSE,Cards.GUARD,Cards.STRIDE]

func make(id:String, side:String, at:Vector2):
	var actor=battle.spawn_unit(id,side,at)
	activate(actor)
	actor.max_hp=100000;actor.hp=100000
	return actor

func equip(id:String, active:String, passive:String, rank:int) -> void:
	BattleRequest.combat_context.loadouts[id]={"active":[active],"passive":passive}
	for card in IDS:
		BattleRequest.combat_context.card_ranks[card]=rank
		BattleRequest.combat_context.get_or_add("card_strength_overrides",{})[card]=MetaProgress.Academy.card_strength(rank,GameData.get_skill(card))

func clear_units() -> void:
	for actor in battle.units: actor.free()
	battle.units.clear()

func exercise(mode:String) -> void:
	start(mode)
	battle.fog=null
	BattleRequest.combat_context.bonuses=MatchRules.neutral_bonuses()
	BattleRequest.combat_context.unit_bonus={}
	BattleRequest.combat_context.unit_talents={"SHK":{Reserve.ID:3}}
	for rank in 4:
		equip("SHK",Cards.CHAIN,"",rank)
		var actor=make("SHK","ally",Vector2(1200,1200))
		var target=make("HTNK","enemy",Vector2(1250,1200))
		var near=make("HTNK","enemy",Vector2(1270,1200))
		var second=make("HTNK","enemy",Vector2(1250,1230))
		var third=make("HTNK","enemy",Vector2(1300,1200))
		var friendly=make("HTNK","ally",Vector2(1250,1190))
		var air=make("JUMPJET","enemy",Vector2(1250,1200))
		var idx:=UnitSkillLayout.index(actor,1)
		if mode==MatchRules.RA2:
			check(idx==-1 and actor.passive.is_empty(),prefix+"extension card not installed")
			actor._fire_shot(target)
			check(near.hp==near.max_hp,prefix+"no chain without card")
			clear_units();continue
		check(idx>=0 and actor.use_ability(idx),"legendary W casts rank "+str(rank))
		check(not actor.use_ability(idx),"cannot bypass cooldown")
		check(is_equal_approx(actor.skills[idx].cd_left,float([40,38,36,34][rank])),"legendary rank cooldown")
		actor.skill_power=10
		Reserve.tick(actor,100)
		actor._fire_shot(target)
		var branch:float=[5,18,32,67][rank]
		check(target.max_hp-target.hp==[125,150,162,168][rank],"card strengthens primary; reserve remains primary only "+str(rank))
		check(near.max_hp-near.hp==branch and second.max_hp-second.hp==branch,"branch fraction follows strengthened primary at rank "+str(rank))
		check(third.hp==third.max_hp and friendly.hp==friendly.max_hp and air.hp==air.max_hp,"two-neighbor cap, no friendly or air hit")
		check(actor.special[Cards.STATE].remaining==2,"first hit consumes one chain charge")
		var previous:float=target.hp
		for i in 3: actor._fire_shot(target)
		check(previous-target.hp==[150,170,180,184][rank],"two remaining empowered primaries then normal fourth shot "+str(rank))
		var ordinary_branch:float=[5,15,25,50][rank]
		check(actor.special.has(Cards.STATE) and actor.special[Cards.STATE].remaining==0 and near.max_hp-near.hp==branch*3+ordinary_branch,"fourth hit still branches without primary increase; no recursive branch")
		Cards.tick(actor,7.99)
		var last_near:float=near.hp
		actor._fire_shot(target)
		check(near.hp==last_near-ordinary_branch and actor.special[Cards.STATE].remaining==0,"branch persists before eight seconds without negative charges")
		Cards.tick(actor,0.02)
		last_near=near.hp
		actor._fire_shot(target)
		check(not actor.special.has(Cards.STATE) and near.hp==last_near,"eight second expiry stops all branches")
		actor.skills[idx].cd_left=0
		actor.use_ability(idx)
		Cards.tick(actor,8.0)
		check(not actor.special.has(Cards.STATE),"chain expires after eight seconds")
		clear_units()
		# Pulse belongs to electric units; passives have their own crew/sortie tests.
		equip("SHK",Cards.PULSE,"",rank)
		actor=make("SHK","ally",Vector2(1200,1200))
		target=make("HTNK","enemy",Vector2(1260,1200))
		friendly=make("HTNK","ally",Vector2(1200,1250))
		air=make("JUMPJET","enemy",Vector2(1250,1200))
		third=make("HTNK","enemy",Vector2(1600,1200))
		var landed=make("SCHP","enemy",Vector2(1240,1200))
		landed.logistics.air_lift=0.0
		idx=UnitSkillLayout.index(actor,1)
		check(idx>=0 and actor.use_ability(idx),"electric pulse casts on Tesla Trooper")
		check(is_equal_approx(target.max_hp-target.hp,float([20,30,40,50][rank])),"pulse rank percent of SHK attack")
		check(landed.hp<landed.max_hp and landed.has_buff("electric_slow"),"landed aircraft count as ground pulse targets")
		check(is_equal_approx(target.move_speed,target._base_speed*0.75),"pulse slows ground target by 25 percent")
		check(friendly.hp==friendly.max_hp and air.hp==air.max_hp and third.hp==third.max_hp,"pulse respects radius, air and ownership")
		target._tick_skills(3.01)
		check(is_equal_approx(target.move_speed,target._base_speed),"pulse slow expires")
		clear_units()
	if mode==MatchRules.EXTENDED:
		equip("SHK",Cards.CHAIN,"",2)
		var actor=make("SHK","ally",Vector2(1200,1200))
		var target=make("HTNK","enemy",Vector2(1250,1200))
		actor.use_ability(UnitSkillLayout.index(actor,1));actor._fire_shot(target)
		Cards.tick(actor,1.25)
		var codec=BattleSaves.Snapshot.new()
		var state:Dictionary=codec.capture(battle)
		check(codec.error.is_empty(),"card state snapshot captures")
		codec.restore(battle,state)
		actor=battle.units.filter(func(u):return u.unit_id=="SHK")[0]
		check(actor.special[Cards.STATE].remaining==2 and is_equal_approx(actor.special[Cards.STATE].left,6.75),"restore keeps chain shots and duration")
		check(is_equal_approx(actor.special[Cards.STATE].primary,1.3) and is_equal_approx(actor.special[Cards.STATE].value,0.5),"restore retains new rank based main and branch values")
		actor.special[Cards.STATE].remaining=0
		actor.special[Cards.STATE].left=12.0
		Cards.restore(actor)
		check(actor.special[Cards.STATE].remaining==0 and is_equal_approx(actor.special[Cards.STATE].left,8.0),"legacy remaining duration clamps without restoring consumed empowerment")
		target=battle.units.filter(func(u):return u.side=="enemy")[0]
		check(is_equal_approx(Cards.primary_multiplier(actor,target),1.0),"restored exhausted empowerment cannot buff main attack")
		var description:=MetaProgress.Academy.skill_description(GameData.get_skill(Cards.CHAIN),2)
		check(description.contains("第四次起") and description.contains("持续 8 秒") and description.find("持续 8 秒")>description.find("不触发被动"),"description separates three main buffs from ongoing branch and ends with duration")
		check_acquisition()
	await finish()

func check_acquisition() -> void:
	var m:=MetaProgress
	m.reset_save();m.academy.card_shards=10000;m.currency.cores=100000
	for id in IDS:
		check(not m.set_unit_skill(GameData.get_skill(id).allowed_units[0],GameData.get_skill(id).type,0,id),"unowned card cannot equip "+id)
	# Common/rare cards use draws; the existing shard shop intentionally sells only epic/legend.
	m.academy.tickets=1000
	for attempt in 100:
		if m.skill_unlocked(Cards.GUARD) and m.skill_unlocked(Cards.STRIDE): break
		check(m.Academy.draw(m,10).size()==10,"real ten-card draw returns rewards")
	for i in IDS.size():
		var id:String=IDS[i]
		var card:=GameData.get_skill(id)
		var type:String=card.type
		check(card.rarity==["legend","epic","rare","common"][i],"four requested rarities "+id)
		check(m.skill_draw_candidates().has(card),"card included in real draw candidates "+id)
		if card.rarity in ["legend","epic"] and not m.skill_unlocked(id):
			check(m.Academy.purchase(m,"redeem",id),"shard redemption uses real catalog "+id)
		check(m.skill_unlocked(id),"real pool or redemption unlocks "+id)
		for rank in 3:check(m.Academy.purchase(m,"level",id),"upgrade actual owned card "+id+str(rank))
		for uid in card.allowed_units: check(m.set_unit_skill(uid,type,0,id),"eligible unit equips owned card "+uid+id)
		check(not m.set_unit_skill("E1",type,0,id),"unrelated unit cannot equip "+id)
		for rank in 4:
			var text:=m.Academy.skill_description(card,rank)
			check(not text.contains("{") and text.begins_with("Lv.%d"%rank),"resolved rank description "+id+str(rank))
	m.unlocked_skills.clear();m.load_save()
	for id in IDS:check(m.skill_unlocked(id) and m.Academy.card_rank(m,id)==3,"ownership and rank persist "+id)
	var gallery=preload("res://scripts/ui/faction_card_gallery.gd").new()
	add_child(gallery)
	for id in IDS:
		var index:int=gallery.ids.find(id)
		for rank in 4:
			gallery.select_card(index,rank)
			check(gallery.stage.card==gallery.ids[index] and gallery.stage.magnitude>0 and not gallery.summary.text.contains("{"),"all new card demos and ranks "+str(index)+str(rank))
	gallery.free()
