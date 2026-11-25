extends "res://tests/input_ownership_regression.gd"
## Includes selection/input regression, then checks the actual icon consumers.

func exercise_additional_input(mode: String, soldier, peer, tank) -> void:
	await super.exercise_additional_input(mode, soldier, peer, tank)
	var hud = screen.hud
	var prefix := mode + ": "
	var mode_label = hud.get("mode_label")
	check(mode_label != null, prefix + "HUD identifies current rules mode")
	if mode_label != null:
		check(("RA2" in mode_label.text) if mode == MatchRules.RA2 else ("扩展" in mode_label.text),
			prefix + "mode badge agrees with rules")
	soldier.hp = soldier.max_hp * 0.4
	battle.select_unit(soldier, false)
	battle.select_unit(peer, true)
	battle._emit_selection()
	hud.select_prod_tab("infantry")
	hud._refresh_production()
	# A button added after HUD setup and a later flat override both receive
	# their battle skin without a periodic pass over unrelated controls.
	var late := Button.new()
	late.add_theme_stylebox_override("normal", StyleBoxFlat.new())
	hud.sel_box.add_child(late)
	await settle_icons()
	var first := late.get_theme_stylebox("normal")
	check(first is StyleBoxTexture and first.has_meta("ra3"), prefix + "new HUD button styled")
	late.add_theme_stylebox_override("hover", StyleBoxFlat.new())
	await settle_icons()
	check(late.get_theme_stylebox("hover").has_meta("ra3") and late.get_theme_stylebox("normal") == first, prefix + "changed button style updated in place")
	late.queue_free()
	var expected := GameData.ra2_cameo_path("E1")
	check(not expected.is_empty() and ResourceLoader.exists(expected), prefix + "existing infantry art fixture available")
	var production = find_icon(hud._prod_buttons["E1"], "E1")
	check(find_icon(hud.sel_box, "E1") == null, prefix + "details do not duplicate selection-strip portraits")
	var strip = find_icon(hud.sel_strip_box, "E1")
	var queue = find_icon(hud._queue_host, "E1")
	for item in [[production, "production"], [strip, "selection strip"], [queue, "queue"]]:
		check(item[0] != null, prefix + item[1] + " uses shared icon control")
		if item[0] != null:
			var texture = item[0].get("cameo_texture")
			check(texture != null and texture.resource_path == expected, prefix + item[1] + " uses same source art", expected)
	check(hud.sel_strip_box.get_child_count() == 2 and "已选部队 2" in hud.sel_strip_title.text and strip != null and strip.count == 1, prefix + "strip preserves both individual portraits and total count")
	check(strip != null and strip.selected and is_equal_approx(strip.hp_frac, 0.4) and strip.damaged,
		prefix + "strip preserves selection and damaged health")
	soldier.hp = soldier.max_hp * 0.7
	hud._refresh_strip_live()
	check(strip != null and is_equal_approx(strip.hp_frac, 0.7), prefix + "live strip health refresh preserved")
	check(hud.ability_panel.visible and hud._ability_btns.size() == 3, prefix + "current Q W E layout retains native deploy action in both modes")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		stage.get_texture().get_image().save_png(output_dir.path_join(mode + "-identity.png"))
	# A missing cameo keeps the same fallback in all HUD consumers.
	var fallback = UnitIcon.new()
	fallback.setup({"id": "__missing_cameo__", "name": "Fallback", "role": "vehicle"}, Color.CORNFLOWER_BLUE, 3, 0.5)
	screen.overlay_layer.add_child(fallback)
	fallback.position = Vector2(650, 180)
	fallback.size = Vector2(64, 64)
	check(fallback.get("cameo_texture") == null and fallback.count == 3 and fallback.damaged,
		prefix + "unknown art uses fallback with status intact")
	# Reusing a control with a different identity must not retain its old image.
	fallback.setup(GameData.get_unit("E1"), Color.CORNFLOWER_BLUE)
	var reused_texture = fallback.get("cameo_texture")
	check(reused_texture != null and reused_texture.resource_path == expected, prefix + "reused icon resolves current identity")
	fallback.setup({"id": "__missing_cameo__", "role": "vehicle"}, Color.CORNFLOWER_BLUE)
	check(fallback.get("cameo_texture") == null, prefix + "missing identity clears previous texture")
	await settle_icons()
	if DisplayServer.get_name() != "headless":
		stage.get_texture().get_image().save_png(output_dir.path_join(mode + "-fallback.png"))
	fallback.queue_free()
	for building in battle.buildings:
		if building.side == "ally" and building.building_id == "GAPOWR":
			battle.select_building(building)
			battle._emit_selection()
			await settle_icons()
			var building_icon = find_icon(hud.sel_strip_box, "GAPOWR")
			check(building_icon != null and building_icon.get("cameo_texture") != null
				and building_icon.get("cameo_texture").resource_path == GameData.ra2_cameo_path("GAPOWR"),
				prefix + "selected building uses production source art")
			check(hud.ability_panel.visible and hud.ability_box.has_node("EffectDetails") and hud._ability_btns.is_empty(), prefix + "building selection replaces unit skills with building details")
			break
	await exercise_strip_stack(mode)
	battle.clear_selection()
	battle._emit_selection()
	await settle_icons()
	check(not hud.ability_panel.visible and hud._ability_btns.is_empty(), prefix + "clearing selection removes skill controls")

func find_icon(node: Node, id: String):
	if node is UnitIcon and str(node.data.get("id", "")) == id:
		return node
	for child in node.get_children():
		var found = find_icon(child, id)
		if found != null:
			return found
	return null

func settle_icons() -> void:
	for i in range(4):
		await get_tree().process_frame

func exercise_strip_stack(mode: String) -> void:
	var hud = screen.hud
	var army: Array = []
	for i in 40:
		army.append(battle.spawn_unit("E1", "ally", Vector2(1600 + i * 4, 1800)))
	for dimensions in [Vector2i(1280, 720), Vector2i(1600, 900)]:
		stage.size = dimensions
		var previous_top := INF
		for count in [1, 4, 5, 12, 16, 17, 40]:
			battle.clear_selection()
			for i in count: battle.select_unit(army[i], true)
			battle._emit_selection()
			await settle_icons()
			var prefix := "%s %s count=%d: " % [mode, dimensions, count]
			var rect: Rect2 = hud.sel_strip.get_global_rect()
			var scroll: ScrollContainer = hud.sel_strip_box.get_parent()
			check(hud.sel_strip_box is GridContainer and hud.sel_strip_box.columns == 4 and hud.sel_strip_box.get_child_count() == (count if count <= 16 else 1), prefix + "four-column grid merges above sixteen")
			check((count > 16 or rect.position.y <= previous_top) and is_equal_approx(rect.end.y, dimensions.y - 228), prefix + "strip grows upward with fixed bottom")
			previous_top = rect.position.y
			check(Rect2(Vector2.ZERO, Vector2(dimensions)).encloses(rect) and not rect.intersects(hud._minimap_frame.get_global_rect()) and not rect.intersects(hud.ability_panel.get_global_rect()) and not rect.intersects(hud._log_holder.get_global_rect()), prefix + "stack fits without minimap skills or log overlap", str(rect))
			check(not scroll.get_h_scroll_bar().visible, prefix + "no horizontal scrolling")
			if count <= 16 or hud._strip_grouped:
				check(not scroll.get_v_scroll_bar().visible, prefix + "normal selection needs no scrolling")
				for tile in hud.sel_strip_box.get_children():
					check(scroll.get_global_rect().encloses(tile.get_global_rect()), prefix + "portrait fully visible")
			else:
				scroll.ensure_control_visible(hud.sel_strip_box.get_child(count - 1))
				await settle_icons()
				check(scroll.get_global_rect().encloses(hud.sel_strip_box.get_child(count - 1).get_global_rect()), prefix + "overflow last portrait remains reachable", [str(scroll.get_global_rect()), str(hud.sel_strip_box.get_child(count - 1).get_global_rect()), scroll.scroll_vertical])
			if count == 24 and DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				stage.get_texture().get_image().save_png(output_dir.path_join("%s-%dx%d-stacked.png" % [mode, dimensions.x, dimensions.y]))
	# Restore a small selection before checking exact portrait-to-actor input.
	battle.clear_selection()
	for i in 16: battle.select_unit(army[i], true)
	battle._emit_selection()
	await settle_icons()
	# Click the last row after scrolling: preserve portrait-to-unit selection.
	get_window().focus_entered.emit()
	var last: Control = hud.sel_strip_box.get_child(15)
	var at := last.get_global_rect().get_center()
	await move_pointer(at)
	await mouse_button(at, true)
	await mouse_button(at, false)
	await settle_icons()
	check(battle.selected_units == [army[15]], mode + ": stacked portrait click focuses correct unit")
	check(hud.sel_strip.size.y <= 90 and hud.sel_strip_box.get_child_count() == 1, mode + ": selection shrinking restores compact strip")
