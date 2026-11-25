extends "res://tests/allied_abilities_regression.gd"
const Visual = preload("res://scripts/units/projectile_visual.gd")

class FogStrip extends Node2D:
	func position_visible_to(_observer: String, point: Vector2) -> bool:
		return point.x < 40 or point.x > 60

func check_trail_gap() -> void:
	if DisplayServer.get_name() == "headless": return
	var view := SubViewport.new()
	view.size = Vector2i(100, 32)
	view.transparent_bg = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)
	var world := FogStrip.new()
	view.add_child(world)
	var host := Node2D.new()
	world.add_child(host)
	var canvas := Node2D.new()
	host.add_child(canvas)
	canvas.draw.connect(func():
		Iso.begin(canvas)
		var path: Array[Vector2] = []
		for x in range(8, 97, 8): path.append(Vector2(x, 16))
		Visual.paint_path(canvas, path, "line", Color.WHITE, 0.01, Color.WHITE))
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var shot := view.get_texture().get_image()
	check(shot.get_pixel(24, 16).a > 0.1 and shot.get_pixel(80, 16).a > 0.1 and shot.get_pixel(50, 16).a == 0.0,
		"joined trail renders both visible sections without bridging the hidden strip")
	view.free()

func screenshot() -> Image:
	await get_tree().process_frame
	if DisplayServer.get_name() == "headless": return null
	await RenderingServer.frame_post_draw
	return stage.get_texture().get_image()

func exercise_mode(mode: String) -> void:
	if mode == MatchRules.EXTENDED: await check_trail_gap()
	setup_logistics_scene(mode, "美国")
	battle.water_rects = []
	battle.path_service.set_water([])
	battle.power_low = false
	battle.camera.position = Vector2(1700, 1600)
	battle.camera.zoom = Iso.cam_zoom(1.5)
	battle.camera.reset_smoothing()
	battle.camera.force_update_scroll()
	# The inherited legacy fixture starts without fog. Install the real service;
	# keep terrain clear for pixel comparisons and vary visibility only at the boundary check.
	BattleRequest.skirmish_config.fog_of_war = true
	battle.fog = preload("res://scripts/world/fog_of_war.gd").new()
	battle.add_child(battle.fog)
	battle.fog.setup(battle)
	battle.fog.process_mode = Node.PROCESS_MODE_DISABLED
	battle.fog.visible = false
	for side in ["ally", "enemy"]: battle.fog.visible_cells[side].fill(1)
	var audit: Array = []
	for id in GameData.ra2_weapons:
		var raw: Dictionary = GameData.ra2_weapons[id]
		var extra: Dictionary = raw.get("extra", {})
		for flag in ["IsLaser", "IsElectricBolt", "IsRadBeam", "IsRailgun"]:
			if not GameData._ra2_flag(extra.get(flag)): continue
			var spec := GameData.ra2_beam_spec(str(id))
			check(not spec.is_empty(), mode + " beam flag covered: " + str(id) + " " + flag)
			audit.append({"weapon": id, "flag": flag, "kind": spec.get("kind", "")})
	for id in GameData.ra2_projectiles:
		var raw: Dictionary = GameData.ra2_projectiles[id]
		var image: String = str(raw.get("image", ""))
		var art := Visual.spec(image)
		if not GameData._ra2_flag(art.get("UseLineTrail")) and not art.has("Trailer"): continue
		var shot := Projectile.new()
		shot._apply_ra2_projectile(str(id))
		check(not Visual.kind(shot).is_empty(), mode + " projectile art trail covered: " + str(id))
		audit.append({"projectile": id, "image": image, "kind": Visual.kind(shot)})
		shot.free()
	var f := FileAccess.open(output_dir.path_join(mode + "-weapon-audit.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(audit, "  ")); f.close()
	check(Visual.spec("DRAGON").get("LineTrailColor") == "216,216,255", mode + " Dragon original YR trail color")
	check(Visual.spec("MEDUSA").get("LineTrailColorDecrement") == "12", mode + " Medusa original YR decrement")
	var probe := Projectile.new()
	probe.ra2_image = "DRAGON"
	for row in [[Vector2.UP, 0], [Vector2.LEFT, 8], [Vector2.DOWN, 16], [Vector2.RIGHT, 24]]:
		probe._heading = RA2Art.art_dir(row[0]).normalized()
		check(Visual.sprite_frame(probe, 32) == row[1], mode + " original missile facing " + str(row[1]))
	probe.free()
	check(GameData.ra2_beam_spec("YR_CAP_CRNeutronRifle").color == Color(128.0 / 255.0, 200.0 / 255.0, 1), mode + " prefixed chrono IFV beam stays blue")
	for id in ["FV", "NASAM", "AEGIS", "ORCA", "BEAG", "GGI"]:
		await actual_missile(mode, id)
	await other_presentations(mode)
	await trail_save(mode)
	screen.free()
	await get_tree().process_frame

func actual_missile(mode: String, id: String) -> void:
	var tag: String = mode + " " + id + ": "
	var source
	if id == "NASAM":
		source = battle._place_building(id, "ally", Vector2(1450, 1550), true)
		source.process_mode = Node.PROCESS_MODE_DISABLED
		source._buildup_play = -1.0
	else:
		source = actor(id, "ally", Vector2(1450, 1550))
		if id == "GGI": source._deployed = true
	var target = actor("ORCA" if id in ["NASAM", "AEGIS"] else "MTNK", "enemy", Vector2(2100, 1650))
	var before: Array = battle.projectiles_root.get_children()
	source.attack_target = target
	if source is Building:
		source._turret_art.angle = (target.position - source.position).angle()
		check(source._fire(), tag + "actual building fires")
	else:
		source._fire_shot(target)
	var shots: Array = battle.projectiles_root.get_children().filter(func(n): return n is Projectile and not before.has(n))
	check(shots.size() == 1, tag + "actual weapon creates projectile")
	if shots.is_empty(): return
	var shot: Projectile = shots[0]
	shot.process_mode = Node.PROCESS_MODE_DISABLED
	check(Visual.kind(shot) == "line", tag + "weapon consumes original line-trail art")
	check(not RA2Art.fx(shot.ra2_image).is_empty(), tag + "real SHP remains present with trail")
	var hp_before: float = target.hp
	for tick in 10:
		target.position.y += 8.0
		shot._physics_process(1.0 / 60.0)
	check(shot._trail.size() >= 2 and shot._trail.size() <= Visual.MAX_POINTS, tag + "homing movement records bounded path")
	check(target.hp == hp_before, tag + "trail does not cause premature damage")
	check(shot._arc_h > 0.0 and Visual.lift_at(shot, shot.global_position) > 5.0, tag + " missile has a raised flight presentation")
	var visual_tip := Visual.visual_position(shot)
	check(visual_tip.distance_to(shot.global_position) > 5.0, tag + " visible missile is not pinned to the straight ground path")
	check(Visual.sprite_frame(shot, 32) != 0, tag + " missile sprite follows flight tangent rather than fixed frame zero")
	var path: Array[Vector2] = shot._trail.duplicate()
	var visible_cells: PackedByteArray = battle.fog.visible_cells.ally.duplicate()
	battle.fog.visible_cells.ally.fill(0)
	check(not Visual.segment_visible(shot, path[0], shot.global_position), tag + "trail cannot expose hidden segment")
	battle.fog.visible_cells.ally = visible_cells
	var with_trail := await screenshot()
	shot._trail.clear(); shot.queue_redraw()
	var without_trail := await screenshot()
	if with_trail != null:
		var changed := 0
		for x in range(300, 1200):
			for y in range(150, 680):
				if with_trail.get_pixel(x, y) != without_trail.get_pixel(x, y): changed += 1
		check(changed > 15, tag + "real sprite path also renders trail pixels", changed)
		with_trail.save_png(output_dir.path_join(mode + "-" + id + "-trail.png"))
	shot._trail.assign(path); shot.queue_redraw()
	var flight: Array[Vector2] = [Iso.dir(shot._arc_from), Iso.dir(Visual.visual_position(shot))]
	var captured_curve := false
	for tick in 300:
		shot._physics_process(1.0 / 60.0)
		flight.append(Iso.dir(Visual.visual_position(shot)))
		if shot.is_queued_for_deletion(): break
		if not captured_curve and shot.global_position.distance_to(shot.target_point) < shot._arc_len * 0.4:
			captured_curve = true
			var curve_image := await screenshot()
			if curve_image != null: curve_image.save_png(output_dir.path_join(mode + "-" + id + "-curve.png"))
	var deviation := 0.0
	for point in flight:
		deviation = maxf(deviation, point.distance_to(Geometry2D.get_closest_point_to_segment(point, flight.front(), flight.back())))
	check(deviation > 10.0, tag + " recorded flight visibly curves rather than connecting endpoints with one line", deviation)
	check(shot._detonated and target.hp < hp_before, tag + "original projectile flight still delivers damage")
	var tails := get_tree().get_nodes_in_group("missile_tails").filter(func(n): return not n.is_queued_for_deletion())
	check(not tails.is_empty(), tag + " impact leaves a fading trail instead of erasing the line")
	if not tails.is_empty():
		var tail = tails.back()
		tail.set_process(false)
		var hp_after: float = target.hp
		check(not tail is Projectile, tag + " detached tail is not a damaging or saved projectile")
		battle.paused = true
		tail._process(2.0)
		check(tail.age == 0.0, tag + " pause freezes detached trail")
		battle.paused = false
		tail._process(2.0)
		check(tail.is_queued_for_deletion() and target.hp == hp_after, tag + " fade retires without a second damage event")
	remove_actor(target)
	if source is Unit: remove_actor(source)
	else: source.queue_free()
	await get_tree().process_frame

func other_presentations(mode: String) -> void:
	var created: Array = []
	for row in [["SubTorpedo", "wake"], ["DredCollision", "smoke"], ["ChemLauncher", "smoke"]]:
		var shot := Projectile.new()
		var start := Vector2(1500, 1500 + created.size() * 100)
		shot.setup(start, null, GameData.spawned_weapon(row[0]), 1.0, {}, "ally")
		shot.target_point = start + Vector2(800, 0)
		battle.projectiles_root.add_child(shot)
		shot.process_mode = Node.PROCESS_MODE_DISABLED
		for i in 10: shot._physics_process(1.0 / 60.0)
		check(Visual.kind(shot) == row[1] and shot._trail.size() > 1, mode + " actual projectile presentation " + row[0])
		created.append(shot)
	var before: Array = battle.effects_root.get_children()
	for id in ["PrismShot", "CoilBolt", "RadBeamWeapon", "LtRail"]:
		var spec := GameData.ra2_beam_spec(id)
		var start := Vector2(1400, 1200 + created.size() * 80)
		Effects.spawn_beam(start, start + Vector2(300, 30), spec.color, spec.kind, spec.thickness, spec.duration)
		created.append(battle.effects_root.get_children().back())
	check(battle.effects_root.get_child_count() == before.size() + 4, mode + " all four beam renderers instantiate")
	var image := await screenshot()
	if image != null: image.save_png(output_dir.path_join(mode + "-other-lines.png"))
	for n in created: n.free()

func trail_save(mode: String) -> void:
	var source = actor("FV", "ally", Vector2(1200, 1600))
	var target = actor("MTNK", "enemy", Vector2(2000, 1600))
	source.attack_target = target
	source._fire_shot(target)
	var shot: Projectile = battle.projectiles_root.get_children().filter(func(n): return n is Projectile and not n.is_queued_for_deletion())[0]
	shot.process_mode = Node.PROCESS_MODE_DISABLED
	for i in 8: shot._physics_process(1.0 / 60.0)
	var path: Array[Vector2] = shot._trail.duplicate()
	var lift: float = Visual.lift_at(shot, shot.global_position)
	var tip: Vector2 = Visual.visual_position(shot)
	var save := BattleSaves.save_slot(battle, "slot1")
	check(save.ok, mode + " trail saves with existing schema", save.get("message", ""))
	if not save.ok: return
	var loaded := BattleSaves.read_slot("slot1")
	check(loaded.ok, mode + " trail snapshot validates")
	if not loaded.ok: return
	var codec = preload("res://scripts/save/battle_snapshot.gd").new()
	codec.restore(battle, loaded.snapshot)
	var restored: Array = battle.projectiles_root.get_children().filter(func(n): return n is Projectile and not n.is_queued_for_deletion())
	check(restored.size() == 1 and restored[0]._trail == path and Visual.kind(restored[0]) == "line", mode + " restore preserves trail path and resolves original art")
	if restored.size() == 1:
		check(is_equal_approx(Visual.lift_at(restored[0], restored[0].global_position), lift) and Visual.visual_position(restored[0]).is_equal_approx(tip), mode + " restore preserves elevated flight and exact displayed tip without schema changes")
