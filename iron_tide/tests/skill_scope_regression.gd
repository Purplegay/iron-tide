extends "res://tests/electric_cards_regression.gd"
const Scope=preload("res://scripts/rules/skill_scope.gd")
const Icon=preload("res://scripts/ui/progression_icon.gd")
const BuildingCard=preload("res://scripts/buildings/tesla_pulse.gd")
const MATRIX={"ap_smoke":["infantry","vehicle"],"ap_overdrive":["vehicle","air"],"ap_focus_fire":["infantry","defense"],"ps_armor_plating":["vehicle","defense"],"ps_hollow_point":["infantry","air"]}

func exercise(mode:String) -> void:
	start(mode);battle.fog=null
	BattleRequest.combat_context.bonuses=MatchRules.neutral_bonuses();BattleRequest.combat_context.unit_bonus={}
	var pool:=MetaProgress.skill_draw_candidates()
	for id in MATRIX:
		var card:=GameData.get_skill(id)
		check(card.unlock=="gacha" and card.rarity=="common" and pool.has(card),"ordinary category card remains drawable "+id)
		for sample in {"E1":"infantry","HTNK":"vehicle","ORCA":"air","JUMPJET":"air","TESLA":"defense","GAPOWR":"building","DEST":"naval"}:
			var kind:String={"E1":"infantry","HTNK":"vehicle","ORCA":"air","JUMPJET":"air","TESLA":"defense","GAPOWR":"building","DEST":"naval"}[sample]
			check(Scope.category(sample)==kind,"classification "+sample)
			check(UnitSkillLayout.compatible(sample,id)==(kind in MATRIX[id]),"equipment scope "+sample+id)
		check(MetaProgress.Academy.skill_description(card,2).contains("适用："),"dynamic description includes scope "+id)
	for card in pool:
		check(Icon.PATHS.has(card.get("scope_icon","")),"every current card declares semantic icon "+card.id)
		check(Icon.texture(card.id)!=null,"every current card icon renders "+card.id)
	check(GameData.get_skill("ps_phase").scope_icon=="hightech" and GameData.get_skill("ap_shock_pulse").scope_icon=="electric","high tech and electrical contexts distinct")
	check(UnitSkillLayout.normalize("ORCA",{"active":["ap_smoke"],"passive":"ps_armor_plating"})=={"active":[""],"passive":""},"legacy incompatible equipment filtered")
	check(UnitSkillLayout.compatible("NAFLAK","ps_barrage") and UnitSkillLayout.compatible("TESLA",Cards.PULSE) and not UnitSkillLayout.compatible("R3TESLA",Cards.PULSE),"exclusive exact rosters preserved")
	for rank in 4:
		BattleRequest.combat_context.loadouts.TESLA={"active":["ap_focus_fire"],"passive":"ps_armor_plating"}
		BattleRequest.combat_context.card_ranks["ap_focus_fire"]=rank
		BattleRequest.combat_context.card_ranks["ps_armor_plating"]=rank
		var coil=battle._place_building("TESLA","ally",Vector2(1200,1200),true)
		coil._buildup_play=-1;coil.powered=false;coil.max_hp=10000;coil.hp=10000
		if mode==MatchRules.RA2:
			check(not BuildingCard.available(coil) and not coil.special.has("card_armor"),"classic ignores category cards")
		else:
			var power:=1+0.15*rank
			check(BuildingCard.available(coil) and BuildingCard.card_id(coil)=="ap_focus_fire","defense equips focus W")
			var reduction:float=[0.2,0.25,0.3,0.35][rank]
			check(BuildingCard.use(coil) and is_equal_approx(BuildingCard.reload_multiplier(coil),1-reduction),"defense focus reload multiplier "+str(rank))
			check(is_equal_approx(BuildingCard.reload_duration(coil),maxf(0,coil.cooldown-float(coil.data.get("fire_delay",0)))*(1-reduction)),"defense focus preserves windup and shortens reload "+str(rank))
			coil.receive_hit(112)
			check(is_equal_approx(10000-coil.hp,floorf(112/(1+0.12*power))),"armor reduces actual building damage "+str(rank))
			var target=make("HTNK","enemy",Vector2(1300,1200));coil.attack_target=target
			var before:float=target.hp;coil._fire();var boosted:float=before-target.hp
			BuildingCard.tick(coil,6.1);before=target.hp;coil._fire();var plain:float=before-target.hp
			check(plain>0 and is_equal_approx(boosted,plain) and is_equal_approx(BuildingCard.reload_multiplier(coil),1),"focus keeps turret hit damage and expires "+str(rank))
			battle.selected_building=coil;screen.hud._rebuild_ability_bar()
			check(screen.hud._tesla_pulse_btn.text.contains("聚焦射击") and screen.hud.ability_box.find_child("BuildingCardPassive",true,false)!=null,"HUD shows correct W and armor icon")
			var codec=BattleSaves.Snapshot.new();var snapshot:Dictionary=codec.capture(battle)
			check(codec.error.is_empty(),"building cards serialize")
			codec.restore(battle,snapshot);battle.paused=false;get_tree().paused=false
			coil=battle.buildings.filter(func(b):return b.building_id=="TESLA" and b.position==Vector2(1200,1200))[0]
			check(BuildingCard.card_id(coil)=="ap_focus_fire" and coil.special.card_armor>0 and BuildingCard.ability(coil).cd_left>0,"building cards restore cooldown and passive")
		battle.selected_building=null;battle.buildings.erase(coil);coil.free();clear_units()
	if mode==MatchRules.EXTENDED:
		BattleRequest.combat_context.loadouts.NABNKR={"active":["ap_focus_fire"],"passive":"ps_armor_plating"}
		BattleRequest.combat_context.card_ranks.ap_focus_fire=0
		var bunker=battle._place_building("NABNKR","ally",Vector2(1600,1200),true);bunker._buildup_play=-1
		var resident=make("E1","ally",Vector2(1600,1200));var foe=make("E1","enemy",Vector2(1700,1200))
		var garrison=preload("res://scripts/units/civilian_orders.gd")
		garrison.enter(resident,bunker);resident.fire_stance="guard";bunker.attack_target=foe
		resident._cd_timer=0;var prior:float=foe.hp;garrison.tick(resident,0);var baseline:float=prior-foe.hp
		check(resident.embarked_in==bunker and baseline>0,"garrison starts normal weapon fire")
		check(BuildingCard.use(bunker),"bunker focus W activates")
		resident._cd_timer=0;prior=foe.hp;var original:Dictionary=resident.bonuses.duplicate(true);garrison.tick(resident,0)
		check(is_equal_approx(prior-foe.hp,baseline) and resident.bonuses==original and is_equal_approx(resident._cd_timer,garrison.weapon(resident).cooldown*0.8),"bunker focus shortens occupant reload without increasing shot damage")
		battle.selected_building=bunker;screen.hud._rebuild_ability_bar()
		check(screen.hud.ability_box.find_child("Occupant*",true,false)!=null and screen.hud._tesla_pulse_btn!=null,"bunker keeps evacuation portraits alongside W")
		battle.selected_building=null;clear_units();battle.buildings.erase(bunker);bunker.free()
		MetaProgress.unlock_skill("ap_focus_fire");MetaProgress.unlock_skill("ps_armor_plating")
		check(MetaProgress.set_unit_skill("TESLA","active",0,"ap_focus_fire") and MetaProgress.set_unit_skill("TESLA","passive",0,"ps_armor_plating"),"profile equips both building slots")
		BattleRequest.freeze_combat_context()
		check(BattleRequest.unit_loadout("TESLA").passive=="ps_armor_plating","defense loadout frozen for battle")
		BattleRequest.combat_context.loadouts.erase("TESLA")
		check(BattleRequest.unit_loadout("TESLA").passive=="","old battle does not import later profile equipment")
		var meta=preload("res://scripts/screens/meta_screen.gd").new();add_child(meta);meta._set_page("units")
		for id in GameData.building_index:
			if Scope.defense(id):check(id in meta.refit_roster,"defense appears in refit "+id)
		meta._unit_sel="TESLA";meta._rebuild_unit_detail()
		check(meta.unit_detail.get_child_count()>3,"defense refit renders both slots")
		meta.free()
	await finish()
