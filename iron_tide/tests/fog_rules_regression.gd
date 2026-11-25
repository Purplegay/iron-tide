extends "res://tests/base_recovery_regression.gd"

func _ready() -> void:
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not ProjectSettings.get_setting("application/config/use_custom_user_dir", false):
		get_tree().quit(2)
		return
	Events.battle_ended.connect(func(result): results.append(result))
	await get_tree().process_frame
	for mode in [MatchRules.RA2, MatchRules.EXTENDED]:
		await exercise_yard_sight(mode)
		await exercise_hidden_placement(mode)
		await exercise_visibility(mode)
		await exercise_death_sight(mode)
		await exercise_bomb_sight(mode)
		for side in ["ally", "enemy"]:
			for id in ["MTNK", "SREF", "GTGCAN", "GAPILL"]:
				await exercise_fire_reveal(mode, side, id)
		for rule in ["short", "annihilation"]:
			for defeated in ["ally", "enemy", "both"]:
				await exercise_rules(mode, rule, defeated)
	exercise_team_scout_masks()
	exercise_vacated_scout_masks()
	await exercise_lobby()
	for map_size in [2400, 3200, 4000]:
		for opening in ["prebuilt", "mcv"]:
			await exercise_starting_resources(map_size, opening)
	var f := FileAccess.open(output_dir.path_join("result.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks": checks, "failed": failed}, "  "))
	f.close()
	get_tree().quit(0 if failed == 0 else 1)

func exercise_hidden_placement(mode: String) -> void:
	start(mode)
	var fog = preload("res://scripts/world/fog_of_war.gd").new()
	battle.fog = fog
	battle.add_child(fog)
	fog.setup(battle)
	var yard = battle._place_building("GACNST", "ally", Vector2(1200, 1200), true)
	var pos := Vector2(1360, 1200)
	var data := GameData.get_building("GAPOWR")
	fog.visible_cells.ally.fill(0)
	fog.explored_cells.ally.fill(0)
	check(not battle.position_visible_to("ally", pos) and not battle.position_explored_by("ally", pos), prefix + "site is unexplored")
	check(battle.build_spot_ok(pos, data, true).ok, prefix + "legal hidden site permits placement")
	check(battle.build_spot_ok(yard.global_position, data, true).reason == "与建筑重叠", prefix + "occupied hidden foundation rejects placement")
	var before: int = battle.buildings.size()
	battle.armed_build = "GAPOWR"
	battle._try_place_building(pos)
	check(battle.buildings.size() == before + 1 and battle.buildings.back().global_position == pos, prefix + "click places power plant in fog")
	await finish()

func exercise_yard_sight(mode: String) -> void:
	start(mode)
	for building in battle.buildings: building.free()
	battle.buildings.clear()
	var center := Vector2(1200, 1200)
	var fog = preload("res://scripts/world/fog_of_war.gd").new()
	battle.fog = fog
	battle.add_child(fog)
	fog.setup(battle)
	for id in ["GACNST", "NACNST"]:
		for side in ["ally", "enemy"]:
			var yard = battle._place_building(id, side, center, true)
			fog.rebuild()
			var label: String = prefix + side + " " + str(id)
			check(is_equal_approx(fog.vision_radius(yard), 660.0), label + " expanded operational radius")
			var ring_visible := true
			var beyond_hidden := true
			for i in 32:
				var direction := Vector2.from_angle(TAU * i / 32)
				ring_visible = ring_visible and battle.position_visible_to(side, center + direction * 659.0)
				beyond_hidden = beyond_hidden and not battle.position_visible_to(side, center + direction * 725.0)
			check(ring_visible and beyond_hidden, label + " actual visible ring and outer fog")
			battle.buildings.erase(yard)
			yard.free()
			fog._process(6.0)
			fog.rebuild()
			check(not battle.position_visible_to(side, center + Vector2(620, 0)) and battle.position_explored_by(side, center + Vector2(620, 0)), label + " removal leaves explored terrain after sight hold")
	await finish()

func exercise_visibility(mode: String) -> void:
	start(mode)
	var stage := SubViewport.new()
	stage.size = Vector2i(1600, 900)
	stage.world_2d = World2D.new()
	stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(stage)
	screen.reparent(stage)
	check(battle.fog == null and battle.position_visible_to("ally", Vector2(100, 100)), prefix + "legacy config without fog remains clear")
	var a = battle.spawn_unit("MTNK", "ally", Vector2(1020, 1020))
	var b = battle.spawn_unit("MTNK", "enemy", Vector2(1420, 1020))
	a.sight = 100.0
	b.sight = 100.0
	# Range now contributes vision. Keep this fixture outside both sources.
	a.attack_range = 200.0
	b.attack_range = 200.0
	# Remove unrelated vision sources while preserving actual actors and command paths.
	for building in battle.buildings:
		building.sight = 40.0
		building.attack_range = 0.0
	battle.fog = preload("res://scripts/world/fog_of_war.gd").new()
	battle.add_child(battle.fog)
	battle.fog.setup(battle)
	check(not battle.actor_visible_to("ally", b) and not b.visible, prefix + "unseen enemy absent from world rendering")
	check(not battle.actor_visible_to("enemy", a), prefix + "opponent obeys independent same visibility rule")
	check(battle._pick_enemy_at(b.global_position) == null, prefix + "hidden enemy cannot be picked")
	a._refresh_target()
	b._refresh_target()
	check(a.attack_target == null and b.attack_target == null, prefix + "weapons cannot acquire outside shared sight and weapon vision")
	check(not a._weapon_target_valid(b) and not b._weapon_target_valid(a), prefix + "fire checks reject unseen target")
	battle.select_unit(a, false)
	battle.force_attack(b)
	check(a.attack_target == null and not a.attack_ordered, prefix + "direct focus command cannot bypass fog")
	var scout = battle.spawn_unit("E1", "ally", Vector2(1320, 1020))
	scout.sight = 200.0
	battle.fog.rebuild()
	check(battle.actor_visible_to("ally", b) and b.visible, prefix + "scout reveals target for entire army")
	check(not battle.actor_visible_to("enemy", a), prefix + "scout revelation does not reveal own distant tank to opponent")
	battle.force_attack(b)
	check(a.attack_target == b and a.attack_ordered and a._weapon_domain_valid(b) and not a._weapon_target_valid(b), prefix + "scout permits focus but distant target still requires moving into range")
	await reveal_photo(mode + "-terrain-visible")
	var remembered: Vector2 = b.global_position
	scout.global_position = Vector2(220, 220)
	battle.fog.rebuild()
	battle.fog._process(4.9)
	check(b.visible and battle.actor_visible_to("ally", b), prefix + "retreat leaves brief live sight in the scouted area")
	battle.fog._process(0.1)
	a._refresh_target()
	check(not battle.actor_visible_to("ally", b) and not b.visible and a.attack_target == null,
		prefix + "losing sight cancels live target tracking")
	check(battle.position_explored_by("ally", remembered) and not battle.position_visible_to("ally", remembered),
		prefix + "explored terrain persists after scout leaves")
	var reinforcement = battle.spawn_unit("E1", "enemy", remembered)
	check(not reinforcement.visible, prefix + "new enemy on explored terrain is hidden immediately before fog tick")
	var new_building = battle._place_building("GAPOWR", "enemy", remembered + Vector2(40, 0), true)
	check(not new_building.visible, prefix + "new enemy structure cannot flash on explored terrain")
	check(not battle.position_explored_by("ally", Vector2(20, 2380)), prefix + "distant unexplored terrain remains unknown")
	var sample: Color = battle.fog.mask_image.get_pixel(35, 25)
	check(sample.a == 0.0, prefix + "lost terrain does not instantly turn dark", sample)
	await reveal_photo(mode + "-terrain-hold")
	check(battle.fog.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR, prefix + "world fog softens cell boundaries")
	battle.fog._process(0.3)
	battle.fog.rebuild()
	check(absf(battle.fog.mask_image.get_pixel(35, 25).a - 0.1125) < 0.005, prefix + "fade begins immediately and survives visibility rebuild")
	battle.paused = true
	battle.fog._process(10.0)
	check(absf(battle.fog.mask_image.get_pixel(35, 25).a - 0.1125) < 0.005, prefix + "pause freezes visual fading")
	battle.paused = false
	battle.fog._process(0.3)
	sample = battle.fog.mask_image.get_pixel(35, 25)
	check(absf(sample.a - 0.225) < 0.005, prefix + "fog reaches half opacity halfway through fade", sample)
	await reveal_photo(mode + "-terrain-fading")
	check(not b.visible and not battle.actor_visible_to("ally", b) and not a._weapon_target_valid(b), prefix + "visual delay grants no enemy rendering or targeting")
	battle.fog._process(0.7)
	sample = battle.fog.mask_image.get_pixel(35, 25)
	check(absf(sample.a - 0.45) < 0.005 and sample.r == 0.0 and sample.g == 0.0 and sample.b == 0.0, prefix + "explored terrain settles at lighter neutral shade", sample)
	await reveal_photo(mode + "-terrain-settled")
	check(battle.fog.mask_image.get_pixel(0, 59).a == 1.0, prefix + "unexplored terrain stays opaque")
	scout.global_position = Vector2(1320, 1020)
	battle.fog.rebuild()
	check(battle.fog.mask_image.get_pixel(35, 25).a == 0.0 and b.visible, prefix + "returning scout immediately clears visual fog")
	scout.global_position = Vector2(220, 220)
	battle.fog.rebuild()
	battle.fog._process(5.0)
	check(battle.fog.mask_image.get_pixel(35, 25).a == 0.0 and not b.visible, prefix + "second loss starts a fresh fade without leaking enemy")
	# Frame partition must not change the final shade or leave a permanent trail.
	for tick in 100: battle.fog._process(0.02)
	check(absf(battle.fog.mask_image.get_pixel(35, 25).a - 0.45) < 0.005, prefix + "small frame steps converge to the same final fog opacity")
	var test_pos := Vector2(2020, 2020)
	var transport = battle.spawn_unit("LCRF", "ally", Vector2(220, 220))
	scout.global_position = test_pos
	scout.embarked_in = transport
	battle.fog.rebuild()
	check(not battle.position_visible_to("ally", test_pos) and not scout.visible, prefix + "passenger contributes no independent vision")
	scout.embarked_in = null
	scout._dead = true
	battle.fog.rebuild()
	check(not battle.position_visible_to("ally", test_pos), prefix + "dead scout contributes no vision")
	var effect := Node2D.new()
	effect.position = test_pos
	battle.effects_root.add_child(effect)
	battle.fog._filter_transient(effect)
	check(not effect.visible, prefix + "hidden transient effects suppressed")
	var ore = preload("res://scripts/world/resource_node.gd").new()
	ore.position = Vector2(20, 2380)
	battle.add_child(ore)
	var miner = battle.spawn_unit("CMIN", "ally", a.position)
	check(not battle.position_explored_by("ally",ore.position) and miner._ore_target()==ore, prefix+"miner locates reachable ore in black shroud")
	miner.harvest_state="to_node"
	miner.resource_node=null
	miner._process_harvester(1.0/60)
	check(miner.resource_node==ore and not battle.position_explored_by("ally",ore.position),prefix+"automatic dispatch targets the hidden ore without exploring it")
	check(battle._pick_node_at(ore.position, "resource_nodes") == null, prefix + "unknown ore cannot be clicked through shroud")
	battle.command_mode = ""
	battle.select_unit(miner, false)
	check(not battle._cursor_on_ore(ore.position), prefix + "cursor does not expose unexplored ore")
	# Save a retreat with more than three seconds of live sight still outstanding.
	scout._dead = false
	scout.position = remembered
	battle.fog.rebuild()
	scout.position = Vector2(220, 220)
	battle.fog.rebuild()
	battle.fog._process(0.5)
	BattleRequest.skirmish_config["fog_of_war"] = true
	var saved := BattleSaves.save_slot(battle,"quick")
	var slot := BattleSaves.read_slot("quick")
	check(saved.ok and slot.ok,prefix + "four and a half seconds of scout sight survives slot validation")
	if saved.ok and slot.ok:
		BattleSaves.Snapshot.new().restore(battle,slot.snapshot)
		battle.paused = false
		get_tree().paused = false
		battle.fog._process(4.4)
		check(battle.position_visible_to("ally",remembered),prefix + "restored retreat keeps its original remaining sight")
		battle.fog._process(0.1)
		check(not battle.position_visible_to("ally",remembered),prefix + "restored scout sight expires at five game seconds")
	await finish()
	stage.free()

func exercise_death_sight(mode: String) -> void:
	start(mode)
	var point := Vector2(1220, 1220)
	var scout = battle.spawn_unit("E1", "ally", point)
	var contact = battle.spawn_unit("E2", "enemy", point + Vector2(40, 0))
	var fog = preload("res://scripts/world/fog_of_war.gd").new()
	battle.fog = fog
	battle.add_child(fog)
	fog.setup(battle)
	scout._die(null, true)
	fog.rebuild()
	check(contact.visible and battle.actor_visible_to("ally", contact), prefix + "death retains live enemy contact")
	contact.global_position = Vector2(220, 2020)
	fog.rebuild()
	check(not contact.visible, prefix + "death sight stays at the last position")
	contact.global_position = point
	fog._process(1.0)
	battle.paused = true
	fog._process(10.0)
	battle.paused = false
	check(contact.visible and is_equal_approx(fog.sight_clock, 1.0), prefix + "pause freezes death sight")
	var codec = preload("res://scripts/save/battle_snapshot.gd").new()
	BattleRequest.skirmish_config["fog_of_war"] = true
	var saved := BattleSaves.save_slot(battle, "quick")
	check(saved.ok, prefix + "death sight saves through normal slot", saved)
	var loaded := BattleSaves.read_slot("quick")
	check(loaded.ok, prefix + "death sight passes normal slot validation")
	if not loaded.ok:
		await finish()
		return
	var snapshot: Dictionary = loaded.snapshot
	fog._process(4.0)
	check(not fog.is_visible_at("ally", point), prefix + "death sight expires without a survivor")
	codec.restore(battle, snapshot)
	battle.paused = false
	get_tree().paused = false
	fog._process(1.8)
	check(fog.is_visible_at("ally", point), prefix + "restored death sight survives until its original deadline")
	fog._process(0.3)
	check(not fog.is_visible_at("ally", point) and fog.is_explored_at("ally", point), prefix + "restored death sight expires into explored terrain")
	snapshot.context.erase("death_sight")
	fog.sight_until.ally[fog._index(point)] = 99.0
	codec.restore(battle, snapshot)
	battle.paused = false
	get_tree().paused = false
	fog.rebuild()
	check(not fog.is_visible_at("ally", point), prefix + "legacy saves discard later death sight")
	await finish()

func exercise_bomb_sight(mode: String) -> void:
	start(mode)
	var point := Vector2(1220, 1220)
	var far := Vector2(2020, 1020)
	var fog = preload("res://scripts/world/fog_of_war.gd").new()
	battle.fog = fog
	battle.add_child(fog)
	fog.setup(battle)
	var ivan = battle.spawn_unit("IVAN", "ally", point)
	var mark = battle.spawn_unit("E2", "enemy", point)
	var transport = battle.spawn_unit("SAPC", "enemy", far)
	ivan._fire_shot(mark)
	ivan.position = Vector2(220, 220)
	fog._process(5.1)
	check(mark.visible and fog.is_visible_at("ally", point + Vector2(100, 0)), prefix + "armed charge reveals nearby terrain after Ivan retreats")
	check(not fog.is_visible_at("ally", point + Vector2(200, 0)), prefix + "charge has limited sight")
	transport.position = point
	check(mark.logistics.request_board(transport), prefix + "armed passenger can board a transport")
	mark.logistics.tick(0.1)
	transport.position = far
	fog.rebuild()
	check(not mark.visible and transport.visible and not fog.is_visible_at("ally", point), prefix + "bomb on passenger reveals transport location only")
	preload("res://scripts/units/soviet_specials.gd").tick_actor(mark, 30.0)
	fog.rebuild()
	fog._process(1.0)
	BattleRequest.skirmish_config["fog_of_war"] = true
	var blast_saved := BattleSaves.save_slot(battle, "quick")
	var blast_slot := BattleSaves.read_slot("quick")
	check(blast_saved.ok and blast_slot.ok, prefix + "blast visibility saves without an armed target")
	if blast_saved.ok and blast_slot.ok:
		BattleSaves.Snapshot.new().restore(battle, blast_slot.snapshot)
		fog._process(10.0)
		battle.paused = false
		get_tree().paused = false
	fog._process(1.9)
	check(fog.is_visible_at("ally", far), prefix + "blast retains live sight at detonation point")
	fog._process(0.2)
	check(not fog.is_visible_at("ally", far) and fog.is_explored_at("ally", far), prefix + "blast sight ends after three seconds")
	await finish()
	start(mode)
	fog = preload("res://scripts/world/fog_of_war.gd").new()
	battle.fog = fog
	battle.add_child(fog)
	fog.setup(battle)
	check(not fog.is_visible_at("enemy", point), prefix + "building site starts outside enemy vision")
	var site = battle._place_building("GAPOWR", "ally", point, true)
	var enemy_ivan = battle.spawn_unit("CIVAN", "enemy", point)
	enemy_ivan._fire_shot(site)
	enemy_ivan.position = far
	fog._process(5.1) # Let the planter's own scouting trail expire before testing disarm.
	check(fog.is_visible_at("enemy", point), prefix + "enemy chrono Ivan reveals bombed building")
	BattleRequest.skirmish_config["fog_of_war"] = true
	var saved := BattleSaves.save_slot(battle, "quick")
	var loaded := BattleSaves.read_slot("quick")
	check(saved.ok and loaded.ok, prefix + "armed charge fog saves through battle slot")
	if saved.ok and loaded.ok:
		BattleSaves.Snapshot.new().restore(battle, loaded.snapshot)
		battle.paused = false
		get_tree().paused = false
		var sites: Array = battle.buildings.filter(func(b): return b.special.has("ivan_bomb"))
		check(sites.size() == 1 and fog.is_visible_at("enemy", point), prefix + "restored armed charge still reveals for original side")
		if sites.size() == 1:
			var engineer = battle.spawn_unit("ENGINEER", "ally", point)
			engineer.position = AlliedAbilities.approach(engineer, sites[0])
			AlliedAbilities.use(engineer, "allied_engineer", sites[0])
			AlliedAbilities.tick_action(engineer, 0.1)
			fog.rebuild()
			check(not fog.is_visible_at("enemy", point), prefix + "engineer disarm removes enemy charge vision")
	await finish()

func shoot(actor, target) -> bool:
	actor.attack_target = target
	if actor is Unit:
		actor._cd_timer = 0.0
		actor._cancel_burst()
		return actor._try_fire_ready()
	return actor._fire()

func reveal_photo(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	battle.camera.position = Vector2(1250, 1020)
	battle.camera.reset_smoothing()
	battle.camera.force_update_scroll()
	for i in 3: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	screen.get_viewport().get_texture().get_image().save_png(output_dir.path_join(name + ".png"))

func exercise_fire_reveal(mode: String, side: String, id: String) -> void:
	start(mode)
	# Offscreen viewport renders every frame even if the desktop window is occluded.
	var stage := SubViewport.new()
	stage.size = Vector2i(1600, 900)
	stage.world_2d = World2D.new()
	stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(stage)
	screen.reparent(stage)
	var label := "%s %s %s: " % [mode, side, id]
	var observer := "enemy" if side == "ally" else "ally"
	var origin := Vector2(1420, 1020)
	var attacker = battle._place_building(id, side, origin, true) if GameData.is_building(id) else battle.spawn_unit(id, side, origin)
	var victim = battle.spawn_unit("MTNK", observer, Vector2(1020, 1020))
	var scout = battle.spawn_unit("E1", side, Vector2(1120, 1020))
	for actor in battle.units + battle.buildings:
		actor.sight = 40.0
		actor.attack_range = 0.0
	attacker.sight = 100.0
	victim.sight = 100.0
	victim.attack_range = 200.0
	victim.hp = 100000.0
	scout.sight = 160.0
	attacker.attack_range = 1000.0
	if attacker is Unit:
		attacker.turret_angle = PI
		attacker.hull_angle = PI
		attacker.aim_dir = Vector2.LEFT
	else:
		attacker._buildup_play = -1.0
		attacker._turret_art.angle = PI
	battle.power_low = false
	battle.enemy_power.low = false
	battle.fog = preload("res://scripts/world/fog_of_war.gd").new()
	battle.add_child(battle.fog)
	battle.fog.setup(battle)
	check(not battle.actor_visible_to(observer, attacker) and battle.actor_visible_to(side, victim), label + "asymmetric scouting allows hidden firing source")
	attacker.attack_target = victim
	if attacker is Unit:
		attacker._cd_timer = 10.0
		check(not attacker._try_fire_ready(), label + "cooldown prevents firing")
	else:
		attacker.under_construction = true
		check(not attacker._fire(), label + "unfinished defense cannot fire")
		attacker.under_construction = false
	check(not battle.actor_visible_to(observer, attacker), label + "failed firing attempt does not reveal")
	if side == "enemy" and id == "MTNK": await reveal_photo(mode + "-before-fire")
	check(shoot(attacker, victim), label + "actual weapon fires with shared scout vision")
	check(battle.actor_visible_to(observer, attacker), label + "shot exposes attacker to victim side immediately")
	check(battle.position_visible_to(observer, origin) and battle.position_explored_by(observer, origin), label + "firing position opens fog and records terrain")
	check(not battle.position_visible_to(observer, origin + Vector2(0, 240)), label + "reveal remains local")
	check(victim._weapon_domain_valid(attacker) and not victim._weapon_target_valid(attacker), label + "revealed attacker can be targeted but short-range victim must approach")
	if side == "enemy":
		check(attacker.visible and battle._pick_enemy_at(origin) == attacker, label + "world rendering and picking share reveal")
		var cell := Vector2i(origin / 40.0)
		check(battle.fog.mask_image.get_pixelv(cell).a == 0.0, label + "world/minimap fog texture opens at firing point")
		var muzzle := Node2D.new()
		muzzle.position = origin
		battle.effects_root.add_child(muzzle)
		battle.fog._filter_transient(muzzle)
		check(muzzle.visible, label + "firing effect visible at exposed origin")
		muzzle.free()
	if side == "enemy" and id == "MTNK": await reveal_photo(mode + "-firing-revealed")
	battle.fog._process(1.5)
	check(battle.actor_visible_to(observer, attacker), label + "reveal survives fog rebuild")
	check(shoot(attacker, victim), label + "second actual shot refreshes reveal")
	battle.fog._process(1.6)
	check(battle.actor_visible_to(observer, attacker), label + "continued firing refreshes three-second window")
	battle.paused = true
	battle.fog._process(10.0)
	check(battle.actor_visible_to(observer, attacker), label + "pause freezes reveal timeout")
	battle.paused = false
	if attacker is Unit:
		attacker.global_position = origin + Vector2(0, 400)
		battle.fog.rebuild()
		check(not battle.actor_visible_to(observer, attacker) and battle.position_visible_to(observer, origin), label + "last shot location does not track fleeing unit")
		attacker.global_position = origin
		battle.fog.rebuild()
	battle.fog._process(1.5)
	check(not battle.actor_visible_to(observer, attacker) and not victim._weapon_target_valid(attacker), label + "ceasefire restores fog and target restrictions")
	check(battle.position_explored_by(observer, origin) and not battle.position_visible_to(observer, origin), label + "expiry keeps terrain memory only")
	if side == "enemy": check(not attacker.visible, label + "expired enemy is removed from world rendering")
	if side == "enemy" and id == "MTNK": await reveal_photo(mode + "-ceased-fire")
	# A shot that misses still gives away its source; no hit/damage callback is needed.
	if attacker is Unit:
		victim.add_buff("dodge", 10.0, 1.0)
		var fixed_seed := 0
		seed(fixed_seed)
		while randf() <= 0.05:
			fixed_seed += 1
			seed(fixed_seed)
		seed(fixed_seed)
		var before_hp: float = victim.hp
		var before_projectiles: int = battle.projectiles_root.get_child_count()
		check(shoot(attacker, victim), label + "evaded shot consumes firing action")
		check(victim.hp == before_hp and battle.projectiles_root.get_child_count() == before_projectiles, label + "fixture takes real dodge branch")
		check(battle.actor_visible_to(observer, attacker), label + "miss still reveals firing origin")
	else:
		check(shoot(attacker, victim), label + "defense can expose itself again")
	var remembered: Vector2 = attacker.global_position
	if attacker is Unit: battle.units.erase(attacker)
	else: battle.buildings.erase(attacker)
	attacker.free()
	battle.fog._process(3.1)
	check(battle.fog.firing_positions.is_empty() and not battle.position_visible_to(observer, remembered), label + "destroyed source expires without stale object references")
	await finish()
	stage.free()

func exercise_starting_resources(map_size: int, opening: String) -> void:
	BattleRequest.configure_skirmish(MatchRules.RA2, {"map_size": map_size, "opening": opening, "fog_of_war": true})
	screen = load("res://scenes/battle.tscn").instantiate()
	add_child(screen)
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	battle = screen.battle
	var label := "%d %s: " % [map_size, opening]
	for side in ["ally", "enemy"]:
		check(battle.fog.starting_ore.has(side), label + side + " starts with nearby resource intelligence")
		var ore_pos: Vector2 = battle.fog.starting_ore.get(side, Vector2.ZERO)
		check(battle.position_explored_by(side, ore_pos), label + side + " known resource is explored terrain")
		var anchor
		for actor in battle.units + battle.buildings:
			if actor.side == side:
				anchor = actor
				break
		if opening == "mcv":
			check(battle.construction_deploy_check(anchor).ok, label + side + " fog permits starting MCV deployment")
		var miner = battle.spawn_unit("CMIN", side, anchor.position)
		var ore = miner._ore_target()
		check(ore != null and miner._ore_reachable(ore), label + side + " automatic miner starts with a reachable resource")
		# A hostile unit at the known ore still requires current sight.
		var intruder = battle.spawn_unit("E1", "enemy" if side == "ally" else "ally", ore_pos)
		var seen: bool = battle.position_visible_to(side, ore_pos)
		check(battle.actor_visible_to(side, intruder) == seen, label + side + " resource intelligence grants no enemy visibility")
		battle.units.erase(intruder)
		intruder.free()
		battle.units.erase(miner)
		miner.free()
	await finish()

func exercise_rules(mode: String, rule: String, defeated: String) -> void:
	start(mode)
	battle.mission["victory_condition"] = rule
	var a = battle.spawn_unit("MTNK", "ally", Vector2(1020, 1020))
	var b = battle.spawn_unit("MTNK", "enemy", Vector2(1420, 1020))
	if defeated in ["ally", "both"]:
		destroy_buildings("ally")
	if defeated in ["enemy", "both"]:
		destroy_buildings("enemy")
	var before := results.size()
	var currency_before := MetaProgress.currency.duplicate(true)
	var wins_before := MetaProgress.appearance_wins()
	if rule == "annihilation":
		battle._check_end()
		check(not battle.ended, prefix + rule + " ordinary tank keeps side alive: " + defeated)
		# Stowed surviving units also remain owned assets.
		a.embarked_in = b
		check(battle.has_surviving_assets("ally"), prefix + "stowed unit counts for annihilation")
		a.embarked_in = null
		# Destroyed buildings can now evacuate crew. An annihilated side must
		# lose those remaining assets as well as its original tank.
		for survivor in battle.units:
			if battle.actor_alive(survivor) and defeated in [survivor.side, "both"]:
				survivor._dead = true
				survivor.hp = 0.0
	battle._check_end()
	check(battle.ended and results.size() == before + 1, prefix + rule + " settles once: " + defeated)
	var result: Dictionary = results.back()
	check(result.outcome == ("draw" if defeated == "both" else ("win" if defeated == "enemy" else "loss")),
		prefix + rule + " correct result: " + defeated, result)
	if defeated == "both":
		# Production statistics / hero participation are recorded for draws too.
		# Those legitimate records must not be mistaken for a victory reward.
		check(result.rewards.is_empty() and MetaProgress.currency == currency_before and MetaProgress.appearance_wins() == wins_before, prefix + rule + " draw grants no victory currency or appearance win")
	battle._check_end()
	check(results.size() == before + 1, prefix + rule + " repeated check cannot settle again")
	await finish()

func exercise_lobby() -> void:
	BattleRequest.configure_skirmish(MatchRules.RA2, {"victory_condition": "annihilation", "fog_of_war": true})
	var preferences = preload("res://scripts/ui/lobby_preferences.gd")
	check(preferences.write({"rules_mode":"ra2","victory_condition":"annihilation","fog_of_war":true}) == OK, "persist isolated lobby preferences before restoring")
	var lobby = load("res://scenes/lobby.tscn").instantiate()
	add_child(lobby)
	check(lobby._victory_opt.selected == 1 and lobby._fog_check.button_pressed, "lobby restores victory and fog options")
	var config := GameData.make_skirmish_mission(BattleRequest.skirmish_config)
	check(config.victory_condition == "annihilation" and config.fog_of_war, "configured settings reach generated mission")
	lobby.free()
	screen = load("res://scenes/battle.tscn").instantiate()
	add_child(screen)
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	battle = screen.battle
	check(battle.fog != null and battle.mission.victory_condition == "annihilation", "actual scene setup consumes selected fog and victory rule")
	for building in battle.buildings:
		building._buildup_play = -1.0
	battle._update_power()
	screen.hud._refresh_top()
	var refinery
	for building in battle.buildings:
		if building.side == "ally" and building.is_refinery():
			refinery = building
	check(refinery != null, "real startup has refinery")
	if refinery != null:
		battle.select_building(refinery)
		battle._emit_selection()
		Ra3Skin.upgrade_tree(screen.hud.get_child(0), UiKit.RA_CYAN)
		battle.fog.rebuild()
		for i in 4:
			await get_tree().process_frame
		var hud = screen.hud
		check(hud._refinery_btn.is_visible_in_tree() and hud.ability_panel.get_global_rect().encloses(hud._refinery_btn.get_global_rect()), "paid miner skill remains visible in persistent skill bar")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(output_dir.path_join("fog-refinery-command-dock.png"))
	await finish()
	BattleRequest.configure_skirmish(MatchRules.RA2, {"victory_condition": "invalid", "fog_of_war": "false"})
	check(BattleRequest.skirmish_config.victory_condition == "short" and not BattleRequest.skirmish_config.fog_of_war, "invalid configuration normalizes safely")
	BattleRequest.configure_mission("m01", {})
	check(not BattleRequest.skirmish and not BattleRequest.skirmish_config.has("fog_of_war"), "campaign does not inherit skirmish fog or victory")

# The large-battle mask must match the per-scout raster byte for byte even at
# tile boundaries, on previously explored terrain and between opposing teams.
func exercise_team_scout_masks() -> void:
	var old_teams:=BattleRequest.house_teams.duplicate()
	BattleRequest.house_teams={"ally":1,"ai2":1,"enemy":2}
	var fog:=preload("res://scripts/world/fog_of_war.gd").new()
	fog.width=41
	var expected:Dictionary={}
	for mode in ["serial", "image", "workers"]:
		for side in BattleRequest.house_teams:
			var cells:=PackedByteArray()
			cells.resize(fog.width*fog.width)
			cells[3 if side=="ally" else 9]=1
			fog.visible_cells[side]=cells.duplicate()
			fog.explored_cells[side]=cells.duplicate()
			fog.sight_until[side]={}
		var batches := {}
		if mode != "serial":
			fog._begin_live_masks()
			for team in fog._live_masks:
				var batch := preload("res://scripts/world/fog_of_war.gd").SightBatch.new()
				batch.mask = fog._live_masks[team]
				batch.width = fog.width
				batches[team] = batch
		for i in 60:
			var point:=Vector2((i*83)%1700-40,(i*149)%1700)
			var side: String = ["ally","ai2","enemy"][i%3]
			var radius: float = [40.0,55.0,87.75][i%3]
			if mode == "workers":
				var batch = batches[BattleRequest.house_teams[side]]
				batch.points.append(point)
				batch.radii.append(radius)
			else: fog._reveal(side, point, radius)
		if mode == "workers":
			for batch in batches.values(): batch.task = WorkerThreadPool.add_task(batch.rasterize)
			for batch in batches.values(): WorkerThreadPool.wait_for_task_completion(batch.task)
		if mode != "serial":
			fog._apply_live_masks()
			check(expected.visible==fog.visible_cells and expected.explored==fog.explored_cells,mode + " allied scout visibility and explored maps equal reference raster")
		else:
			expected={"visible":fog.visible_cells.duplicate(true),"explored":fog.explored_cells.duplicate(true)}
	fog.free()
	BattleRequest.house_teams.assign(old_teams)

# Oracle remains the original per-actor/per-observer stamp. Compare timers too:
# checking only visible cells misses captures, overlapping scouts and expiry.
func exercise_vacated_scout_masks() -> void:
	var saved_teams := BattleRequest.house_teams.duplicate()
	for teams in [{}, {"ally":1,"ai2":1,"ai3":1,"enemy":2,"ai4":2,"ai5":2}]:
		BattleRequest.house_teams.assign(teams)
		var fog := preload("res://scripts/world/fog_of_war.gd").new()
		fog.width = 67
		fog.sight_clock = 20.0
		var sides: Array = ["ally","enemy"] if teams.is_empty() else teams.keys()
		var current := {}
		for i in 240:
			var side: String = sides[i % sides.size()]
			var old := {"side":side,"point":Vector2((i*83)%2900-100,(i*149)%2900-100),"radius":[40.0,55.0,87.75,320.0][i%4]}
			if i % 13 == 0:
				old.point = Vector2(80,120)
				old.radius = 40.0000001 # scalar precision at a tile boundary
			fog._scouts[i] = old
			if i % 7 == 0: continue # vanished / embarked scout
			var next := old.duplicate()
			if i % 5 == 0: next.side = sides[(i+1)%sides.size()] # capture
			if i % 3 != 0: next.point += Vector2(60-i%120,i%90-45)
			if i % 11 == 0: next.radius = 120.0 # range changed
			current[i] = next
		var expected := {}
		for mode in ["serial","union"]:
			for side in sides:
				var cells := PackedByteArray()
				cells.resize(fog.width*fog.width)
				cells[3] = 1
				fog.visible_cells[side] = cells.duplicate()
				fog.explored_cells[side] = cells.duplicate()
				fog.sight_until[side] = {3:29.0,99:21.0}
			if mode == "serial":
				for id in fog._scouts:
					var old: Dictionary = fog._scouts[id]
					var next: Dictionary = current.get(id,{})
					if old == next: continue
					if old.side != next.get("side"): next = {}
					fog._stamp_sight(old.side,old.point,old.radius,4.75,false,next)
				expected = {"visible":fog.visible_cells.duplicate(true),"explored":fog.explored_cells.duplicate(true),"held":fog.sight_until.duplicate(true)}
			else:
				fog._hold_vacated_scouts(current,4.75)
				check(fog.visible_cells == expected.visible,"vacated scout union matches visible cells: %s houses" % sides.size())
				check(fog.explored_cells == expected.explored,"vacated scout union matches exploration: %s houses" % sides.size())
				check(fog.sight_until == expected.held,"vacated scout union preserves all deadlines: %s houses" % sides.size())
		fog.free()
	BattleRequest.house_teams.assign(saved_teams)
