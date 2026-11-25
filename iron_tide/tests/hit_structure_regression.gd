extends "res://tests/selection_regression.gd"

func exercise_mode(mode: String) -> void:
	BattleRequest.configure_skirmish(mode, {"map_size": 3200, "starting_funds": 10000})
	screen = load("res://scenes/battle.tscn").instantiate()
	stage.add_child(screen)
	battle = screen.battle
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	GM.god_mode = false
	GM.one_shot_kill = false
	battle.camera.position = Vector2(1600, 1600)
	battle.camera.zoom = Vector2(2, 1)
	battle.camera.reset_smoothing()
	battle.camera.force_update_scroll()
	for side in ["enemy", "ally"]:
		var victim_side := "ally" if side == "enemy" else "enemy"
		for target_kind in ["unit", "building"]:
			var shooter = battle.spawn_unit("MTNK", side, Vector2(1450, 1600))
			var victim = battle.spawn_unit("MTNK", victim_side, Vector2(1600, 1600)) if target_kind == "unit" \
				else battle._place_building("GAPOWR", victim_side, Vector2(1600, 1600), true)
			var bystander = battle.spawn_unit("MTNK", side, Vector2(1600, 1600))
			var far_target = battle.spawn_unit("MTNK", victim_side, Vector2(1750, 1600))
			for actor in [shooter, victim, bystander, far_target]:
				actor.process_mode = Node.PROCESS_MODE_DISABLED
				actor.bonuses = {}
			var prefix := "%s %s -> %s: " % [mode, side, target_kind]
			var before: float = victim.hp
			var friendly_before: float = bystander.hp
			var far_before: float = far_target.hp
			var holder: Node = shooter._pick_projectile_parent()
			var existing := holder.get_children()
			shooter._fire_shot(victim)
			var shots: Array = holder.get_children().filter(func(node): return node is Projectile and not existing.has(node))
			check(shots.size() == 1, prefix + "real tank fire creates one projectile")
			for shot in shots:
				shot.process_mode = Node.PROCESS_MODE_DISABLED
				# Drive the actual projectile flight, not a replacement damage formula.
				for tick in 180:
					if shot.is_queued_for_deletion():
						break
					shot._physics_process(1.0 / 60.0)
				check(shot.is_queued_for_deletion(), prefix + "projectile reaches impact")
			check(victim.hp < before, prefix + "enemy target loses HP", {"before": before, "after": victim.hp})
			check(before - victim.hp == (65.0 if target_kind == "unit" else 42.0),
				prefix + "AP applies heavy/wood armor and integer damage once", before - victim.hp)
			check(bystander.hp == friendly_before, prefix + "same-side unit at impact is unharmed",
				{"before": friendly_before, "after": bystander.hp})
			check(far_target.hp == far_before, prefix + "target outside splash radius is unharmed")
			# Also cover the extension's non-RA2 splash branch and a direct-hit weapon.
			for splash in [40.0, 0.0]:
				victim.hp = victim.max_hp
				bystander.hp = bystander.max_hp
				var p := Projectile.new()
				p.setup(victim.global_position, victim, {"damage": 20.0, "aoe": splash}, 20.0, {}, side)
				holder.add_child(p)
				p.process_mode = Node.PROCESS_MODE_DISABLED
				p._physics_process(0.01)
				check(victim.hp == victim.max_hp - 20.0, prefix + "legacy/direct damage " + str(splash), victim.hp)
				check(bystander.hp == bystander.max_hp, prefix + "legacy/direct preserves friendly HP " + str(splash))
			for actor in [shooter, victim, bystander, far_target]:
				battle.units.erase(actor)
				battle.buildings.erase(actor)
				actor.free()
			await get_tree().process_frame
	# Frozen impact effects from the damage cases must not cover the art samples.
	for effect in battle.effects_root.get_children():
		effect.free()
	for id in ["GAWEAP", "GAREFN", "GADEPT", "GAAIRC"]:
		var b = battle._place_building(id, "ally", Vector2(1600, 1600), true)
		b.process_mode = Node.PROCESS_MODE_DISABLED
		b._buildup_play = -1.0
		var metadata: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/ra2/shp/%s.json" % id))
		check(metadata.get("bib", "") == id + "BB", mode + " " + id + ": source BibShape is included in finished body")
		check(b.hp == b.max_hp, mode + " " + id + ": visual fixture really has full health")
		check(b.footprint_poly() == Building.placement_poly(b.data), mode + " " + id + ": preview and actor footprint agree")
		b._tick_anim_state(0.0)
		b.queue_redraw()
		await get_tree().process_frame
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			stage.get_texture().get_image().save_png(output_dir.path_join(mode + "-" + id + "-full-health.png"))
			# Independently selected opaque points from each original BibShape,
			# all transparent in the old body-only sheet.
			var source_pixel: Vector2 = {"GAWEAP": Vector2(233, 198), "GAREFN": Vector2(169, 168),
				"GADEPT": Vector2(84, 118), "GAAIRC": Vector2(140, 125)}[id]
			var texture: Texture2D = b._ra2.tex
			check(texture.get_image().get_pixelv(Vector2i(source_pixel)).a > 0.9,
				mode + " " + id + ": original foundation pixel is opaque in imported texture")
			var rect := RA2Art.draw_rect(b._ra2, b.radius, [0], 0.0, b.RA2_SPRITE_SCALE)
			var world: Vector2 = b.global_position + RA2Art.art_dir(rect.position + (source_pixel + Vector2(0.5, 0.5)) * b.RA2_SPRITE_SCALE)
			check(b.hit_test(world), mode + " " + id + ": restored foundation is clickable")
		if id == "GAWEAP":
			b._exit_anim_left = 10.0
			b._set_anim_state("production")
			for air in [false, true]:
				b._exit_air = air
				for health in [1.0, 0.3]:
					b.hp = b.max_hp * health
					for lay in b._ra2_anim:
						if b._is_door_layer(str(lay.kind)) and b._door_layer_matches(str(lay.kind)):
							var st: Dictionary = b._anim_layer(lay)
							var frame: int = b._anim_frame_for(lay, st)
							# These local SHPs contain healthy, damaged, and two shadow frames,
							# not four opening frames. Never show damage/shadow as healthy art.
							check(frame == (0 if health == 1.0 else 1), mode + " factory structural frame " + str(lay.kind) + " " + str(health), frame)
					b.queue_redraw()
					await get_tree().process_frame
					if DisplayServer.get_name() != "headless":
						await RenderingServer.frame_post_draw
						stage.get_texture().get_image().save_png(output_dir.path_join("%s-factory-%s-%s.png" % [mode, "air" if air else "ground", str(health)]))
		battle.buildings.erase(b)
		b.free()
		await get_tree().process_frame
	screen.free()
	await get_tree().process_frame
