extends "res://tests/selection_regression.gd"

func exercise_mode(mode: String) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var pool_size: int = Ra2Sfx.get_child_count()
	for iteration in 3:
		var label := "%s round %d: " % [mode, iteration]
		BattleRequest.configure_skirmish(mode, {"map_size": 3200, "starting_funds": 8000})
		screen = load("res://scenes/battle.tscn").instantiate()
		stage.add_child(screen)
		screen.process_mode = Node.PROCESS_MODE_DISABLED
		battle = screen.battle
		await get_tree().physics_frame
		check(Ra2Sfx.play("GrizzlyTankAttack", battle.camera.position), label + "spatial weapon plays")
		check(Ra2Sfx.play("GrizzlyTankAttack"), label + "global sound plays")
		check(Ra2Sfx.play_voice(GameData.get_unit("E1"), "select", Vector2.INF, 600000),
			label + "new battle does not inherit voice cooldown")
		check(Ra2Sfx.play_eva("EVA_NuclearMissileLaunched", "allied", 600000),
			label + "new battle does not inherit EVA cooldown")
		check(Ra2Sfx.play_eva("EVA_ConstructionComplete", "allied", 0), label + "lower priority EVA accepted")
		check(not Ra2Sfx._eva_queue.is_empty(), label + "real priority logic queues pending announcement")
		check(Ra2Sfx._pool.any(func(p): return p.playing) and Ra2Sfx._global_pool.any(func(p): return p.playing),
			label + "both real playback pools active before teardown")
		var cache: Dictionary = Ra2Sfx._cache.duplicate()
		# Destruction is the common exit path for return-to-menu and scene reload.
		# Also cover leaving while the tree is paused, without waiting for an audio tick.
		get_tree().paused = iteration == 1
		screen.free()
		check(Ra2Sfx._pool.all(func(p): return not p.playing and p.stream == null),
			label + "teardown stops and detaches all spatial streams")
		check(Ra2Sfx._global_pool.all(func(p): return not p.playing and p.stream == null),
			label + "teardown stops and detaches all global streams")
		check(not Ra2Sfx._eva_player.playing and Ra2Sfx._eva_player.stream == null and Ra2Sfx._eva_queue.is_empty(),
			label + "teardown clears current and pending EVA")
		check(Ra2Sfx._voice_lock.is_empty() and Ra2Sfx._eva_last.is_empty(), label + "battle cooldowns cleared")
		check(Ra2Sfx._cache == cache and Ra2Sfx.get_child_count() == pool_size,
			label + "cached resources and reusable players retained")
		get_tree().paused = false
		var eva_plays: int = Ra2Sfx.a_eva_plays
		Ra2Sfx._process(1.0)
		check(Ra2Sfx.a_eva_plays == eva_plays, label + "old queue cannot resume in lobby")
		await get_tree().process_frame
