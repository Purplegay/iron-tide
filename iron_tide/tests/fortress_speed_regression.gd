extends "res://tests/yr_fortress_regression.gd"

func _ready() -> void:
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not ProjectSettings.get_setting("application/config/use_custom_user_dir", false):
		get_tree().quit(2)
		return
	for mode in [MatchRules.RA2, MatchRules.EXTENDED]:
		for count in [1, 5]:
			await exercise_speed(mode, count)
	var file := FileAccess.open(output_dir.path_join("result.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failed": failed}, "  "))
	file.close()
	print("FORTRESS SPEED checks=", checks.size(), " failed=", failed)
	get_tree().quit(0 if failed == 0 else 1)

func shape_count(unit) -> int:
	return unit.get_children().filter(func(child): return child is CollisionShape2D).size()

func exercise_speed(mode: String, count: int) -> void:
	start(mode)
	prefix += "crew=%d: " % count
	GM.god_mode = false
	GM.one_shot_kill = false
	var car = actor("BFRT", "ally", Vector2(800, 1200))
	car.fire_stance = "none"
	var crew: Array = []
	for index in count:
		var passenger = actor("E1", "ally", car.position + Vector2(0, 30))
		board(passenger, car)
		crew.append(passenger)
	await get_tree().physics_frame
	await measure_travel(car, crew, "before promotion")
	car.order_stop()
	car.fire_stance = "auto"
	for passenger in crew:
		var victim = actor("E1", "enemy", car.position + Vector2(130, 0))
		victim.hp = 1.0
		passenger._vet_kills = passenger._vet_need - float(victim.data.cost)
		check(damage_target(passenger, victim) > 0, prefix + "real passenger shot kills victim")
		check(passenger.veteran_level == 1, prefix + "kill promotes embarked passenger")
		check(passenger.collision_layer == 0 and passenger.collision_mask == 0, prefix + "promotion preserves stowed collision exclusion")
		check(shape_count(passenger) == 1, prefix + "promotion does not duplicate collision shape", shape_count(passenger))
		if is_instance_valid(victim):
			battle.units.erase(victim)
			victim.free()
	car.fire_stance = "none"
	await get_tree().physics_frame
	await measure_travel(car, crew, "after combat promotion")
	for passenger in crew:
		passenger.credit_kill(passenger._vet_need, "enemy")
		check(passenger.veteran_level == 2 and passenger.collision_layer == 0 and passenger.collision_mask == 0, prefix + "elite passenger also remains non-colliding")
		check(shape_count(passenger) == 1, prefix + "elite refresh retains a single shape")
	await get_tree().physics_frame
	await measure_travel(car, crew, "after elite promotion")
	car.order_stop()
	# Reproduce a pre-fix save carrying the stale colliding-passenger flags.
	for passenger in crew:
		passenger.collision_layer = 1
		passenger.collision_mask = 7
		passenger._cd_timer = 0.73
	var saved := BattleSaves.save_slot(battle, "slot1")
	check(saved.ok, prefix + "legacy collision fixture saves", saved)
	if saved.ok:
		check(BattleSaves.prepare_load("slot1").ok, prefix + "legacy save validates")
		await finish()
		screen = load("res://scenes/battle.tscn").instantiate()
		add_child(screen)
		screen.process_mode = Node.PROCESS_MODE_DISABLED
		battle = screen.battle
		car = battle.units.filter(func(u): return u.unit_id == "BFRT")[0]
		crew = car.logistics.passengers
		for unit in [car] + crew:
			unit.process_mode = Node.PROCESS_MODE_ALWAYS
			unit.set_physics_process(false)
			unit.set_process(false)
		for passenger in crew:
			check(passenger.collision_layer == 0 and passenger.collision_mask == 0 and shape_count(passenger) == 1, prefix + "legacy load removes stale collision flags")
			check(passenger.embarked_in == car and not passenger.visible and passenger.veteran_level == 2 and is_equal_approx(passenger._cd_timer, 0.73), prefix + "load preserves transport rank visibility and reload")
		await get_tree().physics_frame
		await measure_travel(car, crew, "after legacy load")
	car.order_stop()
	check(car.deploy(), prefix + "normal unload still starts")
	for tick in 15: car.logistics.tick(0.4)
	check(car.logistics.passengers.is_empty(), prefix + "all promoted crew unload")
	for passenger in crew:
		check(passenger.embarked_in == null and passenger.visible and passenger.collision_layer == 1 and passenger.collision_mask == 7 and shape_count(passenger) == 1, prefix + "unload restores one normal ground collider")
	car._grant_veteran(1, false)
	car._grant_veteran(2, false)
	check(car.collision_layer == 1 and car.collision_mask == 7 and shape_count(car) == 1, prefix + "carrier promotion also keeps one normal collider")
	await finish()

func measure_travel(car, crew: Array, label: String) -> void:
	car.hull_angle = 0.0
	car._think_timer = 10000.0
	car.order_move(car.position + Vector2(350, 0))
	var peak := 0.0
	var distance := 0.0
	var limit := 0.0
	for tick in 60:
		for passenger in crew: passenger._physics_process(1.0 / 60.0)
		await get_tree().physics_frame
		var before: Vector2 = car.position
		car._physics_process(1.0 / 60.0)
		var step: float = car.position.distance_to(before)
		peak = maxf(peak, step)
		distance += step
		limit += car.move_speed / 60.0
	check(peak <= car.move_speed / 60.0 + 0.1, prefix + label + " actual displacement stays within speed per tick", peak)
	check(distance > limit * 0.8 and distance <= limit + 1.0, prefix + label + " travels at intended speed for one second", {"actual": distance, "expected": limit})
