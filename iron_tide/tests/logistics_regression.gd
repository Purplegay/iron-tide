extends "res://tests/selection_regression.gd"

func exercise_mode(mode: String) -> void:
	setup_logistics_scene(mode, "美国")
	await check_boarding_routes(mode)
	for id in ["LCRF", "SHAD"]:
		await exercise_transport(mode, id)
	await exercise_aircraft(mode, "ORCA")
	screen.free()
	await get_tree().process_frame
	# Black Eagles use their actual country, without changing an active match.
	setup_logistics_scene(mode, "韩国")
	# The Korean extension opening already fields one fighter. Start this
	# four-empty-berth scenario with only the aircraft spawned by the test.
	for starter in battle.units.duplicate():
		if is_instance_valid(starter) and starter.side == "ally" and starter.unit_id == "BEAG":
			remove_actor(starter)
	await exercise_aircraft(mode, "BEAG")
	await exercise_carrier(mode)
	await exercise_enemy_ownership(mode)
	screen.free()
	await get_tree().process_frame

func setup_logistics_scene(mode: String, country: String) -> void:
	BattleRequest.configure_skirmish(mode, {"map_size": 3200, "starting_funds": 20000, "country": country})
	screen = load("res://scenes/battle.tscn").instantiate()
	stage.add_child(screen)
	battle = screen.battle
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	GM.god_mode = false
	GM.one_shot_kill = false
	GM.infinite_funds = false
	battle.water_rects = [Rect2(1500, 1200, 300, 700)]
	battle.path_service.set_water(battle.water_rects)
	battle._refresh_pathing()

func activate(actor, stop := true) -> void:
	actor.process_mode = Node.PROCESS_MODE_ALWAYS
	actor.set_process(false)
	actor.set_physics_process(false)
	actor.bonuses = {}
	if stop:
		actor.order_stop()

func remove_actor(actor) -> void:
	if is_instance_valid(actor):
		battle.units.erase(actor)
		if actor is Building:battle.buildings.erase(actor)
		actor.free()

func check_boarding_routes(mode: String) -> void:
	var site = battle._place_building("GAWEAP", "enemy", Vector2(2300,800), true)
	battle._refresh_pathing()
	var carrier = battle.spawn_unit("SHAD", "enemy", site.position)
	var passenger = battle.spawn_unit("GHOST", "enemy", site.position - Vector2(450,0))
	activate(carrier)
	activate(passenger)
	await get_tree().physics_frame
	check(passenger.logistics.request_board(carrier), mode+" board helicopter above occupied terrain")
	check(passenger.move_target.distance_to(carrier.position)>24, mode+" boarding destination snapped outside factory")
	var before: int = battle.path_service.stats_paths
	for i in 120: passenger.logistics.tick(1.0/60)
	check(battle.path_service.stats_paths == before, mode+" stationary carrier keeps reachable path")
	var pickup: Vector2 = passenger.move_target
	passenger.position = pickup
	preload("res://scripts/world/skirmish_operations.gd").transport(battle.skirmish_ai,carrier,[])
	check(carrier.has_move_order and carrier.move_target.distance_to(pickup)<1,mode+" AI meets passenger at reachable pickup")
	for i in 120: passenger.logistics.tick(1.0/60)
	var rendezvous_paths: int = battle.path_service.stats_paths
	carrier.position += Vector2(80,0)
	for i in 120: passenger.logistics.tick(1.0/60)
	check(battle.path_service.stats_paths == rendezvous_paths,mode+" passenger keeps fixed pickup as helicopter flies")
	carrier.order_stop()
	before = battle.path_service.stats_paths
	carrier.position += Vector2(240,0)
	for i in 120: passenger.logistics.tick(1.0/60)
	check(battle.path_service.stats_paths == before+1 and passenger.logistics.boarding==carrier,mode+" changed carrier position triggers one new path")
	passenger.order_stop()
	check(passenger.logistics.boarding==null,mode+" player stop cancels boarding")
	remove_actor(passenger)
	remove_actor(carrier)
	battle.buildings.erase(site)
	site.free()
	battle._refresh_pathing()

func exercise_transport(mode: String, id: String) -> void:
	var label := mode + " " + id + ": "
	var transport = battle.spawn_unit(id, "ally", Vector2(2100, 1500))
	var passenger = battle.spawn_unit("E1", "ally", Vector2(2250, 1500))
	var enemy = battle.spawn_unit("E1", "enemy", Vector2(2300, 1500))
	activate(transport)
	activate(passenger)
	activate(enemy)
	await get_tree().physics_frame
	check(not enemy.logistics.request_board(transport), label + "opposing passenger rejected")
	check(passenger.logistics.request_board(transport), label + "boarding order accepted")
	for tick in 600:
		transport._physics_process(1.0 / 60.0)
		passenger._physics_process(1.0 / 60.0)
		if passenger.embarked_in != null:
			break
	check(passenger.embarked_in == transport and not passenger.visible and passenger.collision_layer == 0,
		label + "real movement reaches transport and stows passenger")
	check(not passenger.is_in_group("allies") and not passenger.hit_test(passenger.position),
		label + "stowed passenger removed from targeting and picking")
	var hp: float = passenger.hp
	passenger.receive_hit(100.0)
	check(passenger.hp == hp, label + "passenger cannot be hit separately inside transport")
	var remaining: int = transport.logistics.capacity - transport.logistics.used_capacity()
	for i in remaining:
		var p = battle.spawn_unit("E1", "ally", transport.position + Vector2(40, 0))
		activate(p)
		await get_tree().physics_frame
		p.logistics.request_board(transport)
		for tick in 90:
			transport._physics_process(1.0 / 60.0)
			p._physics_process(1.0 / 60.0)
			if p.embarked_in != null:
				break
	check(transport.logistics.used_capacity() == transport.logistics.capacity,
		label + "source passenger capacity enforced")
	var extra = battle.spawn_unit("E1", "ally", transport.position + Vector2(45, 0))
	activate(extra)
	check(not extra.logistics.request_board(transport), label + "full transport rejects extra passenger")
	transport.position = Vector2(1650, 1500)
	check(transport.deploy(), label + "existing deployment action requests unloading")
	for tick in 90:
		transport._physics_process(1.0 / 60.0)
	check(transport.logistics.used_capacity() == transport.logistics.capacity,
		label + "deep water cannot unload ground passengers")
	battle.selected_units.assign([transport])
	battle._command_move(Vector2(2100, 1500))
	check(transport.move_target.distance_to(Vector2(2100, 1500)) < 2.0,
		label + "player formation command preserves land destination for amphibious transport")
	var path: PackedVector2Array = battle.path_for_unit(transport, Vector2(2100, 1500))
	check(path.size() >= 2 and path[path.size() - 1].distance_to(Vector2(2100, 1500)) < 2.0,
		label + "air/amphibious route reaches land across shore")
	for tick in 900:
		transport._physics_process(1.0 / 60.0)
		if transport.position.distance_to(Vector2(2100, 1500)) < 20.0:
			break
	check(transport.position.distance_to(Vector2(2100, 1500)) < 25.0, label + "real transport crosses shoreline")
	battle.deploy_selected()
	battle.selected_units.clear()
	for tick in 600:
		transport._physics_process(1.0 / 60.0)
		if transport.logistics.passengers.is_empty():
			break
	check(transport.logistics.passengers.is_empty() and passenger.embarked_in == null and passenger.visible,
		label + "unload restores passenger at legal ground position")
	check(passenger.hp == hp and passenger.is_in_group("allies") and not battle.in_water_world(passenger.position),
		label + "unload preserves health, targeting and ground domain")
	# Board again, then kill the transport: no hidden immortal passengers remain.
	passenger.position = transport.position + Vector2(40, 0)
	passenger.logistics.request_board(transport)
	for tick in 90:
		transport._physics_process(1.0 / 60.0)
		passenger._physics_process(1.0 / 60.0)
		if passenger.embarked_in != null:
			break
	transport.hp = 0.0
	transport._die()
	check(passenger.hp == 0.0 and passenger._dead, label + "transport destruction resolves passenger death")
	remove_actor(transport)
	remove_actor(passenger)
	remove_actor(enemy)
	remove_actor(extra)
	for actor in battle.units.duplicate():
		if is_instance_valid(actor) and actor.unit_id == "E1" and actor.position.distance_to(Vector2(2100, 1500)) < 200:
			remove_actor(actor)
	await get_tree().process_frame

func airport(side: String, position: Vector2):
	var b = battle._place_building("GAAIRC", side, position, true)
	b._buildup_play = -1.0
	b.power = 0.0
	return b

func exercise_aircraft(mode: String, id: String) -> void:
	var label := mode + " " + id + ": "
	# move_and_slide uses the engine physics step; the flight controller must use the same clock.
	var physics_step:=1.0/float(Engine.physics_ticks_per_second)
	var base = airport("ally", Vector2(2100, 2200))
	var alternate = airport("ally", Vector2(2400, 2200))
	var plane = battle.spawn_unit(id, "ally", Vector2(2100, 1900))
	var target = battle.spawn_unit("MTNK", "enemy", Vector2(2300, 1900))
	activate(plane)
	activate(target)
	target.hp = 10000.0
	battle.power_low = false
	await get_tree().physics_frame
	plane.attack_target = target
	plane.attack_ordered = true
	plane._think_timer = 1000.0
	var holder: Node = plane._pick_projectile_parent()
	var before: Array = holder.get_children()
	for tick in ceili(.5/physics_step):
		plane._physics_process(physics_step)
	var shots: Array = holder.get_children().filter(func(p): return p is Projectile and not before.has(p))
	check(plane.logistics.ammo == 0 and shots.size() == int(plane.weapon.get("burst", 1)),
		label + "one ammo point pays for exactly one complete volley", shots.size())
	check(plane.logistics.air_state == "returning", label + "empty aircraft automatically returns after final burst")
	for tick in ceili(30.0/physics_step):
		plane._physics_process(physics_step)
		if plane.logistics.air_state == "rearming":
			break
	check(plane.logistics.air_state == "rearming" and plane.logistics.air_lift <= 0.05,
		label + "real flight reaches reserved dock and lands", {"position":plane.position,"dock":plane.logistics.dock_destination(),"state":plane.logistics.air_state,"lift":plane.logistics.air_lift,"velocity":plane.velocity,"speed":plane.move_speed,"home":is_instance_valid(plane.logistics.home)})
	check(not plane.is_air_target(), label + "landed aircraft becomes ground weapon target")
	check(plane.logistics.resume_target == null, label + "return discards completed sortie target")
	# Simulate a legacy save still carrying the previous, living attack target.
	plane.logistics.resume_target = target
	battle.power_low = true
	var elapsed: float = plane.logistics.reload_elapsed
	plane.logistics.tick_return(20.0)
	check(plane.logistics.ammo == 0 and plane.logistics.reload_elapsed == elapsed,
		label + "low power pauses rearming")
	battle.power_low = false
	plane.logistics.tick_return(18.0)
	check(plane.logistics.ammo == 1 and plane.logistics.air_state == "parked",
		label + "reload completes only at powered airport")
	check(plane.logistics.resume_target == null and plane.attack_target == null and not plane.attack_ordered and not plane.attack_move,
		label + "rearm clears legacy target and does not create another attack command")
	# A wingman destroys the designated target before this aircraft can fire.
	var lost_target = battle.spawn_unit("MTNK", "enemy", plane.position + Vector2(950, 0))
	activate(lost_target)
	battle.select_unit(plane, false)
	battle.force_attack(lost_target)
	for tick in ceili(12.0/physics_step):
		plane._physics_process(physics_step)
		if plane.position.distance_to(plane.logistics.dock_destination()) > 90.0: break
	check(plane.attack_ordered and plane.position.distance_to(plane.logistics.dock_destination()) > 90.0 and plane.logistics.ammo > 0, label + "outbound armed before target loss", [plane.logistics.air_lift, plane.logistics.air_state, plane.attack_ordered])
	lost_target.hp = 0.0
	lost_target._die()
	plane._physics_process(physics_step)
	check(plane.logistics.air_state == "returning", label + "armed aircraft recalls on target death")
	for tick in ceili(35.0/physics_step):
		plane._physics_process(physics_step)
		if plane.logistics.air_state == "parked": break
	check(plane.logistics.air_state == "parked" and plane.position.distance_to(plane.logistics.dock_destination()) < 1.0, label + "interrupted sortie reaches reserved berth")
	var docked: Vector2 = plane.position
	for tick in ceili(10.0/physics_step):
		plane._physics_process(physics_step)
	check(plane.position.distance_to(docked) < 0.01 and plane.logistics.air_lift <= 0.05 and
		plane.logistics.ammo == 1 and plane.logistics.air_state == "parked",
		label + "living old enemy cannot trigger another sortie after ten seconds")
	for command in ["stop", "guard"]:
		if command == "stop": plane.order_stop()
		else: plane.order_guard()
		plane._physics_process(physics_step)
		check(plane.logistics.air_state == "parked" and plane.logistics.air_lift <= 0.05,
			label + command + " does not launch parked aircraft")
	battle.power_low = true
	plane._physics_process(physics_step)
	check(plane.logistics.air_state == "parked", label + "full aircraft remains parked when airport loses power")
	battle.power_low = false
	target.position = plane.position + Vector2(120, 0)
	battle.select_unit(plane, false)
	battle.force_attack(target)
	check(plane.attack_ordered and not plane.attack_move and plane.logistics.air_state == "flying",
		label + "new explicit attack starts next sortie")
	for tick in ceili(10.0/physics_step):
		plane._physics_process(physics_step)
		if plane.logistics.ammo == 0: break
	check(plane.logistics.ammo == 0, label + "new sortie actually takes off and fires")
	plane.logistics.resume_target = target
	plane.order_stop()
	check(plane.logistics.resume_target == null and plane._burst_left == 0,
		label + "stop clears pending burst and legacy target even with empty ammo")
	plane.logistics.ammo = 0
	plane.logistics.request_return()
	var old_home = plane.logistics.home
	old_home.side = "enemy"
	plane.logistics.tick_return(1.0 / 60.0)
	check(is_instance_valid(plane.logistics.home) and plane.logistics.home != old_home,
		label + "captured airport reroutes to another same-side dock")
	var new_home = plane.logistics.home
	new_home.side = "enemy"
	plane.logistics.tick_return(1.0 / 60.0)
	check(plane.logistics.home == null and plane.logistics.ammo == 0 and not plane.logistics.can_start_volley(),
		label + "no airport retains empty ammo and cannot fire")
	base.side = "ally"
	alternate.side = "enemy"
	remove_actor(plane)
	base.production.clear()
	for i in 4:
		check(base.enqueue(id), label + "available dock reserves production slot %d" % i)
	check(not base.enqueue(id) and battle.aircraft_population("ally") == 4,
		label + "four docks cap aircraft plus pending orders")
	base.production.clear()
	for b in [base, alternate]:
		battle.buildings.erase(b)
		b.free()
	battle._refresh_pathing()
	remove_actor(target)
	for shot in shots:
		if is_instance_valid(shot):
			shot.free()
	await get_tree().process_frame

func exercise_carrier(mode: String) -> void:
	var label := mode + " carrier: "
	var carrier = battle.spawn_unit("CARRIER", "ally", Vector2(1650, 1500))
	var target = battle.spawn_unit("MTNK", "enemy", Vector2(2000, 1500))
	activate(carrier)
	activate(target)
	target.hp = 10000.0
	carrier.attack_target = target
	carrier.attack_ordered = true
	carrier._think_timer = 1000.0
	await get_tree().physics_frame
	carrier._physics_process(1.0 / 60.0)
	var aircraft: Array = carrier.logistics.squadron.map(func(slot): return slot.unit)
	carrier.order_move(Vector2(1650, 1750))
	check(aircraft.size() == 3 and aircraft.all(func(p): return is_instance_valid(p) and p.unit_id == "HORNET"),
		label + "real three-aircraft squadron launches from carrier")
	for plane in aircraft:
		activate(plane, false)
	await get_tree().physics_frame
	var holder: Node = carrier._pick_projectile_parent()
	var before: Array = holder.get_children()
	for tick in 1800:
		for plane in aircraft:
			plane._physics_process(1.0 / 60.0)
		carrier._physics_process(1.0 / 60.0)
		if aircraft.all(func(p): return p.embarked_in == carrier):
			break
	check(aircraft.all(func(p): return p.embarked_in == carrier and p.logistics.ammo == 0),
		label + "aircraft attack and physically return to moving home")
	check(carrier.position.distance_to(Vector2(1650, 1500)) > 40.0,
		label + "home actually moved during sortie")
	var shots: Array = holder.get_children().filter(func(p): return p is Projectile and not before.has(p))
	check(shots.size() == 3, label + "carrier causes three real bombs, no direct dummy damage", shots.size())
	var initial: float = target.hp
	for shot in shots:
		for tick in 600:
			if shot.is_queued_for_deletion():
				break
			shot._physics_process(1.0 / 60.0)
		shot.free()
	check(target.hp < initial, label + "real bombs damage opposing target")
	carrier.logistics.tick_squadron(9.0)
	check(aircraft.all(func(p): return p.embarked_in == carrier), label + "deck reload prevents immediate relaunch")
	carrier.logistics.tick_squadron(1.1)
	check(aircraft.all(func(p): return p.embarked_in == carrier) and carrier.attack_target == null,
		label + "replacement move cancels old carrier target and leaves recovered aircraft aboard")
	# Continuous carrier salvos require an active carrier attack command.
	battle.select_unit(carrier, false)
	battle.force_attack(target)
	carrier.logistics.tick_squadron(0.0)
	check(aircraft.all(func(p): return p.embarked_in == null and p.logistics.ammo == 1),
		label + "new carrier attack relaunches reloaded surviving aircraft")
	aircraft[0].hp = 0.0
	aircraft[0]._die()
	carrier.logistics.tick_squadron(0.0)
	carrier.logistics.tick_squadron(39.0)
	check(carrier.logistics.squadron[0].unit == null, label + "lost aircraft cannot regenerate early")
	carrier.logistics.tick_squadron(1.0)
	var replacement = carrier.logistics.squadron[0].unit
	check(is_instance_valid(replacement) and replacement != aircraft[0], label + "lost aircraft regenerates after source delay")
	carrier.hp = 0.0
	carrier._die()
	check(is_instance_valid(replacement) and replacement.hp <= 0.0 and aircraft[1].hp <= 0.0 and aircraft[2].hp <= 0.0,
		label + "carrier loss removes remaining squadron")
	for actor in aircraft + [replacement, carrier, target]:
		remove_actor(actor)
	await get_tree().process_frame

func exercise_enemy_ownership(mode: String) -> void:
	var carrier = battle.spawn_unit("LCRF", "enemy", Vector2(2100, 1500))
	var passenger = battle.spawn_unit("MTNK", "enemy", Vector2(2150, 1500))
	activate(carrier)
	activate(passenger)
	await get_tree().physics_frame
	check(passenger.logistics.request_board(carrier), mode + ": enemy transport accepts same-side tank")
	for tick in 180:
		carrier._physics_process(1.0 / 60.0)
		passenger._physics_process(1.0 / 60.0)
		if passenger.embarked_in == carrier:
			break
	check(passenger.embarked_in == carrier and carrier.logistics.used_capacity() == 3,
		mode + ": tank consumes three actual passenger slots")
	carrier.deploy()
	for tick in 60:
		carrier._physics_process(1.0 / 60.0)
	check(passenger.embarked_in == null and passenger.is_in_group("enemies"),
		mode + ": enemy unload restores correct targeting side")
	var helicopter = battle.spawn_unit("SHAD", "enemy", Vector2(2200, 1500))
	activate(helicopter)
	check(not helicopter.logistics.can_board(passenger), mode + ": helicopter size limit rejects tank")
	var own_base = airport("enemy", Vector2(2100, 2200))
	var other_base = airport("ally", Vector2(2300, 2200))
	var plane = battle.spawn_unit("ORCA", "enemy", Vector2(2290, 2200))
	activate(plane)
	plane.logistics.request_return()
	check(plane.logistics.home == own_base, mode + ": enemy aircraft ignores closer opposing airport")
	for actor in [carrier, passenger, helicopter, plane]:
		remove_actor(actor)
	for b in [own_base, other_base]:
		battle.buildings.erase(b)
		b.free()
	battle._refresh_pathing()
	await get_tree().process_frame
