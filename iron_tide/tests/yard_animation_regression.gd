extends "res://tests/soviet_opening_regression.gd"

func _ready() -> void:
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not ProjectSettings.get_setting("application/config/use_custom_user_dir", false):
		get_tree().quit(2)
		return
	await get_tree().process_frame
	for country in ["美国", "苏俄"]:
		start_soviet(country, "soviet" if country == "美国" else "allied", "prebuilt")
		await exercise_yards()
		await finish()
	var report := FileAccess.open(output_dir.path_join("result.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks": checks, "failed": failed}, "  "))
	report.close()
	get_tree().quit(0 if failed == 0 else 1)

func exercise_yards() -> void:
	var id: String = battle.roster_id("GAPOWR", "ally")
	var yard = actor(battle.roster_id("GACNST", "ally"), "ally")
	var enemy = actor(battle.roster_id("GACNST", "enemy"), "enemy")
	check(yard != null and enemy != null, "both starting construction yards exist")
	if yard == null or enemy == null: return
	var tag: String = yard.building_id + " "
	battle.camera.position = yard.position
	battle.camera.zoom = Iso.cam_zoom(1.4)
	battle.camera.reset_smoothing()
	battle.camera.force_update_scroll()
	check(yard._layer_visible("activeanim") and not yard._layer_visible("productionanim"), tag + "idle at opening")
	if yard.building_id == "NACNST":
		check(yard._anim_kinds().has("idleanim") and yard._layer_visible("idleanim"), tag + "idle crane visible with lights")
	await capture_yard(tag.strip_edges() + "-idle")
	battle.request_structure(id)
	battle._tick_structure_queue(0.1)
	check(not yard._layer_visible("productionanim"), tag + "no delivery while paying")
	battle._tick_structure_queue(120)
	battle.request_structure(id)
	battle._try_place_building(yard.position)
	check(battle.armed_build == id and battle.struct_ready.has(id) and not yard._layer_visible("productionanim"), tag + "blocked footprint retains order without crane")
	var spot := placement(id, "ally")
	check(spot != Vector2.INF, tag + "legal paid placement available")
	if spot == Vector2.INF: return
	var total: int = battle.buildings.size()
	var funds: float = battle.funds
	battle._try_place_building(spot)
	check(battle.buildings.size() == total + 1 and not battle.struct_ready.has(id) and is_equal_approx(funds, battle.funds), tag + "single delivery of paid building")
	check(yard._production_anim_t == 0 and not enemy._layer_visible("productionanim"), tag + "only own crane starts")
	var layer: Dictionary = yard._ra2_anim.filter(func(lay): return lay.kind == "productionanim")[0]
	yard._process(1.8)
	check(yard._layer_visible("productionanim") and yard._layer_visible("activeanim") and not yard._layer_visible("idleanim") and yard._anim_frame_for(layer, yard._anim_layer(layer)) > 0, tag + "moving crane replaces idle pose")
	await capture_yard(tag.strip_edges() + "-delivery")
	var elapsed: float = yard._production_anim_t
	var saved := BattleSaves.save_slot(battle, "slot1")
	var loaded := BattleSaves.read_slot("slot1")
	check(saved.ok and loaded.ok, tag + "mid-delivery game saved")
	if saved.ok and loaded.ok:
		BattleSaves.Snapshot.new().restore(battle, loaded.snapshot)
		yard = actor(battle.roster_id("GACNST", "ally"), "ally")
		enemy = actor(battle.roster_id("GACNST", "enemy"), "enemy")
		check(is_equal_approx(yard._production_anim_t, elapsed) and yard._layer_visible("productionanim"), tag + "saved delivery phase restored")
	yard._process(yard._production_anim_duration)
	check(not yard._layer_visible("productionanim") and yard._layer_visible("activeanim") and yard._layer_visible("idleanim"), tag + "idle restored")
	var enemy_id: String = battle.roster_id("GAPOWR", "enemy")
	battle.request_structure(enemy_id, "enemy")
	battle._tick_structure_queue(120)
	battle.skirmish_ai._try_build()
	check(enemy._layer_visible("productionanim") and not battle.enemy_struct_ready.has(enemy_id) and not yard._layer_visible("productionanim"), tag + "paid AI delivery uses opposite yard")

func capture_yard(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png(output_dir.path_join(label + ".png")) == OK, label + " capture")
