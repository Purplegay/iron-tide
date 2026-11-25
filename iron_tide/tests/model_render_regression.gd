extends "res://tests/selection_regression.gd"

func exercise_mode(mode: String) -> void:
	BattleRequest.configure_skirmish(mode, {"map_size": 3200, "starting_funds": 10000})
	screen = load("res://scenes/battle.tscn").instantiate()
	stage.add_child(screen)
	battle = screen.battle
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	check(DisplayServer.get_name() != "headless", mode + ": actual renderer required")
	if DisplayServer.get_name() == "headless": return
	# Every layer needs actual denser source pixels, not an enlarged native atlas.
	for filename in DirAccess.get_files_at("res://assets/ra2/vxl"):
		if not filename.ends_with(".json") or "_shd" in filename or filename.ends_with("_turret.json"): continue
		var detail_id := filename.trim_suffix(".json")
		var detail_art := RA2Art.art(detail_id)
		var detail_texture: Texture2D = detail_art.get("detail_tex")
		check(detail_texture != null and float(detail_art.get("detail_scale", 1)) == 2.0, mode + detail_id + ": surface detail atlas loaded")
		if detail_texture == null: continue
		check(detail_texture.get_size() == detail_art.tex.get_size() * 2.0, mode + detail_id + ": detail/native dimensions align")
		var detail_image := detail_texture.get_image()
		var detail_complete := true
		for frame in 32 * int(detail_art.get("poses", 1)):
			var logical := RA2Art.src_rect(detail_art, frame)
			var detail_rect := Rect2i(logical.position * 2.0, logical.size * 2.0)
			detail_complete = detail_complete and not detail_image.get_region(detail_rect).is_invisible()
		check(detail_complete, mode + detail_id + ": every detail direction/pose has visible surfaces")
	for filename in DirAccess.get_files_at("res://assets/ra2/vxl"):
		if not filename.ends_with(".json") or "_tur" in filename or "_shd" in filename: continue
		var id := filename.trim_suffix(".json")
		var metadata: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/ra2/vxl/" + filename))
		var art := RA2Art.art(id)
		var shadow := RA2Art.art(id + "_shd")
		check(metadata.get("pose_source", "") == "local VXL + HVA" and art.facings == 32, mode + id + ": local source pose and 32 facings")
		var image: Image = art.tex.get_image()
		var shade: Image = shadow.tex.get_image()
		var complete := true
		for frame in 32 * int(art.get("poses", 1)):
			var rect := Rect2i(RA2Art.src_rect(art, frame))
			complete = complete and Rect2i(Vector2i.ZERO, image.get_size()).encloses(rect) and not image.get_region(rect).is_invisible()
			var sr := Rect2i(RA2Art.src_rect(shadow, frame))
			complete = complete and sr.size == rect.size and Rect2i(Vector2i.ZERO, shade.get_size()).encloses(sr) and not shade.get_region(sr).is_invisible()
		check(complete, mode + id + ": every body and ground-shadow pose fits atlas and contains pixels")
	var previous := HouseColor.player_id
	HouseColor.set_player_id("blue")
	battle.camera.position = Vector2(1600, 1600)
	battle.camera.zoom = Iso.cam_zoom(2.0)
	battle.camera.rotation = Iso.cam_angle()
	battle.camera.reset_smoothing()
	battle.camera.force_update_scroll()
	for id in ["ROBO", "MTNK", "FV", "SREF", "MGTK", "TNKD", "CMIN", "AMCV", "BFRT", "ORCA", "BEAG", "SHAD", "HORNET", "DEST", "AEGIS", "CARRIER", "LCRF"]:
		var u = battle.spawn_unit(id, "ally", Vector2(1600, 1600))
		u.process_mode = Node.PROCESS_MODE_DISABLED
		u.order_stop()
		u.special.mirage_enabled = false
		if id == "ROBO": u.hover_motion.lift = 14.0
		if u.is_air: u.logistics.air_lift = 0.15
		u.hull_angle = RA2Art.art_dir(Vector2(-1, .5)).angle()
		u.turret_angle = u.hull_angle
		u.queue_redraw()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		check(u._art_aframes.size() >= 32 and u._art_sc == 1.0, mode + id + ": native-size atlas consumed by live unit renderer")
		check(u.hit_test(u.art_center()), mode + id + ": visual center lies on selectable body, not shadow padding")
		if id in ["MTNK", "CMIN", "ROBO"]:
			var high: Image = stage.get_texture().get_image()
			var old_hit: Vector2 = u.art_center()
			var old_muzzle: Rect2 = u._turret_draw_rect
			var saved_detail: Array = []
			for layer in [u._ra2, u._ra2_tur]:
				saved_detail.append(layer.get("detail_tex"))
				layer.erase("detail_tex")
				layer.erase("detail_scale")
			u.queue_redraw()
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var native: Image = stage.get_texture().get_image()
			check(high.get_data() != native.get_data(), mode + id + ": live draw consumes additional surface detail pixels")
			check(old_hit.is_equal_approx(u.art_center()) and old_muzzle == u._turret_draw_rect, mode + id + ": density preserves hit center and turret placement")
			var layers: Array = [u._ra2, u._ra2_tur]
			for i in layers.size():
				if saved_detail[i] != null:
					layers[i]["detail_tex"] = saved_detail[i]
					layers[i]["detail_scale"] = 2.0
			u.queue_redraw()
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			high.save_png(output_dir.path_join(mode + "-" + id + "-surface-detail.png"))
			native.save_png(output_dir.path_join(mode + "-" + id + "-surface-native.png"))
		if bool(u._ra2.get("split_shadow", false)):
			# Canvas commands outlive the draw callback. Evict cached textures while
			# this stationary actor keeps its submitted draw list, then compare pixels.
			var center: Vector2 = stage.get_canvas_transform() * u.global_position
			var capture := Rect2i(Vector2i(center) - Vector2i(180, 180), Vector2i(360, 360))
			var before: Image = stage.get_texture().get_image().get_region(capture)
			RA2Art._unit_shadow_cache.clear()
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var after: Image = stage.get_texture().get_image().get_region(capture)
			check(before.get_data() == after.get_data(), mode + id + ": stationary unit shadow survives cache eviction without black rectangle")
			if id == "MTNK":
				before.save_png(output_dir.path_join(mode + "-shadow-before-eviction.png"))
				after.save_png(output_dir.path_join(mode + "-shadow-after-eviction.png"))
			u.queue_redraw()
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var hull := RA2Art.art(id + "_shd")
			var turret := RA2Art.art(str(u._ra2_tur.key) + "_shd")
			var hashes := {}
			var union_ok := true
			for direction in 32:
				var tex := RA2Art.unit_shadow_texture(hull, turret, 0, direction)
				var merged := tex.get_image()
				var body: Image = hull.img.get_region(Rect2i(RA2Art.src_rect(hull, 0)))
				var top: Image = turret.img.get_region(Rect2i(RA2Art.src_rect(turret, direction)))
				for y in merged.get_height():
					for x in merged.get_width():
						union_ok = union_ok and is_equal_approx(merged.get_pixel(x,y).a, maxf(body.get_pixel(x,y).a, top.get_pixel(x,y).a))
				hashes[hash(merged.get_data())] = true
			check(union_ok, mode + id + ": hull/turret shadow union does not double opacity")
			check(hashes.size() > 8, mode + id + ": turret shadow turns independently of stationary hull", hashes.size())
		if id in ["ROBO", "MTNK", "FV", "SHAD", "BFRT"]:
			stage.get_texture().get_image().save_png(output_dir.path_join(mode + "-" + id + "-model.png"))
		battle.units.erase(u)
		u.free()
	check(RA2Art._unit_shadow_cache.size() <= 128, mode + ": rotating shadow cache remains bounded")
	HouseColor.set_player_id(previous)
	screen.free()
	await get_tree().process_frame
