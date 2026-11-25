extends "res://tests/allied_abilities_regression.gd"

func exercise_mode(mode: String) -> void:
	if mode == MatchRules.RA2: return
	setup_logistics_scene(mode, "美国")
	for node in battle.units + battle.buildings: node.free()
	battle.units.clear(); battle.buildings.clear()
	if battle.fog != null: battle.fog.free(); battle.fog = null
	for entry in [["mirage", Ra3Mirage.ID, Ra3Wreck.ROOT, 11, 8.0, 5.0],
		["future", Ra3Expansion.FUTURE, "res://assets/ra3/expansion/future/", 9, 4.0, 3.0],
		["harbinger", Ra3Expansion.HARBINGER, "res://assets/ra3/expansion/harbinger/", 10, 4.0, 3.0]]:
		var profile: Dictionary = Ra3Wreck.dynamics[entry[0]]
		var geometry: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(entry[2] + "wreck.json"))
		check(profile.bodies.size() == entry[3] and profile.explodiness == entry[4] and profile.fling_perturbation == 15.0, entry[0] + " native body count and fling values")
		check(profile.min_lifetime == 4.0 and profile.max_lifetime == 5.0, entry[0] + " native random lifetime range")
		var a := RandomNumberGenerator.new()
		var b := RandomNumberGenerator.new()
		var c := RandomNumberGenerator.new()
		a.seed = 12345; b.seed = 12345; c.seed = 67890
		var repeatable := true
		var different := true
		var bounded := true
		for piece: Dictionary in geometry.pieces:
			var first := Ra3Wreck.sample_motion(profile, piece, Vector3.ZERO, a)
			var repeat := Ra3Wreck.sample_motion(profile, piece, Vector3.ZERO, b)
			var other := Ra3Wreck.sample_motion(profile, piece, Vector3.ZERO, c)
			repeatable = repeatable and first == repeat
			different = different and first.velocity != other.velocity and first.spin != other.spin
			bounded = bounded and first.flight_time > 0.0 and first.flight_time < 4.0 and first.velocity.is_finite() and first.spin.is_finite()
			check(profile.bodies[String(piece.name).to_upper()].spinniness == entry[5], entry[0] + " native spin " + piece.name)
		check(repeatable, entry[0] + " fixed seed reproduces cosmetic trajectories")
		check(different, entry[0] + " different deaths vary each piece velocity and spin")
		check(bounded, entry[0] + " finite motion settles before sinking")
		var zero: Dictionary = profile.duplicate(true)
		zero.fling_perturbation = 0.0; zero.explodiness = 0.0
		zero.bodies[String(geometry.pieces[0].name).to_upper()].spinniness = 0.0
		var no_fling := Ra3Wreck.sample_motion(zero, geometry.pieces[0], Vector3(3, 0, 5), a)
		check(no_fling.velocity == Vector3(3, 9, 5) and no_fling.spin == Vector3.ZERO, entry[0] + " zero native fields suppress fling and spin while inheriting motion")
		# Dedicated streams cannot change simulation random draws.
		seed(2541)
		var expected := randi()
		seed(2541)
		Ra3Wreck.sample_motion(profile, geometry.pieces[0], Vector3.ZERO, a)
		check(randi() == expected, entry[0] + " cosmetic sampling preserves global random sequence")
		if DisplayServer.get_name() != "headless":
			await exercise_render(entry, geometry)
	screen.free(); Music.stop(); Ra2Sfx.stop_all()
	await get_tree().process_frame

func exercise_render(entry: Array, geometry: Dictionary) -> void:
	var tank = actor(entry[1], "ally", Vector2(1800, 1800))
	var first := Ra3Wreck.spawn(tank)
	var second := Ra3Wreck.spawn(tank)
	check(first != null and second != null, entry[0] + " production spawn supports wreck")
	if first == null or second == null: return
	first.set_process(false); second.set_process(false)
	check(first.parts.size() == entry[3] and second.parts.size() == entry[3], entry[0] + " shared surfaces stay on one rigid piece")
	var surfaces := 0
	for part: Dictionary in first.parts: surfaces += part.node.get_child_count()
	check(surfaces == geometry.pieces.size(), entry[0] + " all native surfaces retained")
	check(first.parts[0].velocity != second.parts[0].velocity and first.parts[0].spin != second.parts[0].spin, entry[0] + " actual spawns randomize independently")
	check(first.death_age >= 4.0 and first.death_age <= 5.0, entry[0] + " actual spawn samples native lifetime")
	check(not first.is_in_group("combatants") and not first.is_in_group("obstacles"), entry[0] + " cosmetic pieces do not obstruct gameplay")
	var airborne := false
	for part: Dictionary in first.parts: airborne = airborne or part.flight_time > 1.05
	check(airborne, entry[0] + " flight not forcibly truncated to one second")
	for wreck: Ra3Wreck in [first, second]:
		for time in [0.6, 3.5]:
			wreck.age = time; wreck._process(0)
			var grounded := true
			for part: Dictionary in wreck.parts:
				var bounds: AABB = part.node.transform * part.bounds
				grounded = grounded and bounds.position.y >= 0.19
			check(grounded, entry[0] + " rotating geometry remains above ground at " + str(time))
			for frame in 3: await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var image := wreck.viewport.get_texture().get_image()
			var bounds := image.get_used_rect()
			check(bounds.has_area() and bounds.position.x > 1 and bounds.position.y > 1 and bounds.end.x < image.get_width() - 1 and bounds.end.y < image.get_height() - 1, entry[0] + " rendered scatter stays inside capture")
			image.save_png(output_dir.path_join(entry[0] + ("-a-" if wreck == first else "-b-") + str(time) + ".png"))
		wreck.age = 9.0; wreck._process(0)
		check(wreck.is_queued_for_deletion(), entry[0] + " lifetime cleanup preserved")
	await get_tree().process_frame
