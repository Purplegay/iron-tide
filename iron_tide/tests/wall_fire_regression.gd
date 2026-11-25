extends "res://tests/selection_regression.gd"

func exercise_mode(mode: String) -> void:
	BattleRequest.configure_skirmish(mode, {"fog_of_war": false, "map_size": 3200})
	screen = load("res://scenes/battle.tscn").instantiate()
	stage.add_child(screen)
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	battle = screen.battle
	GM.one_shot_kill = false
	GM.god_mode = false
	var center := Vector2(1600, 1600)
	for pair in [["E1", "NAWALL"], ["E2", "GAWALL"], ["GHOST", "NAWALL"]]:
		var tag: String = mode + " " + pair[0] + " "
		var gun = battle.spawn_unit(pair[0], "ally", center - Vector2(80, 0))
		var victim = battle.spawn_unit("E2", "enemy", center + Vector2(80, 0))
		var wall = battle._place_building(pair[1], "enemy", center, true)
		gun.attack_ordered = true
		gun.attack_target = victim
		gun._cd_timer = 0
		var initial: float = victim.hp
		check(not gun._try_fire_ready() and gun._cd_timer == 0.0 and victim.hp == initial, tag + "wall screens target before firing")
		var rifle: Dictionary = gun._weapon_for_target(victim)
		check(WallArt.shot_blocked(battle, victim, gun, rifle), tag + "wall screens either direction")
		var ground := ForceFirePoint.new()
		if pair[0] == "E1":
			gun.set_deployed(true, false)
			check(not gun._try_fire_ready(), tag + "deployed machine gun is also screened")
			gun.set_deployed(false, false)
		ground.global_position = victim.global_position
		check(WallArt.shot_blocked(battle, gun, ground, rifle), tag + "forced ground shot uses same ray")
		check(not ForceFire.reason(battle, gun, wall).is_empty() and not gun._weapon_target_valid(wall), tag + "rifle cannot target wall even with force fire")
		var pillbox = battle._place_building("GAPILL", "ally", center - Vector2(80, 40), true)
		check(not pillbox._valid_weapon_target(victim), tag + "pillbox gun screened")
		var tank = battle.spawn_unit("MTNK", "ally", center - Vector2(80, 80))
		tank.attack_ordered = true
		check(tank._weapon_target_valid(wall), tag + "tank can target wall")
		pillbox.free()
		tank.free()
		var wall_hp: float = wall.hp
		wall.receive_hit(100, "bullet", {}, gun, str(rifle.ra2_warhead))
		check(wall.hp == wall_hp, tag + "wall resists rifle damage")
		wall.receive_hit(20, "cannon", {}, gun, "AP")
		check(wall.hp < wall_hp, tag + "armor piercing tank shell damages wall")
		victim.position = center + Vector2(80, 100)
		gun.position = center - Vector2(80, -100)
		check(not WallArt.shot_blocked(battle, gun, victim, rifle), tag + "clear parallel lane")
		gun.position = center - Vector2(80, 0)
		victim.position = center + Vector2(80, 0)
		wall.receive_hit(1, "explosion", {}, gun, "NUKE")
		check(wall.is_dead() and not WallArt.shot_blocked(battle, gun, victim, rifle), tag + "destroyed segment immediately opens gap")
		gun.hull_angle = 0.0
		gun.turret_angle = 0.0
		check(gun._try_fire_ready() and victim.hp < initial, tag + "same shot hits through gap")
		await get_tree().process_frame
		gun.free()
		victim.free()
	screen.free()
	await get_tree().process_frame
