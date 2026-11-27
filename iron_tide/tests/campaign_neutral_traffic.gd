extends Node

var failures := 0
var world: Battle

func _ready() -> void:
	call_deferred("run")

func check(ok: bool, label: String, detail = "") -> void:
	print("NEUTRAL ", "PASS" if ok else "FAIL", " ", label, " ", detail)
	if not ok: failures += 1

func actor(id: String, side: String, at: Vector2) -> Unit:
	var unit: Unit = world.spawn_unit(id, side, at)
	unit.process_mode = Node.PROCESS_MODE_ALWAYS
	unit.set_process(false)
	unit.set_physics_process(false)
	unit.set_fire_stance("none")
	unit.order_stop()
	return unit

func run() -> void:
	var profile := OS.get_environment("IRON_TIDE_TEST_PROFILE").replace("\\", "/").to_lower()
	if profile.is_empty() or not OS.get_user_data_dir().replace("\\", "/").to_lower().begins_with(profile + "/"):
		printerr("Not using the isolated profile: ", OS.get_user_data_dir())
		get_tree().quit(2)
		return
	BattleRequest.configure_mission("yr_hollywood", {"campaign_growth": false})
	var screen = load("res://scenes/battle.tscn").instantiate()
	add_child(screen)
	world = screen.battle
	var residents := world.units.filter(func(u): return u.side == "neutral" and u.unit_id.begins_with("CIV"))
	check(world.mission.id == "yr_hollywood" and not residents.is_empty(), "Hollywood assembles native neutral residents", residents.size())
	# Freeze scripting/combat; retain the real actors, collision and retail terrain.
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	get_tree().paused = false
	var start := Vector2.INF
	for x in range(1000, int(world.map_size) - 1000, 200):
		for y in range(1000, int(world.map_size) - 1000, 200):
			var p := Vector2(x, y)
			if not world.path_service.line_walkable(p - Vector2(40, 80), p + Vector2(720, -80), world.path_service.cost): continue
			if not world.path_service.line_walkable(p - Vector2(40, 80), p + Vector2(720, 80), world.path_service.cost): continue
			if not world.path_service.line_walkable(p - Vector2(40, 0), p + Vector2(720, 0), world.path_service.cost): continue
			if world.units.any(func(u): return u.position.distance_to(p + Vector2(320, 0)) < 550): continue
			if world.buildings.any(func(b): return b.position.distance_to(p + Vector2(320, 0)) < 620): continue
			start = p
			break
		if start.is_finite(): break
	check(start.is_finite(), "isolated stretch on the retail terrain", start)
	if not start.is_finite():
		get_tree().quit(1)
		return
	# Controlled spawn positions and visibility; leave the terrain and actors real.
	var goal := start + Vector2(640, 0)
	var crossing := start + Vector2(156, 0)
	var tank := actor("MTNK", "ally", start)
	var civilian := actor("CIV2", "neutral", crossing)
	await get_tree().physics_frame
	var service := world.movement_service(tank)
	var terrain := service.cost.duplicate()
	var fog = world.fog
	var original_sight: PackedByteArray = fog.visible_cells["ally"]
	var hidden := original_sight.duplicate()
	hidden.fill(0)
	fog.visible_cells["ally"] = hidden
	check(world.path_for_unit(tank, goal, []).size() == 2, "unseen residents do not reveal themselves by changing routes")
	fog.visible_cells["ally"] = original_sight
	world.fog = null
	world.skirmish = true
	check(world.path_for_unit(tank, goal, []).size() == 2, "skirmish routing unchanged")
	world.skirmish = false
	civilian.special.hollywood_on_deck = true
	check(world.path_for_unit(tank, goal, []).size() == 2, "street route ignores elevated resident")
	civilian.special.erase("hollywood_on_deck")
	civilian.collision_layer = 0
	check(world.path_for_unit(tank, goal, []).size() == 2, "route ignores non-solid resident")
	civilian.collision_layer = 1
	civilian.order_move(crossing + Vector2(0, 200))
	check(world.path_for_unit(tank, goal, []).size() == 2, "moving resident is not reserved as a parked obstacle")
	civilian.order_stop()
	world.select_unit(tank, false)
	world._command_move(goal)
	check(tank._path_pts.size() > 2 and tank._path_pts[-1].is_equal_approx(goal), "player move plots detour before contact", tank._path_pts)
	await move_to_goal(tank, goal, "tank with resident present at order time")
	check(civilian.global_position == crossing and civilian.hp == civilian.max_hp and not civilian._local_traffic.yield_target.is_finite(), "resident is not moved, pushed or damaged")
	civilian.free()
	tank.free()
	await get_tree().physics_frame
	var soldier := actor("E1", "ally", start)
	world.select_unit(soldier, false)
	world._command_move(goal)
	check(soldier._path_pts.size() == 2, "infantry starts on an unobstructed route", soldier._path_pts)
	for tick in 20:
		soldier._physics_process(1.0 / 60.0)
		await get_tree().physics_frame
	var late := actor("CIV2", "neutral", start + Vector2(310, 0))
	await get_tree().physics_frame
	await move_to_goal(soldier, goal, "infantry recovers from later obstruction")
	check(soldier._path_pts.size() > 2 and soldier._path_pts[-1].is_equal_approx(goal), "stalled infantry replans around the neutral instead of repeating the straight route", soldier._path_pts)
	check(not late.has_move_order and late.hp == late.max_hp and late.global_position == start + Vector2(310, 0), "later resident remains unchanged")
	check(terrain == service.cost, "temporary circles do not change the shared terrain grid")
	get_tree().quit(0 if failures == 0 else 1)

func move_to_goal(unit: Unit, goal: Vector2, label: String) -> void:
	var tick := 0
	while unit.has_move_order and tick < 1000:
		unit._physics_process(1.0 / 60.0)
		tick += 1
		await get_tree().physics_frame
	check(not unit.has_move_order and unit.global_position.distance_to(goal) <= Unit.ARRIVE_EPS + 1.0, label, [tick, unit.global_position, unit._path_pts])
