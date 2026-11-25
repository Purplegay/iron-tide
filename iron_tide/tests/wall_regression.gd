extends "res://tests/selection_regression.gd"

const DIRECTIONS := [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]

func exercise_mode(mode: String) -> void:
	BattleRequest.configure_skirmish(mode, {"map_size": 4000, "starting_funds": 10000, "fog_of_war": false})
	screen = load("res://scenes/battle.tscn").instantiate()
	stage.add_child(screen)
	battle = screen.battle
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	# The junction fixture requires bare ground. Generated ore may cover its
	# fixed cells; remove only those random arena props, not placement checks.
	for group in ["resource_nodes", "obstacles"]:
		for node in get_tree().get_nodes_in_group(group):
			if node.position.distance_to(Vector2(2000, 2000)) < 200.0: node.free()
	battle._refresh_pathing()
	GM.god_mode = false
	GM.one_shot_kill = false
	battle.camera.position = Vector2(2000, 2000)
	battle.camera.zoom = Iso.cam_zoom(3.0)
	battle.camera.rotation = Iso.cam_angle()
	battle.camera.reset_smoothing()
	battle.camera.force_update_scroll()
	for id in ["GAWALL", "NAWALL", "GASAND"]:
		await combinations(mode, id)
	await neighbor_changes(mode)
	await navigation_removal(mode)
	await connected_selection(mode)
	screen.free()
	await get_tree().process_frame

func connected_selection(mode: String) -> void:
	for actor in battle.buildings + battle.units:
		if is_instance_valid(actor): actor.free()
	battle.buildings.clear()
	# A frame used to prune destroyed segments also checks victory. Keep the
	# sale test in a live match, with a construction yard on each side.
	battle._place_building("GACNST", "ally", Vector2(400, 400), true)
	battle._place_building("NACNST", "enemy", Vector2(800, 400), true)
	battle.units.clear()
	battle.clear_selection()
	battle.process_mode = Node.PROCESS_MODE_ALWAYS
	battle.set_process(false)
	battle.set_physics_process(false)
	screen.hud.process_mode = Node.PROCESS_MODE_ALWAYS
	screen.hud.set_process(false)
	get_window().focus_entered.emit()
	var center := Vector2(2000, 2000)
	var connected: Array = []
	# Ring plus branch exercises cycles, corners and a junction.
	for offset in [Vector2(0,0), Vector2(1,0), Vector2(2,0), Vector2(2,1), Vector2(2,2), Vector2(1,2), Vector2(0,2), Vector2(0,1), Vector2(-1,0)]:
		connected.append(wall("GAWALL", center + offset * 40))
	var excluded: Array = [wall("GAWALL", center + Vector2(120,120)), wall("GAWALL", center + Vector2(200,0)),
		wall("GAWALL", center + Vector2(120,0), "enemy"), wall("GASAND", center + Vector2(-80,0)),
		wall("GAWALL", center + Vector2(0,-40)), wall("GAWALL", center + Vector2(0,-80))]
	excluded[4].under_construction = true
	await redraw(connected[0])
	var point: Vector2 = stage.get_canvas_transform() * connected[0].art_center()
	check(battle._pick_at(connected[0].art_center()) == connected[0], mode + ": connected wall real click fixture")
	await mouse_button(point, true)
	await mouse_button(point, false)
	check(battle.selected_building == connected[0] and battle.selected_wall_members().size() == 9, mode + ": one real click selects complete ring and branch")
	check(connected.all(func(b): return b.selected), mode + ": every connected segment displays selection")
	check(excluded.all(func(b): return not b.selected), mode + ": gap diagonal enemy material and unfinished bridge excluded")
	check(screen.hud._command_box.get_node_or_null("SellSelectedWalls") != null, mode + ": group has explicit bulk sale button")
	battle.assign_control_group(7)
	check(battle.control_groups["7"].size() == 9, mode + ": control group records every selected wall once")
	battle.clear_selection()
	check(connected.all(func(b): return not b.selected), mode + ": clear removes all highlights")
	battle.select_control_group(7)
	check(battle.selected_wall_members().size() == 9 and connected.all(func(b): return b.selected), mode + ": control group recalls complete wall selection")
	await settle_draw()
	save_picture(mode + "-connected-wall-selection.png")
	var soldier = battle.spawn_unit("E1", "ally", center + Vector2(240,240))
	soldier.process_mode = Node.PROCESS_MODE_DISABLED
	battle.select_unit(soldier, true)
	check(battle.selected_walls.is_empty() and connected.all(func(b): return not b.selected) and battle.selected_units == [soldier], mode + ": shift unit selection clears wall group highlights")
	battle.select_building(excluded[1])
	check(battle.selected_wall_members() == [excluded[1]], mode + ": disconnected segment selects alone")
	battle.select_building(excluded[2])
	check(battle.selected_walls.is_empty(), mode + ": enemy inspection never selects friendly wall group")
	battle.select_building(connected[0])
	var dead = connected.pop_back()
	dead.receive_hit(dead.hp + 1.0)
	battle._process(0.0)
	check(battle.selected_wall_members().size() == 8 and battle.selected_walls.size() == 8, mode + ": destruction prunes selected members")
	# Sale cursor behavior stays single-segment, including within a selected group.
	var single = connected.pop_back()
	check(battle.apply_building_action("sell", single) and battle.selected_wall_members().size() == 7, mode + ": targeted sale removes only one wall")
	check(connected.all(func(b): return not b.is_dead()), mode + ": other selected walls survive targeted sale")
	battle._emit_selection()
	var button: Button = screen.hud._command_box.get_node_or_null("SellSelectedWalls")
	check(button != null and "7" in button.text, mode + ": sale button updates remaining count")
	var before: float = battle.funds
	if button != null: button.pressed.emit()
	check(connected.all(func(b): return b.is_dead()), mode + ": explicit group button sells all selected survivors")
	check(is_equal_approx(battle.funds - before, 7.0 * GameData.ra2_refund(100)), mode + ": group sale refunds each segment exactly once")
	check(battle.selected_building == null and battle.selected_walls.is_empty(), mode + ": group sale clears selection")
	check(excluded.all(func(b): return not b.is_dead()), mode + ": group sale preserves all excluded walls")
	battle.select_control_group(7)
	check(battle.selected_walls.is_empty(), mode + ": sold and dead walls cannot be recalled")

func settle_draw() -> void:
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw

func save_picture(filename: String) -> void:
	if DisplayServer.get_name() != "headless":
		stage.get_texture().get_image().save_png(output_dir.path_join(filename))

func wall(id: String, pos: Vector2, side: String = "ally"):
	var b = battle._place_building(id, side, pos, true)
	b.process_mode = Node.PROCESS_MODE_DISABLED
	b._buildup_play = -1.0
	return b

func remove_wall(b) -> void:
	if is_instance_valid(b):
		battle.buildings.erase(b)
		b.free()

func redraw(b) -> void:
	b.queue_redraw()
	await settle_draw()

func combinations(mode: String, id: String) -> void:
	var center := Vector2(2000, 2000)
	var levels := 2 if id == "GASAND" else 3 # Local art.ini DamageLevels.
	for mask in 16:
		var b = wall(id, center)
		var neighbors := []
		for i in 4:
			if (mask & (1 << i)) != 0:
				neighbors.append(wall(id, center + DIRECTIONS[i] * 40.0))
		var original_rect := Rect2()
		for damage_level in 3:
			b.hp = b.max_hp * [1.0, 0.5, 0.2][damage_level]
			await redraw(b)
			var label := "%s %s mask=%d damage=%d: " % [mode, id, mask, damage_level]
			var expected := mask + mini(damage_level, levels - 1) * 16
			check(b._art_frame == expected, label + "connection and damage groups", b._art_frame)
			check(b._art_aframes == [0], label + "stable healthy anchor")
			var rect := RA2Art.draw_rect(b._ra2, b.radius, b._art_aframes, b._art_lift, b._art_sc)
			if damage_level == 0:
				original_rect = rect
			check(rect == original_rect, label + "damage does not move body")
			check(opaque_pixel_is_pickable(b), label + "current visible wall pixels are selectable")
		var bounds := Placement.aabb(b.footprint_poly())
		check(bounds == Rect2(-20, -20, 40, 40), mode + id + ": wall uses one centered build cell", bounds)
		var collision = null
		for child in b.get_children():
			if child is CollisionPolygon2D:
				collision = child
		check(collision != null and collision.polygon == b.footprint_poly(), mode + id + ": collision matches placement")
		for n in neighbors:
			remove_wall(n)
		remove_wall(b)
		await get_tree().process_frame

func opaque_pixel_is_pickable(b) -> bool:
	var image: Image = b._ra2.get("img")
	if image == null:
		return false
	var src := RA2Art.src_rect(b._ra2, b._art_frame)
	var rect := RA2Art.draw_rect(b._ra2, b.radius, b._art_aframes, b._art_lift, b._art_sc)
	for y in range(0, int(src.size.y), 3):
		for x in range(0, int(src.size.x), 3):
			if image.get_pixelv(Vector2i(src.position) + Vector2i(x, y)).a > 0.9:
				var world: Vector2 = b.position + RA2Art.art_dir(rect.position + (Vector2(x, y) + Vector2(0.5, 0.5)) * b._art_sc)
				return b.hit_test(world)
	return false

func neighbor_changes(mode: String) -> void:
	var center := Vector2(2000, 2000)
	var b = wall("GAWALL", center)
	var other = wall("GAWALL", center + Vector2(40, 0), "enemy")
	await redraw(b)
	check(b._art_frame == 0, mode + ": hostile wall does not connect")
	remove_wall(other)
	other = wall("GASAND", center + Vector2(40, 0))
	await redraw(b)
	check(b._art_frame == 0, mode + ": different wall material does not connect")
	remove_wall(other)
	other = wall("GAWALL", center + Vector2(40, 40))
	await redraw(b)
	check(b._art_frame == 0, mode + ": diagonal wall does not connect")
	remove_wall(other)
	other = wall("GAWALL", center + Vector2(40, 0))
	await redraw(b)
	check(b._art_frame == 1 and other._art_frame == 4, mode + ": new neighbor refreshes both ends")
	other.receive_hit(other.hp + 1.0)
	await settle_draw()
	check(b._art_frame == 0, mode + ": destruction refreshes survivor without manual redraw", b._art_frame)
	battle.buildings = battle.buildings.filter(func(item): return is_instance_valid(item))
	# Walls have BaseNormal=no: placement needs a completed ordinary source.
	var range_source = battle._place_building("GAPOWR", "ally", center + Vector2(-200, -200), true)
	range_source.process_mode = Node.PROCESS_MODE_DISABLED
	# Actual ready-building placement must allow a neighboring cell and consume one item.
	battle._refresh_pathing()
	var data: Dictionary = GameData.get_building("GAWALL")
	var next := center + Vector2(0, 40)
	var ok: Dictionary = battle.build_spot_ok(next, data, true)
	check(ok.ok, mode + ": adjacent wall placement is legal", ok)
	if ok.ok:
		battle.struct_ready["GAWALL"] = 1
		battle.armed_build = "GAWALL"
		battle.preview_override = next
		battle.queue_redraw()
		battle.hp_overlay.queue_redraw()
		await settle_draw()
		save_picture(mode + "-wall-preview.png")
		battle._try_place_building(next)
		await settle_draw()
		check(b._art_frame == 2, mode + ": installed wall connects to original")
		check(int(battle.struct_ready.get("GAWALL", 0)) == 0, mode + ": placement consumes exactly one ready wall")
		for item in battle.buildings.duplicate():
			if is_instance_valid(item) and item != b and item.building_id == "GAWALL" and item.position == next:
				remove_wall(item)
	remove_wall(range_source)
	battle.preview_override = Vector2.INF
	battle.armed_build = ""
	battle.queue_redraw()
	battle.hp_overlay.queue_redraw()
	# Cross junction screenshot uses the actual production renderer and shadow.
	var neighbors := []
	for direction in DIRECTIONS:
		neighbors.append(wall("GAWALL", center + direction * 40.0))
	await redraw(b)
	save_picture(mode + "-wall-junction.png")
	for item in neighbors:
		remove_wall(item)
	remove_wall(b)
	await get_tree().process_frame
	b = wall("GAWALL", center, "enemy")
	other = wall("GAWALL", center + Vector2(40, 0), "enemy")
	await redraw(b)
	check(b._art_frame == 1 and other._art_frame == 4, mode + ": enemy walls also connect")
	remove_wall(other)
	await settle_draw()
	check(b._art_frame == 0, mode + ": direct removal refreshes survivor")
	remove_wall(b)
	b = wall("GAWALL", center)
	other = battle._place_building("GAWALL", "ally", center + Vector2(40, 0), false)
	other.process_mode = Node.PROCESS_MODE_DISABLED
	await redraw(b)
	check(b._art_frame == 0, mode + ": unfinished neighbor does not connect")
	other._process(other.build_total)
	await settle_draw()
	check(not other.under_construction and b._art_frame == 1, mode + ": finishing construction refreshes connection")
	remove_wall(other)
	remove_wall(b)
	await get_tree().process_frame

func navigation_removal(mode: String) -> void:
	battle._refresh_pathing()
	var position := Vector2.INF
	for x in range(25, 75):
		var candidate := Vector2(x * 40, 2400)
		if not battle.path_service.is_blocked(candidate) and not battle.path_service.in_water(candidate):
			position = candidate
			break
	check(position.is_finite(), mode + ": open land navigation fixture")
	if not position.is_finite():
		return
	var b = wall("GAWALL", position)
	var retained = wall("GAWALL", position + Vector2(160, 0))
	check(battle.path_service.is_blocked(position), mode + ": placed wall blocks navigation")
	b.receive_hit(b.hp + 1.0)
	await get_tree().process_frame
	await get_tree().process_frame
	check(not battle.path_service.is_blocked(position), mode + ": destroyed isolated wall releases navigation")
	check(battle.path_service.is_blocked(retained.position), mode + ": surviving building remains a blocker")
	remove_wall(retained)
	battle._refresh_pathing()
	b = wall("GAPOWR", position)
	check(battle.path_service.is_blocked(position), mode + ": ordinary building blocks navigation")
	b.receive_hit(b.hp + 1.0)
	await get_tree().process_frame
	await get_tree().process_frame
	check(not battle.path_service.is_blocked(position), mode + ": ordinary building destruction also refreshes navigation")
	b = wall("GAWALL", position)
	retained = wall("GAWALL", position + Vector2(160, 0))
	var epoch: int = battle.path_service.epoch
	b.receive_hit(b.hp + 1.0)
	retained.receive_hit(retained.hp + 1.0)
	await get_tree().process_frame
	await get_tree().process_frame
	check(battle.path_service.epoch == epoch + 1, mode + ": simultaneous destruction batches one terrain rebuild")
