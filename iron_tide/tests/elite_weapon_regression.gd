extends "res://tests/selection_regression.gd"

const Snapshot = preload("res://scripts/save/battle_snapshot.gd")
var original: Dictionary

func raw_id(id: String) -> String:
	for prefix in ["YR_CAP_", "YR_ROBO_", "YR_BFRT_", "YR_"]:
		if id.begins_with(prefix): return id.trim_prefix(prefix)
	return id

func actor(id: String, side := "ally"):
	var unit = battle.spawn_unit(id, side, Vector2(1600, 1600))
	unit.process_mode = Node.PROCESS_MODE_DISABLED
	unit.order_stop()
	return unit

func remove_unit(unit) -> void:
	battle.units.erase(unit)
	unit.free()

func expected_weapon(row: Dictionary, rank: int, deployed := false) -> String:
	var primary: String = row.get("secondary", "") if deployed else row.get("primary", row.get("weapon1", ""))
	if rank < 2: return primary
	if deployed: return row.get("elitesecondary", primary)
	# Original Mirage uses EliteSecondary even though normal fire is Primary.
	if primary == "MirageGun": return row.get("elitesecondary", primary)
	return row.get("eliteprimary", row.get("eliteweapon1", primary))

func check_weapon(unit, expected: String, label: String) -> void:
	var actual: Dictionary = unit._active_weapon()
	check(raw_id(str(actual.get("ra2_weapon_id", ""))) == expected, label + " selects original weapon", actual.get("ra2_weapon_id"))
	if not original.weapons.has(expected): return
	var raw: Dictionary = original.weapons[expected]
	for pair in [["damage", "damage", 1.0, 0.0], ["range", "range", 55.0, 0.0],
		["cooldown", "rof", 1.0 / 15.0, 0.0], ["burst", "burst", 1.0, 1.0]]:
		check(is_equal_approx(float(actual.get(pair[0], pair[3])), float(raw.get(pair[1], pair[3])) * pair[2]),
			label + " original " + pair[0], actual.get(pair[0]))
	check(raw_id(str(actual.get("ra2_projectile", ""))) == raw.get("projectile", ""), label + " projectile follows weapon")
	check(raw_id(str(actual.get("ra2_warhead", ""))) == raw.get("warhead", ""), label + " warhead follows weapon")
	var muzzle: String = raw.get("anim", "")
	if not muzzle.is_empty():
		check(GameData.ra2_muzzle_anims(actual.ra2_weapon_id) == Array(muzzle.split(",")), label + " source muzzle animation")
		for image in muzzle.split(","):
			check(not RA2Art.fx(image.strip_edges()).is_empty(), label + " muzzle asset exists " + image)

func exercise_mode(mode: String) -> void:
	original = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/elite_weapon_source.json"))
	BattleRequest.configure_skirmish(mode, {"map_size": 3200, "starting_funds": 8000, "fog_of_war": false})
	screen = load("res://scenes/battle.tscn").instantiate()
	stage.add_child(screen)
	battle = screen.battle
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	GM.god_mode = false
	GM.one_shot_kill = false
	for id in original.units:
		var unit = actor(id)
		var row: Dictionary = original.units[id]
		var trainable: bool = row.get("trainable", "yes").to_lower() != "no" and row.has("veteranabilities")
		check(unit.can_gain_veterancy() == trainable, mode + " " + id + " source trainability")
		if trainable:
			for rank in [0, 1, 2, 0]:
				unit._grant_veteran(rank, false)
				var expected := expected_weapon(row, rank)
				if not expected.is_empty(): check_weapon(unit, expected, mode + " " + id + " rank " + str(rank))
				if id in ["E1", "GGI"]:
					unit.set_deployed(true)
					check_weapon(unit, expected_weapon(row, rank, true), mode + " " + id + " deployed " + str(rank))
					unit.set_deployed(false)
		else:
			unit.credit_kill(999999.0, "enemy")
			check(unit.veteran_level == 0, mode + " " + id + " nontrainable cannot gain stars")
		remove_unit(unit)
	for pair in [["20mm", "20mmE"], ["MP5", "YR_CAP_MP5E"], ["AWP", "AWPE"], ["DoublePistols", "YR_CAP_DoublePistolsE"]]:
		var normal := GameData.ra2_muzzle_anims(pair[0])
		check(not normal.is_empty() and GameData.ra2_muzzle_anims(pair[1]) == normal, mode + " promotion preserves existing muzzle fallback " + pair[1])
	await volleys(mode)
	await ifv_modes(mode)
	await legacy_restore(mode)
	screen.free()
	await get_tree().process_frame

func volleys(mode: String) -> void:
	for id in ["MTNK", "TNKD", "FV", "HORNET"]:
		for rank in [0, 1, 2]:
			var unit = actor(id)
			var target = actor("MTNK", "enemy")
			target.position += Vector2(160, 0)
			target.hp = 10000.0
			unit._grant_veteran(rank, false)
			unit.attack_target = target
			unit.hull_angle = 0.0
			unit.turret_angle = 0.0
			unit.aim_dir = Vector2.RIGHT
			unit.logistics.air_lift = 1.0
			var label := "%s %s rank %d: " % [mode, id, rank]
			var raw: Dictionary = original.weapons[expected_weapon(original.units[id], rank)]
			var old: Array = battle.projectiles_root.get_children()
			var old_fx: Array = Effects._host().get_children()
			check(unit._try_fire_ready(), label + "real volley starts")
			for tick in 90: unit._update_burst(1.0 / 60.0)
			var shots: Array = battle.projectiles_root.get_children().filter(func(p): return p is Projectile and not old.has(p))
			check(shots.size() == int(raw.get("burst", 1)), label + "real burst count", shots.size())
			var expected_damage := float(raw.damage) * float(original.warheads[raw.warhead].verses.split(",")[5].trim_suffix("%")) / 100.0
			expected_damage *= float(unit.bonuses.get("veteran_attack", 1.0))
			for shot in shots:
				check(is_equal_approx(shot.damage, expected_damage), label + " actual projectile damage", shot.damage)
				check(raw_id(shot.ra2_warhead) == raw.warhead, label + " actual projectile warhead")
				shot.process_mode = Node.PROCESS_MODE_DISABLED
				for tick in 600:
					if shot.is_queued_for_deletion(): break
					shot._physics_process(1.0 / 60.0)
			check(is_equal_approx(10000.0 - target.hp, floorf(expected_damage) * shots.size()), label + "actual impact damage quantizes each hit", 10000.0 - target.hp)
			if id in ["MTNK", "TNKD"] and rank == 2:
				var effects: Array = Effects._host().get_children().filter(func(fx): return fx is Ra2Fx and not old_fx.has(fx))
				check(effects.any(func(fx): return fx.anim.tex == RA2Art.fx("VTMUZZLE").tex), label + "elite muzzle actually spawned")
				check(effects.any(func(fx): return fx.anim.tex == RA2Art.fx("VTEXPLOD").tex), label + "elite impact actually spawned")
			for shot in shots: shot.free()
			for fx in Effects._host().get_children():
				if not old_fx.has(fx): fx.free()
			remove_unit(unit)
			remove_unit(target)
			await get_tree().process_frame

func ifv_modes(mode: String) -> void:
	var unit = actor("FV")
	for id in ["E1", "ENGINEER", "GGI", "GHOST", "SNIPE", "CLEG", "PTROOP"]:
		var passenger = actor(id)
		unit.logistics.passengers.append(passenger)
		passenger.set_stowed(unit)
		var mode_index := int(original.units[id].get("ifvmode", 0)) + 1
		for rank in [0, 1, 2]:
			unit._grant_veteran(rank, false)
			var key := ("eliteweapon" if rank == 2 else "weapon") + str(mode_index)
			check_weapon(unit, original.units.FV[key], mode + " IFV " + id + " rank " + str(rank))
		unit.logistics.passengers.clear()
		remove_unit(passenger)
	unit._refresh_weapon_derived()
	check_weapon(unit, "HoverMissileE", mode + " elite IFV unload returns elite missile")
	remove_unit(unit)

func legacy_restore(mode: String) -> void:
	for id in ["BFRT", "HORNET"]:
		var unit = actor(id)
		unit.credit_kill(unit._vet_need * 2.0 + 7.0, "enemy")
		check(unit.veteran_level == 2, mode + " " + id + " real experience promotes twice")
		var xp: float = unit._vet_kills
		# Simulate an old snapshot with missing runtime definition caches.
		unit._vet_cfg = {}
		unit._vet_elite_weapon = {}
		unit._ra2_weapon_override = {}
		unit.bonuses = {}
		var saved: Dictionary = BattleSaves.save_slot(battle, "quick")
		check(saved.ok, mode + " legacy " + id + " writes isolated disk save", saved)
		var loaded: Dictionary = BattleSaves.read_slot("quick")
		check(loaded.ok, mode + " legacy " + id + " validates disk read", loaded.get("error"))
		if not loaded.ok: return
		Snapshot.new().restore(battle, loaded.snapshot)
		var restored = battle.units.filter(func(u): return u.unit_id == id)[0]
		check(restored.veteran_level == 2 and restored._vet_kills == xp, mode + " legacy " + id + " preserves rank and XP")
		check(restored.can_gain_veterancy() and restored.bonuses.has("veteran_attack"), mode + " legacy " + id + " repairs source abilities")
		check_weapon(restored, expected_weapon(original.units[id], 2), mode + " legacy " + id)
		remove_unit(restored)
		await get_tree().process_frame
