extends "res://tests/logistics_regression.gd"

# Measured centers of the four painted pads in the 188x162 original GAAIRCBB canvas.
const PAD_PIXELS := [Vector2(124, 110), Vector2(94, 125), Vector2(154, 125), Vector2(124, 140)]

func exercise_mode(mode: String) -> void:
	setup_logistics_scene(mode, "韩国" if mode == MatchRules.RA2 else "美国")
	for unit in battle.units: unit.free()
	battle.units.clear()
	for building in battle.buildings: building.free()
	battle.buildings.clear()
	for group in ["obstacles", "resource_nodes"]:
		for node in get_tree().get_nodes_in_group(group): node.free()
	if battle.fog != null: battle.fog.free(); battle.fog = null
	battle.water_rects.clear()
	battle.path_service.set_water([])
	var base = airport("ally", Vector2(1600, 1600))
	battle.camera.position = base.position
	battle.camera.zoom = Vector2(3, 1.5)
	battle.camera.reset_smoothing()
	battle.camera.force_update_scroll()
	for id in ["ORCA", "BEAG"]:
		var planes: Array = []
		for slot in 4:
			var plane = battle.spawn_unit(id, "ally", Vector2(1100, 1300))
			activate(plane)
			plane.hull_angle = 0.0
			plane.logistics.assign_producer(base)
			planes.append(plane)
			check(plane.logistics.dock_slot == slot, mode + id + " reserves unique slot " + str(slot))
		for health in [1.0, 0.3]:
			base.hp = base.max_hp * health
			base.queue_redraw()
			for slot in 4:
				var plane = planes[slot]
				plane.logistics.tick_return(0.1)
				check_on_pad(base, plane, slot, mode + id + " grounded health=" + str(health))
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			stage.get_texture().get_image().save_png(output_dir.path_join("%s-%s-pads-%d.png" % [mode, id, int(health * 100)]))
		base.hp = base.max_hp
		# An already parked legacy save must realign without launching a sortie.
		var returning = planes[0]
		returning.position = base.position + Vector2(-22, -22)
		returning.logistics.tick_return(0.1)
		check(returning.logistics.air_state == "parked" and returning.logistics.air_lift == 0.0, mode + id + " legacy parked point corrects without taking off")
		check_on_pad(base, returning, 0, mode + id + " legacy parking")
		# Real flight back from four approach directions must finish exactly on the pad.
		for direction in 4:
			returning.position = base.position + Vector2.from_angle(direction * PI / 2.0) * 420.0
			returning.logistics.air_state = "returning"
			returning.logistics.air_lift = 1.0
			for tick in 2400:
				returning._physics_process(1.0 / 60.0)
				if tick % 30 == 0: await get_tree().physics_frame
				if returning.logistics.air_state == "parked": break
			check(returning.logistics.air_state == "parked", mode + id + " return lands from direction " + str(direction))
			check(returning.get_collision_exceptions().is_empty(), mode + id + " overhead landing leaves no collision exceptions")
			check_on_pad(base, returning, 0, mode + id + " returned direction=" + str(direction))
		for plane in planes: remove_actor(plane)
	screen.free()
	await get_tree().process_frame

func check_on_pad(base, plane, slot: int, label: String) -> void:
	var frame: int = plane._sprite_facing(plane._ra2, plane.hull_angle)
	var origin: Array = plane._weapon_art.origins[frame]
	var rect := RA2Art.draw_rect(plane._ra2, plane.radius, range(32), plane._visual_lift(), plane.RA2_SPRITE_SCALE)
	var actual: Vector2 = Iso.dir(plane.position - base.position) + rect.position + Vector2(origin[0], origin[1]) * plane.RA2_SPRITE_SCALE
	var anchor := RA2Art.anchor(base._ra2, [base._body_damage_frame()])
	var expected: Vector2 = Vector2(-anchor.x, base.radius * 0.35 - anchor.y) + PAD_PIXELS[slot]
	check(actual.distance_to(expected) <= 1.0, label + " projected model origin matches painted pad " + str(slot), {"actual": str(actual), "expected": str(expected)})
