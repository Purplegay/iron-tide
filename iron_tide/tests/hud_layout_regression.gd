extends Node
## Inspect actual laid-out controls and render the real HUD at several viewport sizes.
var checks: Array = []
var failed := 0
var stage: SubViewport
var output_dir := ""

func check(ok: bool, label: String, details = null) -> void:
	checks.append({"name": label, "passed": ok, "details": details})
	if not ok:
		failed += 1
		print("FAIL ", label, " ", details)

func _ready() -> void:
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not ProjectSettings.get_setting("application/config/use_custom_user_dir", false):
		get_tree().quit(2)
		return
	stage = SubViewport.new()
	stage.size = Vector2i(1600, 900)
	stage.world_2d = World2D.new()
	stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(stage)
	for mode in [MatchRules.RA2, MatchRules.EXTENDED]:
		BattleRequest.configure_skirmish(mode, {"map_size": 3200, "starting_funds": 8000})
		var screen = load("res://scenes/battle.tscn").instantiate()
		stage.add_child(screen)
		var hud = screen.hud
		for building in screen.battle.buildings:
			building._buildup_play = -1.0
		var infantry = screen.battle.spawn_unit("E1", "ally", screen.battle.camera.position)
		var guardian = screen.battle.spawn_unit("GGI", "ally", screen.battle.camera.position + Vector2(80, 0))
		screen.process_mode = Node.PROCESS_MODE_DISABLED
		hud.process_mode = Node.PROCESS_MODE_ALWAYS
		hud.set_process(false)
		hud._refresh_production()
		Ra3Skin.upgrade_tree(hud.get_child(0), UiKit.RA_CYAN)
		check(not hud._prod_buttons.is_empty(), mode + ": real production catalog is populated")
		var top: Control = hud.funds_label.get_parent().get_parent()
		var map_frame: Control = hud.minimap.get_parent().get_parent()
		for dimensions in [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440)]:
			stage.size = dimensions
			await settle()
			var label := "%s %s: " % [mode, dimensions]
			var bounds := Rect2(Vector2.ZERO, Vector2(dimensions))
			check(not hud.view_btn.is_visible_in_tree(), label + "projection parameters hidden in normal HUD")
			check(not visible_text(top, "GM"), label + "GM entry not in normal topbar")
			for entry in [[top, "topbar"], [map_frame, "minimap frame"], [hud.prod_panel, "production"]]:
				check(bounds.encloses(entry[0].get_global_rect()), label + entry[1] + " fits viewport",
					str(entry[0].get_global_rect()))
			check(top.get_global_rect().end.y + 6 <= map_frame.get_global_rect().position.y,
				label + "minimap clears actual topbar height")
			check(map_frame.get_global_rect().end.y <= hud.prod_panel.get_global_rect().position.y
				and not map_frame.get_global_rect().intersects(hud.sel_panel.get_global_rect())
				and hud.sel_panel.get_global_rect().end.x + 6 <= hud.prod_panel.get_global_rect().position.x,
				label + "radar, command dock and production do not overlap")
			for id in hud.deck_tabs_btns:
				var tab: Button = hud.deck_tabs_btns[id]
				check(hud.prod_panel.get_global_rect().encloses(tab.get_global_rect()), label + "production tab visible: " + id)
			for id in hud._prod_buttons:
				var button: Button = hud._prod_buttons[id]
				var button_rect := button.get_global_rect()
				var caption: Label = hud._prod_status_labels[id]
				check(caption.size.x >= 70 and caption.size.y >= 20 and button_rect.encloses(caption.get_global_rect()), label + "production reason has readable area: " + id, str(caption.get_global_rect()))
				check(button_rect.position.x >= hud.prod_panel.get_global_rect().position.x and button_rect.end.x <= hud.prod_panel.get_global_rect().end.x,
					label + "production card fits horizontally: " + id)
			var scroll: ScrollContainer = hud.prod_box.get_parent()
			scroll.scroll_vertical = 100000
			await settle()
			var last_button: Button = hud._prod_buttons.values().back()
			check(scroll.get_global_rect().encloses(last_button.get_global_rect()), label + "last production card reachable by scrolling")
			scroll.scroll_vertical = 0
			await settle()
			check(bounds.encloses(hud.funds_label.get_global_rect()) and bounds.encloses(hud.power_plate.get_global_rect())
				and bounds.encloses(hud.pause_btn.get_global_rect()) and bounds.encloses(hud.speed_btn.get_global_rect()),
				label + "resources and controls fit")
			await capture(mode + "-%dx%d.png" % [dimensions.x, dimensions.y])
			screen.battle.select_unit(infantry, false)
			screen.battle._emit_selection()
			await settle()
			for entry in [[hud.sel_panel, "selection details"], [hud.sel_strip, "selection icons"], [hud._command_box, "fixed commands"]]:
				check(bounds.encloses(entry[0].get_global_rect()), label + entry[1] + " fits after selection", str(entry[0].get_global_rect()))
			check(hud.sel_panel.is_visible_in_tree() and not hud.cmd_buttons.is_empty(), label + "actual selection populates command dock")
			check(hud.buff_panel.is_visible_in_tree() and hud.buff_empty.is_visible_in_tree()
				and bounds.encloses(hud.buff_panel.get_global_rect())
				and hud.buff_panel.get_global_rect().encloses(hud.buff_empty.get_global_rect()), label + "idle selection shows readable empty Buff bar within viewport")
			for command in hud.cmd_buttons.values():
				check(hud.sel_panel.get_global_rect().encloses(command.get_global_rect()), label + "command always visible outside stats scroll")
			if hud.ability_panel.visible:
				check(bounds.encloses(hud.ability_panel.get_global_rect()) and not hud.ability_panel.get_global_rect().intersects(hud.sel_panel.get_global_rect()), label + "skills fit above selection without overlap")
			await capture(mode + "-selected-%dx%d.png" % [dimensions.x, dimensions.y])
			# Collapse details/commands while retaining skills and the Buff bar.
			check(bounds.encloses(hud.unit_menu_toggle.get_global_rect()), label + "collapse button fits")
			for panel in [hud.sel_panel, hud.ability_panel, hud.buff_panel]:
				if panel.is_visible_in_tree():
					check(not hud.unit_menu_toggle.get_global_rect().intersects(panel.get_global_rect()), label + "collapse button clears visible menu panels")
			var had_skills: bool = hud.ability_panel.is_visible_in_tree()
			await click(hud.unit_menu_toggle.get_global_rect().get_center())
			check(hud.unit_menu_collapsed and not hud.sel_panel.is_visible_in_tree()
				and hud.ability_panel.is_visible_in_tree() == had_skills and hud.buff_panel.is_visible_in_tree(), label + "collapse preserves skills and compact status cells")
			check(bounds.encloses(hud.buff_panel.get_global_rect())
				and not hud.buff_panel.get_global_rect().intersects(hud._compact_vitals.get_global_rect())
				and not hud.buff_panel.get_global_rect().intersects(hud.ability_panel.get_global_rect()), label + "collapsed empty Buff bar stays on screen clear of vitals and skills")
			check(hud.minimap.is_visible_in_tree() and hud.prod_panel.is_visible_in_tree(), label + "collapse preserves radar and production")
			check(hud.unit_menu_toggle.is_visible_in_tree() and bounds.encloses(hud.unit_menu_toggle.get_global_rect()), label + "expand remains reachable at bottom")
			screen.battle.select_unit(guardian, false)
			screen.battle._emit_selection()
			guardian.add_buff("armor", 10.0, 0.1)
			hud._update_buff_live()
			await settle()
			check(not hud.sel_panel.is_visible_in_tree() and hud.ability_panel.is_visible_in_tree()
				and hud.buff_panel.is_visible_in_tree() and hud.ability_title.text.contains(guardian.display_name), label + "selection refresh updates compact status cells without reopening details")
			check(bounds.encloses(hud.ability_panel.get_global_rect()) and is_equal_approx(hud.ability_panel.get_global_rect().end.y, dimensions.y - 8.0)
				and not hud.ability_panel.get_global_rect().intersects(hud.unit_menu_toggle.get_global_rect()), label + "compact skill bar docks at bottom clear of expand button", str(hud.ability_panel.get_global_rect()))
			var compact: Rect2 = hud._compact_vitals.get_global_rect()
			check(hud.sel_hp_bar.is_visible_in_tree() and hud.sel_xp_bar.is_visible_in_tree()
				and bounds.encloses(compact) and compact.encloses(hud.sel_hp_bar.get_global_rect())
				and compact.encloses(hud.sel_xp_bar.get_global_rect())
				and not compact.intersects(hud.unit_menu_toggle.get_global_rect())
				and not compact.intersects(hud.ability_panel.get_global_rect()), label + "collapsed HP and XP fit beside expand control")
			guardian.hp = guardian.max_hp * 0.73
			guardian.credit_kill(10, "enemy")
			hud._refresh_selection_live()
			check(is_equal_approx(hud.sel_hp_bar._cur, guardian.hp)
				and is_equal_approx(hud.sel_xp_bar.value, guardian.veterancy_status().progress * 100.0)
				and hud.sel_xp_bar.value > 0.0, label + "collapsed bars follow damage and earned experience")
			var motion := InputEventMouseMotion.new()
			motion.position = hud.sel_panel.get_global_rect().get_center()
			stage.push_input(motion, true)
			await settle()
			check(stage.gui_get_hovered_control() == null, label + "hidden menu no longer blocks world pointer")
			guardian.set_deployed(false)
			get_window().focus_entered.emit()
			await click(hud._ability_btns[2].get_global_rect().get_center())
			check(guardian.is_deployed() and not screen.battle.dragging, label + "collapsed skill remains clickable without world command leakage")
			guardian.set_deployed(false)
			for pressed in [true, false]:
				var key_event := InputEventKey.new()
				key_event.keycode = KEY_E
				key_event.pressed = pressed
				stage.push_input(key_event, true)
				await get_tree().process_frame
			check(guardian.is_deployed(), label + "E still deploys while details hidden")
			await capture(mode + "-collapsed-%dx%d.png" % [dimensions.x, dimensions.y])
			await click(hud.unit_menu_toggle.get_global_rect().get_center())
			hud._update_ability_live()
			check(not hud.unit_menu_collapsed and hud.sel_panel.is_visible_in_tree() and hud.ability_panel.is_visible_in_tree(), label + "expand restores current unit menu")
			check(not hud._compact_vitals.is_visible_in_tree() and hud.sel_panel.is_ancestor_of(hud.sel_hp_bar) and hud.sel_xp_bar.is_visible_in_tree(), label + "expand restores original bars")
			check(hud._ability_btns[2].get_meta("name_label").text == "收起导弹", label + "expanded skill shows latest hidden-state change")
			screen.battle.clear_selection()
			screen.battle._emit_selection()
			await settle()
		# Resize the existing HUD back down and exercise its real settings toggle.
		stage.size = Vector2i(1280, 720)
		await settle()
		var settings = hud.get("settings_btn")
		check(settings != null, mode + ": settings entry exists")
		if settings != null:
			await click(settings.get_global_rect().get_center())
			check(hud.view_btn.is_visible_in_tree(), mode + ": settings exposes projection control")
			var panel: Control = hud.get("settings_panel")
			check(panel != null and Rect2(Vector2.ZERO, Vector2(stage.size)).encloses(panel.get_global_rect()),
				mode + ": settings panel stays on screen after resize")
			check(visible_text(panel, "GM"), mode + ": developer entry remains available in settings")
			await capture(mode + "-settings.png")
			check(hud.armed_escape(), mode + ": Escape closes settings first")
			check(not hud.view_btn.is_visible_in_tree(), mode + ": closing settings hides debug parameters")
		# Long live status texts must not push the toolbar beyond the viewport.
		hud.funds_label.text = "资金 9999999"
		hud.power_label.text = "⚡ 12000 / 15000"
		hud.power_sub.text = "赤字 −3000   电力不足 - 生产减缓"
		await settle()
		check(Rect2(Vector2.ZERO, Vector2(stage.size)).encloses(top.get_global_rect()),
			mode + ": long resource and power status fits compact viewport")
		await capture(mode + "-status.png")
		await check_panel_memory(mode, screen)
	var f := FileAccess.open(output_dir.path_join("result.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks": checks, "failed": failed, "evidence": {
		"project": ProjectSettings.globalize_path("res://"), "user_dir": OS.get_user_data_dir(),
		"engine": Engine.get_version_info().string, "sizes": ["1280x720", "1600x900", "1920x1080", "2560x1440"]
	}}, "  "))
	f.close()
	print("HUD_LAYOUT checks=", checks.size(), " failed=", failed)
	get_tree().quit(0 if failed == 0 else 1)

func check_panel_memory(mode: String, initial_screen) -> void:
	var current = initial_screen
	for collapsed in [[true, true], [false, true], [true, false], [false, false]]:
		var hud = current.hud
		var snapshot:Dictionary=preload("res://scripts/save/battle_snapshot.gd").new().capture(current.battle)
		if hud.production_collapsed != collapsed[0]: hud.production_toggle.pressed.emit()
		if hud.unit_menu_collapsed != collapsed[1]: hud.unit_menu_toggle.pressed.emit()
		var config := ConfigFile.new()
		check(config.load(hud.PANEL_PREFERENCES_PATH) == OK
			and config.get_value("panels", "production_collapsed") == collapsed[0]
			and config.get_value("panels", "unit_menu_collapsed") == collapsed[1], mode + " panel choices persist on disk " + str(collapsed))
		current.free()
		await get_tree().process_frame
		current = load("res://scenes/battle.tscn").instantiate()
		stage.add_child(current)
		current.process_mode = Node.PROCESS_MODE_DISABLED
		hud = current.hud
		var unit = current.battle.spawn_unit("E1", "ally", current.battle.player_start())
		current.battle.select_unit(unit, false)
		current.battle._emit_selection()
		await settle()
		check(hud.production_collapsed == collapsed[0] and hud.prod_panel.visible == not collapsed[0]
			and hud.unit_menu_collapsed == collapsed[1] and hud._unit_menu.visible == not collapsed[1], mode + " fresh battle restores independent panel choices " + str(collapsed))
		check(hud.unit_menu_toggle.text.begins_with("▲") == collapsed[1]
			and hud.production_toggle.text == ("◀" if collapsed[0] else "▶"), mode + " restored controls offer the correct next action " + str(collapsed))
		check(is_instance_valid(hud._unit_vitals) and hud._unit_vitals.get_parent() == (hud._compact_vitals if collapsed[1] else hud._vitals_home), mode + " selecting a unit after restore uses correct vitals host " + str(collapsed))
		preload("res://scripts/save/battle_snapshot.gd").new().restore(current.battle,snapshot)
		get_tree().paused=false;current.battle.paused=false
		check(hud.production_collapsed == collapsed[0] and hud.unit_menu_collapsed == collapsed[1], mode + " loading an earlier battle keeps latest panel preferences " + str(collapsed))
	current.free()
	await get_tree().process_frame

func settle() -> void:
	for i in range(6):
		await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw

func capture(filename: String) -> void:
	if DisplayServer.get_name() != "headless":
		stage.get_texture().get_image().save_png(output_dir.path_join(filename))

func visible_text(node: Node, value: String) -> bool:
	if node is Control and not node.is_visible_in_tree():
		return false
	if (node is Button or node is Label) and value in node.text:
		return true
	for child in node.get_children():
		if visible_text(child, value):
			return true
	return false

func click(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	stage.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		stage.push_input(event, true)
		await get_tree().process_frame
	await settle()
