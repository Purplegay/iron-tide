extends "res://tests/allied_abilities_regression.gd"
const Impact = preload("res://scripts/units/ra3_gunship_impact.gd")

func frame(model, label: String) -> Image:
	for i in 3:
		model.viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
	var image: Image = model.viewport.get_texture().get_image()
	image.save_png(output_dir.path_join(label + ".png"))
	return image

func shades(before: Image, after: Image) -> Array[int]:
	var dark := 0
	var unchanged := 0
	for y in range(0, before.get_height(), 2):
		for x in range(0, before.get_width(), 2):
			var a := before.get_pixel(x,y)
			var b := after.get_pixel(x,y)
			if minf(a.a,b.a) < 0.9: continue
			var diff := a.get_luminance() - b.get_luminance()
			if diff > 0.015: dark += 1
			if absf(diff) < 0.006: unchanged += 1
	return [dark, unchanged]

func exercise_mode(mode: String) -> void:
	if mode == MatchRules.RA2: return
	setup_logistics_scene(mode, "苏俄")
	for node in battle.units + battle.buildings: node.free()
	battle.units.clear()
	battle.buildings.clear()
	if battle.fog != null: battle.fog.free(); battle.fog = null
	var origin := Vector2(1900,1900)
	battle.camera.position = origin
	battle.camera.zoom = Iso.cam_zoom(2.8)
	battle.camera.reset_smoothing()
	battle.camera.force_update_scroll()
	var tank = actor("R3APOC", "ally", origin)
	var model = tank._ra3_model
	model.set_process(false)
	var shadow = model.ground_shadow
	shadow.set_process(false)
	tank.turret_angle = 0.9
	model._sample(0.1)
	model.sync_pose()
	shadow.refresh()
	var sun: DirectionalLight3D = model.surface_lighting.lights[0]
	check(sun.shadow_enabled, "visible tank has a sun shadow pass")
	for row in shadow.silhouettes: row.original.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var baseline := await frame(model, "unshadowed")
	for row in shadow.silhouettes: row.original.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var self_shadow := await frame(model, "self-shadow")
	var diff := shades(baseline, self_shadow)
	check(diff[0] > 10 and diff[1] > 100, "turret and hull cast local shadows; lit paint stays stable", diff)
	var factory = battle._place_building("NAWEAP", "ally", origin + Vector2(100,55), true)
	factory._buildup_play = -1
	shadow.building_clock = 0
	shadow.refresh()
	var covered := await frame(model, "factory-shadow")
	diff = shades(self_shadow, covered)
	check(shadow.proxies.size() > 0 and diff[0] > 20, "near sunward factory shades actual vehicle pixels", diff)
	factory.position = origin + Vector2(750,500)
	shadow.building_clock = 0
	shadow.refresh()
	var clear := await frame(model, "clear")
	check(shades(covered, clear)[0] == 0 and shades(clear,covered)[0] > 20, "moving caster away clears its shadow")
	var high = actor("R3HARBINGER","ally",origin)
	var high_shadow = high._ra3_model.ground_shadow
	factory.position = origin + Vector2(100,55)
	high.logistics.air_lift = 1.0
	high_shadow.refresh()
	check(high_shadow.proxies.all(func(p): return not p.visible), "aircraft above factory roof receives no ground-building shadow")
	battle._ensure_visual_layers()
	var post = battle._post_layer
	check(post.layer < screen.hud.layer and post.exposure_ev == 0.0, "exposure world pass below HUD")
	var fx = Impact.spawn(battle,origin,false)
	fx.set_process(false)
	for i in 10:
		fx.age = i / 60.0
		fx._sample()
		post._process(1.0/60.0)
	check(post.exposure_ev > 0.01, "real visible cannon flash changes exposure", post.exposure_ev)
	var peak: float = post.exposure_ev
	post.set_process(false)
	var hud_point: Vector2i = screen.hud.unit_menu_toggle.get_global_rect().get_center()
	stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	post.grade.set_shader_parameter("exposure_ev", 0.0)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var reference: Image = stage.get_texture().get_image()
	post.grade.set_shader_parameter("exposure_ev", peak)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var adapted: Image = stage.get_texture().get_image()
	var world_darkened := 0
	for y in range(150, 480, 9):
		for x in range(450, 1000, 9):
			if reference.get_pixel(x,y).get_luminance() - adapted.get_pixel(x,y).get_luminance() > 0.004:
				world_darkened += 1
	check(world_darkened > 50 and reference.get_pixelv(hud_point) == adapted.get_pixelv(hud_point), "visible flash adjusts battlefield pixels while HUD is unchanged", world_darkened)
	reference.save_png(output_dir.path_join("neutral-exposure.png"))
	adapted.save_png(output_dir.path_join("flash-exposure.png"))
	battle.paused = true
	post._process(1.0)
	check(post.exposure_ev == peak, "pause holds exposure")
	battle.paused = false
	fx.free()
	for i in 200: post._process(1.0/60.0)
	check(post.exposure_ev == 0.0, "exposure recovers to neutral")
	var distant = Impact.spawn(battle,origin + Vector2(2400,2400),false)
	distant._sample()
	post._process(0.1)
	check(post.exposure_ev == 0.0, "offscreen explosion does not meter")
	PostLayer.bright_flash(battle,tank,origin,350.0,2.0)
	post._process(0.05)
	var snapshot := BattleSaves.Snapshot.new().capture(battle)
	BattleSaves.Snapshot.new().restore(battle,snapshot)
	check(post.exposure_ev == 0.0 and post.samples.is_empty(), "load clears prior explosion exposure")
	screen.free()
	await get_tree().process_frame
