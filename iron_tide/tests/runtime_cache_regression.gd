extends "res://tests/base_recovery_regression.gd"

func _ready() -> void:
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not ProjectSettings.get_setting("application/config/use_custom_user_dir",false):
		get_tree().quit(2)
		return
	var names: Array = GameData.ra2_sfx_files.keys()
	names.sort()
	var readings: Array = []
	for round_index in 3:
		start(MatchRules.RA2)
		var sample_count := 0
		for i in 240:
			var entry: Dictionary = GameData.ra2_sfx_files[names[(round_index * 240 + i) * 3 % names.size()]]
			if Ra2Sfx._stream(str(entry.file)) != null: sample_count += 1
		check(sample_count == 240, "sound files load during each round")
		var actors: Array = []
		for i in 40:
			actors.append(battle.spawn_unit("MTNK","ally",Vector2(500 + i * 25,900)))
		var descriptor: Dictionary = actors[0]._weapon_art
		check(not descriptor.get("muzzles",[]).is_empty() and actors.all(func(u): return is_same(u._weapon_art, descriptor)), "40 Grizzly tanks share their weapon attachment data")
		await finish()
		var bytes := 0
		for stream in Ra2Sfx._cache.values():
			if stream != null: bytes += stream.data.size()
		readings.append([Ra2Sfx._cache.size(),bytes])
		check(Ra2Sfx._cache.size() <= 256 and bytes <= 16 * 1024 * 1024, "sound cache bounded after leaving battle", readings.back())
	# Imported game clips are small. Use isolated 2 MiB fixtures to exercise the
	# byte limit separately from the 256-entry limit.
	var hot_name := str(GameData.ra2_sfx_files[names[0]].file)
	var hot := Ra2Sfx._stream(hot_name)
	var player := Ra2Sfx._take_global_player()
	player.stream = hot
	var samples := PackedByteArray()
	samples.resize(2 * 1024 * 1024)
	var fixture := AudioStreamWAV.new()
	fixture.data = samples
	for i in 9:
		var path := "user://cache-probe-%d.res" % i
		check(ResourceSaver.save(fixture, path, ResourceSaver.FLAG_COMPRESS) == OK and Ra2Sfx._cached_stream(path,path) != null, "load large isolated clip " + str(i))
	check(Ra2Sfx._cached_bytes == Ra2Sfx.CACHE_BYTES and Ra2Sfx._cache.size() == 8, "byte limit reached independently of entry limit")
	check(not Ra2Sfx._cache.has(hot_name) and player.stream == hot and hot.get_length() > 0, "eviction keeps player-owned clip intact")
	check(Ra2Sfx._stream(hot_name) != null and Ra2Sfx._cache.has(hot_name), "cold clip can be requested again")
	player.stream = null
	for i in 300:
		Ra2Sfx._stream("__missing_cache_probe_%d" % i)
		Ra2Sfx._stream(hot_name)
	check(Ra2Sfx._cache.has(hot_name) and Ra2Sfx._cache.size() == Ra2Sfx.CACHE_ENTRIES, "frequent hits survive bounded missing entries")
	var normal := RA2Art.weapon_descriptor("FV")
	var missile := RA2Art.weapon_descriptor("FV_mode1")
	check(not normal.is_empty() and not missile.is_empty() and not is_same(normal,missile), "IFV modes retain distinct weapon attachments")
	RA2Art.clear_cache()
	check(not is_same(normal,RA2Art.weapon_descriptor("FV")) and normal == RA2Art.weapon_descriptor("FV"), "cache reset reloads original data without invalidating existing units")
	print("CACHE_ROUNDS ", readings)
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"rounds":readings}))
	get_tree().quit(0 if failed==0 else 1)
