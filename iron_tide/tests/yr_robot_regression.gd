extends "res://tests/yr_guardian_regression.gd"

func _ready() -> void:
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not ProjectSettings.get_setting("application/config/use_custom_user_dir", false):
		get_tree().quit(2)
		return
	var original_ap: Dictionary = GameData.ra2_warheads.ap.duplicate(true)
	GameData.reload()
	check(GameData.units.filter(func(u): return u.id == "ROBO").size() == 1, "reload keeps one robot")
	check(GameData.buildings.filter(func(b): return b.id == "GAROBO").size() == 1, "reload keeps one controller")
	check(GameData.ra2_warheads.ap == original_ap and not GameData.get_unit("GGI").is_empty(), "addition preserves base AP and Guardian GI")
	for id in ["ROBO", "ROBO_tur", "ROBO_shd", "GAROBO", "GAROBO_A", "GAROBOMK"]:
		check(RA2Art.has_art(id), "original imported artwork " + id)
	for id in ["ROBO", "GAROBO"]:
		check(ResourceLoader.exists(GameData.ra2_cameo_path(id)), "original portrait " + id)
	check(GameData.ra2_muzzle_anims("YR_Robogun").has("GUNFIRE") and RA2Art.has_fx("GUNFIRE"), "original muzzle animation resolved")
	for mode in [MatchRules.RA2, MatchRules.EXTENDED]:
		await exercise_robot(mode)
	var file := FileAccess.open(output_dir.path_join("result.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failed": failed}, "  "))
	file.close()
	get_tree().quit(0 if failed == 0 else 1)

func building(id: String, side: String, pos: Vector2):
	var result = battle._place_building(id, side, pos, true)
	result._buildup_play = -1.0
	result.process_mode = Node.PROCESS_MODE_DISABLED
	return result

func tick(unit, count: int) -> void:
	for index in count:
		unit._physics_process(1.0 / 60.0)
		await get_tree().physics_frame

func exercise_robot(mode: String) -> void:
	start(mode)
	if battle.fog != null:
		battle.fog.free()
		battle.fog = null
	GM.god_mode = false
	GM.one_shot_kill = false
	GM.no_build_time = false
	GM.infinite_funds = false
	battle.funds = 50000
	battle.enemy_funds = 50000
	var data := GameData.get_unit("ROBO")
	check(data.hp == 180 and data.cost == 600 and data.speed == 150 and data.sight == 330, prefix + "original unit values")
	check(is_equal_approx(GameData.ra2_build_time(data), 32.76 if mode == MatchRules.RA2 else 15.6), prefix + "original 1.3 build multiplier in mode timing")
	check(GameData.get_building("GAROBO").hp == 600 and GameData.get_building("GAROBO").power == -100, prefix + "original controller health and drain")
	check(not GameData.ra2_prereq_ok("ROBO", ["GAWEAP"]) and GameData.ra2_prereq_ok("ROBO", ["GAWEAP", "GAROBO"]), prefix + "both robot prerequisites")
	check(not GameData.ra2_prereq_ok("GAROBO", ["GACNST"]) and GameData.ra2_prereq_ok("GAROBO", ["GACNST", "GAWEAP"]), prefix + "controller requires factory and yard, not lab")
	check(battle.structure_category("GAROBO") == "building", prefix + "controller uses main building category")
	for kind in ["select", "move", "attack", "select_deactivated", "die", "activate", "deactivate"]:
		check(Ra2Sfx.has_voice(data, kind) and Ra2Sfx.play_voice(data, kind, Vector2.INF, 0), prefix + "original PCM plays " + kind)
	check(Ra2Sfx.play_weapon(data.weapon, Vector2.INF), prefix + "original gun report plays")
	for side in ["ally", "enemy"]:
		var other := "enemy" if side == "ally" else "ally"
		var factory = building("GAWEAP", side, Vector2(650, 800))
		check(factory.buildable.has("ROBO") and not factory.can_queue("ROBO"), prefix + side + "factory lists locked robot and refuses before controller")
		if side == "ally":
			var money: float = battle.funds
			battle.request_structure("GAROBO")
			check(battle.struct_queue.size() == 1 and battle.struct_queue[0].id == "GAROBO", prefix + "actual structure queue accepts controller")
			battle._tick_structure_queue(1000.0)
			check(battle.struct_ready.get("GAROBO", 0) == 1 and absf(money-battle.funds-600.0) < 0.01, prefix + "controller production completes and spends exactly 600")
			battle.struct_ready.erase("GAROBO")
		var robot = actor("ROBO", side, Vector2(1400, 1350))
		check("缺少" in robot.power_disabled_reason(), prefix + side + "missing controller explains offline")
		var power = building("GAPOWR", side, Vector2(650, 1150))
		power.power = 5000 # deterministic power fixture; normal power aggregation remains authoritative
		var controller = building("GAROBO", other, Vector2(900, 800))
		battle._update_power()
		check(not robot.power_disabled_reason().is_empty(), prefix + side + "enemy controller never grants control")
		controller.side = side
		controller._buildup_play = 0.0
		check("展开" in robot.power_disabled_reason(), prefix + side + "unfolding controller cannot activate tank")
		controller._buildup_play = -1.0
		battle._update_power()
		check(robot.power_disabled_reason().is_empty() and factory.can_queue("ROBO"), prefix + side + "completed powered controller activates and unlocks")
		var layer: Dictionary = controller._ra2_anim[0]
		var healthy: Dictionary = controller._anim_layer(layer)
		controller.hp = controller.max_hp * 0.3
		var damaged: Dictionary = controller._anim_layer(layer)
		check(healthy.loopStart == 0 and healthy.loopEnd == 19 and damaged.loopStart == 20 and damaged.loopEnd == 39, prefix + side + "healthy and damaged antenna layers never select shadow frames")
		controller.hp = controller.max_hp
		var before: float = battle.funds if side == "ally" else battle.enemy_funds
		check(factory.enqueue("ROBO"), prefix + side + "actual factory queue accepts robot")
		for i in 500:
			factory._process(0.1)
			if factory.production.is_empty(): break
		var after: float = battle.funds if side == "ally" else battle.enemy_funds
		check(factory.production.is_empty() and absf(before-after-600.0) < 0.01, prefix + side + "real production spends exactly 600", before-after)
		var produced: Array = battle.units.filter(func(u): return is_instance_valid(u) and u != robot and u.unit_id == "ROBO" and u.side == side)
		check(produced.size() == 1, prefix + side + "factory spawns one robot", produced.size())
		for unit in produced:
			battle.units.erase(unit)
			unit.free()
		check(robot.is_amphibious and not robot.is_naval and not robot.is_air, prefix + side + "hover remains a ground amphibious unit")
		var target = actor("MTNK", other, robot.position + Vector2(220, 0))
		var air = actor("JUMPJET", other, robot.position + Vector2(180, 0))
		await get_tree().physics_frame
		check(not robot._weapon_domain_valid(air), prefix + side + "original cannon cannot attack air")
		check(damage_target(robot, target) > 0, prefix + side + "actual original cannon damages armor")
		var health: float = robot.hp
		for warhead in ["Controller", "RadBeamWarhead", "RadEruptionWarhead", "RadSite"]:
			check(robot.ignores_warhead(warhead), prefix + side + "original immunity flag " + warhead)
			robot.receive_hit(50, "bullet", {}, target, warhead)
		check(robot.hp == health, prefix + side + "immune hits cannot reduce robot health")
		check(not target.ignores_warhead("Controller") and not robot.ignores_warhead("PsiPulse"), prefix + side + "immunity does not spread to ordinary tanks or unrelated psychic damage")
		robot.receive_hit(10, "bullet", {}, target, "PsiPulse")
		check(robot.hp < health, prefix + side + "non-immune psychic damage still applies")
		var psychic = actor("PTROOP", other, robot.position + Vector2(180, 80))
		check(not psychic._weapon_domain_valid(robot), prefix + side + "mind controller rejects immune robot before firing")
		battle.units.erase(psychic)
		psychic.free()
		check(robot._weapon_art.get("muzzles", []).size() == 32 and not robot._ra2_tur.is_empty(), prefix + side + "separate turret and 32 real muzzle anchors")
		robot.credit_kill(100000, other)
		check(not robot.can_gain_veterancy() and robot.veteran_level == 0 and robot._vet_kills == 0, prefix + side + "untrainable robot cannot earn experience")
		robot.order_stop()
		robot.fire_stance = "none"
		robot.order_move(Vector2(1650, 1450))
		await tick(robot, 20)
		var stop: Vector2 = robot.position
		var destination: Vector2 = robot.move_target
		var powers: Array = []
		for b in battle.buildings:
			if is_instance_valid(b) and b.side == side and b.power > 0:
				powers.append([b, b.power])
				b.power = 0
		battle._update_power()
		check(battle.side_power_low(side) and "电力不足" in robot.power_disabled_reason(), prefix + side + "real power deficit gives exact reason")
		controller._anim_t = 9.0
		check(controller._anim_frame_for(layer, healthy) == 0, prefix + side + "offline controller antenna stops animating")
		if side == "ally":
			battle.selected_building = null
			battle.selected_units = [robot]
			screen.hud._refresh_selection()
			check(is_instance_valid(screen.hud.economy_status_label) and "电力不足" in screen.hud.economy_status_label.text, prefix + "actual selection panel displays offline cause")
			check(battle._voice_rep([robot], "move") == null and battle._play_group_voice([robot], "select", 0), prefix + "group voice uses offline selection and refuses move acknowledgement")
		robot._burst_left = 2
		robot._burst_target = target
		await tick(robot, 10)
		check(robot.position == stop and robot.velocity == Vector2.ZERO and robot._burst_left == 0, prefix + side + "power loss stops movement and queued burst")
		check(robot.move_target == destination and robot.has_move_order, prefix + side + "power loss retains interrupted destination")
		check(robot.command_voice_kind("select") == "select_deactivated" and robot.command_voice_kind("move").is_empty(), prefix + side + "offline selection uses original offline voice")
		robot.order_move(Vector2(800, 1500))
		check(robot.move_target == destination, prefix + side + "offline new move rejected without replacing paused order")
		robot.fire_stance = "free"
		robot.attack_target = target
		robot._cd_timer = 0
		check(not robot._try_fire_ready(), prefix + side + "direct fire entry cannot bypass power gate")
		robot.fire_stance = "none"
		for pair in powers: pair[0].power = pair[1]
		battle._update_power()
		await tick(robot, 20)
		check(robot.power_disabled_reason().is_empty() and not robot.powered_unit.offline and robot.position.distance_to(stop) > 3, prefix + side + "restoring actual supply resumes original movement")
		var spare = building("GAROBO", side, Vector2(1050, 800))
		controller.side = other
		battle._update_power()
		check(robot.power_disabled_reason().is_empty(), prefix + side + "second own center survives losing first")
		spare._die()
		check("缺少" in robot.power_disabled_reason(), prefix + side + "losing last own center immediately disables")
		controller.side = side
		battle._update_power()
		check(robot.power_disabled_reason().is_empty(), prefix + side + "restored ownership uses current owner")
		robot.order_stop()
		battle.water_rects.append(Rect2(1350, 1700, 300, 160))
		battle.path_service.water_rects = battle.water_rects.duplicate()
		battle._refresh_pathing()
		check(robot._domain_ok(Vector2(1450, 1750)) and not target._domain_ok(Vector2(1450, 1750)), prefix + side + "water accepts hover but rejects normal tank")
		robot.position = Vector2(1200, 1750)
		var path: PackedVector2Array = robot._path_for(Vector2(1800, 1750))
		check(not path.is_empty(), prefix + side + "amphibious path service returns reachable route")
		robot.order_move(Vector2(1800, 1750))
		await tick(robot, 170)
		check(battle.on_water(robot.position), prefix + side + "actual hover movement crosses onto water", robot.position)
		await tick(robot, 240)
		check(robot.position.distance_to(Vector2(1800, 1750)) < 25 and not battle.on_water(robot.position), prefix + side + "actual hover returns to land and reaches destination", robot.position)
		battle.water_rects.clear()
		battle.path_service.water_rects.clear()
		battle._refresh_pathing()
		for item in [robot, target, air, factory, power, controller, spare]:
			if is_instance_valid(item) and not item.is_queued_for_deletion():
				battle.units.erase(item)
				battle.buildings.erase(item)
				item.free()
		await get_tree().process_frame
		battle.selected_units.clear()
	if DisplayServer.get_name() != "headless":
		await robot_preview(mode)
	await finish()

func robot_preview(mode: String) -> void:
	var color := HouseColor.player_id
	HouseColor.set_player_id("purple" if mode == MatchRules.EXTENDED else "blue")
	var center := Vector2(1500, 1500)
	battle.camera.position = center
	battle.camera.zoom = Iso.cam_zoom(1.5)
	battle.camera.rotation = Iso.cam_angle()
	battle.camera.reset_smoothing()
	battle.camera.force_update_scroll()
	screen.hud.hide()
	for i in 8:
		var unit = actor("ROBO", "ally", center + RA2Art.art_dir(Vector2((i-3.5)*65, 70)))
		unit.hull_angle = float(i)*TAU/8.0
		unit.turret_angle = unit.hull_angle
		unit.powered_unit.offline = i >= 4
		unit.queue_redraw()
	for i in 3:
		var b = building("GAROBO", "ally", center + RA2Art.art_dir(Vector2((i-1)*190, -90)))
		if i == 1: b.hp = b.max_hp * 0.3
		if i == 2: b._buildup_play = GameData.ra2_buildup_seconds() * 0.6
		b._process(0.1)
		b.queue_redraw()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png(output_dir.path_join(mode + "-robot.png")) == OK, prefix + "actual healthy damaged buildup and eight-facing render captured")
	HouseColor.set_player_id(color)
