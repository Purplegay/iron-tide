extends Node
## Run in an isolated project copy with a dedicated custom_user_dir_name.
## Uses the real battle scene, orders, physics, production queue and building renderer.

var checks: Array = []
var evidence: Dictionary = {}
var failed := 0
var output_dir := ""

func check(condition: bool, label: String, details = null) -> void:
	checks.append({"name": label, "passed": condition, "details": details})
	if not condition:
		failed += 1
		print("FAIL ", label, " ", details)

func frames(count: int) -> void:
	for i in range(count):
		await get_tree().process_frame

func check_flow_sampling() -> void:
	const N := 24
	var grid := PackedFloat32Array()
	grid.resize(N*N)
	grid.fill(1.0)
	for y in N:
		grid[y*N+12]=-1.0
		if y!=6: grid[y*N+4]=-1.0
		grid[y*N+8]=2.0
	var full:=FlowField.new()
	var partial:=FlowField.new()
	for field in [full,partial]: field.configure(1.0,N,N,grid)
	for goal in [Vector2(5.5,6.5),Vector2(4.5,8.5)]:
		full.compute(goal,1)
		partial.compute(goal,1,true)
		var nearby:=Vector2(6.5,6.5)
		check(partial.direction_at(nearby)==full.direction_at(nearby) and partial._settled.count(1)<N*N/4,"Short flow queries settle only nearby cells")
		var same:=true
		for y in N:
			for x in N:
				var point:=Vector2(x+0.5,y+0.5)
				if partial.direction_at(point)!=full.direction_at(point):same=false
		check(same,"Lazy and complete fields agree across walls, blocked goals and unreachable cells")

func check_shared_route() -> void:
	var nav := PathService.new()
	nav.configure(1000, 40)
	var start := Vector2(100, 340)
	var goal := Vector2(820, 340)
	for y in range(2, 16):
		nav.cost[y*nav.cols+10] = -1
	var first := nav.find_path(start, goal,false,6000,false,[],false,true)
	check(first.size() >= 3 and first[-1] == goal, "Obstacle creates a complete indirect route")
	check(nav.stats_window_paths==1,"Short detour uses native eight-direction search")
	first.clear() # Units consume or replace their own waypoint arrays.
	var next_start := start + Vector2(2, 1)
	var next_goal := goal + Vector2(1, 2)
	var reused := nav.find_path(next_start, next_goal,false,6000,false,[],false,true)
	var valid := reused.size() >= 3 and reused[0] == next_start and reused[-1] == next_goal
	for i in range(1, reused.size()):
		valid = valid and nav.line_walkable(reused[i-1], reused[i], nav.cost)
	check(valid and nav.stats_route_reuse == 1, "Following unit keeps its own endpoints and walkable corners")
	nav.find_path(start, goal, false, 1)
	nav.find_path(start, goal, false, 6000, false, [{"position": start + Vector2(80,0), "radius": 20.0}],false,true)
	check(nav.stats_route_reuse == 1, "Limited searches and temporary obstacles bypass shared route")
	var cached:AStarGrid2D=nav._windows.values()[0]
	check(not cached.is_point_solid(nav._cell_of(start+Vector2(80,0))),"Temporary occupied cells restored on the shared solver")

	for y in nav.rows: nav.cost[y*nav.cols+10] = -1
	nav.epoch += 1
	var separated := nav.find_path(start, goal)
	check(nav.stats_route_reuse == 1 and separated[-1] != goal, "Closed passage invalidates previous crossing")
	nav.free()

func _ready() -> void:
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not ProjectSettings.get_setting("application/config/use_custom_user_dir", false):
		push_error("Use an isolated project copy, custom user directory and IRON_TIDE_REPORT_DIR.")
		get_tree().quit(2)
		return
	check_flow_sampling()
	check_shared_route()
	seed(20261020)
	DirAccess.make_dir_recursive_absolute(output_dir)
	evidence["user_dir"] = OS.get_user_data_dir()
	evidence["project"] = ProjectSettings.globalize_path("res://")
	evidence["engine"] = Engine.get_version_info().string
	evidence["fixed_fps"] = Engine.get_physics_ticks_per_second()
	await frames(1)
	var screen = load("res://scenes/battle.tscn").instantiate()
	add_child(screen)
	await frames(45)
	var b = screen.battle
	# Live desktop input must not replace the test's issued orders.
	b.set_process_input(false)
	b.set_process_unhandled_input(false)
	# Suppress unrelated wave spawning; actual navigation and physics remain enabled.
	b.wave_timer = 99999.0
	_test_separation_and_detour(b)
	_test_grid()
	_test_movement_domains(b)
	await _test_formation(b)
	await _test_building(screen)
	var f := FileAccess.open(output_dir.path_join("result.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks": checks, "failed": failed, "evidence": evidence}, "  "))
	f.close()
	print("REGRESSION checks=", checks.size(), " failed=", failed, " output=", output_dir)
	get_tree().quit(0 if failed == 0 else 1)

func _test_movement_domains(b) -> void:
	var water: Vector2 = b.water_rects[0].get_center()
	var enemy = b.spawn_unit("MTNK", "enemy", Vector2(b.map_size * 0.5, b.map_size * 0.65))
	enemy.set_physics_process(false)
	check(not enemy._domain_ok(water), "enemy ground unit uses battle water boundary")
	check(enemy._terrain_epoch() == b.path_epoch(), "enemy unit receives terrain invalidation")
	var route: PackedVector2Array = enemy._path_for(Vector2(b.map_size * 0.5, b.map_size * 0.55))
	check(route.size() >= 2, "enemy nested under enemy_root can request A-star")
	var ship = b.spawn_unit("DEST", "ally", water)
	ship.set_physics_process(false)
	var naval_field = ship._field_for(water)
	var expected_field = b.field_for_pos(water, true)
	check(naval_field == expected_field, "naval patrol uses the water flow field")
	var air = b.spawn_unit("ORCA", "ally", Vector2(b.map_size * 0.5, b.map_size * 0.7))
	air.set_physics_process(false)
	b.selected_units = [air]
	b._command_move(water)
	check(air.move_target.is_equal_approx(water), "air order keeps water target instead of snapping ashore", str(air.move_target))
	check(air._path_pts.size() == 2, "air uses direct flight path across ground blockers")
	var ore = get_tree().get_first_node_in_group("resource_nodes")
	b.selected_units = [enemy]
	check(not b._cursor_on_ore(ore.global_position), "combat unit does not show harvesting cursor")
	var miner = b.spawn_unit("CMIN", "ally", Vector2(1500, 2200))
	miner.set_physics_process(false)
	b.selected_units = [miner]
	check(b._cursor_on_ore(ore.global_position), "harvester shows ore cursor without Object.get error")
	b.selected_units = []
	enemy.free()
	ship.free()
	air.free()
	miner.free()

func _test_separation_and_detour(b) -> void:
	var a = b.spawn_unit("MTNK", "ally", Vector2(3000, 3000))
	var c = b.spawn_unit("MTNK", "ally", Vector2(3025, 3000))
	a.set_physics_process(false)
	c.set_physics_process(false)
	a.velocity = Vector2.ZERO
	c.velocity = Vector2.ZERO
	a.apply_separation(1.0 / 60.0)
	c.apply_separation(1.0 / 60.0)
	check(a.velocity.x < 0.0 and c.velocity.x > 0.0, "friendly separation pushes apart",
		[str(a.velocity), str(c.velocity)])
	# The safe route initially leads away from the final target.
	a.global_position = Vector2(400, 400)
	a.has_move_order = true
	a.set_agent_path(PackedVector2Array([Vector2(400, 400), Vector2(400, 600), Vector2(800, 400)]))
	var before: int = b.path_service.stats_paths
	for i in range(120):
		a.global_position = Vector2(400, 400 + i)
		a._tick_path_stuck(1.0 / 60.0)
	check(b.path_service.stats_paths == before and a._dodge_t == 0.0,
		"progress toward detour waypoint does not trigger stuck recovery", b.path_service.stats_paths - before)
	a.free()
	c.free()

func _test_grid() -> void:
	var ps := PathService.new()
	ps.configure(200.0)
	ps.cost[1] = -1.0
	ps.epoch += 1
	check(not ps.line_walkable(Vector2(20, 20), Vector2(60, 60), ps.cost),
		"path smoothing cannot cross a blocked diagonal corner")
	var route := ps.find_path(Vector2(20, 20), Vector2(180, 20))
	check(route.size() >= 3 and route[-1].is_equal_approx(Vector2(180, 20)),
		"route goes around blocked cell", str(route))
	ps.configure(200.0)
	ps.set_water([Rect2(80, 0, 40, 200)])
	var dry_path := ps.find_path(Vector2(20, 100), Vector2(100, 100))
	check(dry_path.size() >= 2 and not ps.in_water(dry_path[-1]),
		"ground order to water ends on reachable land", str(dry_path))
	var split_path := ps.find_path(Vector2(20, 100), Vector2(180, 100))
	check(split_path.size() >= 1 and ps.same_zone(Vector2(20, 100), split_path[-1]),
		"disconnected destination stays in source zone", str(split_path))
	var sea_path := ps.find_path(Vector2(100, 20), Vector2(100, 180), true)
	check(sea_path.size() >= 2 and ps.in_water(sea_path[-1]),
		"naval path stays in water", str(sea_path))
	ps.free()

func _test_formation(b) -> void:
	var units: Array = []
	var anchor := Vector2(b.map_size * 0.5, b.map_size * 0.8)
	for i in range(6):
		var u = b.spawn_unit("MTNK", "ally", anchor + Vector2(-90 + (i % 3) * 70, 180 + (i / 3) * 60))
		u.fire_stance = "none"
		units.append(u)
	b.selected_units = units.duplicate()
	b._command_move(Vector2(b.map_size * 0.32, b.map_size * 0.32))
	var closest_slot := INF
	for i in range(units.size()):
		for j in range(i + 1, units.size()):
			closest_slot = minf(closest_slot, units[i].move_target.distance_to(units[j].move_target))
	check(closest_slot >= b._formation_spacing(units) - 0.1,
		"obstacle-snapped formation slots preserve body and arrival clearance", closest_slot)
	var arrival := PackedInt32Array()
	arrival.resize(6)
	arrival.fill(-1)
	var tick := 0
	for i in range(3600):
		tick = i
		await frames(1)
		var all_done := true
		for j in range(units.size()):
			var u = units[j]
			if u.position.distance_to(u.move_target) <= 26.0 and not u.has_move_order:
				if arrival[j] < 0:
					arrival[j] = i
			else:
				all_done = false
		if all_done:
			break
	var rows: Array = []
	var neighbors: Array = []
	for other in get_tree().get_nodes_in_group("allies"):
		if not units.has(other):
			neighbors.append({"name": str(other.name), "unit": other.get("unit_id"), "position": str(other.position), "state": other.get("harvest_state")})
	var arrived := 0
	for i in range(units.size()):
		var u = units[i]
		var d: float = u.position.distance_to(u.move_target)
		if d <= 26.0 and not u.has_move_order:
			arrived += 1
		rows.append({"position": str(u.position), "target": str(u.move_target),
			"distance": d, "arrival_seconds": arrival[i] / 60.0, "moving": u.has_move_order, "velocity": str(u.velocity)})
	var overlaps := 0
	for i in range(units.size()):
		for j in range(i + 1, units.size()):
			if units[i].position.distance_to(units[j].position) < (units[i].radius + units[j].radius) * 0.95:
				overlaps += 1
	evidence["formation"] = {"elapsed_seconds": (tick + 1) / 60.0, "units": rows, "neighbors": neighbors, "stats": b.path_service.stats()}
	check(arrived == 6, "six tanks reach assigned slots and finish orders within 60 seconds", arrived)
	check(overlaps == 0, "formation finishes without overlapping bodies", overlaps)
	# Actual command path, not a replacement movement state machine.
	var water: Rect2 = b.water_rects[0]
	b._command_move(water.get_center())
	var dry := true
	for u in units:
		dry = dry and not b.on_water(u.move_target)
	check(dry, "group water click assigns dry endpoints")
	for u in units:
		u.order_stop()

func _test_building(screen) -> void:
	var b = screen.battle
	b.set_process(false)
	for u in b.units:
		if is_instance_valid(u):
			u.set_physics_process(false)
	for building in b.buildings:
		if is_instance_valid(building):
			building.set_process(false)
	b.funds = 10000.0
	b.power_low = false
	var bd: Dictionary = GameData.get_building("GAPOWR")
	var spot := Vector2.INF
	var hq = b._player_hq()
	for x in range(-10, 11):
		for y in range(-10, 11):
			var candidate: Vector2 = b.snap_build_pos(hq.position + Vector2(x, y) * 40.0)
			if b.build_spot_ok(candidate, bd, true).ok:
				spot = candidate
				break
		if spot != Vector2.INF:
			break
	check(spot != Vector2.INF, "find legal building placement")
	if spot == Vector2.INF:
		return
	b.request_structure("GAPOWR")
	check(b.struct_queue.size() == 1, "sidebar request enters production queue")
	var seconds: float = GameData.ra2_build_time(bd)
	b._tick_structure_queue(seconds)
	check(int(b.struct_ready.get("GAPOWR", 0)) == 1, "completed production creates one ready building")
	var funds_before: float = b.funds
	check(is_equal_approx(10000.0 - funds_before, float(bd.cost)), "production charges exactly one building cost")
	b.set_build_mode("GAPOWR")
	b._try_place_building(spot)
	var building = b.buildings[-1]
	building.set_process(false)
	check(building.building_id == "GAPOWR" and building.position.is_equal_approx(spot),
		"ready building follows actual placement entry")
	check(is_equal_approx(b.funds, funds_before) and not building.under_construction,
		"placement does not charge twice or restart construction")
	check(not building._buildup_art.is_empty() and building._buildup_play == 0.0 and not building.is_operational(),
		"placement starts real buildup sequence and stays non-operational")
	var footprint: PackedVector2Array = building.footprint_poly()
	var duration: float = GameData.ra2_buildup_seconds() / BattleClock.PLACED_BUILDUP_SCALE
	var stages: Array = []
	b.camera.position = building.position
	b.camera.reset_smoothing()
	for i in range(3):
		if i > 0:
			building._process(duration * 0.4)
		await _capture("building-stage-%d.png" % i)
		stages.append({"time": building._buildup_play, "frame": building._art_frame,
			"operational": building.is_operational()})
		check(not building.is_operational(), "building stays non-operational during stage %d" % i)
	building._process(duration * 0.21)
	await _capture("building-complete.png")
	check(building._buildup_play < 0.0 and building.is_operational(), "building becomes operational after buildup")
	check(building.footprint_poly() == footprint, "buildup keeps placement and collision footprint stable")
	check(is_equal_approx(b.funds, funds_before), "buildup animation adds no construction charges")
	if DisplayServer.get_name() != "headless":
		check(stages[0].frame < stages[1].frame and stages[1].frame < stages[2].frame,
			"rendered buildup frames advance", stages)
	evidence["building"] = {"duration": duration, "stages": stages, "position": str(spot), "cost": bd.cost}

func _capture(filename: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var error := img.save_png(output_dir.path_join(filename))
	check(error == OK, "save rendered screenshot " + filename, error)
