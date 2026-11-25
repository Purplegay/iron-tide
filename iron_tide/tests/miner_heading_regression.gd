extends "res://tests/selection_regression.gd"

func exercise_mode(mode: String) -> void:
	BattleRequest.configure_skirmish(mode, {"map_size": 3200})
	screen = load("res://scenes/battle.tscn").instantiate()
	stage.add_child(screen)
	battle = screen.battle
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	var miner = battle.spawn_unit("CMIN", "ally", Vector2(1600, 1600))
	battle.camera.position = miner.position
	battle.camera.zoom = Vector2(3, 1.5)
	battle.camera.reset_smoothing()
	battle.camera.force_update_scroll()
	var facings := int(miner._ra2.get("facings", 8))
	for direction in facings:
		miner.hull_angle = direction * TAU / float(facings)
		miner.queue_redraw()
		await get_tree().process_frame
		if DisplayServer.get_name() == "headless":
			continue
		await RenderingServer.frame_post_draw
		# CMIN's cabin is at model +X. The source renderer projects +X as
		# (-sin(az), 0.5*cos(az)); this is independent of runtime frame selection.
		var az: float = PI / 4.0 - miner._art_frame * TAU / float(facings)
		var cabin_front := Vector2(-sin(az), 0.5 * cos(az)).normalized()
		var expected := Iso.dir(Vector2.RIGHT.rotated(miner.hull_angle)).normalized()
		check(cabin_front.dot(expected) > 0.98, "%s CMIN cabin faces travel direction %d" % [mode, direction],
			{"frame": miner._art_frame, "dot": cabin_front.dot(expected)})
		var rect := RA2Art.draw_rect(miner._ra2, miner.radius, range(facings), 0.0, miner.RA2_SPRITE_SCALE)
		var source := RA2Art.src_rect(miner._ra2, miner._art_frame)
		var texture: Texture2D = miner._ra2.tex
		var pixels := texture.get_image()
		var errors := 0
		var opaque := 0
		for x in range(0, int(source.size.x), 3):
			for y in range(0, int(source.size.y), 3):
				var sample := Vector2i(source.position) + Vector2i(x, y)
				var expected_hit := false
				if sample.x < pixels.get_width() and sample.y < pixels.get_height():
					expected_hit = pixels.get_pixelv(sample).a >= 20.0 / 255.0
				var local: Vector2 = rect.position + (Vector2(x, y) + Vector2(0.5, 0.5)) * miner.RA2_SPRITE_SCALE
				var hit: bool = miner.hit_test(miner.position + RA2Art.art_dir(local))
				errors += 1 if hit != expected_hit else 0
				opaque += 1 if expected_hit else 0
		check(errors == 0 and opaque > 20, "%s CMIN drawn frame and click mask agree %d" % [mode, direction], errors)
		if direction % 4 == 0:
			stage.get_texture().get_image().save_png(output_dir.path_join("%s-heading-%d.png" % [mode, direction]))
	screen.free()
	await get_tree().process_frame
