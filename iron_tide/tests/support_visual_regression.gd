extends "res://tests/logistics_regression.gd"

func exercise_mode(mode: String) -> void:
	setup_logistics_scene(mode, "美国")
	for group in ["obstacles", "resource_nodes"]:
		for actor in get_tree().get_nodes_in_group(group): actor.free()
	for actor in battle.units + battle.buildings: actor.free()
	battle.units.clear()
	battle.buildings.clear()
	battle.water_rects = []
	battle.path_service.set_water([])
	if battle.fog != null: battle.fog.free(); battle.fog = null
	battle.power_low = false
	var center := Vector2(1600, 1600)
	battle.camera.position = center
	battle.camera.zoom = Iso.cam_zoom(1.6)
	battle.camera.reset_smoothing()
	battle.camera.force_update_scroll()
	var weather = battle._place_building("GAWEAT", "ally", center + Vector2(-220, -150), true)
	weather._buildup_play = -1.0
	var target = battle._place_building("GAPOWR", "enemy", center + Vector2(80, 40), true)
	target._buildup_play = -1.0
	weather._sw_charge = weather.sw_recharge()
	var strike: Vector2 = target.position
	var fired: bool = weather.fire_superweapon(strike)
	check(fired, mode + ": charged weather controller accepts target")
	if fired:
		var state: Dictionary = LightningStorm.storms(battle)[0]
		LightningStorm.tick(battle, state.delay)
		var lighting = battle.get_node_or_null("StormPresentation/StormLighting")
		check(lighting != null and lighting.color != Color.WHITE, mode + ": storm darkens battle lighting")
		var clouds: Array = state.clouds.filter(func(cloud): return cloud.point == strike)
		check(not clouds.is_empty(), mode + ": storm creates cloud over target")
		if not clouds.is_empty():
			var art := RA2Art.fx(str(clouds[0].id))
			check(art.get("tex") != null and int(art.get("count", 0)) > 1, mode + ": live cloud has an animated texture")
			var before: float = target.hp
			LightningStorm.tick(battle, clouds[0].hit - state.time)
			var effects: Array = battle.effects_root.get_children()
			check(effects.any(func(fx): return fx is Ra2Fx and fx.position == strike and str(fx.anim.image).begins_with("WCLBOLT") and fx.bright), mode + ": lightning bolt at cloud strike")
			check(effects.any(func(fx): return fx is Ra2Fx and fx.position == strike and fx.anim.image == "EXPLOLB") and target.hp < before, mode + ": impact and damage at same target")
	battle.select_building(weather)
	battle._emit_selection()
	await capture(mode + "-lightning-storm")
	LightningStorm.tick(battle, 60.0)
	var lighting = battle.get_node_or_null("StormPresentation/StormLighting")
	check(LightningStorm.storms(battle).is_empty() and lighting != null and lighting.color == Color.WHITE, mode + ": storm clears clouds and restores lighting")
	for fx in battle.effects_root.get_children(): fx.free()
	battle.buildings.erase(weather); weather.free()
	battle.buildings.erase(target); target.free()
	var gap = battle._place_building("GAGAP", "ally", center, true)
	gap._buildup_play = -1.0
	battle.select_building(gap)
	battle._emit_selection()
	var summary = screen.hud.sel_box.get_node_or_null("SelectionDescription")
	check(summary != null and summary.text == EntityDescription.text(gap.data) and SupportSystems.gap_radius(gap) == 550.0, mode + ": selected gap description and ten-cell coverage")
	await capture(mode + "-gap-description")
	battle.buildings.erase(gap); gap.free()
	var chrono = battle._place_building("GACSPH", "ally", center + Vector2(-180, -120), true)
	chrono._buildup_play = -1.0
	var tank = battle.spawn_unit("MTNK", "ally", center + Vector2(60, 0))
	var origin: Vector2 = tank.position
	battle.select_unit(tank, false)
	battle._emit_selection()
	chrono._sw_charge = chrono.sw_recharge()
	var destination := center + Vector2(160, 0)
	check(chrono.fire_superweapon(destination, tank.position) and tank.position == destination, mode + ": charged chronosphere transports selected tank")
	check(battle.effects_root.get_children().any(func(fx): return fx is Ra2Fx and fx.anim.image == "CHRONOFD" and fx.position == origin), mode + ": teleport emits departure animation")
	check(battle.effects_root.get_children().any(func(fx): return fx is Ra2Fx and fx.anim.image == "CHRONOTG" and fx.position == destination), mode + ": teleport emits destination animation")
	for fx in battle.effects_root.get_children():
		if fx is Ra2Fx:
			fx.frame = mini(10, int(fx.anim.get("count", 1)) - 1)
			fx.queue_redraw()
	await capture(mode + "-chrono-unit-description")
	var description_button = screen.hud.sel_box.find_child("UnitDescriptionButton", true, false)
	check(description_button != null and description_button.is_visible_in_tree(), mode + ": unit has visible explanation button")
	if description_button != null:
		description_button.pressed.emit()
		var dialog = screen.hud.get_node_or_null("EntityDescriptionDialog")
		check(dialog != null and dialog.visible and dialog.dialog_text == EntityDescription.text(tank.data), mode + ": actual description button opens full explanation")
		if dialog != null: dialog.hide(); dialog.queue_free()
	screen.free()
	await get_tree().process_frame

func capture(name: String) -> void:
	await get_tree().process_frame
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var image := stage.get_texture().get_image()
	check(not image.is_empty(), name + ": rendered actual scene")
	image.save_png(output_dir.path_join(name + ".png"))
