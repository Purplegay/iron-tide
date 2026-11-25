extends "res://tests/logistics_regression.gd"

func capture() -> Image:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	return stage.get_texture().get_image()

func exercise_mode(mode: String) -> void:
	check(DisplayServer.get_name() != "headless", mode+": actual rendering required")
	if DisplayServer.get_name() == "headless": return
	setup_logistics_scene(mode, "美国")
	# HUD normally processes while battle is paused, including its 0.4s skin timer.
	# Freeze it for pixel comparisons; controls/signals still operate normally.
	screen.hud.process_mode = Node.PROCESS_MODE_DISABLED
	for group in ["obstacles", "resource_nodes"]:
		for node in get_tree().get_nodes_in_group(group): node.free()
	for node in battle.units + battle.buildings: node.free()
	battle.units.clear(); battle.buildings.clear()
	battle.water_rects = []; battle.path_service.set_water([])
	battle.camera.position = Vector2(1600,1600)
	var controls = screen.hud.settings_panel.find_child("ModelSmoothing", true, false)
	check(controls != null, mode+": battle settings exposes option")
	var menu = load("res://scenes/settings.tscn").instantiate()
	# Main-menu controls need an untransformed canvas in a battle-camera fixture.
	var menu_layer := CanvasLayer.new()
	menu_layer.layer=100
	stage.add_child(menu_layer)
	menu_layer.add_child(menu)
	var menu_control = menu.find_child("ModelSmoothing",true,false)
	check(menu_control != null, mode+": menu settings exposes option")
	(await capture()).save_png(output_dir.path_join(mode+"-menu.png"))
	check(menu.size == Vector2(stage.size) and menu.get_global_rect().encloses(menu_control.get_global_rect()),mode+": real menu scene fills viewport and contains option")
	menu.hide()
	MetaProgress.set_model_smoothing(false)
	check(not controls.button_pressed and not menu_control.button_pressed, mode+": both controls reflect setting")
	menu_control.button_pressed=true
	check(MetaProgress.model_smoothing and controls.button_pressed,mode+": menu toggle updates battle option")
	controls.button_pressed=false
	check(not MetaProgress.model_smoothing and not menu_control.button_pressed,mode+": battle toggle updates menu option")
	MetaProgress.model_smoothing=true
	MetaProgress.load_save()
	check(not MetaProgress.model_smoothing,mode+": disabled setting survives disk reload")
	var legacy: Dictionary = MetaProgress.to_dict()
	legacy.erase("model_smoothing")
	var file := FileAccess.open(MetaProgress.SAVE_PATH,FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy)); file.close()
	MetaProgress.load_save()
	check(MetaProgress.model_smoothing and controls.button_pressed,mode+": old save defaults smooth and updates UI")
	for color in ["blue","green"]:
		HouseColor.set_player_id(color)
		for id in ["MTNK", "CMIN", "E1", "GAPOWR", "GAWEAP"]:
			var building: bool = id.begins_with("GA")
			var actor = battle._place_building(id,"ally",Vector2(1600,1600),true) if building else battle.spawn_unit(id,"ally",Vector2(1600,1600))
			if building: actor._buildup_play=-1.0
			else: actor.order_stop()
			var label: String = mode+color+id+": "
			check(actor.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR,label+"new actor inherits smooth preference")
			var material: Material = actor.material
			var position_before: Vector2 = actor.position
			var hp_before: float = actor.hp
			for zoom in [1.0,2.0,3.0]:
				Iso.apply_to(battle.camera,zoom)
				battle.camera.reset_smoothing(); battle.camera.force_update_scroll()
				MetaProgress.set_model_smoothing(false)
				actor.queue_redraw()
				var original := await capture()
				MetaProgress.set_model_smoothing(true)
				actor.queue_redraw()
				var smooth := await capture()
				check(original.get_region(Rect2i(560,280,480,240)).get_data() != smooth.get_region(Rect2i(560,280,480,240)).get_data(),label+"actual rendered pixels change at zoom "+str(zoom))
				var hud_region:=Rect2i(1230,120,350,220)
				check(original.get_region(hud_region).get_data() == smooth.get_region(hud_region).get_data(),label+"sidebar unaffected at zoom "+str(zoom))
				if mode == MatchRules.RA2 and zoom == 3.0:
					original.save_png(output_dir.path_join(color+id+"-original.png"))
					smooth.save_png(output_dir.path_join(color+id+"-smooth.png"))
			check(actor.material == material and actor.position == position_before and actor.hp == hp_before,label+"filter preserves team material and gameplay state")
			if not building: check(actor.hit_test(actor.art_center()),label+"sprite center remains selectable")
			if building:
				actor.special.c4_left=1.2
				preload("res://scripts/units/temporal_visual.gd").sync(actor)
				var effect: Material=actor.material
				MetaProgress.set_model_smoothing(false)
				check(actor.material == effect and effect != material,label+"filter preserves active C4 material")
				actor.special.erase("c4_left")
				preload("res://scripts/units/temporal_visual.gd").sync(actor)
				check(actor.material == material,label+"C4 restores original material after filter change")
				battle.buildings.erase(actor)
			else: battle.units.erase(actor)
			actor.free()
			MetaProgress.set_model_smoothing(true)
	MetaProgress.model_smoothing=false
	MetaProgress.load_save()
	check(MetaProgress.model_smoothing,mode+": enabled setting survives disk reload")
	screen.hud.settings_panel.show()
	(await capture()).save_png(output_dir.path_join(mode+"-battle-settings.png"))
	menu_layer.free(); screen.free()
	await get_tree().process_frame
