extends "res://tests/allied_abilities_regression.gd"
const Resolution = preload("res://scripts/units/ra3_fx_resolution.gd")
const Soviet = preload("res://scripts/units/ra3_soviet.gd")

func check_capture(fx, width: float, baseline: int, label: String) -> void:
	var wanted := Resolution.side(width, Resolution.pixel_density(fx), get_tree().get_node_count_in_group("ra3_weapon_fx_captures"), baseline)
	check(fx.viewport.size.x >= wanted and fx.viewport.size.x > baseline, label + " scales to projected footprint", [baseline, wanted, fx.viewport.size.x])
	fx.viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = fx.viewport.get_texture().get_image()
	check(image != null and image.get_used_rect().has_area(), label + " renders visible pixels")

func exercise_mode(mode: String) -> void:
	if mode == MatchRules.RA2: return
	setup_logistics_scene(mode, "美国")
	if battle.fog != null: battle.fog.free(); battle.fog = null
	stage.size_2d_override = Vector2i(1600,900)
	stage.size_2d_override_stretch = true
	stage.size = Vector2i(3840,2160)
	await get_tree().process_frame
	battle.camera.zoom = Iso.cam_zoom(3.2)
	battle.camera.force_update_scroll()
	var origin: Vector2 = battle.camera.position
	var tank = actor("R3FUTURE", "ally", origin)
	var enemy = actor("MTNK", "enemy", origin + Vector2(350,0))
	var bomb := Ra3Expansion.make_shot(tank, null, enemy.position, "neutron")
	bomb.set_physics_process(false)
	Ra3Expansion.tick_shot(bomb, 0.03)
	var flight = bomb.get_node("NativeFlightFx")
	await check_capture(flight, flight.draw_size, 256, "neutron projectile")
	for step in 300:
		Ra3Expansion.tick_shot(bomb, 1.0/60)
		if bomb.has_node("NativeFx"): break
	var blast = bomb.get_node("NativeFx")
	Ra3Expansion.tick_shot(bomb, 1.8)
	blast._process(0.05)
	await check_capture(blast, blast.draw_size, 384, "neutron blast")
	bomb.free()
	var gunship = actor("R3HARBINGER","ally",origin)
	var shell := Ra3Expansion.make_shot(gunship,enemy,enemy.position,"shell")
	shell.set_physics_process(false)
	Ra3Expansion.tick_shot(shell, 0.01)
	var round_fx = shell.get_node("NativeFx")
	await check_capture(round_fx, round_fx.size, 96, "gunship shell")
	shell.free()
	var reaper = actor("R3REAPER","ally",origin)
	reaper.special.soviet_mounts = {}
	for kind in ["rocket","grenade1"]:
		Soviet.volley(reaper, enemy, kind, 1, 0.2, 2.0, 15, 450)
		var shot = battle.projectiles_root.get_children().back()
		shot.set_physics_process(false)
		Soviet.advance(shot,shot.splinters.duration*0.35)
		var visual = shot.get_node("ReaperRound")
		await check_capture(visual, visual.SIZE, 96, "reaper " + kind)
		shot.free()
	check(Resolution.side(48,1,1,96) == 96, "small distant shell keeps original allocation")
	check(Resolution.side(INF,1,256,96)**2 * 256 <= Resolution.PIXEL_BUDGET, "large volley shares capture budget")
	screen.free()
	await get_tree().process_frame
