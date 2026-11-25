extends "res://tests/base_recovery_regression.gd"

func _ready() -> void:
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not ProjectSettings.get_setting("application/config/use_custom_user_dir", false):
		get_tree().quit(2)
		return
	var original_m60: Dictionary = GameData.ra2_weapon("M60").duplicate(true)
	GameData.reload()
	check(GameData.units.filter(func(u): return u.id == "GGI").size() == 1, "reload does not duplicate Guardian GI")
	check(GameData.ra2_weapon("M60") == original_m60, "YR pack does not override base M60")
	var meta := RA2Art.art("GGI")
	check(not meta.is_empty() and meta.get("count", 0) == 744, "original 744-frame SHP loads")
	check(ResourceLoader.exists(GameData.ra2_cameo_path("GGI")), "production portrait imports")
	var seq := RA2Art.seq("GGI")
	for name in ["Guard", "Walk", "FireUp", "Deployed", "DeployedFire", "Die1"]:
		for direction in 8:
			var frame := RA2Art.seq_frame(seq, name, direction, 0)
			check(frame >= 0 and frame < 372, name + " valid body frame " + str(direction), frame)
	for mode in [MatchRules.RA2, MatchRules.EXTENDED]:
		await exercise(mode)
	var file := FileAccess.open(output_dir.path_join("result.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failed": failed}, "  "))
	file.close()
	get_tree().quit(0 if failed == 0 else 1)

func actor(id: String, side: String, at: Vector2):
	var unit = battle.spawn_unit(id, side, at)
	unit.process_mode = Node.PROCESS_MODE_ALWAYS
	unit.set_process(false)
	unit.set_physics_process(false)
	unit.order_stop()
	return unit

func damage_target(unit, target) -> float:
	var before: float = target.hp
	unit._cd_timer = 0.0
	unit._cancel_burst()
	unit.attack_target = target
	unit.attack_ordered = true
	unit._think_timer = 100.0
	unit.hull_angle = unit.position.direction_to(target.position).angle()
	unit.turret_angle = unit.hull_angle
	var host: Node = unit._pick_projectile_parent()
	var previous := host.get_children()
	for tick in 30:
		unit._physics_process(1.0 / 60.0)
		if host.get_child_count() > previous.size(): break
	var shots := host.get_children().filter(func(child): return not previous.has(child) and child is Projectile)
	check(shots.size() == 1, prefix + "combat update emits one real shot at " + target.unit_id, shots.size())
	for shot in shots:
		shot.process_mode = Node.PROCESS_MODE_DISABLED
		if unit.is_deployed():
			check(shot.ra2_homing and shot.ra2_aa and shot.ra2_image == "DRAGON", prefix + "deployed missile uses original homing/AA/image data")
		for tick in 240:
			if shot.is_queued_for_deletion(): break
			shot._physics_process(1.0 / 60.0)
		shot.free()
	return before - target.hp

func exercise(mode: String) -> void:
	start(mode)
	if battle.fog != null:
		battle.fog.free()
		battle.fog = null
	GM.god_mode = false
	GM.one_shot_kill = false
	GM.infinite_funds = false
	GM.no_build_time = false
	var data := GameData.get_unit("GGI")
	check(data.cost == 400 and data.hp == 100 and data.speed == 45, prefix + "original price health movement")
	check(not GameData.ra2_prereq_ok("GGI", []) and GameData.ra2_prereq_ok("GGI", ["GAPILE"]), prefix + "barracks prerequisite")
	check(not GameData.ra2_source_units.GGI.occupier, prefix + "explicit Occupier=no preserved")
	for kind in ["select", "move", "attack", "feedback", "die", "deploy", "undeploy"]:
		check(Ra2Sfx.has_voice(data, kind) and Ra2Sfx.play_voice(data, kind, Vector2.INF, 0), prefix + "original voice decodes and plays: " + kind)
	check(Ra2Sfx.play_weapon(data.deployed_weapon, Vector2.INF), prefix + "deployed launch sound decodes and plays")
	var barracks = battle._place_building("GAPILE", "ally", Vector2(800, 700), true)
	barracks._buildup_play = -1.0
	barracks.process_mode = Node.PROCESS_MODE_DISABLED
	check(barracks.can_queue("GGI") and barracks.enqueue("GGI"), prefix + "actual barracks accepts GGI")
	var before: float = battle.funds
	for tick in 300:
		barracks._process(0.1)
		if barracks.production.is_empty(): break
	check(barracks.production.is_empty() and battle.units.any(func(u): return is_instance_valid(u) and u.unit_id == "GGI"), prefix + "paid production spawns Guardian GI")
	check(absf(before - battle.funds - 400.0) < 0.01, prefix + "production charges exactly 400", before - battle.funds)
	for side in ["ally", "enemy"]:
		var enemy := "enemy" if side == "ally" else "ally"
		var origin := Vector2(1500, 1200)
		var unit = actor("GGI", side, origin)
		var tank = actor("MTNK", enemy, origin + Vector2(200, 0))
		var air = actor("JUMPJET", enemy, origin + Vector2(200, 160))
		await get_tree().physics_frame
		check(unit._active_weapon().name == "M60" and not unit._weapon_domain_valid(air), prefix + side + "standing machinegun excludes air")
		check(damage_target(unit, tank) > 0, prefix + side + "standing gun damages ground")
		unit.deploy()
		check(unit.is_deployed() and not unit.crushable and not unit.is_prone(), prefix + side + "deployed protected stance is not prone")
		check(unit.attack_range == 440 and unit.min_range == 55 and unit.can_hit_air, prefix + side + "missile range minimum range and AA")
		check(unit._active_weapon().name == "MissileLauncher", prefix + side + "deployment switches weapon")
		check(damage_target(unit, tank) > 0, prefix + side + "deployed missile damages armor")
		check(damage_target(unit, air) > 0, prefix + side + "deployed missile damages aircraft")
		var close = actor("MTNK", enemy, origin + Vector2(30, 0))
		check(not unit._weapon_target_valid(close), prefix + side + "minimum range blocks close target")
		close.velocity = Vector2(100, 0)
		close.position = unit.position
		close._crush_tick(0.2)
		check(unit.hp > 0, prefix + side + "real crusher cannot kill deployed GGI")
		close.position += Vector2(0, 300)
		unit.order_move(origin + Vector2(400, 0))
		unit._physics_process(0.1)
		check(unit.position.distance_to(origin) < 0.01 and not unit.has_move_order and not unit.crushable, prefix + side + "deployment remains immobile and uncrushable after tick")
		unit._grant_veteran(2, false)
		check(unit._active_weapon().name == "MissileLauncherE" and unit._active_weapon().damage == 50, prefix + side + "elite deployed weapon")
		unit.set_deployed(false)
		check(unit._active_weapon().name == "M60E" and not unit.can_hit_air and unit.crushable, prefix + side + "undeploy restores elite machinegun and crushability")
		close.position = unit.position
		close._crush_tick(0.2)
		check(unit.hp <= 0, prefix + side + "real crusher kills standing GGI")
		for item in [unit, tank, air, close]:
			if is_instance_valid(item): item.free()
	if DisplayServer.get_name() != "headless":
		await render_preview(mode)
	await finish()

func render_preview(mode: String) -> void:
	var previous_color := HouseColor.player_id
	HouseColor.set_player_id("purple" if mode == MatchRules.EXTENDED else "blue")
	var center := Vector2(1500, 1500)
	battle.camera.position = center
	battle.camera.zoom = Iso.cam_zoom(1.6)
	battle.camera.rotation = Iso.cam_angle()
	battle.camera.reset_smoothing()
	battle.camera.force_update_scroll()
	screen.hud.hide()
	for row in 2:
		for facing in 8:
			var unit = actor("GGI", "ally", center + RA2Art.art_dir(Vector2((facing - 3.5) * 65, (row - 0.5) * 85)))
			unit.hull_angle = float(facing) * TAU / 8.0
			unit.turret_angle = unit.hull_angle
			unit.set_deployed(row == 1)
			unit._fire_anim_time = 0.15 if facing % 2 else -1.0
			unit.queue_redraw()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png(output_dir.path_join(mode + "-ggi-poses.png")) == OK, mode + " real eight-direction stance rendering captured")
	HouseColor.set_player_id(previous_color)
