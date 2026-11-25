extends "res://tests/unit_fire_regression.gd"

func exercise_mode(mode: String) -> void:
	BattleRequest.configure_skirmish(mode, {"map_size": 3200, "starting_funds": 10000})
	screen = load("res://scenes/battle.tscn").instantiate()
	stage.add_child(screen)
	battle = screen.battle
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	GM.god_mode = false
	GM.one_shot_kill = false
	battle.camera.position = Vector2(1600, 1600)
	battle.camera.zoom = Iso.cam_zoom(3.0)
	battle.camera.rotation = Iso.cam_angle()
	battle.camera.reset_smoothing()
	battle.camera.force_update_scroll()
	for side in ["ally", "enemy"]:
		for id in ["AEGIS", "DLPH"]:
			await check_targets(mode, side, id)
	await check_damage_particles(mode)
	await check_ship_facings(mode)
	await check_dolphin_frames(mode)
	screen.free()
	await get_tree().process_frame

func actor(id: String, side: String, pos: Vector2):
	var u = battle.spawn_unit(id, side, pos)
	u.order_stop()
	u.bonuses = {}
	u.process_mode = Node.PROCESS_MODE_DISABLED
	return u

func remove_actor(u) -> void:
	if is_instance_valid(u):
		battle.units.erase(u)
		u.free()

func check_targets(mode: String, side: String, id: String) -> void:
	var other := "enemy" if side == "ally" else "ally"
	var u = actor(id, side, Vector2(1600, 1600))
	var targets := [
		actor("MTNK", other, Vector2(1700, 1600)),
		actor("DEST", other, Vector2(1760, 1600)),
		actor("ORCA", other, Vector2(1820, 1600)),
		actor("ORCA", other, Vector2(1840, 1600))]
	targets[3].logistics.air_lift = 0.0
	u._refresh_target()
	var allowed = targets[2] if id == "AEGIS" else targets[1]
	check(u.attack_target == allowed, mode + side + id + ": acquisition ignores closer incompatible targets")
	var holder: Node = u._pick_projectile_parent()
	for target in targets:
		var valid: bool = target == allowed
		u.attack_target = target
		u.attack_ordered = true
		u._cd_timer = 0.0
		var before := holder.get_children()
		u._try_fire_ready()
		var shots := new_shots(holder, before)
		check((shots.size() == 1) if valid else (shots.is_empty() and u._cd_timer == 0.0),
			mode + side + id + ": explicit fire respects domain " + target.unit_id + " air=" + str(target.is_air_target()))
		if valid and not shots.is_empty():
			var initial: float = target.hp
			if id == "DLPH":
				check(shots[0].get("is_sonic") == true, mode + side + ": sonic projectile uses distinct wave presentation")
			for shot in shots:
				for tick in 600:
					if shot.is_queued_for_deletion():
						break
					shot._physics_process(1.0 / 60.0)
			check(target.hp < initial, mode + side + id + ": compatible target receives real projectile damage")
		for shot in shots:
			shot.free()
	for target in targets:
		remove_actor(target)
	remove_actor(u)
	await get_tree().process_frame

func draw_frame(u) -> void:
	u.queue_redraw()
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw

func check_damage_particles(mode: String) -> void:
	const Damage = preload("res://scripts/units/vehicle_damage_particles.gd")
	var camera_before: Vector2 = battle.camera.position
	var sea: Vector2 = battle.water_rects[0].get_center()
	battle.camera.position = sea
	battle.camera.reset_smoothing()
	battle.camera.force_update_scroll()
	for id in ["DEST", "AEGIS", "CARRIER", "LCRF", "DRED", "HYD", "SAPC", "SUB", "DLPH", "SQD"]:
		var ship = actor(id, "ally", sea)
		var emits: bool = id not in ["SUB", "DLPH", "SQD"]
		for threshold in [[0.51, 0], [0.5, 1], [0.251, 1], [0.25, 2]]:
			ship.hp = ship.max_hp * threshold[0]
			check(Damage.stage(ship) == (threshold[1] if emits else 0), mode + " " + id + " damage at " + str(threshold[0]))
		if id == "DRED" and DisplayServer.get_name() != "headless":
			ship.special.gm_stationary = true
			await draw_frame(ship)
			var renders := [0]
			ship.draw.connect(func(): renders[0] += 1)
			ship._physics_process(0.5)
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			check(renders[0] > 0 and ship._body_bounds.has_area(), mode + " damaged idle dreadnought redraws its deck without selection")
			stage.get_texture().get_image().save_png(output_dir.path_join(mode + "-damaged-dreadnought.png"))
		ship.heal(ship.max_hp)
		check(Damage.stage(ship) == 0, mode + " " + id + " repaired ship clears particles")
		remove_actor(ship)
	battle.camera.position = camera_before
	battle.camera.reset_smoothing()
	battle.camera.force_update_scroll()

func check_ship_facings(mode: String) -> void:
	check(DisplayServer.get_name() != "headless", mode + ": ships require renderer")
	if DisplayServer.get_name() == "headless": return
	for id in ["DEST", "AEGIS", "CARRIER", "LCRF"]:
		var u = actor(id, "ally", Vector2(1600, 1600))
		var shadow := RA2Art.art(id + "_shd")
		check(u._ra2.get("facings", 0) == 32 and shadow.get("facings", 0) == 32,
			mode + id + ": body and shadow contain 32 source-model facings")
		var unique: Dictionary = {}
		var frames: Dictionary = {}
		var anchor := RA2Art.anchor(u._ra2, range(32))
		var shadow_image: Image = shadow.tex.get_image()
		for frame in 32:
			# Same +X voxel heading convention used by the ground/aircraft renderer.
			var az := PI / 4.0 - frame * TAU / 32.0
			u.hull_angle = RA2Art.art_dir(Vector2(-sin(az), 0.5 * cos(az))).angle()
			await draw_frame(u)
			check(u._art_frame == frame, mode + id + ": hull aligns with projected model +X " + str(frame), u._art_frame)
			frames[u._art_frame] = true
			var src := RA2Art.src_rect(u._ra2, u._art_frame)
			var tile: Image = u._ra2.img.get_region(Rect2i(src))
			unique[hash(tile.get_data())] = true
			check(not tile.is_invisible() and not shadow_image.get_region(Rect2i(RA2Art.src_rect(shadow, u._art_frame))).is_invisible(),
				mode + id + ": body/shadow pixels " + str(frame))
			check(RA2Art.src_rect(shadow, u._art_frame).size == src.size and RA2Art.anchor(u._ra2, u._art_aframes) == anchor,
				mode + id + ": common canvas and stable anchor " + str(frame))
			check(pickable(u), mode + id + ": visible hull selectable " + str(frame))
		check(frames.size() == 32 and unique.size() == 32, mode + id + ": all 32 distinct rendered directions reached", [frames.size(), unique.size()])
		stage.get_texture().get_image().save_png(output_dir.path_join(mode + "-" + id + "-32.png"))
		remove_actor(u)

func check_dolphin_frames(mode: String) -> void:
	check(DisplayServer.get_name() != "headless", mode + ": frame assertions require actual renderer")
	if DisplayServer.get_name() == "headless":
		return
	var u = actor("DLPH", "ally", Vector2(1600, 1600))
	check(u._seq.size() >= 4, mode + ": dolphin action table loaded")
	for facing in 8:
		# SHP is N, NE, E, SE, S, SW, W, NW, unlike the voxel model +X convention.
		var heading := RA2Art.art_dir(Vector2.RIGHT.rotated(-PI / 2.0 + facing * TAU / 8.0)).angle()
		u.hull_angle = heading
		u.velocity = Vector2.ZERO
		u._muzzle = 0.0
		await draw_frame(u)
		check(u._art_frame == facing * 6 + posmod(int(u._anim * 15.0 / 8.0), 6), mode + ": idle swim facing " + str(facing))
		check(pickable(u), mode + ": idle visible pixels remain selectable")
		check_mouth(u, facing, mode)
		var anchor: Vector2 = RA2Art.anchor(u._ra2, u._art_aframes)
		for phase in 6:
			u.velocity = Vector2(40, 0)
			u._walk_phase = (float(phase) + 0.01) / 6.0
			await draw_frame(u)
			check(u._art_frame == facing * 6 + phase, mode + ": swimming frame %d:%d" % [facing, phase])
			check(RA2Art.anchor(u._ra2, u._art_aframes) == anchor, mode + ": swimming preserves idle anchor")
		check(pickable(u), mode + ": swimming visible pixels remain selectable")
	u.velocity = Vector2.ZERO
	u.hull_angle = RA2Art.art_dir(Vector2.UP).angle()
	var target = actor("DEST", "enemy", u.position + RA2Art.art_dir(Vector2(0, -130)))
	var holder: Node = u._pick_projectile_parent()
	var before := holder.get_children()
	u._anim = 19.7
	u._fire_shot(target)
	u._muzzle = 0.0 # The short muzzle flash must not truncate the six-frame action.
	for phase in 6:
		await draw_frame(u)
		check(u._art_frame == 56 + phase, mode + ": attack restarts and plays complete phase " + str(phase))
		if phase == 3:
			stage.get_texture().get_image().save_png(output_dir.path_join(mode + "-dolphin-firing.png"))
		u.decorate_tick(1.0 / 16.0)
	await draw_frame(u)
	check(u._art_frame == posmod(int(u._anim * 15.0 / 8.0), 6), mode + ": completed attack returns to idle swim cycle")
	for shot in new_shots(holder, before):
		shot.free()
	remove_actor(target)
	u._die()
	await draw_frame(u)
	check(is_instance_valid(u) and not u.is_queued_for_deletion(), mode + ": death keeps corpse for full animation")
	if is_instance_valid(u) and not u.is_queued_for_deletion():
		for phase in 12:
			if not is_instance_valid(u):
				check(false, mode + ": corpse disappeared before final death frame")
				break
			await draw_frame(u)
			check(u._art_frame == 104 + phase, mode + ": death frame " + str(phase))
			if phase < 11:
				u._physics_process(1.0 / 13.0)
		if is_instance_valid(u):
			u._physics_process(1.0 / 13.0 + 0.001)
			await get_tree().process_frame
			check(not is_instance_valid(u), mode + ": corpse reclaimed after final death frame")

func pickable(u) -> bool:
	var source: Rect2 = RA2Art.src_rect(u._ra2, u._art_frame)
	var img: Image = u._ra2.img
	var rect: Rect2 = RA2Art.draw_rect(u._ra2, u.radius, u._art_aframes, 0.0, u.RA2_SPRITE_SCALE)
	for y in range(0, int(source.size.y), 2):
		for x in range(0, int(source.size.x), 2):
			if img.get_pixelv(Vector2i(source.position) + Vector2i(x, y)).a > 0.5:
				var world: Vector2 = u.position + RA2Art.art_dir(rect.position + (Vector2(x, y) + Vector2(0.5, 0.5)) * u.RA2_SPRITE_SCALE)
				return u.hit_test(world)
	return false

func check_mouth(u, facing: int, mode: String) -> void:
	var world: Vector2 = u._weapon_muzzle()
	var base: Rect2 = RA2Art.draw_rect(u._ra2, u.radius, range(48, 56), 0.0, u.RA2_SPRITE_SCALE)
	var point: Vector2 = (Iso.dir(world - u.position) - base.position) / u.RA2_SPRITE_SCALE
	var src: Rect2 = RA2Art.src_rect(u._ra2, 56 + facing * 6)
	var image: Image = u._ra2.img
	var direction := Vector2.RIGHT.rotated(-PI / 2.0 + float(facing) * TAU / 8.0)
	var front := -INF
	var near_opaque := false
	for y in int(src.size.y):
		for x in int(src.size.x):
			if image.get_pixelv(Vector2i(src.position) + Vector2i(x, y)).a > 0.5:
				var pixel := Vector2(x + 0.5, y + 0.5)
				front = maxf(front, pixel.dot(direction))
				near_opaque = near_opaque or pixel.distance_to(point) <= 2.0
	check(near_opaque and absf(point.dot(direction) - front) < 0.01,
		mode + ": sound source touches front of firing silhouette " + str(facing))
