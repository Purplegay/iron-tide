extends "res://tests/base_recovery_regression.gd"
const Preview = preload("res://scripts/world/attack_range_preview.gd")

func choose(army: Array) -> void:
	battle.clear_selection()
	for u in army: battle.select_unit(u, true)
	battle._emit_selection()

func tile(id: String):
	for entry in screen.hud._strip_icons:
		if entry.icon.data.id == id: return entry.icon
	return null

func click(icon, button := MOUSE_BUTTON_LEFT, double := false) -> void:
	var event := InputEventMouseButton.new()
	event.pressed = true
	event.button_index = button
	event.double_click = double
	icon.gui_input.emit(event)

func _ready() -> void:
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not ProjectSettings.get_setting("application/config/use_custom_user_dir", false):
		get_tree().quit(2)
		return
	for mode in [MatchRules.RA2, MatchRules.EXTENDED]:
		start(mode)
		var hud = screen.hud
		var army: Array = []
		for i in 77:
			var id: String = "E1" if i < 50 else "GGI" if i < 75 else "SREF"
			army.append(battle.spawn_unit(id, "ally", Vector2(1000 + (i % 10) * 30, 1000 + floori(i / 10.0) * 30)))
		var outside = battle.spawn_unit("E1", "ally", Vector2(1300,1300))
		choose(army.slice(0,16))
		check(hud.sel_strip_box.get_child_count() == 16 and not hud._strip_grouped, mode + ": sixteen keeps individual portraits")
		choose(army.slice(0,17))
		check(hud.sel_strip_box.get_child_count() == 1 and tile("E1").count == 17, mode + ": seventeen merges by type")
		choose(army)
		check(hud.sel_strip_box.get_child_count() == 3 and tile("E1").count == 50 and tile("GGI").count == 25 and tile("SREF").count == 2, mode + ": seventy-seven actors become three counted frames")
		check("已选部队 77" in hud.sel_strip_title.text and battle.selected_units.size() == 77, mode + ": summary and orders retain full army")
		check(hud._strip_unit_count == 77 and hud._strip_icons.all(func(e): return not e.icon.is_processing() and e.icon.show_count), mode + ": aggregation retains large-selection throttle and static portraits")
		check(Preview.ranges(battle).size() == 3, mode + ": distinct weapon ranges remain unchanged")
		var first = tile("E1")
		var move_button = hud.cmd_buttons.move
		for i in 8: hud._rebuild_selection_strip()
		check(tile("E1") == first and hud.cmd_buttons.move == move_button, mode + ": repeated updates reuse portraits and command buttons")
		army[49].hp *= 0.5
		army[0].veteran_level = 2
		hud._refresh_strip_live()
		check(is_equal_approx(tile("E1").hp_frac, 49.5 / 50.0) and tile("E1").veteran_rank == 0 and "军衔混合" in tile("E1").tooltip_text, mode + ": group health and mixed ranks reflect every member")
		var hp := 0.0
		var max_hp := 0.0
		for u in army: hp += u.hp; max_hp += u.max_hp
		check(("总血量 %d%%" % roundi(hp / max_hp * 100)) in hud.sel_strip_title.text, mode + ": summary weights real maximum health")
		if DisplayServer.get_name() != "headless":
			for i in 5: await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(output_dir.path_join(mode + "-grouped.png"))
		# A dead representative is replaced without rebuilding its type's tile.
		var lost = army.pop_front()
		lost.hp = 0
		battle._emit_selection()
		check(tile("E1") == first and tile("E1").count == 49, mode + ": representative death updates count and preserves type frame")
		battle.units.erase(lost); lost.free()
		hud._refresh_strip_live()
		click(tile("GGI"))
		check(battle.selected_units.size() == 25 and battle.selected_units.all(func(u): return u.unit_id == "GGI") and not outside.selected, mode + ": left click filters current selection only")
		choose(army)
		click(tile("GGI"), MOUSE_BUTTON_RIGHT)
		check(battle.selected_units.size() == 51 and not battle.selected_units.any(func(u): return u.unit_id == "GGI"), mode + ": right click removes entire chosen type")
		choose(army)
		click(tile("SREF"))
		check(hud.sel_strip_box.get_child_count() == 2 and not hud._strip_grouped and hud._strip_icons.all(func(e): return e.unit.unit_id == "SREF"), mode + ": small subgroup expands into individual portraits")
		click(hud._strip_icons[1].icon)
		check(battle.selected_units == [army.back()] and hud._strip_icons[0].icon.is_processing(), mode + ": individual click still focuses exact actor")
		choose(army.slice(0,16))
		check(hud.sel_strip_box.get_child_count() == 16, mode + ": returning to threshold restores sixteen tiles")
		choose(army)
		battle.select_building(battle.buildings[0]); battle._emit_selection()
		check(not hud._strip_grouped and hud._strip_icons.is_empty() and hud.sel_strip_box.get_child_count() == 1, mode + ": building selection clears grouped tiles")
		choose(army.slice(0,20))
		click(tile("E1"), MOUSE_BUTTON_RIGHT)
		check(battle.selected_units.is_empty() and not hud.sel_strip.visible and hud._strip_icons.is_empty(), mode + ": removing last type clears panel")
		await finish()
	FileAccess.open(output_dir.path_join("result.json"), FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed}, "  "))
	get_tree().quit(0 if failed == 0 else 1)
