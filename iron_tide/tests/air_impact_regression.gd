extends "res://tests/allied_abilities_regression.gd"

func clear_fx() -> void:
	for node in battle.effects_root.get_children(): node.free()

func exercise_mode(mode: String) -> void:
	if mode == MatchRules.RA2: return
	setup_logistics_scene(mode, "美国")
	for node in battle.units + battle.buildings: node.free()
	battle.units.clear(); battle.buildings.clear()
	if battle.fog != null: battle.fog.free(); battle.fog = null
	battle.water_rects = []; battle.path_service.set_water([])
	battle.camera.position = Vector2(1500, 1400)
	battle.camera.zoom = Iso.cam_zoom(1.0)
	battle.camera.reset_smoothing(); battle.camera.force_update_scroll()
	var source = actor("FV", "ally", Vector2(1300, 1450))
	source._grant_veteran(2, false)
	for id in ["R3HARBINGER", "ORCA", "JUMPJET", "MTNK"]:
		var target = actor(id, "enemy", Vector2(1600, 1400))
		target.hp = 10000; target.max_hp = 10000
		target.logistics.air_lift = 1.0
		source._fire_shot(target)
		var shots: Array = battle.projectiles_root.get_children().filter(func(n):return n is Projectile and not n.is_queued_for_deletion())
		check(not shots.is_empty(), "elite IFV fires actual projectile at " + id)
		if shots.is_empty(): continue
		var shot = shots[-1]; shot.set_physics_process(false)
		clear_fx()
		for i in 600:
			shot._physics_process(1.0/60.0)
			if shot._detonated: break
		var expected: Vector2 = target.position + RA2Art.art_dir(Vector2(0, -target._visual_lift()))
		check(shot._detonated and target.hp < 10000, id + " real missile still delivers damage")
		check(shot.target_point == target.position, id + " simulation target stays at the ground coordinate")
		var impacts: Array = battle.effects_root.get_children().filter(func(n):return not n is Effects.FloatText and n is Node2D and n.name != "__decals")
		check(not impacts.is_empty(), id + " emits native impact effect")
		for fx in impacts:
			check(fx.position.distance_to(expected) < 0.1, id + " impact uses projected aircraft height", {"actual":str(fx.position),"expected":str(expected)})
		var labels: Array = battle.effects_root.get_children().filter(func(n):return n is Effects.FloatText)
		check(labels.size() == 1, id + " emits one damage number")
		if not labels.is_empty():
			var offset: Vector2 = labels[0].position - expected
			check(absf(offset.x) < 12 and offset.y < 0 and offset.length() < 100, id + " damage number is above the visible body", str(offset))
		if target.is_air:
			check(battle.effects_root.get_node_or_null("__decals") == null, id + " airborne detonation cannot scorch terrain")
		if DisplayServer.get_name() != "headless":
			for fx in battle.effects_root.get_children():
				if fx.has_method("_process"): fx.call("_process", 0.08)
				fx.set_process(false)
			for i in 3: await get_tree().process_frame
			await RenderingServer.frame_post_draw
			stage.get_texture().get_image().save_png(output_dir.path_join(id + "-impact.png"))
		clear_fx(); battle.units.erase(target); target.free()
		for node in battle.projectiles_root.get_children(): node.free()
	await lifecycle_cases(source)
	# Instant weapons share the same FX helper but must not stamp airborne decals.
	var gun = actor("MTNK", "ally", Vector2(1300, 1400))
	var deforming := ""
	for id in GameData.ra2_warheads:
		if Ra2Damage.should_deform(id, 1000): deforming = id; break
	check(not deforming.is_empty(), "native deforming warhead fixture exists")
	gun._ra2_weapon_override = {"ra2_warhead":deforming}
	gun._spawn_impact_anim(Vector2(1500, 1400), 1000, false)
	check(battle.effects_root.get_node_or_null("__decals") == null, "instant airborne effect does not stamp terrain")
	gun._spawn_impact_anim(Vector2(1500, 1400), 1000, true)
	check(battle.effects_root.get_node_or_null("__decals") != null, "instant ground effect retains original terrain scorch")
	screen.free(); await get_tree().process_frame

func lifecycle_cases(source) -> void:
	for scenario in ["lethal", "invisible", "removed_then_saved", "legacy_live_target"]:
		var target = actor("R3HARBINGER", "enemy", Vector2(1600, 1400))
		target.hp = 1.0 if scenario == "lethal" else 10000.0
		var weapon: Dictionary = source._active_weapon().duplicate(true)
		var shot := Projectile.new()
		shot.setup(source._weapon_muzzle(), target, weapon, 25, {}, "ally", source)
		shot.set_physics_process(false)
		if scenario == "invisible": shot.ra2_inviso = true
		# The cached height must follow descent, not stay at the initial altitude.
		target.logistics.air_lift = 0.5
		var expected: Vector2 = target.position + RA2Art.art_dir(Vector2(0, -target._visual_lift()))
		clear_fx()
		battle.projectiles_root.add_child(shot)
		if scenario == "removed_then_saved":
			shot._physics_process(1.0/60)
			battle.units.erase(target); target.free()
			var codec = preload("res://scripts/save/battle_snapshot.gd").new()
			var snapshot = codec.capture(battle); codec.restore(battle, snapshot)
			shot = battle.projectiles_root.get_child(0)
			source = battle.units.filter(func(u):return u.unit_id == "FV")[0]
		elif scenario == "legacy_live_target":
			shot.splinters.erase("visual_target_lift")
		if not shot._detonated: shot._explode()
		var impacts: Array = battle.effects_root.get_children().filter(func(n):return not n is Effects.FloatText and n is Node2D and n.name != "__decals")
		# Lethal Harbinger additionally creates its native crash FX; require the
		# missile's original warhead effect at the expected height, not that crash FX.
		check(impacts.any(func(fx):return fx.position.distance_to(expected) < 0.1), scenario + " keeps aircraft-height impact through real projectile lifecycle")
		if scenario == "lethal": check(target._dead, "lethal missile enters real aircraft death")
		check(battle.effects_root.get_node_or_null("__decals") == null, scenario + " has no terrain scorch")
		clear_fx()
		if is_instance_valid(target): battle.units.erase(target); target.free()
		for node in battle.projectiles_root.get_children(): node.free()
