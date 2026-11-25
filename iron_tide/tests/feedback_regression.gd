extends "res://tests/unit_fire_regression.gd"

func exercise_mode(mode: String) -> void:
	BattleRequest.configure_skirmish(mode, {"map_size": 3200, "starting_funds": 10000})
	screen = load("res://scenes/battle.tscn").instantiate()
	stage.add_child(screen)
	battle = screen.battle
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	battle.process_mode = Node.PROCESS_MODE_ALWAYS
	battle.set_process(false)
	battle.set_physics_process(false)
	for child in battle.get_children():
		child.process_mode = Node.PROCESS_MODE_DISABLED
	screen.hud.process_mode = Node.PROCESS_MODE_ALWAYS
	screen.hud.set_process(false)
	GM.god_mode = false
	GM.one_shot_kill = false
	get_window().focus_entered.emit()
	await check_base_tab(mode)
	var yard = battle._place_building("GACNST", "ally", Vector2(1400, 1100), true)
	yard._buildup_play = -1.0
	await check_base_tab(mode + " GACNST", yard)
	await check_resources(mode)
	for side in ["ally", "enemy"]:
		await check_unloading(mode, side)
		await check_gi(mode, side)
	screen.free()
	await get_tree().process_frame

func focus_at(point: Vector2, zoom := 2.0) -> void:
	battle.camera.position = point
	battle.camera.zoom = Vector2(zoom, zoom * 0.5)
	battle.camera.reset_smoothing()
	battle.camera.force_update_scroll()

func photo(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	stage.get_texture().get_image().save_png(output_dir.path_join(name + ".png"))

func check_base_tab(mode: String, target = null) -> void:
	var hq = battle._player_hq() if target == null else target
	focus_at(hq.global_position)
	await get_tree().process_frame
	var point := Vector2.INF
	for y in range(160, 610, 8):
		for x in range(350, 1100, 8):
			var candidate := Vector2(x, y)
			var world: Vector2 = stage.get_canvas_transform().affine_inverse() * candidate
			if battle._pick_at(world) == hq:
				point = candidate
				break
		if point.is_finite():
			break
	check(point.is_finite(), mode + ": base has pickable visible pixels")
	if not point.is_finite():
		return
	for repeat in 2:
		screen.hud.select_prod_tab("vehicle")
		await gesture(point, point)
		check(battle.selected_building == hq and screen.hud.prod_tab == "building", mode + ": actual base click/reclick opens building tab")
		screen.hud._process(0.1)
		screen.hud.select_prod_tab("vehicle")
		screen.hud._process(0.1)
		check(screen.hud.prod_tab == "vehicle", mode + ": manual tab remains until another selection")
	for b in battle.buildings:
		if b.side == "enemy" or b.is_refinery():
			screen.hud._auto_focus_building_tab(b)
			check(screen.hud.prod_tab == "vehicle", mode + ": enemy/refinery does not steal production tab")

func check_resources(mode: String) -> void:
	focus_at(Vector2(1600, 1600))
	for kind in ["ore", "gems"]:
		for level in [0.0, 0.001, 0.5, 1.0]:
			var ore = preload("res://scripts/world/resource_node.gd").new()
			ore.resource_kind = kind
			ore.position = Vector2(1510 + level * 240, 1530 if kind == "ore" else 1650)
			ore.max_amount = 100.0
			ore.amount = level * 100.0
			battle.add_child(ore)
			ore.process_mode = Node.PROCESS_MODE_DISABLED
			check(ore._ore_texture != null and ore._ore_texture.get_size() == Vector2(360, 240), mode + ": original overlay sheet loaded " + kind)
			var expected := -1 if level == 0.0 else (0 if level < 0.01 else (5 if level == 0.5 else 11))
			check(ore.density_frame() == expected, mode + ": resource density/empty frame " + kind, ore.density_frame())
	await photo(mode + "-ore-gems")

func check_unloading(mode: String, side: String) -> void:
	var refinery = battle._place_building("GAREFN", side, Vector2(1900, 1900), true)
	refinery._buildup_play = -1.0
	var miner = battle.spawn_unit("CMIN", side, Vector2(1900, 1900))
	miner.process_mode = Node.PROCESS_MODE_DISABLED
	miner.home_base = refinery
	miner._lock_dock()
	miner.global_position = miner._dock_pt
	miner.cargo = miner.cargo_cap
	miner.harvest_state = "to_base"
	refinery._tick_anim_state(0.1)
	check(refinery._anim_state != "special", mode + side + ": approach does not unload")
	miner.harvest_state = "unloading"
	refinery._tick_anim_state(0.1)
	check(refinery._anim_state == "special" and refinery.unloading_miner() == miner, mode + side + ": actual docked cargo triggers special layer")
	check(refinery._layer_visible("specialanim") and refinery._layer_visible("activeanim"), mode + side + ": unloading retains refinery machinery")
	refinery._tick_anim_state(0.6)
	check(refinery._anim_group_t >= 0.6, mode + side + ": unloading timeline advances without resetting")
	for layer in refinery._ra2_anim:
		if str(layer.kind) == "specialanim":
			var state: Dictionary = refinery._anim_layer(layer)
			check(refinery._anim_frame_for(layer, state) > int(state.loopStart), mode + side + ": original unloading frame advances")
	focus_at(refinery.position)
	refinery.queue_redraw()
	await photo(mode + "-" + side + "-unloading")
	miner.position += Vector2(200, 0)
	refinery._tick_anim_state(0.1)
	check(refinery._anim_state != "special", mode + side + ": remote miner cannot trigger unloading")
	miner.position = miner._dock_pt
	miner.cargo = 0.0
	refinery._tick_anim_state(0.1)
	check(refinery._anim_state != "special", mode + side + ": empty cargo stops unloading")
	miner.cargo = miner.cargo_cap
	miner._dead = true
	refinery._tick_anim_state(0.1)
	check(refinery._anim_state != "special", mode + side + ": dead miner stops unloading")
	battle.units.erase(miner)
	miner.free()
	battle.buildings.erase(refinery)
	refinery.free()

func check_gi(mode: String, side: String) -> void:
	var u = battle.spawn_unit("E1", side, Vector2(1400, 1400))
	var t = battle.spawn_unit("E1", "enemy" if side == "ally" else "ally", Vector2(1500, 1400))
	for actor in [u, t]:
		actor.process_mode = Node.PROCESS_MODE_DISABLED
		actor.bonuses = {}
		actor.order_stop()
	focus_at(u.position, 4.0)
	check(u._active_weapon().ra2_weapon_id == "M60", mode + side + ": standing M60")
	u.set_deployed(true)
	check(u._active_weapon().ra2_weapon_id == "Para" and u.attack_range == 275.0 and u.cooldown == 1.0, mode + side + ": deployed weapon/range/ROF use original Para")
	check(u._active_weapon().report == "GIAttackDeployed" and GameData.ra2_muzzle_anims("Para").is_empty(), mode + side + ": deployed report and baked muzzle flash")
	u.bonuses = {} # Exact raw weapon damage, independent of extension card bonuses.
	for face in 8:
		u.hull_angle = float(face) * TAU / 8.0
		u.aim_dir = Vector2.RIGHT.rotated(u.hull_angle)
		var holder: Node = u._pick_projectile_parent()
		var before := holder.get_children()
		u._fire_shot(t)
		check(u._fire_anim_time == 0.0, mode + side + ": shot starts animation at first frame")
		var shots := new_shots(holder, before)
		check(shots.size() == 1, mode + side + ": deployed emits single original shot")
		var hp_before: float = t.hp
		for shot in shots:
			shot.process_mode = Node.PROCESS_MODE_DISABLED
			for tick in 120:
				if shot.is_queued_for_deletion(): break
				shot._physics_process(1.0 / 60.0)
			shot.free()
		check(is_equal_approx(hp_before - t.hp, 15.0), mode + side + ": Para SSA applies original unarmored damage", hp_before - t.hp)
		t.hp = t.max_hp
		var anchor: Array = []
		for phase in [0.0, 0.125, 0.25]:
			u._fire_anim_time = phase
			u.queue_redraw()
			await get_tree().process_frame
			await get_tree().process_frame
			if DisplayServer.get_name() != "headless":
				var expected := RA2Art.seq_frame(u._seq, "DeployedFire", RA2Art.facing_index(u.hull_angle, 8), int(phase * 16.0))
				check(u._art_frame == expected, mode + side + ": real draw uses deployed fire facing/frame", u._art_frame)
				if anchor.is_empty(): anchor = u._art_aframes.duplicate()
				check(anchor == u._art_aframes, mode + side + ": firing anchor stable")
		if face == 0: await photo(mode + "-" + side + "-gi-deployed")
	u.decorate_tick(1.0)
	check(u._fire_anim_time < 0.0, mode + side + ": fire animation ends")
	u._grant_veteran(2, false)
	check(u._active_weapon().ra2_weapon_id == "ParaE" and u.attack_range == 385.0, mode + side + ": elite deployed uses ParaE")
	u.set_deployed(false)
	check(u._active_weapon().ra2_weapon_id == "M60E" and u._fire_anim_time < 0.0 and u.attack_range == float(u._active_weapon().range), mode + side + ": standing restores elite primary and clears animation")
	u._grant_veteran(0, false)
	u.set_deployed(true)
	u.hull_angle = 0.0
	u.aim_dir = Vector2.RIGHT
	u.attack_target = t
	u._cd_timer = 0.0
	t.position = u.position + Vector2(280, 0)
	check(not u._try_fire_ready() and u._cd_timer == 0.0, mode + side + ": deployed rejects outside Para range without spending readiness")
	t.position = u.position + Vector2(260, 0)
	var holder: Node = u._pick_projectile_parent()
	var before := holder.get_children()
	check(u._try_fire_ready() and u._cd_timer > 0.0, mode + side + ": real firing gate accepts deployed extended range")
	check(not u._try_fire_ready(), mode + side + ": deployed cooldown blocks repeated shot")
	for shot in new_shots(holder, before): shot.free()
	for actor in [u, t]:
		battle.units.erase(actor)
		actor.free()
	await get_tree().process_frame
