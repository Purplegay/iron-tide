extends "res://tests/allied_abilities_regression.gd"
const Tools = preload("res://scripts/admin/gm_unit_tools.gd")

func exercise_mode(mode: String) -> void:
	if mode == MatchRules.RA2: return
	if DisplayServer.get_name() == "headless":
		check(false, "real RA3 wreck lifetime requires rendering")
		return
	setup_logistics_scene(mode, "美国")
	for node in battle.units + battle.buildings: node.free()
	battle.units.clear(); battle.buildings.clear()
	if battle.fog != null: battle.fog.free(); battle.fog = null
	# Freeze battle AI/economy but let real actor and wreck engine callbacks run.
	battle.process_mode = Node.PROCESS_MODE_ALWAYS
	battle.set_process(false); battle.set_physics_process(false)
	battle.paused = false
	# Native Harbinger death now falls via a projectile before the wreck clock starts.
	battle.projectiles_root.process_mode = Node.PROCESS_MODE_INHERIT
	battle.water_rects = []; battle.path_service.set_water([])
	battle.camera.position = Vector2(1800, 1800)
	var dead: Array = []
	for id in ["E1", "MTNK", Ra3Mirage.ID, Ra3Expansion.FUTURE, Ra3Expansion.HARBINGER]:
		check(Tools.spawn_count(battle, {"id":id, "count":1, "side":"enemy", "stationary":true, "health":1}) == 1, id + " spawns through actual GM stationary command")
		var unit = battle.units[-1]
		check(unit.is_physics_processing() and unit.special.gm_stationary, id + " target keeps engine lifecycle active")
		unit.receive_hit(unit.max_hp * 100.0)
		check(unit._dead and not unit.is_in_group("combatants"), id + " real damage enters death and removes combat eligibility")
		dead.append(unit)
	var wrecks := get_tree().get_nodes_in_group("ra3_wrecks")
	check(wrecks.size() == 3, "three RA3 deaths each create one independent wreck")
	await get_tree().create_timer(1.6).timeout
	for i in dead.size():
		check(not is_instance_valid(dead[i]), "original dead actor released by engine callback " + str(i))
	var advancing := true
	for wreck in wrecks:
		advancing = advancing and is_instance_valid(wreck) and (wreck.age > 1.0 or (wreck.falling_ref != null and wreck.falling_ref.get_ref().splinters.age > 1.0))
	check(advancing, "wreck timers advance naturally for stationary GM deaths")
	# Save/restore may restore the flag without disabled processing. Both paths
	# must reach death cleanup; alive flagged actors must still stay stationary.
	var restored = actor("E1", "enemy", Vector2(2100, 1800))
	restored.special.gm_stationary = true
	restored.set_physics_process(true)
	var point: Vector2 = restored.position
	await get_tree().create_timer(0.1).timeout
	check(restored.position == point, "processing-enabled stationary flag still prevents movement")
	restored.receive_hit(restored.max_hp * 100.0)
	await get_tree().create_timer(1.25).timeout
	check(not is_instance_valid(restored), "stationary flag cannot bypass death timer after restore")
	# Stop before expiry; aircraft's nine-second wreck lifetime starts after landing.
	await get_tree().create_timer(4.8).timeout
	var fading := true
	for wreck in wrecks:
		fading = fading and is_instance_valid(wreck) and wreck.opacity() < 0.8 and wreck.opacity() > 0.0
	check(fading, "native wrecks visibly fade during the real five-to-nine second interval")
	await get_tree().create_timer(4.7).timeout
	for i in wrecks.size(): check(not is_instance_valid(wrecks[i]), "wreck automatically released after native lifetime " + str(i))
	check(get_tree().get_nodes_in_group("ra3_wrecks").is_empty(), "no wreck nodes retained after expiry")
	screen.free(); Music.stop(); Ra2Sfx.stop_all()
	await get_tree().process_frame
