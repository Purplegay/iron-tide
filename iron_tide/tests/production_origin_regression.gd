extends "res://tests/selection_regression.gd"

const Airport = preload("res://scripts/buildings/airport_dock.gd")

func make_building(id: String, point: Vector2):
	var b = battle._place_building(id, "ally", point, true)
	b.process_mode = Node.PROCESS_MODE_DISABLED
	b._buildup_play = -1.0
	return b

func produce(b, id: String):
	# Start from a paid-for-production order, exercising the actual timed queue,
	# money, completion, spawn and producer/rally paths rather than direct spawn.
	b.production.assign([id]); b.progress = 0.0; b.production_paid = 0.0
	b._process(10000.0)
	return battle.units[-1] if b.production.is_empty() else null

func remove_unit(u) -> void:
	if is_instance_valid(u): battle.units.erase(u); u.free()

func photo(label: String, producer) -> void:
	if DisplayServer.get_name() == "headless": return
	battle._update_depth_order()
	battle.camera.position = producer.position
	battle.camera.zoom = Vector2(3, 1.5)
	battle.camera.reset_smoothing(); battle.camera.force_update_scroll()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	stage.get_texture().get_image().save_png(output_dir.path_join(label + ".png"))

func exercise_mode(mode: String) -> void:
	BattleRequest.configure_skirmish(mode, {"map_size": 5000, "starting_funds": 100000, "fog_of_war": false})
	screen = load("res://scenes/battle.tscn").instantiate()
	stage.add_child(screen); battle = screen.battle
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	check(battle.units.filter(func(u): return u.side == "ally" and u.unit_id == "CMIN").size() == 2, mode + ": opening retains both miners")
	for initial in battle.buildings:
		if initial.side == "ally" and initial.building_id == "GAPILE":
			check(initial._spawn_point("E1") != Vector2.INF, mode + ": starting barracks has a usable physical exit", str(ProductionExit.origin(initial, GameData.get_unit("E1"))))
	for actor in battle.units + battle.buildings: actor.free()
	battle.units.clear(); battle.buildings.clear()
	for group in ["obstacles", "resource_nodes"]:
		for actor in get_tree().get_nodes_in_group(group): actor.free()
	battle.water_rects.clear(); battle.path_service.set_water([])
	battle._refresh_pathing()
	battle.power_low = false; battle.funds = 1000000
	GM.god_mode = false; GM.no_build_time = false; GM.infinite_funds = false
	var prerequisites := ["GACNST", "GAPOWR", "GAPILE", "GAREFN", "GAWEAP", "GAAIRC", "GATECH", "GADEPT", "GAROBO"]
	for i in prerequisites.size(): make_building(prerequisites[i], Vector2(600 + (i % 3) * 350, 600 + (i / 3) * 350))
	if mode == MatchRules.EXTENDED:
		var base = make_building("GACNST", Vector2(1520, 1550))
		base.special[Ra3Clearance.KEY] = {"tier":3, "target":0, "paused":false, "elapsed":0.0, "paid":0.0}
	battle.power_low = false
	var prefix := mode + ": "
	for spec in [["GAPILE", ["E1", "GGI", "ENGINEER", "DOG", "JUMPJET"]], ["GAWEAP", ["MTNK", "FV", "BFRT", "CMIN", "AMCV", "SHAD", "R3MIRAGE"]], ["GAREFN", ["CMIN"]]]:
		var b = make_building(spec[0], Vector2(1800, 1800))
		battle._refresh_pathing()
		for id in spec[1]:
			if id == "R3MIRAGE" and mode == MatchRules.RA2: continue
			var expected: Vector2 = b._spawn_point(id)
			check(expected != Vector2.INF, prefix + spec[0] + " has legal port for " + id)
			var money: float = battle.funds
			var u = produce(b, id)
			check(is_instance_valid(u), prefix + id + " completes real production")
			if not is_instance_valid(u): continue
			u.process_mode = Node.PROCESS_MODE_DISABLED
			check(u.position.is_equal_approx(expected), prefix + id + " appears at declared port without relocation")
			check(is_equal_approx(u.hull_angle, ProductionExit.direction(b).angle()), prefix + id + " faces away from its actual exit")
			check(is_equal_approx(money - battle.funds, float(GameData.get_unit(id).cost)), prefix + id + " charges exactly once")
			if id == "SHAD":
				await photo(mode + "-roof-calibration", b)
				if DisplayServer.get_name() != "headless":
					check(u.art_center().distance_to(ProductionExit.art_point(b, Vector2(155, 145))) < 1.0, prefix + "rendered helicopter body aligns with roof hatch")
			elif not u.is_air:
				check(not ProductionExit.near_footprint(b, expected, u.radius), prefix + id + " clears physical producer footprint")
			if id in ["MTNK", "E1", "CMIN", "SHAD"]: await photo(mode + "-" + spec[0] + "-" + id, b)
			if id == "MTNK":
				check(u.has_move_order, prefix + "default departure clears fixed vehicle port")
				var shifted: Vector2 = b._spawn_point(id)
				check(shifted != Vector2.INF and shifted != expected and shifted.distance_to(expected) <= 160.01, prefix + "occupied door shifts to a nearby free position")
				check((shifted - expected).dot(ProductionExit.direction(b)) >= -0.01, prefix + "offset never goes behind the exit")
				check(b._spawn_point(id) == shifted and shifted.distance_to(u.position) >= u.radius * 2.0 + 2.0, prefix + "offset is deterministic and clears the existing unit")
				var saved_cost: PackedFloat32Array = battle.path_service.cost.duplicate()
				battle.path_service.cost.fill(-1.0)
				b.production.assign([id]); b.progress = GameData.ra2_build_time(GameData.get_unit(id)) / b.build_speed
				b.production_paid = float(GameData.get_unit(id).cost)
				var count: int = battle.units.size()
				money = battle.funds
				b._process(10.0)
				check(b.exit_blocked and battle.units.size() == count and battle.funds == money, prefix + "blocked ready unit keeps payment and queue")
				battle.path_service.cost = saved_cost
				b._process(0.0)
				check(b.production.is_empty() and battle.units.size() == count + 1 and battle.funds == money and battle.units[-1].position == shifted, prefix + "clearing nearby space releases exactly one paid unit at offset")
				remove_unit(battle.units[-1])
				# Actual movement, not teleporting the first unit, must reopen the port.
				u.process_mode = Node.PROCESS_MODE_ALWAYS
				u.set_physics_process(false)
				await get_tree().physics_frame
				for tick in 180:
					u._physics_process(1.0 / 60.0)
					await get_tree().physics_frame
				check(u.position.distance_to(expected) > u.radius * 2.0 + 2.0 and b._spawn_point(id) == expected, prefix + "real default departure reopens original exit")
				u.process_mode = Node.PROCESS_MODE_DISABLED
			remove_unit(u)
		if b.building_id == "GAPILE":
			var squad: Array = []
			for uid in ["E1", "GGI", "GGI", "E1"]:
				var recruit = produce(b, uid)
				if not is_instance_valid(recruit): break
				check(squad.all(func(other): return other.position.distance_to(recruit.position) >= other.radius + recruit.radius), prefix + "successive recruits clear occupied exit")
				squad.append(recruit)
			check(squad.size() == 4, prefix + "four consecutive recruits leave the barracks")
			for recruit in squad: remove_unit(recruit)
		battle.buildings.erase(b); b.free()
	# Each production airport must use its own four real pads, even with another
	# empty airport nearby. En-route aircraft keep their reservations.
	var airport = make_building("GAAIRC", Vector2(2000, 2000))
	var spare = make_building("GAAIRC", Vector2(2700, 2000))
	for slot in 4:
		var expected := Airport.production_point(airport, "ORCA")
		var plane = produce(airport, "ORCA")
		check(is_instance_valid(plane), prefix + "airport produces slot " + str(slot))
		if not is_instance_valid(plane): continue
		plane.process_mode = Node.PROCESS_MODE_DISABLED
		check(plane.position.is_equal_approx(expected) and plane.logistics.home == airport and plane.logistics.dock_slot == slot and plane.logistics.air_state == "parked", prefix + "exact reserved pad and producer retained " + str(slot))
	check(airport._spawn_point("ORCA") == Vector2.INF and spare._spawn_point("ORCA") != Vector2.INF, prefix + "full airport cannot spawn aircraft at another factory")
	var funds: float = battle.funds
	var count: int = battle.units.size()
	produce(airport, "ORCA")
	check(airport.exit_blocked and battle.units.size() == count and airport.production == ["ORCA"], prefix + "full local pads retain completed production")
	check(is_equal_approx(funds - battle.funds, float(GameData.get_unit("ORCA").cost)), prefix + "blocked aircraft paid once")
	await photo(mode + "-airport-pads", airport)
	for u in battle.units.duplicate(): remove_unit(u)
	var yard = make_building("GAYARD", Vector2(3500, 3500))
	battle.water_rects.assign([Rect2(Vector2.ZERO, Vector2(5000, 5000))])
	battle.path_service.set_water(battle.water_rects); battle._refresh_pathing()
	for id in ["DEST", "AEGIS", "CARRIER", "LCRF", "DLPH"]:
		var p: Vector2 = yard._spawn_point(id)
		var u = produce(yard, id)
		check(p != Vector2.INF and is_instance_valid(u), prefix + "shipyard port produces " + id)
		if not is_instance_valid(u): continue
		u.process_mode = Node.PROCESS_MODE_DISABLED
		check(u.position.is_equal_approx(p) and battle.in_water_world(p), prefix + id + " stays at water exit")
		if id == "DEST": await photo(mode + "-shipyard", yard)
		remove_unit(u)
	screen.free()
	Ra2Sfx.stop_all(); Music.stop(); Music.player.stream = null
	await get_tree().process_frame
	OS.delay_msec(150)
