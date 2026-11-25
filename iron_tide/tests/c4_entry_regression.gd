extends "res://tests/logistics_regression.gd"

func capture_target(target, name: String) -> int:
	if DisplayServer.get_name() == "headless": return 0
	target.queue_redraw()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var picture := stage.get_texture().get_image()
	picture.save_png(output_dir.path_join(name + ".png"))
	var center: Vector2 = battle.hp_overlay.get_global_transform_with_canvas() * battle.hp_overlay.to_local(target.position)
	var area := picture.get_region(Rect2i(Vector2i(center) - Vector2i(170, 230), Vector2i(340, 240)))
	var red := 0
	for y in area.get_height():
		for x in area.get_width():
			var color := area.get_pixel(x, y)
			if color.r > 0.35 and color.r > color.g * 1.8 and color.r > color.b * 1.8: red += 1
	return red

func advance_seal(seal, target, exiting := false) -> void:
	for tick in 600:
		seal._physics_process(1.0 / 60.0)
		if exiting:
			if not seal.special.has("action"): return
		elif target.special.has("c4_left"): return

func exercise_mode(mode: String) -> void:
	for unit_id in ["GHOST", "TANY"]:
		await exercise_commando(mode, unit_id)
		await factory_approaches(mode, unit_id)

func factory_approaches(mode: String, unit_id: String) -> void:
	setup_logistics_scene(mode, "美国")
	for group in ["obstacles", "resource_nodes"]:
		for node in get_tree().get_nodes_in_group(group): node.free()
	for actor in battle.units + battle.buildings: actor.free()
	battle.units.clear()
	battle.buildings.clear()
	battle.water_rects = []
	battle.path_service.set_water([])
	battle._refresh_pathing()
	if battle.fog != null:
		battle.fog.free()
		battle.fog = null
	var target = battle._place_building("GAWEAP", "enemy", Vector2(1600,1600), true)
	target._buildup_play = -1.0
	for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		var tag := "%s %s factory from %s: " % [mode, unit_id, direction]
		var unit = battle.spawn_unit(unit_id, "ally", target.position + direction * 300.0)
		activate(unit)
		await get_tree().physics_frame
		battle.select_unit(unit, false)
		battle._issue_order(target.position)
		check(unit.attack_target == target, tag + "right-click acquired building")
		await advance_seal(unit, target)
		check(target.special.has("c4_left") and Geometry2D.is_point_in_polygon(unit.position - target.position, target.footprint_poly()), tag + "crossed foundation and planted")
		await advance_seal(unit, target, true)
		check(not Geometry2D.is_point_in_polygon(unit.position - target.position, target.footprint_poly()), tag + "left foundation")
		# Reset the charge between independent approaches; exercise_commando tests its fuse.
		target.special.erase("c4_left")
		target.special.erase("c4_owner")
		battle.clear_selection()
		remove_actor(unit)
	screen.free()
	await get_tree().process_frame


func exercise_commando(mode: String, unit_id: String) -> void:
	setup_logistics_scene(mode, "美国")
	battle.water_rects = []
	battle.path_service.set_water([])
	battle._refresh_pathing()
	var tag := mode + " " + unit_id + " C4: "
	var target = battle._place_building("GAPOWR", "enemy", Vector2(2300, 2300), true)
	target._buildup_play = -1.0
	var neighbor = battle._place_building("GAPOWR", "enemy", Vector2(2700, 2300), true)
	neighbor._buildup_play = -1.0
	var seal = battle.spawn_unit(unit_id, "ally", Vector2(2500, 2300))
	activate(seal)
	var engineer = battle.spawn_unit("ENGINEER", "enemy", Vector2(2300, 2500))
	activate(engineer)
	battle.camera.position = target.position
	Iso.apply_to(battle.camera, 1.5)
	battle.camera.reset_smoothing()
	battle.camera.force_update_scroll()
	await get_tree().physics_frame
	var original: Material = target.material
	var neighbor_material: Material = neighbor.material
	var normal := await capture_target(target, mode + "-" + unit_id + "-c4-normal")
	battle.select_unit(seal, false)
	battle.force_attack(target)
	seal._physics_process(1.0 / 60.0)
	check(not target.special.has("c4_left"), tag + "attack command cannot plant remotely")
	await advance_seal(seal, target)
	check(target.special.has("c4_left") and Geometry2D.is_point_in_polygon(seal.position - target.position, target.footprint_poly()),
		tag + "actual movement crosses target foundation before arming")
	check(is_equal_approx(float(target.special.get("c4_left", 0.0)), 1.8), tag + "original 0.03-minute delay is 1.8 seconds")
	check(not seal._dead and seal.embarked_in == null and seal.hp > 0, tag + "saboteur survives and is not garrisoned or consumed")
	check(seal.get_collision_exceptions().is_empty(), tag + "entry leaves no persistent collision exception")
	target._process(0.05)
	var strong := await capture_target(target, mode + "-" + unit_id + "-c4-red")
	if DisplayServer.get_name() != "headless":
		check(strong > normal + 250, tag + "real building sprite flashes red", [normal, strong])
	check(neighbor.material == neighbor_material and target.material != original, tag + "red material does not contaminate shared house color")
	target._process(0.125)
	var dim := await capture_target(target, mode + "-" + unit_id + "-c4-pulse-low")
	if DisplayServer.get_name() != "headless":
		check(dim < strong - 250, tag + "real countdown drives alternating red intensity", [strong, dim])
	await advance_seal(seal, target, true)
	check(not Geometry2D.is_point_in_polygon(seal.position - target.position, target.footprint_poly()) and seal.get_collision_exceptions().is_empty(),
		tag + "soldier exits foundation after arming")
	var remaining: float = target.special.c4_left
	check(not AlliedAbilities.use(seal, "allied_c4", target) and target.special.c4_left == remaining,
		tag + "duplicate planting cannot reset the running fuse")
	engineer.position = AlliedAbilities.approach(engineer, target)
	check(AlliedAbilities.use(engineer, "allied_engineer", target), tag + "engineer accepts disarm")
	engineer._physics_process(0.1)
	check(not target.special.has("c4_left") and target.material == original and not engineer._dead, tag + "disarm immediately restores original material")
	check(not target._dead, tag + "disarm preserves building")
	# Abort while entering: no charge, no leaked pass-through, no trapped actor.
	seal.position = AlliedAbilities.approach(seal, target)
	AlliedAbilities.use(seal, "allied_c4", target)
	seal._physics_process(0.01)
	check(seal.special.get("c4_stage") == "enter", tag + "entry is a real intermediate state")
	seal.order_stop()
	check(not target.special.has("c4_left") and not seal.special.has("c4_stage") and seal.get_collision_exceptions().is_empty(), tag + "stop cancels entry without planting")
	check(not Geometry2D.is_point_in_polygon(seal.position - target.position, target.footprint_poly()), tag + "stop leaves soldier outside foundation")
	# Disk round-trip while entering uses the existing saved special-state schema.
	AlliedAbilities.use(seal, "allied_c4", target)
	seal._physics_process(0.01)
	var saved := BattleSaves.save_slot(battle, "quick")
	check(saved.ok, tag + "entry saves through actual disk slot", saved)
	var loaded := BattleSaves.read_slot("quick")
	check(loaded.ok, tag + "entry save passes schema and checksum")
	if loaded.ok:
		BattleSaves.Snapshot.new().restore(battle, loaded.snapshot)
		seal = battle.units.filter(func(u): return u.unit_id == unit_id)[0]
		target = seal.special.target
		activate(seal, false)
		await get_tree().physics_frame
		check(seal.special.get("c4_stage") == "enter", tag + "load retains entry phase and building reference")
		await advance_seal(seal, target)
		check(target.special.has("c4_left"), tag + "restored entry completes planting")
		saved = BattleSaves.save_slot(battle, "quick")
		loaded = BattleSaves.read_slot("quick")
		check(saved.ok and loaded.ok, tag + "planted exit phase round-trips to disk")
		if loaded.ok:
			BattleSaves.Snapshot.new().restore(battle, loaded.snapshot)
			seal = battle.units.filter(func(u): return u.unit_id == unit_id)[0]
			target = seal.special.target
			activate(seal, false)
			await get_tree().physics_frame
			target._process(0.0)
			check(target.material is ShaderMaterial and target.material.get_shader_parameter("c4_flash") > 0.0, tag + "loaded charge reconstructs red flash")
			await advance_seal(seal, target, true)
			var experience: float = seal._vet_kills
			target._process(1.79)
			check(not target._dead, tag + "building survives before original deadline")
			target._process(0.02)
			check(target._dead and seal.hp > 0 and seal._vet_kills > experience, tag + "deadline destroys building and credits surviving planter")
	screen.free()
	await get_tree().process_frame
