extends "res://tests/soviet_defense_regression.gd"

func _ready() -> void:
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2)
		return
	GM.god_mode = false
	GM.one_shot_kill = false
	for mode in [MatchRules.RA2, MatchRules.EXTENDED]:
		BattleRequest.configure_skirmish(mode, {"country":"苏俄", "enemy_base":"allied", "map_size":3200, "starting_funds":12000, "opening":"prebuilt"})
		screen = load("res://scenes/battle.tscn").instantiate()
		add_child(screen)
		battle = screen.battle
		screen.process_mode = Node.PROCESS_MODE_DISABLED
		if battle.fog != null:
			battle.fog.free()
			battle.fog = null
		for site in battle.buildings: site._process(10.0)
		exercise_shield(mode)
		await finish()
	FileAccess.open(output_dir.path_join("result.json"), FileAccess.WRITE).store_string(JSON.stringify({"checks":checks, "failed":failed}, "  "))
	print("FORCE_SHIELD_TARGET checks=", checks.size(), " failed=", failed)
	get_tree().quit(0 if failed == 0 else 1)

func align_shooter(unit, target) -> void:
	unit.order_stop()
	unit.attack_target = target
	unit.attack_ordered = true
	unit._cd_timer = 0.0
	unit.turret_angle = unit.global_position.direction_to(target.global_position).angle()
	unit.hull_angle = unit.turret_angle
	unit.aim_dir = Vector2.from_angle(unit.turret_angle)

func exercise_shield(mode: String) -> void:
	var tag := mode + ": "
	var lab = ready_building("NATECH", Vector2(1600,1600))
	ready_building("NAPOWR", Vector2(1200,1600))
	ready_building("NAPOWR", Vector2(1200,1800))
	battle._update_power()
	var tank = battle.spawn_unit("APOC", "enemy", lab.position + Vector2(150,0))
	align_shooter(tank, lab)
	check(tank._try_fire_ready() and tank._burst_left > 0, tag + "unshielded building starts real Apocalypse burst")
	var tower = battle._place_building("GTGCAN", "enemy", lab.position + Vector2(0,220), true)
	tower._buildup_play = -1.0
	check(tower._valid_weapon_target(lab), tag + "unshielded building is valid for defensive turret")
	var bunker = battle._place_building("NABNKR", "enemy", lab.position + Vector2(0,-200), true)
	bunker._buildup_play = -1.0
	var occupant = battle.spawn_unit("E2", "enemy", bunker.position)
	Garrison.enter(occupant, bunker)
	check(occupant.embarked_in == bunker and Garrison.order_block_reason(bunker,lab).is_empty(), tag + "occupied bunker can attack unshielded building")
	lab._sw_charge = lab.sw_recharge()
	check(lab.fire_superweapon(lab.position) and float(lab.special.get("force_shield_left",0)) > 0, tag + "real ForceShield activation protects building")
	var before: int = battle.projectiles_root.get_child_count()
	tank._update_burst(1.0)
	check(tank._burst_left == 0 and battle.projectiles_root.get_child_count() == before, tag + "activation cancels remaining burst before next shot")
	tank._refresh_target()
	check(tank.attack_target == null and not tank.attack_ordered and not tank.has_move_order, tag + "existing explicit attack ends without pursuing shield")
	for id in ["MTNK", "APOC", "SCHP", "ZEP", "V3", "SREF"]:
		var unit = battle.spawn_unit(id, "enemy", lab.position + Vector2(150,0))
		align_shooter(unit, lab)
		var ammo: int = unit.logistics.ammo
		check(not unit.attack_domain_valid(lab) and not unit._try_fire_ready(), tag + id + " does not fire at shielded target")
		check(unit.logistics.ammo == ammo, tag + id + " does not consume ammo")
		unit.special[ForceFire.KEY] = lab
		check(not unit._try_fire_ready(), tag + id + " force attack cannot bypass shield exclusion")
		battle.units.erase(unit)
		unit.free()
	tower.attack_target = lab
	check(not tower._valid_weapon_target(lab) and not tower._fire(), tag + "defensive turret stops firing immediately")
	bunker.attack_target = lab
	check(not Garrison.order_block_reason(bunker,lab).is_empty(), tag + "garrison rejects shielded building")
	Garrison.tick(occupant,1.0)
	check(bunker.attack_target != lab, tag + "garrison releases existing shielded target")
	tower._acquire_target()
	check(tower.attack_target != lab, tag + "defensive turret does not reacquire shielded building")
	tank.order_stop()
	tank.set_fire_stance("free")
	tank._refresh_target()
	check(tank.attack_target != lab, tag + "automatic search skips shielded building")
	var alternative = battle.spawn_unit("HTNK", "ally", tank.position + Vector2(50,0))
	tank._refresh_target()
	check(tank.attack_target == alternative, tag + "automatic search selects unshielded alternative")
	var health: float = lab.hp
	lab.receive_hit(200)
	check(lab.hp == health, tag + "existing shield damage immunity remains intact")
	lab._process(float(lab.special.force_shield_left) + 0.1)
	check(not lab.special.has("force_shield_left"), tag + "real duration expiry removes shield")
	battle.units.erase(alternative)
	alternative.free()
	tank._refresh_target()
	check(tank.attack_target == lab, tag + "automatic search reacquires building after shield expiry")
	align_shooter(tank, lab)
	check(tank._try_fire_ready(), tag + "ordinary attack fires again after shield expires")
	check(tower._valid_weapon_target(lab), tag + "defensive turret accepts expired shield")
	check(Garrison.order_block_reason(bunker,lab).is_empty(), tag + "garrison accepts expired shield")
	lab.special.force_shield_left = 0.0
	check(tank.attack_domain_valid(lab) and tower._valid_weapon_target(lab), tag + "zero duration does not block attacks")
