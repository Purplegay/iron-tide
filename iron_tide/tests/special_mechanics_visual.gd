extends "res://tests/logistics_regression.gd"
const Sites = preload("res://scripts/world/civilian_sites.gd")
const Presentation = preload("res://scripts/world/storm_presentation.gd")

func _ready() -> void:
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or DisplayServer.get_name() == "headless" or not ProjectSettings.get_setting("application/config/use_custom_user_dir", false): get_tree().quit(2); return
	stage = SubViewport.new(); stage.size = Vector2i(1600, 900); stage.world_2d = World2D.new()
	stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(stage)
	setup_logistics_scene(MatchRules.RA2, "美国")
	for actor in battle.units + battle.buildings: actor.free()
	battle.units.clear(); battle.buildings.clear()
	for group in ["obstacles", "resource_nodes"]:
		for node in get_tree().get_nodes_in_group(group): node.free()
	battle.water_rects = [Rect2(1000, 900, 240, 600)]
	battle.path_service.set_water(battle.water_rects); battle._refresh_pathing()
	for child in battle.get_children():
		if child is WaterLayer: child.rects = battle.water_rects; child.queue_redraw()
	var house = Sites.create(battle, "CAHSE01", Vector2(1400, 1100))
	var hut = Sites.create(battle, "CABHUT", Vector2(920, 1200))
	hut.special.bridge_span = Rect2(980, 1140, 280, 120); hut.special.bridge_repaired = false
	Sites.repair(hut)
	battle.camera.position = house.position
	battle.camera.zoom = Iso.cam_zoom(2)
	battle.camera.position_smoothing_enabled = false
	battle.camera.force_update_scroll()
	await picture("empty-house")
	var unit = battle.spawn_unit("E1", "ally", house.position + Vector2(60, 0))
	preload("res://scripts/units/civilian_orders.gd").enter(unit, house)
	var enemy = battle.spawn_unit("HTNK","enemy",house.position+Vector2(210,0))
	battle.select_building(house)
	battle._emit_selection()
	battle.force_attack(enemy)
	unit._cd_timer=0
	preload("res://scripts/units/civilian_orders.gd").tick(unit,0.1)
	await picture("fortified-house")
	var center := Vector2i(house.get_global_transform_with_canvas().origin)
	stage.get_texture().get_image().get_region(Rect2i(center-Vector2i(145,220),Vector2i(290,260))).save_png(output_dir.path_join("house-window.png"))
	check(house._art_frame==2 and enemy.hp<enemy.max_hp,"rendered armed house shoots chosen target")
	var weather = battle._place_building("GAWEAT", "enemy", Vector2(1900, 1700), true)
	weather._buildup_play = -1.0; weather._sw_charge = weather.sw_recharge()
	battle.enemy_power.low = false; battle.power_low = false
	battle.camera.position = Vector2(1330, 1190); battle.camera.zoom = Iso.cam_zoom(1.3)
	battle.camera.position_smoothing_enabled = false
	battle.camera.force_update_scroll()
	await picture("civilian-sites")
	check(weather.fire_superweapon(house.position), "real storm launch")
	LightningStorm.tick(battle, 250.0 / 15.0 + 2.5)
	Presentation.sync(battle)
	await picture("storm-clouds")
	check(battle.get_node("StormPresentation/StormLighting").color != Color.WHITE, "active storm dims battlefield")
	LightningStorm.tick(battle, 30)
	check(battle.get_node("StormPresentation/StormLighting").color == Color.WHITE, "storm completion restores lighting")
	await picture("storm-finished")
	var file := FileAccess.open(output_dir.path_join("result.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failed": failed}, "  ")); file.close()
	Ra2Sfx.stop_all(); Music.stop(); Music.player.stream = null
	OS.delay_msec(150)
	get_tree().quit(0 if failed == 0 else 1)

func picture(name: String) -> void:
	for i in 3: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := stage.get_texture().get_image()
	check(not image.is_empty() and image.save_png(output_dir.path_join(name + ".png")) == OK, name + " real viewport capture")
