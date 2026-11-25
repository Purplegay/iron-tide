extends "res://tests/selection_regression.gd"

func exercise_mode(mode: String) -> void:
	BattleRequest.configure_skirmish(mode, {"map_size": 3200, "starting_funds": 10000})
	screen = load("res://scenes/battle.tscn").instantiate()
	stage.add_child(screen)
	battle = screen.battle
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	battle.power_low = false
	GM.god_mode = false
	GM.one_shot_kill = false
	battle.camera.position = Vector2(1600, 1600)
	battle.camera.zoom = Vector2(2, 1)
	battle.camera.reset_smoothing()
	battle.camera.force_update_scroll()
	for side in ["ally", "enemy"]:
		for id in ["GTGCAN", "NASAM"]:
			await exercise_weapon(mode, side, id)
	screen.free()
	await get_tree().process_frame

func exercise_weapon(mode: String, side: String, id: String) -> void:
	var prefix := "%s %s %s: " % [mode, side, id]
	var other := "enemy" if side == "ally" else "ally"
	var b = battle._place_building(id, side, Vector2(1600, 1600), true)
	var target = battle.spawn_unit("MTNK" if id == "GTGCAN" else "ORCA", other, Vector2(1600, 2000))
	var friendly = battle.spawn_unit("MTNK", side, target.position)
	for actor in [b, target, friendly]:
		actor.process_mode = Node.PROCESS_MODE_DISABLED
		actor.bonuses = {}
	b._buildup_play = -1.0
	b.attack_target = target
	b._think = 100.0
	b._cd = 0.0
	var holder: Node = get_tree().get_first_node_in_group("projectiles_root")
	var before := holder.get_children()
	var effects_before: Array = Effects._host().get_children()
	b._process(0.1)
	var shots := new_shots(holder, before)
	check(shots.is_empty() and b._cd == 0.0,
		prefix + "perpendicular target cannot consume cooldown or fire before turning", shots.size())
	var speed := 21.09375 if id == "GTGCAN" else 168.75
	check(is_equal_approx(b._turret_art.angle, deg_to_rad(speed * 0.1)),
		prefix + "turret advances at bounded speed without drawing", b._turret_art.angle)
	var previous: float = b._turret_art.angle
	var bounded := true
	for tick in 600:
		if not shots.is_empty():
			break
		b._process(1.0 / 60.0)
		bounded = bounded and absf(angle_difference(previous, b._turret_art.angle)) <= deg_to_rad(speed / 60.0) + 0.00001
		previous = b._turret_art.angle
		shots = new_shots(holder, before)
	check(bounded, prefix + "each real building tick respects rotation speed")
	check(shots.size() == 1 and b._cd == b.cooldown, prefix + "aligned turret fires once and starts normal cooldown")
	check(absf(angle_difference(b._turret_art.angle, PI / 2.0)) <= deg_to_rad(2.0),
		prefix + "first shot waits until within two degrees")
	check(target.hp == target.max_hp, prefix + "no damage before projectile flight")
	var muzzle: Vector2 = b._weapon_muzzle()
	for shot in shots:
		check(shot.global_position.distance_to(muzzle) < 0.001, prefix + "real projectile starts at model muzzle")
		shot.process_mode = Node.PROCESS_MODE_DISABLED
	if id == "GTGCAN":
		var flashes: Array = Effects._host().get_children().filter(func(node):
			return node is Ra2Fx and not effects_before.has(node) and str(node.anim.get("image", "")) == "GCMUZZLE")
		check(flashes.size() == 1, prefix + "real firing creates one original muzzle flash")
		for flash in flashes:
			check(flash.global_position.distance_to(muzzle) < 0.001, prefix + "flash and projectile share muzzle")
	b._process(0.01)
	check(new_shots(holder, before).size() == 1, prefix + "cooldown prevents duplicate projectile")
	await photograph(b, prefix.replace(" ", "-").replace(":", "") + "-firing")
	for shot in shots:
		for tick in 240:
			if shot.is_queued_for_deletion():
				break
			shot._physics_process(1.0 / 60.0)
		check(shot.is_queued_for_deletion(), prefix + "actual projectile reaches impact")
	check(target.max_hp - target.hp == (150.0 if id == "GTGCAN" else 75.0),
		prefix + "one impact applies unchanged weapon damage", target.max_hp - target.hp)
	check(friendly.hp == friendly.max_hp, prefix + "same-side unit at impact remains unharmed")
	for shot in shots:
		shot.free()
	# Power loss freezes both pose and weapon; target loss cannot spend readiness.
	b.attack_target = target
	b._cd = 1.0
	previous = b._turret_art.angle
	set_power_low(side, true)
	b._process(0.5)
	check(b._turret_art.angle == previous and b._cd == 1.0, prefix + "low power freezes aim and cooldown")
	set_power_low(side, false)
	set_power_low(other, true)
	check(b.is_operational(), prefix + "opposing side power shortage does not disable own turret")
	set_power_low(other, false)
	b._cd = 0.0
	for invalid_case in ["dead", "friendly", "range", "domain", "buildup"]:
		target.hp = target.max_hp
		target.side = other
		target.is_air = id == "NASAM"
		target.position = b.position + Vector2(400, 0)
		b._turret_art.angle = 0.0
		b._buildup_play = -1.0
		match invalid_case:
			"dead": target.hp = 0.0
			"friendly": target.side = side
			"range": target.position = b.position + Vector2(b.attack_range + 1.0, 0)
			"domain": target.is_air = id != "NASAM"
			"buildup": b._buildup_play = 0.0
		check(not b._fire() and new_shots(holder, before).is_empty() and b._cd == 0.0,
			prefix + "reject " + invalid_case + " without spawning or spending cooldown")
	b._buildup_play = -1.0
	target.hp = target.max_hp
	target.side = other
	target.is_air = id == "NASAM"
	if id == "GTGCAN":
		target.position = b.position + Vector2(164, 0)
		check(not b._fire(), prefix + "minimum range rejects point-blank fire")
	target.position = b.position + Vector2(400, 0)
	b._acquire_target()
	check(b.attack_target == target, prefix + "acquisition skips invalid domains and friendly actors")
	b.attack_target = null
	b._think = 100.0
	previous = b._turret_art.angle
	b._process(0.1)
	check(b._turret_art.angle == previous and b._cd == 0.0, prefix + "idle turret keeps heading and readiness")
	b.attack_target = target
	# 179 -> -179 degrees must take the short two-degree arc.
	b._turret_art.angle = deg_to_rad(179.0)
	target.position = b.position + Vector2.RIGHT.rotated(deg_to_rad(-179.0)) * 400.0
	b._cd = 10.0
	b._process(0.001)
	check(angle_difference(deg_to_rad(179.0), b._turret_art.angle) > 0.0
		and absf(angle_difference(deg_to_rad(179.0), b._turret_art.angle)) < deg_to_rad(1.0),
		prefix + "wraparound follows shortest turn")
	# Actual rendering cannot alter the authoritative heading.
	previous = b._turret_art.angle
	target.position = b.position + Vector2(0, -400)
	await photograph(b, prefix.replace(" ", "-").replace(":", "") + "-holding")
	check(b._turret_art.angle == previous, prefix + "redraw cannot snap aim toward new target")
	await check_muzzles(b, prefix)
	for actor in [target, friendly, b]:
		battle.units.erase(actor)
		battle.buildings.erase(actor)
		actor.free()
	for effect in Effects._host().get_children():
		if not effects_before.has(effect):
			effect.free()
	await get_tree().process_frame

func set_power_low(side: String, low: bool) -> void:
	if side == "ally":
		battle.power_low = low
	else:
		battle.enemy_power.low = low

func new_shots(holder: Node, before: Array) -> Array:
	return holder.get_children().filter(func(node): return node is Projectile and not before.has(node) and not node.is_queued_for_deletion())

func photograph(b, name: String) -> void:
	b.queue_redraw()
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		stage.get_texture().get_image().save_png(output_dir.path_join(name + ".png"))

func check_muzzles(b, prefix: String) -> void:
	# This suite checks the idle 32-direction anchors; recoil poses have their own suite.
	b._turret_art.advance_recoil(10.0)
	var metadata: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/ra2/bldturret/" + b.building_id + ".json"))
	var point: Array = metadata.muzzle_model_point
	check(point[0] > (70.0 if b.building_id == "GTGCAN" else 15.0),
		prefix + "muzzle is anchored to barrel/launcher front face")
	var seen := {}
	for health in [1.0, 0.3]:
		b.hp = b.max_hp * health
		for direction in 32:
			b._turret_art.angle = float(direction) * TAU / 32.0
			var frame: int = b._turret_art.facing()
			seen[frame] = true
			var az := PI / 4.0 - float(frame) * TAU / 32.0
			# Independent voxel projection, not the runtime muzzle helper.
			var projected := Vector2(-float(point[0]) * sin(az) + float(point[1]) * cos(az),
				0.5 * (float(point[0]) * cos(az) + float(point[1]) * sin(az)) - float(point[2]) * sqrt(3.0) / 2.0)
			var body := RA2Art.draw_rect(b._ra2, b.radius, [0 if health == 1.0 else 2])
			var expected := body.position + body.size * 0.5 + Vector2(metadata.offset[0], metadata.offset[1]) + projected
			var actual: Vector2 = Iso.dir(b._weapon_muzzle() - b.global_position)
			check(actual.distance_to(expected) < 0.01,
				prefix + "muzzle matches voxel projection hp=%s facing=%d" % [health, frame])
	check(seen.size() == 32, prefix + "all 32 facing anchors exercised")
