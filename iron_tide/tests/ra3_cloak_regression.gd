extends "res://tests/allied_abilities_regression.gd"

const Cloak = preload("res://scripts/units/ra3_cloak_visual.gd")

func exercise_mode(mode: String) -> void:
	if mode == MatchRules.RA2: return
	setup_logistics_scene(mode, "美国")
	for node in battle.units + battle.buildings: node.free()
	battle.units.clear(); battle.buildings.clear()
	if battle.fog != null: battle.fog.free(); battle.fog = null
	var caster = actor("R3MIRAGE", "ally", Vector2(1800, 1800))
	var friend = actor("MTNK", "ally", Vector2(1850, 1800))
	var infantry = actor("E1", "ally", Vector2(1800, 1850))
	var air = actor("JUMPJET", "ally", Vector2(1850, 1850))
	check(caster.use_ability(UnitSkillLayout.index(caster, 0)), "real Q activation")
	# Exercise the production tick_actor -> Mirage.tick -> visual path.
	AlliedAbilities.tick_actor(friend, 0.01)
	check(is_equal_approx(Cloak.opacity(friend), 0.9), "owner receives SDK maximum opacity on entry")
	for i in 60: AlliedAbilities.tick_actor(friend, 1.0 / 60.0)
	check(is_equal_approx(Cloak.opacity(friend), 0.4), "SDK half-cycle reaches minimum in one real second")
	for i in 60: AlliedAbilities.tick_actor(friend, 1.0 / 60.0)
	check(is_equal_approx(Cloak.opacity(friend), 0.9), "60 native frames form a two-second cycle, independent of YR rate")
	check(not battle.actor_visible_to("enemy", friend) and battle.actor_visible_to("ally", friend), "owner visual preserves enemy concealment and owner visibility")
	AlliedAbilities.tick_actor(infantry, 0.21)
	AlliedAbilities.tick_actor(air, 0.21)
	check(Cloak.opacity(infantry) < 1.0, "ground infantry covered")
	check(Cloak.opacity(air) == 1.0 and Cloak.opacity(caster) == 1.0, "aircraft and broadcasting caster stay opaque")
	friend.special.reveal = 2.0
	check(Cloak.opacity(friend) == 1.0, "firing or damage restores body immediately")
	AlliedAbilities.tick_actor(friend, 0.01)
	check(not friend.has_meta(Cloak.STATE), "reveal clears visual phase")
	friend.special.reveal = 0.0
	AlliedAbilities.tick_actor(friend, 0.21)
	check(Cloak.opacity(friend) < 1.0, "concealment returns after reveal expires")
	friend.position = caster.position + Vector2(400, 0)
	AlliedAbilities.tick_actor(friend, 0.21)
	check(Cloak.opacity(friend) == 1.0, "leaving coverage restores opacity")
	friend.position = caster.position + Vector2(50, 0)
	var detector = actor("DOG", "enemy", friend.position + Vector2(10, 0))
	AlliedAbilities.tick_actor(friend, 0.21)
	check(Cloak.opacity(friend) == 1.0, "detected beneficiary stays visible")
	remove_actor(detector)
	AlliedAbilities.tick_actor(friend, 0.21)
	check(Cloak.opacity(friend) < 1.0, "removing detector restores owner cloak feedback")
	friend.embarked_in = caster
	check(Cloak.opacity(friend) == 1.0, "embarked body does not retain cloak tint")
	friend.embarked_in = null
	var second = actor("R3MIRAGE", "ally", caster.position + Vector2(30, 30))
	Ra3Mirage.toggle(second)
	caster.hp = 0.0
	AlliedAbilities.tick_actor(friend, 0.21)
	check(Cloak.opacity(friend) < 1.0, "overlapping live broadcaster retains visuals")
	second.hp = 0.0
	AlliedAbilities.tick_actor(friend, 0.21)
	check(Cloak.opacity(friend) == 1.0, "last broadcaster death clears visuals")
	caster.hp = caster.max_hp
	Ra3Mirage.tick(caster, 2.1)
	check(caster.use_ability(UnitSkillLayout.index(caster, 0)), "real Q deactivation")
	AlliedAbilities.tick_actor(friend, 0.21)
	check(Cloak.opacity(friend) == 1.0, "Q off removes cached cloak")
	Ra3Mirage.tick(caster, 2.1); caster.use_ability(UnitSkillLayout.index(caster, 0))
	for subject in [friend, infantry]:
		AlliedAbilities.tick_actor(subject, 0.21)
		await pixels(subject)
	var passive = actor("R3MIRAGE", "ally", caster.position + Vector2(60, 0))
	passive.velocity = Vector2(2, 0)
	AlliedAbilities.tick_actor(passive, 0.21)
	passive._ra3_model.disguise_blend = 0.0
	await pixels(passive)
	var disguised = actor("MGTK", "ally", caster.position + Vector2(0, 60))
	AlliedAbilities.tick_actor(disguised, 0.21)
	await pixels(disguised)
	var saved := BattleSaves.save_slot(battle, "quick")
	var loaded := BattleSaves.read_slot("quick")
	check(saved.ok and loaded.ok, "real save retains gameplay state")
	if loaded.ok:
		BattleSaves.Snapshot.new().restore(battle, loaded.snapshot)
		var restored = battle.units.filter(func(u): return u.unit_id == "MTNK" and u.side == "ally")[0]
		check(not restored.has_meta(Cloak.STATE), "presentation cache is not serialized")
		AlliedAbilities.tick_actor(restored, 0.21)
		check(Cloak.opacity(restored) < 1.0, "loaded active field reconstructs cloak presentation")
	screen.free()
	await get_tree().process_frame

func capture_unit(unit, viewport: SubViewport, label: String) -> Image:
	unit.queue_redraw()
	for i in 3: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := viewport.get_texture().get_image()
	img.save_png(output_dir.path_join(label + ".png"))
	return img

func pixels(unit) -> void:
	# Real Unit._draw, real SHP/VXL/3D/disguise resources; isolate alpha from
	# battlefield terrain and the field shell, with no replacement draw code.
	var parent = unit.get_parent()
	var point: Vector2 = unit.position
	var state: Dictionary = unit.get_meta(Cloak.STATE).duplicate()
	var viewport := SubViewport.new()
	viewport.size = Vector2i(256, 256); viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.world_2d = World2D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	unit.reparent(viewport, false); unit.position = Vector2(128, 150)
	unit.process_mode = Node.PROCESS_MODE_DISABLED
	unit.selected = false; unit.hovered = false
	if unit._ra3_model != null: unit._ra3_model.sync_pose(true)
	unit.remove_meta(Cloak.STATE)
	var ordinary := await capture_unit(unit, viewport, unit.unit_id + "-ordinary")
	state.phase = 1.0; state.covered = true; unit.set_meta(Cloak.STATE, state)
	var cloaked := await capture_unit(unit, viewport, unit.unit_id + "-cloaked")
	var ratios: Array[float] = []
	# Reparenting the live 3D viewport makes Compatibility clear this parent
	# opaque black. Measure compositing against that known black background;
	# sprite-only cases retain their direct transparent-alpha measurement.
	var opaque_clear := unit._ra3_model != null
	if opaque_clear:
		check(ordinary.get_pixel(0, 0) == Color.BLACK and cloaked.get_pixel(0, 0) == Color.BLACK, "3D capture has identical opaque black clear")
	for y in ordinary.get_height():
		for x in ordinary.get_width():
			var before := ordinary.get_pixel(x, y)
			var after := cloaked.get_pixel(x, y)
			if opaque_clear and maxf(before.r, maxf(before.g, before.b)) > 0.32:
				ratios.append((after.r + after.g + after.b) / (before.r + before.g + before.b))
			elif not opaque_clear and before.a > 0.99:
				ratios.append(cloaked.get_pixel(x, y).a)
	ratios.sort()
	var median: float = ratios[ratios.size() / 2] if not ratios.is_empty() else 1.0
	check(ratios.size() > 10 and median >= 0.38 and median < 0.75, unit.unit_id + " real body pixels become translucent", {"pixels":ratios.size(), "median_alpha":median})
	check(unit.modulate == Color.WHITE and unit.self_modulate == Color.WHITE, unit.unit_id + " whole actor and HUD modulation unchanged")
	unit.selected = true
	var selected := await capture_unit(unit, viewport, unit.unit_id + "-selected")
	var bright_ring := 0
	for y in range(150, 190):
		for x in range(80, 180):
			var pixel := selected.get_pixel(x, y)
			if pixel.g > 0.9 and pixel.r < 0.7 and pixel.a > 0.85: bright_ring += 1
	check(bright_ring > 10, unit.unit_id + " selection ring stays opaque", bright_ring)
	unit.selected = false; unit.reparent(parent, false); unit.position = point
	unit.process_mode = Node.PROCESS_MODE_ALWAYS
	viewport.free()
