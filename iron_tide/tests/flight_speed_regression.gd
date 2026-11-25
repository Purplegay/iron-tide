extends "res://tests/logistics_regression.gd"

var speed_metrics: Array = []

func exercise_mode(mode: String) -> void:
	setup_logistics_scene(mode, "美国")
	var ids: Array = []
	for id in GameData.unit_index:
		if GameData.get_unit(id).get("tags", []).has("air"): ids.append(id)
	ids.sort()
	check(ids.size() == 7, mode + " audit includes all seven runtime air units", ids)
	for id in ids:
		var unit = battle.spawn_unit(str(id), "ally", Vector2(600, 2000))
		activate(unit)
		unit.fire_stance = "none"
		unit._think_timer = 10000.0
		unit.hull_angle = 0.0
		unit.logistics.air_lift = 1.0
		unit.order_move(Vector2(2700, 2000))
		await get_tree().physics_frame
		var top: float = unit.flight.max_speed()
		var origin: Vector2 = unit.position
		var reached := -1.0
		var first_second := 0.0
		for tick in 120:
			unit._physics_process(1.0 / 60.0)
			if reached < 0.0 and unit.velocity.length() >= top * 0.95: reached = float(tick + 1) / 60.0
			if tick == 59: first_second = unit.position.distance_to(origin)
		check(reached > 0.0 and reached <= 1.0, mode + " " + id + " airborne straight start reaches cruise promptly", reached)
		check(first_second >= top * 0.6, mode + " " + id + " first-second travel is not bogged down", first_second)
		check(unit.velocity.length() <= top + 0.01 and unit.velocity.length() >= top * 0.95, mode + " " + id + " respects unchanged cruise limit")
		# Already cruising straight, outside the physical braking distance.
		# A turn-radius limiter must not slow a zero-angle approach.
		unit.position = origin
		var approach: float = top * top / (2.0 * unit.flight.acceleration) + 35.0
		unit.move_target = origin + Vector2(approach, 0)
		unit.velocity = Vector2(top, 0)
		unit.flight.travel(unit.move_target, 1.0 / 60.0)
		var near_speed: float = unit.velocity.length()
		check(near_speed >= top * 0.99, mode + " " + id + " aligned approach preserves cruise outside braking distance", near_speed)
		var before: Vector2 = unit.position
		unit.order_stop()
		for tick in 240: unit._physics_process(1.0 / 60.0)
		check(unit.velocity.length() < 0.01, mode + " " + id + " stop converges to rest")
		check(unit.position.distance_to(before) <= top * top / (2.0 * unit.flight.acceleration) + 15.0, mode + " " + id + " braking stays bounded")
		var speed: float = unit.move_speed
		unit.move_speed = speed * 1.2
		check(is_equal_approx(unit.flight.max_speed(), top * 1.2), mode + " " + id + " speed modifiers remain effective")
		unit.move_speed = speed
		speed_metrics.append({"mode": mode, "unit": id, "cruise": top, "acceleration": unit.flight.acceleration,
			"seconds_to_95_percent": reached, "distance_first_second": first_second, "aligned_approach_speed": near_speed})
		remove_actor(unit)
		await get_tree().process_frame
	# Original rocketeer is an eight-direction sprite, unlike 32-angle voxel aircraft.
	var seq := RA2Art.seq("JUMPJET")
	for state in ["Fly", "Hover", "FireFly"]:
		check(int(seq[state].facings) == 8, mode + " original rocketeer " + state + " has eight real facings")
	for id in ["ORCA", "BEAG", "SHAD", "HORNET"]:
		check(int(RA2Art.art(id).facings) == 32, mode + " " + id + " keeps 32 voxel facings")
	screen.free()
	await get_tree().process_frame
	var file := FileAccess.open(output_dir.path_join("speed-metrics.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(speed_metrics, "  "))
	file.close()
