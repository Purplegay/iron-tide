extends "res://tests/base_recovery_regression.gd"

func _ready() -> void:
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not ProjectSettings.get_setting("application/config/use_custom_user_dir", false):
		get_tree().quit(2)
		return
	await get_tree().process_frame
	GM.god_mode = false
	GM.one_shot_kill = false
	MetaProgress.reset_save()
	for mode in [MatchRules.RA2, MatchRules.EXTENDED]:
		await preload("res://tests/aggressive_hotkey_cases.gd").run(self,mode)
		await exercise_defense(mode)
		await exercise_pursuit(mode)
		await exercise_deployed(mode)
	FileAccess.open(output_dir.path_join("result.json"), FileAccess.WRITE).store_string(JSON.stringify({"checks": checks, "failed": failed}, "  "))
	print("AUTO_DEFENSE checks=", checks.size(), " failed=", failed)
	get_tree().quit(0 if failed == 0 else 1)

func open_arena(mode: String) -> void:
	start(mode)
	if battle.fog != null:
		battle.fog.free()
		battle.fog = null
	# Keep the real base so spawned enemy orders have a valid strategic destination.

func exercise_pursuit(mode: String) -> void:
	open_arena(mode)
	var origin := Vector2(1200, 1200)
	var tank = battle.spawn_unit("MTNK", "ally", origin)
	var enemy = battle.spawn_unit("HTNK", "enemy", origin + Vector2.RIGHT * (tank.attack_range + 55))
	for actor in [tank, enemy]:
		actor.disable_mode = CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
	tank.order_stop()
	tank._refresh_target()
	check(tank.attack_target == null, prefix + "unprovoked tank ignores opponent beyond reach")
	tank.receive_hit(3, "shell", {}, enemy)
	tank._refresh_target()
	check(tank.attack_target == enemy and not tank._weapon_target_valid(enemy), prefix + "hit acquires distant attacker without extending weapon reach")
	for tick in 300:
		tank._physics_process(1.0 / 60.0)
		if battle.projectiles_root.get_children().any(func(p): return p is Projectile and p.shooter() == tank): break
	check(tank.position.distance_to(origin) > 10 and tank._weapon_target_valid(enemy) and battle.projectiles_root.get_children().any(func(p): return p is Projectile and p.shooter() == tank), prefix + "tank closes and fires a real shot within weapon range")
	enemy.position = origin + Vector2.RIGHT * (tank.attack_range + 140)
	tank.receive_hit(3, "shell", {}, enemy)
	tank._refresh_target()
	var stopped: Vector2 = tank.position
	for tick in 30: tank._physics_process(1.0 / 60.0)
	check(tank.attack_target == null and not tank.has_move_order and tank.position.distance_to(stopped) < 2.0, prefix + "repeated hit does not move the pursuit boundary")
	tank.order_stop()
	tank.position = origin
	enemy.position = origin + Vector2.RIGHT * (tank.attack_range + 55)
	tank.set_fire_stance("return")
	tank.receive_hit(3, "shell", {}, enemy)
	tank._refresh_target()
	check(tank.attack_target == enemy, prefix + "return-fire order acquires attacker outside weapon reach")
	tank.order_move(origin + Vector2.DOWN * 300)
	var destination: Vector2 = tank.move_target
	tank.receive_hit(3, "shell", {}, enemy)
	tank._refresh_target()
	tank._physics_process(1.0 / 60.0)
	check(tank.has_move_order and tank.move_target == destination, prefix + "incoming fire cannot replace a move order")
	tank.order_stop()
	tank.hold_position = true
	tank.receive_hit(3, "shell", {}, enemy)
	tank._refresh_target()
	check(tank.attack_target == null, prefix + "hold position cannot pursue")
	tank.hold_position = false
	tank.set_fire_stance("none")
	tank._refresh_target()
	check(tank.attack_target == null, prefix + "hold fire cannot pursue")
	tank.order_stop()
	tank.receive_hit(3, "shell", {}, enemy)
	tank._return_timer = 0.01
	tank._physics_process(0.02)
	tank._refresh_target()
	check(tank.attack_target == null and not tank.has_move_order, prefix + "expired contact leaves no move order")
	var bomber = battle.spawn_unit("DTRUCK", "ally", origin + Vector2.DOWN * 200)
	bomber.set_fire_stance("return")
	bomber.receive_hit(3, "shell", {}, enemy)
	check(not bomber.special.has("retaliation_target"), prefix + "native CanRetaliate=no prevents revenge detonation")
	var flyer = battle.spawn_unit("JUMPJET", "ally", origin + Vector2.UP * 400)
	flyer.disable_mode = CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
	enemy.position = flyer.position + Vector2.RIGHT * (flyer.attack_range + 35)
	flyer.set_fire_stance("return")
	flyer.receive_hit(3, "shell", {}, enemy)
	var launch: Vector2 = flyer.position
	for tick in 240:
		flyer._physics_process(1.0 / 60.0)
		if flyer._weapon_target_valid(enemy): break
	check(flyer.position.distance_to(launch) > 5 and flyer._weapon_target_valid(enemy) and not flyer.attack_ordered, prefix + "mobile air defender closes without an explicit sortie")
	tank.order_stop()
	tank.position = origin
	var tower = battle._place_building("GTGCAN", "enemy", origin + Vector2.RIGHT * (tank.attack_range + 90), true)
	tower._buildup_play = -1
	tank.set_fire_stance("return")
	tank.receive_hit(3, "shell", {}, tower)
	tank._refresh_target()
	check(tank.attack_target == tower and not tank._weapon_target_valid(tower), prefix + "reachable firing tower is measured at its foundation")
	tank._physics_process(1.0 / 60.0)
	var snapshot = BattleSaves.Snapshot.new()
	snapshot.restore(battle, snapshot.capture(battle))
	tank = battle.units.filter(func(u): return u.side == "ally" and u.unit_id == "MTNK")[0]
	tower = battle.buildings.filter(func(b): return b.side == "enemy" and b.building_id == "GTGCAN")[0]
	check(tank.special.get("retaliation_origin") == origin and tank.special.get("retaliation_target") == tower and tank._return_timer > 0 and not tank.has_move_order, prefix + "load preserves retaliation origin and source without issuing a move")
	tank._refresh_target()
	check(tank.attack_target == tower, prefix + "loaded defender can resume bounded pursuit")
	tower._die()
	tank._refresh_target()
	check(tank.attack_target == null and not tank.has_move_order, prefix + "destroyed attacker leaves no chase destination")
	await finish()

func exercise_defense(mode: String) -> void:
	open_arena(mode)
	var origin := Vector2(1200, 1200)
	var unit = battle.spawn_unit("MTNK", "ally", origin)
	var target = battle.spawn_unit("E1", "enemy", origin + Vector2(120, 0))
	var structure = battle._place_building("GAPOWR", "enemy", origin + Vector2(0, 150), true)
	structure._buildup_play = -1.0
	check(unit.fire_stance == "defend" and unit.fire_stance_label() == "自动防卫", prefix + "new unit has explicit automatic-defense stance")
	unit._refresh_target()
	check(unit.attack_target == target and not unit.attack_ordered, prefix + "stationary enemy unit acquired without prior damage or player command")
	unit.turret_angle = 0.0
	unit._cd_timer = 0.0
	check(unit._try_fire_ready(), prefix + "default acquisition reaches actual weapon fire")
	unit.order_stop()
	target.position = origin + Vector2(unit.attack_range + 100, 0)
	unit._refresh_target()
	check(unit.attack_target == null and not unit.has_move_order, prefix + "out-of-range unit not chased; in-range building ignored")
	unit.attack_target = structure
	check(not unit._weapon_target_valid(structure), prefix + "stale building target cannot bypass default firing filter")
	battle.select_unit(unit, false)
	battle.force_attack(structure)
	check(unit.attack_ordered and unit._weapon_target_valid(structure), prefix + "explicit building attack remains legal")
	unit.order_stop()
	target.position = origin + Vector2(60, 0)
	unit._refresh_target()
	unit._think_timer = 0.3
	unit.receive_hit(1.0, "shell", {}, structure)
	unit._physics_process(1.0 / 60.0)
	check(unit.attack_target == structure, prefix + "first physics step after hit prefers the shooter over a nearby bystander")
	target.position = origin + Vector2(unit.attack_range + 100, 0)
	unit._refresh_target()
	check(unit.attack_target == structure and unit._weapon_target_valid(structure), prefix + "building which attacked us may be answered")
	unit._return_timer = 0.0
	unit._refresh_target()
	check(unit.attack_target == null, prefix + "expired retaliation cannot continue unsolicited building attack")
	unit.order_move(origin + Vector2(400, 0), true)
	unit._refresh_target()
	check(unit.attack_target == structure and unit._weapon_target_valid(structure), prefix + "explicit attack-move retains building engagement")
	unit.order_stop()
	target.position = origin + Vector2(120, 0)
	unit.order_move(origin + Vector2(400, 0))
	unit._refresh_target()
	check(unit.attack_target == target and unit.has_move_order and not unit.attack_move, prefix + "normal move keeps destination when enemy is acquired")
	unit.set_fire_stance("none")
	unit._refresh_target()
	check(unit.attack_target == null and not unit._weapon_target_valid(target), prefix + "hold fire remains authoritative")
	unit.order_stop()
	unit.set_fire_stance("return")
	unit._refresh_target()
	check(unit.attack_target == null, prefix + "explicit return-fire-only remains selectable")
	unit.receive_hit(1.0, "shell", {}, target)
	unit._refresh_target()
	check(unit.attack_target == target, prefix + "return-fire-only still answers its attacker")
	unit.order_stop()
	var native: Dictionary = GameData.ra2_source_units.MTNK.extra
	var original: Dictionary = native.duplicate(true)
	native.CanPassiveAquire = "no"
	unit._refresh_target()
	check(unit.attack_target == null, prefix + "native CanPassiveAquire=no prevents default acquisition")
	native.clear()
	native.merge(original)
	unit._refresh_target()
	check(unit.attack_target == target, prefix + "native passive acquisition restored")
	for stance in ["free", "return", "none", "defend"]:
		unit.cycle_fire_stance()
		check(unit.fire_stance == stance, prefix + "stance control cycles " + stance)
	var saved = BattleSaves.save_slot(battle, "slot1")
	check(saved.ok, prefix + "default stance saves without schema change")
	var slot = BattleSaves.read_slot("slot1")
	check(slot.ok, prefix + "default stance save validates")
	preload("res://scripts/save/battle_snapshot.gd").new().restore(battle, slot.snapshot)
	get_tree().paused = false
	battle.paused = false
	unit = battle.units.filter(func(u): return u.unit_id == "MTNK" and u.side == "ally")[0]
	check(unit.fire_stance == "defend", prefix + "restored default stance remains automatic defense")
	unit.set_fire_stance("return")
	check(BattleSaves.save_slot(battle, "slot2").ok, prefix + "legacy return stance can still save")
	slot = BattleSaves.read_slot("slot2")
	preload("res://scripts/save/battle_snapshot.gd").new().restore(battle, slot.snapshot)
	get_tree().paused = false
	battle.paused = false
	unit = battle.units.filter(func(u): return u.unit_id == "MTNK" and u.side == "ally")[0]
	check(unit.fire_stance == "return", prefix + "saved return stance is not silently overwritten")
	unit.order_stop()
	check(unit.fire_stance == "defend", prefix + "S resets an existing unit to new default")
	await finish()

func exercise_deployed(mode: String) -> void:
	open_arena(mode)
	var origin := Vector2(1200, 1200)
	var target = battle.spawn_unit("MTNK", "enemy", origin + Vector2(160, 0))
	for id in ["E1", "GGI"]:
		var unit = battle.spawn_unit(id, "ally", origin)
		unit.set_deployed(true)
		unit._refresh_target()
		check(unit.attack_target == target and unit._weapon_target_valid(target), prefix + id + " deployed auto-acquires enemy vehicle")
		unit._cd_timer = 0.0
		var holder: Node = unit._pick_projectile_parent()
		var before: Array = holder.get_children()
		var hp: float = target.hp
		target.max_hp = 10000.0
		target.hp = target.max_hp
		hp = target.hp
		check(unit._try_fire_ready(), prefix + id + " deployed fires without guard command")
		for shot in holder.get_children().filter(func(child): return not before.has(child)):
			shot.process_mode = Node.PROCESS_MODE_DISABLED
			for tick in 300:
				if shot.is_queued_for_deletion(): break
				shot._physics_process(1.0 / 60.0)
			shot.free()
		check(target.hp < hp and unit.position == origin and not unit.has_move_order, prefix + id + " real shot damages target without moving deployed infantry")
		battle.units.erase(unit)
		unit.free()
	for id in ["CMIN", "ORCA", "CARRIER"]:
		var unit = battle.spawn_unit(id, "ally", origin)
		unit._refresh_target()
		check(unit.attack_target == null, prefix + id + " harvester or sortie-controlled unit does not auto-attack")
		battle.units.erase(unit)
		unit.free()
	var defense = battle._place_building("GAPILL", "ally", origin, true)
	defense._buildup_play = -1.0
	defense._acquire_target()
	check(defense.attack_target == target, prefix + "own defensive building still auto-acquires enemies")
	await finish()
