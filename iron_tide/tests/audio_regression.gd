extends Node
## Measure the actual mixer output with real assets, not just play() counters.
var checks: Array[Dictionary] = []
var capture := AudioEffectCapture.new()
var camera := Camera2D.new()

func check(ok: bool, label: String, detail: Variant = null) -> void:
	checks.append({"ok": ok, "label": label, "detail": detail})
	print(("PASS " if ok else "FAIL ") + label + " " + str(detail))

func reset_audio() -> void:
	Music.stop() # Keep music out of the independent SFX mixer oracle.
	Ra2Sfx.stop_eva()
	for child in Ra2Sfx.get_children():
		if child is AudioStreamPlayer or child is AudioStreamPlayer2D:
			child.stop()
	await get_tree().create_timer(0.15).timeout
	capture.clear_buffer()

func peak() -> float:
	await get_tree().create_timer(0.8).timeout
	var frames := capture.get_buffer(capture.get_frames_available())
	check(not frames.is_empty(), "mixer supplied frames", frames.size())
	var value := 0.0
	for frame in frames:
		value = maxf(value, maxf(absf(frame.x), absf(frame.y)))
	return value

func expect_eva(event: String, label: String) -> void:
	var id := GameData.ra2_eva_sound_id(event, "allied")
	var file := str(GameData.ra2_eva_file(id).get("file", ""))
	check(Ra2Sfx._eva_player.playing and Ra2Sfx._eva_player.stream == Ra2Sfx._stream_eva(file), label + " uses correct real EVA sample")
	check(await peak() > 0.001, label + " reaches mixer")

func production_audio(screen: Node, mode: String) -> void:
	var battle = screen.battle
	var hud = screen.hud
	for b in battle.buildings:
		b._buildup_play = -1.0
	battle.power_low = false
	battle.funds = 50000
	var refinery = battle._place_building("GAREFN", "ally", Vector2(1200, 1800), true)
	var barracks = battle._place_building("GAPILE", "ally", Vector2(1500, 1800), true)
	var factory = battle._place_building("GAWEAP", "ally", Vector2(1900, 1800), true)
	for b in [refinery, barracks, factory]: b._buildup_play = -1.0
	Ra2Sfx.stop_all()
	await reset_audio()
	hud.select_prod_tab("building")
	hud._start_build("GAPOWR")
	check(battle.struct_queue.size() == 1, mode + " structure order accepted")
	await expect_eva("EVA_Building", mode + " structure order")
	Ra2Sfx.stop_all()
	await reset_audio()
	hud._start_build("GAPOWR")
	check(battle.struct_queue.size() == 2, mode + " repeated structure order accepted")
	await expect_eva("EVA_Building", mode + " repeated structure order")
	Ra2Sfx.stop_all()
	await reset_audio()
	battle.request_structure("GAWEAT")
	check(not Ra2Sfx._eva_player.playing and battle.struct_queue.size() == 2, mode + " missing prerequisite does not announce building")
	battle.funds = 0
	hud._start_build("GAPILE")
	check(not Ra2Sfx._eva_player.playing and battle.struct_queue.size() == 2, mode + " unaffordable HUD order does not announce")
	battle.funds = 50000
	battle.request_structure("GAPOWR", "enemy")
	check(not Ra2Sfx._eva_player.playing, mode + " enemy structure order stays silent")
	battle.struct_ready["GAPILE"] = 1
	battle.request_structure("GAPILE")
	check(battle.armed_build == "GAPILE" and not Ra2Sfx._eva_player.playing, mode + " ready structure placement does not restart building voice")
	battle.armed_build = ""
	for entry in [[refinery, "CMIN", "EVA_Building"], [barracks, "E1", "EVA_Training"], [factory, "MTNK", "EVA_Building"]]:
		var producer = entry[0]
		Ra2Sfx.stop_all()
		await reset_audio()
		battle.select_building(producer)
		battle._emit_selection()
		var before_plays: int = Ra2Sfx.a_eva_plays
		if producer == refinery:
			hud._refinery_btn.pressed.emit()
		else:
			hud._queue(entry[1], 5)
		check(producer.production.size() == (1 if producer == refinery else 5), mode + " production order accepted " + entry[1])
		check(Ra2Sfx.a_eva_plays == before_plays + 1 and Ra2Sfx._eva_queue.is_empty(), mode + " one announcement per batch " + entry[1])
		await expect_eva(entry[2], mode + " production " + entry[1])
		Ra2Sfx.stop_all()
		await reset_audio()
		check(not producer.enqueue("missing_unit") and not Ra2Sfx._eva_player.playing, mode + " rejected unit does not announce")
		if producer == refinery:
			check(not producer.enqueue("CMIN") and not Ra2Sfx._eva_player.playing, mode + " full miner queue stays silent")
	var enemy = battle._place_building("GAREFN", "enemy", Vector2(2400, 1800), true)
	enemy._buildup_play = -1.0
	check(enemy.enqueue("CMIN") and not Ra2Sfx._eva_player.playing, mode + " enemy miner production stays silent")

func _ready() -> void:
	# This oracle measures SFX silence; menu music is verified independently.
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), true)
	capture.buffer_length = 2.0
	AudioServer.add_bus_effect(0, capture)
	add_child(camera)
	camera.position = Vector2(5000, 5000)
	camera.make_current()
	await get_tree().process_frame
	await get_tree().physics_frame
	check(not AudioServer.is_bus_mute(0), "Master bus is not muted")
	await yuri_voice_audio()
	for mode in ["ra2", "iron_tide"]:
		BattleRequest.rules_mode = mode
		await reset_audio()
		check(Ra2Sfx.play_weapon({"report": "GrizzlyTankAttack"}, camera.global_position),
			mode + " weapon sound accepted")
		var near_peak := await peak()
		check(near_peak > 0.001, mode + " on-screen weapon is audible away from map origin", near_peak)
		await reset_audio()
		check(Ra2Sfx.play_weapon({"report": "GrizzlyTankAttack"}, Vector2.ZERO),
			mode + " distant weapon sound accepted")
		var far_peak := await peak()
		check(far_peak < 0.0001, mode + " distant weapon still attenuates", far_peak)
		await reset_audio()
		check(Ra2Sfx.play("GrizzlyTankAttack"), mode + " global sound accepted")
		var global_peak := await peak()
		check(global_peak > 0.001, mode + " global sound ignores camera distance", global_peak)
		await reset_audio()
		var unit_data := GameData.get_unit("E1")
		check(Ra2Sfx.play_voice(unit_data, "select", camera.global_position, 0),
			mode + " actual infantry selection voice accepted")
		var voice_peak := await peak()
		check(voice_peak > 0.001, mode + " infantry selection voice reaches mixer", voice_peak)
		await reset_audio()
		check(Ra2Sfx.play_eva("EVA_ConstructionComplete", "allied", 0),
			mode + " EVA construction complete accepted")
		var eva_peak := await peak()
		check(eva_peak > 0.001, mode + " EVA still reaches mixer", eva_peak)
	await reset_audio()
	# Reuse spatial players after many changing coordinates and global sounds.
	for i in 40:
		Ra2Sfx.play("GrizzlyTankAttack", Vector2(i * 100, -5000))
	await reset_audio()
	Ra2Sfx.play("GrizzlyTankAttack", camera.global_position)
	var reuse_peak := await peak()
	check(reuse_peak > 0.001, "reused spatial player uses new world position", reuse_peak)
	await reset_audio()
	check(not Ra2Sfx.play("missing_sound_for_regression"), "unknown sound fails safely")
	for mode in [MatchRules.RA2, MatchRules.EXTENDED]:
		BattleRequest.configure_skirmish(mode, {"map_size": 3200, "starting_funds": 8000})
		var screen: Node = load("res://scenes/battle.tscn").instantiate()
		add_child(screen)
		screen.process_mode = Node.PROCESS_MODE_DISABLED
		await production_audio(screen, mode)
		await reset_audio()
		check(Ra2Sfx.play("GrizzlyTankAttack"), mode + " exit fixture starts real sound")
		check(Ra2Sfx._global_pool.any(func(p): return p.playing), mode + " exit fixture has active playback")
		screen.free()
		check(Ra2Sfx._global_pool.all(func(p): return not p.playing and p.stream == null),
			mode + " real battle teardown stops playback immediately")
		# Drain already mixed samples without manually stopping any player.
		await get_tree().create_timer(0.15).timeout
		capture.clear_buffer()
		var exit_peak := await peak()
		check(exit_peak < 0.0001, mode + " mixer silent after battle exit", exit_peak)
		check(Ra2Sfx.play("GrizzlyTankAttack"), mode + " playback accepted after teardown")
		capture.clear_buffer()
		var restart_peak := await peak()
		check(restart_peak > 0.001, mode + " reused service remains audible", restart_peak)
		await reset_audio()
	var failed := 0
	for item in checks:
		if not item.ok:
			failed += 1
	var report_dir := OS.get_environment("IRON_TIDE_REPORT_DIR")
	var file := FileAccess.open(report_dir.path_join("result.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failed": failed,
		"output_device": AudioServer.get_output_device(),
		"evidence": "mixer PCM only; user listening confirmation remains pending"}, "\t"))
	file.close()
	get_tree().quit(0 if failed == 0 else 1)

func yuri_voice_audio() -> void:
	var expected := {"AMCV": "MCVAlliedSelect", "CARRIER": "AircraftCarrierSelect", "AEGIS": "AegisSelect",
		"LCRF": "HoverAlliedSelect", "TNKD": "TankDestroyerSelect", "CMIN": "ChronoMinerSelect",
		"SREF": "PrismTankSelect", "MGTK": "MirageTankSelect", "FV": "IFVSelect"}
	check(GameData.ra2_voice_overrides.size() == expected.size(), "YR pack covers nine existing units")
	for token in GameData.ra2_sfx_files:
		if not str(token).begins_with("yr_"): continue
		var file: String = GameData.ra2_sfx_files[token].file
		var stream = Ra2Sfx._stream(file)
		check(stream is AudioStreamWAV and stream.get_length() > 0.0, "YR sample decodes: " + file)
	for mode in [MatchRules.RA2, MatchRules.EXTENDED]:
		BattleRequest.rules_mode = mode
		for id in expected:
			var data := GameData.get_unit(id)
			check(Ra2Sfx.voice_id(data, "select") == "yr_" + expected[id], mode + " correct YR select " + id)
			check(data.voice.select == GameData.unit_index[id].voice.select, mode + " base data remains unchanged " + id)
			for kind in GameData.ra2_voice_overrides[id]:
				await reset_audio()
				check(Ra2Sfx.play_voice(data, kind, camera.global_position, 0), mode + " YR command plays " + id + "/" + kind)
				check(await peak() > 0.001, mode + " YR command reaches mixer " + id + "/" + kind)
		check(Ra2Sfx.voice_id(GameData.get_unit("E1"), "select") == "GISelect", mode + " unchanged GI voice retained")
		check(Ra2Sfx.voice_id(GameData.get_unit("SREF"), "die") == str(GameData.get_unit("SREF").voice.die), mode + " death sound retained")
	var original := GameData.ra2_voice_overrides.duplicate(true)
	GameData.ra2_voice_overrides.clear()
	check(Ra2Sfx.voice_id(GameData.get_unit("SREF"), "select") == "GenAllVehicleSelect", "absent optional pack falls back to RA2")
	GameData.ra2_voice_overrides = original
	GameData.ra2_voice_overrides["SREF"]["select"] = "missing_yr_sound"
	check(Ra2Sfx.voice_id(GameData.get_unit("SREF"), "select") == "GenAllVehicleSelect", "missing optional sound falls back to RA2")
	GameData._load_ra2_sfx()
	check(Ra2Sfx.voice_id(GameData.get_unit("SREF"), "select") == "yr_PrismTankSelect", "data reload restores YR voice pack")
