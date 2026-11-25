extends "res://tests/base_recovery_regression.gd"
const Preview = preload("res://scripts/world/attack_range_preview.gd")

func _ready() -> void:
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not ProjectSettings.get_setting("application/config/use_custom_user_dir", false):
		get_tree().quit(2)
		return
	get_window().size = Vector2i(1280, 720)
	for mode in [MatchRules.RA2, MatchRules.EXTENDED]:
		await exercise_ranges(mode)
	var file := FileAccess.open(output_dir.path_join("result.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failed": failed}, "  "))
	file.close()
	get_tree().quit(0 if failed == 0 else 1)

func exercise_ranges(mode: String) -> void:
	start(mode)
	if battle.fog != null:
		battle.fog.free()
		battle.fog = null
	var center := Vector2(1200, 1200)
	var tank = battle.spawn_unit("MTNK", "ally", center)
	var enemy = battle.spawn_unit("MTNK", "enemy", center)
	battle.select_unit(tank, false)
	var rings := Preview.ranges(battle)
	check(rings.size() == 1 and rings[0].center == tank.global_position, prefix + "single selection centers range on real firing origin")
	var radius: float = rings[0].radius
	enemy.global_position = center + Vector2(radius, 0)
	check(tank._weapon_target_valid(enemy), prefix + "outer boundary matches actual inclusive target check")
	enemy.global_position.x += 1.0
	check(not tank._weapon_target_valid(enemy), prefix + "just outside displayed range cannot fire")
	tank.global_position += Vector2(40, 30)
	check(Preview.ranges(battle)[0].center == tank.global_position, prefix + "ring follows movement without cached origin")
	tank._grant_veteran(2, false)
	check(Preview.ranges(battle)[0].radius == tank.attack_range and tank.attack_range == float(tank._active_weapon().range), prefix + "promotion follows current elite weapon")
	tank.fire_stance = "none"
	check(not Preview.ranges(battle)[0].active, prefix + "hold fire dims range")
	tank.fire_stance = "free"
	var gi = battle.spawn_unit("E1", "ally", center + Vector2(180, 0))
	battle.select_unit(gi, false)
	var standing: float = Preview.ranges(battle)[0].radius
	check(gi.set_deployed(true), prefix + "real GI deploy action accepted")
	check(Preview.ranges(battle)[0].radius == gi.attack_range and gi.attack_range > standing, prefix + "deployed GI range updates immediately")
	battle.select_unit(tank, true)
	check(Preview.ranges(battle).size() == 2, prefix + "multi selection includes both independent centers")
	await picture(mode + "-squad", center)
	battle.cast_slot = 0
	check(Preview.ranges(battle).is_empty(), prefix + "skill targeting suppresses weapon rings")
	battle.cast_slot = -1
	battle.armed_build = "GAPOWR"
	check(Preview.ranges(battle).is_empty(), prefix + "placement suppresses selection range clutter")
	battle.armed_build = ""
	var transport = battle.spawn_unit("LCRF", "ally", center)
	tank.embarked_in = transport
	battle.selected_units = [tank]
	check(Preview.ranges(battle).is_empty(), prefix + "stowed units show no firing range")
	tank.embarked_in = null
	battle.selected_units = [enemy]
	check(Preview.ranges(battle).is_empty(), prefix + "enemy references never expose range through fog")
	var miner = battle.spawn_unit("CMIN", "ally", center)
	battle.select_unit(miner, false)
	check(Preview.ranges(battle).is_empty(), prefix + "economy units show no attack ring")
	var cannon = battle._place_building("GTGCAN", "ally", center, true)
	cannon._buildup_play = -1.0
	battle.select_building(cannon)
	rings = Preview.ranges(battle)
	check(rings.size() == 1 and rings[0].radius == cannon.attack_range, prefix + "defense uses actual range")
	var minimum: float = rings[0].minimum
	check(minimum > 0.0 and minimum == float(cannon.weapon.min_range), prefix + "grand cannon exposes real minimum range")
	enemy.global_position = center + Vector2(minimum, 0)
	check(cannon._valid_weapon_target(enemy), prefix + "minimum boundary permits valid target")
	enemy.global_position.x -= 1.0
	check(not cannon._valid_weapon_target(enemy), prefix + "inner blind zone rejects actual target")
	battle.power_low = false
	await picture(mode + "-defense", center)
	# Test true is_operational power gating, not a copied display-only flag.
	cannon.powered = true
	battle.power_low = true
	check(not cannon.is_operational() and not Preview.ranges(battle)[0].active, prefix + "power outage dims the actual defense")
	await picture(mode + "-offline", center)
	battle.select_building(battle._player_hq())
	check(Preview.ranges(battle).is_empty(), prefix + "unarmed base has no range")
	battle.select_unit(tank, false)
	tank.hp = 0.0
	check(Preview.ranges(battle).is_empty(), prefix + "dead selection removes ring")
	battle.clear_selection()
	battle.queue_redraw()
	await get_tree().process_frame
	check(Preview.ranges(battle).is_empty(), prefix + "clearing selection removes all ranges")
	var projection := Transform2D(0.6, Vector2(2, 0.8), 0.0, Vector2(320, 180))
	var points := Preview.circle(center, radius, projection)
	var error := 0.0
	for point in points:
		error = maxf(error, absf((projection.affine_inverse() * point).distance_to(center) - radius))
	check(error < 0.001 and points[0].distance_to(points[-1]) < 0.001, prefix + "projected boundary preserves world radius under zoom and oblique view", error)
	await finish()

func picture(label: String, center: Vector2) -> void:
	battle.camera.position = center
	battle.camera.zoom = Iso.cam_zoom(0.9)
	battle.camera.reset_smoothing()
	battle.camera.force_update_scroll()
	battle._emit_selection()
	battle.queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(output_dir.path_join(label + ".png"))
