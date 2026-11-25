extends "res://tests/command_voice_regression.gd"

func _ready() -> void:
	output = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output.is_empty() or not ProjectSettings.get_setting("application/config/use_custom_user_dir", false):
		get_tree().quit(2)
		return
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), true)
	capture.buffer_length = 2.0
	AudioServer.add_bus_effect(0, capture)
	var pack: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/ra2/yr_unit_voices.json"))
	check(pack.entries.size() == 1400 and pack.specs.size() == 362, "complete original audio catalogue")
	for key in pack.entries:
		var entry: Dictionary = pack.entries[key]
		var stream: AudioStreamWAV = Ra2Sfx._stream(entry.file)
		check(stream != null and stream.get_length() > 0.0 and stream.stereo == (int(entry.channels) == 2), "Godot loads " + key)
	var covered := 0
	for data in GameData.units:
		var uid: String = data.id
		if not pack.units.has(uid):
			continue
		covered += 1
		for kind in pack.units[uid]:
			check(Ra2Sfx.voice_id(data, kind) == pack.units[uid][kind], uid + " resolves original " + kind)
		for kind in ["select", "move", "attack"]:
			if not pack.units[uid].has(kind):
				continue
			await reset()
			check(Ra2Sfx.play_voice(data, kind, Vector2(99999, 99999), 0), uid + " accepts " + kind)
			check(await peak() > 0.001, uid + " original " + kind + " reaches real mixer")
	check(covered == 32, "all 29 current original units plus three prototype aliases", covered)
	check(GameData.get_unit("YURIPR").is_empty(), "reserved voice mappings do not unlock Yuri Prime")
	check(not GameData.ra2_voice_overrides.has("swarm_drone"), "custom swarm keeps its own sounds")
	var original: Dictionary = GameData.ra2_voice_overrides.duplicate(true)
	GameData.ra2_voice_overrides.clear()
	check(Ra2Sfx.voice_id(GameData.get_unit("E1"), "select") == "GISelect", "absent optional pack uses base unit voice")
	check(Ra2Sfx.voice_id(GameData.get_unit("CMIN"), "harvest") == "ChronoMinerMove", "older data falls back to move for harvest")
	GameData.ra2_voice_overrides["E1"] = {"select": "missing_sound"}
	check(Ra2Sfx.voice_id(GameData.get_unit("E1"), "select") == "GISelect", "unavailable override falls back to base")
	GameData.ra2_voice_overrides = original
	for mode in [MatchRules.RA2, MatchRules.EXTENDED]:
		await harvest_command(mode)
	await robot_control_voice()
	var file := FileAccess.open(output.path_join("result.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failed": failed, "covered_units": covered}, "  "))
	file.close()
	get_tree().quit(0 if failed == 0 else 1)

func robot_control_voice() -> void:
	BattleRequest.configure_skirmish(MatchRules.RA2, {"map_size": 3200, "fog_of_war": false})
	var screen = load("res://scenes/battle.tscn").instantiate()
	add_child(screen)
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	var battle = screen.battle
	var pos := Vector2(1500, 1500)
	battle.camera.position = pos
	battle.camera.reset_smoothing()
	battle.camera.force_update_scroll()
	var robot = battle.spawn_unit("ROBO", "ally", pos)
	robot._physics_process(0.01)
	await reset()
	check(battle._play_group_voice([robot], "select", 180), "offline robot uses selection acknowledgement")
	check(Ra2Sfx._voice_lock.has("yr_full_robottankselectdeactivated") and await peak() > 0.001, "offline selection reaches real mixer")
	var center = battle._place_building("GAROBO", "ally", pos + Vector2(300, 300), true)
	center._buildup_play = -1.0
	var power = battle._place_building("GAPOWR", "ally", pos + Vector2(300, -300), true)
	power._buildup_play = -1.0
	power.power = 5000
	battle._update_power()
	await reset()
	robot._physics_process(0.01)
	check(not robot.powered_unit.offline and await peak() > 0.001, "actual controller activation sound reaches real mixer")
	await reset()
	center._die()
	robot._physics_process(0.01)
	check(robot.powered_unit.offline and await peak() > 0.001, "actual controller loss sound reaches real mixer")
	await reset()
	check(Ra2Sfx.play_weapon(robot.weapon, pos) and await peak() > 0.001, "robot cannon sound reaches real mixer")
	screen.free()
	await get_tree().process_frame

func harvest_command(mode: String) -> void:
	BattleRequest.configure_skirmish(mode, {"map_size": 3200, "starting_funds": 8000, "fog_of_war": false})
	var screen = load("res://scenes/battle.tscn").instantiate()
	add_child(screen)
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	var battle = screen.battle
	var miner = battle.spawn_unit("CMIN", "ally", Vector2(1800, 1800))
	var gi = battle.spawn_unit("E1", "ally", Vector2(1850, 1800))
	var ore := ResourceNode.new()
	ore.position = Vector2(2100, 1900)
	battle.add_child(ore)
	ore.process_mode = Node.PROCESS_MODE_DISABLED
	battle.select_unit(gi, false)
	battle.select_unit(miner, true)
	await reset()
	check(battle._try_harvest_at(ore.position), mode + " actual mixed selection harvest accepted")
	check(miner.resource_node == ore and miner.harvest_state == "to_node", mode + " real miner receives ore order")
	check(Ra2Sfx._voice_lock.has("yr_full_chronominerharvest") and not Ra2Sfx._voice_lock.has("yr_full_gimove"), mode + " miner acknowledges instead of unrelated selected soldier")
	check(await peak() > 0.001, mode + " dedicated harvest acknowledgement audible")
	await reset()
	var before: int = Ra2Sfx.a_voice_plays
	battle.select_unit(gi, false)
	check(not battle._try_harvest_at(ore.position) and Ra2Sfx.a_voice_plays == before, mode + " non-miner selection does not announce harvest")
	screen.free()
	await get_tree().process_frame
