extends "res://tests/input_ownership_regression.gd"

const Snapshot = preload("res://scripts/save/battle_snapshot.gd")
var prefix := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not ProjectSettings.get_setting("application/config/use_custom_user_dir", false):
		get_tree().quit(2)
		return
	await get_tree().process_frame
	if "--cold-force" in OS.get_cmdline_user_args():
		await cold()
		await conclude("force-cold-result.json")
		return
	stage = SubViewport.new()
	stage.size = Vector2i(1600, 900)
	stage.world_2d = World2D.new()
	stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(stage)
	for mode in [MatchRules.RA2, MatchRules.EXTENDED]:
		await exercise_mode(mode)
	var output: Array = []
	var code := OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "res://tests/force_fire_regression.tscn", "--", "--cold-force"], output, true)
	check(code == 0, "fresh engine restores force-fire point and projectile from disk", output)
	await conclude("result.json")

func conclude(name: String) -> void:
	Ra2Sfx.stop_all()
	Music.stop()
	Music.player.stream = null
	await get_tree().process_frame
	OS.delay_msec(150)
	await get_tree().process_frame
	var file := FileAccess.open(output_dir.path_join(name), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failed": failed}, "  "))
	file.close()
	print("FORCE_FIRE checks=", checks.size(), " failed=", failed)
	get_tree().quit(0 if failed == 0 else 1)

func unit(id: String, point: Vector2, side := "ally"):
	# This empty arena has no player base for enemy wave rally orders. Spawn
	# stationary actors, then use the real side/group transition for enemies.
	var actor = battle.spawn_unit(id, "ally", point)
	if side != "ally": AlliedAbilities.change_side(actor, side)
	actor.process_mode = Node.PROCESS_MODE_DISABLED
	return actor

func building(id: String, point: Vector2, side := "ally"):
	var actor = battle._place_building(id, side, point, true)
	actor.process_mode = Node.PROCESS_MODE_DISABLED
	actor._buildup_play = -1.0
	return actor

func ctrl(pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_CTRL
	event.physical_keycode = KEY_CTRL
	event.pressed = pressed
	Input.parse_input_event(event)
	await get_tree().process_frame

func force_click(pixel: Vector2, append := false) -> void:
	# Render-window focus can change while collecting the screenshot. Restore
	# the same focus signal the real game requires before injecting input.
	get_window().focus_entered.emit()
	await move_pointer(pixel)
	await ctrl(true)
	battle.command_cursor.refresh(0.0)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = pixel
		event.global_position = pixel
		event.pressed = pressed
		event.ctrl_pressed = true
		event.shift_pressed = append
		stage.push_input(event, true)
		await get_tree().process_frame
	await ctrl(false)

func align(actor, target) -> void:
	var angle: float = actor.global_position.direction_to(target.global_position).angle()
	actor.hull_angle = angle
	actor.turret_angle = angle
	actor.aim_dir = Vector2.RIGHT.rotated(angle)
	actor._cd_timer = 0.0
	actor._cancel_burst()

func advance_shots() -> void:
	for frame in 120:
		for shot in battle.projectiles_root.get_children():
			if shot is Projectile and not shot.is_queued_for_deletion(): shot._physics_process(1.0 / 60.0)
	await get_tree().process_frame

func exercise_mode(mode: String) -> void:
	prefix = mode + ": "
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
	for actor in battle.units + battle.buildings: actor.free()
	battle.units.clear(); battle.buildings.clear()
	for group in ["obstacles", "resource_nodes"]:
		for actor in get_tree().get_nodes_in_group(group): actor.free()
	battle.water_rects.clear(); battle.path_service.set_water([])
	battle._refresh_pathing()
	battle.power_low = false
	GM.god_mode = false; GM.one_shot_kill = false; GM.infinite_power = false
	battle.camera.position = Vector2(1600, 1600)
	battle.camera.reset_smoothing(); battle.camera.force_update_scroll()
	get_window().focus_entered.emit()
	await get_tree().process_frame
	var tank = unit("MTNK", Vector2(1600, 1600))
	var friend = unit("MTNK", Vector2(1700, 1600))
	place_art_at(tank, Vector2(650, 400)); place_art_at(friend, Vector2(800, 400))
	battle.select_unit(tank, false)
	await move_pointer(Vector2(800, 400)); await ctrl(true)
	get_window().focus_entered.emit()
	battle.command_cursor.refresh(0.0)
	check(Input.is_key_pressed(KEY_CTRL) and battle.command_cursor.resolve(friend.art_center()) == "attack", prefix + "Ctrl hover uses original attack icon over ally")
	check(battle.command_cursor.sprite.visible and battle.command_cursor.state == "attack", prefix + "actual cursor sprite displays attack state")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		stage.get_texture().get_image().save_png(output_dir.path_join(mode + "-force-attack-cursor.png"))
	await ctrl(false)
	await force_click(Vector2(800, 400))
	check(tank.attack_ordered and tank.attack_target == friend and ForceFire.active(tank, friend), prefix + "real Ctrl-left targets ally")
	check(battle.selected_units == [tank] and not battle.dragging and not Input.is_key_pressed(KEY_CTRL), prefix + "release preserves selection and sustained order without selection drag")
	friend.hp = friend.max_hp
	var before: float = friend.hp
	align(tank, friend)
	check(tank._try_fire_ready(), prefix + "normal turn/cooldown weapon path accepts explicit friendly order")
	check(not tank._try_fire_ready(), prefix + "force fire cannot bypass cooldown")
	await advance_shots()
	check(friend.hp < before, prefix + "real shell applies friendly armor damage")
	battle.stop_selected()
	check(not ForceFire.active(tank, friend) and tank.attack_target == null, prefix + "S path clears force fire")
	tank.attack_target = friend; tank.attack_ordered = true
	align(tank, friend)
	check(not tank._try_fire_ready(), prefix + "ordinary target order cannot implicitly friendly fire")
	tank.order_stop()
	var enemy = unit("MTNK", Vector2(1900, 1600), "enemy")
	place_art_at(enemy, Vector2(900, 400))
	await force_click(Vector2(900, 400))
	check(tank.attack_target == enemy and ForceFire.active(tank, enemy), prefix + "Ctrl-left selects real enemy actor rather than an empty ground point")
	tank.order_stop()
	battle.units.erase(enemy); enemy.free()
	# GUI owns Ctrl clicks too, including the minimap.
	for pixel in [screen.hud.prod_panel.get_global_rect().end - Vector2(20, 20), screen.hud.minimap.get_global_rect().get_center()]:
		await force_click(pixel)
		check(tank.attack_target == null and not battle.dragging, prefix + "Ctrl click on HUD or minimap does not fire")
	await ground(tank, friend)
	await restrictions(tank)
	await defenses()
	await mixed_and_lethal()
	await passenger_fire()
	await persistence(mode, tank)
	screen.free()
	get_tree().paused = false
	await get_tree().process_frame

func ground(tank, friend) -> void:
	tank.position = Vector2(1500, 1500)
	friend.position = Vector2(2100, 2100)
	var aim := Vector2(1600, 1500)
	var pixel: Vector2 = stage.get_canvas_transform() * aim
	battle.select_unit(tank, false)
	await force_click(pixel)
	var point = tank.attack_target
	check(point is ForceFirePoint and point.global_position.is_equal_approx(aim), prefix + "empty ground creates a fixed order point")
	if not point is ForceFirePoint: return
	check(point not in battle.units and point not in battle.buildings, prefix + "ground point is not a scene actor or blocker")
	friend.position = aim
	var before: float = friend.hp
	align(tank, point)
	check(tank._try_fire_ready(), prefix + "shell fires at stationary ground coordinate")
	await advance_shots()
	check(friend.hp < before and tank.attack_target == point and point.hp == 1.0, prefix + "ground impact damages a real ally at the point and keeps firing order")
	friend.position = Vector2(2100, 2100)
	before = friend.hp
	align(tank, point); tank._try_fire_ready()
	await advance_shots()
	check(friend.hp == before and point.global_position.is_equal_approx(aim), prefix + "unit leaving impact point is not followed")
	var laser = unit("SREF", Vector2(1500, 1600))
	battle.select_unit(laser, false)
	check(ForceFire.issue(battle, aim) == 1, prefix + "prism can force fire ground")
	friend.position = aim
	before = friend.hp
	align(laser, laser.attack_target)
	check(laser._try_fire_ready(), prefix + "beam ground order uses regular weapon path")
	await advance_shots()
	check(friend.hp < before, prefix + "beam ground impact deals damage")
	laser.order_move(Vector2(1400, 1400))
	check(not laser.special.has(ForceFire.KEY) and laser.attack_target == null, prefix + "ordinary move clears force fire state")
	friend.position = Vector2(2100, 2100)
	battle.select_unit(tank, false)
	ForceFire.issue(battle, aim)
	battle._issue_order(Vector2(1450, 1700), false, true)
	check(tank.has_move_order and tank.attack_move and tank.attack_target == null and not tank.special.has(ForceFire.KEY), prefix + "Ctrl-right replaces force fire with attack move")
	battle._issue_order(friend.art_center(), true, true)
	tank._advance_queue()
	check(tank.has_move_order and tank.attack_move and not tank.attack_ordered and tank.order_queue.is_empty(), prefix + "queued Ctrl-right over ally remains an attack move when executed")
	tank.order_stop()
	var first = unit("MTNK", Vector2(1450, 1450), "enemy")
	var skipped = unit("MTNK", Vector2(1320, 1450), "enemy")
	var last = unit("MTNK", Vector2(1200, 1450), "enemy")
	battle._issue_order(first.art_center(), true)
	battle._issue_order(skipped.art_center(), true)
	battle.arm_command("attack")
	battle._issue_command_at(last.art_center(), true)
	battle.arm_command("")
	check(tank.attack_target == first and tank.order_queue.size() == 2, prefix + "Shift right-click and A append live targets")
	var preview = preload("res://scripts/world/movement_order_preview.gd")
	check(preview.routes(battle)[0].points.size() == 4, prefix + "attack route displays all designated enemies")
	skipped.free()
	first.hp = 0.0
	tank._refresh_target()
	check(tank.attack_target == last and tank.attack_ordered and tank.order_queue.is_empty(), prefix + "skip previously freed target after first kill")
	last.hp = 0.0
	tank._refresh_target()
	var bystander = unit("MTNK", tank.position + Vector2(48, 0), "enemy")
	tank._refresh_target()
	check(tank.attack_target == null and not tank.attack_ordered and not tank.has_move_order, prefix + "finished list stays stopped around another enemy")
	battle._command_move(Vector2(1410, 1700))
	place_art_at(friend, Vector2(800, 400))
	await force_click(Vector2(800, 400), true)
	check(tank.has_move_order and tank.order_queue.size() == 1, prefix + "Ctrl-Shift ally attack queues behind move")
	tank.has_move_order = false
	tank._advance_queue()
	check(ForceFire.active(tank, friend), prefix + "queued friendly attack retains force permission")
	battle._command_move(Vector2(1450, 1700), true)
	check(tank.attack_target == friend and tank.order_queue.size() == 1, prefix + "move queues behind stationary attack")
	tank.order_stop()
	check(tank.order_queue.is_empty() and not tank.special.has(ForceFire.KEY), prefix + "stop cancels both active and pending orders")
	bystander.free()
	first.free()
	last.free()
	battle.select_unit(tank, false)
	tank.set_fire_stance("none")
	ForceFire.issue(battle, aim)
	battle._command_move(Vector2(1450, 1700), true)
	var ground_target = tank.attack_target
	align(tank, ground_target)
	tank._physics_process(1.0 / 60.0)
	check(tank.has_move_order and not tank.attack_ordered and tank.order_queue.is_empty() and tank.fire_stance == "none", prefix + "hold-fire unit completes explicit ground volley then executes queued move")
	tank.order_stop()
	var mover = unit("MTNK", Vector2(800, 800))
	battle.select_unit(mover, false)
	check(ForceFire.issue(battle, Vector2(1400, 800)) == 1, prefix + "mobile unit accepts distant ground order")
	var start: Vector2 = mover.position
	mover.process_mode = Node.PROCESS_MODE_ALWAYS
	mover.set_physics_process(false)
	await get_tree().physics_frame
	for frame in 60: mover._physics_process(1.0 / 60.0)
	check(mover.position.distance_to(Vector2(1400, 800)) < start.distance_to(Vector2(1400, 800)), prefix + "normal movement closes to ground weapon range")
	mover.order_stop()
	mover.process_mode = Node.PROCESS_MODE_DISABLED
	# Existing RA3 unit shares force-fire order semantics without changing its delay.
	var mirage = unit("R3MIRAGE", Vector2(1500, 1550))
	battle.select_unit(mirage, false)
	ForceFire.issue(battle, aim)
	friend.position = aim; friend.hp = friend.max_hp
	before = friend.hp
	align(mirage, mirage.attack_target)
	check(mirage._try_fire_ready() and friend.hp == before, prefix + "RA3 forced ground beam retains delayed damage")
	await advance_shots()
	check(friend.hp < before, prefix + "RA3 delayed ground beam hits a real actor once")
	mirage.order_stop(); friend.position = Vector2(2100, 2100)

func restrictions(tank) -> void:
	# Keep this ground-only case away from the larger models in earlier cases.
	var aim := Vector2(1600, 1500)
	var empty_ground := Vector2(2800, 2800)
	for id in ["ENGINEER", "SPY", "CMIN", "DOG", "SNIPE", "CLEG", "PTROOP"]:
		var actor = unit(id, Vector2(2600, 2600))
		battle.select_unit(actor, false)
		check(ForceFire.pick(battle, empty_ground) is ForceFirePoint, prefix + id + " restriction fixture actually targets empty ground")
		check(ForceFire.issue(battle, empty_ground) == 0 and not actor.attack_ordered, prefix + id + " cannot use an incompatible weapon against ground")
		battle.units.erase(actor); actor.free()
	battle.select_unit(tank, false)
	check(ForceFire.issue(battle, tank.art_center()) == 0, prefix + "self targeting rejected")
	check(ForceFire.issue(battle, Vector2(-10, 10)) == 0, prefix + "outside-map target rejected")
	var plane = unit("ORCA", Vector2(1500, 1500))
	plane.logistics.air_state = "parked"
	plane.logistics.air_lift = 1.0
	battle.select_unit(plane, false)
	check(ForceFire.issue(battle, aim) == 1, prefix + "aircraft accepts ground sortie order")
	check(plane.logistics.air_state == "flying", prefix + "parked aircraft launches for a new force order")
	var ammo: int = plane.logistics.ammo
	align(plane, plane.attack_target)
	check(plane._try_fire_ready() and plane.logistics.ammo == ammo - 1, prefix + "force attack consumes original aircraft ammo")
	plane.logistics.ammo = 0; align(plane, plane.attack_target)
	check(not plane._try_fire_ready(), prefix + "empty aircraft cannot force unlimited shots")
	var next_sortie = unit("MTNK", Vector2(1560, 1640), "enemy")
	plane.order_target(next_sortie, false, true)
	plane._finish_ground_waypoint()
	plane.logistics.tick(0.01)
	check(not plane.attack_ordered and plane.order_queue.size() == 1, prefix + "empty plane retains designated next target while returning")
	plane.logistics.ammo = plane.logistics.ammo_max
	plane.logistics.park_after_sortie()
	check(plane.attack_target == next_sortie and plane.logistics.air_state == "flying", prefix + "reloaded plane resumes only explicitly queued sortie")
	plane.order_stop()
	var gi = unit("E1", Vector2(1500, 1500))
	gi.deploy()
	battle.select_unit(gi, false)
	check(ForceFire.issue(battle, aim) == 1, prefix + "deployed infantry can force fire in range")
	var origin: Vector2 = gi.position
	gi._physics_process(1.0 / 60.0)
	check(gi.is_deployed() and gi.position == origin and not gi.has_move_order, prefix + "forced attack preserves deployed immobility")
	check(ForceFire.issue(battle, Vector2(2800, 2800)) == 0, prefix + "deployed infantry does not chase out-of-range point")
	gi.order_stop()
	var friendly_plane = unit("ORCA", Vector2(1500, 1800))
	friendly_plane.logistics.air_lift = 1.0
	battle.select_unit(tank, false)
	check(not ForceFire.reason(battle, tank, friendly_plane).is_empty(), prefix + "ground cannon cannot force air target")

func defenses() -> void:
	var bunker=building("NABNKR",Vector2(800,850))
	var point:Vector2=bunker.position+Vector2(125,0)
	battle.select_building(bunker)
	check(ForceFire.issue(battle,point)==0,prefix+"empty bunker cannot force fire")
	var crew=unit("E2",bunker.position)
	var garrison=preload("res://scripts/units/civilian_orders.gd")
	garrison.enter(crew,bunker)
	check(ForceFire.issue(battle,point)==1 and bunker.attack_target is ForceFirePoint,prefix+"occupied bunker accepts ground order")
	var ground_victim=unit("E1",point)
	var before_ground:float=ground_victim.hp
	garrison.tick(crew,0.1)
	await advance_shots()
	check(ground_victim.hp<before_ground and ForceFire.active(crew,bunker.attack_target),prefix+"occupied bunker damages friendly at designated ground point")
	battle.stop_selected()
	check(not ForceFire.active(crew,crew.attack_target),prefix+"stop clears crew force policy")
	check(ForceFire.issue(battle,point+Vector2(1000,0))==0,prefix+"bunker rejects distant ground")
	var pill=building("GAPILL",Vector2(1300,850))
	battle.select_building(pill)
	check(battle.has_selected_attack_building(),prefix+"pillbox exposes attack command")
	battle.arm_command("attack")
	battle._issue_command_at(pill.position+Vector2(90,0))
	check(pill.attack_target is ForceFirePoint and pill._fire(),prefix+"pillbox attack command fires at ground")
	battle.stop_selected()
	var gun = building("GTGCAN", Vector2(2300, 2000))
	var ally = unit("MTNK", Vector2(2500, 2000))
	battle.select_building(gun)
	check(ForceFire.issue(battle, Vector2(2400, 2000)) == 0, prefix + "grand cannon retains minimum firing distance")
	check(ForceFire.issue(battle, ally.art_center()) == 1, prefix + "defense can force fire ally")
	gun._acquire_target()
	check(gun.attack_target == ally, prefix + "defense auto acquisition retains explicit friendly target")
	gun._turret_art.angle = gun.global_position.direction_to(ally.global_position).angle()
	var before: float = ally.hp
	check(gun._fire(), prefix + "defense normal firing path accepts force order")
	await advance_shots()
	check(ally.hp < before, prefix + "defense shell applies actual friendly damage")
	battle.stop_selected()
	check(gun.attack_target == null and not gun.special.has(ForceFire.KEY), prefix + "stop selected also cancels defense force fire")
	var patriot = building("NASAM", Vector2(2300, 2300))
	battle.select_building(patriot)
	check(ForceFire.issue(battle, Vector2(2450, 2300)) == 0, prefix + "AA defense cannot fire at empty ground")
	var prism = building("ATESLA", Vector2(2300, 2400))
	battle.select_building(prism)
	check(ForceFire.issue(battle, Vector2(2450, 2400)) == 1, prefix + "laser defense accepts ground point")
	var victim = unit("MTNK", Vector2(2450, 2400))
	before = victim.hp
	check(prism._fire() and victim.hp < before, prefix + "instant defense ground beam applies damage")
	ForceFire.clear(prism); prism.attack_target = null

func mixed_and_lethal() -> void:
	var shooter = unit("MTNK", Vector2(700, 1300))
	var spy = unit("SPY", Vector2(700, 1400))
	var victim = unit("MTNK", Vector2(900, 1300))
	victim.hp = 1.0
	battle.select_unit(shooter, false); battle.select_unit(spy, true)
	check(ForceFire.issue(battle, victim.art_center()) == 1 and not spy.attack_ordered, prefix + "mixed force order filters noncombatant without disguise or special actions")
	var xp: float = shooter._vet_kills
	align(shooter, victim)
	shooter._try_fire_ready()
	await advance_shots()
	check(not is_instance_valid(victim) or victim._dead, prefix + "forced friendly hit can actually destroy target")
	check(shooter._vet_kills == xp, prefix + "friendly kill never grants veterancy XP")
	shooter._refresh_target()
	check(not shooter.attack_ordered and not shooter.special.has(ForceFire.KEY), prefix + "dead forced target clears order and flag")

func passenger_fire() -> void:
	var carrier = unit("BFRT", Vector2(500, 2200))
	var crew = unit("E1", carrier.position + Vector2(0, 30))
	check(crew.logistics.request_board(carrier), prefix + "passenger receives real boarding order")
	crew.logistics.tick(0.1)
	check(crew.embarked_in == carrier, prefix + "passenger actually boards")
	var victim = unit("E1", Vector2(600, 2200))
	battle.select_unit(carrier, false)
	check(ForceFire.issue(battle, victim.art_center()) == 1, prefix + "carrier can force fire friendly infantry")
	var before: float = victim.hp
	OpenTopped.tick(crew, 0.1)
	await advance_shots()
	check(victim.hp < before and ForceFire.active(crew, victim), prefix + "embarked weapon inherits explicit friendly attack and deals damage")
	carrier.order_stop()
	check(not ForceFire.active(crew, victim), prefix + "carrier stop cancels passenger force policy")
	crew.order_stop()
	# Real building hit and splash must obey armor and both-side candidate rules.
	var gun = unit("MTNK", Vector2(500, 2500))
	var plant = building("GAPOWR", Vector2(650, 2500))
	battle.select_unit(gun, false)
	check(ForceFire.issue(battle, plant.art_center()) == 1, prefix + "friendly building can be explicitly targeted")
	before = plant.hp
	align(gun, plant); gun._try_fire_ready()
	await advance_shots()
	check(plant.hp < before, prefix + "friendly building receives actual cannon damage")
	gun.order_stop()

func persistence(mode: String, tank) -> void:
	battle.units = battle.units.filter(is_instance_valid)
	battle.buildings = battle.buildings.filter(is_instance_valid)
	for actor in battle.units:
		actor.order_stop()
	for actor in battle.buildings:
		ForceFire.clear(actor); actor.attack_target = null
	for shot in battle.projectiles_root.get_children(): shot.free()
	var legacy := Snapshot.new().capture(battle)
	check(legacy.records.all(func(record): return record.kind != "force_fire_point"), prefix + "legacy fixture contains only old record kinds")
	var bytes := var_to_bytes(legacy)
	var envelope := {"version": BattleSaves.VERSION, "content": BattleSaves.pre_force_fire_hash(), "hash": BattleSaves.digest(bytes), "payload": bytes}
	var path := output_dir.path_join(mode + "-pre-force.itsave")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(BattleSaves.pack_file(envelope)); file.close()
	check(BattleSaves.read_path(path).ok, prefix + "pre-force-fire content hash remains loadable")
	envelope.content = "unrelated-rule-change"
	file = FileAccess.open(path + ".bad", FileAccess.WRITE)
	file.store_buffer(BattleSaves.pack_file(envelope)); file.close()
	check(not BattleSaves.read_path(path + ".bad").ok, prefix + "unrelated content mismatch still rejected")
	tank.position = Vector2(1000, 1000)
	battle.select_unit(tank, false)
	check(ForceFire.issue(battle, Vector2(1100, 1000)) == 1, prefix + "save fixture force order")
	align(tank, tank.attack_target)
	tank._try_fire_ready()
	var queued = unit("MTNK", Vector2(1190, 1020), "enemy")
	tank.order_target(queued, false, true)
	var slot := "slot1" if mode == MatchRules.RA2 else "slot2"
	check(BattleSaves.save_slot(battle, slot).ok, prefix + "point and in-flight forced shot serialize")
	var read: Dictionary = BattleSaves.read_slot(slot)
	check(read.ok, prefix + "disk force-fire save passes schema validation")
	if not read.ok: return
	Snapshot.new().restore(battle, read.snapshot)
	var restored = battle.selected_units[0]
	check(restored.attack_target is ForceFirePoint and restored.special[ForceFire.KEY] == restored.attack_target, prefix + "saved order and marker share restored point identity")
	check(restored.order_queue.size() == 1 and restored.order_queue[0].target in battle.units and restored.order_queue[0].target.side == "enemy", prefix + "saved route restores live target identity")
	var shots: Array = battle.projectiles_root.get_children()
	check(shots.size() == 1 and shots[0].target == restored.attack_target and shots[0].splinters.get("force_fire", false), prefix + "in-flight shot preserves point and friendly-hit policy")
	check(battle.paused and get_tree().paused, prefix + "load starts paused")
	for actor in battle.units + battle.buildings: actor.process_mode = Node.PROCESS_MODE_DISABLED
	get_tree().paused = false; battle.paused = false
	restored.order_stop()
	check(not restored.special.has(ForceFire.KEY), prefix + "restored force order can be cancelled")

func cold() -> void:
	get_tree().current_scene = null
	for slot in ["slot1", "slot2"]:
		var loaded: Dictionary = BattleSaves.load_into_scene(slot)
		check(loaded.ok, slot + " cold load through actual scene route")
		if not loaded.ok: continue
		await get_tree().process_frame
		await get_tree().process_frame
		var scene = get_tree().current_scene
		var world = scene.battle
		var actor = world.selected_units[0]
		check(actor.attack_target is ForceFirePoint and ForceFire.active(actor, actor.attack_target), slot + " cold reload resumes forced ground order")
		check(world.projectiles_root.get_child_count() == 1 and world.projectiles_root.get_child(0).target == actor.attack_target, slot + " cold projectile reference remaps")
		check(world.paused and get_tree().paused, slot + " cold load stays paused")
		get_tree().current_scene = null
		scene.free()
		get_tree().paused = false
		await get_tree().process_frame
