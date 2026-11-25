extends "res://tests/ground_control_regression.gd"

func exercise(mode: String) -> void:
	start(mode)
	await get_tree().process_frame
	var hud = screen.hud
	var unit = battle.spawn_unit("MTNK", "ally", Vector2(600,600))
	battle.select_unit(unit,false)
	battle._emit_selection()
	check(hud.production_collapsed and hud.sel_strip.is_visible_in_tree(),prefix+"selection opens roster")
	check(hud.deck_tabs.is_visible_in_tree() and hud.minimap.is_visible_in_tree(),prefix+"persistent tabs and radar")
	hud.deck_tabs_btns.building.pressed.emit()
	check(hud._prod_scroll.is_visible_in_tree() and not hud.sel_strip.is_visible_in_tree(),prefix+"catalog replaces roster")
	battle.request_structure("GAPOWR")
	check(not battle.struct_queue.is_empty(),prefix+"construction queued")
	battle.set_build_mode("GAPOWR")
	hud.deck_tabs_btns.building.pressed.emit()
	check(battle.armed_build.is_empty() and hud.sel_strip.is_visible_in_tree(),prefix+"same tab exits preview and returns roster")
	check(battle.selected_units==[unit],prefix+"same unit still selected")
	var before:float=battle.struct_queue[0].paid
	battle._tick_structure_queue(1.0)
	check(battle.struct_queue[0].paid>before,prefix+"queue progresses with catalog closed")
	hud.production_toggle.pressed.emit()
	check(hud._prod_scroll.is_visible_in_tree(),prefix+"toggle reopens catalog")
	await finish()
