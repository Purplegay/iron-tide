extends "res://tests/base_recovery_regression.gd"
var metrics: Array = []

func _ready() -> void:
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not ProjectSettings.get_setting("application/config/use_custom_user_dir", false):
		get_tree().quit(2)
		return
	seed(21102026)
	for mode in [MatchRules.RA2, MatchRules.EXTENDED]:
		await exercise(mode)
	var file := FileAccess.open(output_dir.path_join("result.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failed": failed, "metrics": metrics}, "  "))
	file.close()
	get_tree().quit(0 if failed == 0 else 1)

func activate(actor) -> void:
	actor.process_mode = Node.PROCESS_MODE_ALWAYS
	actor.set_process(false)
	actor.set_physics_process(false)
	actor.order_stop()
	actor.set_fire_stance("none")

func step(actors: Array, count: int) -> void:
	for i in count:
		for actor in actors: actor._physics_process(1.0 / 60.0)
		if i % 30 == 0: await get_tree().process_frame

func check_attack_sides() -> void:
	var center := Vector2(1260, 1250)
	var factory = battle._place_building("GAWEAP", "enemy", center, true)
	factory._buildup_play = -1
	factory.max_hp = 100000
	factory.hp = factory.max_hp
	battle._refresh_pathing()
	for direction in [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]:
		var d: Vector2 = direction
		var truck = battle.spawn_unit("DTRUCK", "ally", center + d * 320)
		activate(truck)
		battle.select_unit(truck, false)
		battle.force_attack(factory)
		await get_tree().physics_frame
		for frame in 750:
			truck._physics_process(1.0 / 60.0)
			if truck._dead: break
		check(truck._dead and (truck.position - center).dot(d) > 0, prefix + "truck reaches and detonates on approaching side " + str(d), [truck.position, truck.move_target])
		battle.units.erase(truck)
		truck.free()
		for id in ["E1", "MTNK"]:
			var actor = battle.spawn_unit(id, "ally", center + d * 800)
			activate(actor)
			var edge := CommandoCombat.contact_point(actor, factory)
			actor.position = edge + (actor.position - edge).normalized() * (actor.attack_range - 2)
			battle.select_unit(actor, false)
			battle.force_attack(factory)
			var before: Vector2 = actor.position
			actor._process_combat(0.1)
			actor.hull_angle = before.angle_to_point(center)
			actor.turret_angle = actor.hull_angle
			check(not actor.has_move_order and actor.position == before and actor._try_fire_ready(), prefix + id + " fires from near edge " + str(d))
			battle.units.erase(actor)
			actor.free()
	battle.buildings.erase(factory)
	factory.free()
	battle._refresh_pathing()
	var victim = battle.spawn_unit("MTNK", "enemy", center)
	victim.max_hp = 10000
	victim.hp = victim.max_hp
	for direction in [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]:
		var d: Vector2 = direction
		var truck = battle.spawn_unit("DTRUCK", "ally", center + d * (victim.radius + 50.0))
		activate(truck)
		truck.hull_angle = d.angle()
		battle.select_unit(truck, false)
		battle.force_attack(victim)
		check(truck._try_fire_ready() and truck._dead, prefix + "back-facing truck proximity detonation " + str(d))
		battle.units.erase(truck)
		truck.free()
	battle.units.erase(victim)
	victim.free()
	battle.clear_selection()

func exercise(mode: String) -> void:
	start(mode)
	if battle.fog != null:
		battle.fog.free()
		battle.fog = null
	for building in battle.buildings: building.free()
	battle.buildings.clear()
	battle._refresh_pathing()
	await check_attack_sides()
	var origin := Vector2(400, 600)
	var tank = battle.spawn_unit("MTNK", "ally", origin)
	activate(tank)
	tank.hull_angle = 0.0
	tank.order_move(origin + Vector2(0, 400))
	await get_tree().physics_frame
	await step([tank], 1)
	check(tank.position.distance_to(origin) < 0.01, prefix + "sideways move turns hull before translation")
	var max_slip := 0.0
	var max_turn := 0.0
	for tick in 180:
		var angle: float = tank.hull_angle
		tank._physics_process(1.0 / 60.0)
		max_turn = maxf(max_turn, absf(angle_difference(angle, tank.hull_angle)))
		if tank.velocity.length() > 5.0:
			max_slip = maxf(max_slip, absf(angle_difference(tank.hull_angle, tank.velocity.angle())))
	check(max_turn <= deg_to_rad(float(tank.data.move.rot) / 60.0) + 0.0001, prefix + "turn speed respects actual ROT", max_turn)
	check(max_slip < deg_to_rad(5.0), prefix + "driving velocity follows visible hull instead of strafing", rad_to_deg(max_slip))
	var turn_origin: Vector2 = tank.position
	tank.order_move(turn_origin - Vector2.from_angle(tank.hull_angle) * 300)
	await step([tank], 1)
	check(tank.position.distance_to(turn_origin) < 0.01, prefix + "reverse order brakes and turns rather than instantly driving backwards")
	tank.order_stop()
	tank.position = origin
	var peer = battle.spawn_unit("MTNK", "ally", origin + Vector2(tank.radius * 2 + 2, 0))
	activate(peer)
	await get_tree().physics_frame
	await step([tank], 120)
	check(tank.position.distance_to(origin) < 0.01, prefix + "stopped non-overlapping tank does not drift from neighbor separation", tank.position.distance_to(origin))
	battle.units.erase(peer)
	peer.free()
	tank.position = origin
	tank.hull_angle = 0.0
	var rocks: Array = []
	for y in range(200, 1400, 120):
		var rock = preload("res://scripts/world/obstacle.gd").new()
		rock.position = Vector2(1100, y)
		rock.radius = 74.0
		rock.process_mode = Node.PROCESS_MODE_ALWAYS
		battle.add_child(rock)
		rocks.append(rock)
	battle._refresh_pathing()
	var target = battle.spawn_unit("MTNK", "enemy", Vector2(1850, 600))
	activate(target)
	tank.set_fire_stance("free")
	tank._cd_timer = 99999.0
	battle.select_unit(tank, false)
	battle.force_attack(target)
	check(tank._path_pts.size() > 2, prefix + "attack order has a real route around the barrier")
	await get_tree().physics_frame
	var reached := false
	var ticks := 0
	var detour := 0.0
	for i in 3600:
		tank._physics_process(1.0 / 60.0)
		detour = maxf(detour, absf(tank.position.y - origin.y))
		if tank._weapon_target_valid(target):
			reached = true
			ticks = i + 1
			break
		if i % 60 == 0: await get_tree().process_frame
	check(reached and detour > 300, prefix + "explicit attack actually follows detour and reaches firing range", {"reached":reached,"detour":detour,"position":str(tank.position)})
	metrics.append({"mode":mode,"chase_seconds":ticks / 60.0,"chase_reached":reached,"slip_degrees":rad_to_deg(max_slip)})
	if reached:
		target.position += Vector2(0, 500)
		for i in 1800:
			tank._physics_process(1.0 / 60.0)
			if tank._weapon_target_valid(target): break
			if i % 60 == 0: await get_tree().process_frame
		check(tank._weapon_target_valid(target), prefix + "pursuit refreshes route when target moves")
	for rock in rocks: rock.free()
	for actor in [tank, target]:
		battle.units.erase(actor)
		actor.free()
	battle._refresh_pathing()
	battle.clear_selection()
	var squad: Array = []
	for i in 20:
		var u = battle.spawn_unit("MTNK", "ally", Vector2(400 + (i % 5) * 75, 1400 + (i / 5) * 75))
		activate(u)
		squad.append(u)
	battle.selected_units = squad.duplicate()
	battle._command_move(Vector2(1800, 1600))
	await get_tree().physics_frame
	var arrived := 0
	var elapsed := 0
	for i in 3600:
		arrived = 0
		for u in squad:
			u._physics_process(1.0 / 60.0)
			if not u.has_move_order and u.position.distance_to(u.move_target) <= 26: arrived += 1
		elapsed = i + 1
		if arrived == squad.size(): break
		if i % 60 == 0: await get_tree().process_frame
	check(arrived == 20, prefix + "twenty tanks finish assigned formation positions within sixty seconds", arrived)
	var overlap := 0
	for i in squad.size():
		for j in range(i + 1, squad.size()):
			if squad[i].position.distance_to(squad[j].position) < (squad[i].radius + squad[j].radius) * 0.95: overlap += 1
	check(overlap == 0, prefix + "twenty tank formation has no body overlaps", overlap)
	var rows: Array = []
	for u in squad:
		rows.append({"position":str(u.position),"target":str(u.move_target),"distance":u.position.distance_to(u.move_target),"moving":u.has_move_order,"turning":u._drive_turning,"angle":rad_to_deg(u.hull_angle),"velocity":str(u.velocity),"path":str(u._path_pts),"waypoint":u._path_i})
	metrics.append({"rows":rows,"mode":mode,"formation_arrived":arrived,"formation_seconds":elapsed / 60.0,"overlaps":overlap})
	await finish()
