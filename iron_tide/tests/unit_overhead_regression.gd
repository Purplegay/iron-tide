extends "res://tests/base_recovery_regression.gd"

func _ready() -> void:
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not ProjectSettings.get_setting("application/config/use_custom_user_dir", false):
		get_tree().quit(2)
		return
	start(MatchRules.EXTENDED)
	var point := Vector2(1200, 1200)
	battle.camera.position = point
	battle.camera.reset_smoothing()
	battle.camera.force_update_scroll()
	var inspected := {}
	for faction in ["allied", "soviet", "other"]:
		var roster := GameData.unit_index.keys() if faction == "other" else GameData.faction_unit_catalog(faction)
		check(not roster.is_empty(), faction + " roster loaded")
		for id in roster:
			if inspected.has(id): continue
			inspected[id] = true
			var u = battle.spawn_unit(id, "ally", point)
			u.selected = true
			u.hp *= 0.6
			u.queue_redraw()
			await get_tree().process_frame
			if DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				var bar: Rect2 = u.hp_bar_rect()
				var bounds: Rect2 = u._body_bounds
				check(bar.has_area() and bar.end.y < 0, id + " overhead bar above origin", bar)
				if u._ra3_model != null or not u._ra2.is_empty():
					check(bounds.has_area() and bar.end.y <= bounds.position.y - 4.0, id + " bar clears drawn body", [bar,bounds])
				if u._ra3_model != null and u._ra3_model.body_mask != null:
					var img: Image = u._ra3_model.body_mask.get_texture().get_image()
					var pixels := img.get_used_rect()
					if pixels.has_area():
						var rect: Rect2 = u._ra3_model.draw_rect
						var top := rect.position.y + rect.size.y * pixels.position.y / img.get_height()
						check(bar.end.y < top, id + " bar clears rendered 3D silhouette", [bar.end.y, top])
				elif u._art_frame >= 0 and u._ra2.get("img") != null:
					var src := RA2Art.src_rect(u._ra2, u._art_frame)
					var image: Image = u._ra2.img
					var pixels := image.get_region(Rect2i(src)).get_used_rect()
					var rect := RA2Art.draw_rect(u._ra2,u.radius,u._art_aframes,u._art_lift,u._art_sc)
					check(bar.end.y < rect.position.y + pixels.position.y * u._art_sc, id + " bar clears native frame")
			battle.units.erase(u)
			u.free()
	await finish()
	var report := FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks,"failed":failed}))
	report.close()
	get_tree().quit(0 if failed == 0 else 1)
