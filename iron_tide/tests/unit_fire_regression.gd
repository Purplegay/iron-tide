extends "res://tests/selection_regression.gd"

func exercise_mode(mode: String) -> void:
	BattleRequest.configure_skirmish(mode, {"map_size": 3200, "starting_funds": 10000})
	screen = load("res://scenes/battle.tscn").instantiate()
	stage.add_child(screen)
	battle = screen.battle
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	GM.god_mode = false
	GM.one_shot_kill = false
	for side in ["ally", "enemy"]:
		for id in ["MTNK", "FV", "SREF"]:
			await exercise_weapon(mode, side, id)
	screen.free()
	await get_tree().process_frame

func exercise_weapon(mode: String, side: String, id: String) -> void:
	var label := "%s %s %s: " % [mode, side, id]
	var other := "enemy" if side == "ally" else "ally"
	var u = battle.spawn_unit(id, side, Vector2(1600, 1600))
	var t = battle.spawn_unit("MTNK", other, Vector2(1600, 1780))
	for actor in [u, t]:
		actor.process_mode = Node.PROCESS_MODE_ALWAYS
		actor.set_process(false)
		actor.set_physics_process(false)
		actor.bonuses = {}
		actor.order_stop()
	await get_tree().physics_frame
	u.attack_target = t
	u.hold_position = true
	u._think_timer = 100.0
	var holder: Node = u._pick_projectile_parent()
	var before := holder.get_children()
	var effects_before: Array = Effects._host().get_children()
	var hp_before: float = t.hp
	u._physics_process(1.0 / 60.0)
	var shots := new_shots(holder, before)
	check(shots.is_empty() and u._cd_timer <= 0.0 and t.hp == hp_before,
		label + "no shot or cooldown before turret turns", shots.size())
	var bounded := true
	var previous: float = u.turret_angle
	for tick in 120:
		if not shots.is_empty():
			break
		u._physics_process(1.0 / 60.0)
		bounded = bounded and absf(angle_difference(previous, u.turret_angle)) <= deg_to_rad(105.47 / 60.0) + 0.00001
		previous = u.turret_angle
		shots = new_shots(holder, before)
	check(bounded, label + "existing ROT limit is respected before first shot")
	check(shots.size() == 1 and u._cd_timer > 0.0, label + "aligned turret emits exactly one first shot")
	check(absf(angle_difference(u.turret_angle, (t.position - u.position).angle())) <= deg_to_rad(2.0),
		label + "actual firing heading within two degrees")
	# Original LargeCometP.Inviso=yes: the beam hits in its firing frame.
	# 105mm and HoverMissile still require actual projectile flight.
	check(hp_before - t.hp == (50.0 if id == "SREF" else 0.0),
		label + "Inviso hits on fire; physical shells and missiles wait for flight")
	check(u.aim_dir.distance_to(Vector2.RIGHT.rotated(u.turret_angle)) < 0.00001,
		label + "muzzle direction uses constrained turret heading")
	if id == "FV":
		var ticks := 0
		while shots.size() == 1 and ticks < 30:
			u._physics_process(1.0 / 60.0)
			ticks += 1
			shots = new_shots(holder, before)
		check(shots.size() == 2 and float(ticks) / 60.0 >= 0.12,
			label + "real two-shot burst preserves full delay after first shot", ticks)
	else:
		u._physics_process(0.05)
		check(new_shots(holder, before).size() == 1, label + "cooldown prevents duplicate fire")
	for shot in shots:
		shot.process_mode = Node.PROCESS_MODE_DISABLED
		for tick in 240:
			if shot.is_queued_for_deletion():
				break
			shot._physics_process(1.0 / 60.0)
		check(shot.is_queued_for_deletion(), label + "actual projectile reaches impact")
	var expected: float = {"MTNK": 65.0, "FV": 16.0, "SREF": 50.0, "MGTK": 100.0}[id]
	check(hp_before - t.hp == expected, label + "original heavy-armor damage", hp_before - t.hp)
	for shot in shots:
		shot.free()
	if id == "FV":
		await exercise_burst_boundaries(u, t, holder, before, label)
	# Retargeting to the opposite side must turn again, without consuming readiness.
	t.hp = t.max_hp
	t.position = u.position + Vector2(0, -180)
	u.attack_target = t
	u._cd_timer = 0.0
	u._cancel_burst()
	u._physics_process(1.0 / 60.0)
	check(new_shots(holder, before).is_empty() and u._cd_timer <= 0.0,
		label + "opposite target requires another aim before fire")
	for actor in [u, t]:
		battle.units.erase(actor)
		actor.free()
	for effect in Effects._host().get_children():
		if not effects_before.has(effect):
			effect.free()
	await get_tree().process_frame

func exercise_burst_boundaries(u, t, holder: Node, before: Array, label: String) -> void:
	var other: String = t.side
	for boundary in ["range", "min_range", "dead", "friendly", "stop", "retarget", "repair"]:
		t.side = other
		t.hp = t.max_hp
		t.position = u.position + Vector2(180, 0)
		u.turret_angle = 0.0
		u.attack_target = t
		u._cd_timer = 0.0
		u.repairing = false
		u.set_fire_stance("free")
		u._cancel_burst()
		u._physics_process(1.0 / 60.0)
		check(new_shots(holder, before).size() == 1 and u._burst_left == 1, label + boundary + " starts real burst")
		for shot in new_shots(holder, before):
			shot.free()
		match boundary:
			"range": t.position = u.position + Vector2(u.attack_range + 100, 0)
			"min_range": t.position = u.position + Vector2(20, 0)
			"dead": t.hp = 0.0
			"friendly": t.side = u.side
			"stop": u.set_fire_stance("none")
			"retarget": u.attack_target = null
			"repair": u.repairing = true
		u._update_burst(0.2)
		check(new_shots(holder, before).is_empty() and u._burst_left == 0 and u._cd_timer > 0.0,
			label + boundary + " cancels remaining burst without refunding cooldown")
	u.repairing = false
	u.set_fire_stance("free")
	t.hp = t.max_hp
	t.side = other
	# A moving, still valid target pauses the second shot until realignment.
	t.position = u.position + Vector2(180, 0)
	u.attack_target = t
	u.turret_angle = 0.0
	u._cd_timer = 0.0
	u._physics_process(1.0 / 60.0)
	for shot in new_shots(holder, before):
		shot.free()
	t.position = u.position + Vector2(0, 180)
	u._physics_process(0.15)
	check(new_shots(holder, before).is_empty() and u._burst_left == 1,
		label + "second shot waits for moving target alignment")
	for tick in 120:
		if not new_shots(holder, before).is_empty():
			break
		u._physics_process(1.0 / 60.0)
	check(new_shots(holder, before).size() == 1 and u._burst_left == 0,
		label + "paused second shot resumes exactly once")
	for shot in new_shots(holder, before):
		shot.free()

func new_shots(holder: Node, before: Array) -> Array:
	# Count shots fired, including Inviso projectiles already queued for deletion.
	return holder.get_children().filter(func(n): return n is Projectile and not before.has(n))
