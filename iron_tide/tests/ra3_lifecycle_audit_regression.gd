extends "res://tests/allied_abilities_regression.gd"
## XML-derived passive healing through the real Unit tick and snapshot consumer.
func exercise_mode(mode: String) -> void:
	if mode == MatchRules.RA2: return
	setup_logistics_scene(mode, "美国")
	for node in battle.units + battle.buildings: node.free()
	battle.units.clear(); battle.buildings.clear()
	if battle.fog != null: battle.fog.free(); battle.fog = null
	var subjects: Array = []
	for id in ["R3MIRAGE", "R3FUTURE", "R3HARBINGER"]:
		var unit = actor(id, "ally", Vector2(1400 + subjects.size() * 300, 1400))
		subjects.append(unit)
		await get_tree().physics_frame # Register the real physics bodies before manually stepping.
		# Real Unit ticks include abilities, healing, movement and cooldowns;
		# the test scene supplies no enemies or external repair sources.
		unit.fire_stance = "none"
		for rank in [0, 3]:
			unit._grant_veteran(rank, false)
			unit.hp = unit.max_hp - 100
			unit.special.erase("ra3_passive_heal_remaining")
			unit.special.erase("ra3_heal_remaining")
			var start: float = unit.hp
			unit._physics_process(0.9)
			check(is_equal_approx(unit.hp, start), id + " rank %d no early healing" % rank)
			unit._physics_process(0.1)
			var pulse: float = (0.0 if id == "R3MIRAGE" else 2.0) + (3.0 if rank == 3 else 0.0)
			check(is_equal_approx(unit.hp - start, pulse), id + " rank %d native heal at one second" % rank, unit.hp - start)
			unit._physics_process(1.0)
			check(is_equal_approx(unit.hp - start, pulse * 3), id + " rank %d catches up two half-second pulses" % rank, unit.hp - start)
			check(unit.hp <= unit.max_hp, id + " healing respects max health")
		unit.hp = unit.max_hp - 100
		unit.special.ra3_heal_remaining = 0.4
		if id != "R3MIRAGE": unit.special.ra3_passive_heal_remaining = 0.2
	var codec = preload("res://scripts/save/battle_snapshot.gd").new()
	var snapshot = codec.capture(battle)
	check(not snapshot.is_empty(), "three native units serialize their independent healing clocks")
	codec.restore(battle, snapshot)
	for unit in battle.units:
		unit.process_mode = Node.PROCESS_MODE_ALWAYS
		unit.set_physics_process(false); unit.set_process(false)
	await get_tree().physics_frame
	for unit in battle.units:
		var start: float = unit.hp
		unit._physics_process(0.2)
		var passive: float = 0.0 if unit.unit_id == "R3MIRAGE" else 2.0
		check(is_equal_approx(unit.hp - start, passive), unit.unit_id + " load resumes passive timer without restarting hero timer")
		unit._physics_process(0.2)
		check(is_equal_approx(unit.hp - start, passive + 3.0), unit.unit_id + " load resumes separate heroic timer")
	# The generic HUD used to label RA3's highest rank and next rank as Elite.
	for unit in battle.units:
		for rank in 4:
			unit._grant_veteran(rank, false)
			battle.select_unit(unit, false); battle._emit_selection()
			screen.hud._refresh_veterancy_live(unit)
			var expected: String = ["距老兵", "距精英", "距英雄", "英雄 · 已达最高军衔"][rank]
			check(expected in screen.hud.sel_xp_label.text, unit.unit_id + " rank %d real HUD names next/max rank correctly" % rank, screen.hud.sel_xp_label.text)
	var ra2 = actor("E1", "ally", Vector2(1400, 1900))
	ra2._grant_veteran(2, false)
	battle.select_unit(ra2, false); battle._emit_selection()
	screen.hud._refresh_veterancy_live(ra2)
	check(screen.hud.sel_xp_label.text == "精英 · 已达最高军衔", "RA2 highest-rank label stays Elite")
	screen.free(); await get_tree().process_frame
