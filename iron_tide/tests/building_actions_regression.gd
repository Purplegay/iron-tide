extends "res://tests/cursor_regression.gd"

var sold_deaths := 0

func click_action(at: Vector2) -> void:
	await move_pointer(at)
	await mouse_button(at, true)
	check(not battle.dragging, "building action/UI click must not start a selection drag")
	await mouse_button(at, false)

func exercise_mode(mode: String) -> void:
	if mode == MatchRules.EXTENDED and not MetaProgress.technology_owned("repair_all"):
		MetaProgress.grant("credits", 1200)
		check(MetaProgress.research_technology("repair_all"), "research mass repair before starting extended match")
	BattleRequest.configure_skirmish(mode, {"map_size": 3200, "starting_funds": 8000, "fog_of_war": false})
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
	GM.infinite_funds = false
	GM.infinite_power = false
	get_window().focus_entered.emit()
	var prefix := mode + ": "
	var plant = battle._place_building("GAPOWR", "ally", Vector2(1600, 1600), true)
	var factory = battle._place_building("GAWEAP", "ally", Vector2(1900, 1600), true)
	var enemy = battle._place_building("GAPOWR", "enemy", Vector2(2300, 1600), true)
	var wall = battle._place_building("GAWALL", "ally", Vector2(2400, 1600), true)
	for b in [plant, factory, enemy, wall]:
		b.process_mode = Node.PROCESS_MODE_DISABLED
		b._buildup_play = -1.0
		b.queue_redraw()
	battle.camera.position = Vector2(1600, 1600)
	battle.camera.reset_smoothing()
	battle.camera.force_update_scroll()
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
	place_art_at(plant, Vector2(600, 350))
	place_art_at(factory, Vector2(900, 350))
	await get_tree().process_frame
	check(battle._pick_building_at(plant.art_center()) == plant, prefix + "building pixel hit-test fixture")
	var hud = screen.hud
	for size in [Vector2i(1280, 720), Vector2i(1600, 900)]:
		stage.size = size
		await get_tree().process_frame
		for action in ["repair", "repair_all", "sell"]:
			var button: Button = hud.building_action_buttons[action]
			if action == "repair_all" and mode == MatchRules.RA2:
				check(not button.is_visible_in_tree(), prefix + "classic sidebar omits mass repair")
				continue
			check(button.is_visible_in_tree() and Rect2(Vector2.ZERO, Vector2(size)).encloses(button.get_global_rect()), prefix + "%s permanent button fits %s" % [action, size])
	stage.size = Vector2i(1600, 900)
	hud._toggle_unit_menu()
	await get_tree().process_frame
	check(hud.unit_menu_collapsed and hud.building_action_buttons.repair.is_visible_in_tree(), prefix + "repair survives collapsed unit menu")
	battle.clear_selection()
	var all_button: Button = hud.building_action_buttons.repair_all
	plant.hp -= 30
	factory.hp -= 40
	wall.hp -= 10
	enemy.hp -= 20
	var initial_funds: float = battle.funds
	if mode == MatchRules.EXTENDED:
		battle.arm_command("sell")
		await click_action(all_button.get_global_rect().get_center())
		check(plant.repairing and factory.repairing and not wall.repairing and not enemy.repairing, prefix + "one click schedules only eligible damaged friendly structures")
		check(battle.command_mode == "" and battle.funds == initial_funds and battle.selected_units.is_empty(), prefix + "instant action requires no selection or upfront payment")
		plant._process_building_repair(0.5)
		var partial: float = plant._building_repair_elapsed
		await click_action(all_button.get_global_rect().get_center())
		check(plant.repairing and plant._building_repair_elapsed == partial and partial > 0, prefix + "repeat click preserves repair progress")
		plant.set_repairing(false)
		factory.set_repairing(false)
		factory.under_construction = true
		plant.hp = plant.max_hp
		await click_action(all_button.get_global_rect().get_center())
		check(not plant.repairing and not factory.repairing, prefix + "skip full and unfinished structures")
	else:
		battle.repair_all_buildings()
		check(not plant.repairing and not factory.repairing, prefix + "classic command rejects mass repair")
		plant.hp = plant.max_hp
	factory.under_construction = false
	factory.hp = factory.max_hp
	var button_at: Vector2 = hud.building_action_buttons.repair.get_global_rect().get_center()
	await click_action(button_at)
	check(battle.command_mode == "repair" and hud.building_action_buttons.repair.button_pressed, prefix + "real sidebar click arms without selection")
	battle._emit_selection()
	check(battle.command_mode == "repair", prefix + "empty selection refresh preserves building mode")
	check(battle.command_cursor.resolve(plant.art_center()) == "repair_blocked", prefix + "full-health cursor rejects repair")
	plant.hp = plant.max_hp - 20.0
	await point(stage.get_canvas_transform() * plant.art_center())
	check(battle.command_cursor.state == "repair", prefix + "damaged building uses original wrench")
	check(battle.command_cursor.metadata.sequences.repair.start == 170 and battle.command_cursor.metadata.sequences.sell.start == 129, prefix + "source cursor frame mapping")
	var plant_at: Vector2 = stage.get_canvas_transform() * plant.art_center()
	Ra2Sfx.stop_eva()
	Ra2Sfx._eva_last.clear()
	await click_action(plant_at)
	check(plant.repairing and battle.command_mode == "repair", prefix + "world click starts repair and keeps mode")
	check_eva("EVA_Repairing", prefix)
	var hp_before: float = plant.hp
	var funds_before: float = battle.funds
	var per_hp: float = float(plant.data.cost) / plant.max_hp * 0.15
	plant._process_building_repair(0.95)
	check(plant.hp == hp_before and battle.funds == funds_before, prefix + "no heal or charge before original interval")
	plant._process_building_repair(0.01)
	check(is_equal_approx(plant.hp, hp_before + 8.0) and is_equal_approx(battle.funds, funds_before - per_hp * 8.0), prefix + "original RepairStep/Rate/Percent consumed")
	await photo(mode + "-repair")
	plant._process_building_repair(1.92)
	check(plant.hp == plant.max_hp and not plant.repairing and is_equal_approx(battle.funds, funds_before - per_hp * 20.0), prefix + "partial final step charges only healed HP and stops at full")
	plant._process_building_repair(10.0)
	check(is_equal_approx(battle.funds, funds_before - per_hp * 20.0), prefix + "full health never drains cash")
	plant.hp -= 20.0
	battle.apply_building_action("repair", plant)
	await click_action(plant_at)
	check(not plant.repairing, prefix + "second world click cancels repair")
	battle.apply_building_action("repair", plant)
	battle.funds = 0.0
	hp_before = plant.hp
	plant._process_building_repair(100.0)
	check(plant.repairing and plant.repair_waiting_funds and plant.hp == hp_before and battle.funds == 0.0, prefix + "cash stall keeps active repair without free healing")
	await photo(mode + "-waiting-funds")
	battle.credit_side("ally", 100.0)
	plant._process_building_repair(0.95)
	check(plant.hp == hp_before, prefix + "cash return cannot spend accumulated stalled time")
	plant._process_building_repair(0.01)
	check(plant.hp == hp_before + 8.0 and not plant.repair_waiting_funds, prefix + "cash return resumes one paid step")
	hp_before = plant.hp
	funds_before = battle.funds
	battle.paused = true
	plant._process_building_repair(10.0)
	check(plant.hp == hp_before and battle.funds == funds_before and not battle.apply_building_action("sell", plant), prefix + "pause prevents healing and sale")
	battle.paused = false
	plant._process_building_repair(-10.0)
	check(plant.hp == hp_before and battle.funds == funds_before, prefix + "negative time is inert")
	for action in ["repair", "sell"]:
		check(not battle.apply_building_action(action, enemy), prefix + action + " cannot act on enemies")
		check(not battle.apply_building_action(action, null), prefix + action + " empty target rejected")
		factory.under_construction = true
		check(not battle.apply_building_action(action, factory), prefix + action + " unfinished target rejected")
		factory.under_construction = false
	wall.hp -= 10.0
	check(not battle.apply_building_action("repair", wall), prefix + "Repairable=false wall rejected")
	var extra: Dictionary = GameData.ra2_source_buildings.GAWEAP.extra
	var previous_unsellable = extra.get("Unsellable")
	extra["Unsellable"] = "yes"
	check(not battle.apply_building_action("sell", factory), prefix + "Unsellable source flag rejected")
	if previous_unsellable == null: extra.erase("Unsellable")
	else: extra["Unsellable"] = previous_unsellable
	await key(KEY_L)
	check(battle.command_mode == "sell" and not hud.building_action_buttons.repair.button_pressed and hud.building_action_buttons.sell.button_pressed, prefix + "L switches mutually exclusive modes")
	# GAWEAP's padded SHP centre can be transparent. Target a visible roof pixel.
	var factory_roof: Vector2 = factory.art_center() + RA2Art.art_dir(Vector2(20, 25))
	check(factory.hit_test(factory_roof), prefix + "factory roof pixel is opaque")
	await point(stage.get_canvas_transform() * factory_roof)
	check(battle.command_cursor.state == "sell", prefix + "eligible factory uses original sale cursor")
	check(battle.command_cursor.resolve(enemy.art_center()) == "sell_blocked", prefix + "enemy uses forbidden sale cursor")
	await photo(mode + "-sell")
	factory.production = ["MTNK", "FV"]
	factory.production_paid = 123.5
	factory.progress = 2.0
	battle.select_building(factory)
	battle.rally_points[factory.get_instance_id()] = Vector2(1000, 1000)
	funds_before = battle.funds
	var refund: float = float(GameData.ra2_refund(int(factory.data.cost))) + 123.5
	sold_deaths = 0
	var death_callback := func(_actor): sold_deaths += 1
	Events.unit_died.connect(death_callback)
	battle._refresh_pathing()
	battle._update_power()
	var drain_before: float = battle.power_drain
	var factory_power: float = factory.power
	var factory_pos: Vector2 = factory.position
	check(battle.path_service.is_blocked(factory_pos), prefix + "factory footprint blocks path before sale")
	# Invoke the actual targeting handler, then repeat before deferred deletion.
	Ra2Sfx.stop_eva()
	Ra2Sfx._eva_last.clear()
	battle._issue_command_at(factory_roof)
	check_eva("EVA_StructureSold", prefix)
	check(is_equal_approx(battle.funds, funds_before + refund), prefix + "sale refunds configured price fraction plus actual paid production")
	check(sold_deaths == 0 and factory.is_dead() and factory.is_queued_for_deletion() and factory.production.is_empty(), prefix + "sale retires without a death event or surviving jobs")
	check(not battle.apply_building_action("sell", factory) and is_equal_approx(battle.funds, funds_before + refund), prefix + "same-frame duplicate sale cannot refund twice")
	check(not battle.buildings.has(factory) and not battle.rally_points.has(factory.get_instance_id()) and battle.selected_building == null and battle.command_mode == "sell", prefix + "sale clears selection and rally while preserving sale mode")
	check(not battle.path_service.is_blocked(factory_pos) and is_equal_approx(battle.power_drain, drain_before + factory_power), prefix + "sale immediately clears path footprint and power drain")
	await check_sale_animation(factory_pos, mode + "-factory", prefix)
	Events.unit_died.disconnect(death_callback)
	funds_before = battle.funds
	refund = float(GameData.ra2_refund(int(plant.data.cost)))
	var plant_pos: Vector2 = plant.position
	await click_action(stage.get_canvas_transform() * plant.art_center())
	check(is_equal_approx(battle.funds, funds_before + refund) and battle.command_mode == "sell", prefix + "actual world mouse click sells a second building")
	await check_sale_animation(plant_pos, mode + "-power", prefix)
	for yard_id in ["NACNST","GACNST"]:
		var yard=battle._place_building(yard_id,"ally",plant_pos,true)
		yard._buildup_play=-1
		var yard_point:Vector2=yard.art_center()
		if not yard.hit_test(yard_point):yard_point=yard.position
		check(battle.command_cursor.resolve(yard_point)=="sell",prefix+yard_id+" accepts sale cursor")
		var cash:float=battle.funds
		await click_action(stage.get_canvas_transform()*yard_point)
		check(not battle.buildings.has(yard) and is_equal_approx(battle.funds,cash+1500),prefix+yard_id+" click sells yard for 1500")
		await check_sale_animation(plant_pos,mode+"-"+yard_id,prefix)
	await key(KEY_ESCAPE)
	check(battle.command_mode == "" and not hud.building_action_buttons.sell.button_pressed, prefix + "Escape exits mode and unpresses button")
	await key(KEY_K)
	check(battle.command_mode == "repair", prefix + "K arms with no units")
	await mouse_button(Vector2(600, 400), true, false, MOUSE_BUTTON_RIGHT)
	await mouse_button(Vector2(600, 400), false, false, MOUSE_BUTTON_RIGHT)
	check(battle.command_mode == "", prefix + "right click cancels targeting")
	battle.arm_command("sell")
	battle.arm_command("sell")
	check(battle.command_mode == "", prefix + "same action toggles mode off")
	screen.queue_free()
	await get_tree().process_frame

func check_eva(event: String, prefix: String) -> void:
	var sound := GameData.ra2_eva_sound_id(event, "allied")
	var file := str(GameData.ra2_eva_file(sound).get("file", ""))
	var stream := Ra2Sfx._stream_eva(file)
	check(stream != null and Ra2Sfx._eva_player.stream == stream and Ra2Sfx._eva_player.playing, prefix + event + " starts the real local voice sample")

func check_sale_animation(at: Vector2, label: String, prefix: String) -> void:
	var visuals := get_tree().get_nodes_in_group("building_sale_visuals").filter(func(fx): return fx.global_position == at)
	check(visuals.size() == 1, prefix + label + " creates exactly one reverse buildup visual")
	if visuals.size() != 1: return
	var fx = visuals[0]
	fx.set_process(false)
	check(not fx is Building and not fx is CollisionObject2D and not battle.buildings.has(fx), prefix + label + " visual cannot produce, collide or enter saved building roster")
	var last := int(fx.art.count) - 1
	check(fx.start_frame == last and fx.frame >= last - 2, prefix + label + " sale begins at completed make frame")
	await photo(label + "-sale-start")
	var before: int = fx.frame
	battle.paused = true
	fx._process(GameData.ra2_buildup_seconds())
	check(fx.frame == before and not fx.is_queued_for_deletion(), prefix + label + " pause holds sale animation")
	battle.paused = false
	fx._process(GameData.ra2_buildup_seconds() * 0.5)
	check(fx.frame < before and fx.frame > 0, prefix + label + " animation runs backwards through original make frames")
	await photo(label + "-sale-middle")
	fx._process(GameData.ra2_buildup_seconds())
	check(fx.is_queued_for_deletion(), prefix + label + " reverse sequence retires at empty foundation")
	await get_tree().process_frame
	await photo(label + "-sale-finished")
