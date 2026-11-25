extends "res://tests/allied_abilities_regression.gd"

func exercise_mode(mode: String) -> void:
	if mode == MatchRules.RA2: return
	setup_logistics_scene(mode, "苏俄")
	if battle.fog != null: battle.fog.free(); battle.fog = null
	for id in ["R3APOC", "R3MIRAGE", "R3FUTURE", "R3HARBINGER"]:
		var unit = actor(id, "ally", battle.camera.position)
		var model = unit._ra3_model
		check(model != null, id + " uses actual GPU renderer")
		if model == null: continue
		unit.set_selected(true)
		battle.camera.zoom = Iso.cam_zoom(1.0)
		battle.camera.force_update_scroll()
		model._process(0.1)
		var logical: Rect2 = model.draw_rect
		var near_zoom := 3.2
		battle.camera.zoom = Iso.cam_zoom(near_zoom)
		battle.camera.force_update_scroll()
		model._process(0.1)
		unit.queue_redraw()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var width: float = logical.size.x * preload("res://scripts/units/ra3_fx_resolution.gd").pixel_density(unit)
		var expected := clampi(ceili(width / 128.0) * 128, 384, 1024)
		check(model.viewport.size.x == expected and (logical.size.x <= 120 or expected > 384), id + " viewport follows projected pixels", [width,expected,model.viewport.size.x])
		check(model.draw_rect == logical, id + " zoom retains world-space size and origin")
		check(model.body_mask != null and model.body_mask.size == model.viewport.size, id + " outline resolution matches model")
		var image: Image = model.viewport.get_texture().get_image()
		image.save_png(output_dir.path_join(id + "-surface.png"))
		var used := image.get_used_rect()
		check(used.has_area() and image.get_width() == expected, id + " rendered nonempty native mesh")
		if id == "R3APOC":
			var body = load("res://assets/ra3/soviet/R3APOC/SUAntiAirVehicleTech3.png").get_image()
			check(body.get_width() == 512 and body.has_mipmaps(), "native 512px tank texture retains a full mip chain")
			image.save_png(output_dir.path_join("apocalypse-close.png"))
			var armor: ShaderMaterial = model.parts.NEWSKIN.material_override
			var tracks: ShaderMaterial = model.parts.NEWSKIN_TREADS.material_override
			var environment: Cubemap = armor.get_shader_parameter("environment_map")
			check(environment != null and environment.get_layers() == 6 and environment.get_width() == 64 and environment.get_format() == Image.FORMAT_RGBAH, "retail EVDefault retains six HDR faces")
			check(tracks.get_shader_parameter("alpha_test") and not armor.get_shader_parameter("alpha_test"), "material alpha test follows tread and hull definitions")
			var skin: Texture2D = armor.get_shader_parameter("diffuse_map")
			unit.hp = unit.max_hp * 0.1
			model._sample(0.1)
			check(armor.get_shader_parameter("diffuse_map") != skin and armor.get_shader_parameter("environment_map") == environment, "damaged skin keeps native environment")
			unit.hp = unit.max_hp
			model._sample(0.1)
		if id == "R3APOC":
			stage.size_2d_override = Vector2i(1600, 900)
			stage.size_2d_override_stretch = true
			stage.size = Vector2i(3840, 2160)
			await get_tree().process_frame
			battle.camera.force_update_scroll()
			model._process(0.1)
			await RenderingServer.frame_post_draw
			image = model.viewport.get_texture().get_image()
			check(image.get_width() == 1024 and model.body_mask.size == Vector2i(1024,1024), "4K close view reaches bounded 1024px capture", image.get_width())
			var center := image.get_used_rect().get_center()
			var pixel := Vector2i(-1,-1)
			for x in range(image.get_width()):
				if image.get_pixel(x,center.y).a > 0.8:
					pixel = Vector2i(x, center.y)
					break
			var point: Vector2 = model.draw_rect.position + (Vector2(pixel) + Vector2(0.5,0.5)) / Vector2(image.get_size()) * model.draw_rect.size
			check(pixel.x >= 0 and model.hits(unit.global_position + RA2Art.art_dir(point)), "resized opaque hull remains selectable")
			image.save_png(output_dir.path_join("apocalypse-4k.png"))
			stage.size = Vector2i(1600, 900)
			stage.size_2d_override = Vector2i.ZERO
			stage.size_2d_override_stretch = false
		if id in ["R3FUTURE","R3HARBINGER"]:
			var primary: ShaderMaterial = model.materials[0]
			check(primary.shader == model.OBJECT_SHADER and primary.get_shader_parameter("environment_map") == model.ENV_DEFAULT, id + " Allied hull uses retail environment")
			if id == "R3FUTURE":
				unit.special.ra3_attack_age = 0.01
			else:
				unit.special.ra3_gun_mode = false
				unit.special.ra3_mounts = {"side":{"flash":0.5},"rear":{"flash":0.5}}
			model._sample(0.0)
			var count: int = primary.get_shader_parameter("muzzle_light_count")
			check(count == (1 if id == "R3FUTURE" else 2), id + " firing illuminates the high material")
			model.viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
			await RenderingServer.frame_post_draw
			var lit: Image = model.viewport.get_texture().get_image()
			for light in model.fire_lights: light.hide()
			model._sync_surface_muzzle_lights()
			model.viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
			await RenderingServer.frame_post_draw
			var dark: Image = model.viewport.get_texture().get_image()
			check(primary.get_shader_parameter("muzzle_light_count") == 0 and lit.get_data() != dark.get_data(), id + " muzzle illumination changes rendered pixels and clears")
		if id == "R3MIRAGE":
			check(model._body_material.shader == model.OBJECT_SHADER and model._tread_material.get_shader_parameter("alpha_test"), "Mirage body and treads use retail alpha test")
		unit.hide()
		model._process(0.1)
		check(model.viewport.size.x == 384 and model.viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, id + " hidden model releases enlarged target")
		remove_actor(unit)
	screen.free()
	await get_tree().process_frame
