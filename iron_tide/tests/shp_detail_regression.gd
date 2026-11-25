extends "res://tests/logistics_regression.gd"
const Detail = preload("res://scripts/core/shp_detail.gd")

func capture() -> Image:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	return stage.get_texture().get_image()

func exercise_mode(mode: String) -> void:
	check(DisplayServer.get_name() != "headless", mode + ": actual rendering required")
	if DisplayServer.get_name() == "headless": return
	var sprites := 0
	var frames := 0
	for filename in DirAccess.get_files_at(Detail.ROOT):
		if not filename.ends_with(".json") or filename == "manifest.json": continue
		var id := filename.trim_suffix(".json")
		var art := RA2Art.art(id)
		var detail: Dictionary = art.get("detail", {})
		check(not detail.is_empty(), mode + id + ": SHP detail map loaded")
		if detail.is_empty(): continue
		check(art.rects.size() == detail.frames.size(), mode + id + ": all original animation frames retained")
		var aligned := true
		for i in detail.frames.size():
			var entry: Dictionary = detail.frames[i]
			var source: Array = entry.source
			aligned = aligned and RA2Art.src_rect(art, i) == Rect2(source[0],source[1],source[2],source[3])
			if int(entry.page) < 0: continue
			var page: Dictionary = detail.pages[int(entry.page)]
			var uv: Array = entry.rect
			var crop: Array = entry.crop
			aligned = aligned and Vector2(uv[2],uv[3]) == Vector2(crop[2],crop[3]) * 2.0
			aligned = aligned and Rect2(0,0,page.width,page.height).encloses(Rect2(uv[0],uv[1],uv[2],uv[3]))
		check(aligned, mode + id + ": every crop maps into its page at native logical coordinates")
		for page in detail.pages:
			check(ResourceLoader.exists(Detail.ROOT + str(page.file)) and int(page.width) <= 2048 and int(page.height) <= 2048, mode + id + ": bounded imported detail page")
		sprites += 1
		frames += detail.frames.size()
	check(sprites == 111 and frames == 11181, mode + ": all current valid SHP atlases covered", [sprites,frames])
	setup_logistics_scene(mode, "美国")
	screen.hud.process_mode = Node.PROCESS_MODE_DISABLED
	for group in ["obstacles", "resource_nodes"]:
		for node in get_tree().get_nodes_in_group(group): node.free()
	for node in battle.units + battle.buildings: node.free()
	battle.units.clear(); battle.buildings.clear()
	battle.water_rects = []; battle.path_service.set_water([])
	battle.camera.position = Vector2(1600,1600)
	Iso.apply_to(battle.camera,3.0)
	battle.camera.reset_smoothing(); battle.camera.force_update_scroll()
	var old_color := HouseColor.player_id
	HouseColor.set_player_id("green" if mode == MatchRules.EXTENDED else "blue")
	for id in ["E1","GGI","GHOST","TANY","JUMPJET","DLPH","GAPOWR","GAREFN","GAWEAP","GADEPT","GAAIRC","GAYARD","GACNST"]:
		var building: bool = id.begins_with("GA")
		var actor = battle._place_building(id,"ally",Vector2(1600,1600),true) if building else battle.spawn_unit(id,"ally",Vector2(1600,1600))
		actor.process_mode = Node.PROCESS_MODE_DISABLED
		if building: actor._buildup_play = -1.0
		else: actor.order_stop()
		var art_list: Array = [actor._ra2]
		if building:
			for layer in actor._ra2_anim:
				var a := RA2Art.art(str(layer.image))
				if not a in art_list: art_list.append(a)
		actor.queue_redraw()
		var enhanced := await capture()
		check(actor.has_meta("shp_detail_textures"), mode + id + ": real actor consumed detail pages")
		var anchor := RA2Art.anchor(actor._ra2,[0])
		var position_before: Vector2 = actor.position
		var hp_before: float = actor.hp
		var saved: Array = []
		for art in art_list:
			saved.append(art.get("detail",{})); art["detail"] = {}
		actor.queue_redraw()
		var native := await capture()
		check(native.get_region(Rect2i(570,210,460,420)).get_data() != enhanced.get_region(Rect2i(570,210,460,420)).get_data(), mode + id + ": actual enhanced render differs from native")
		check(RA2Art.anchor(actor._ra2,[0]) == anchor and actor.position == position_before and actor.hp == hp_before, mode + id + ": original geometry and game state preserved")
		for i in art_list.size(): art_list[i]["detail"] = saved[i]
		actor.queue_redraw()
		var retained := await capture()
		Detail.clear_cache()
		var evicted := await capture()
		check(retained.get_region(Rect2i(570,210,460,420)).get_data() == evicted.get_region(Rect2i(570,210,460,420)).get_data(), mode + id + ": stationary draw survives shared texture cache eviction")
		if not building: check(actor.hit_test(RA2Art.visible_unit_center(actor.global_position, actor._ra2, actor.radius, actor._art_aframes, actor._art_frame, actor._art_lift, actor._art_sc)), mode + id + ": visible body pixel remains selectable")
		if mode == MatchRules.RA2 and id in ["E1","GAWEAP","GAREFN"]:
			native.get_region(Rect2i(570,210,460,420)).save_png(output_dir.path_join(id+"-native.png"))
			enhanced.get_region(Rect2i(570,210,460,420)).save_png(output_dir.path_join(id+"-detail.png"))
		if building: battle.buildings.erase(actor)
		else: battle.units.erase(actor)
		actor.free()
	check(Detail._bytes <= Detail.CACHE_BYTES, mode + ": shared page cache stays bounded")
	HouseColor.set_player_id(old_color)
	screen.free()
	await get_tree().process_frame
