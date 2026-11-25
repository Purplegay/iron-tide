extends "res://tests/selection_regression.gd"

func rendered() -> void:
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw

func exercise_mode(mode: String) -> void:
	BattleRequest.configure_skirmish(mode, {"map_size": 3200, "starting_funds": 10000})
	screen = load("res://scenes/battle.tscn").instantiate()
	stage.add_child(screen)
	battle = screen.battle
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	battle.process_mode = Node.PROCESS_MODE_ALWAYS
	battle.set_process(false)
	battle.set_physics_process(false)
	for child in battle.get_children():
		child.process_mode = Node.PROCESS_MODE_DISABLED
	battle.camera.position = Vector2(1600, 1600)
	battle.camera.zoom = Vector2(2, 1)
	battle.camera.reset_smoothing()
	battle.camera.force_update_scroll()
	battle.power_low = false
	var target = battle.spawn_unit("ORCA", "enemy", Vector2(1900, 1600))
	target.process_mode = Node.PROCESS_MODE_DISABLED
	for id in ["GTGCAN", "NASAM"]:
		battle.camera.zoom = Vector2(2, 1)
		battle.camera.force_update_scroll()
		var b = battle._place_building(id, "ally", Vector2(1600, 1600), true)
		b.process_mode = Node.PROCESS_MODE_DISABLED
		b._buildup_play = -1.0
		b.attack_target = target
		b._cd = 3.25
		var prefix := mode + " " + str(id) + ": "
		var art: Dictionary = b._turret_art.art
		check(b._ra2.get("tex") != null and art.get("tex") != null, prefix + "base and complete turret import")
		if art.is_empty() or b._ra2.is_empty():
			battle.buildings.erase(b)
			b.free()
			continue
		var texture: Texture2D = art.tex
		var detail: Texture2D = art.get("detail_tex")
		check(detail != null and detail.get_size() == texture.get_size() * 2.0, prefix + "surface detail texture imports at twice native density")
		var frames_valid: bool = int(art.facings) == 32 and b._turret_art.origins.size() == 32
		for frame in range(int(art.facings)):
			frames_valid = frames_valid and Rect2(Vector2.ZERO, texture.get_size()).encloses(RA2Art.src_rect(art, frame))
		check(frames_valid, prefix + "all 32 turret frames and origins are valid")
		var footprint: PackedVector2Array = b.footprint_poly()
		var target_hp: float = target.hp
		var funds: float = battle.funds
		var directions := {}
		for health in [1.0, 0.3]:
			b.hp = b.max_hp * health
			for direction in range(8):
				target.global_position = b.global_position + Vector2.RIGHT.rotated(float(direction) * TAU / 8.0) * 220.0
				# Advance the shared pose explicitly. Drawing alone must not aim/fire.
				b._turret_art.turn_toward(target.global_position - b.global_position, 20.0, b._turret_turn_speed)
				b.queue_redraw()
				await rendered()
				directions[b._turret_art.frame] = true
				var label := prefix + "hp " + str(health) + " direction " + str(direction)
				check(b._turret_art.visible, label + " turret draws")
				# These source models point along +X. Project that model axis
				# independently of the runtime's unit-facing lookup.
				var azimuth: float = PI / 4.0 - float(b._turret_art.frame) * TAU / 32.0
				var model_forward := Vector2(-sin(azimuth), 0.5 * cos(azimuth)).normalized()
				var target_forward: Vector2 = Iso.dir(target.global_position - b.global_position).normalized()
				check(model_forward.dot(target_forward) > 0.98, label + " model muzzle faces target")
				check(b.footprint_poly() == footprint and footprint == Building.placement_poly(b.data),
					label + " turret orientation and health do not enlarge collision")
				var pick := inspect_pixels(b, label)
				check(pick.is_finite(), label + " turret has pickable pixels beyond base")
				if pick.is_finite():
					check(battle._pick_at(pick) == b, label + " world picking includes turret")
				if DisplayServer.get_name() != "headless":
					stage.get_texture().get_image().save_png(output_dir.path_join("%s-%s-%d-%d.png" % [mode, id, int(health * 100), direction]))
		check(directions.size() == 8, prefix + "eight target bearings select eight distinct frames")
		check(target.hp == target_hp and battle.funds == funds and b._cd == 3.25 and b.attack_target == target,
			prefix + "drawing leaves target, damage, funds and weapon cooldown unchanged")
		b.hp = b.max_hp
		for zoom in [0.5, 1.0, 2.0, 4.0]:
			battle.camera.zoom = Vector2(zoom, zoom * 0.5)
			battle.camera.force_update_scroll()
			b.queue_redraw()
			await rendered()
			var point := inspect_pixels(b, prefix + "zoom " + str(zoom))
			check(point.is_finite(), prefix + "zoom " + str(zoom) + " turret click fixture")
			if point.is_finite():
				battle.clear_selection()
				var pixel: Vector2 = stage.get_canvas_transform() * point
				await mouse_button(pixel, true)
				await mouse_button(pixel, false)
				check(battle.selected_building == b, prefix + "zoom " + str(zoom) + " actual mouse selects turret")
		# Existing power and buildup rules: appearance must not expose a second
		# clickable turret while the construction sprite is being shown.
		var last_frame: int = b._turret_art.frame
		battle.power_low = true
		target.position = b.position + Vector2(200, 100)
		b.queue_redraw()
		await rendered()
		check(b._turret_art.frame == last_frame, prefix + "offline turret holds its heading")
		battle.power_low = false
		for fraction in [0.2, 0.8]:
			b._buildup_play = GameData.ra2_buildup_seconds() * fraction
			b.queue_redraw()
			await rendered()
			check(not b._turret_art.visible and b._art_source == b._buildup_art,
				prefix + "buildup hides finished turret " + str(fraction))
		b._buildup_play = -1.0
		b.attack_target = null
		b.queue_redraw()
		await rendered()
		check(b._turret_art.visible and b._turret_art.frame == last_frame,
			prefix + "idle turret retains last heading")
		battle.clear_selection()
		battle.buildings.erase(b)
		b.free()
		battle.camera.zoom = Vector2(2, 1)
		battle.camera.force_update_scroll()
		battle.set_build_mode(id)
		battle.preview_override = Vector2(1600, 1600)
		battle.queue_redraw()
		await rendered()
		var ghost: BuildingTurretArt = battle._build_ghost_turrets.get(id)
		check(ghost != null and ghost.visible and ghost.art.get("tex") != null,
			prefix + "placement ghost includes independent turret")
		if DisplayServer.get_name() != "headless":
			stage.get_texture().get_image().save_png(output_dir.path_join(mode + "-" + id + "-preview.png"))
		battle.armed_build = ""
		battle.preview_override = Vector2.INF
		battle.queue_redraw()
	battle.units.erase(target)
	target.free()
	screen.free()
	await get_tree().process_frame

func inspect_pixels(b, label: String) -> Vector2:
	var turret: BuildingTurretArt = b._turret_art
	var rect: Rect2 = turret.rect
	var source := turret.drawn_source
	var size := Vector2i(source.size)
	var first := Vector2.INF
	var first_raw_pixel := Vector2.INF
	var mismatches := 0
	var transparent := 0
	for y in range(0, size.y, 2):
		for x in range(0, size.x, 2):
			var local := rect.position + (Vector2(x, y) + Vector2(0.5, 0.5)) / source.size * rect.size
			var world: Vector2 = b.global_position + RA2Art.art_dir(local)
			var body_hit := RA2Art.hits_pixel(world, b.global_position, b._art_source, b.radius, b._art_aframes, b._art_frame, b._art_lift, b._art_sc)
			var turret_hit := turret.drawn_image.get_pixelv(Vector2i(source.position) + Vector2i(x, y)).a * 255.0 >= 20.0
			var expected := body_hit or turret_hit
			if b.hit_test(world) != expected:
				mismatches += 1
			if turret_hit and not body_hit:
				var pixel: Vector2 = stage.get_canvas_transform() * world
				if not first_raw_pixel.is_finite():
					first_raw_pixel = pixel
				# At 4x the long barrel can extend underneath the top HUD.
				# Test world clicks on exposed pixels; UI correctly owns covered ones.
				if not first.is_finite() and Rect2(390, 140, 800, 630).has_point(pixel):
					first = world
			if not expected:
				transparent += 1
	check(mismatches == 0 and transparent > 0, label + " hit mask equals base/turret alpha union",
		{"mismatches": mismatches, "first_raw_screen_pixel": str(first_raw_pixel)})
	return first
