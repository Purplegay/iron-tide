extends "res://tests/logistics_regression.gd"

const Tower = preload("res://scripts/units/head_games_weapons.gd")

func add_unit(id: String, side: String, point: Vector2) -> Unit:
	var unit: Unit = battle.spawn_unit(id, side, point)
	activate(unit)
	return unit

func played_since(count: int, sample: String) -> bool:
	if Ra2Sfx.a_plays != count + 1: return false
	var slot := posmod(Ra2Sfx._global_cursor - 1, Ra2Sfx._global_pool.size())
	var stream: AudioStream = Ra2Sfx._global_pool[slot].stream
	return stream != null and stream.resource_path == GameData.ra2_sfx_path("hollywood/" + sample.trim_prefix("hol_") + ".wav")

func exercise_mode(mode: String) -> void:
	setup_logistics_scene(mode, "美国")
	var tag := mode + " "
	var point := Vector2(1600, 1600)
	for id in ["YURI", "YURIPR", "MIND"]:
		var owner := add_unit(id, "enemy", point)
		var target := add_unit("E1", "ally", point + Vector2(100, 0))
		var weapon: Dictionary = owner._weapon_for_target(target)
		var count: int = Ra2Sfx.a_plays
		AlliedAbilities.special_shot(owner, target, weapon)
		check(target.side == "enemy" and target.special.get("controller") == owner and played_since(count, "hol_iyurat1a"), tag + id + " capture plays retail global sample")
		count = Ra2Sfx.a_plays
		AlliedAbilities.special_shot(owner, target, weapon)
		check(Ra2Sfx.a_plays == count, tag + id + " repeat hit is silent")
		var second: Unit = null
		if id == "MIND":
			second = add_unit("E1", "ally", point + Vector2(100, 40))
			AlliedAbilities.special_shot(owner, second, owner._weapon_for_target(second))
			check(second.special.get("controller") == owner and played_since(count, "hol_iyurat1a"), tag + "Mastermind second target capture sound")
		count = Ra2Sfx.a_plays
		AlliedAbilities.release_control(owner)
		check(target.side == "ally" and not target.special.has("controller") and (played_since(count, "hol_gmindcle") if second == null else (Ra2Sfx.a_plays == count + 2 and played_since(count + 1, "hol_gmindcle") and second.side == "ally")), tag + id + " release plays once per surviving target")
		count = Ra2Sfx.a_plays
		AlliedAbilities.release_control(owner)
		AlliedAbilities.tick_actor(target, 0.0)
		check(Ra2Sfx.a_plays == count, tag + id + " repeated cleanup is silent")
		remove_actor(owner)
		remove_actor(target)
		remove_actor(second)
	var tower: Building = battle._place_building("YAPSYT", "enemy", point, true)
	activate(tower, false)
	tower.powered = false
	var victim := add_unit("E1", "ally", point + Vector2(105, 0))
	var count: int = Ra2Sfx.a_plays
	Tower.tower(tower, 1.0)
	check(victim.side == "enemy" and victim.special.get("controller") == tower and played_since(count, "hol_iyurat1a"), tag + "Psychic Tower capture plays retail global sample")
	count = Ra2Sfx.a_plays
	Tower.tower(tower, 1.0)
	check(Ra2Sfx.a_plays == count, tag + "Psychic Tower repeat scan is silent")
	tower.hp = 0.0
	AlliedAbilities.tick_actor(victim, 0.0)
	check(victim.side == "ally" and not victim.special.has("controller") and played_since(count, "hol_gmindcle"), tag + "Psychic Tower loss plays retail release sample")
	count = Ra2Sfx.a_plays
	AlliedAbilities.tick_actor(victim, 0.0)
	check(Ra2Sfx.a_plays == count, tag + "Psychic Tower repeat cleanup is silent")
	Ra2Sfx.stop_all()
	screen.free()
	await get_tree().process_frame
