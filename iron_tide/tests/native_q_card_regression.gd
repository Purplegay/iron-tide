extends "res://tests/base_recovery_regression.gd"

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
	await get_tree().process_frame
	MetaProgress.reset_save()
	start(MatchRules.EXTENDED)
	for id in GameData.unit_index:
		check(not GameData.is_gacha_skill(UnitSkillLayout.primary_id(id)),"Q never grants a lottery card "+id)
	for id in ["MTNK","TNKD","SREF","E1","ORCA","CMIN"]:
		var unit=battle.spawn_unit(id,"ally",Vector2(1200,900))
		check(UnitSkillLayout.index(unit,0)==-1,"no free Q "+id)
		check(unit.skills.all(func(a):return not GameData.is_gacha_skill(a.id)),"unowned cards not injected "+id)
	check(UnitSkillLayout.primary_id("R3MIRAGE")=="allied_ra3_field" and UnitSkillLayout.primary_id("GGI")=="ggi_guard" and UnitSkillLayout.primary_id("CLEG")=="allied_chrono","native Q retained")
	var gi=battle.spawn_unit("E1","ally",Vector2(1100,900))
	check(UnitSkillLayout.info(gi,2).get("id")=="allied_deploy","GI native deployment E retained")
	check(not MetaProgress.set_unit_skill("MTNK","active",0,"ap_smoke"),"unowned smoke cannot equip W")
	MetaProgress.unlocked_skills.assign(["ap_smoke","ap_overdrive"])
	check(MetaProgress.set_unit_skill("MTNK","active",0,"ap_smoke"),"owned smoke can explicitly equip W")
	BattleRequest.freeze_combat_context()
	var grizzly=battle.spawn_unit("MTNK","ally",Vector2(1200,1000))
	var wi:=UnitSkillLayout.index(grizzly,1)
	check(UnitSkillLayout.index(grizzly,0)==-1 and wi>=0 and grizzly.skills[wi].id=="ap_smoke","equipped smoke is W only")
	grizzly.skills[wi].cd_left=7.5
	UnitSkillLayout.ensure(grizzly)
	check(grizzly.skills[wi].cd_left==7.5,"ensure preserves legitimate W cooldown")
	var codec=BattleSaves.Snapshot.new()
	codec.restore(battle,codec.capture(battle))
	grizzly=battle.units.filter(func(u):return u.unit_id=="MTNK" and UnitSkillLayout.index(u,1)>=0)[0]
	wi=UnitSkillLayout.index(grizzly,1)
	check(UnitSkillLayout.index(grizzly,0)==-1 and grizzly.skills[wi].id=="ap_smoke" and grizzly.skills[wi].cd_left==7.5,"new battle restores explicit smoke W cooldown")
	# Reproduce old snapshot with an injected free Q and a separate equipped W.
	BattleRequest.combat_context.erase("native_q_cards_removed")
	BattleRequest.combat_context.loadouts.MTNK={"active":["ap_smoke","ap_overdrive"],"passive":""}
	var overdrive:=Ability.new();overdrive.setup(GameData.get_skill("ap_overdrive"));overdrive.cd_left=9.25
	grizzly.skills.append(overdrive)
	codec.restore(battle,codec.capture(battle))
	grizzly=battle.units.filter(func(u):return u.unit_id=="MTNK" and UnitSkillLayout.find(u,"ap_overdrive")>=0)[0]
	check(UnitSkillLayout.find(grizzly,"ap_smoke")==-1 and UnitSkillLayout.index(grizzly,0)==-1,"old snapshot removes injected free Q")
	wi=UnitSkillLayout.index(grizzly,1)
	check(wi>=0 and grizzly.skills[wi].id=="ap_overdrive" and grizzly.skills[wi].cd_left==9.25,"old snapshot preserves actual W and cooldown")
	var next=battle.spawn_unit("MTNK","ally",Vector2(1400,900))
	check(UnitSkillLayout.find(next,"ap_smoke")==-1 and UnitSkillLayout.find(next,"ap_overdrive")>=0,"production after old load does not reinject Q")
	await finish()
	var legacy:=MetaProgress.to_dict().duplicate(true)
	legacy.academy.erase("native_q_cards_removed")
	legacy.unit_loadouts.MTNK={"active":["ap_smoke","ap_overdrive"],"passive":""}
	legacy.academy.hero_loadouts.MTNK=legacy.unit_loadouts.MTNK.duplicate(true)
	FileAccess.open(MetaProgress.SAVE_PATH,FileAccess.WRITE).store_string(JSON.stringify(legacy))
	MetaProgress.load_save()
	check(MetaProgress.unit_effective_loadout("MTNK").active[0]=="ap_overdrive","old profile removes legacy Q entry without replacing W")
	check(MetaProgress.academy.hero_loadouts.MTNK.active==["ap_overdrive"],"hero profile migration matches base")
	check(MetaProgress.skill_unlocked("ap_smoke"),"migration retains owned cards")
	check(MetaProgress.set_unit_skill("MTNK","active",0,"ap_smoke"),"post-migration explicit W allowed")
	MetaProgress.load_save()
	check(MetaProgress.unit_effective_loadout("MTNK").active[0]=="ap_smoke","one-time migration never removes new legitimate W")
	var ui=load("res://scenes/meta.tscn").instantiate();add_child(ui)
	ui._set_page("units");ui._unit_sel="MTNK";ui._rebuild_unit_detail()
	check(_has_empty_q(ui.unit_detail),"refit shows Q empty instead of free smoke")
	ui.free()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed}))
	get_tree().quit(failed)

func _has_empty_q(node:Node) -> bool:
	if node is Label and node.text.begins_with("Q 固有主动：暂无"):return true
	for child in node.get_children():
		if _has_empty_q(child):return true
	return false
