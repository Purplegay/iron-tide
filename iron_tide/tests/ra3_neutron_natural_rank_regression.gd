extends "res://tests/ra3_neutron_visibility_regression.gd"
## Natural kill-credit promotion, full orb lifetime, and in-flight bonus snapshot.
func full_damage(shot, target) -> float:
	var before: float = target.hp
	arrive(shot)
	for i in 180: Ra3Expansion.tick_shot(shot, 1.0 / 60.0)
	check(int(shot.splinters.neutron_pre) == 7 and int(shot.splinters.neutron_tick) == 19,
		"promotion does not multiply node queries", shot.splinters)
	var damage: float = before - target.hp
	shot.free()
	return damage

func exercise_mode(mode: String) -> void:
	if mode == MatchRules.RA2: return
	setup_logistics_scene(mode, "美国")
	for node in battle.units + battle.buildings: node.free()
	battle.units.clear(); battle.buildings.clear()
	if battle.fog != null: battle.fog.free(); battle.fog = null
	GM.god_mode = false; GM.one_shot_kill = false
	var future = actor("R3FUTURE", "ally", Vector2(1400, 1400))
	var target = actor("R3FUTURE", "enemy", Vector2(1700, 1400))
	var hits: Array[float] = []
	for rank in 4:
		target.hp = target.max_hp
		future._fire_shot(target)
		var shot = battle.projectiles_root.get_child(0)
		shot.target_point = target.position
		hits.append(full_damage(shot, target))
		check(is_equal_approx(hits[rank], 65.1 * (1.25 if rank > 0 else 1.0)),
			"natural rank %d full native-target orb damage" % rank, hits[rank])
		if rank == 3: break
		# Prepare XP just below the boundary; the real lethal projectile awards XP,
		# enters Unit._die -> credit_kill -> announce=true, and switches weapons.
		var victim = actor("R3FUTURE", "enemy", Vector2(1700, 2200))
		future._vet_kills = Ra3Expansion.rank_requirement(future) - victim._vet_value
		victim.hp = 0.01
		var previous = Ra3Expansion.make_shot(future, target, target.position, "neutron")
		var kill = Ra3Expansion.make_shot(future, victim, victim.position, "neutron")
		arrive(kill)
		Ra3Expansion.tick_shot(kill, 1.0 / 60.0)
		check(victim._dead and future.veteran_level == rank + 1,
			"lethal orb naturally promotes to rank %d" % (rank + 1), future.veterancy_status())
		kill.free()
		target.hp = target.max_hp
		check(is_equal_approx(full_damage(previous, target), hits[rank]),
			"already fired orb retains its pre-promotion bonus at rank %d" % rank)
		future._recompute_bonuses()
		# Keep this fixture free of unrelated player loadout upgrades.
		future.bonuses.attack_bonus = 1.0
		check(is_equal_approx(float(future.bonuses.veteran_attack), 1.25),
			"ordinary bonus refresh preserves natural promotion")
	check(is_equal_approx(future.cooldown, 2.5), "heroic cycle is 3 / 1.2 seconds", future.cooldown)
	screen.free(); await get_tree().process_frame
