extends "res://tests/command_voice_regression.gd"

var battle

func _ready() -> void:
	output = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output.is_empty() or not ProjectSettings.get_setting("application/config/use_custom_user_dir", false):
		get_tree().quit(2)
		return
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), true)
	capture.buffer_length = 2.0
	AudioServer.add_bus_effect(0, capture)
	for mode in [MatchRules.RA2, MatchRules.EXTENDED]:
		await construction(mode)
	var file := FileAccess.open(output.path_join("result.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failed": failed, "driver": AudioServer.get_driver_name()}, "  "))
	file.close()
	get_tree().quit(0 if failed == 0 else 1)

func placement(id: String) -> Vector2:
	var hq = battle._player_hq()
	for distance in [160, 240, 320, 440, 600, 800]:
		for direction in 24:
			var at: Vector2 = battle.snap_build_pos(hq.global_position + Vector2.RIGHT.rotated(TAU * direction / 24.0) * distance)
			if battle.build_spot_ok(at, GameData.get_building(id), true).ok: return at
	return Vector2.INF

func construction(mode: String) -> void:
	await reset()
	var before: int = Ra2Sfx.a_plays
	BattleRequest.configure_skirmish(mode, {"map_size": 3200, "starting_funds": 50000, "fog_of_war": true})
	var screen = load("res://scenes/battle.tscn").instantiate()
	add_child(screen)
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	battle = screen.battle
	check(Ra2Sfx.a_plays == before, mode + " initial map structures emit no placement sounds")
	# Disable unrelated simulation, but exercise real production and placement entries.
	for group in ["obstacles", "resource_nodes"]:
		for node in get_tree().get_nodes_in_group(group): node.free()
	for unit in battle.units: unit.free()
	battle.units.clear()
	battle.water_rects.clear()
	battle.path_service.water_rects.clear()
	battle._refresh_pathing()
	for building in battle.buildings: building._buildup_play = -1.0
	battle.power_low = false
	battle.funds = 50000
	battle.camera.position = Vector2(2200, 2200)
	battle.camera.zoom = Iso.cam_zoom(0.3)
	battle.camera.make_current()
	battle.camera.reset_smoothing()
	battle.camera.force_update_scroll()
	await get_tree().process_frame
	await reset()
	var eva_before: int = Ra2Sfx.a_eva_plays
	screen.hud._start_build("GAPOWR")
	check(battle.struct_queue.size() == 1 and Ra2Sfx.a_eva_plays == eva_before + 1, mode + " real HUD order announces Building once")
	check(await peak() > 0.001, mode + " build-order EVA has actual PCM")
	await reset()
	eva_before = Ra2Sfx.a_eva_plays
	battle._tick_structure_queue(1000.0)
	check(int(battle.struct_ready.get("GAPOWR", 0)) == 1 and Ra2Sfx.a_eva_plays > eva_before, mode + " paid completion announces ConstructionComplete")
	check(await peak() > 0.001, mode + " completion EVA has actual PCM")
	await reset()
	screen.hud._start_build("GAPOWR")
	check(battle.armed_build == "GAPOWR", mode + " ready HUD card arms placement")
	var money: float = battle.funds
	before = Ra2Sfx.a_plays
	battle._try_place_building(battle._player_hq().global_position)
	check(Ra2Sfx.a_plays == before and battle.armed_build == "GAPOWR" and int(battle.struct_ready.get("GAPOWR", 0)) == 1, mode + " rejected overlap is silent and preserves ready building")
	var pos := placement("GAPOWR")
	check(pos != Vector2.INF, mode + " legal footprint exists")
	if pos == Vector2.INF:
		screen.free()
		return
	battle._try_place_building(pos)
	check(Ra2Sfx.a_plays == before + 1 and battle.funds == money and not battle.struct_ready.has("GAPOWR"), mode + " placement emits exactly one sound without paying twice")
	check(Ra2Sfx._global_pool[0].playing and Ra2Sfx._global_pool[0].stream.get_length() > 1.4, mode + " placement uses original full-length global sound")
	check(await peak() > 0.001, mode + " placement PCM remains audible at distant camera and wide zoom")
	var placed = battle.buildings.back()
	for i in 5: placed._process(0.1)
	check(Ra2Sfx.a_plays == before + 1, mode + " buildup animation frames do not replay the sound")
	await get_tree().create_timer(1.1).timeout
	check(not Ra2Sfx._global_pool[0].playing, mode + " one-shot ends without an infinite loop")
	await reset()
	# Legacy in-place construction shares the same placement event.
	battle.armed_build = "GAPOWR"
	pos = placement("GAPOWR")
	before = Ra2Sfx.a_plays
	battle._try_place_building(pos)
	check(Ra2Sfx.a_plays == before + 1 and battle.buildings.back().under_construction, mode + " in-place construction also emits placement sound")
	await reset()
	# Hidden enemy placement must never reveal enemy activity through sound.
	pos = Vector2(1600, 1600)
	check(not battle.fog.is_visible_at("ally", pos), mode + " enemy fixture starts outside allied sight")
	before = Ra2Sfx.a_plays
	battle._place_building("GAPOWR", "enemy", pos, true, true)
	check(Ra2Sfx.a_plays == before and await peak() < 0.0001, mode + " hidden enemy construction is silent")
	battle.fog._reveal("ally", pos, 200.0)
	await reset()
	battle._place_building("GAPOWR", "enemy", pos, true, true)
	check(Ra2Sfx.a_plays == before + 1 and Ra2Sfx._pool[0].playing, mode + " visible enemy construction uses spatial sound")
	check(await peak() < 0.0001, mode + " distant visible enemy obeys attenuation")
	battle.camera.position = pos
	battle.camera.force_update_scroll()
	await get_tree().process_frame
	await reset()
	battle._place_building("GAPOWR", "enemy", pos, true, true)
	check(await peak() > 0.001, mode + " nearby visible enemy construction has actual PCM")
	await reset()
	var mcv = battle.spawn_unit("AMCV", "ally", Vector2(1600, 2300))
	check(battle.construction_deploy_check(mcv).ok, mode + " MCV has valid deployment footprint")
	before = Ra2Sfx.a_plays
	money = battle.funds
	check(battle.deploy_construction_vehicle(mcv), mode + " actual MCV deployment succeeds")
	check(Ra2Sfx.a_plays == before + 1 and battle.funds == money, mode + " MCV deployment emits one sound without charging")
	check(await peak() > 0.001, mode + " MCV deployment outputs actual PCM")
	screen.free()
	await get_tree().create_timer(0.2).timeout
	capture.clear_buffer()
	check(await peak() < 0.0001, mode + " leaving battle stops placement sound tails")
