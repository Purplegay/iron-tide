extends "res://tests/logistics_regression.gd"

func picture() -> Image:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	return stage.get_texture().get_image()

func warm_pixels(image: Image) -> int:
	var total := 0
	for y in range(150, 650):
		for x in range(250, 1000):
			var c := image.get_pixel(x, y)
			if c.r > 0.45 and c.g > 0.16 and c.r > c.b * 1.8 and c.g > c.b * 1.3: total += 1
	return total

func exercise_mode(mode: String) -> void:
	get_tree().paused = false
	setup_logistics_scene(mode, "美国")
	for group in ["obstacles", "resource_nodes"]:
		for actor in get_tree().get_nodes_in_group(group): actor.free()
	for actor in battle.units + battle.buildings: actor.free()
	battle.units.clear(); battle.buildings.clear()
	battle.water_rects = []; battle.path_service.set_water([])
	battle.camera.position = Vector2(1600, 1600)
	battle.camera.zoom = Iso.cam_zoom(2.0)
	battle.camera.reset_smoothing(); battle.camera.force_update_scroll()
	for id in ["GAPOWR", "GAWEAP", "GAREFN", "GADEPT", "GAAIRC", "GACNST", "ATESLA", "GAWALL"]:
		var b = battle._place_building(id, "ally", Vector2(1600, 1600), true)
		b._buildup_play = -1.0
		var fire = b.get_node("DamageFire")
		var tag: String = mode + " " + id + ": "
		var n: int = fire.offsets.size()
		check((n == 0) == (id == "GAWALL"), tag + "native offset coverage, no invented wall fire")
		for ratio in [1.0, 0.51, 0.5, 0.26, 0.25, 0.01]:
			b.hp = b.max_hp * ratio
			fire.advance(0.15)
			var expected: int = 0 if ratio > 0.5 else (n if ratio <= 0.25 else ceili(n * 0.5))
			check(fire.active_count() == expected and fire.visible == (expected > 0), tag + "health threshold " + str(ratio))
		var hp: float = b.hp
		var fx_count: int = battle.effects_root.get_child_count()
		for step in 30: fire.advance(1.0)
		check(b.hp == hp and battle.effects_root.get_child_count() == fx_count and b.get_child_count() < 10, tag + "loop is bounded and causes no additional damage")
		var previous: float = fire.elapsed
		battle.paused = true; fire.advance(3.0)
		check(fire.elapsed == previous, tag + "pause freezes fire animation")
		battle.paused = false
		b.under_construction = true; fire.advance(0.0)
		check(not fire.visible, tag + "no construction fire")
		b.under_construction = false; b._buildup_play = 0.0; fire.advance(0.0)
		check(not fire.visible, tag + "no buildup fire")
		b._buildup_play = -1.0; b.special.chrono_left = 1.0; fire.advance(0.0)
		check(not fire.visible, tag + "chrono frozen fire hidden")
		b.special.erase("chrono_left")
		b.hp = b.max_hp; b.receive_hit(b.max_hp * 0.8)
		fire.advance(0.0)
		check(fire.active_count() == n, tag + "actual receive_hit activates heavy damage fire")
		if n > 0:
			fire.elapsed = 2.0; fire.advance(0.0)
			check(fire.material == null and not fire.use_parent_material, tag + "flame palette does not inherit house remap")
			check(fire.fire_position(0).is_finite(), tag + "native offset has valid screen projection")
			if DisplayServer.get_name() != "headless":
				fire.hide()
				var without: Image = await picture()
				fire.show(); fire.queue_redraw()
				var burning: Image = await picture()
				burning.save_png(output_dir.path_join(mode + "-" + id + "-fire.png"))
				check(warm_pixels(burning) > warm_pixels(without) + 12, tag + "actual rendered orange flames", [warm_pixels(without), warm_pixels(burning)])
		b.set_repairing(true)
		for tick in 200: b._process_building_repair(1.0)
		fire.advance(0.0)
		check(b.hp == b.max_hp and not fire.visible, tag + "real paid repair extinguishes fire")
		battle.buildings.erase(b); b.free()
	# Real fog rebuild must hide the child with its enemy building.
	var enemy = battle._place_building("GAPOWR", "enemy", Vector2(2200, 2200), true)
	enemy._buildup_play = -1.0; enemy.hp = enemy.max_hp * 0.2
	var flame = enemy.get_node("DamageFire")
	flame.advance(0.0)
	if battle.fog != null:
		battle.fog.rebuild()
		check(not enemy.visible and not flame.is_visible_in_tree(), mode + ": unseen enemy fire does not leak through fog")
		var scout = battle.spawn_unit("E1", "ally", enemy.position + Vector2(80, 0))
		battle.fog.rebuild()
		check(enemy.visible and flame.is_visible_in_tree(), mode + ": scouting reveals building and fire together")
		battle.units.erase(scout); scout.free()
	# Existing disk schema stores HP; derived child is recreated rather than serialized.
	var saved := BattleSaves.save_slot(battle, "quick")
	var loaded := BattleSaves.read_slot("quick")
	check(saved.ok and loaded.ok, mode + ": damaged building saves and loads")
	if loaded.ok:
		BattleSaves.Snapshot.new().restore(battle, loaded.snapshot)
		check(battle.paused and get_tree().paused, mode + ": load preserves existing paused contract")
		battle.paused = false; get_tree().paused = false
		enemy = battle.buildings.filter(func(b): return b.building_id == "GAPOWR")[0]
		flame = enemy.get_node("DamageFire")
		flame.advance(0.0)
		check(flame.active_count() == 2, mode + ": loaded HP recreates both native fire points")
	var weak_fire: WeakRef = weakref(flame)
	enemy.retire_sold()
	await get_tree().process_frame
	check(weak_fire.get_ref() == null, mode + ": selling frees the fire child")
	battle.buildings = battle.buildings.filter(func(b): return is_instance_valid(b))
	var doomed = battle._place_building("GAPOWR", "enemy", Vector2(1600, 1600), true)
	weak_fire = weakref(doomed.get_node("DamageFire"))
	doomed.receive_hit(doomed.max_hp * 2.0)
	await get_tree().process_frame
	check(weak_fire.get_ref() == null, mode + ": destruction frees the fire child")
	screen.free()
	await get_tree().process_frame
