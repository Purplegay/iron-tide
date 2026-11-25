extends "res://tests/allied_abilities_regression.gd"

func exercise_mode(mode: String) -> void:
	if mode == MatchRules.RA2: return
	setup_logistics_scene(mode, "苏俄")
	battle.water_rects = []
	battle.path_service.set_water([])
	if battle.fog != null: battle.fog.free(); battle.fog = null
	var origin := Vector2(1550, 1550)
	var tank = actor("R3APOC", "ally", origin)
	var turret = battle._place_building("GTGCAN", "enemy", origin + Vector2(0, -160), true)
	turret._buildup_play = -1
	tank._refresh_target()
	check(tank.attack_target == null, "default defense leaves silent building alone")
	for stance in ["defend", "return", "none"]:
		tank.order_stop()
		tank.set_fire_stance(stance)
		var before: float = tank.hp
		var shell := Projectile.new()
		battle.projectiles_root.add_child(shell)
		shell.setup(turret.position,tank,turret.weapon,100,{},turret.side,turret)
		shell._explode()
		check(tank.hp < before, stance + " incoming shell damages tank")
		check(tank.special.get("retaliation_target") == turret, stance + " records launcher, not shell")
		tank.turret_angle = PI / 2.0
		var fired := false
		for frame in 265:
			tank._physics_process(1.0/60)
			for shot in battle.projectiles_root.get_children():
				if shot is Projectile and shot.target == turret and not shot.is_queued_for_deletion():
					var hp_before: float = turret.hp
					shot._physics_process(1)
					fired = turret.hp < hp_before
			if fired: break
		check(fired == (stance != "none"), stance + " rear target return damage obeys stance")
	var hostile = actor("HTNK","enemy",origin + Vector2(130,0))
	tank.order_stop()
	tank.order_move(origin + Vector2(500,0))
	tank.receive_hit(2.0,"shell",{},hostile)
	tank._refresh_target()
	check(tank.has_move_order and tank.attack_target == hostile, "mobile target acquired without cancelling movement")
	tank.order_stop()
	var soldier = actor("E2", "enemy", origin + Vector2(20,0))
	soldier.hp = 1
	preload("res://scripts/units/ra3_soviet.gd").use(tank,tank.position)
	tank._refresh_target()
	check(not tank.attack_domain_valid(soldier) and tank.attack_target == hostile, "harpoon chooses engageable vehicle over wounded infantry")
	var plane = actor("SHAD", "enemy", origin + Vector2(62,0))
	plane.logistics.air_lift = 0.0
	check(tank.attack_domain_valid(plane), "landed Nighthawk counts as a vehicle")
	plane.logistics.air_lift = 1.0
	check(not tank.attack_domain_valid(plane), "airborne Nighthawk cannot be hooked")
	exercise_landed_chopper()
	preload("res://scripts/units/ra3_soviet.gd").use(tank,tank.position)
	check(tank.attack_domain_valid(soldier), "cannons can target infantry again")
	tank.set_fire_stance("return")
	tank.receive_hit(3,"shell",{},hostile)
	var friendly = actor("MTNK", "ally", origin + Vector2(-80,0))
	var stray := Projectile.new()
	battle.projectiles_root.add_child(stray)
	stray.setup(friendly.position,tank,turret.weapon,10,{},friendly.side,friendly)
	tank.receive_hit(2,"shell",{},stray)
	check(tank.special.get("retaliation_target") == hostile, "friendly splash preserves hostile attacker")
	remove_actor(friendly)
	tank.receive_hit(2,"shell",{},stray)
	check(tank.special.get("retaliation_target") == hostile, "orphan projectile cannot become a target")
	stray.queue_free()

	exercise_harpoon()

func exercise_landed_chopper() -> void:
	const Soviet = preload("res://scripts/units/ra3_soviet.gd")
	const Pounce = preload("res://scripts/units/dog_pounce.gd")
	const Chopper = preload("res://scripts/units/siege_chopper.gd")
	var chopper = actor("SCHP", "enemy", Vector2(2000, 1600))
	var hook = actor("R3APOC", "ally", chopper.position - Vector2(120, 0))
	var drone = actor("DRON", "ally", chopper.position - Vector2(32, 0))
	Soviet.use(hook, hook.position)
	check(chopper.set_deployed(true, false), "siege chopper starts landing")
	battle.select_unit(drone, false)
	check(not drone.attack_domain_valid(chopper) and not hook.attack_domain_valid(chopper), "descent alone does not grant ground contact")
	for frame in 400: Chopper.tick(chopper, 1.0 / 60.0)
	check(chopper._ra2.get("key") == "SCHD" and battle.command_cursor.resolve(chopper.position) == "attack", "deployed chopper has drone attack cursor")
	battle.select_unit(hook, false)
	check(battle.command_cursor.resolve(chopper.position) == "attack", "deployed chopper has harpoon attack cursor")
	battle._issue_order(chopper.position)
	hook.hull_angle = hook.position.angle_to_point(chopper.position)
	check(hook.attack_target == chopper and hook._try_fire_ready() and hook.special.get("harpoon_target") == chopper, "order attaches magnetic harpoon")
	var before: Vector2 = chopper.position
	Soviet.tick(hook, 0.2)
	check(chopper.position.distance_to(hook.position) < before.distance_to(hook.position), "grounded chopper is pulled toward tank")
	drone.position = chopper.position - Vector2(drone.radius + chopper.radius - 1, 0)
	battle.select_unit(drone, false)
	battle._issue_order(chopper.position)
	drone.hull_angle = drone.position.angle_to_point(chopper.position)
	check(drone.attack_target == chopper and drone._try_fire_ready() and drone.special.has("pounce"), "drone starts an ordered leap at grounded chopper")
	check(chopper.set_deployed(false, false), "chopper begins takeoff")
	for frame in 180: Chopper.tick(chopper, 1.0 / 60.0)
	Pounce.tick(drone, 0.1)
	Soviet.tick(hook, 0.1)
	check(drone.embarked_in == null and not hook.special.has("harpoon_target"), "takeoff before contact prevents infestation and breaks the hook")
	drone.position = chopper.position - Vector2(50, 0)
	check(chopper.set_deployed(true, false), "free pad permits second landing")
	for frame in 400: Chopper.tick(chopper, 1.0 / 60.0)
	drone.position = chopper.position - Vector2(drone.radius + chopper.radius - 1, 0)
	drone._cd_timer = 0
	battle._issue_order(chopper.position)
	drone._try_fire_ready()
	Pounce.tick(drone, 0.1)
	check(drone.embarked_in == chopper and chopper.special.get("parasite") == drone, "ground contact attaches real parasite")
	var hp: float = chopper.hp
	chopper._physics_process(0.1)
	check(chopper.hp < hp, "attached parasite damages the chopper")
	var jet = actor("ORCA", "enemy", Vector2(2150, 1650))
	jet.logistics.air_lift = 0.0
	check(not drone.attack_domain_valid(jet) and not hook.attack_domain_valid(jet), "parked fixed-wing jet keeps its existing domain")
	battle.clear_selection()

func exercise_harpoon() -> void:
	const Soviet=preload("res://scripts/units/ra3_soviet.gd")
	var tank=actor("R3APOC","ally",Vector2(1830,1690))
	var enemy=actor("R3APOC","enemy",tank.position+Vector2(140,0))
	tank.hull_angle=PI/2;tank.turret_angle=0
	Soviet.use(tank,tank.position)
	battle.select_unit(tank,false)
	battle.force_attack(enemy)
	check(not tank._try_fire_ready(),"turret alone cannot aim the hull harpoon")
	var hp:float=enemy.hp
	for frame in 240:
		tank._physics_process(1.0/60.0)
		if tank.special.has("harpoon_target"):break
	check(tank.special.get("harpoon_target")==enemy and absf(angle_difference(tank.hull_angle,tank.position.angle_to_point(enemy.position)))<=deg_to_rad(1.0),"real attack order rotates hull before hook")
	check(is_equal_approx(hp-enemy.hp,Ra3Expansion.raw_damage(1,"CANNON",enemy)),"single cannon point on hook")
	var hooked_hp:float=enemy.hp
	var initial:Vector2=enemy.position
	Soviet.tick(tank,0.2);tank._try_fire_ready()
	check(enemy.position.distance_to(initial)>0.1 and enemy.hp==hooked_hp,"pull without ranged grinding or repeated hook damage")
	enemy.position=tank.position+Vector2(0,100)
	var off_axis:Vector2=enemy.position
	Soviet.tick(tank,0.5)
	check(enemy.position==off_axis and enemy.hp==hooked_hp,"off-axis target pauses pulling and damage")
	enemy.position=tank.position+Vector2(tank.radius+enemy.radius+6,0)
	Soviet.tick(tank,0.24)
	check(enemy.hp==hooked_hp,"contact under one quarter second")
	Soviet.tick(tank,0.01)
	check(is_equal_approx(hooked_hp-enemy.hp,Ra3Expansion.raw_damage(50,"EXPLOSIVE",enemy)),"vehicle takes armor-adjusted grind pulse")
	Soviet.tick(tank,0.74)
	check(AlliedAbilities.alive(enemy),"vehicle survives before full second of contact")
	Soviet.tick(tank,0.011)
	check(not AlliedAbilities.alive(enemy) and enemy._crush_death,"full second of contact crushes the vehicle")
	var yard=battle._place_building("GACNST","enemy",tank.position+Vector2(210,0),true)
	var reach:float=yard.footprint_clearance(Vector2.LEFT)+tank.radius+6
	tank.position=yard.position-Vector2(reach,0)
	battle.force_attack(yard);tank.hull_angle=0;tank.turret_angle=0
	check(tank._try_fire_ready(),"can hook a construction yard")
	var yard_hp:float=yard.hp
	Soviet.tick(tank,1.0)
	check(is_equal_approx(yard_hp-yard.hp,4*Ra3Expansion.raw_damage(50,"EXPLOSIVE",yard)),"building receives four scaled pulses without vehicle crush")
