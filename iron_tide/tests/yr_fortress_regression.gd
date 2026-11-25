extends "res://tests/yr_robot_regression.gd"

func _ready() -> void:
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not ProjectSettings.get_setting("application/config/use_custom_user_dir", false):
		get_tree().quit(2)
		return
	var base: Dictionary = GameData.ra2_weapon("M60").duplicate(true)
	GameData.reload()
	check(GameData.units.filter(func(u): return u.id == "BFRT").size() == 1, "reload registers BFRT once")
	check(GameData.ra2_weapon("M60") == base, "base weapons unchanged")
	for id in ["GGI", "ROBO", "BFRT"]:
		check(not GameData.get_unit(id).is_empty() and ResourceLoader.exists(GameData.ra2_cameo_path(id)), "YR Allied new unit and portrait " + id)
	check(RA2Art.art("BFRT").get("facings") == 32 and RA2Art.has_art("BFRT_shd"), "32 direction hull and separate shadow")
	for mode in [MatchRules.RA2, MatchRules.EXTENDED]:
		await fortress(mode)
	var file := FileAccess.open(output_dir.path_join("result.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failed": failed}, "  "))
	file.close()
	print("FORTRESS checks=", checks.size(), " failed=", failed)
	get_tree().quit(0 if failed == 0 else 1)

func board(passenger, carrier) -> void:
	passenger.position = carrier.position + Vector2(0, 30)
	check(passenger.logistics.request_board(carrier), prefix + passenger.unit_id + " accepts real boarding order")
	passenger.logistics.tick(0.1)
	check(passenger.embarked_in == carrier and carrier.logistics.passengers.has(passenger), prefix + passenger.unit_id + " boarding completes")
	check(not passenger.visible and passenger.collision_layer == 0 and not passenger.is_in_group("combatants"), prefix + passenger.unit_id + " passenger stays hidden and untargetable")

func fortress(mode: String) -> void:
	start(mode)
	if battle.fog != null:
		battle.fog.free()
		battle.fog = null
	GM.god_mode = false
	GM.one_shot_kill = false
	GM.infinite_funds = false
	GM.infinite_power = false
	GM.no_build_time = false
	battle.funds = 50000
	var data := GameData.get_unit("BFRT")
	check(data.hp == 600 and data.cost == 2000 and data.speed == 60 and data.sight == 330, prefix + "original BFRT health price speed sight")
	check(is_equal_approx(GameData.ra2_build_time(data), 84.0), prefix + "mode-correct build duration")
	for kind in ["select", "move", "attack", "die"]:
		check(Ra2Sfx.has_voice(data, kind) and Ra2Sfx.play_voice(data, kind, Vector2.INF, 0), prefix + "original PCM " + kind)
	check(Ra2Sfx.play_weapon(data.weapon, Vector2.INF), prefix + "original gun report")
	check(GameData.ra2_muzzle_anims("YR_20mmRapid").has("GUNFIRE") and RA2Art.has_fx("GUNFIRE"), prefix + "original muzzle animation")
	var factory = building("GAWEAP", "ally", Vector2(650, 800))
	check(factory.buildable.has("BFRT") and not factory.can_queue("BFRT"), prefix + "factory lists locked fortress without laboratory")
	building("GATECH", "ally", Vector2(900, 800))
	var power = building("GAPOWR", "ally", Vector2(650, 1100))
	power.power = 5000
	battle._update_power()
	check(factory.can_queue("BFRT") and factory.enqueue("BFRT"), prefix + "laboratory unlocks real factory queue")
	var before: float = battle.funds
	for i in 1500:
		factory._process(0.1)
		if factory.production.is_empty(): break
	check(factory.production.is_empty() and is_equal_approx(before - battle.funds, 2000), prefix + "production spends exactly 2000")
	var made: Array = battle.units.filter(func(u): return is_instance_valid(u) and u.unit_id == "BFRT")
	check(made.size() == 1, prefix + "factory creates one actual fortress", made.size())
	for u in made:
		battle.units.erase(u)
		u.free()
	# Generate a real pre-addition save in the isolated profile; never touch user's slots.
	# Construct the historical roster separately. The live compatibility reader
	# still needs today's factories when verifying the temporary slot on disk.
	var units_then:Dictionary=GameData.unit_index.duplicate()
	var buildings_then:Dictionary=GameData.building_index.duplicate()
	for u in GameData.raw_docs["yr_soviet.json"].units:units_then.erase(u.id)
	for b in GameData.raw_docs["yr_soviet.json"].buildings:buildings_then.erase(b.id)
	units_then.erase("BFRT")
	var old_hash:=BattleSaves.digest(var_to_bytes([BattleSaves.Schema.FIELDS,units_then,buildings_then,GameData.ra2_general,GameData.allied_capabilities]))
	BattleSaves._content_hash=old_hash
	check(BattleSaves.save_slot(battle, "slot3").ok, prefix + "pre-addition save fixture written")
	BattleSaves._content_hash = ""
	check(old_hash != BattleSaves.content_hash() and old_hash == BattleSaves.pre_fortress_hashes().current, prefix + "additive compatibility hash matches exact old roster")
	check(BattleSaves.read_slot("slot3").ok, prefix + "pre-fortress save remains readable")
	var old_health: float = GameData.unit_index.MTNK.hp
	GameData.unit_index.MTNK.hp = old_health + 1
	BattleSaves._content_hash = ""
	check(not BattleSaves.read_slot("slot3").ok, prefix + "other unit data changes remain incompatible")
	GameData.unit_index.MTNK.hp = old_health
	BattleSaves._content_hash = ""
	var car = actor("BFRT", "ally", Vector2(1300, 1400))
	check(car.logistics.capacity == 5 and car.logistics.size_limit == 2, prefix + "original five passenger capacity and size limit")
	check(UnitSkillLayout.info(car, 2).name == "卸下乘员", prefix + "unload is visible in E slot")
	var tank = actor("MTNK", "enemy", Vector2(1500, 1400))
	var air = actor("JUMPJET", "enemy", Vector2(1520, 1440))
	check(not car._weapon_domain_valid(air), prefix + "fortress primary remains ground only")
	check(damage_target(car, tank) > 0.0, prefix + "real 20mm primary damages tank")
	car.order_stop()
	car._cd_timer = 100.0
	var crew: Array = []
	for id in ["GGI", "E1", "SNIPE", "ENGINEER", "GHOST"]:
		var p = actor(id, "ally", car.position + Vector2(0, 30))
		board(p, car)
		crew.append(p)
	var extra = actor("GGI", "ally", car.position + Vector2(-80, 80))
	check(not car.logistics.can_board(extra) and not extra.logistics.request_board(car), prefix + "sixth passenger rejected")
	var friendly_tank = actor("MTNK", "ally", car.position + Vector2(-100, 80))
	check(not car.logistics.can_board(friendly_tank) and not car.logistics.can_board(tank), prefix + "vehicles and enemies cannot board")
	var ggi = crew[0]
	var gi = crew[1]
	check(not ggi._deployed and not gi._deployed, prefix + "boarding never changes deploy state")
	check(is_equal_approx(ggi.attack_range, float(ggi.data.deployed_weapon.range) + 110), prefix + "GGI deployed missile plus two cell range")
	check(is_equal_approx(gi._active_weapon().damage, float(gi.data.deployed_weapon.damage) * 1.2), prefix + "GI deployed machine gun times 1.2 damage")
	check(ggi._weapon_domain_valid(air) and not gi._weapon_domain_valid(air), prefix + "individual passenger anti-air rules")
	battle.select_unit(car, false)
	check(battle.command_cursor.attack_cursor(air) == "attack", prefix + "loaded fortress advertises AA attack cursor")
	battle.force_attack(air)
	car._refresh_target()
	check(car.attack_ordered and car.attack_target == air and not car._weapon_target_valid(air), prefix + "cargo keeps player AA target without giving the hull gun AA")
	car._process_combat(0.016)
	check(not car.has_move_order and car.velocity.is_zero_approx(), prefix + "carrier stops within passenger AA range")
	car.order_stop()
	check(not crew[3]._weapon_domain_valid(tank), prefix + "engineer does not acquire a fabricated gun")
	# S restores automatic defense; inherited commands replace stale passenger orders.
	ggi.attack_target = tank
	ggi.attack_ordered = true
	ggi._cd_timer = 0.0
	ggi._physics_process(0.016)
	check(ggi.fire_stance == "defend" and not ggi.attack_ordered and ggi._cd_timer > 0.0, prefix + "stopped carrier permits in-range passenger defense without stale manual order")
	check(ggi.attack_target is Unit and ggi._weapon_target_valid(ggi.attack_target), prefix + "default passenger target remains a shootable mobile unit")
	car.set_fire_stance("none")
	ggi.attack_target = tank
	ggi.attack_ordered = true
	ggi._cd_timer = 0.0
	ggi._physics_process(0.016)
	check(ggi._cd_timer <= 0.0 and ggi._burst_left == 0, prefix + "explicit cease fire suppresses stale passenger attack")
	car.order_guard()
	check(damage_target(ggi, tank) > 0.0, prefix + "embarked GGI really damages armor")
	check(damage_target(ggi, air) > 0.0, prefix + "embarked GGI really damages air")
	var infantry = actor("GGI", "enemy", Vector2(1520, 1380))
	check(damage_target(gi, infantry) > 0.0, prefix + "embarked GI really fires machine gun")
	check(ggi._cd_timer > 0.0 and gi._cd_timer > 0.0 and car._cd_timer == 100.0, prefix + "passengers and carrier keep independent reloads")
	car.position += Vector2(75, 40)
	ggi._physics_process(0.016)
	check(ggi.global_position == car.global_position and ggi._weapon_muzzle().distance_to(car.global_position) < 80.0, prefix + "passenger follows carrier and fires from roof")
	check(ggi._weapon_muzzle() != gi._weapon_muzzle(), prefix + "distinct passenger firing ports")
	var fog = preload("res://scripts/world/fog_of_war.gd").new()
	battle.add_child(fog)
	battle.fog = fog
	fog.setup(battle)
	check(fog.vision_radius(car) >= ggi.attack_range, prefix + "passenger range contributes to carrier vision")
	ggi.attack_target = tank
	ggi._fire_shot(tank)
	check(fog.firing_positions.has(car.get_instance_id()) and not fog.firing_positions.has(ggi.get_instance_id()), prefix + "cargo shot reveals carrier position without exposing hidden infantry")
	fog.free()
	battle.fog = null
	car.fire_stance = "none"
	ggi._cd_timer = 0.0
	ggi._cancel_burst()
	ggi._physics_process(0.016)
	check(ggi._cd_timer <= 0.0 and ggi._burst_left == 0, prefix + "carrier cease-fire suppresses cargo")
	car.fire_stance = "auto"
	var cd_before: float = ggi._cd_timer
	car.fire_stance = "return"
	car._return_timer = 0.0
	ggi._physics_process(0.016)
	check(ggi._cd_timer <= cd_before, prefix + "return-fire stance does not initiate passenger fire")
	car.fire_stance = "auto"
	ggi._cd_timer = 0.73
	var saved := BattleSaves.save_slot(battle, "slot1")
	check(saved.ok, prefix + "full loaded fortress runtime graph saves", saved)
	if saved.ok:
		check(BattleSaves.prepare_load("slot1").ok, prefix + "saved fortress validates")
		await finish()
		screen = load("res://scenes/battle.tscn").instantiate()
		add_child(screen)
		screen.process_mode = Node.PROCESS_MODE_DISABLED
		battle = screen.battle
		car = battle.units.filter(func(u): return u.unit_id == "BFRT")[0]
		car.process_mode = Node.PROCESS_MODE_ALWAYS
		crew = car.logistics.passengers
		ggi = crew[0]
		check(crew.size() == 5 and ggi.embarked_in == car and not ggi.visible, prefix + "fresh scene restores passenger references and hidden state")
		check(is_equal_approx(ggi._cd_timer, 0.73) and is_equal_approx(ggi.attack_range, float(ggi.data.deployed_weapon.range) + 110), prefix + "save restores reload and enhanced weapon")
		for p in crew:
			p.set_physics_process(false)
			p.set_process(false)
		car.set_physics_process(false)
		car.set_process(false)
		await get_tree().physics_frame
	check(car.deploy() and car.logistics.unloading, prefix + "actual special action starts unloading")
	for i in 10: car.logistics.tick(0.4)
	check(car.logistics.passengers.is_empty() and not car.logistics.unloading, prefix + "all five passengers unload")
	check(ggi.embarked_in == null and ggi.visible and ggi.collision_layer == 1 and ggi.is_in_group("combatants"), prefix + "unload restores collision selection and visibility")
	check(not ggi._deployed and is_equal_approx(ggi.attack_range, float(ggi.weapon.range)), prefix + "unload removes range bonus and restores mobile weapon")
	await check_specials(car)
	await finish()

func check_specials(car) -> void:
	car.position = Vector2(1200, 1700)
	car.order_stop()
	var chrono = actor("CLEG", "ally", car.position + Vector2(0, 30))
	board(chrono, car)
	var target = actor("MTNK", "enemy", car.position + Vector2(220, 0))
	battle.select_unit(car, false)
	battle.force_attack(target)
	check(car.attack_ordered and car.attack_target == target, prefix + "real carrier command directs temporal passenger")
	chrono._cd_timer = 0.0
	chrono._physics_process(0.016)
	check(chrono.special.get("temporal_target") == target, prefix + "embarked chrono starts temporal attack")
	var work: float = chrono.special.get("temporal_work", 0.0)
	var reload_before: float = chrono._cd_timer
	chrono._physics_process(0.2)
	check(is_equal_approx(chrono._cd_timer,reload_before-0.2),prefix + "temporal passenger reload advances exactly once")
	check(float(chrono.special.get("temporal_work", 0.0)) > work, prefix + "temporal channel continues while embarked")
	chrono.set_stowed(null)
	car.logistics.passengers.clear()
	check(not target.special.has("temporal_by"), prefix + "unload releases temporal freeze")
	var victim = actor("MTNK", "enemy", car.position + Vector2(40, 0))
	var friend = actor("MTNK", "ally", car.position + Vector2(-80, 0))
	var resistant = actor("BFRT", "enemy", car.position + Vector2(100, 80))
	var flying = actor("JUMPJET", "enemy", car.position + Vector2(60, 80))
	check(OpenTopped.can_crush(car, victim) and not OpenTopped.can_crush(car, friend), prefix + "omnicrush permits enemy vehicles only")
	check(not OpenTopped.can_crush(car, resistant) and not OpenTopped.can_crush(car, flying), prefix + "resistant fortress and aircraft protected")
	car.velocity = Vector2(60, 0)
	car._move_water_safe()
	check(victim.hp <= 0.0 and friend.hp > 0.0 and resistant.hp > 0.0, prefix + "real movement contact crushes enemy tank")
	car.velocity = Vector2.ZERO
	var doomed = actor("E1", "ally", car.position + Vector2(0, 30))
	board(doomed, car)
	car._die()
	check(doomed.hp <= 0.0 and car.logistics.passengers.is_empty(), prefix + "carrier death destroys cargo and clears references")
