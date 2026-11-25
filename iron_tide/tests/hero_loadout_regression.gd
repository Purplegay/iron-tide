extends "res://tests/base_recovery_regression.gd"
const Loadouts=preload("res://scripts/rules/hero_loadouts.gd")
const Academy=preload("res://scripts/rules/academy.gd")

func check_outfit(actor, hero: bool, equipped: bool, stage: String) -> void:
	var id: String = actor.unit_id
	var normal_skin: String = MetaProgress.unit_cosmetics[id].skin
	var expected: int = MetaProgress.Cosmetics.SKIN_MATERIALS[normal_skin]
	if hero:
		expected = (10 if id == "MTNK" else 11) if equipped and id in Unit.TankHero.IDS else 0
	var actual: int = int(actor.material.get_shader_parameter("unit_skin")) if actor.material != null else 0
	check(actual == expected and (actor.tank_finish != null) == (expected in [4,5]),stage+" "+id+" uses only its own material and effects")
	if hero: check(bool(actor.special.get("hero_skin",false)) == equipped and actor.cosmetic_outfit().is_empty(),stage+" "+id+" retains independent hero appearance")

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
	await get_tree().process_frame
	MetaProgress.reset_save()
	MetaProgress.unlocked_skills.assign(["ap_smoke","ap_overdrive","ap_focus_fire","ps_armor_plating","ps_hollow_point"])
	MetaProgress.unit_loadouts={"E1":{"active":["ap_smoke"],"passive":"ps_hollow_point"}}
	var old:=MetaProgress.to_dict().duplicate(true)
	old.academy.erase("hero_loadouts")
	FileAccess.open(MetaProgress.SAVE_PATH,FileAccess.WRITE).store_string(JSON.stringify(old))
	MetaProgress.load_save()
	check(Loadouts.effective(MetaProgress,"E1")==MetaProgress.unit_effective_loadout("E1"),"old profile copies base equipment once")
	check(Loadouts.equip(MetaProgress,"E1","active","ap_focus_fire"),"hero equips owned W")
	check(Loadouts.equip(MetaProgress,"E1","passive",""),"hero clears passive independently")
	check(MetaProgress.unit_effective_loadout("E1").passive=="ps_hollow_point" and MetaProgress.unit_effective_loadout("E1").active[0]=="ap_smoke","hero changes leave normal soldier intact")
	MetaProgress.save();MetaProgress.load_save()
	check(Loadouts.effective(MetaProgress,"E1").active[0]=="ap_focus_fire" and Loadouts.effective(MetaProgress,"E1").passive=="","independent cleared slot survives reload")
	check(not Loadouts.equip(MetaProgress,"E1","passive","ps_armor_plating"),"hero obeys infantry eligibility")
	check(not Loadouts.equip(MetaProgress,"E1","active","ap_slope"),"wrong-unit exclusive card rejected")
	check(not Loadouts.equip(MetaProgress,"MTNK","active","ap_bayonet"),"unowned card rejected")
	check(not Loadouts.equip(MetaProgress,"GGI","active","ap_smoke"),"nonhero ID rejected")
	var saved:=MetaProgress.academy.duplicate(true)
	DirAccess.make_dir_absolute(MetaProgress.SAVE_PATH+".tmp")
	check(not Loadouts.equip(MetaProgress,"E1","active","ap_smoke") and MetaProgress.academy==saved,"save failure rolls back hero equipment")
	DirAccess.remove_absolute(MetaProgress.SAVE_PATH+".tmp")
	for id in Academy.LEGACY_HEROES:
		var infantry:bool=id in ["E1","E2"]
		MetaProgress.unit_cosmetics[id]={"skin":{"MTNK":"cobalt_porcelain","HTNK":"ember_steel"}.get(id,"winter")}
		MetaProgress.academy.get_or_add("hero_skin",{})[id]=id in ["HTNK","E2"]
		MetaProgress.unit_levels[id]={"atk":7,"def":5}
		MetaProgress.academy.get_or_add("hero_builds",{})[id]=100
		MetaProgress.academy.get_or_add("hero_training",{})[id]={"firepower":4,"health":3}
		MetaProgress.set_unit_skill(id,"active",0,"ap_smoke")
		MetaProgress.set_unit_skill(id,"passive",0,"ps_hollow_point" if infantry else "ps_armor_plating")
		Loadouts.equip(MetaProgress,id,"active","ap_focus_fire" if infantry else "ap_overdrive")
		Loadouts.equip(MetaProgress,id,"passive","")
	start(MatchRules.EXTENDED)
	for id in Academy.LEGACY_HEROES:
		var infantry:bool=id in ["E1","E2"]
		var normal=battle.spawn_unit(id,"ally",Vector2(1000,800))
		var hero=battle.spawn_unit(id,"ally",Vector2(1200,800))
		Academy.promote(MetaProgress,battle,id,hero)
		check_outfit(normal,false,false,"ordinary unit beside hero")
		check_outfit(hero,true,id in ["HTNK","E2"],"promotion")
		check(hero.special.get("academy_hero")==id and hero.passive.is_empty(),"hero no longer retains body passive "+id)
		var wi:=UnitSkillLayout.index(hero,1)
		check(wi>=0 and hero.skills[wi].id==("ap_focus_fire" if infantry else "ap_overdrive"),"hero receives independent W "+id)
		check(UnitSkillLayout.find(normal,"ap_smoke")>=0 and not normal.passive.is_empty(),"normal keeps own equipment "+id)
		var b:=BattleRequest.combat_bonuses()
		var ub:=BattleRequest.unit_bonus(id)
		check(is_equal_approx(hero._base_atk,float(b.attack_bonus)*float(ub.attack_bonus)*1.02),"hero inherits base firepower exactly once plus hero training "+id)
		check(is_equal_approx(hero._base_def,float(b.defense_bonus)*float(ub.defense_bonus)),"normal armor card not retained on hero "+id)
		check(is_equal_approx(hero._base_max_hp,normal._base_max_hp*1.0225),"hero life training retained "+id)
		if infantry:check(UnitSkillLayout.find(hero,"allied_deploy")>=0 if id=="E1" else true,"native deploy retained")
		Loadouts.equip(MetaProgress,id,"active","")
		check(BattleRequest.hero_loadout(id).active[0]==("ap_focus_fire" if infantry else "ap_overdrive"),"battle freezes hero cards "+id)
	var context:=BattleRequest.combat_context.duplicate(true)
	BattleRequest.combat_context.erase("hero_loadouts")
	check(BattleRequest.hero_loadout("E1")==BattleRequest.unit_loadout("E1"),"old battle uses frozen normal loadout")
	BattleRequest.combat_context=context
	var codec=BattleSaves.Snapshot.new()
	var snapshot:Dictionary=codec.capture(battle)
	check(codec.error.is_empty(),"hero equipment battle serializes")
	for id in Academy.LEGACY_HEROES: MetaProgress.academy.hero_skin[id]=id in ["MTNK","E1"]
	codec.restore(battle,snapshot)
	check(codec.error.is_empty(),"hero equipment battle restores")
	for hero in battle.units.filter(func(u):return u.special.has("academy_hero")):
		var wi:=UnitSkillLayout.index(hero,1)
		check_outfit(hero,true,hero.unit_id in ["HTNK","E2"],"restored hero")
		check(hero.passive.is_empty() and wi>=0 and hero.skills[wi].id==("ap_focus_fire" if hero.unit_id in ["E1","E2"] else "ap_overdrive"),"restored hero retains independent equipment")
	await finish()
	for id in Academy.LEGACY_HEROES:
		MetaProgress.set_unit_skill(id,"passive",0,"")
		Loadouts.equip(MetaProgress,id,"passive","ps_hollow_point" if id in ["E1","E2"] else "ps_armor_plating")
	start(MatchRules.EXTENDED)
	for id in Academy.LEGACY_HEROES:
		var hero=battle.spawn_unit(id,"ally",Vector2(1200,900))
		Academy.promote(MetaProgress,battle,id,hero)
		var pid:="ps_hollow_point" if id in ["E1","E2"] else "ps_armor_plating"
		check(hero.passive.get("id")==pid,"hero receives its own passive "+id)
		var factor:=1.0+float(GameData.get_skill(pid).value)*BattleRequest.card_scale(pid)
		var b:=BattleRequest.combat_bonuses()
		var ub:=BattleRequest.unit_bonus(id)
		check(is_equal_approx(hero._base_atk,float(b.attack_bonus)*float(ub.attack_bonus)*1.02*(factor if pid=="ps_hollow_point" else 1.0)),"hero own damage card stacks once with inherited growth "+id)
		check(is_equal_approx(hero._base_def,float(b.defense_bonus)*float(ub.defense_bonus)*(factor if pid=="ps_armor_plating" else 1.0)),"hero own defense card stacks once with inherited growth "+id)
		check(MetaProgress.unit_effective_loadout(id).passive.is_empty(),"hero passive does not equip base "+id)
	await finish()
	var ui=load("res://scenes/heroes.tscn").instantiate();add_child(ui)
	for id in Academy.LEGACY_HEROES:
		ui.heroes.selected=id;ui.heroes.refresh()
		var page=ui.heroes
		var equipped: bool = MetaProgress.academy.hero_skin[id]
		page.trial.button_pressed=not equipped
		check_outfit(page.preview.actor,true,not equipped,"hero try-on")
		page.outfit.pressed.emit()
		check(MetaProgress.academy.hero_skin[id]!=equipped and MetaProgress.cosmetic_style(id).has("skin"),"hero page equips independently "+id)
		page.outfit.pressed.emit()
		check_outfit(page.preview.actor,true,equipped,"restored hero preview")
		var equipment=ui.heroes.equipment
		check(equipment.unit_id==id and equipment.inheritance.text.contains("Lv.7 / 20") and equipment.inheritance.text.contains("Lv.5 / 20"),"inherited purchased levels shown "+id)
		var pick:OptionButton=equipment.find_child("active",true,false)
		var chosen:="ap_overdrive" if id=="MTNK" else "ap_smoke"
		for i in pick.item_count:
			if pick.get_item_metadata(i)==chosen:pick.select(i);pick.item_selected.emit(i);break
		check(Loadouts.effective(MetaProgress,id).active[0]==chosen,"hero UI writes independent slot "+id)
		var passive_picker:OptionButton=equipment.find_child("passive",true,false)
		passive_picker.select(0);passive_picker.item_selected.emit(0)
		check(Loadouts.effective(MetaProgress,id).passive.is_empty(),"hero UI clears only own passive "+id)
	ui.free()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed}))
	get_tree().quit(failed)
