extends "res://tests/ra3_riot_regression.gd"

func total(source, target, scale: float, step: float, restore_midway := false) -> float:
	Riot.balance.structure_damage_multiplier = scale
	target.hp = 100000; target.max_hp = 100000
	var shot = beam(source, target.position)
	var elapsed := 0.0
	var restored := false
	while elapsed < 1.2:
		Ra3Expansion.tick_shot(shot, step)
		elapsed += step
		if restore_midway and not restored and elapsed >= 0.45:
			var id: String = target.building_id
			var codec = preload("res://scripts/save/battle_snapshot.gd").new()
			var saved: Dictionary = codec.capture(battle)
			codec.restore(battle, saved)
			shot = battle.projectiles_root.get_child(0)
			target = battle.buildings.filter(func(b):return b.building_id == id)[0]
			restored = true
	var dealt: float = 100000 - target.hp
	clear_shots()
	return dealt

func exercise_mode(mode: String) -> void:
	if mode == MatchRules.RA2: return
	setup_logistics_scene(mode, "美国")
	for node in battle.units + battle.buildings: node.free()
	battle.units.clear(); battle.buildings.clear()
	if battle.fog != null: battle.fog.free(); battle.fog = null
	battle.water_rects = []; battle.path_service.set_water([]); battle.paused = false
	var source = actor("R3FUTURE", "ally", Vector2(1200, 1200))
	source.fire_stance = "none"
	check(is_equal_approx(float(Riot.balance.structure_damage_multiplier), 0.5), "production balance config sets structures to half damage")
	for id in ["GACNST", "GAPILE", "GAPOWR", "GAWEAP"]:
		var target = battle._place_building(id, "enemy", Vector2(1500, 1200), true)
		target._buildup_play = -1
		var real_hp: float = target.max_hp
		for rank in [0, 3]:
			source._grant_veteran(rank, false)
			var old := total(source, target, 1.0, 1.0/60)
			for step in [1.0/15, 1.0/60, 1.0/120, 0.4]:
				var now := total(source, target, 0.5, step)
				check(old > 0 and is_equal_approx(now, old*0.5), id + " rank " + str(rank) + " full Q halves structure damage at step " + str(step), {"before":old,"after":now,"original_hp":real_hp,"before_fraction":old/real_hp,"after_fraction":now/real_hp})
		battle.buildings.erase(target); target.free()
	source._grant_veteran(0, false)
	for id in ["E1", "MTNK", "R3MIRAGE", "R3FUTURE"]:
		var target = actor(id, "enemy", Vector2(1500, 1200))
		var old := total(source, target, 1.0, 1.0/60)
		var now := total(source, target, 0.5, 1.0/60)
		check(old > 0 and is_equal_approx(now, old), id + " unit damage remains unchanged", {"before":old,"after":now})
		battle.units.erase(target); target.free()
	var yard = battle._place_building("GACNST", "enemy", Vector2(1500, 1200), true)
	yard._buildup_play = -1
	var baseline := total(source, yard, 0.5, 1.0/60)
	var restored := total(source, yard, 0.5, 1.0/60, true)
	check(is_equal_approx(baseline, restored), "mid-Q save restore preserves reduced damage without replay", {"baseline":baseline,"restored":restored})
	check(Riot.cooldown() == 15 and Riot.duration() == 1, "native cooldown and sweep duration unchanged")
	check("50%" in Ra3Expansion.info(battle.units[0]).desc, "skill UI describes the active structure damage reduction")
	screen.free(); await get_tree().process_frame
