extends Node
## Isolated 1x wall-clock benchmark. Run with a real clock and --headless.
const P95_LIMIT_MS := 30.0
const SAMPLE_SECONDS := 15.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var out := OS.get_environment("IRON_OUT")
	var source := OS.get_environment("IRON_SAVE")
	if DisplayServer.get_name() != "headless" or not OS.get_user_data_dir().contains("CodexIronTideValidation") or out.is_empty() or source.is_empty():
		get_tree().quit(2)
		return
	if DirAccess.make_dir_recursive_absolute(BattleSaves.DIRECTORY) != OK or DirAccess.make_dir_recursive_absolute(out) != OK:
		get_tree().quit(2)
		return
	if DirAccess.copy_absolute(source, ProjectSettings.globalize_path(BattleSaves.slot_path("slot1"))) != OK:
		get_tree().quit(2)
		return
	get_tree().current_scene = null
	seed(12345)
	if not BattleSaves.load_into_scene("slot1").ok:
		get_tree().quit(2)
		return
	await get_tree().process_frame
	await get_tree().process_frame
	var world: Battle = get_tree().current_scene.battle
	var report := {"units":world.units.size(), "buildings":world.buildings.size(), "layout":world.map_layout(), "phases":{}, "limit_ms":P95_LIMIT_MS}
	var squad := []
	for unit in world.units:
		if unit.side == "ally" and not unit.is_harvester and not unit.is_air and not unit.is_naval and not unit._deployed and unit.embarked_in == null:
			squad.append(unit)
	BattleClock.set_speed(1)
	world.paused = false
	get_tree().paused = false
	var warm_until: float = world.fog.sight_clock + 4.0
	while world.fog.sight_clock < warm_until:
		await get_tree().process_frame
	var passed := true
	for phase in ["battle", "selection", "move"]:
		squad = squad.filter(func(unit): return world.actor_alive(unit))
		if phase == "selection":
			world.clear_selection()
			for unit in squad: world.select_unit(unit, true)
			if not squad.is_empty(): world.center_on_selection()
		elif phase == "move" and not squad.is_empty():
			world._command_move(squad[0].position + Vector2(420,70))
		var stats: Dictionary = await sample_phase(world)
		report.phases[phase] = stats
		if stats.p95 >= P95_LIMIT_MS or stats.sim_s < stats.wall_s * 0.95:
			passed = false
		if phase != "battle" and world.selected_units.is_empty():
			passed = false
	report.passed = passed
	var file := FileAccess.open(out.path_join("result.json"), FileAccess.WRITE)
	if file == null:
		get_tree().quit(2)
		return
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	get_tree().quit(0 if passed else 1)

func sample_phase(world: Battle) -> Dictionary:
	var intervals := PackedFloat64Array()
	var start_us := Time.get_ticks_usec()
	var previous := start_us
	var start_clock: float = world.fog.sight_clock
	var tick := Engine.get_physics_frames()
	var paths: int = world.path_service.stats_paths
	var native_start: int = world.path_service.get("stats_map_paths") if "stats_map_paths" in world.path_service else 0
	var reuse_start: int = world.get("remote_route_reuses") if "remote_route_reuses" in world else 0
	while world.fog.sight_clock - start_clock < SAMPLE_SECONDS:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		intervals.append((now - previous) / 1000.0)
		previous = now
	intervals.sort()
	var count := intervals.size()
	var native_end: int = world.path_service.get("stats_map_paths") if "stats_map_paths" in world.path_service else 0
	var reuse_end: int = world.get("remote_route_reuses") if "remote_route_reuses" in world else 0
	return {"native_long_paths":native_end-native_start, "unaffected_routes":reuse_end-reuse_start, "frames":count, "selected":world.selected_units.size(), "paths":world.path_service.stats_paths-paths,
		"physics_steps":Engine.get_physics_frames()-tick, "sim_s":world.fog.sight_clock-start_clock, "wall_s":(previous-start_us)/1000000.0,
		"p50":intervals[count/2], "p95":intervals[ceili(count*0.95)-1], "p99":intervals[ceili(count*0.99)-1], "max":intervals[-1]}
