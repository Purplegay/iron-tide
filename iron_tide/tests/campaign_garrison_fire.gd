extends Node

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	var tree := get_tree()
	var mission := "yr_head_games"
	for arg in OS.get_cmdline_user_args():
		if arg in ["yr_time_shift", "yr_hollywood", "m01"]: mission = arg
	if mission != "yr_head_games":
		BattleRequest.configure_mission(mission, {"campaign_growth":false, "difficulty":1})
		var screen = load("res://scenes/battle.tscn").instantiate()
		tree.root.add_child(screen)
		tree.current_scene = screen
		var other: Battle = screen.battle
		await skip_intro(other)
		tree.quit(0 if await shared_contact(other) else 1)
		return
	var menu = load("res://scenes/campaign_command.tscn").instantiate()
	tree.root.add_child(menu)
	tree.current_scene = menu
	print("USER_DIR ", OS.get_user_data_dir())
	for label in ["苏军战役", "首脑游戏"]:
		for btn in menu.find_children("*", "Button", true, false):
			if btn.text == label and not btn.disabled:
				btn.pressed.emit()
				break
		await tree.process_frame
	if menu.mission.get("id") != "yr_head_games":
		push_error("Cannot enter Head Games: " + str(menu.mission.get("id")))
		tree.quit(2)
		return
	print("LAUNCH ", menu.mission.id)
	menu.launch()
	await tree.scene_changed
	print("BATTLE LOADED")
	var world: Battle = tree.current_scene.battle
	await skip_intro(world)
	world.allied_state.erase("head_brief_stage")
	var garrisons := world.units.filter(func(u): return u.side == "enemy")
	for actor in world.units + world.buildings:
		actor.set_physics_process(false)
		actor.set_process(false)
		if actor is Unit and actor.unit_id in ["YURI", "YURIPR", "MIND"]:
			actor.set_fire_stance("none")
	var failures := 0
	for sample in [["INIT", true], ["INIT", false], ["BRUTE", false], ["VIRUS", false], ["YURI", false]]:
		var id: String = sample[0]
		var solid: bool = sample[1]
		var guard: Unit = null
		for candidate in garrisons:
			if is_instance_valid(candidate) and candidate.unit_id == id and candidate.hold_position == solid:
				guard = candidate
				break
		if guard == null:
			failures += 1
			continue
		guard.set_physics_process(true)
		if id == "YURI": guard.set_fire_stance("free")
		var origin := guard.global_position
		var victim: Unit = world.spawn_unit("E2", "ally", origin + Vector2.RIGHT * minf(105.0, guard.attack_range * 0.75))
		victim.order_stop()
		victim.hold_position = true
		victim.set_fire_stance("none")
		print("CASE ", solid, " paused=", tree.paused, " position=", guard.position)
		victim.set_physics_process(false)
		victim.hp = 5000.0
		var hp := victim.hp
		var locked := false
		var fired := false
		for step in 65:
			await tree.physics_frame
			if not is_instance_valid(victim) or not is_instance_valid(guard): break
			locked = locked or guard.attack_target == victim
			fired = fired or (guard.attack_target == victim and guard._cd_timer > 0.0)
			if (id == "YURI" and victim.side == "enemy") or (locked and fired and victim.hp < hp): break
		var effect := victim.side == "enemy" if id == "YURI" else victim.hp < hp
		var original_order := guard.special.has("campaign_area_guard") != solid
		var ok := original_order and (locked or id == "YURI") and (fired or id == "YURI") and effect
		print("GARRISON ",id," hold=",solid," locked=",locked," fired=",fired," effect=",effect)
		if not ok:
			failures += 1
			if is_instance_valid(victim):
				print("DETAIL stance=",guard.fire_stance," range=",guard.attack_range," distance=",guard.position.distance_to(victim.position)," visibility=",world.actor_visible_to(guard.side,victim)," domain=",guard.attack_domain_valid(victim)," target_valid=",guard._weapon_target_valid(victim)," guard paused=",not guard.can_process()," group=",victim.is_in_group("allies")," side=",victim.side," target=",guard.attack_target," cd=",guard._cd_timer)
		guard.set_physics_process(false)
		if id == "YURI": guard.set_fire_stance("none")
		if is_instance_valid(victim): victim.queue_free()
		await tree.process_frame
	if not await area_guard_contact(world, garrisons): failures += 1
	tree.quit(int(failures > 0))

func skip_intro(world: Battle) -> void:
	for frame in 12:
		var film = world.get_node_or_null("HollywoodFilm")
		if film != null: film.skip.pressed.emit()
		await get_tree().process_frame
	if get_tree().paused: world.hud._toggle_pause()

func shared_contact(world: Battle) -> bool:
	for actor in world.units + world.buildings:
		actor.set_physics_process(false)
		actor.set_process(false)
	var guard: Unit = null
	var start := Vector2.ZERO
	for candidate in world.units:
		if candidate.side != "enemy" or candidate.unit_id not in ["E1", "E2", "INIT"]: continue
		for i in 8:
			var pos: Vector2 = candidate.global_position + Vector2.RIGHT.rotated(i * TAU / 8.0) * 100.0
			if world.path_service.is_blocked(pos): continue
			guard = candidate
			start = pos
			break
		if guard != null: break
	if guard == null:
		var at := world.player_start() + Vector2(850, 0)
		guard = world.spawn_unit("E2", "enemy", at)
		start = at + Vector2(100, 0)
	var unmarked := not guard.special.has("campaign_area_guard")
	var target: Unit = world.spawn_unit("E2", "ally", start)
	target.set_fire_stance("none")
	target.set_physics_process(false)
	target.hp = 5000.0
	guard.set_physics_process(true)
	var fired := false
	for i in 75:
		await get_tree().physics_frame
		fired = fired or (guard.attack_target == target and guard._cd_timer > 0)
		if fired and target.hp < 5000.0: break
	var ok := unmarked and fired and target.hp < 5000.0
	print("OTHER CAMPAIGN ",world.mission.id," unit=", guard.unit_id," unmarked=", unmarked," fired=", fired," damage=", 5000.0 - target.hp," distance=",guard.position.distance_to(target.position)," visible=",world.actor_visible_to(guard.side,target)," valid=",guard._weapon_target_valid(target)," stance=",guard.fire_stance," target=",guard.attack_target," special=",guard.special.keys())
	return ok

func area_guard_contact(world: Battle, garrisons: Array) -> bool:
	var guard: Unit = null
	var start := Vector2.ZERO
	for candidate in garrisons:
		if candidate.unit_id != "INIT" or candidate.hold_position: continue
		if candidate.sight < candidate.attack_range + 20.0: continue
		var origin: Vector2 = candidate.global_position
		if world.path_service.is_blocked(origin): continue
		var offset: float = candidate.attack_range + 14.0
		for i in 8:
			var destination := origin + Vector2.RIGHT.rotated(i * TAU / 8.0) * offset
			if world.path_service.is_blocked(destination) or not world.fog.is_visible_at("enemy", destination): continue
			if world.path_for_unit(candidate, destination).size() < 2: continue
			guard = candidate
			start = destination
			break
		if guard != null: break
	if guard == null:
		print("AREA GUARD no open fixture")
		return false
	var post := guard.global_position
	for other in world.units.duplicate():
		if is_instance_valid(other) and other != guard and other.global_position.distance_to(post) < 95.0:
			other.free()
	var victim: Unit = world.spawn_unit("E2", "ally", start)
	victim.set_fire_stance("none")
	victim.set_physics_process(false)
	victim.hp = 5000.0
	guard.set_physics_process(true)
	var fired := false
	for i in 90:
		await get_tree().physics_frame
		if victim.hp < 5000.0:
			fired = true
			break
	var moved := post.distance_to(guard.global_position) > 10.0
	victim.free()
	for i in 100:
		await get_tree().physics_frame
		if post.distance_to(guard.global_position) <= Unit.ARRIVE_EPS: break
	var returned := post.distance_to(guard.global_position) <= Unit.ARRIVE_EPS
	print("AREA GUARD moved=", moved, " fired=", fired, " returned=", returned, " post=",post," at=",guard.global_position," goal=",guard._chase_goal," path=",guard._path_pts.size())
	return moved and fired and returned
