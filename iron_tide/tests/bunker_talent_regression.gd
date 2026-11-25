extends "res://tests/electric_cards_regression.gd"
const Talent=preload("res://scripts/rules/bunker_talent.gd")
const Garrison=preload("res://scripts/units/civilian_orders.gd")

func exercise(mode:String) -> void:
	var m:=MetaProgress
	m.reset_save();m.currency.cores=10000
	start(mode)
	var bunker=battle._place_building("NABNKR","ally",Vector2(1200,1200),true)
	bunker._buildup_play=-1
	var resident=make("E2","ally",bunker.position+Vector2(70,0))
	resident.set_fire_stance("free");Garrison.enter(resident,bunker)
	check(resident.embarked_in==bunker,"native infantry garrisons building")
	var base:float=Garrison.bunker_range(bunker)
	var fog=preload("res://scripts/world/fog_of_war.gd").new()
	var cap:float=GameData.get_unit("GGI").deployed_weapon.range+Ra2Damage.PX_PER_CELL*0.5
	check(m.available_talent_slots("NABNKR")==1 and not m.buy_talent_slot("NABNKR",2),"only actual bunker talent grants capacity")
	var offer:=m.talent_unlock_quote("NABNKR",Talent.ID)
	var before:=m.balance("cores")
	check(not offer.is_empty() and m.unlock_unit_talent("NABNKR",Talent.ID,offer.cost),"building uses real atomic talent purchase")
	check(m.balance("cores")==before-offer.cost and m.unassigned_talent_points()==0,"unlock pays exact fee and allocates one point")
	for rank in 4:
		if rank>0:check(m.upgrade_talent("NABNKR",Talent.ID,rank-1),"upgrade bunker talent "+str(rank))
		m.save();m.load_save()
		check(m.talent_rank("NABNKR",Talent.ID,m.unit_talents)==rank,"new rank does not gain free levels on reload")
		BattleRequest.freeze_combat_context()
		var expected:=lerpf(base,cap,float(rank+1)/4.0) if mode==MatchRules.EXTENDED else base
		check(is_equal_approx(Garrison.bunker_range(bunker),expected),"real range matches original tier "+mode+str(rank))
		check(is_equal_approx(Garrison.weapon(resident).range,expected),"garrison weapon uses talent range")
		check(is_equal_approx(fog.vision_radius(bunker),maxf(bunker.sight,expected)),"occupied bunker vision matches range")
		if mode==MatchRules.EXTENDED:check(is_equal_approx(Talent.range_cells(rank)*Ra2Damage.PX_PER_CELL,expected),"demo equals real firing range")
	check(not m.upgrade_talent("NABNKR",Talent.ID,3),"max rank cannot purchase another level")
	m.save();m.load_save()
	check(m.talent_rank("NABNKR",Talent.ID,m.unit_talents)==3,"new four-rank profile survives reload")
	var frozen:float=Garrison.bunker_range(bunker)
	check(m.set_effect_enabled("talent",Talent.ID,"NABNKR",false),"talent toggle persists")
	check(Garrison.bunker_range(bunker)==frozen,"profile toggle does not change current match")
	BattleRequest.freeze_combat_context()
	check(is_equal_approx(Garrison.bunker_range(bunker),base),"disabled talent returns to native range in new match")
	if mode==MatchRules.EXTENDED:
		m.set_effect_enabled("talent",Talent.ID,"NABNKR",true)
		for rank in 3:
			m.unit_talents.NABNKR[Talent.ID]=rank
			BattleRequest.freeze_combat_context()
			BattleRequest.combat_context.bunker_talent_version=1
			check(is_equal_approx(Garrison.bunker_range(bunker),lerpf(base,cap,float(rank+1)/3.0)),"saved three-rank battle retains exact range")
	# Old battle retains research even with a migrated/disabled current profile.
	BattleRequest.combat_context.erase("bunker_talent_version")
	for id in Talent.OLD_IDS:battle.production_technology.unlock(id,"ally")
	check(is_equal_approx(Garrison.bunker_range(bunker),cap if mode==MatchRules.EXTENDED else base),"legacy battle research remains independent")
	check(BattleSaves.save_slot(battle,"slot1").ok,"save actual legacy battle file")
	BattleRequest.freeze_combat_context()
	check(BattleSaves.prepare_load("slot1").ok,"restore old battle context through public entry")
	BattleSaves.restore_pending(battle)
	bunker=battle.buildings.filter(func(b):return b.building_id=="NABNKR")[0]
	check(is_equal_approx(Garrison.bunker_range(bunker),cap if mode==MatchRules.EXTENDED else base),"legacy snapshot restores original range")
	battle.paused=false;get_tree().paused=false
	fog.free()
	await finish()
	if mode!=MatchRules.EXTENDED:return
	for tier in [1,2,3]:
		for disabled in [false,true]:
			m.reset_save();m.currency.cores=1234;m.owned_talent_points=3
			m.academy.erase("bunker_optics_four_ranks")
			for i in tier:m.unlocked_technologies.append(Talent.OLD_IDS[i])
			if disabled:m.disabled_effects["tech//bunker_optics_1"]=true
			check(m.save(),"seed legacy profile")
			m.load_save()
			check(m.talent_rank("NABNKR",Talent.ID,m.unit_talents)==tier and m.talent_capacity("NABNKR")==1,"paid research preserves or improves range and slot")
			check(m.balance("cores")==1234 and m.unassigned_talent_points()==3,"migration charges nothing and preserves unassigned points")
			check(m.effect_enabled("talent",Talent.ID,"NABNKR")==not disabled,"disabled legacy research stays disabled")
			m.load_save()
			check(m.owned_talent_points==4 and m.balance("cores")==1234,"repeated load does not duplicate migration grants")
			check(m.researched_count()==tier,"old research-count receipts survive")
	for old_rank in 3:
		m.reset_save();m.academy.erase("bunker_optics_four_ranks")
		m.academy.bunker_optics_migrated=true
		m.unit_talents={"NABNKR":{Talent.ID:old_rank}};m.talent_slots={"NABNKR":1};m.owned_talent_points=1
		m.save();m.load_save();m.load_save()
		check(m.talent_rank("NABNKR",Talent.ID,m.unit_talents)==old_rank+1,"three-rank talent profile upgrades once")
	var meta=preload("res://scripts/screens/meta_screen.gd").new();add_child(meta)
	meta._set_page("units");meta._unit_sel="NABNKR";meta._rebuild_unit_detail()
	check("NABNKR" in meta.refit_roster and meta._has_exclusive_progression("NABNKR"),"bunker appears in exclusive talent refit filter")
	check(meta.unit_detail.find_child("Enable_"+Talent.ID,true,false)!=null,"talent enable switch exists")
	meta._show_talent_demo("NABNKR",Talent.ID,3)
	check(meta.has_node("TalentDemo"),"building-specific range preview opens")
	meta.free()
	var tree=preload("res://scripts/ui/technology_tree.gd").new();add_child(tree)
	for id in Talent.OLD_IDS:
		check(not tree.cards.has(id) and not m.research_technology(id),"retired research has no UI or purchase entry")
	tree.free()
