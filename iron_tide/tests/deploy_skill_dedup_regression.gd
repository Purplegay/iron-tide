extends "res://tests/selection_regression.gd"

func ids(unit) -> Array:
	return unit.skills.map(func(ab): return ab.id)

func exercise_mode(mode: String) -> void:
	MetaProgress.unlock_skill("ap_bayonet")
	for id in ["E1", "GGI", "GHOST"]:
		MetaProgress.unit_loadouts[id] = {"active": ["ap_deploy", "ap_bayonet"], "passive": ""}
	BattleRequest.configure_skirmish(mode, {"map_size": 3200, "starting_funds": 8000})
	screen = load("res://scenes/battle.tscn").instantiate()
	stage.add_child(screen)
	battle = screen.battle
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	battle.process_mode = Node.PROCESS_MODE_ALWAYS
	battle.set_process(false)
	battle.set_physics_process(false)
	for child in battle.get_children(): child.process_mode = Node.PROCESS_MODE_DISABLED
	var hud = screen.hud
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	hud.set_process(false)
	get_window().focus_entered.emit()
	for id in ["E1", "GGI"]:
		var unit = battle.spawn_unit(id, "ally", Vector2(1600, 1600))
		unit.process_mode = Node.PROCESS_MODE_DISABLED
		var prefix: String = mode + " " + id + ": "
		var native_id := "allied_deploy" if id == "E1" else "ggi_deploy"
		check(ids(unit).count(native_id) == 1 and not ids(unit).has("ap_deploy"), prefix + "native deployment replaces legacy loadout entry")
		check(ids(unit).has("ap_bayonet") == (mode == MatchRules.EXTENDED), prefix + "unrelated extended skill preserved only in extended mode")
		if id == "GGI": check(ids(unit)[1] == "ggi_guard", prefix + "independent guard stays in Q")
		battle.select_unit(unit, false)
		battle._emit_selection()
		await get_tree().process_frame
		var names: Array = hud._ability_btns.map(func(btn): return btn.get_meta("name_label").text)
		check(not names.has("部署/卧倒") and names.count("卧倒据守" if id == "E1" else "部署导弹") == 1, prefix + "real HUD contains one deployment button")
		await key(KEY_E)
		hud._update_ability_live()
		check(unit.is_deployed() and hud._ability_btns[2].get_meta("name_label").text == ("起身" if id == "E1" else "收起导弹"), prefix + "E deploys once and updates button")
		await key(KEY_E)
		check(not unit.is_deployed(), prefix + "E toggles back without duplicate invocation")
		# Reproduce a previously saved duplicate runtime list, including a live
		# unrelated cooldown. Restore must normalize without resetting that skill.
		var legacy := Ability.new()
		legacy.setup(GameData.get_skill("ap_deploy"))
		unit.skills.append(legacy)
		var custom := Ability.new()
		custom.setup(GameData.get_skill("ap_smoke"))
		custom.cd_left = 7.25
		unit.skills.append(custom)
		unit.deploy()
		unit.special.dedup_test = id
		var saved := BattleSaves.save_slot(battle, "slot1")
		check(saved.ok, prefix + "old duplicate runtime saves through real slot entry")
		var loaded := BattleSaves.read_slot("slot1")
		check(loaded.ok, prefix + "saved duplicate snapshot validates")
		if loaded.ok:
			preload("res://scripts/save/battle_snapshot.gd").new().restore(battle, loaded.snapshot)
			unit = battle.units.filter(func(u): return u.special.get("dedup_test", "") == id)[0]
			check(ids(unit).count(native_id) == 1 and not ids(unit).has("ap_deploy"), prefix + "restore removes legacy duplicate")
			var restored = unit.skills.filter(func(ab): return ab.id == "ap_smoke")[0]
			check(unit.is_deployed() and restored.cd_left == 7.25, prefix + "restore preserves deployment and unrelated cooldown")
			var before := ids(unit)
			AlliedAbilities.install(unit)
			check(ids(unit) == before, prefix + "repeated normalization is idempotent")
	var seal = battle.spawn_unit("GHOST", "ally", Vector2(1700, 1600))
	seal.process_mode = Node.PROCESS_MODE_DISABLED
	check(not ids(seal).has("ap_deploy") and UnitSkillLayout.index(seal, 2) < 0, mode + ": SEAL has no E operation")
	battle.select_unit(seal, false)
	battle._emit_selection()
	await get_tree().process_frame
	await key(KEY_E)
	check(not seal.is_deployed() and not seal.can_deploy() and not seal.deploy(), mode + ": E and deploy command cannot deploy SEAL")
	var obsolete := Ability.new()
	obsolete.setup(GameData.get_skill("ap_deploy"))
	seal.skills.append(obsolete)
	seal.set_deployed(true, false)
	check(seal.is_deployed() and seal.move_speed == 0, mode + ": reproduced old immobilized SEAL")
	var seal_save := BattleSaves.save_slot(battle, "slot1")
	var seal_read := BattleSaves.read_slot("slot1")
	check(seal_save.ok and seal_read.ok, mode + ": old SEAL stance saves and reads")
	if seal_save.ok and seal_read.ok:
		preload("res://scripts/save/battle_snapshot.gd").new().restore(battle, seal_read.snapshot)
		var restored_seal = battle.units.filter(func(u): return u.unit_id == "GHOST")[0]
		check(not restored_seal.can_deploy() and UnitSkillLayout.index(restored_seal, 2) < 0, mode + ": restored SEAL has no deployment")
		check(not restored_seal.is_deployed() and restored_seal.move_speed > 0.0, mode + ": restored SEAL can move")
	check(MetaProgress.unit_loadouts.E1.active == ["ap_deploy", "ap_bayonet"], mode + ": stored player loadout remains untouched")
	screen.free()
	await get_tree().process_frame
