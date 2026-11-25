extends "res://tests/unit_fire_regression.gd"

func exercise_mode(mode: String) -> void:
	BattleRequest.configure_skirmish(mode, {"map_size": 3200, "starting_funds": 10000})
	screen = load("res://scenes/battle.tscn").instantiate()
	stage.add_child(screen)
	battle = screen.battle
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	GM.god_mode = false
	GM.one_shot_kill = false
	for side in ["ally", "enemy"]:
		for id in ["MGTK", "TNKD"]:
			await exercise_hull(mode, side, id)
	await exercise_art(mode)
	await exercise_infantry(mode)
	screen.free()
	await get_tree().process_frame

func exercise_hull(mode: String, side: String, id: String) -> void:
	var label := "%s %s %s: " % [mode, side, id]
	var u = battle.spawn_unit(id, side, Vector2(1600, 1600))
	var t = battle.spawn_unit("MTNK", "enemy" if side == "ally" else "ally", Vector2(1600, 1780))
	for actor in [u, t]:
		actor.process_mode = Node.PROCESS_MODE_ALWAYS
		actor.set_process(false)
		actor.set_physics_process(false)
		actor.bonuses = {}
		actor.order_stop()
	await get_tree().physics_frame
	u.attack_target = t
	u.hold_position = true
	u._think_timer = 100.0
	var holder: Node = u._pick_projectile_parent()
	var before := holder.get_children()
	var effects_before: Array = Effects._host().get_children()
	# Inviso damage is applied on spawn; sample before firing, not after the hit.
	var hp_before: float = t.hp
	u._physics_process(1.0 / 60.0)
	check(new_shots(holder, before).is_empty() and u._cd_timer <= 0.0,
		label + "fixed weapon does not shoot sideways or consume cooldown")
	var bounded := true
	var previous: float = u.hull_angle
	for tick in 120:
		if not new_shots(holder, before).is_empty():
			break
		u._physics_process(1.0 / 60.0)
		bounded = bounded and absf(angle_difference(previous, u.hull_angle)) <= deg_to_rad(105.47 / 60.0) + 0.00001
		previous = u.hull_angle
	check(bounded and absf(angle_difference(u.hull_angle, PI / 2.0)) <= deg_to_rad(2.0),
		label + "body turns to target within ROT limit", u.hull_angle)
	check(absf(angle_difference(u.hull_angle, u.turret_angle)) < 0.00001,
		label + "fixed weapon art follows body")
	check(new_shots(holder, before).size() == 1, label + "aligned fixed weapon fires")
	for shot in new_shots(holder, before):
		shot.process_mode = Node.PROCESS_MODE_DISABLED
		for tick in 240:
			if shot.is_queued_for_deletion():
				break
			shot._physics_process(1.0 / 60.0)
		shot.free()
	check(hp_before - t.hp == (100.0 if id == "MGTK" else 150.0),
		label + "real projectile preserves heavy-armor damage", hp_before - t.hp)
	# Ordinary move keeps the travel heading; attack-move may stop and aim.
	u.cancel_stance() # The real Battle move command cancels hold before Unit.order_move.
	u.order_move(u.position + Vector2(300, 0))
	u.hull_angle = 0.0
	u.attack_target = t
	u._cd_timer = 0.0
	u._think_timer = 100.0
	u._physics_process(1.0 / 60.0)
	check(u.has_move_order and not u.attack_move and absf(u.hull_angle) < 0.001
		and new_shots(holder, before).is_empty(), label + "ordinary move does not turn sideways to fire")
	u.order_move(u.position + Vector2(300, 0), true)
	u.attack_target = t
	u._think_timer = 100.0
	u._physics_process(1.0 / 60.0)
	check(u.attack_move and u.hull_angle > 0.0 and new_shots(holder, before).is_empty(),
		label + "attack move starts bounded hull aim")
	for actor in [u, t]:
		battle.units.erase(actor)
		actor.free()
	for effect in Effects._host().get_children():
		if not effects_before.has(effect):
			effect.free()
	await get_tree().process_frame

func exercise_infantry(mode: String) -> void:
	var u = battle.spawn_unit("E1", "ally", Vector2(1600, 1600))
	var t = battle.spawn_unit("MTNK", "enemy", Vector2(1600, 1780))
	u.order_stop()
	u._face(t.position)
	check(absf(angle_difference(u.hull_angle, PI / 2.0)) < 0.001
		and u._weapon_aligned(t), mode + ": stationary infantry turns firing frames to target")
	for actor in [u, t]:
		battle.units.erase(actor)
		actor.free()

func exercise_art(mode: String) -> void:
	check(DisplayServer.get_name() != "headless", mode + ": emitter and pixel checks require rendering")
	if DisplayServer.get_name() == "headless":
		return
	battle.camera.position = Vector2(1600, 1600)
	battle.camera.zoom = Iso.cam_zoom(3.0)
	battle.camera.rotation = Iso.cam_angle()
	battle.camera.reset_smoothing()
	battle.camera.force_update_scroll()
	for id in ["MTNK", "FV", "SREF", "MGTK", "TNKD", "ORCA", "BEAG", "HORNET"]:
		var u = battle.spawn_unit(id, "ally", Vector2(1600, 1600))
		u.special.mirage_enabled = false # This case measures the firing model; disguise is covered separately.
		u.order_stop()
		u.selected = true
		u.process_mode = Node.PROCESS_MODE_DISABLED
		var descriptor: Dictionary = u._weapon_art
		var facings := int(u._ra2.get("facings", 8))
		check(descriptor.get("muzzles", []).size() == facings, "%s %s: complete emitter metadata" % [mode, id])
		var turret_only_total := 0
		for frame in facings:
			var label := "%s %s facing %d: " % [mode, id, frame]
			var az := PI / 4.0 - frame * TAU / float(facings)
			# Independent model +X projection, not the runtime facing helper.
			var forward := Vector2(-sin(az), 0.5 * cos(az))
			var heading := RA2Art.art_dir(forward).angle()
			u.hull_angle = heading
			u.turret_angle = heading
			u.aim_dir = Vector2.RIGHT.rotated(heading)
			u.queue_redraw()
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			check(u._art_frame == frame, label + "body points along projected model +X", u._art_frame)
			var source: Rect2 = RA2Art.src_rect(u._ra2, frame)
			var body_image: Image = u._ra2.img
			var turret_image: Image = u._ra2_tur.get("img")
			check(Rect2(Vector2.ZERO, body_image.get_size()).encloses(source), label + "source rectangle fits actual atlas")
			if turret_image != null:
				check(u._turret_draw_source == RA2Art.src_rect(u._ra2_tur, frame), label + "turret faces same target")
			var point: Array = descriptor.muzzle_model_point
			var origin: Array = descriptor.origins[frame]
			var projected := Vector2(float(origin[0]) - float(point[0]) * sin(az) + float(point[1]) * cos(az),
				float(origin[1]) + 0.5 * (float(point[0]) * cos(az) + float(point[1]) * sin(az)) - float(point[2]) * sqrt(3.0) / 2.0)
			# These three fixed-wing fixtures use stock YR General FlightLevel=1500.
			var lift: float = 1500.0 * 30.0 / 256.0 * u.logistics.air_lift if u.is_air else 0.0
			var base: Rect2 = RA2Art.draw_rect(u._ra2, u.radius, range(facings), lift, u.RA2_SPRITE_SCALE)
			var expected: Vector2 = u.position + RA2Art.art_dir(base.position + projected * u.RA2_SPRITE_SCALE)
			check(u._weapon_muzzle().distance_to(expected) < 0.001, label + "muzzle matches independent model projection")
			var emitter_image: Image = turret_image if turret_image != null else body_image
			var emitter_source: Rect2 = u._turret_draw_source if turret_image != null else source
			var near_opaque := false
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					var pixel := Vector2i(emitter_source.position + projected.round()) + Vector2i(dx, dy)
					if pixel.x >= 0 and pixel.y >= 0 and pixel.x < emitter_image.get_width() and pixel.y < emitter_image.get_height():
						near_opaque = near_opaque or emitter_image.get_pixelv(pixel).a > 0.08
			check(near_opaque, label + "projected emitter touches visible model pixels")
			var mask_ok := true
			var turret_only := 0
			for y in int(source.size.y):
				for x in int(source.size.x):
					var bp: Vector2i = Vector2i(source.position) + Vector2i(x, y)
					var opaque := bp.x < body_image.get_width() and bp.y < body_image.get_height() \
						and body_image.get_pixelv(bp).a * 255.0 >= 20.0
					if turret_image != null:
						var tp := Vector2i(u._turret_draw_source.position) + Vector2i(x, y)
						var top := turret_image.get_pixelv(tp).a * 255.0 >= 20.0
						if top and not opaque:
							turret_only += 1
						opaque = opaque or top
					var world: Vector2 = u.position + RA2Art.art_dir(base.position + (Vector2(x, y) + Vector2(0.5, 0.5)) * u.RA2_SPRITE_SCALE)
					mask_ok = mask_ok and u.hit_test(world) == opaque
			check(mask_ok, label + "all visible body and turret pixels clickable; transparent pixels rejected")
			turret_only_total += turret_only
			# Real firing entry must spawn its projectile at the same visual emitter.
			var t = battle.spawn_unit("MTNK", "enemy", u.position + Vector2.RIGHT.rotated(heading) * 180.0)
			t.order_stop()
			var holder: Node = u._pick_projectile_parent()
			var before := holder.get_children()
			var effects_before: Array = Effects._host().get_children()
			u._fire_shot(t)
			var shots := new_shots(holder, before)
			if shots.size() == 1 and shots[0].ra2_inviso:
				check(shots[0]._detonated and shots[0].global_position.distance_to(t.global_position) < 0.001,
					label + "Inviso resolves immediately at target without artificial travel")
				var beams := Effects._host().get_children().filter(func(effect): return not effects_before.has(effect) and effect is Effects.Beam)
				if not GameData.ra2_beam_spec(str(u._active_weapon().get("ra2_weapon_id", ""))).is_empty():
					check(beams.any(func(beam): return beam.from.distance_to(expected) < 0.001), label + "instant weapon beam starts at visible emitter")
				else:
					check(Effects._host().get_children().any(func(effect): return not effects_before.has(effect) and effect is Ra2Fx and effect.global_position.distance_to(expected) < 0.001), label + "instant heat weapon native muzzle animation starts at emitter")
			else:
				check(shots.size() == 1 and shots[0].global_position.distance_to(expected) < 0.001,
					label + "actual projectile starts at visible emitter")
			for shot in shots:
				shot.free()
			for effect in Effects._host().get_children():
				if not effects_before.has(effect):
					effect.free()
			battle.units.erase(t)
			t.free()
			if frame == 1:
				await RenderingServer.frame_post_draw
				stage.get_texture().get_image().save_png(output_dir.path_join("%s-%s-muzzle.png" % [mode, id]))
		if not u._ra2_tur.is_empty():
			check(turret_only_total > 0, "%s %s: coverage includes exposed turret/barrel pixels" % [mode, id], turret_only_total)
			# A rotating turret can point independently of the body.
			if u._mv("turret", false):
				u.turret_angle = u.hull_angle + PI / 2.0
				u.queue_redraw()
				await get_tree().process_frame
				await RenderingServer.frame_post_draw
				check(u._turret_draw_source != RA2Art.src_rect(u._ra2_tur, u._art_frame),
					"%s %s: independent turret frame retained" % [mode, id])
		battle.units.erase(u)
		u.free()
