extends "res://tests/logistics_regression.gd"

func actor(id: String, side: String, point: Vector2):
	var unit = battle.spawn_unit(id, side, point)
	activate(unit)
	return unit

func exercise_mode(mode: String) -> void:
	if "--sapper-only" in OS.get_cmdline_user_args():
		setup_logistics_scene(mode, "美国")
		battle.water_rects = []
		battle.path_service.set_water([])
		var tank = actor("MTNK", "enemy", Vector2(2350, 2000))
		exercise_sapper(mode + ": ", tank)
		remove_actor(tank)
		screen.free()
		await get_tree().process_frame
		return
	setup_logistics_scene(mode, "美国")
	battle.water_rects = []
	battle.path_service.set_water([])
	var tag := mode + ": "
	var tank = actor("MTNK", "enemy", Vector2(2350, 2000))
	var man = actor("E1", "enemy", Vector2(2350, 2100))
	var ship = actor("DEST", "enemy", Vector2(2350, 2200))
	var plane = actor("ORCA", "enemy", Vector2(2350, 2300))
	var building = battle._place_building("GAPOWR", "enemy", Vector2(2300, 2500), true)
	activate(building, false)
	for row in [["TANY", "Sapper", "DoublePistols", "Sapper"], ["GHOST", "MP5", "MP5", "Sapper"], ["CCOMAND", "ChronoMP5", "ChronoMP5", "ChronoMP5"], ["PTROOP", "MindControl", "MindControl", "MindControl"]]:
		var unit = actor(row[0], "ally", Vector2(2100, 2100))
		for pair in [[tank, row[1]], [man, row[2]], [ship, row[3]]]:
			check(unit._weapon_for_target(pair[0]).get("ra2_weapon_id") == "YR_CAP_" + pair[1], tag + row[0] + " selects " + pair[1])
		check(not unit._weapon_domain_valid(plane), tag + row[0] + " rejects aircraft")
		check(UnitSkillLayout.index(unit, 0) == -1, tag + row[0] + " C4 does not occupy Q")
		var obsolete := Ability.new()
		obsolete.setup({"id": "allied_c4", "effect": "allied_c4"})
		unit.skills.append(obsolete)
		AlliedAbilities.install(unit)
		check(UnitSkillLayout.find(unit, "allied_c4") == -1, tag + row[0] + " removes old saved C4 button")
		check(CommandoCombat.building_c4(unit, building) == (row[0] != "CCOMAND"), tag + row[0] + " building C4 follows source flag")
		check(not AlliedAbilities.can_order(unit, tank, "allied_c4"), tag + row[0] + " vehicle never receives delayed building charge")
		unit.veteran_level = 2
		if row[0] == "TANY": check(unit._weapon_for_target(tank).get("ra2_weapon_id") == "YR_CAP_Sapper", tag + "elite Tanya retains Sapper")
		remove_actor(unit)
	exercise_sapper(tag, tank)
	for item in [tank, man, ship, plane]: remove_actor(item)
	await exercise_orders(mode, tag, building)

func exercise_sapper(tag: String, tank) -> void:
	var tanya = actor("TANY", "ally", tank.position - Vector2(220, 0))
	var hp_at_start: float = tank.hp
	tank.receive_hit(5.0, "bullet", {"impact_weapon": "YR_CAP_Sapper"}, tanya, "YR_CAP_Mechanical")
	check(tank.hp > 0.0 and tank.hp < hp_at_start and tank._sapper_flash_left == 0.0, tag + "nonlethal Sapper damage does not begin the death effect")
	tanya.attack_target = tank
	tanya._refresh_weapon_derived()
	check(is_equal_approx(tanya.attack_range, 82.5) and is_equal_approx(tanya.cooldown, 100.0 / 15.0), tag + "Sapper range and ROF from YR")
	check(not tanya._weapon_target_valid(tank), tag + "Sapper cannot hit at pistol range")
	battle.select_unit(tanya, false)
	check(battle.command_cursor.attack_cursor(tank) == "sabotage", tag + "vehicle uses sabotage pointer")
	# Default defense does not chase outside Sapper range; a player attack must.
	tanya._refresh_target()
	check(tanya.attack_target == null and not tanya.has_move_order, tag + "default Tanya does not chase outside Sapper range")
	battle.force_attack(tank)
	var tank_material: ShaderMaterial = tank.material
	var original_flash = tank_material.get_shader_parameter("sapper_flash")
	var explosions_before := get_tree().get_nodes_in_group("yr_death_effects").size()
	var credit_before: float = tanya._vet_kills
	var hp_before: float = tank.hp
	for tick in 600:
		tanya._physics_process(1.0 / 60.0)
		if tank.hp < hp_before: break
	check(tank.hp < hp_before and tanya.position.distance_to(tank.position) <= 84.0, tag + "explicit attack approaches and damages vehicle")
	check(not tank.special.has("c4_left"), tag + "Sapper is weapon damage, not timed destruction")
	check(tank._dead and tank.hp == 0.0 and tank.collision_layer == 0 and tanya._vet_kills > credit_before,
		tag + "Sapper death, collision removal and kill credit still resolve on hit")
	check(tank.material != tank_material and tank.material.get_shader_parameter("sapper_flash") == 0.5
		and tank_material.get_shader_parameter("sapper_flash") == original_flash, tag + "Sapper highlights only the killed hull")
	tank._physics_process(1.0 / 15.0)
	check(tank._sapper_flash_left > 0.0 and not tank.is_queued_for_deletion()
		and get_tree().get_nodes_in_group("yr_death_effects").size() == explosions_before, tag + "hull flashes before the explosion")
	tank._physics_process(1.0 / 15.0)
	check(tank.is_queued_for_deletion() and get_tree().get_nodes_in_group("yr_death_effects").size() == explosions_before + 1,
		tag + "Sapper flash gives way to one native vehicle explosion")
	remove_actor(tanya)

func exercise_orders(mode: String, tag: String, building) -> void:
	var mover = actor("TANY", "ally", Vector2(1500, 1800))
	var victim = actor("MTNK", "enemy", Vector2(1730, 1800))
	var goal := Vector2(1500, 2300)
	mover.order_move(goal, true)
	for tick in 900:
		mover._physics_process(1.0 / 60.0)
		if victim._dead: break
	mover._refresh_target()
	check(victim._dead and mover.attack_move and mover.move_target == goal, tag + "attack-move approaches vehicle then resumes original route")
	remove_actor(mover); remove_actor(victim)
	await building_attack(tag, building)
	screen.free()
	await get_tree().process_frame

func building_attack(tag: String, building) -> void:
	var seal = actor("GHOST", "ally", building.position + Vector2(300, 0))
	var escort = actor("MTNK", "ally", seal.position + Vector2(0, 70))
	battle.select_unit(seal, false)
	battle.select_unit(escort, true)
	check(battle.command_cursor.attack_cursor(building) == "c4", tag + "building uses C4 pointer")
	var source: Dictionary = GameData.allied_capabilities.buildings.GAPOWR
	source.CanC4 = "no"
	check(not AlliedAbilities.can_order(seal, building, "allied_c4"), tag + "CanC4=no rejects planted charge")
	source.erase("CanC4")
	battle._issue_order(building.position)
	check(seal.attack_target == building and escort.attack_target == building, tag + "right-click orders whole mixed group")
	check(not building.special.has("c4_left"), tag + "right-click does not plant remotely")
	for tick in 900:
		seal._physics_process(1.0 / 60.0)
		if building.special.has("c4_left"): break
	check(building.special.has("c4_left") and building.hp > 0, tag + "ordinary attack reaches building and plants charge")
	check(seal.position.distance_to(AlliedAbilities.approach(seal, building)) <= seal.radius + 25.0, tag + "charge requires physical contact")
	var engineer = actor("ENGINEER", "enemy", AlliedAbilities.approach(seal, building))
	check(AlliedAbilities.use(engineer, "allied_engineer", building), tag + "engineer can disarm building C4")
	engineer._physics_process(0.1)
	check(not building.special.has("c4_left") and not engineer._dead, tag + "disarm preserves engineer")
	remove_actor(engineer)
	seal.order_stop()
	seal.position = AlliedAbilities.approach(seal, building)
	seal.set_fire_stance("none")
	check(not CommandoCombat.begin_c4(seal,building),tag+"ceasefire still prevents automatic C4")
	battle.select_unit(seal,false)
	battle.force_attack(building)
	for tick in 240:
		seal._physics_process(1.0/60.0)
		if building.special.has("c4_left"):break
	check(building.special.has("c4_left"),tag+"manual C4 attack overrides ceasefire like normal weapons")
	seal.order_stop()
	building.special.erase("c4_left");building.special.erase("c4_owner")
	check(not seal.special.has("c4_explicit"),tag+"cancel removes manual C4 permission")
	seal.position = building.position + Vector2(300, 0)
	seal.attack_target = building
	seal.order_guard()
	var origin: Vector2 = seal.position
	seal._physics_process(0.1)
	check(seal.position == origin and not seal.special.has("action"), tag + "hold does not chase to plant")
	seal.order_move(origin + Vector2(0, 250))
	seal.attack_target = building
	seal._physics_process(0.1)
	check(not seal.special.has("action"), tag + "normal move is not hijacked by C4")
	seal.order_stop()
	seal.position = building.position + Vector2(300, 0)
	seal.set_fire_stance("free")
	seal.attack_target = building
	seal._physics_process(0.1)
	check(seal.special.get("action") == "allied_c4", tag + "automatic approach uses saved action")
	seal.order_stop()
	check(not seal.special.has("action"), tag + "stop cancels pending C4 approach")
	seal.order_stop()
	seal.position = AlliedAbilities.approach(seal, building)
	seal.set_fire_stance("free")
	seal._refresh_target()
	for tick in 180:
		seal._physics_process(1.0 / 60.0)
		if building.special.has("c4_left"): break
	check(building.special.has("c4_left"), tag + "explicit free-fire stance plants nearby building without skill")
	building._process(0.5)
	check(not building._dead, tag + "C4 obeys original delay")
	building._process(2.0)
	check(building._dead, tag + "C4 explodes through building death")
	remove_actor(seal); remove_actor(escort)
	var target = battle._place_building("GAPOWR", "enemy", Vector2(2300, 1900), true)
	activate(target, false)
	var chrono = actor("CCOMAND", "ally", target.position + Vector2(180, 0))
	chrono.attack_target = target
	chrono._refresh_weapon_derived()
	check(chrono._active_weapon().get("ra2_weapon_id") == "YR_CAP_FakeC4", tag + "Chrono Commando chooses FakeC4 secondary")
	check(battle.command_cursor.textures.has("c4") and battle.command_cursor.textures.has("sabotage"), tag + "original cursor frames imported")
	chrono.position = AlliedAbilities.approach(chrono, target)
	battle.select_unit(chrono, false)
	battle.force_attack(target)
	chrono.hull_angle = (target.position - chrono.position).angle()
	chrono._cd_timer = 0.0
	check(chrono._try_fire_ready(), tag + "FakeC4 uses normal firing entry")
	check(target._dead and not target.special.has("c4_left"), tag + "FakeC4 immediate weapon damage, no invented timed bomb")
	remove_actor(chrono)
	var follow_target = battle._place_building("GAPOWR", "enemy", Vector2(2100, 1800), true)
	activate(follow_target, false)
	var follower = actor("GHOST", "ally", follow_target.position + Vector2(180, 0))
	follower.position = AlliedAbilities.approach(follower, follow_target)
	var next_goal: Vector2 = follower.position + Vector2(0, 350)
	follower.order_move(next_goal, true)
	follower.attack_target = follow_target
	for tick in 180:
		follower._physics_process(1.0 / 60.0)
		if follow_target.special.has("c4_left") and follower.attack_move: break
	check(follow_target.special.has("c4_left") and follower.attack_move and follower.move_target == next_goal, tag + "C4 attack-move resumes after planting")
	remove_actor(follower)
