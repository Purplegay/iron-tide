extends "res://tests/input_ownership_regression.gd"

func point(at: Vector2) -> void:
	await move_pointer(at)
	# The OS can steal focus during first-frame resource loading. Inject the
	# normal focus return before pointer assertions; explicit focus-loss tests
	# below still call refresh directly and retain their original coverage.
	get_window().focus_entered.emit()
	battle.command_cursor.refresh(0.0)

func photo(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	stage.get_texture().get_image().save_png(output_dir.path_join(name + ".png"))

func exercise_mode(mode: String) -> void:
	BattleRequest.configure_skirmish(mode, {"map_size": 3200, "starting_funds": 8000, "fog_of_war": true})
	screen = load("res://scenes/battle.tscn").instantiate()
	stage.add_child(screen)
	battle = screen.battle
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	battle.process_mode = Node.PROCESS_MODE_ALWAYS
	battle.set_process(false)
	battle.set_physics_process(false)
	for child in battle.get_children(): child.process_mode = Node.PROCESS_MODE_DISABLED
	screen.hud.process_mode = Node.PROCESS_MODE_ALWAYS
	screen.hud.set_process(false)
	# Generated ore can overlap the target fixture and correctly take harvest priority.
	for ore in get_tree().get_nodes_in_group("resource_nodes"): ore.queue_free()
	get_window().focus_entered.emit()
	var cursor = battle.command_cursor
	var prefix := mode + ": "
	var tank = battle.spawn_unit("MTNK", "ally", Vector2(1600, 1600))
	var enemy = battle.spawn_unit("MTNK", "enemy", Vector2(1650, 1650))
	var plane = battle.spawn_unit("ORCA", "enemy", Vector2(1700, 1700))
	var miner = battle.spawn_unit("CMIN", "ally", Vector2(1500, 1500))
	for actor in [tank, enemy, plane, miner]: actor.process_mode = Node.PROCESS_MODE_DISABLED
	battle.camera.position = Vector2(1600, 1600)
	battle.camera.reset_smoothing()
	battle.camera.force_update_scroll()
	await get_tree().process_frame
	place_art_at(tank, Vector2(650, 400))
	place_art_at(enemy, Vector2(850, 400))
	place_art_at(plane, Vector2(950, 300))
	place_art_at(miner, Vector2(550, 400))
	if battle.fog != null: battle.fog.rebuild()
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		# Visible art offsets are cached by the first draw, especially aircraft lift.
		place_art_at(tank, Vector2(650, 400))
		place_art_at(enemy, Vector2(850, 400))
		place_art_at(plane, Vector2(950, 300))
		place_art_at(miner, Vector2(550, 400))
		if battle.fog != null: battle.fog.rebuild()
	check(battle._pick_enemy_at(enemy.art_center()) == enemy, prefix + "visible target uses real sprite hit testing")
	battle.clear_selection()
	await point(Vector2(650, 400))
	check(cursor.state == "select" and cursor.sprite.visible, prefix + "friendly hover displays original select cursor")
	check(cursor.sprite.position == Vector2(623, 379), prefix + "select hotspot centered on actual pointer")
	# Exercise the exact Windows cursor image preparation without installing a desktop pointer.
	var selected_frame:AtlasTexture=cursor.sprite.texture
	var native_image:Image=cursor._native_frame(selected_frame)
	check(native_image.get_size()==Vector2i(selected_frame.region.size) and native_image.get_used_rect().has_area() and native_image==cursor._native_frame(selected_frame),prefix+"native cursor reuses a nonempty cropped frame")
	var first: Rect2 = cursor.sprite.texture.region
	cursor.refresh(0.1)
	check(cursor.frame == 1 and cursor.sprite.texture.region != first, prefix + "selection animates distinct original frames")
	await photo(mode + "-select")
	await gesture(Vector2(650, 400), Vector2(650, 400))
	check(battle.selected_units == [tank], prefix + "cursor does not consume actual single selection")
	await point(Vector2(850, 400))
	check(cursor.state == "attack", prefix + "selected armed unit over enemy uses attack cursor")
	check(not tank.attack_ordered, prefix + "hover does not issue an attack")
	await photo(mode + "-attack")
	await mouse_button(Vector2(850, 400), true, false, MOUSE_BUTTON_RIGHT)
	await mouse_button(Vector2(850, 400), false, false, MOUSE_BUTTON_RIGHT)
	check(tank.attack_ordered and tank.attack_target == enemy, prefix + "right click still issues actual focus fire")
	tank.order_stop()
	battle.arm_command("attack")
	await point(Vector2(850, 400))
	check(cursor.state == "attack", prefix + "explicit attack mode uses same target cursor")
	await mouse_button(Vector2(850, 400), true)
	await mouse_button(Vector2(850, 400), false)
	check(tank.attack_target == enemy and battle.command_mode == "", prefix + "explicit left click attacks and leaves targeting mode")
	tank.order_stop()
	# Keep the aircraft inside the live scout radius, then aim at its lifted art.
	var original_miner_pos: Vector2 = miner.global_position
	miner.global_position = plane.global_position + Vector2(65,0)
	if battle.fog != null: battle.fog.rebuild()
	# Newly revealed aircraft can still have their previous ground-level pick frame.
	# Finish the reveal/redraw before deriving a screen coordinate for input.
	await get_tree().process_frame
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
	await point(stage.get_canvas_transform() * plane.art_center())
	check(battle._pick_enemy_at(plane.art_center()) == plane, prefix + "air target fixture is visible and hittable")
	check(cursor.state == "blocked", prefix + "ground-only tank cannot advertise attacking aircraft", cursor.state)
	var ifv = battle.spawn_unit("FV", "ally", tank.position + Vector2(40, 0))
	ifv.process_mode = Node.PROCESS_MODE_DISABLED
	battle.select_unit(ifv, true)
	if battle.fog != null: battle.fog.rebuild()
	cursor.refresh(0.0)
	check(cursor.state == "attack", prefix + "mixed selection can attack if one member has valid weapon domain", cursor.state)
	miner.global_position = original_miner_pos
	battle.select_unit(miner, false)
	await point(Vector2(850, 400))
	check(cursor.state == "blocked", prefix + "harvester cannot advertise attack", cursor.state)
	await photo(mode + "-blocked")
	battle.clear_selection()
	cursor.refresh(0.0)
	check(cursor.state == "arrow", prefix + "no selected attacker gives ordinary pointer over enemy")
	check(cursor.sprite.position == stage.get_mouse_position(), prefix + "arrow hotspot at tip")
	battle.select_unit(tank, false)
	await point(Vector2(1050, 350))
	check(cursor.state == "move", prefix + "selected unit on ground shows movement cursor")
	battle.arm_command("attack_move")
	cursor.refresh(0.0)
	check(cursor.state == "attack_move", prefix + "attack-move has distinct original icon")
	battle.arm_command("")
	for zoom in [0.5, 1.0, 2.0, 4.0]:
		battle.camera.zoom = Vector2(zoom, zoom * 0.5)
		battle.camera.force_update_scroll()
		await get_tree().process_frame
		place_art_at(tank, Vector2(650, 400))
		await point(Vector2(650, 400))
		check(cursor.sprite.texture.get_size() == Vector2(55, 43) and cursor.sprite.position == Vector2(623, 379), prefix + "cursor size/hotspot independent of zoom " + str(zoom))
	var button: Button = screen.hud.deck_tabs_btns["building"]
	await point(button.get_global_rect().get_center())
	check(not cursor.sprite.visible and cursor.state.is_empty(), prefix + "HUD restores ordinary pointer")
	await point(Vector2(650, 400))
	battle.paused = true
	cursor.refresh(0.0)
	check(not cursor.sprite.visible, prefix + "pause hides world cursor")
	battle.paused = false
	battle._on_window_focus_exited()
	cursor.refresh(0.0)
	check(not cursor.sprite.visible, prefix + "focus loss hides world cursor")
	battle._on_window_focus_entered()
	cursor.refresh(0.0)
	check(cursor.sprite.visible, prefix + "focus return restores world cursor")
	battle.ended = true
	cursor.refresh(0.0)
	check(not cursor.sprite.visible, prefix + "result overlay does not retain battle cursor")
	battle.ended = false
	# Fog state must win over stale hover_entity, even without mouse motion.
	battle.camera.zoom = Vector2(2, 1)
	battle.camera.force_update_scroll()
	await get_tree().process_frame
	place_art_at(enemy, Vector2(850, 400))
	for actor in battle.units + battle.buildings:
		if actor.side == "ally": actor.global_position = Vector2(100, 100)
	check(battle.fog != null, prefix + "fog fixture enabled")
	if battle.fog != null:
		battle.fog.rebuild()
		battle.fog.sight_clock += battle.fog.MAX_HELD_SIGHT_SECONDS + 1.0
		battle.fog.rebuild()
		battle.hover_entity = enemy
		await point(Vector2(850, 400))
		check(not battle.actor_visible_to("ally", enemy) and cursor.state == "move", prefix + "unseen enemy does not leak through stale hover cursor")
	check(not cursor._owns_pointer, prefix + "offscreen validation does not hide user's desktop cursor")
	if DisplayServer.get_name()!="headless":
		await check_superweapon_preview()
	screen.free()
	await get_tree().process_frame

func check_superweapon_preview() -> void:
	var aim := Vector2(1550,1550)
	battle.camera.position=aim
	battle.camera.zoom=Iso.cam_zoom(0.8)
	battle.camera.reset_smoothing()
	battle.camera.force_update_scroll()
	battle.fog._reveal("ally",aim,750)
	battle.fog._sync_mask()
	battle.power_low=false
	for row in [["NAIRON","iron",77.0,Color("#f64e50")],["NAMISL","nuke",550.0,Color("#ffb435")]]:
		var source=battle._place_building(row[0],"ally",aim+Vector2(650,500),true)
		source._buildup_play=-1.0
		source._sw_charge=source.sw_recharge()
		battle.arm_superweapon(source)
		await point(stage.get_canvas_transform()*aim)
		battle.hp_overlay.queue_redraw()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var cursor=battle.command_cursor
		check(cursor.sprite.visible and cursor.state==row[1],"viewport pointer uses "+row[1])
		var pic:=stage.get_texture().get_image()
		pic.save_png(output_dir.path_join(str(row[1])+"-aim.png"))
		var edge:=Vector2i(stage.get_canvas_transform()*(aim+Vector2.LEFT.rotated(Iso.eff_angle())*float(row[2])))
		var colored:=false
		for y in range(-4,5):
			for x in range(-4,5):
				var pixel:=pic.get_pixelv(edge+Vector2i(x,y))
				if pixel.r>0.80 and absf(pixel.g-row[3].g)<0.13 and pixel.b<0.42: colored=true
		check(colored,"rendered "+row[1]+" boundary at expected ground distance",edge)
		battle.arm_command("")
