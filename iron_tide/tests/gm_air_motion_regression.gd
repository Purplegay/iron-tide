extends "res://tests/allied_abilities_regression.gd"
const Tools = preload("res://scripts/admin/gm_unit_tools.gd")

func exercise_mode(mode: String) -> void:
	if mode == MatchRules.RA2: return
	setup_logistics_scene(mode, "美国")
	for node in battle.units + battle.buildings: node.free()
	battle.units.clear(); battle.buildings.clear()
	if battle.fog != null: battle.fog.free(); battle.fog = null
	battle.process_mode = Node.PROCESS_MODE_ALWAYS
	battle.set_process(false); battle.set_physics_process(false)
	battle.paused = false
	battle.water_rects = []; battle.path_service.set_water([])
	battle.camera.position = Vector2(1500, 1500)
	battle.camera.reset_smoothing(); battle.camera.force_update_scroll()
	for id in ["R3HARBINGER", "R3MIRAGE", "JUMPJET"]:
		check(Tools.spawn_count(battle, {"id":id, "stationary":true, "side":"enemy"}) == 1, "GM spawns " + id)
	var air = battle.units[0]
	var ground = battle.units[1]
	var jet = battle.units[2]
	var start: Vector2 = air.position
	var heading: float = air.hull_angle
	var ground_start: Vector2 = ground.position
	var jet_lift: float = jet._visual_lift()
	check(air.is_physics_processing() and ground.is_physics_processing(), "GM leaves engine lifecycle callbacks enabled")
	await get_tree().create_timer(2.4).timeout
	check(air.position.distance_to(start) > 40 and absf(angle_difference(heading, air.hull_angle)) > 0.2, "GM Harbinger flies and turns through real callbacks")
	check(air.logistics.air_lift >= 0.95 and air.special.get("ra3_flight_mode", "") == "idle", "target follows native idle orbit without attack mode")
	check(ground.position == ground_start, "ground target remains stationary")
	check(absf(jet._visual_lift() - jet_lift) > 0.01, "hover target animation clock continues")
	check(battle.projectiles_root.get_child_count() == 0 and air.fire_stance == "none", "target flight never emits weapons")
	# Exercise the serialized GM flag with the ordinary restore path.
	var codec = preload("res://scripts/save/battle_snapshot.gd").new()
	var saved: Dictionary = codec.capture(battle)
	check(codec.error.is_empty(), "GM targets serialize through battle save")
	codec.restore(battle, saved)
	get_tree().paused = false; battle.paused = false
	air = battle.units.filter(func(u):return u.unit_id == "R3HARBINGER")[0]
	air.process_mode = Node.PROCESS_MODE_ALWAYS
	start = air.position
	await get_tree().create_timer(0.6).timeout
	check(air.position.distance_to(start) > 10 and air.fire_stance == "none", "restored aircraft target resumes idle flight")
	screen.free(); await get_tree().process_frame
