extends "res://tests/base_recovery_regression.gd"
const Upgrade=preload("res://scripts/ui/progression_upgrade.gd")
const Loadouts=preload("res://scripts/rules/hero_loadouts.gd")
const Auto=preload("res://scripts/rules/auto_skill_loadout.gd")

func marked(control:Node) -> bool:
	if control==null:return false
	var dot:=control.get_node_or_null("UpgradeDot")
	return dot!=null and dot.visible

func choose(picker:OptionButton,id:String) -> void:
	for i in picker.item_count:
		var value=picker.get_meta("ids")[i] if picker.has_meta("ids") else picker.get_item_metadata(i)
		if value==id:
			picker.select(i);picker.item_selected.emit(i);return
	check(false,"equipment choice exists "+id)

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation") or DisplayServer.get_name()=="headless":get_tree().quit(2);return
	MetaProgress.reset_save();MetaProgress.unlocked_skills.clear()
	MetaProgress.currency.cores=0;MetaProgress.currency.credits=0
	MetaProgress.unit_talents={};MetaProgress.owned_talent_points=0
	MetaProgress.unit_loadouts={"E1":{"active":[""],"passive":""},"MTNK":{"active":[""],"passive":""}}
	MetaProgress.unit_loadouts.TESLA={"active":[""],"passive":""}
	MetaProgress.academy.hero_builds={"E1":50,"ORCA":0}
	MetaProgress.academy.hero_loadouts={"E1":{"active":[""],"passive":""}}
	var ui=load("res://scenes/meta.tscn").instantiate();ui.initial_page="units";add_child(ui);ui.set_process(false)
	ui.exclusive_filter.set_pressed_no_signal(false);ui._unit_sel="E1";ui._refresh()
	check(not Upgrade.skills("E1") and not marked(ui.tab_units_btn),"empty slots without owned compatible skills have no dots")
	check(not Upgrade.skills("invalid") and not Upgrade.skills("invalid",true),"invalid owner never alerts")
	check(MetaProgress.unlock_skill("ps_armor_plating"),"acquire vehicle-only passive")
	check(not Upgrade.skills("E1") and not marked(ui.unit_detail.find_child("EquipSlot_passive",true,false)),"incompatible skill cannot alert infantry slot")
	check(Upgrade.skill_slots("MTNK").passive and marked(ui.tab_units_btn) and marked(ui.auto_skill_all),"compatible empty vehicle passive aggregates to unit tab and auto install")
	check(Upgrade.skill_slots("TESLA").passive,"defensive building empty passive participates in installation alerts")
	check(MetaProgress.unlock_skill("ap_smoke"),"acquire compatible W skill")
	check(marked(ui.unit_detail.find_child("EquipSlot_active",true,false)) and marked(ui.unit_list.find_child("ViewUnit_E1",true,false)) and marked(ui.auto_skill_selected),"owned W highlights slot unit row and selected auto install")
	check(not marked(ui.unit_detail.find_child("EquipSlot_passive",true,false)),"active acquisition does not mark passive slot")
	var saved:=MetaProgress.to_dict().duplicate(true)
	for i in 3:ui._refresh();Upgrade.any_hero();Upgrade.any_unit_skills()
	check(saved==MetaProgress.to_dict(),"equipment dot queries and refresh do not mutate loadouts or profile")
	choose(ui.unit_detail.find_child("EquipSlot_active",true,false),"ap_smoke")
	check(MetaProgress.unit_effective_loadout("E1").active[0]=="ap_smoke" and not marked(ui.unit_detail.find_child("EquipSlot_active",true,false)),"actual ordinary picker installs W and removes slot dot immediately")
	check(not marked(ui.unit_list.find_child("ViewUnit_E1",true,false)) and not marked(ui.auto_skill_selected),"equipped ordinary unit clears row and selected action")
	check(Loadouts.effective(MetaProgress,"E1").active[0]=="" and Upgrade.skills("E1",true) and marked(ui.hero_tab),"ordinary installation leaves independent hero slot pending")
	MetaProgress.unlock_skill("ap_focus_fire")
	check(not Upgrade.skill_slots("E1").active,"extra alternative card does not nag an occupied slot")
	MetaProgress.unlock_skill("ps_hollow_point")
	check(marked(ui.unit_detail.find_child("EquipSlot_passive",true,false)) and marked(ui.auto_skill_selected),"compatible passive unlock immediately marks empty passive")
	ui.auto_skill_selected.pressed.emit()
	check(MetaProgress.unit_effective_loadout("E1").passive=="ps_hollow_point" and not Upgrade.skills("E1"),"real auto-install button fills empty passive and clears unit alert")
	ui._set_page("heroes");ui.heroes.selected="E1";ui.heroes.refresh()
	check(marked(ui.heroes.equipment.find_child("active",true,false)) and marked(ui.heroes.equipment.find_child("passive",true,false)) and marked(ui.heroes.hero_buttons.E1),"independent hero empty W and passive mark pickers and roster")
	choose(ui.heroes.equipment.find_child("active",true,false),"ap_smoke")
	check(not marked(ui.heroes.equipment.find_child("active",true,false)) and marked(ui.heroes.equipment.find_child("passive",true,false)) and marked(ui.hero_tab),"hero W installation leaves missing passive alert")
	choose(ui.heroes.equipment.find_child("passive",true,false),"ps_hollow_point")
	check(not marked(ui.heroes.hero_buttons.E1) and not marked(ui.hero_tab),"both hero slots filled clears roster and hero tab with no upgrades affordable")
	choose(ui.heroes.equipment.find_child("active",true,false),"")
	check(marked(ui.heroes.equipment.find_child("active",true,false)) and marked(ui.hero_tab),"clearing hero slot restores pending install indicator")
	check(MetaProgress.unit_effective_loadout("E1").active[0]!="","hero clearing preserves ordinary equipment")
	choose(ui.heroes.equipment.find_child("active",true,false),"ap_smoke")
	var card:String=preload("res://scripts/rules/hero_contract_pool.gd").for_hero("ORCA").cards[0]
	MetaProgress.unlock_skill(card)
	check(not Upgrade.skills("ORCA") and not Upgrade.skills("ORCA",true),"hero-only card cannot alert ordinary plane or locked hero")
	MetaProgress.academy.hero_builds.ORCA=5;Events.meta_changed.emit()
	ui.heroes.selected="ORCA";ui.heroes.refresh()
	check(Upgrade.skills("ORCA",true) and marked(ui.heroes.equipment.find_child("active",true,false)) and marked(ui.heroes.hero_buttons.ORCA),"hero unlock enables compatible exclusive installation alert")
	choose(ui.heroes.equipment.find_child("active",true,false),card)
	check(not Upgrade.skill_slots("ORCA",true).active and marked(ui.heroes.equipment.find_child("passive",true,false)),"exclusive W installation clears W but retains compatible air passive reminder")
	choose(ui.heroes.equipment.find_child("passive",true,false),"ps_hollow_point")
	check(not Upgrade.skills("ORCA",true) and not marked(ui.hero_tab),"both hero plane slots installed clear hero tab")
	ui._set_page("units");ui.auto_skill_all.pressed.emit()
	check(not Upgrade.any_unit_skills() and not marked(ui.tab_units_btn) and not marked(ui.auto_skill_all),"all-unit auto install clears complete ordinary aggregate")
	MetaProgress.save();MetaProgress.load_save();Events.meta_changed.emit()
	check(not Upgrade.any_unit_skills() and not Upgrade.skills("ORCA",true) and not marked(ui.hero_tab),"installed equipment and cleared indicators survive profile reload")
	ui._unit_sel="E1";ui._refresh()
	choose(ui.unit_detail.find_child("EquipSlot_active",true,false),"")
	check(marked(ui.tab_units_btn) and marked(ui.unit_list.find_child("ViewUnit_E1",true,false)),"ordinary unequip restores row and tab indicators")
	ui.free();await get_tree().process_frame
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"screenshots":0},"  "))
	get_tree().quit(0 if failed==0 else 1)
