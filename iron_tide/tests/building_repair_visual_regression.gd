extends "res://tests/logistics_regression.gd"

func picture(indicator, label: String) -> Image:
	indicator.queue_redraw()
	battle.hp_overlay.queue_redraw()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := stage.get_texture().get_image()
	image.save_png(output_dir.path_join(label + ".png"))
	return image.get_region(Rect2i(Vector2i(indicator.screen_origin()), Vector2i(42,34)))

func different(a: Image, b: Image) -> int:
	var count := 0
	for y in a.get_height():
		for x in a.get_width():
			if a.get_pixel(x,y) != b.get_pixel(x,y): count += 1
	return count

func exercise_mode(mode: String) -> void:
	get_tree().paused = false
	setup_logistics_scene(mode, "美国")
	for group in ["obstacles", "resource_nodes"]:
		for node in get_tree().get_nodes_in_group(group): node.free()
	for node in battle.units + battle.buildings: node.free()
	battle.units.clear(); battle.buildings.clear()
	battle.water_rects = []; battle.path_service.set_water([])
	battle.camera.position = Vector2(1600,1600)
	Iso.apply_to(battle.camera, 2.0)
	battle.camera.reset_smoothing(); battle.camera.force_update_scroll()
	for id in ["GAPOWR", "GAWEAP", "GAREFN", "GADEPT", "ATESLA"]:
		var b = battle._place_building(id, "ally", Vector2(1600,1600), true)
		b._buildup_play = -1.0
		var fx = b.get_node("RepairIndicator")
		var tag: String = mode+id+": "
		fx.advance(0.0)
		check(not fx.visible, tag+"healthy building has no repair icon")
		b.hp = b.max_hp * 0.75
		b.set_repairing(true); fx.advance(0.0)
		check(fx.visible and fx.frame_index() == 0 and fx.textures.size() == 7, tag+"repair starts original seven-frame wrench")
		var hp_top: float = (battle.hp_overlay.get_global_transform_with_canvas() * b.position).y - b.radius * 2.9 * battle.camera.zoom.x
		check(fx.screen_origin().y + 32.0 < hp_top, tag+"wrench is above HP bar using battle camera zoom")
		var hp: float = b.hp
		var funds: float = battle.funds
		var first := await picture(fx, tag.replace(": ","")+"-frame0")
		fx.advance(0.32)
		var later := await picture(fx, tag.replace(": ","")+"-frame2")
		check(fx.frame_index() == 2 and different(first,later)>20, tag+"actual rendered wrench changes shape")
		check(b.hp == hp and battle.funds == funds, tag+"animation does not heal or charge")
		var elapsed: float = fx.elapsed
		battle.paused=true; fx.advance(0.5)
		check(fx.elapsed == elapsed, tag+"pause freezes frame")
		battle.paused=false
		battle.funds=0.0
		b._process_building_repair(2.0); fx.advance(0.5)
		check(b.repair_waiting_funds and fx.elapsed == elapsed and fx.visible, tag+"unfunded real repair holds icon")
		check(b.hp == hp, tag+"unfunded repair does not heal")
		battle.funds=20000.0
		b._process_building_repair(2.0); fx.advance(0.16)
		check(not b.repair_waiting_funds and b.hp > hp and battle.funds < 20000.0 and fx.elapsed != elapsed, tag+"paid repair resumes animation")
		b.set_repairing(false); fx.advance(0.0)
		check(not fx.visible and fx.elapsed == 0.0, tag+"cancel hides and resets animation")
		b.set_repairing(true); b.under_construction=true; fx.advance(0.0)
		check(not fx.visible, tag+"construction excludes repair wrench")
		b.under_construction=false; b.special.chrono_left=1.0; fx.advance(0.0)
		check(not fx.visible, tag+"chrono freeze excludes wrench")
		b.special.erase("chrono_left"); fx.advance(0.0)
		b.hide(); check(not fx.is_visible_in_tree(), tag+"building visibility also hides child")
		b.show()
		for i in 200: b._process_building_repair(1.0)
		fx.advance(0.0)
		check(b.hp == b.max_hp and not b.repairing and not fx.visible, tag+"real repair completion removes wrench")
		var ref: WeakRef = weakref(fx)
		battle.buildings.erase(b); b.free()
		check(ref.get_ref() == null, tag+"building destruction frees indicator")
	screen.free()
	await get_tree().process_frame
