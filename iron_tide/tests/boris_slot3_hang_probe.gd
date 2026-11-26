extends Node

func _ready() -> void:
	get_tree().current_scene = null
	call_deferred("run")

func run() -> void:
	var out := OS.get_environment("IRON_TIDE_REPORT_DIR")
	if out.is_empty() or not OS.get_user_data_dir().contains("IronTideSlot3Hang"):
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(BattleSaves.DIRECTORY)
	if DirAccess.copy_absolute(OS.get_environment("IRON_SAVE"), ProjectSettings.globalize_path(BattleSaves.slot_path("slot1"))) != OK:
		get_tree().quit(3)
		return
	var loaded := BattleSaves.load_into_scene("slot1")
	if not loaded.ok:
		print("LOAD_FAILED ", loaded)
		get_tree().quit(4)
		return
	await get_tree().scene_changed
	var world = get_tree().current_scene.battle
	var checks: Array = []
	var subjects: Array = world.units.filter(func(u): return world.actor_alive(u) and u.side == "ally" and u.unit_id in ["BORIS", "HTNK"] and u.position.distance_to(Vector2(4977.5, 7232.5)) < 500.0)
	checks.append({"name":"saved fourth-era squad", "ok": world.mission.get("id") == "yr_time_shift" and world.allied_state.time_shift.phase == 4 and subjects.size() == 5})
	checks.append({"name":"retail map boundary includes base", "ok": world.path_service.time_shift_area == world.TimeShift.BOUNDS[2] and subjects.all(func(u): return (world.path_service.native_flags(u.position) & 1) != 0 and u._domain_ok(u.position))})
	var raw := preload("res://scripts/world/native_maps.gd").data(world.map_layout())
	var rock := Vector2.INF
	for cell in raw.cells:
		if int(cell[2]) == 15:
			var point := (Vector2(cell[0],cell[1]) + Vector2(0.5,0.5)) * 55.0
			if world.TimeShift.region(Vector2i(cell[0],cell[1]),world.path_service.time_shift_area):
				rock = point
				break
	checks.append({"name":"native impassable terrain stays blocked", "ok": rock.is_finite() and world.path_service.native_flags(rock) == 4})
	get_tree().paused = false
	world.paused = false
	var start_positions: Array = []
	for unit in subjects:
		start_positions.append(unit.position)
		unit.order_move(unit.position + Vector2(-350,300))
	checks.append({"name":"five move commands accepted", "ok": subjects.size() == 5 and subjects.all(func(u):return u.has_move_order)})
	var elapsed := 0.0
	while elapsed < 3.0:
		await get_tree().physics_frame
		elapsed += get_physics_process_delta_time()
	var moved := subjects.size() == 5
	for i in subjects.size():
		moved = moved and world.actor_alive(subjects[i]) and subjects[i].position.distance_to(start_positions[i]) > 20.0
	checks.append({"name":"Boris and four tanks move on restored battlefield", "ok": moved})
	var failed := checks.filter(func(c):return not c.ok).size()
	var file := FileAccess.open(out.path_join("result.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	file.close()
	print("SOV01_SLOT3_MOVE ",checks.size()," checks, ",failed," failed")
	get_tree().quit(0 if failed == 0 else 1)
