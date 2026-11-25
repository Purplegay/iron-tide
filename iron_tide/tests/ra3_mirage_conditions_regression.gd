extends "res://tests/allied_abilities_regression.gd"

const MirageDamageVisual = preload("res://scripts/units/ra3_mirage_damage_visual.gd")
const ExpansionDamageState = preload("res://scripts/units/ra3_damage_state.gd")

func exercise_mode(mode: String) -> void:
	if mode == MatchRules.RA2: return
	setup_logistics_scene(mode, "美国")
	for node in battle.units + battle.buildings: node.free()
	battle.units.clear(); battle.buildings.clear()
	if battle.fog != null: battle.fog.free(); battle.fog = null
	var tank = actor(Ra3Mirage.ID, "ally", Vector2(1800, 1800))
	var peer = actor(Ra3Mirage.ID, "ally", Vector2(1920, 1800))
	var ra2 = actor("MTNK", "ally", Vector2(2000, 1800))
	check(MirageDamageVisual.smoke_birth_fade(0.0) == 0.0 and MirageDamageVisual.smoke_birth_fade(1.5) > 0.0 and MirageDamageVisual.smoke_birth_fade(3.0) == 1.0, "native smoke particles fade in without popping")
	check(is_equal_approx(ExpansionDamageState.smoke_scale_for("R3HARBINGER"), 0.08) and is_equal_approx(ExpansionDamageState.smoke_scale_for("R3FUTURE"), 0.24) and is_equal_approx(ExpansionDamageState.smoke_scale_for("R3TESLA"), 0.24), "gunship smoke is smaller without changing tank smoke scale")
	var ra2_mirage = actor("MGTK", "ally", Vector2(2100, 1800))
	var tree_before_move: String = AlliedAbilities.disguise_visual(ra2_mirage).art.key
	ra2_mirage.order_move(ra2_mirage.position + Vector2.RIGHT * 80)
	AlliedAbilities.tick_actor(ra2_mirage, 0.1)
	ra2_mirage.order_stop()
	AlliedAbilities.tick_actor(ra2_mirage, 0.1)
	check(AlliedAbilities.disguise_visual(ra2_mirage).art.key == tree_before_move, "RA2 mirage retains its tree after moving and stopping")
	ra2_mirage.special.reveal = 2.0
	AlliedAbilities.tick_actor(ra2_mirage, 0.1)
	check(ra2_mirage.special.get("mirage_tree", "") == tree_before_move, "RA2 mirage retains its tree while revealed")
	ra2_mirage.special.reveal = 0.0
	AlliedAbilities.tick_actor(ra2_mirage, 0.1)
	check(AlliedAbilities.disguise_visual(ra2_mirage).art.key == tree_before_move, "RA2 mirage reuses the same tree after reveal ends")
	for row in [[1.0, 0], [0.67, 0], [0.66, 1], [0.34, 1], [0.33, 2], [0.01, 2], [0.0, 0]]:
		tank.hp = tank.max_hp * row[0]
		check(Ra3Mirage.damage_state(tank) == row[1], "native damage state at " + str(row[0]))
		tank._spd_cur = 0.0
		var factor := 0.75 if row[1] > 0 else 1.0
		check(is_equal_approx(tank._ramped_speed(5.0), tank.move_speed * factor), "real movement consumes damage speed at " + str(row[0]))
	check(is_equal_approx(ra2._ramped_speed(5.0), ra2.move_speed), "RA2 movement unaffected")
	tank.hp = tank.max_hp * 0.2
	tank._grant_veteran(3, false)
	check(Ra3Mirage.damage_state(tank) == 2, "promotion scales damage threshold with max health")
	if DisplayServer.get_name() != "headless":
		await exercise_gunship_smoke()
		await exercise_visual(tank, peer)
	screen.free()
	await get_tree().process_frame

func exercise_gunship_smoke() -> void:
	var plane = actor("R3HARBINGER", "ally", Vector2(1700, 1700))
	var model = plane._ra3_model
	model.set_process(false)
	plane.hp = plane.max_hp * 0.5
	var visual = model.damage_state
	for i in 12: visual.tick(1.0 / 30.0)
	check(not visual.rows.is_empty(), "gunship emits real damage smoke")
	plane.position += Vector2(180, 100)
	plane.hull_angle += PI * 0.5
	visual.tick(0.0)
	var attached := true
	var scaled := true
	for row in visual.rows:
		var offset: Vector3 = row.velocity * row.age + row.offset
		var expected: Vector2 = Iso.dir(model.bone_world(row.bone) - plane.global_position) + model.project(offset) - model.project(Vector3.ZERO)
		attached = attached and row.sprite.position.is_equal_approx(expected)
		var native_size: float = maxf(0.01, row.size + row.rate * ExpansionDamageState.Particle.integral(row.age, row.damping))
		var diameter: float = row.sprite.scale.x * row.sprite.texture.get_width()
		scaled = scaled and is_equal_approx(diameter, native_size * 1.5 * 0.08)
	check(attached, "existing gunship smoke follows damage sockets after movement and turn")
	check(scaled, "actual gunship smoke diameter uses reduced scale")
	battle.camera.position = plane.position + RA2Art.art_dir(Vector2(0, -plane._visual_lift()))
	battle.camera.zoom = Iso.cam_zoom(2.0)
	for i in 3: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	stage.get_texture().get_image().save_png(output_dir.path_join("gunship-smoke-corrected.png"))
	remove_actor(plane)

func capture(model, name: String) -> Image:
	model.sync_pose(true)
	for i in 3: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var picture: Image = model.viewport.get_texture().get_image()
	picture.save_png(output_dir.path_join(name + ".png"))
	return picture

func exercise_visual(tank, peer) -> void:
	battle.camera.position = tank.position
	battle.camera.zoom = Iso.cam_zoom(2.0)
	tank.special.reveal = 60.0
	var model: Ra3UnitModel = tank._ra3_model
	model.animation.enabled = false
	model.set_process(false)
	model._suspended = false
	var visual = model.damage_visual
	visual.set_process(false)
	var tread: Texture2D = model._tread_material.get_shader_parameter("diffuse_map")
	tank.hp = tank.max_hp
	var normal := await capture(model, "mirage-healthy")
	tank.hp = tank.max_hp * 0.5
	visual._process(0.1)
	check(visual.active_systems() == ["VehicleDamageSmoke"] and not visual.rows.is_empty(), "DAMAGED emits smoke only")
	check(model._body_material.get_shader_parameter("diffuse_map") == visual.normal_texture, "DAMAGED keeps normal skin")
	tank.hp = tank.max_hp * 0.2
	visual._process(0.1)
	check(visual.active_systems().size() == 3, "REALLYDAMAGED enables smoke plus both fire layers")
	for system in visual.active_systems():
		check(visual.rows.any(func(r): return r.system == system), "native particle emitted: " + system)
	check(model._body_material.get_shader_parameter("diffuse_map") == visual.damaged_texture, "actual renderer uses damaged texture")
	check(model._tread_material.get_shader_parameter("diffuse_map") == tread, "body replacement preserves tread texture")
	check(peer._ra3_model._body_material.get_shader_parameter("diffuse_map") != visual.damaged_texture, "damage does not leak to healthy peer materials")
	var damaged := await capture(model, "mirage-damaged")
	var changed_pixels := 0
	for y in normal.get_height():
		for x in normal.get_width():
			var a := normal.get_pixel(x, y)
			var b := damaged.get_pixel(x, y)
			if a.a > 0.5 and absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) > 0.12:
				changed_pixels += 1
	check(changed_pixels > 200, "rendered damaged hull visibly differs", changed_pixels)
	for i in 12: visual._process(1.0 / 30.0)
	for i in 3: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	stage.get_texture().get_image().save_png(output_dir.path_join("mirage-damage-battle.png"))
	tank.special.reveal = 0.0
	tank.has_move_order = false
	tank.velocity = Vector2.ZERO
	visual._process(0.1)
	check(Ra3Mirage.disguised(tank) and visual.rows.is_empty(), "disguise suppresses damage particles")
	check(model._body_material.get_shader_parameter("diffuse_map") == visual.damaged_texture, "disguise retains damaged underlying hull")
	tank.special.reveal = 60.0
	visual._process(0.1)
	check(not visual.rows.is_empty(), "reveal resumes damage emitters")
	var age: float = visual.rows[0].age
	get_tree().paused = true
	visual._process(0.5)
	check(visual.rows[0].age == age, "pause freezes particle clock")
	get_tree().paused = false
	model._suspended = true
	visual._process(0.5)
	check(visual.rows.is_empty() and visual.clocks.is_empty(), "offscreen clears particles and emission backlog")
	model._suspended = false
	tank.heal(tank.max_hp)
	visual._process(0.1)
	check(visual.rows.is_empty() and visual.skin_state == 0, "repair clears damage effects")
	var repaired := await capture(model, "mirage-repaired")
	var max_difference := 0
	var normal_bytes := normal.get_data()
	var repaired_bytes := repaired.get_data()
	for i in normal_bytes.size(): max_difference = maxi(max_difference, absi(normal_bytes[i] - repaired_bytes[i]))
	check(model._body_material.get_shader_parameter("diffuse_map") == visual.normal_texture and max_difference <= 1, "repaired hull matches healthy render within one 8-bit quantization step", max_difference)
	tank.hp = tank.max_hp * 0.1
	for i in 60: visual._process(1.0 / 30.0)
	check(visual.rows.size() <= visual.MAX_PARTICLES, "persistent damage particles remain bounded")
	var saved := BattleSaves.save_slot(battle, "quick")
	var loaded := BattleSaves.read_slot("quick")
	check(saved.ok and loaded.ok, "damaged unit saves using existing schema")
	if loaded.ok:
		BattleSaves.Snapshot.new().restore(battle, loaded.snapshot)
		var restored = battle.units.filter(func(u): return u.unit_id == Ra3Mirage.ID and u.hp < u.max_hp * 0.2)[0]
		restored._ra3_model.sync_pose(true)
		check(restored._ra3_model.damage_visual.skin_state == 2, "load reconstructs damaged skin from saved HP")
