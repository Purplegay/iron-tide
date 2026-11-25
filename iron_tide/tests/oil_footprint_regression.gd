extends "res://tests/special_mechanics_regression.gd"

func _ready() -> void:
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not ProjectSettings.get_setting("application/config/use_custom_user_dir", false):
		get_tree().quit(2)
		return
	await get_tree().process_frame
	for mode in [MatchRules.RA2, MatchRules.EXTENDED]:
		if mode == MatchRules.EXTENDED and not MetaProgress.technology_owned("repair_all"):
			var repair := MetaProgress.technology_definition("repair_all")
			MetaProgress.grant(repair.currency, repair.cost)
			check(MetaProgress.research_technology("repair_all"), "unlock repair all")
		arena(mode)
		var site = Sites.create(battle, "CAOILD", AIM)
		var plant := GameData.get_building("GAPOWR")
		var point := AIM + Vector2(120, 0)
		for side in ["ally", "enemy"]:
			check(not battle.build_spot_ok(point, plant, true, side).ok, prefix + "neutral well offers no territory to " + side)
		var rect := RA2Art.draw_rect(site._ra2, site.radius, [0], 0, Building.RA2_SPRITE_SCALE)
		var pad := rect.position + Vector2(124.5, 89.5) * Building.RA2_SPRITE_SCALE
		var arm := rect.position + Vector2(88.5, 50.5) * Building.RA2_SPRITE_SCALE
		var outside := rect.position + Vector2(155.5, 30.5) * Building.RA2_SPRITE_SCALE
		var collider: CollisionPolygon2D = site.find_children("*", "CollisionPolygon2D", false, false)[0]
		check(Geometry2D.is_point_in_polygon(Building.art_to_ground(pad), collider.polygon), prefix + "pump base impassable")
		battle._refresh_pathing()
		var path = battle.path_service
		var cell: Vector2i = path._cell_of(AIM + Building.art_to_ground(pad))
		check(path.cost[cell.y * path.cols + cell.x] < 0, prefix + "navigation blocks pump base")
		check(not Geometry2D.is_point_in_polygon(Building.art_to_ground(arm), collider.polygon), prefix + "overhanging arm outside ground blocker")
		check(site.hit_test(AIM + RA2Art.art_dir(arm)), prefix + "visible pump arm selectable")
		check(not site.hit_test(AIM + RA2Art.art_dir(outside)), prefix + "clear grass remains clickable as terrain")
		var worker = spawn("ENGINEER", "ally", AIM + Vector2(120, 0))
		battle.select_unit(worker, false)
		battle._issue_order(AIM + RA2Art.art_dir(pad))
		check(worker.special.get("target") == site and worker.special.get("action") == "allied_engineer", prefix + "right-click pump foundation orders capture")
		check(not battle.apply_building_action("repair", site), prefix + "neutral derrick rejects wrench")
		worker.position = AlliedAbilities.approach(worker, site)
		AlliedAbilities.tick_action(worker, 0.1)
		check(site.side == "ally" and worker._dead, prefix + "engineer captured derrick")
		check(not battle.apply_building_action("repair", site) and not battle.apply_building_action("sell", site), prefix + "full or sale blocked")
		site.hp -= 16
		var hp_before: float = site.hp
		check(battle.apply_building_action("repair", site) and site.repairing, prefix + "start wrench")
		GM.infinite_funds = false
		battle.funds = 0
		site._process_building_repair(0.96)
		check(site.hp == hp_before and site.repair_waiting_funds, prefix + "repair waits for money")
		battle.funds = 10
		site._process_building_repair(0.96)
		check(site.hp == hp_before + 8 and battle.funds == 9, prefix + "one credit per repair tick")
		check(battle.apply_building_action("repair", site) and not site.repairing, prefix + "cancel wrench")
		battle.repair_all_buildings()
		check(site.repairing == (mode == MatchRules.EXTENDED), prefix + "mass repair obeys mode")
		if site.repairing:
			site._process_building_repair(0.96)
			check(site.hp == site.max_hp and not site.repairing, prefix + "repair ends at full")
		site.hp = site.max_hp - 128
		var crew = spawn("SENGINEER", "ally", AIM + Vector2(120, 0))
		crew.position = AlliedAbilities.approach(crew, site)
		crew.order_interaction("allied_engineer", site, false)
		AlliedAbilities.tick_action(crew, 0.1)
		check(site.hp == site.max_hp and crew._dead, prefix + "engineer repairs to full")
		await get_tree().process_frame
		site._fp_poly = PackedVector2Array([Vector2.ZERO, Vector2.RIGHT, Vector2.DOWN])
		var snapshot := Snapshot.new().capture(battle)
		Snapshot.new().restore(battle, snapshot)
		site = battle.buildings.filter(func(b): return b.building_id == "CAOILD")[0]
		check(Geometry2D.is_point_in_polygon(Building.art_to_ground(pad), site.footprint_poly()), prefix + "load replaces undersized historic pad")
		get_tree().paused = false
		battle.paused = false
		battle.select_building(site)
		var preview = battle.build_range_preview
		preview.update(battle)
		var cell_id := Vector2i(point / battle.BUILD_GRID)
		check(preview.cells.has(cell_id) and battle.build_spot_ok(point, plant, true).ok, prefix + "restored player well shows buildable grid on selection")
		check(not battle.build_spot_ok(AIM, plant, true).ok and not battle.build_spot_ok(AIM + Vector2(400, 0), plant, true).ok, prefix + "occupied footprint and distant cells remain blocked")
		check(not battle.build_spot_ok(point, plant, true, "enemy").ok, prefix + "enemy cannot use player territory")
		battle.struct_ready.GAPOWR = 1
		battle.armed_build = "GAPOWR"
		battle._try_place_building(point)
		var placed: Array = battle.buildings.filter(func(b): return b.building_id == "GAPOWR" and b.position == point)
		check(placed.size() == 1 and not battle.struct_ready.has("GAPOWR"), prefix + "ready power plant placed beside oil")
		for b in placed:
			battle.buildings.erase(b)
			b.free()
		var initial_funds: float = battle.funds
		site.special.oil_elapsed = 0.0
		for tick in 399: Sites.oil_income(site, 1.0 / 60.0)
		check(battle.funds == initial_funds, prefix + "no payment before 100 rule ticks")
		Sites.oil_income(site, 1.0 / 60.0)
		check(battle.funds == initial_funds + 20, prefix + "20 credits on first period boundary")
		for tick in 3200: Sites.oil_income(site, 1.0 / 60.0)
		check(battle.funds == initial_funds + 180, prefix + "one minute pays nine installments at normal speed")
		AlliedAbilities.change_side(site, "enemy")
		battle.armed_build = "GAPOWR"
		preview.update(battle)
		check(not preview.cells.has(cell_id) and not battle.build_spot_ok(point, plant, true).ok and battle.build_spot_ok(point, plant, true, "enemy").ok, prefix + "capture transfers placement rights and overlay")
		spawn("E1", "ally", AIM + Vector2(245, 0))
		if battle.fog != null: battle.fog.rebuild()
		site._die()
		var rings: Array = battle.effects_root.get_children().filter(func(fx): return fx is Ra2Fx and fx.anim.get("image") == "RING1")
		check(rings.size() == 1 and rings[0].anim.tex != null and rings[0].anim.count == 21, prefix + "oil death plays retail ring texture once")
		var scrap: Array = battle.allied_state.get("yr_vehicle_debris", [])
		check(scrap.size() >= 4 and scrap.size() <= 8 and scrap.all(func(piece): return piece.kind == "shp" and ResourceLoader.exists("res://assets/ra2/death/%s.png" % piece.id)), prefix + "four to eight native textured fragments")
		var ruins := get_tree().get_nodes_in_group("yr_building_rubble")
		check(ruins.size() == 1 and ruins[0].rubble_texture != null, prefix + "oil leaves textured ISO rubble")
		check(not battle.build_spot_ok(point, plant, true, "enemy").ok, prefix + "destroyed well loses construction territory")
		if DisplayServer.get_name() != "headless" and not rings.is_empty():
			battle.camera.position = AIM
			battle.camera.zoom = Iso.cam_zoom(2.0)
			battle.camera.reset_smoothing()
			battle.camera.force_update_scroll()
			rings[0]._process(0.8)
			for fx in get_tree().get_nodes_in_group("yr_death_effects"):
				fx._process(0.25)
			var debris = battle.effects_root.get_node("YrVehicleDebris")
			for tick in 24: debris.advance(1.0 / 60.0)
			debris.queue_redraw()
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			battle.get_viewport().get_texture().get_image().save_png(output_dir.path_join(mode + "-oil.png"))
			for tick in 360: debris.advance(1.0 / 60.0)
			debris.queue_redraw()
			rings[0]._process(6.0)
			for fx in get_tree().get_nodes_in_group("yr_death_effects"):
				if not fx.is_queued_for_deletion(): fx._process(8.0)
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			battle.get_viewport().get_texture().get_image().save_png(output_dir.path_join(mode + "-rubble.png"))
		await finish()
		await oil_skirmish(mode)
	var report := FileAccess.open(output_dir.path_join("result.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks": checks, "failed": failed}, "  "))
	report.close()
	get_tree().quit(0 if failed == 0 else 1)
