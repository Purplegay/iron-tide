extends "res://tests/ground_control_regression.gd"

func exercise(mode: String) -> void:
	for scenario in [[false, false], [true, false], [false, true], [true, true]]:
		var late: bool = scenario[0]
		var nearby_buildings: bool = scenario[1]
		start(mode)
		for b in battle.buildings: b.free()
		battle.buildings.clear()
		if nearby_buildings:
			battle._place_building("GAPOWR", "ally", Vector2(1010, 940), true)
			battle._place_building("GADEPT", "ally", Vector2(1020, 1330), true)
		battle._refresh_pathing()
		var car = battle.spawn_unit("BFRT", "ally", Vector2(700, 1100))
		activate(car)
		car.hull_angle = 0.0
		var blockers: Array = []
		var origins: Array = []
		for x in 3:
			for y in 5:
				var at := Vector2(980 + x * 28, 1044 + y * 28)
				var soldier = battle.spawn_unit("GGI" if (x + y) % 2 == 0 else "E1", "ally", at)
				activate(soldier)
				if not late: soldier.set_deployed(true)
				blockers.append(soldier); origins.append(at)
		var goal := Vector2(1350, 1100)
		var terrain_before = battle.path_service.cost.duplicate()
		car.order_move(goal)
		await get_tree().physics_frame
		if late:
			for tick in 240:
				car._physics_process(1.0 / 60.0)
				await get_tree().physics_frame
			for soldier in blockers: soldier.set_deployed(true)
		car._physics_process(1.0 / 60.0)
		var without_soldiers: PackedVector2Array = battle.path_for_unit(car,goal,[])
		var with_soldiers: PackedVector2Array = battle.path_for_unit(car,goal,blockers)
		check(with_soldiers==without_soldiers, mode + ": friendly deployed infantry do not alter the planned route", str(with_soldiers))
		check(battle.path_service.cost == terrain_before, mode + ": temporary blockers preserve shared terrain grid")
		var time := 0.0
		var max_speed := 0.0
		for tick in 2400:
			car._physics_process(1.0 / 60.0)
			for soldier in blockers: soldier._physics_process(1.0 / 60.0)
			max_speed = maxf(max_speed, car.velocity.length())
			time += 1.0 / 60.0
			await get_tree().physics_frame
			if not car.has_move_order: break
		var info := {"mode":mode,"late_deploy":late,"nearby_buildings":nearby_buildings,"seconds":time,"position":str(car.position),"goal":str(goal),"path":str(car._path_pts)}
		metrics.append(info)
		check(car.position.distance_to(goal) < 16.0 and not car.has_move_order, mode + ": fortress routes around deployed platoon late=" + str(late), info)
		check(max_speed <= car.move_speed + 0.01, mode + ": detour respects native movement speed", [max_speed, car.move_speed])
		for i in blockers.size():
			check(blockers[i]._deployed and blockers[i].position.distance_to(origins[i]) < 0.1, mode + ": deployed soldier stays in place " + str(i))
			check(blockers[i].hp == blockers[i].max_hp, mode + ": no friendly crushing " + str(i))
		for soldier in blockers: soldier.set_deployed(false)
		var straight: PackedVector2Array = battle.path_for_unit(car, Vector2(700,1100))
		check(straight.size() == 2 if not nearby_buildings else straight.size() >= 2, mode + ": undeployment removes temporary path blockers", str(straight))
		await finish()
