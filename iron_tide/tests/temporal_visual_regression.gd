extends "res://tests/allied_abilities_regression.gd"

func image_now() -> Image:
	await get_tree().process_frame
	if DisplayServer.get_name() == "headless": return null
	await RenderingServer.frame_post_draw
	return stage.get_texture().get_image()

func pixel_changes(a: Image, b: Image, rect: Rect2i) -> int:
	var count := 0
	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):
			if a.get_pixel(x, y) != b.get_pixel(x, y): count += 1
	return count

func exercise_mode(mode: String) -> void:
	setup_logistics_scene(mode, "美国")
	battle.water_rects = []
	battle.path_service.set_water([])
	battle.camera.position = Vector2(1600, 1600)
	battle.camera.zoom = Iso.cam_zoom(1.5)
	battle.camera.reset_smoothing()
	battle.camera.force_update_scroll()
	for id in ["E1", "MTNK", "GAPOWR"]:
		var tag: String = mode + " " + id + ": "
		var target
		if id == "GAPOWR":
			target = battle._place_building(id, "ally", Vector2(1600, 1600), true)
			target.process_mode = Node.PROCESS_MODE_DISABLED
			target._buildup_play = -1.0
		else:
			target = actor(id, "ally", Vector2(1600, 1600))
		var chrono = actor("CLEG", "enemy", Vector2(1400, 1600))
		var neighbor = actor("MTNK", "ally", Vector2(1900, 1600))
		if id == "MTNK":
			# Exercise the cached non-default house material as well as null/base blue.
			target.material = HouseColor.material_for(Color(0.8, 0.2, 0.5))
			neighbor.material = target.material
		var original: Material = target.material
		var neighbor_material: Material = neighbor.material
		var normal := await image_now()
		if normal != null: normal.save_png(output_dir.path_join(mode + "-" + id + "-normal.png"))
		chrono.attack_target = target
		chrono._fire_shot(target)
		check(target.material is ShaderMaterial and target.material != original, tag + "first shot installs isolated frozen material")
		check(neighbor.material == neighbor_material, tag + "same-house neighbor keeps its material")
		if original is ShaderMaterial:
			check(not original.get_shader_parameter("temporal_active"), tag + "cached house material remains unchanged")
		var frozen := await image_now()
		if frozen != null:
			# Target footprint only; the shooter at x~590 changes facing when firing.
			var rect := Rect2i(650, 250, 400, 270)
			check(pixel_changes(normal, frozen, rect) > 50, tag + "renderer changes visible target pixels")
			frozen.save_png(output_dir.path_join(mode + "-" + id + "-frozen.png"))
		var hp_before: float = target.hp
		chrono.special.channel_fx = 100.0
		var half_time: float = target.max_hp * 0.5 / (float(chrono._active_weapon().damage) * 15.0)
		AlliedAbilities.channel(chrono, half_time)
		check(is_equal_approx(float(target.material.get_shader_parameter("temporal_progress")), 0.5), tag + "fade follows real erasure work")
		check(target.hp == hp_before, tag + "visual progression does not damage HP")
		var faded := await image_now()
		if faded != null:
			check(pixel_changes(frozen, faded, Rect2i(650, 250, 400, 270)) > 50, tag + "renderer shows progressive disappearance")
			faded.save_png(output_dir.path_join(mode + "-" + id + "-half.png"))
		chrono.order_stop()
		check(target.material == original and not target.has_meta(&"temporal_visual"), tag + "interrupt immediately restores material")
		var restored := await image_now()
		if restored != null:
			restored.save_png(output_dir.path_join(mode + "-" + id + "-restored.png"))
			var changed := pixel_changes(normal, restored, Rect2i(650, 250, 400, 270))
			check(changed == 0, tag + "cancel restores original rendered pixels", changed)
		chrono.attack_target = target
		chrono._fire_shot(target)
		chrono.special.erase("temporal_target")
		AlliedAbilities.tick_actor(target, 0.0)
		check(target.material == original and not target.special.has("temporal_by"), tag + "orphan channel clears visual and lock")
		target.special.chrono_left = 1.0
		AlliedAbilities.tick_actor(target, 0.0)
		check(target.material == original, tag + "teleport recovery is not target erasure")
		target.special.erase("chrono_left")
		chrono.attack_target = target
		chrono._fire_shot(target)
		chrono.special.channel_fx = 100.0
		AlliedAbilities.channel(chrono, half_time * 2.1)
		check(target._dead and target.is_queued_for_deletion(), tag + "completed erasure removes actor without corpse animation")
		check(not chrono.special.has("temporal_target"), tag + "completed erasure clears channel")
		remove_actor(chrono)
		remove_actor(neighbor)
		await get_tree().process_frame
	screen.free()
	await get_tree().process_frame
