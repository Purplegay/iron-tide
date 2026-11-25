extends "res://tests/base_recovery_regression.gd"

func _ready() -> void:
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not ProjectSettings.get_setting("application/config/use_custom_user_dir", false):
		get_tree().quit(2)
		return
	await get_tree().process_frame
	for mode in [MatchRules.RA2, MatchRules.EXTENDED]:
		start(mode)
		if battle.fog != null:
			battle.fog.free()
			battle.fog = null
		for b in battle.buildings: b.free()
		battle.buildings.clear()
		battle._refresh_pathing()
		for kind in ["ore", "gems"]:
			await cross_field(kind)
		await solid_boundaries()
		await finish()
	var f := FileAccess.open(output_dir.path_join("result.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks": checks, "failed": failed,
		"scope": "Real move orders, A-star and CharacterBody2D physics over dense ore and gems in both modes and sides"}, "  "))
	f.close()
	print("ORE_PASSAGE checks=", checks.size(), " failed=", failed)
	get_tree().quit(0 if failed == 0 else 1)

func cross_field(kind: String) -> void:
	var nodes: Array = []
	for x in range(1140, 1261, 30):
		for y in range(1020, 1381, 30):
			# Use actual map placement, including original resource radius/density.
			battle._spawn_ore_tile(Vector2(x, y), 250.0, 30.0, kind)
			var n = battle.get_child(battle.get_child_count() - 1)
			n.process_mode = Node.PROCESS_MODE_ALWAYS
			n.set_process(false)
			nodes.append(n)
	battle._refresh_pathing()
	var center: Vector2 = Vector2(1200, 1200)
	check(not battle.path_service.is_blocked(center), prefix + kind + " resource cells remain walkable in path grid")
	check(battle.build_spot_ok(center, GameData.get_building("GAPOWR"), true).reason == "与矿点重叠",
		prefix + kind + " walkable resources still reject building foundations")
	for side in ["ally", "enemy"]:
		for id in ["E1", "MTNK", "CMIN"]:
			var label: String = prefix + kind + " " + side + " " + id + ": "
			var u = battle.spawn_unit(id, side, Vector2(900, 1200))
			u.process_mode = Node.PROCESS_MODE_ALWAYS
			u.set_process(false)
			u.set_physics_process(false)
			u.set_fire_stance("none")
			u.order_stop()
			await get_tree().physics_frame
			check(not u.test_move(u.global_transform, Vector2(600, 0)), label + "physics agrees that dense ore is traversable")
			var total := total_amount(nodes)
			for goal in [center, Vector2(1500, 1200)]:
				u.order_move(goal)
				var deviation := 0.0
				for tick in 900:
					await get_tree().physics_frame
					u._physics_process(1.0 / 60.0)
					deviation = maxf(deviation, absf(u.global_position.y - 1200.0))
					if u.global_position.distance_to(goal) < 12.0: break
				check(u.global_position.distance_to(goal) < 12.0,
					label + "actual move reaches " + str(goal), {"position": str(u.global_position), "goal": str(goal)})
				check(deviation < 45.0, label + "crosses through ore instead of detouring around field", deviation)
			check(is_equal_approx(total_amount(nodes), total), label + "movement does not destroy or extract resource")
			if u.is_harvester:
				battle.selected_units = [u]
				check(battle._try_harvest_at(center) and is_instance_valid(u.resource_node), label + "resource remains selectable for harvest")
				battle.selected_units.clear()
			battle.units.erase(u)
			u.free()
			await get_tree().physics_frame
	var central = nodes[nodes.size() / 2]
	central.extract(central.amount)
	check(central.is_empty(), prefix + kind + " extraction still depletes resource")
	if BattleRequest.extensions_enabled() and kind == "ore":
		central._process(1.0)
		check(central.amount > 0.0, prefix + "extension ore still regenerates")
	for n in nodes: n.free()
	await get_tree().physics_frame

func total_amount(nodes: Array) -> float:
	var total := 0.0
	for n in nodes: total += n.amount
	return total

func solid_boundaries() -> void:
	var u = battle.spawn_unit("MTNK", "ally", Vector2(900, 1200))
	u.process_mode = Node.PROCESS_MODE_ALWAYS
	u.set_process(false)
	u.set_physics_process(false)
	u.order_stop()
	var rock := Obstacle.new()
	rock.process_mode = Node.PROCESS_MODE_ALWAYS
	rock.position = Vector2(1200, 1200)
	battle.add_child(rock)
	await get_tree().physics_frame
	check(u.test_move(u.global_transform, Vector2(600, 0)), prefix + "rock collision remains solid")
	rock.free()
	var building = battle._place_building("GAWEAP", "ally", Vector2(1200, 1200), true)
	building.process_mode = Node.PROCESS_MODE_ALWAYS
	building.set_process(false)
	await get_tree().physics_frame
	check(u.test_move(u.global_transform, Vector2(600, 0)), prefix + "building collision remains solid")
	check(battle.path_service.is_blocked(Vector2(1200, 1200)), prefix + "building remains blocked in path grid")
	battle.buildings.erase(building)
	building.free()
	battle.units.erase(u)
	u.free()
