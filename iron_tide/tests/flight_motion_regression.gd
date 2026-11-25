extends "res://tests/logistics_regression.gd"

func exercise_mode(mode: String) -> void:
	setup_logistics_scene(mode, "美国")
	var ids: Array = []
	for id in GameData.unit_index:
		if GameData.get_unit(id).get("tags", []).has("air"): ids.append(id)
	ids.sort()
	check(ids.has("ORCA") and ids.has("BEAG") and ids.has("SHAD") and ids.has("JUMPJET") and ids.has("HORNET"), mode + ": audit covers current allied air roster", ids)
	for id in ids:
		if GameData._ra2_flag(GameData.ra2_source_units.get(id, {}).get("extra", {}).get("MissileSpawn", false)):
			exercise_payload(mode, id)
		else:
			await exercise_flight(mode, str(id))
	await exercise_hover_attack(mode)
	await exercise_jetpack_sway(mode)
	await exercise_jetpack_sequences(mode)
	await exercise_production_takeoff(mode)
	await exercise_takeoff(mode)
	screen.free()
	await get_tree().process_frame

# Spawned missiles have a launch rail and an impact point, not move/land orders.
func exercise_payload(mode: String, id: String) -> void:
	var origin := Vector2(2100,1800)
	var launcher = battle.spawn_unit("V3","ally",origin)
	var target = battle.spawn_unit("MTNK","enemy",origin+Vector2(500,0))
	preload("res://scripts/units/soviet_advanced.gd").launch(launcher,target)
	var shots: Array = battle.units.filter(func(u): return is_instance_valid(u) and u.unit_id == id)
	check(shots.size() == 1, mode + " launch creates one payload")
	if shots.size() == 1:
		var shot = shots[0]
		shot._physics_process(float(launcher.data.rocket.windup))
		check(shot.position == origin and shot._visual_lift() > 0, mode + " missile rises from launch rail")
		shot._physics_process(float(shot.special.flight.duration) * 0.5)
		check(shot.position.is_equal_approx(origin.lerp(target.position,0.5)) and shot._visual_lift() > 16, mode + " missile advances aloft")
		shot._physics_process(float(shot.special.flight.duration))
		check(shot.is_queued_for_deletion() and target.hp < target.max_hp, mode + " missile ends at ground impact")
		battle.units.erase(shot)
	remove_actor(launcher)
	remove_actor(target)

func exercise_flight(mode: String, id: String) -> void:
	var prefix := mode + " " + id + ": "
	var unit = battle.spawn_unit(id, "ally", Vector2(2100, 1800))
	activate(unit)
	unit.fire_stance = "none"
	unit._think_timer = 10000.0
	unit.hull_angle = 0.0
	unit.logistics.air_lift = 1.0
	await get_tree().physics_frame
	if id in ["ORCA", "BEAG", "HORNET"]:
		check(not unit.flight.jumpjet and unit.flight.height == 1500.0, prefix + "YR General FlightLevel 1500")
	if id in ["SHAD", "JUMPJET"]:
		check(unit.flight.jumpjet and unit.flight.height == 500.0, prefix + "YR JumpjetHeight 500")
		check(is_equal_approx(unit.flight.horizontal_speed, 30.0 * 15.0 * 55.0 / 256.0), prefix + "JumpjetSpeed 30 has independent lepton conversion")
	if id == "JUMPJET":
		check(absf(unit._visual_lift() - 500.0 * 30.0 / 256.0) <= 2.5001, prefix + "visual sway stays within 2.5 pixels of source cruise height")
	else:
		check(is_equal_approx(unit._visual_lift(), unit.flight.height * 30.0 / 256.0) or not unit.flight.no_wobbles, prefix + "source altitude replaces model-radius height")
	var goal := Vector2(1450, 1950)
	unit.order_move(goal)
	var bounded := true
	var aligned := true
	var peaked := 0.0
	var previous: float = unit.hull_angle
	for tick in 2400:
		unit._physics_process(1.0 / 60.0)
		bounded = bounded and absf(angle_difference(previous, unit.hull_angle)) <= unit.flight.turn_rate / 60.0 + 0.0001
		previous = unit.hull_angle
		if unit.velocity.length() > 1.0:
			aligned = aligned and absf(angle_difference(unit.velocity.angle(), unit.hull_angle)) < 0.01
		peaked = maxf(peaked, unit.velocity.length())
		if not unit.has_move_order: break
	check(bounded, prefix + "yaw remains within source locomotor turn rate")
	check(aligned, prefix + "trajectory follows actual nose through turn, no side sliding")
	check(peaked <= unit.flight.max_speed() + 0.01, prefix + "speed capped by locomotor and buffs")
	if id=="R3HARBINGER":
		check(not unit.has_move_order and unit.position.distance_to(goal)<=447.01, prefix+"fixed-wing destination joins native holding circle",str(unit.position))
	else:
		check(not unit.has_move_order and unit.position.distance_to(goal) <= 8.0, prefix + "reversed flight order converges without endless orbit", str(unit.position))
	for tick in 400: unit._physics_process(1.0 / 60.0)
	if unit.flight.balloon:
		check(unit.logistics.air_lift > 0.95, prefix + "BalloonHover stays airborne when idle")
	elif unit.flight.can_land():
		check(unit.logistics.air_lift < 0.01, prefix + "landable aircraft descends at legal idle destination")
	unit.logistics.air_lift = 1.0
	unit.queue_redraw()
	battle.camera.position = unit.position
	battle.camera.zoom = Vector2(1.0, 0.5)
	battle.camera.reset_smoothing()
	battle.camera.force_update_scroll()
	battle._update_depth_order()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	check(unit.z_index == DepthLayers.AIR, prefix + "airborne sprite clears ground depth band")
	check(is_equal_approx(unit._art_lift, unit._visual_lift()) or unit._ra2.is_empty(), prefix + "drawing and click geometry use identical height")
	if not unit._ra2.is_empty():
		var hits := 0
		var center: Vector2 = unit.art_center()
		for x in range(-20, 21, 4):
			for y in range(-20, 21, 4):
				if unit.hit_test(center + RA2Art.art_dir(Vector2(x, y))): hits += 1
		check(hits > 0, prefix + "elevated visible sprite remains selectable")
	if id in ["ORCA", "SHAD", "JUMPJET"]:
		stage.get_texture().get_image().save_png(output_dir.path_join(mode + "-" + id + "-altitude.png"))
	if id in ["ORCA", "BEAG", "SHAD", "HORNET"]:
		check(unit._ra2.facings == 32 and unit._ra2_shd.facings == 32, prefix + "body and shadow rebaked to 32 source-model headings")
		if id == "SHAD":
			var complete := int(unit._ra2.get("poses", 1)) == 2
			for frame in 64:
				for art in [unit._ra2, unit._ra2_shd]:
					var pixels: Image = art.tex.get_image()
					var rect: Rect2 = RA2Art.src_rect(art, frame)
					complete = complete and Rect2(Vector2.ZERO, Vector2(pixels.get_size())).encloses(rect) and not pixels.get_region(rect).is_invisible()
			check(complete, prefix + "two original HVA rotor poses times 32 headings present in body and shadow")
		if not unit._weapon_art.is_empty():
			check(unit._weapon_art.muzzles.size() == 32, prefix + "all heading-specific weapon emitters rebuilt")
		var visible := true
		var elevated := true
		for facing in 32:
			unit.hull_angle = float(facing) * TAU / 32.0
			unit.turret_angle = unit.hull_angle
			unit.aim_dir = Vector2.from_angle(unit.hull_angle)
			unit.queue_redraw()
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var pixels: Image = unit._ra2.img
			visible = visible and not pixels.get_region(RA2Art.src_rect(unit._ra2, unit._art_frame)).is_invisible()
			elevated = elevated and Iso.dir(unit._weapon_muzzle() - unit.position).y < -unit._visual_lift() + unit.radius * 2.0
		check(visible, prefix + "all 32 rendered frames contain the real model")
		check(elevated, prefix + "muzzle stays at aircraft height across all headings")
	remove_actor(unit)
	await get_tree().process_frame

func exercise_jetpack_sway(mode: String) -> void:
	var unit = battle.spawn_unit("JUMPJET", "ally", Vector2(2200, 1800))
	activate(unit)
	unit.order_stop()
	unit.fire_stance = "none"
	unit._think_timer = 10000.0
	unit._seed = 0
	unit._anim = 0.0
	unit.logistics.air_lift = 1.0
	var start: Vector2 = unit.position
	var low := INF
	var high := -INF
	for tick in 144:
		unit._physics_process(1.0 / 60.0)
		low = minf(low, unit._visual_lift())
		high = maxf(high, unit._visual_lift())
	check(high - low > 4.9 and high - low < 5.1, mode + ": jetpack idle visibly floats over real animation ticks")
	check(unit.position == start and unit.logistics.air_lift == 1.0 and unit.flight.height == 500.0 and not unit.has_move_order, mode + ": visual sway preserves position flight height and orders")
	var cruise := 500.0 * 30.0 / 256.0
	unit._anim = 0.6
	check(is_equal_approx(unit._visual_lift(), cruise + 2.5), mode + ": idle peak uses slow 2.4 second cycle")
	unit.velocity = Vector2.RIGHT * unit.flight.max_speed()
	check(is_equal_approx(unit._visual_lift(), cruise + 0.8), mode + ": moving jetpack reduces float amplitude")
	unit.velocity = Vector2.ZERO
	unit.logistics.air_lift = 0.0
	check(is_zero_approx(unit._visual_lift()), mode + ": grounded jetpack has no floating offset")
	unit.logistics.air_lift = 1.0
	unit._seed = 249
	check(absf(unit._visual_lift() - (cruise + 2.5)) > 2.4, mode + ": different unit phases avoid synchronized bobbing")
	unit._seed = 0
	battle.camera.position = unit.position
	Iso.apply_to(battle.camera, 2.0)
	battle.camera.reset_smoothing()
	battle.camera.force_update_scroll()
	var centers: Array[Vector2] = []
	for time in [0.6, 1.8]:
		unit._anim = time
		unit.queue_redraw()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		centers.append(unit.art_center())
		check(is_equal_approx(unit._art_lift, unit._visual_lift()), mode + ": animated render and picking use same hover offset")
		stage.get_texture().get_image().save_png(output_dir.path_join("%s-jetpack-sway-%s.png" % [mode, time]))
	check(absf(Iso.dir(centers[0] - centers[1]).y) > 4.9, mode + ": visible body moves vertically across hover cycle")
	remove_actor(unit)
	await get_tree().process_frame

func exercise_jetpack_sequences(mode: String) -> void:
	var unit = battle.spawn_unit("JUMPJET", "ally", Vector2(2200, 1800))
	activate(unit)
	unit.fire_stance = "none"
	battle.camera.position = unit.position
	Iso.apply_to(battle.camera, 3.0)
	battle.camera.reset_smoothing()
	battle.camera.force_update_scroll()
	# Independent source expectations: installed artmd.ini [RocketeerSequence].
	for state in ["air_idle", "air_move", "air_fire", "ground_idle", "ground_move", "ground_fire"]:
		unit.logistics.air_lift = 1.0 if state.begins_with("air") else 0.0
		unit.velocity = Vector2(40, 0) if state.ends_with("move") else Vector2.ZERO
		unit.has_move_order = state.ends_with("move")
		unit._muzzle = 0.0
		for direction in 8:
			unit.hull_angle = TAU * float(direction) / 8.0
			var facing := RA2Art.facing_index(unit.hull_angle, 8)
			for time in [0.0, 0.125, 0.3]:
				unit._anim = time
				unit._walk_phase = time
				unit._fire_anim_time = time if state.ends_with("fire") else -1.0
				unit.queue_redraw()
				await get_tree().process_frame
				await RenderingServer.frame_post_draw
				var expected := 0
				match state:
					"air_idle", "air_move": expected = 292 + facing * 6 + posmod(int(time * 14.0 + 0.00001), 6)
					"air_fire": expected = 370 + facing * 6 + posmod(int(time * 16.0 + 0.00001), 6)
					"ground_idle": expected = facing
					"ground_move": expected = 8 + facing * 6 + int(time * 6.0)
					"ground_fire": expected = 164 + facing * 6 + posmod(int(time * 16.0 + 0.00001), 6)
				check(unit._art_frame == expected, mode + " rocketeer " + state + " actual render frame " + str(direction) + "/" + str(time), unit._art_frame)
				check(is_equal_approx(unit._art_lift, unit._visual_lift()), mode + " rocketeer state preserves lift/picking anchor")
				if direction == 0 and time == 0.125:
					stage.get_texture().get_image().save_png(output_dir.path_join(mode + "-rocketeer-" + state + ".png"))
	# Use the real firing entry, not only an injected animation clock.
	unit.logistics.air_lift = 1.0
	unit.has_move_order = false
	unit.velocity = Vector2.ZERO
	var target = battle.spawn_unit("E1", "enemy", unit.position + Vector2(100, 0))
	activate(target)
	unit._fire_shot(target)
	check(unit._fire_sequence() == "FireFly" and unit._fire_anim_time == 0.0, mode + " real airborne shot starts FireFly")
	unit._think_timer = 10000.0
	unit.attack_target = null
	unit._physics_process(0.5)
	unit.queue_redraw()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	check(unit._fire_anim_time < 0.0 and unit._art_frame >= 292 and unit._art_frame < 340, mode + " shot completion returns to airborne hover")
	remove_actor(target)
	remove_actor(unit)
	await get_tree().process_frame

func exercise_hover_attack(mode: String) -> void:
	for id in ["SHAD", "JUMPJET"]:
		var unit = battle.spawn_unit(id, "ally", Vector2(2200, 1800))
		var target = battle.spawn_unit("E1", "enemy", Vector2(2300, 1800))
		activate(unit)
		activate(target)
		unit.hull_angle = PI
		unit.turret_angle = PI
		unit._think_timer = 10000.0
		unit.attack_target = target
		unit.attack_ordered = true
		unit.logistics.air_lift = 1.0
		target.hp = 10000.0
		await get_tree().physics_frame
		var holder: Node = unit._pick_projectile_parent()
		var before: Array = holder.get_children()
		unit._physics_process(1.0 / 60.0)
		check(unit._cd_timer <= 0.0, mode + " " + id + ": turn to target before firing")
		for tick in 600:
			unit._physics_process(1.0 / 60.0)
			if unit._cd_timer > 0.0: break
		check(unit._cd_timer > 0.0 and unit.logistics.air_lift > 0.95, mode + " " + id + ": hover attack fires through real weapon entry")
		check(absf(angle_difference(unit.hull_angle, unit.position.direction_to(target.position).angle())) <= deg_to_rad(2.0), mode + " " + id + ": actual hull faces fired target")
		for shot in holder.get_children():
			if shot is Projectile and not before.has(shot): shot.free()
		remove_actor(unit)
		remove_actor(target)
		await get_tree().process_frame

func exercise_production_takeoff(mode: String) -> void:
	var base = airport("ally", Vector2(2200, 2400))
	var plane = battle.spawn_unit("ORCA", "ally", Vector2(2300, 2400), base)
	activate(plane, false)
	check(plane.logistics.air_lift == 0.0 and plane.logistics.air_state == "parked" and plane.position == plane.logistics.dock_destination(), mode + ": production creates grounded aircraft at reserved dock")
	var start: Vector2 = plane.position
	plane.order_move(Vector2(2600, 2400))
	for tick in 30: plane._physics_process(1.0 / 60.0)
	check(plane.position == start and plane.logistics.air_lift > 0.0 and not plane.logistics.can_start_volley(), mode + ": parked aircraft takes off vertically before departure")
	remove_actor(plane)
	battle.buildings.erase(base)
	base.free()
	battle._refresh_pathing()
	await get_tree().process_frame

func exercise_takeoff(mode: String) -> void:
	var unit = battle.spawn_unit("SHAD", "ally", Vector2(2150, 1950))
	activate(unit)
	unit.fire_stance = "none"
	unit.logistics.air_lift = 0.0
	unit.order_move(Vector2(2450, 1950))
	var initial: Vector2 = unit.position
	for tick in 30: unit._physics_process(1.0 / 60.0)
	check(unit.position == initial and unit.logistics.air_lift > 0.0 and unit.logistics.air_lift < 0.95, mode + ": helicopter climbs before translation")
	check(not unit.logistics.can_start_volley(), mode + ": cannot fire while taking off")
	var saved := BattleSaves.save_slot(battle, "slot1")
	var loaded := BattleSaves.read_slot("slot1")
	check(saved.ok and loaded.ok, mode + ": in-flight state saves through real disk entry")
	var before: float = unit.logistics.air_lift
	if loaded.ok:
		preload("res://scripts/save/battle_snapshot.gd").new().restore(battle, loaded.snapshot)
		unit = battle.units.filter(func(u): return u.unit_id == "SHAD" and u.has_move_order)[0]
		activate(unit, false)
		check(unit.flight.jumpjet and unit.flight.height == 500.0 and is_equal_approx(unit.logistics.air_lift, before), mode + ": restore rebuilds flight profile and preserves ascent")
		for tick in 1800:
			unit._physics_process(1.0 / 60.0)
			if not unit.has_move_order: break
		check(unit.position.distance_to(Vector2(2450, 1950)) <= 8.0, mode + ": restored takeoff continues to destination")
