extends "res://tests/selection_regression.gd"
## Real battle, actors, placement entry and collision shapes; no replacement placement rules.

func exercise_mode(mode: String) -> void:
	BattleRequest.configure_skirmish(mode, {"map_size": 3200, "starting_funds": 8000})
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
	var prefix := mode + ": "
	for id in GameData.ra2_art:
		var sprite_path := GameData.ra2_sprite_path(id)
		if not sprite_path.is_empty():
			var art := RA2Art.art(id)
			check(art.get("tex") != null and RA2Art.frame_size(art).x > 0.0 and RA2Art.frame_size(art).y > 0.0,
				prefix + id + " declared sprite loads with valid frame")
		var cameo_path := GameData.ra2_cameo_path(id)
		if not cameo_path.is_empty():
			check(load(cameo_path) is Texture2D, prefix + id + " declared cameo imports")
	for id in GameData.building_index:
		var bd := GameData.get_building(id)
		var actor := Building.new()
		actor.setup(bd, "enemy", Vector2(2500, 2500), battle, true)
		var expected := Building.placement_poly(bd)
		check(expected.size() >= 3 and actor.footprint_poly() == expected,
			prefix + id + " preview and actual footprint agree")
		var collision: CollisionPolygon2D = null
		for child in actor.get_children():
			if child is CollisionPolygon2D:
				collision = child
		check(collision != null and collision.polygon == expected,
			prefix + id + " collision matches placement footprint")
		actor.free()
	var fallback := Building.placement_poly({"id": "__missing__", "foundation": "2x3", "radius": 99.0})
	check(Placement.aabb(fallback).size.is_equal_approx(Vector2(57.6, 86.4)),
		prefix + "missing sprite uses existing foundation scale")
	# Find a naturally legal gap in the generated base, without bypassing checks.
	var bd := GameData.get_building("GAPOWR")
	var hq = battle._player_hq()
	var spot := Vector2.INF
	for x in range(-10, 11):
		for y in range(-10, 11):
			var candidate: Vector2 = battle.snap_build_pos(hq.position + Vector2(x, y) * 40.0)
			if battle.build_spot_ok(candidate, bd, true).ok:
				spot = candidate
				break
		if spot.is_finite():
			break
	check(spot.is_finite(), prefix + "legal placement fixture")
	if not spot.is_finite():
		screen.free()
		return
	var original_color := HouseColor.player_id
	HouseColor.set_player_id("purple")
	battle.struct_ready["GAPOWR"] = 1
	battle.set_build_mode("GAPOWR")
	await show_preview(mode + "-legal", spot)
	check_ghost_house(HouseColor.player_color(), true, prefix + "legal building")
	HouseColor.set_player_id("red")
	for zoom in [0.5, 1.0, 4.0]:
		await show_preview(mode + "-legal-zoom-" + str(zoom), spot, zoom)
	await reject(prefix + "map edge", Vector2.ZERO, bd, "超出地图边界")
	await reject(prefix + "existing building", hq.position, bd, "与建筑重叠")
	var poly := Building.placement_poly(bd)
	var center: Vector2 = spot + Placement.aabb(poly).get_center()
	var rock := Obstacle.new()
	rock.position = center
	rock.radius = 12.0
	battle.add_child(rock)
	await reject(prefix + "rock", spot, bd, "地形不可建")
	await show_preview(mode + "-blocked", spot)
	check_ghost_house(HouseColor.player_color(), false, prefix + "blocked building follows changed house color")
	rock.free()
	var ore := ResourceNode.new()
	ore.position = center
	ore.radius = 12.0
	battle.add_child(ore)
	await reject(prefix + "ore", spot, bd, "与矿点重叠")
	ore.free()
	var soldier = battle.spawn_unit("E1", "ally", center)
	soldier.process_mode = Node.PROCESS_MODE_DISABLED
	await reject(prefix + "ground unit", spot, bd, "与单位重叠")
	soldier.free()
	var original_water: Array = battle.path_service.water_rects.duplicate()
	battle.path_service.set_water([Placement.aabb(poly, spot).grow(10.0)])
	await reject(prefix + "water", spot, bd, "不能建在水面")
	battle.path_service.set_water(original_water)
	var yard := GameData.get_building("GAYARD")
	var remote := Vector2.INF
	for x in range(400, 2800, 160):
		for y in range(400, 2800, 160):
			var candidate := Vector2(x, y)
			if battle.build_spot_ok(candidate, bd, true).reason == "超出建造范围，请靠近己方建筑或盟友建造场" and \
				battle.build_spot_ok(candidate, yard, true).reason == "船坞必须建在水面":
				remote = candidate
				break
		if remote.is_finite():
			break
	check(remote.is_finite(), prefix + "clear remote land fixture for adjacency and shipyard")
	if remote.is_finite():
		await reject(prefix + "no adjacency", remote, bd, "超出建造范围，请靠近己方建筑或盟友建造场")
		check(battle.build_spot_ok(remote, yard, true).reason == "船坞必须建在水面",
			prefix + "shipyard rejects clear dry land")
	var saved_funds: float = battle.funds
	battle.funds = 0.0
	check(battle.build_spot_ok(spot, bd, false).reason == "资金不足", prefix + "unpaid construction requires funds")
	check(battle.build_spot_ok(spot, bd, true).ok, prefix + "paid ready building needs no extra funds")
	var count_before: int = battle.buildings.size()
	# Actual viewport mouse input -> battle placement -> inventory and physical actor.
	battle.camera.position = spot
	battle.camera.zoom = Vector2(2, 1)
	battle.camera.reset_smoothing()
	battle.camera.force_update_scroll()
	await get_tree().process_frame
	var at: Vector2 = stage.get_canvas_transform() * spot
	var approach := InputEventMouseMotion.new()
	approach.position = at
	approach.global_position = at
	stage.push_input(approach, true)
	await get_tree().process_frame
	await mouse_button(at, true)
	await mouse_button(at, false)
	check(battle.buildings.size() == count_before + 1 and battle.armed_build.is_empty(),
		prefix + "green preview commits through real mouse input")
	check(int(battle.struct_ready.get("GAPOWR", 0)) == 0 and battle.funds == 0.0,
		prefix + "placement consumes one ready item with no duplicate charge")
	var placed = battle.buildings[-1]
	check(placed.material == battle._build_ghost_layer.material and placed._col.is_equal_approx(HouseColor.player_color()),
		prefix + "placed building and preview share house material")
	check(placed.position.is_equal_approx(spot) and placed.footprint_poly() == poly,
		prefix + "committed location and footprint match preview")
	battle.funds = saved_funds
	battle.set_build_mode("GATECH")
	await show_preview(mode + "-fallback", spot + Vector2(160, 0))
	# Cancellation exits placement without consuming another paid building.
	battle.struct_ready["GATECH"] = 1
	screen.hud.armed_escape()
	check(battle.armed_build.is_empty() and battle.struct_ready["GATECH"] == 1,
		prefix + "cancel keeps ready inventory")
	battle.queue_redraw()
	await get_tree().process_frame
	check(battle._build_ghosts.is_empty(), prefix + "cancel clears preview")
	HouseColor.set_player_id(original_color)
	screen.free()
	await get_tree().process_frame

func check_ghost_house(color: Color, legal: bool, label: String) -> void:
	var material: ShaderMaterial = battle._build_ghost_layer.material
	check(battle._build_ghosts.size() == 1 and battle._build_ghosts[0].ok == legal
		and material != null and color.is_equal_approx(material.get_shader_parameter("target_color"))
		and battle.material != material, label)

func reject(label: String, pos: Vector2, bd: Dictionary, reason: String) -> void:
	var result: Dictionary = battle.build_spot_ok(battle.snap_build_pos(pos), bd, true)
	check(not result.ok and result.reason == reason, label + " gives precise reason", result)
	var count_before: int = battle.buildings.size()
	var funds_before: float = battle.funds
	battle._try_place_building(pos)
	check(battle.buildings.size() == count_before and battle.struct_ready.get("GAPOWR", 0) == 1
		and battle.funds == funds_before and battle.armed_build == "GAPOWR",
		label + " cannot place or consume ready stock")

func show_preview(label: String, pos: Vector2, zoom: float = 2.0) -> void:
	battle.preview_override = pos
	battle.camera.position = pos
	battle.camera.zoom = Vector2(zoom, zoom * 0.5)
	battle.camera.reset_smoothing()
	battle.camera.force_update_scroll()
	battle.queue_redraw()
	battle.hp_overlay.queue_redraw()
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		check(stage.get_texture().get_image().save_png(output_dir.path_join(label + ".png")) == OK,
			"save " + label)
	battle.preview_override = Vector2.INF
