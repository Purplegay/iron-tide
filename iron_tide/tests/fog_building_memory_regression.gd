extends "res://tests/base_recovery_regression.gd"

func _ready() -> void:
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not ProjectSettings.get_setting("application/config/use_custom_user_dir", false):
		get_tree().quit(2)
		return
	await get_tree().process_frame
	for mode in [MatchRules.RA2, MatchRules.EXTENDED]:
		await exercise_memory(mode)
	var report := FileAccess.open(output_dir.path_join("result.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks": checks, "failed": failed}, "  "))
	report.close()
	get_tree().quit(int(failed != 0))

func exercise_memory(mode: String) -> void:
	prefix = mode + ": "
	BattleRequest.configure_skirmish(mode, {"map_size": 2400, "starting_funds": 8000, "enemy_base": "allied", "fog_of_war": true})
	screen = load("res://scenes/battle.tscn").instantiate()
	add_child(screen)
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	battle = screen.battle
	var fog = battle.fog
	var memory = fog.building_memory
	var point := Vector2(1200, 1200)
	var unseen := point + Vector2(240, 0)
	var power = battle._place_building("GAPOWR", "enemy", point, true)
	var factory = battle._place_building("GAWEAP", "enemy", unseen, true)
	power._buildup_play = -1.0
	factory._buildup_play = -1.0
	fog.visible_cells.ally.fill(0)
	fog.explored_cells.ally.fill(0)
	memory.restore({})
	fog._publish_combat_sight()
	check(not power.visible and not factory.visible and memory.records.is_empty(), prefix + "unseen buildings do not appear")
	var probe: Building = factory
	var cached := probe.fog_pose()
	check(is_same(cached, probe.fog_pose()) and cached == probe._build_fog_pose(), prefix + "unchanged ordered animated pose reuses commands")
	check(cached.is_read_only() and not cached.is_empty() and cached[0].is_read_only(), prefix + "published commands cannot be edited in place")
	var old_radius := probe.radius
	probe.radius += 7.0
	var resized := probe.fog_pose()
	check(not is_same(cached, resized) and resized == probe._build_fog_pose(), prefix + "geometry changes invalidate pose")
	probe.radius = old_radius
	probe._buildup_play = 0.15
	check(probe.fog_pose() == probe._build_fog_pose(), prefix + "construction playback falls back")
	probe._buildup_play = -1.0
	var factory_cell: int = fog._index(unseen)
	fog.visible_cells.ally[factory_cell] = 1
	fog._publish_combat_sight()
	check(memory.records.has(unseen), prefix + "observation seeds factory record")
	AlliedAbilities.change_side(factory, "ally", false)
	fog._publish_combat_sight()
	check(not memory.records.has(unseen), prefix + "capturing visible factory clears enemy memory")
	AlliedAbilities.change_side(factory, "enemy", false)
	fog._publish_combat_sight()
	check(memory.records.get(unseen, {}).get("pose") == probe._build_fog_pose(), prefix + "return to enemy observes current pose")
	fog.visible_cells.ally[factory_cell] = 0
	fog.explored_cells.ally[factory_cell] = 0
	memory.forget(unseen)
	var cell: int = fog._index(point)
	fog.visible_cells.ally[cell] = 1
	fog.explored_cells.ally[cell] = 1
	fog._publish_combat_sight()
	var known: Dictionary = memory.records.get(point, {}).duplicate(true)
	check(power.visible and not memory.shown.has(point) and not known.get("pose", []).is_empty(), prefix + "observe actual shell and do not draw a duplicate")
	var live_pose: Array = known.get("pose", [])
	power.hp *= 0.33
	fog._publish_combat_sight()
	known = memory.records.get(point, {}).duplicate(true)
	check(known.get("pose", []) != live_pose, prefix + "visible damage updates observed art")
	fog.visible_cells.ally[cell] = 0
	power.hp = power.max_hp
	power._col = Color.LIME_GREEN
	fog._publish_combat_sight()
	check(not power.visible and memory.shown.get(point, {}) == known and not memory.shown.has(unseen), prefix + "hidden repair, paint and unrelated construction stay hidden")
	check(not battle.actor_visible_to("ally", power) and battle._pick_enemy_at(power.art_center()) == null, prefix + "memory does not give combat sight or a clickable target")
	var ghost: Node = memory._nodes.get(point)
	check(ghost is Node2D and not ghost is CollisionObject2D and ghost.get_groups().is_empty(), prefix + "world memory has no collision or actor groups")
	power.retire_sold()
	await get_tree().process_frame
	fog.rebuild()
	check(not is_instance_valid(power) and memory.shown.get(point, {}) == known, prefix + "hidden sale keeps the recorded sprite and radar state")
	var saved := BattleSaves.save_slot(battle, "quick")
	var slot := BattleSaves.read_slot("quick")
	check(saved.get("ok", false) and slot.has("snapshot"), prefix + "write and validate isolated quick save", [saved, slot.get("error", "")])
	if slot.has("snapshot"):
		await finish()
		screen = load("res://scenes/battle.tscn").instantiate()
		add_child(screen)
		screen.process_mode = Node.PROCESS_MODE_DISABLED
		battle = screen.battle
		fog = battle.fog
		memory = fog.building_memory
		BattleSaves.Snapshot.new().restore(battle, slot.snapshot)
		check(memory.shown.get(point, {}) == known, prefix + "fresh battle restores a ghost whose source is gone")
		var legacy: Dictionary = slot.snapshot.duplicate(true)
		legacy.context.erase("fog_buildings")
		BattleSaves.Snapshot.new().restore(battle, legacy)
		check(not memory.records.has(point), prefix + "legacy save does not invent old sightings")
		BattleSaves.Snapshot.new().restore(battle, slot.snapshot)
	var replacement = battle._place_building("GAPILE", "enemy", point, true)
	replacement._buildup_play = -1.0
	fog._publish_combat_sight()
	check(not replacement.visible and memory.shown.get(point, {}) == known, prefix + "hidden replacement does not overwrite previous building")
	fog.visible_cells.ally[cell] = 1
	fog._publish_combat_sight()
	check(replacement.visible and not memory.shown.has(point) and memory.records[point].pose != known.pose, prefix + "renewed sight replaces the old picture")
	replacement.retire_sold()
	fog.visible_cells.ally[cell] = 0
	fog._publish_combat_sight()
	check(not memory.records.has(point), prefix + "sale in view stays cleared even if scout leaves immediately")
	await get_tree().process_frame
	var second = battle._place_building("GAPOWR", "neutral", point, true)
	second._buildup_play = -1.0
	fog.visible_cells.ally[cell] = 1
	fog._publish_combat_sight()
	fog.visible_cells.ally[cell] = 0
	fog._publish_combat_sight()
	check(memory.shown.has(point), prefix + "neutral building is remembered")
	second.retire_sold()
	fog.visible_cells.ally[cell] = 1
	fog._publish_combat_sight()
	check(not memory.records.has(point), prefix + "scouting an empty site clears memory")
	await get_tree().process_frame
	var third = battle._place_building("GAPOWR", "enemy", point, true)
	third._buildup_play = -1.0
	fog._publish_combat_sight()
	fog.visible_cells.ally[cell] = 0
	fog._publish_combat_sight()
	check(memory.shown.has(point), prefix + "seed memory before reshroud")
	third._die(null, true)
	await get_tree().process_frame
	fog._publish_combat_sight()
	check(not is_instance_valid(third) and memory.shown.has(point), prefix + "hidden death does not erase the ghost")
	fog.reset_exploration("ally")
	check(not memory.records.has(point) and not memory.shown.has(point), prefix + "reshroud clears building memory")
	var scout = battle.spawn_unit("MTNK", "ally", point + Vector2(80, 0))
	var tower = battle._place_building("GTGCAN", "enemy", point, true)
	tower._buildup_play = -1.0
	fog.rebuild()
	check(tower.visible and memory.records.get(point, {}).get("pose", []).size() >= 2, prefix + "scout observes body and independent turret pose")
	scout.global_position = Vector2(400, 400)
	fog.sight_clock += 6.0
	fog.rebuild()
	fog.sight_clock += 6.0
	fog.rebuild()
	check(not tower.visible and memory.shown.has(point), prefix + "normal scouting and sight expiry publish memory")
	await finish()
