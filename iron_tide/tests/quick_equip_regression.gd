extends "res://tests/electric_cards_regression.gd"

func exercise(mode:String) -> void:
	if mode==MatchRules.RA2:return
	BattleRequest.rules_mode=mode
	var m:=MetaProgress
	m.reset_save()
	var meta=preload("res://scripts/screens/meta_screen.gd").new();add_child(meta)
	meta.size=Vector2(1280,720)
	meta._set_page("units");meta._unit_sel="DEST";meta._rebuild_unit_detail()
	var locked:Button=meta.unit_detail.find_child("QuickEquip_ap_buoy",true,false)
	check(locked!=null and locked.disabled,"unowned card has disabled quick equip")
	meta._quick_equip_card("DEST","ap_buoy")
	check(m.unit_effective_loadout("DEST").active[0]!="ap_buoy","unowned handler cannot bypass ownership")
	for id in ["ap_buoy","ps_contact","ap_tesla_chain","ap_shock_pulse"]:
		if id not in m.unlocked_skills:m.unlocked_skills.append(id)
	m.save();meta._rebuild_unit_detail()
	for frame in 4:await get_tree().process_frame
	var scroll:ScrollContainer=meta.unit_detail.get_parent()
	scroll.scroll_vertical=120
	var original_scroll:int=scroll.scroll_vertical
	check(original_scroll>0,"detail page can scroll before quick equip")
	var wallet:=m.currency.duplicate(true)
	for id in ["ap_buoy","ps_contact"]:
		var button:Button=meta.unit_detail.find_child("QuickEquip_"+id,true,false)
		check(button!=null and not button.disabled,"owned card quick equip available "+id)
		button.pressed.emit()
		for frame in 4:await get_tree().process_frame
		check(scroll.scroll_vertical==original_scroll,"quick equip preserves scroll position "+id)
		var installed:Button=meta.unit_detail.find_child("QuickEquip_"+id,true,false)
		check(installed.disabled and installed.text.begins_with("已装配"),"quick equip refreshes installed state "+id)
	check(m.unit_effective_loadout("DEST")=={"active":["ap_buoy"],"passive":"ps_contact"},"W and passive equipped independently")
	check(meta._unit_sel=="DEST" and meta._page=="units","quick equip stays on selected unit page")
	meta._unit_sel="SHK";meta._rebuild_unit_detail()
	meta.unit_detail.find_child("QuickEquip_ap_tesla_chain",true,false).pressed.emit()
	meta.unit_detail.find_child("QuickEquip_ap_shock_pulse",true,false).pressed.emit()
	check(m.unit_effective_loadout("SHK").active==["ap_shock_pulse"],"new W replaces previous W")
	check(not meta.unit_detail.find_child("QuickEquip_ap_tesla_chain",true,false).disabled,"replaced card can be equipped again")
	check(m.skill_unlocked("ap_tesla_chain"),"replacement preserves ownership")
	meta._unit_sel="TESLA";meta._rebuild_unit_detail()
	meta.unit_detail.find_child("QuickEquip_ap_shock_pulse",true,false).pressed.emit()
	check(m.unit_effective_loadout("TESLA").active==["ap_shock_pulse"],"building card quick equip supported")
	meta._quick_equip_card("E1","ap_shock_pulse")
	check(m.unit_effective_loadout("E1").active[0]!="ap_shock_pulse","wrong unit rejected")
	check(m.currency==wallet,"quick equip has no currency cost")
	meta.free();m.load_save()
	check(m.unit_effective_loadout("DEST")=={"active":["ap_buoy"],"passive":"ps_contact"} and m.unit_effective_loadout("TESLA").active==["ap_shock_pulse"],"quick equipment survives reload")
