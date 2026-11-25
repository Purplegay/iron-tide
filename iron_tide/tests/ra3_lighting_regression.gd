extends "res://tests/allied_abilities_regression.gd"
const Lighting = preload("res://scripts/units/ra3_lighting.gd")

func capture_shadow(model, name: String) -> Image:
	model.sync_pose(true)
	model.ground_shadow.refresh()
	model.viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	for i in 3: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = model.ground_shadow.capture.get_texture().get_image()
	image.save_png(output_dir.path_join(name + "-shadow.png"))
	model.viewport.get_texture().get_image().save_png(output_dir.path_join(name + "-model.png"))
	return image

func exercise_mode(mode: String) -> void:
	if mode == MatchRules.RA2: return
	check(Lighting.source.lights.size() == 3, "official sun and two accent lights imported")
	check(Lighting.source.lights[0].Ambient == [0.21961, 0.20392, 0.17255], "official afternoon ambient preserved")
	check(Lighting.sun_direction().y < -0.4, "SAGE z-up sunlight converts to Godot down direction")
	if DisplayServer.get_name() == "headless":
		check(false, "lighting and shadow acceptance requires a rendered run")
		return
	setup_logistics_scene(mode, "美国")
	for node in battle.units + battle.buildings: node.free()
	battle.units.clear(); battle.buildings.clear()
	if battle.fog != null: battle.fog.free(); battle.fog = null
	battle.camera.position = Vector2(1800, 1800)
	battle.camera.zoom = Iso.cam_zoom(2.0)
	var units: Array = []
	for id in [Ra3Mirage.ID, Ra3Expansion.FUTURE, Ra3Expansion.HARBINGER]:
		var unit = actor(id, "ally", Vector2(1700 + units.size() * 140, 1800))
		units.append(unit)
		unit.special.reveal = 60.0
		var model = unit._ra3_model
		model.set_process(false); model.ground_shadow.set_process(false)
		var shadow = model.ground_shadow
		check(shadow.silhouettes.size() >= 2, id + " native body and tread/wing meshes cast shadow")
		check(model.camera.cull_mask == 1 and shadow.shadow_camera.cull_mask == 2, id + " shadow geometry excluded from body and picking")
		var originals := true
		for pair: Dictionary in shadow.silhouettes:
			originals = originals and pair.copy.mesh == pair.original.mesh and pair.copy.skin == pair.original.skin
		check(originals, id + " shadow reuses original mesh and skin")
		var first := await capture_shadow(model, id + "-front")
		var bounds := first.get_used_rect()
		check(bounds.has_area() and bounds.position.x > 0 and bounds.position.y > 0 and bounds.end.x < first.get_width() and bounds.end.y < first.get_height(), id + " visible shadow fits capture")
		unit.hull_angle += PI * 0.5
		var turned := await capture_shadow(model, id + "-turned")
		var changed := 0
		for y in first.get_height():
			for x in first.get_width():
				if absf(first.get_pixel(x, y).a - turned.get_pixel(x, y).a) > 0.2: changed += 1
		check(changed > 200, id + " actual silhouette changes with heading", changed)
		unit.visible = false; shadow.refresh()
		check(not shadow.visible and shadow.capture.render_target_update_mode == SubViewport.UPDATE_DISABLED, id + " hidden actors leave no shadow or render workload")
		unit.visible = true; shadow.refresh()
		check(shadow.visible, id + " visibility restoration restores shadow")
		if unit.is_air:
			var before_lift: float = unit.logistics.air_lift
			unit.logistics.air_lift = 0.0
			model.sync_pose(true); shadow.refresh()
			var ground: Rect2 = shadow.rect
			var ground_alpha: float = shadow.material.get_shader_parameter("opacity")
			unit.logistics.air_lift = 1.0
			model.sync_pose(true); shadow.refresh()
			check(shadow.rect.position.distance_to(ground.position) > 10, "aircraft altitude shifts shadow along sunlight")
			check(float(shadow.material.get_shader_parameter("opacity")) < ground_alpha, "aircraft altitude softens shadow opacity")
			unit.logistics.air_lift = before_lift
			model.sync_pose(true); shadow.refresh()
	for i in 3: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	stage.get_texture().get_image().save_png(output_dir.path_join("lighting-battle.png"))
	var mirage = units[0]
	mirage._ra3_model.disguise_blend = 1.0
	mirage._ra3_model.ground_shadow.refresh()
	check(is_equal_approx(mirage._ra3_model.ground_shadow.material.get_shader_parameter("opacity"), 0.18), "owner disguise fades tank shadow with native body opacity")
	var ra2 = actor("MTNK", "ally", Vector2(1800, 1900))
	check(ra2._ra3_model == null, "RA2 sprites keep existing rendering")
	screen.free(); Music.stop(); Ra2Sfx.stop_all()
	await get_tree().process_frame
