extends "res://tests/defense_art_regression.gd"

func exercise_mode(mode: String) -> void:
	BattleRequest.configure_skirmish(mode, {"map_size": 3200, "starting_funds": 10000})
	screen = load("res://scenes/battle.tscn").instantiate()
	stage.add_child(screen)
	battle = screen.battle
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	battle.power_low = false
	battle.camera.position = Vector2(1600, 1600)
	battle.camera.zoom = Vector2(3, 1.5)
	battle.camera.reset_smoothing()
	battle.camera.force_update_scroll()
	var b = battle._place_building("GTGCAN", "ally", Vector2(1600, 1600), true)
	var t = battle.spawn_unit("MTNK", "enemy", Vector2(1900, 1600))
	b._buildup_play = -1.0
	b.attack_target = t
	b._think = 100.0
	var art: BuildingTurretArt = b._turret_art
	check(art.recoil_texture != null and art.recoil_image != null and art.recoil.poses.size() == 8,
		mode + ": eight recoil poses import")
	var footprint: PackedVector2Array = b.footprint_poly()
	var holder: Node = get_tree().get_first_node_in_group("projectiles_root")
	var target_hp: float = t.hp
	var funds: float = battle.funds
	for direction in 8:
		var angle := float(direction) * TAU / 8.0
		t.position = b.position + Vector2.RIGHT.rotated(angle) * 400.0
		art.angle = angle
		b._cd = 0.0
		var before := holder.get_children()
		b._process(0.0)
		check(art._recoil_elapsed == 0.0 and b._cd == b.cooldown, mode + ": real fire triggers recoil " + str(direction))
		var muzzle_start: Vector2 = Iso.dir(b._weapon_muzzle() - b.position)
		var elapsed := 0.0
		var anchor := Vector2.INF
		# Original local configuration: compress 3, hold 3, recover 40 ticks at 15 Hz.
		var times := [0.0, 0.025, 0.05, 0.075, 0.1, 0.125, 0.15, 0.175, 0.2, 0.3, 0.4, 1.733333, 3.066667]
		var expected_poses := [0, 1, 2, 3, 4, 5, 6, 7, 8, 8, 8, 4, 0]
		for i in times.size():
			var time: float = times[i]
			b._process(time - elapsed)
			elapsed = time
			b.queue_redraw()
			await rendered()
			var prefix := "%s bearing=%d time=%.3f: " % [mode, direction, time]
			var pose := art.recoil_pose()
			check(pose == expected_poses[i], prefix + "compress/hold/recover phase", pose)
			var az := PI / 4.0 - float(art.frame) * TAU / 32.0
			var travel := float(pose) # eight model units across eight poses
			var wanted := muzzle_start + Vector2(travel * sin(az), -travel * 0.5 * cos(az))
			check(Iso.dir(b._weapon_muzzle() - b.position).distance_to(wanted) < 0.01,
				prefix + "muzzle retracts along barrel axis")
			var origins: Array = art.recoil.poses[pose - 1].origins if pose > 0 else art.origins
			var model_origin := art.rect.position + Vector2(origins[art.frame][0], origins[art.frame][1])
			if not anchor.is_finite():
				anchor = model_origin
			check(model_origin.distance_to(anchor) < 0.01 and b.footprint_poly() == footprint,
				prefix + "turret origin and building footprint stay fixed")
			check(Rect2(Vector2.ZERO, art.drawn_image.get_size()).encloses(art.drawn_source),
				prefix + "recoil source frame lies inside atlas")
			inspect_pixels(b, prefix)
			if direction in [1, 5] and i in [0, 8, 12] and DisplayServer.get_name() != "headless":
				stage.get_texture().get_image().save_png(output_dir.path_join("%s-recoil-%d-%d.png" % [mode, direction, i]))
		check(art._recoil_elapsed < 0.0 and art.drawn_image == art.image,
			mode + ": full recovery returns to original idle sprite " + str(direction))
		check(t.hp == target_hp and battle.funds == funds and is_equal_approx(b._cd, b.cooldown - elapsed),
			mode + ": recoil does not change damage, funds or cooldown " + str(direction))
		for node in holder.get_children():
			if node is Projectile and not before.has(node):
				node.free()
		for node in Effects._host().get_children():
			node.free()
	var sam = battle._place_building("NASAM", "ally", Vector2(1800, 1600), true)
	sam._turret_art.start_recoil()
	check(sam._turret_art.recoil_pose() == 0, mode + ": non-recoiling launcher keeps original sprite")
	screen.free()
	await get_tree().process_frame
