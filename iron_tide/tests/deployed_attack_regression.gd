extends "res://tests/base_recovery_regression.gd"
var messages: Array[String] = []

func _ready() -> void:
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not ProjectSettings.get_setting("application/config/use_custom_user_dir", false):
		get_tree().quit(2)
		return
	Events.battle_message.connect(func(text, _color): messages.append(text))
	for mode in [MatchRules.RA2, MatchRules.EXTENDED]:
		await exercise(mode)
	var file := FileAccess.open(output_dir.path_join("result.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failed": failed}, "  "))
	file.close()
	get_tree().quit(0 if failed == 0 else 1)

func activate(actor) -> void:
	actor.process_mode = Node.PROCESS_MODE_ALWAYS
	actor.set_process(false)
	actor.set_physics_process(false)
	actor.order_stop()

func exercise(mode: String) -> void:
	start(mode)
	if battle.fog != null:
		battle.fog.free()
		battle.fog = null
	GM.god_mode = false
	GM.one_shot_kill = false
	var origin := Vector2(1200, 1200)
	var gi = battle.spawn_unit("E1", "ally", origin)
	var peer = battle.spawn_unit("E1", "ally", origin + Vector2(10, 0))
	var target = battle.spawn_unit("MTNK", "enemy", origin + Vector2(600, 0))
	for actor in [gi, peer, target]: activate(actor)
	await get_tree().physics_frame
	gi.set_deployed(true)
	battle.select_unit(gi, false)
	messages.clear()
	battle.arm_command("attack")
	battle._issue_command_at(target.global_position)
	check(gi.attack_target == target and gi.attack_ordered and gi.is_deployed(), prefix + "attack command preserves deployed stance and target")
	check(messages.filter(func(text): return "需先起身" in text).is_empty(), prefix + "stationary attack does not issue a rejected movement command")
	for tick in 60: gi._physics_process(1.0 / 60.0)
	check(gi.position.distance_to(origin) < 0.01 and gi.velocity == Vector2.ZERO, prefix + "crowded deployed GI cannot slide toward an out-of-range target", gi.position.distance_to(origin))
	check(not gi.has_move_order and gi.move_speed == 0.0, prefix + "deployed attack has no pending movement")
	peer.position = origin + Vector2(300, 300)
	gi.position = origin
	target.position = origin + Vector2(160, 0)
	await get_tree().physics_frame
	gi._cd_timer = 0.0
	gi._cancel_burst()
	gi._think_timer = 100.0
	battle.force_attack(target)
	var holder: Node = gi._pick_projectile_parent()
	var before := holder.get_children()
	var hp: float = target.hp
	for tick in 60:
		gi._physics_process(1.0 / 60.0)
		if holder.get_child_count() > before.size(): break
	var shots: Array = holder.get_children().filter(func(child): return not before.has(child))
	check(not shots.is_empty() and gi.position.distance_to(origin) < 0.01, prefix + "in-range target fires deployed weapon without moving")
	for shot in shots:
		shot.process_mode = Node.PROCESS_MODE_DISABLED
		for tick in 240:
			if shot.is_queued_for_deletion(): break
			shot._physics_process(1.0 / 60.0)
		shot.free()
	check(target.hp < hp, prefix + "real deployed projectile still damages target", hp - target.hp)
	gi.order_move(origin + Vector2(300, 0))
	check(gi.is_deployed() and not gi.has_move_order, prefix + "plain move continues to require manual undeploy")
	gi.order_patrol(origin + Vector2(400, 0))
	for tick in 60: gi._physics_process(1.0 / 60.0)
	check(gi.position.distance_to(origin) < 0.01, prefix + "patrol cannot displace deployed GI")
	gi.order_stop()
	peer.position = origin + Vector2(10, 0)
	await get_tree().physics_frame
	for tick in 60: gi._physics_process(1.0 / 60.0)
	check(gi.position.distance_to(origin) < 0.01 and gi.velocity == Vector2.ZERO, prefix + "idle deployed GI also resists separation drift", gi.position.distance_to(origin))
	gi.position = origin
	peer.position = origin + Vector2(300, 300)
	gi.set_deployed(false)
	target.position = origin + Vector2(600, 0)
	await get_tree().physics_frame
	battle.force_attack(target)
	for tick in 30: gi._physics_process(1.0 / 60.0)
	check(gi.position.distance_to(origin) > 1.0 and not gi.is_deployed(), prefix + "undeployed GI resumes normal attack pursuit")
	var tank = battle.spawn_unit("MTNK", "ally", origin + Vector2(0, 200))
	activate(tank)
	gi.order_stop()
	gi.set_deployed(true)
	var held: Vector2 = gi.position
	var tank_start: Vector2 = tank.position
	battle.select_unit(gi, false)
	battle.select_unit(tank, true)
	battle.force_attack(target)
	await get_tree().physics_frame
	for tick in 30:
		gi._physics_process(1.0 / 60.0)
		tank._physics_process(1.0 / 60.0)
	check(gi.position.distance_to(held) < 0.01 and tank.position.distance_to(tank_start) > 1.0, prefix + "mixed group keeps deployed GI fixed while tank pursues")
	var wingman = battle.spawn_unit("E1", "ally", gi.position + Vector2(20, 0))
	wingman.set_deployed(true, false)
	gi.set_deployed(true, false)
	battle.select_unit(gi, false)
	battle.select_unit(wingman, true)
	messages.clear()
	battle._command_move(gi.position + Vector2(90, 0))
	var refusals := messages.filter(func(msg): return "已卧倒据守" in msg)
	check(refusals.size() == 1 and not gi.has_move_order and not wingman.has_move_order, prefix + "one refusal per deployed type, both GIs hold position")
	await finish()
	await exercise_prism_bridge(mode)

func exercise_prism_bridge(mode: String) -> void:
	start(mode)
	if battle.fog != null:
		battle.fog.free()
		battle.fog = null
	var origin := Vector2(1060, 1220)
	var river := Rect2(800, 0, 800, battle.map_size)
	var bridge := Rect2(760, 1160, 880, 120)
	battle.path_service.set_water([river], [bridge])
	var tank = battle.spawn_unit("SREF", "ally", origin)
	activate(tank)
	var target = battle._place_building("TESLA", "enemy", origin + Vector2(tank.attack_range + 200, 0), true)
	for y in [1180, 1220, 1260]:
		var guard = battle.spawn_unit("GGI", "ally", Vector2(1420, y))
		activate(guard)
		guard.set_deployed(true, false)
	await get_tree().physics_frame
	var hp_before: float = target.hp
	var initial_distance := CommandoCombat.distance_to(tank, target)
	battle.select_unit(tank, false)
	battle._issue_order(target.position)
	check(tank.attack_ordered and tank.attack_target == target and initial_distance > tank.attack_range,
		prefix + "prism right-click locks a shore building outside range")
	var distance_on_hit := INF
	for tick in 480:
		tank._physics_process(1.0 / 60.0)
		if target.hp < hp_before:
			distance_on_hit = CommandoCombat.distance_to(tank, target)
			break
	check(tank.position.x > origin.x + 10 and tank.position.x < 1420 and bridge.has_point(tank.position),
		prefix + "prism drives to firing range before deployed bridge blockers", tank.position)
	check(distance_on_hit <= tank.attack_range, prefix + "prism actually damages the shore target from legal range", distance_on_hit)
	var firing_position: Vector2 = tank.position
	battle._issue_order(target.position)
	for tick in 60:
		tank._physics_process(1.0 / 60.0)
	check(tank.position.distance_to(firing_position) < 1.0 and tank.attack_target == target,
		prefix + "repeat right-click inside prism range holds the firing position")
	await finish()
