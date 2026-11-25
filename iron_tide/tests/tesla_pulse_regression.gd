extends "res://tests/electric_cards_regression.gd"
const Pulse=preload("res://scripts/buildings/tesla_pulse.gd")

func exercise(mode:String) -> void:
	start(mode);battle.fog=null
	BattleRequest.combat_context.bonuses=MatchRules.neutral_bonuses()
	BattleRequest.combat_context.unit_bonus={}
	check(GameData.get_skill(Cards.PULSE).allowed_units==["SHK","TTNK","TESLA"],"YR-only exact roster")
	equip("R3TESLA",Cards.PULSE,"",3)
	var ra3=make("R3TESLA","ally",Vector2(900,900))
	check(UnitSkillLayout.find(ra3,Cards.PULSE)<0,"RA3 production rejects pulse")
	var legacy:=Ability.new();legacy.setup(GameData.get_skill(Cards.PULSE),3)
	ra3.skills.append(legacy)
	check(not Cards.cast(ra3,legacy),"RA3 direct cast rejects pulse")
	Cards.restore(ra3)
	check(UnitSkillLayout.find(ra3,Cards.PULSE)<0,"legacy RA3 saved skill removed")
	clear_units()
	for rank in 4:
		equip("TESLA",Cards.PULSE,"",rank)
		var coil=battle._place_building("TESLA","ally",Vector2(1200,1200),true)
		coil._buildup_play=-1;coil.powered=false
		if mode==MatchRules.RA2:
			check(not Pulse.available(coil) and not Pulse.use(coil),"classic excludes building card")
			battle.buildings.erase(coil);coil.free();continue
		check(Pulse.available(coil),"building equips W rank "+str(rank))
		var target=make("HTNK","enemy",coil.position+Vector2(100,0))
		var friend=make("HTNK","ally",coil.position+Vector2(0,100))
		var air=make("JUMPJET","enemy",coil.position+Vector2(-100,0))
		var outside=make("HTNK","enemy",coil.position+Vector2(0,-400))
		var factory=battle._place_building("GAWEAP","enemy",coil.position+Vector2(180,0),true)
		factory._buildup_play=-1;factory.max_hp=100000;factory.hp=100000
		check(Pulse.use(coil),"coil pulse executes rank "+str(rank))
		check(is_equal_approx(target.max_hp-target.hp,floorf(float(coil.weapon.damage)*[0.4,0.6,0.8,1.0][rank])),"coil damage derives from native weapon")
		check(target.has_buff("electric_slow") and factory.hp<factory.max_hp,"ground slows and building receives damage")
		check(friend.hp==friend.max_hp and air.hp==air.max_hp and outside.hp==outside.max_hp,"no allied, air or out-of-range damage")
		check(Pulse.ability(coil).cd_left==[26,25,24,23][rank] and not Pulse.use(coil),"rank cooldown enforced")
		battle.paused=true;Pulse.tick(coil,3)
		check(Pulse.ability(coil).cd_left==[26,25,24,23][rank],"pause freezes building cooldown")
		battle.paused=false;Pulse.tick(coil,2.25)
		var left:float=Pulse.ability(coil).cd_left
		var codec=BattleSaves.Snapshot.new()
		var snapshot:Dictionary=codec.capture(battle)
		check(codec.error.is_empty(),"snapshot captures building W")
		codec.restore(battle,snapshot)
		battle.paused=false;get_tree().paused=false
		coil=battle.buildings.filter(func(b):return b.building_id=="TESLA")[0]
		check(Pulse.ability(coil).cd_left==left and int(coil.special[Pulse.STATE].rank)==rank,"snapshot restores rank and exact cooldown")
		coil.special[Pulse.STATE].left=0
		coil.under_construction=true
		check(not Pulse.use(coil),"unfinished building refuses W")
		coil.under_construction=false;coil._buildup_play=-1
		coil._prism_offline=1
		check(not Pulse.use(coil),"disabled building refuses W")
		coil._prism_offline=0;coil.powered=false
		coil.powered=true
		battle.power_low=true
		check(battle.side_power_low("ally") and not Pulse.use(coil),"unpowered coil refuses W")
		coil.powered=false
		battle.power_low=false
		# Exercise actual HUD binding, not only the adapter.
		battle.selected_building=coil
		screen.hud._rebuild_ability_bar()
		check(is_instance_valid(screen.hud._tesla_pulse_btn) and not screen.hud._tesla_pulse_btn.disabled,"selected coil exposes enabled W button")
		screen.hud._cast_ability(1)
		check(Pulse.ability(coil).cd_left>0 and screen.hud._tesla_pulse_btn.disabled,"HUD W executes and disables during cooldown")
		battle.selected_building=null
		for b in battle.buildings.duplicate():
			if b.building_id in ["TESLA","GAWEAP"] and b.global_position.distance_to(Vector2(1200,1200))<300:
				battle.buildings.erase(b);b.free()
		clear_units()
	if mode==MatchRules.EXTENDED:
		MetaProgress.academy.card_shards=10000
		if not MetaProgress.skill_unlocked(Cards.PULSE):check(MetaProgress.Academy.purchase(MetaProgress,"redeem",Cards.PULSE),"unlock card through shard shop")
		check(MetaProgress.set_unit_skill("TESLA","active",0,Cards.PULSE),"real profile permits building equip")
		check(not MetaProgress.set_unit_skill("R3TESLA","active",0,Cards.PULSE),"profile rejects RA3 equip")
		BattleRequest.freeze_combat_context()
		check(BattleRequest.unit_loadout("TESLA").active==[Cards.PULSE],"new match freezes coil loadout")
		BattleRequest.combat_context.loadouts.erase("TESLA")
		check(BattleRequest.unit_loadout("TESLA").active==[""],"old battle does not import newly equipped profile card")
		MetaProgress.load_save()
		check(MetaProgress.unit_effective_loadout("TESLA").active==[Cards.PULSE],"building loadout persists")
		var meta=preload("res://scripts/screens/meta_screen.gd").new()
		add_child(meta)
		meta._set_page("units")
		meta._unit_sel="TESLA";meta._rebuild_unit_detail()
		check("TESLA" in meta.refit_roster and meta.exclusive_cards_by_unit.TESLA.any(func(c):return c.id==Cards.PULSE),"coil included in refit roster and exclusive filter")
		check(meta.unit_detail.find_child("Demo_"+Cards.PULSE,true,false)!=null and meta.unit_detail.find_child("Growth_"+Cards.PULSE,true,false)!=null,"coil card demo and growth table exist")
		var gallery=preload("res://scripts/ui/faction_card_gallery.gd").new()
		gallery.refit_unit="TESLA";add_child(gallery)
		gallery.select_card(gallery.card_ids().find(Cards.PULSE),3)
		check(not gallery.actor_view.visible and gallery.summary.text.contains("磁暴线圈") and not gallery.summary.text.contains("RA3"),"building demo uses coil model and YR-only description")
		gallery.free();meta.free()
	await finish()
