extends "res://tests/base_recovery_regression.gd"
const Auto = preload("res://scripts/rules/auto_skill_loadout.gd")
var notifications := 0
var changed_ids: Array = []

func meta_event() -> void:
	notifications += 1

func loadout_event(id: String) -> void:
	changed_ids.append(id)

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2);return
	await get_tree().process_frame
	if "--cold-auto-skills" in OS.get_cmdline_user_args():
		cold_profile()
		write_result("cold-result.json");return
	MetaProgress.reset_save()
	MetaProgress.unlocked_skills.assign(["ap_smoke","ap_overdrive","ap_focus_fire","ps_armor_plating","ps_hollow_point"])
	MetaProgress.unit_loadouts={"MTNK":{"active":["ap_smoke"],"passive":""}}
	MetaProgress.save()
	Events.meta_changed.connect(meta_event)
	Events.meta_loadout_changed.connect(loadout_event)
	var currency:=MetaProgress.currency.duplicate(true)
	var unlocks:=MetaProgress.unlocked_skills.duplicate()
	var heroes:Dictionary=MetaProgress.academy.hero_loadouts.duplicate(true)
	var initial:=MetaProgress.unit_loadouts.duplicate(true)
	var plan:=Auto.plan(MetaProgress,["MTNK"])
	check(plan.ok and MetaProgress.unit_loadouts==initial,"planning does not mutate equipment")
	check(plan.changes.MTNK.active==["ap_smoke"] and plan.changes.MTNK.passive=="ps_armor_plating","equal priority keeps equipped W and fills suitable passive")
	var result:=MetaProgress.auto_configure_unit_skills(["MTNK","MTNK"])
	check(result.ok and result.changed==1 and result.total==1 and changed_ids==["MTNK"] and notifications==1,"single-unit operation deduplicates and emits one saved change")
	check(MetaProgress.unit_loadouts.size()==1,"single-unit operation leaves other types untouched")
	result=MetaProgress.auto_configure_unit_skills(["MTNK"])
	check(result.ok and result.changed==0 and notifications==1,"repeat operation is idempotent")
	MetaProgress.academy.get_or_add("levels",{}).ap_overdrive=3
	result=MetaProgress.auto_configure_unit_skills(["MTNK"])
	check(result.ok and MetaProgress.unit_effective_loadout("MTNK").active==["ap_overdrive"],"higher level wins within same rarity")
	MetaProgress.unlock_skill("ap_slope")
	result=MetaProgress.auto_configure_unit_skills(["HTNK"])
	check(result.ok and MetaProgress.unit_effective_loadout("HTNK").active==["ap_slope"],"owned exclusive wins for its intended tank")
	MetaProgress.unlock_skill("ps_phase")
	result=MetaProgress.auto_configure_unit_skills(["R3MIRAGE"])
	check(result.ok and MetaProgress.unit_effective_loadout("R3MIRAGE").passive=="ps_phase","higher rarity wins among compatible passive cards")
	MetaProgress.unlock_skill("ap_furnace_bastion")
	result=MetaProgress.auto_configure_unit_skills(["E2"])
	check(result.ok and MetaProgress.unit_effective_loadout("E2").active!=["ap_furnace_bastion"],"hero-only card is never assigned to ordinary infantry")
	check(MetaProgress.currency==currency and MetaProgress.academy.hero_loadouts==heroes,"auto configuration charges nothing and preserves independent hero slots")
	initial=MetaProgress.unit_loadouts.duplicate(true)
	result=MetaProgress.auto_configure_unit_skills(["E1","invalid-unit"])
	check(not result.ok and MetaProgress.unit_loadouts==initial,"invalid batch rejected before applying any item")
	var saved_text:=FileAccess.get_file_as_string(MetaProgress.SAVE_PATH)
	var before_notifications:=notifications
	DirAccess.make_dir_absolute(MetaProgress.SAVE_PATH+".tmp")
	result=MetaProgress.auto_configure_unit_skills(["E1","TESLA"])
	check(not result.ok and result.reason=="save_failed" and MetaProgress.unit_loadouts==initial,"failed batch save rolls back all in-memory loadouts")
	check(notifications==before_notifications and FileAccess.get_file_as_string(MetaProgress.SAVE_PATH)==saved_text,"failed batch preserves disk profile and emits no successful change")
	DirAccess.remove_absolute(MetaProgress.SAVE_PATH+".tmp")
	var ui=load("res://scenes/meta.tscn").instantiate();ui.initial_page="units";add_child(ui);ui.set_process(false)
	ui.exclusive_filter.set_pressed_no_signal(false)
	ui._unit_filter="";ui._unit_sel="";ui._rebuild_unit_list();ui._rebuild_unit_detail()
	check(ui.auto_skill_selected.disabled and not ui.auto_skill_all.disabled,"toolbar disables current-unit action until a type is selected")
	ui._unit_sel="E1";ui._rebuild_unit_list();ui._rebuild_unit_detail()
	initial=MetaProgress.unit_loadouts.duplicate(true)
	ui.auto_skill_selected.pressed.emit()
	check(not ui.auto_skill_selected.disabled and MetaProgress.unit_effective_loadout("E1").passive=="ps_hollow_point","real current-type button equips selected infantry")
	check(MetaProgress.unit_loadouts.get("TESLA",{})==initial.get("TESLA",{}),"current-type button does not configure other types")
	ui._unit_filter="allied";ui._rebuild_unit_list();ui._rebuild_unit_detail()
	currency=MetaProgress.currency.duplicate(true);unlocks=MetaProgress.unlocked_skills.duplicate()
	ui.auto_skill_all.pressed.emit()
	check(MetaProgress.unit_effective_loadout("TESLA").passive=="ps_armor_plating" and MetaProgress.unit_effective_loadout("E2").passive=="ps_hollow_point","all-types button covers defenses and Soviet units despite Allied filter")
	check(ui.refit_roster==Auto.roster(),"UI and bulk operation share the same authoritative roster")
	for id: String in Auto.roster():
		var lo:=MetaProgress.unit_effective_loadout(id)
		check(lo.active.size()==1,"one W slot "+id)
		for pair in [["active",str(lo.active[0])],["passive",str(lo.passive)]]:
			var skill:String=pair[1]
			check(skill.is_empty() or (MetaProgress.skill_unlocked(skill) and UnitSkillLayout.compatible(id,skill) and GameData.get_skill(skill).type==pair[0] and (pair[0]!="active" or UnitSkillLayout.equippable(id,skill))),"bulk eligible owned "+id+" "+pair[0])
	check(MetaProgress.currency==currency and MetaProgress.unlocked_skills==unlocks and MetaProgress.academy.hero_loadouts==heroes,"bulk operation preserves currencies, ownership and hero equipment")
	var desired:=MetaProgress.unit_loadouts.duplicate(true)
	ui.auto_skill_all.pressed.emit()
	check(MetaProgress.unit_loadouts==desired and ui.auto_skill_result.text.contains("无需调整"),"bulk repeat leaves equipment stable and reports no changes")
	await get_tree().process_frame
	check(ui.auto_skill_selected.is_visible_in_tree() and ui.auto_skill_all.get_global_rect().end.x<=get_viewport().get_visible_rect().end.x,"auto actions are visible and fit the viewport")
	ui.free()
	MetaProgress.load_save()
	check(MetaProgress.unit_loadouts==desired,"all equipment survives profile reload")
	var output:Array=[]
	var code:=OS.execute(OS.get_executable_path(),["--headless","--path",ProjectSettings.globalize_path("res://"),"res://tests/auto_skill_loadout_regression.tscn","--","--cold-auto-skills"],output,true)
	check(code==0,"fresh process restores automatic equipment",output if code!=0 else null)
	start(MatchRules.EXTENDED)
	var actor=battle.spawn_unit("MTNK","ally",Vector2(1200,1200))
	check(UnitSkillLayout.index(actor,1)>=0 and actor.skills[UnitSkillLayout.index(actor,1)].id=="ap_overdrive" and actor.passive.id=="ps_armor_plating","new extended battle consumes automatic W and passive")
	var frozen:=BattleRequest.combat_context.duplicate(true)
	MetaProgress.academy.levels.ap_smoke=3
	MetaProgress.set_unit_skill("MTNK","active",0,"ap_smoke")
	MetaProgress.auto_configure_unit_skills(["MTNK"])
	check(BattleRequest.combat_context==frozen and actor.skills[UnitSkillLayout.index(actor,1)].id=="ap_overdrive","profile reconfiguration does not rewrite active battle snapshot")
	var codec=BattleSaves.Snapshot.new();var snapshot:Dictionary=codec.capture(battle)
	check(codec.error.is_empty(),"auto-equipped battle serializes")
	codec.restore(battle,snapshot);battle.paused=false;get_tree().paused=false
	actor=battle.units.filter(func(u):return u.unit_id=="MTNK" and u.side=="ally")[0]
	check(actor.skills[UnitSkillLayout.index(actor,1)].id=="ap_overdrive" and actor.passive.id=="ps_armor_plating","battle restore retains frozen automatic equipment")
	await finish()
	start(MatchRules.RA2)
	actor=battle.spawn_unit("MTNK","ally",Vector2(1200,1200))
	check(UnitSkillLayout.index(actor,1)==-1 and actor.passive.is_empty(),"classic mode still ignores equipped extension cards")
	await finish()
	write_result("result.json")

func cold_profile() -> void:
	check(MetaProgress.unit_effective_loadout("HTNK").active==["ap_slope"],"cold profile keeps tank-exclusive choice")
	check(MetaProgress.unit_effective_loadout("TESLA").passive=="ps_armor_plating","cold profile keeps defense equipment")
	check(MetaProgress.auto_configure_unit_skills(Auto.roster()).changed==0,"cold batch remains deterministic and idempotent")

func write_result(name: String) -> void:
	FileAccess.open(output_dir.path_join(name),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	get_tree().quit(0 if failed==0 else 1)
