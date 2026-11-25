extends "res://tests/selection_regression.gd"

func exercise_mode(mode: String) -> void:
	check(DisplayServer.get_name() != "headless", mode + " requires real rendered evidence")
	if DisplayServer.get_name() == "headless":
		return
	BattleRequest.configure_skirmish(mode, {"map_size": 3200, "starting_funds": 8000, "fog_of_war": false})
	screen = load("res://scenes/battle.tscn").instantiate()
	stage.add_child(screen)
	battle = screen.battle
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	screen.hud.hide()
	for actor in battle.units.duplicate(): actor.free()
	battle.units.clear()
	for building in battle.buildings.duplicate(): building.free()
	battle.buildings.clear()
	for node in get_tree().get_nodes_in_group("resource_nodes"):
		if battle.is_ancestor_of(node): node.free()
	battle.camera.position = Vector2(1600, 1600)
	battle.camera.zoom = Iso.cam_zoom(2.0)
	battle.camera.reset_smoothing()
	battle.camera.force_update_scroll()
	var miners: Array = []
	var ores: Array = []
	for i in 8:
		var pos := Vector2(1600, 1600) + RA2Art.art_dir(Vector2((i % 4) * 175 - 262, (i / 4) * 180 - 90))
		var miner = battle.spawn_unit("CMIN", "ally", pos)
		var ore := ResourceNode.new()
		ore.position = pos + Vector2.RIGHT.rotated(i * TAU / 8.0) * 48.0
		ore.radius = 22.0
		ore.amount = 100.0
		ore.max_amount = 100.0
		battle.add_child(ore)
		ore.process_mode = Node.PROCESS_MODE_DISABLED
		miner.selected = false
		miner.hovered = false
		miner.resource_node = ore
		miner.harvest_state = "harvesting"
		miner.hull_angle = i * TAU / 8.0
		miners.append(miner)
		ores.append(ore)
	# Real physics entry: the previous fixture pre-aligned all eight hulls and
	# could not detect a miner extracting forever with its side facing the ore.
	for miner in miners:
		miner.process_mode = Node.PROCESS_MODE_ALWAYS
		miner.set_process(false)
		miner.set_physics_process(false)
	await get_tree().physics_frame
	for offset in [PI / 2.0, PI, -PI / 2.0]:
		var settled := true
		var waited := true
		var limited := true
		var stationary := true
		var conserved := true
		for i in 8:
			var miner = miners[i]
			var ore = ores[i]
			var desired := i * TAU / 8.0
			miner.hull_angle = desired + offset
			miner.harvest_state = "harvesting"
			miner.cargo = 0.0
			miner.cargo_gems = 0.0
			miner.velocity = Vector2(20, -10)
			miner._harvest_fx.remaining = 0.0
			ore.amount = 100.0
			var origin: Vector2 = miner.global_position
			var rate: float = deg_to_rad(float(miner._mv("rot", 0.0)))
			for tick in 180:
				var previous: float = miner.hull_angle
				var old_cargo: float = miner.cargo
				var old_amount: float = ore.amount
				miner._physics_process(1.0 / 60.0)
				var error := absf(angle_difference(miner.hull_angle, desired))
				limited = limited and absf(angle_difference(previous, miner.hull_angle)) <= rate / 60.0 + 0.0001
				stationary = stationary and miner.global_position.distance_to(origin) < 0.01
				conserved = conserved and is_equal_approx(old_amount - ore.amount, miner.cargo - old_cargo)
				if error > deg_to_rad(2.0):
					waited = waited and is_equal_approx(miner.cargo, old_cargo) and not miner._harvest_fx.active(miner)
				if miner.cargo > 0.0: break
			settled = settled and absf(angle_difference(miner.hull_angle, desired)) <= deg_to_rad(2.0) and miner.cargo > 0.0
		check(waited, mode + " no sideways extraction or particles before aligned " + str(offset))
		check(settled, mode + " all eight hulls turn and resume extraction " + str(offset))
		check(limited, mode + " harvest rotation respects imported ROT " + str(offset))
		check(stationary, mode + " harvesting stops translation " + str(offset))
		check(conserved, mode + " turn and harvest conserve resources " + str(offset))
	await snapshot(mode + "-turned-to-ore.png")
	for kind in ["ore", "gems"]:
		for i in 8:
			var miner = miners[i]
			var ore = ores[i]
			ore.resource_kind = kind
			ore._ore_texture = load("res://assets/ra2/resources/%s-1.png" % kind)
			ore.queue_redraw()
			var old_amount: float = ore.amount
			var old_cargo: float = miner.cargo
			miner._process_harvester(0.1)
			check(is_equal_approx(old_amount - ore.amount, miner.cargo - old_cargo) and miner.cargo > old_cargo,
				mode + " actual extraction preserves cargo conservation " + kind + str(i))
			check(miner._harvest_fx.active(miner) and miner._harvest_fx.kind == kind, mode + " real extraction activates matching particles " + kind + str(i))
			check(not miner.selected and not miner.hovered, mode + " unselected fixture " + kind + str(i))
		var first := await snapshot(mode + "-" + kind + "-a.png")
		for tick in 12:
			for miner in miners:
				miner._harvest_fx.tick(miner, 1.0 / 60.0)
				miner._process_harvester(1.0 / 60.0)
		var next := await snapshot(mode + "-" + kind + "-b.png")
		check(first.get_data() != next.get_data(), mode + " idle unselected extraction visibly animates " + kind)
	var miner = miners[0]
	var ore = ores[0]
	var ore_position: Vector2 = ore.global_position
	var before_switch: float = miner.cargo
	ore.global_position = miner.global_position + Vector2.LEFT * 48.0
	check(not miner._harvest_fx.active(miner), mode + " stale stream hides immediately when resource direction changes")
	miner._physics_process(1.0 / 60.0)
	check(is_equal_approx(miner.cargo, before_switch) and not miner._harvest_fx.active(miner), mode + " changed resource waits for chassis turn")
	ore.global_position = miner.global_position
	miner._physics_process(1.0 / 60.0)
	check(miner.cargo > before_switch and is_finite(miner.hull_angle), mode + " miner directly over traversable ore can harvest without an undefined turn")
	ore.global_position = ore_position
	miner.hull_angle = 0.0
	miner.has_move_order = true
	check(not miner._harvest_fx.active(miner), mode + " manual movement stops intake immediately")
	miner.has_move_order = false
	for state in ["to_node", "to_base", "unloading"]:
		miner.harvest_state = state
		check(not miner._harvest_fx.active(miner), mode + " no intake during " + state)
	miner.harvest_state = "harvesting"
	miner._stun_timer = 1.0
	check(not miner._harvest_fx.active(miner), mode + " stun suppresses intake")
	miner._stun_timer = 0.0
	miner._harvest_fx.tick(miner, 0.2)
	check(not miner._harvest_fx.active(miner), mode + " no successful extraction expires stream")
	miner._harvest_fx.extracted(miner, ore, 0.0)
	check(not miner._harvest_fx.active(miner), mode + " zero extraction cannot create particles")
	miner.cargo = miner.cargo_cap
	miner.hull_angle = PI
	miner._process_harvester(0.1)
	check(not miner._harvest_fx.active(miner) and miner.harvest_state == "to_base", mode + " full cargo returns without intake")
	miner._harvest_fx.extracted(miner, ore, 1.0)
	miner.harvest_state = "harvesting"
	ore.free()
	check(not miner._harvest_fx.active(miner), mode + " freed ore reference is safe")
	for other in miners:
		other.harvest_state = "to_base"
		other.queue_redraw()
	await snapshot(mode + "-stopped.png")
	screen.free()
	await get_tree().process_frame

func snapshot(name: String) -> Image:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := stage.get_texture().get_image()
	image.save_png(output_dir.path_join(name))
	return image
