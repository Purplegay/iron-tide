extends "res://tests/base_recovery_regression.gd"
const Snapshot = preload("res://scripts/save/battle_snapshot.gd")
const Sites = preload("res://scripts/world/civilian_sites.gd")
const Civil = preload("res://scripts/units/civilian_orders.gd")
const Clouds = preload("res://scripts/world/storm_clouds.gd")
const AIM := Vector2(1200, 1200)

func _ready() -> void:
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not ProjectSettings.get_setting("application/config/use_custom_user_dir", false): get_tree().quit(2); return
	await get_tree().process_frame
	for mode in [MatchRules.RA2, MatchRules.EXTENDED]:
		await oil_skirmish(mode)
		arena(mode)
		await contested_oil()
		await finish()
		for side in ["ally", "enemy"]:
			arena(mode)
			chrono(side)
			await finish()
			arena(mode)
			spy(side)
			await finish()
		arena(mode)
		await civilian()
		await finish()
		arena(mode)
		await dog()
		await finish()
		await storm(mode)
	var f := FileAccess.open(output_dir.path_join("result.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks": checks, "failed": failed}, "  "))
	f.close()
	Ra2Sfx.stop_all(); Music.stop(); Music.player.stream = null
	OS.delay_msec(150)
	await get_tree().process_frame
	print("SPECIAL_MECHANICS checks=", checks.size(), " failed=", failed)
	get_tree().quit(0 if failed == 0 else 1)

func arena(mode: String) -> void:
	start(mode)
	for b in battle.buildings: b.free()
	battle.buildings.clear()
	battle._refresh_pathing()
	GM.god_mode = false; GM.one_shot_kill = false; GM.infinite_power = false
	battle.paused = false; battle.ended = false; get_tree().paused = false
	battle.power_low = false; battle.enemy_power.low = false

func oil_skirmish(mode: String) -> void:
	var ops = preload("res://scripts/world/skirmish_operations.gd")
	for size in [2400, 3200, 4000]:
		var faction := "soviet" if size == 3200 else "allied"
		BattleRequest.configure_skirmish(mode, {"map_size": size, "starting_funds": 20000, "enemy_base": faction, "fog_of_war": size == 3200})
		screen = load("res://scenes/battle.tscn").instantiate()
		add_child(screen)
		screen.process_mode = Node.PROCESS_MODE_DISABLED
		battle = screen.battle
		var sites: Array = battle.buildings.filter(func(b): return b.building_id == "CAOILD")
		check(sites.size() == 3 and sites.all(func(b): return b.side == "neutral" and not battle.in_water_world(b.position) and not b._ra2.is_empty() and b._ra2_anim.size() == 2), mode + str(size) + " map has three neutral oil derricks with working art on land")
		if sites.is_empty():
			await finish()
			continue
		var site = sites[0]
		check(sites.all(func(b): return b._col == Color.GRAY and b.material is ShaderMaterial and b.material.get_shader_parameter("paint_mode") == HouseColor.PaintMode.NEUTRAL_OIL), prefix + "neutral derricks use grayscale for all sprite layers")
		var ai = battle.skirmish_ai
		var engineer_id := "SENGINEER" if faction == "soviet" else "ENGINEER"
		for building in battle.buildings: building._buildup_play = -1.0
		ops.claim_oil(ai)
		ops.claim_oil(ai)
		var producers: Array = battle.buildings.filter(func(b): return b.production.has(engineer_id))
		check(producers.size() == 1 and ops.count(ai, engineer_id) == 1, faction + " pays for one engineer across decisions", [ai.enemy_base, ai.funds, battle.buildings.filter(func(b): return b.side == "enemy").map(func(b): return [b.building_id, b.queue_block_reason(engineer_id)])])
		if producers.is_empty():
			await finish()
			continue
		var producer = producers[0]
		producer._process(120.0)
		var engineers: Array = battle.units.filter(func(u): return u.unit_id == engineer_id and u.side == "enemy")
		check(engineers.size() == 1, faction + " barracks delivers engineer")
		if engineers.is_empty():
			await finish()
			continue
		var engineer = engineers[0]
		ops.tick(ai)
		site = engineer.special.get("target")
		check(is_instance_valid(site) and engineer.special.get("action") == "allied_engineer", faction + " AI issues real capture order")
		if not is_instance_valid(site):
			await finish()
			continue
		var before: float = battle.enemy_funds
		if size == 3200:
			engineer.process_mode = Node.PROCESS_MODE_ALWAYS
			engineer.set_physics_process(false)
			for building in battle.buildings: building.disable_mode = CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
			await get_tree().physics_frame
			for frame in 2700:
				engineer._physics_process(1.0 / 60.0)
				if engineer._dead: break
				if frame % 6 == 0: battle.fog.rebuild()
			check(engineer._dead, "Soviet engineer walks from the barracks to an explored oil well", [engineer.position, site.position, engineer.special.get("action")])
		else:
			engineer.position = AlliedAbilities.approach(engineer, site)
			AlliedAbilities.tick_action(engineer, 0.1)
		check(site.side == "enemy" and engineer._dead and battle.enemy_funds == before + 1000, faction + " neutral capture consumes engineer and grants startup once")
		site._process(3.0)
		var point: Vector2 = site.position
		await get_tree().process_frame
		var snapshot := Snapshot.new().capture(battle)
		check(BattleSaves.validate(snapshot).is_empty(), "neutral and held oil wells both validate")
		Snapshot.new().restore(battle, snapshot)
		battle.paused = false
		get_tree().paused = false
		site = battle.buildings.filter(func(b): return b.position == point and b.building_id == "CAOILD")[0]
		var expected_enemy := HouseColor.enemy_color_for(str(GameData.get_faction(faction).color))
		check(site._col.is_equal_approx(expected_enemy) and site.material == HouseColor.material_for(expected_enemy), faction + "captured derrick restores owner paint")
		before = battle.enemy_funds
		site._process(3.8)
		check(battle.enemy_funds == before + 20, faction + " restored partial oil period pays owner")
		var player = battle.spawn_unit("ENGINEER", "ally", site.position + Vector2(120, 0))
		player.position = AlliedAbilities.approach(player, site)
		if battle.fog != null: battle.fog.rebuild()
		before = battle.funds
		check(player.order_interaction("allied_engineer", site, false), "player can order recapture")
		AlliedAbilities.tick_action(player, 0.1)
		site._process(6.7)
		check(site.side == "ally" and battle.funds == before + 20, "recapture transfers income without a second startup award")
		check(site._col.is_equal_approx(HouseColor.player_color()) and site.material == HouseColor.material_for(HouseColor.player_color()), prefix + "recapture switches derrick to player paint immediately")
		await finish()

func contested_oil() -> void:
	var ops = preload("res://scripts/world/skirmish_operations.gd")
	var point := Vector2(820, 1050)
	battle.allied_state.oil_mid_point = point
	var site = Sites.create(battle, "CAOILD", point)
	var player = spawn("ENGINEER", "ally", point + Vector2(120, 0))
	player.position = AlliedAbilities.approach(player, site)
	player.order_interaction("allied_engineer", site, false)
	AlliedAbilities.tick_action(player, 0.1)
	var guard_unit = spawn("E1", "ally", point + Vector2(60, 0))
	var ai = battle.skirmish_ai
	var scout = spawn("DOG", "enemy", ai.rally)
	var escort = spawn("MTNK", "enemy", ai.rally)
	var worker = spawn("ENGINEER", "enemy", ai.rally)
	battle.fog = preload("res://scripts/world/fog_of_war.gd").new()
	battle.add_child(battle.fog)
	battle.fog.setup(battle)
	ops.claim_oil(ai)
	check(site.side == "ally" and scout.special.has("ai_oil_post") and scout.has_move_order and not worker.special.has("action") and escort.attack_target == null, prefix + "unseen player oil prompts scouting only")
	scout.position = point + Vector2(0, -120)
	battle.fog.rebuild()
	ops.claim_oil(ai)
	check(escort.attack_target == guard_unit and not worker.special.has("action") and worker.special.has("ai_mid_engineer"), prefix + "defenders targeted while engineer waits")
	guard_unit.hp = 1
	escort.position = point + Vector2(160, 0)
	escort._fire_shot(escort.attack_target)
	for shot in battle.projectiles_root.get_children():
		if shot is Projectile:
			for frame in 240:
				if shot.is_queued_for_deletion(): break
				shot._physics_process(1.0 / 60.0)
	check(guard_unit._dead, prefix + "escort shell clears defender before engineer enters")
	ops.claim_oil(ai)
	check(worker.special.get("target") == site, prefix + "visible cleared enemy oil receives capture order")
	worker.receive_hit(worker.hp * 10)
	var next = spawn("ENGINEER", "enemy", ai.rally)
	ops.claim_oil(ai)
	next.receive_hit(next.hp * 10)
	var replacement = spawn("ENGINEER", "enemy", ai.rally)
	ops.claim_oil(ai)
	check(battle.allied_state.get("oil_retry_left", 0) == 60 and not replacement.special.has("action"), prefix + "two lost engineers suspend midfield capture")
	add("GACNST", "enemy", ai.base_center)
	ai._train_t = 100
	ai._process(60.0)
	ops.claim_oil(ai)
	replacement.position = AlliedAbilities.approach(replacement, site)
	AlliedAbilities.tick_action(replacement, 0.1)
	var before: float = battle.enemy_funds
	site._process(6.8)
	ops.claim_oil(ai)
	check(site.side == "enemy" and battle.enemy_funds == before + 20 and scout.special.has("ai_oil_post") and not escort.special.has("ai_oil_post"), prefix + "retry captures midfield, earns next payment and keeps one guard")
	await get_tree().process_frame

func add(id: String, side := "ally", point := Vector2(300, 300)):
	var b = battle._place_building(id, side, point, true)
	b._buildup_play = -1.0
	return b

func spawn(id: String, side: String, point: Vector2):
	var unit = battle.spawn_unit(id, "ally", point)
	unit.disable_mode = CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
	if side != "ally": AlliedAbilities.change_side(unit, side)
	return unit

func chrono(side: String) -> void:
	var b = add("GACSPH", side)
	b._sw_charge = b.sw_recharge()
	var tank = spawn("MTNK", side, AIM)
	var enemy = spawn("MTNK", "enemy" if side == "ally" else "ally", AIM + Vector2(65, 60))
	var gi = spawn("E1", side, AIM + Vector2(-60, 0))
	var chrono_gi = spawn("CLEG", side, AIM + Vector2(0, -65))
	battle.power_low = false; battle.enemy_power.low = false
	battle._chrono_source_point = AIM
	check(not b.fire_superweapon(Vector2(-1, 400)) and b.sw_ready(), prefix + side + " rejects outside map without charge")
	check(b.fire_superweapon(Vector2(1800, 1000)), prefix + side + " transfers mixed-owner square")
	check(tank.position == Vector2(1800, 1000) and enemy.position == Vector2(1865, 1060), prefix + "both owners preserve offsets")
	check(gi._dead and not chrono_gi._dead and chrono_gi.position == Vector2(1800, 935), prefix + "organic dies; Teleporter infantry survives")
	check(tank._stun_timer == 4 and not b.sw_ready(), prefix + "arrival delay and one charge")
	b._sw_charge = b.sw_recharge()
	battle.water_rects = [Rect2(500, 1200, 500, 500)]
	battle.path_service.set_water(battle.water_rects)
	battle._chrono_source_point = tank.position
	check(b.fire_superweapon(Vector2(700, 1450)) and tank._dead, prefix + "land vehicle in water is destroyed and consumes charge")

func spy(side: String) -> void:
	var owner := "enemy" if side == "ally" else "ally"
	var radar = add("GAAIRC", owner, AIM)
	var spy_unit = spawn("SPY", side, AIM + Vector2(150, 0))
	check(AlliedAbilities.default_order(spy_unit, radar) == "allied_infiltrate", prefix + "radar infiltration uses ordinary right-click")
	if battle.fog == null:
		battle.fog = preload("res://scripts/world/fog_of_war.gd").new(); battle.add_child(battle.fog); battle.fog.setup(battle)
	battle.fog.explored_cells[owner].fill(1)
	battle.fog.explored_cells[side].fill(1)
	AlliedAbilities.resolve_infiltration(spy_unit, radar)
	check(not battle.fog.is_explored_at(owner, Vector2(2200, 2200)) and battle.fog.is_explored_at(side, Vector2(2200, 2200)), prefix + "clears victim terrain only")
	check(battle.fog.is_visible_at(owner, AIM), prefix + "current scouts remain visible after reset")
	# Disable fog for this independent superweapon eligibility check.
	battle.fog.free(); battle.fog = null
	for id in ["GACSPH", "GAWEAT"]:
		var launcher = add(id, owner, Vector2(500, 500))
		launcher._sw_charge = launcher.sw_recharge(); launcher._sw_was_ready = true
		var infiltrator = spawn("SPY", side, Vector2(650, 500))
		check(AlliedAbilities.can_order(infiltrator, launcher, "allied_infiltrate"), prefix + id + " accepts spy")
		AlliedAbilities.resolve_infiltration(infiltrator, launcher)
		check(launcher._sw_charge == 0 and not launcher._sw_was_ready and infiltrator._dead, prefix + id + " resets charge and consumes spy once")

func civilian() -> void:
	var house = Sites.create(battle, "CAHSE01", AIM)
	check(not house.is_in_group("enemies") and not house.is_in_group("ally_targets"), prefix + "neutral sites are not enemy army targets")
	check(not preload("res://scripts/world/build_range_preview.gd").provides_range(house.data), prefix + "civilian grants no build territory")
	var gi = spawn("E1", "ally", AIM + Vector2(100, 0))
	check(AlliedAbilities.default_order(gi, house) == "allied_garrison", prefix + "GI right-click enters neutral house")
	check(house._body_damage_frame() == 0, prefix + "empty house uses civilian sprite")
	battle.select_unit(gi,false)
	battle._issue_order(house.art_center())
	for i in 90:
		if gi.embarked_in != null: break
		AlliedAbilities.tick_action(gi,1.0/60.0)
	check(house._body_damage_frame() == 2 and house.data.fire_ports.size()==5, prefix + "entering selects sandbags and opens five firing ports")
	check(house.side == "ally" and gi.embarked_in == house and not gi.visible and gi.collision_layer == 0, prefix + "garrison owns house and removes infantry collision")
	check(not battle.has_base_assets("ally"), prefix + "civilian occupation does not prevent short-game defeat")
	var target = spawn("E1", "enemy", AIM + Vector2(180, 0))
	var hp: float = target.hp
	Civil.tick(gi, 1.0)
	check(target.hp < hp and not Civil.weapon(gi).is_empty(), prefix + "occupy weapon actually damages enemy")
	var priority = spawn("HTNK","enemy", AIM + Vector2(255,0))
	battle.select_building(house)
	battle._emit_selection()
	battle._issue_order(priority.art_center())
	check(house.attack_target == priority and battle.command_cursor.can_attack(priority),prefix + "right-click designates enemy from civilian house")
	gi._cd_timer = 0
	Civil.tick(gi,0.1)
	check(priority.hp < priority.max_hp and gi.attack_target == priority,prefix + "occupier shoots designated target instead of closer enemy")
	check(battle.effects_root.get_children().any(func(fx):return fx is Ra2Fx and fx.anim.image=="UCFLASH" and fx.position.is_equal_approx(gi._weapon_muzzle())),prefix + "window muzzle flash matches firing port")
	battle.stop_selected()
	screen.hud.cmd_buttons.attack.pressed.emit()
	battle._issue_command_at(priority.art_center())
	check(house.attack_target == priority, prefix + "attack button can retarget occupied house")
	# Older saves contain the same actors but no weapon, port or capacity fields.
	for key in ["garrison_slots","fire_ports","garrison_weapons"]: house.data.erase(key)
	var snapshot := Snapshot.new().capture(battle)
	check(BattleSaves.validate(snapshot).is_empty(), prefix + "neutral and occupied buildings validate in saves", BattleSaves.validate(snapshot))
	var tampered := snapshot.duplicate(true)
	tampered.special_rules = "different rules"
	check(not BattleSaves.validate(tampered).is_empty(), prefix + "changed special rules rejected")
	tampered.erase("special_rules")
	check(BattleSaves.validate(tampered).is_empty(), prefix + "pre-special-mechanics save remains loadable")
	Snapshot.new().restore(battle, snapshot)
	battle.paused = false; get_tree().paused = false
	house = battle.buildings[0]; gi = house.special.occupants[0]
	check(gi.embarked_in == house and not gi.visible, prefix + "garrison references restore")
	check(house.supports_attack_order() and house.data.fire_ports.size()==5 and house._body_damage_frame()==2, prefix+"legacy house restores fire controls and fortified frame")
	Civil.evacuate(house)
	check(house._body_damage_frame()==0 and house.attack_target==null, prefix+"evacuated house clears focus and sandbags")
	check(gi.embarked_in == null and gi.visible and house.side == "neutral", prefix + "evacuate restores infantry and neutral ownership")
	for i in 5: Civil.enter(spawn("E1", "ally", AIM + Vector2(100, 40 + i * 20)), house)
	check(not Civil.can_enter(gi, house) and house.special.occupants.size() == 5, prefix + "full house rejects sixth occupant")
	house.hp = house.max_hp * 0.25
	Civil.tick_building(house)
	check(house.special.occupants.is_empty() and house.side == "neutral" and not Civil.can_enter(gi, house), prefix + "critical house evacuates and refuses entry")
	var hut = Sites.create(battle, "CABHUT", Vector2(500, 1000))
	hut.special.bridge_span = Rect2(600, 900, 500, 120)
	hut.special.bridge_repaired = false
	battle.water_rects = [Rect2(620, 700, 450, 700)]
	battle.path_service.set_water(battle.water_rects)
	var engineer = spawn("ENGINEER", "ally", hut.position + Vector2(70, 0))
	hut.disable_mode = CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
	check(Civil.can_repair(engineer, hut) and battle.in_water_world(Vector2(800, 960)), prefix + "engineer recognizes broken bridge")
	engineer.special.action = "allied_bridge"; engineer.special.target = hut
	await get_tree().physics_frame
	for i in 150:
		if engineer._dead: break
		AlliedAbilities.tick_action(engineer, 1.0 / 30.0)
	check(engineer._dead and hut.special.bridge_repaired and not battle.in_water_world(Vector2(800, 960)), prefix + "engineer consumed; actual crossing becomes land")
	check(battle.in_water_world(Vector2(800, 800)) and not Civil.can_repair(gi, hut), prefix + "water outside crossing preserved")
	var choke := Vector2(800, 960)
	var ivan = spawn("IVAN", "ally", hut.position - Vector2(180, 0))
	battle.select_unit(ivan, false)
	battle._issue_order(hut.position)
	check(ivan.attack_target == hut and ivan.attack_ordered, prefix + "right click sends Ivan to neutral repair hut")
	for tick in 600:
		if hut.special.has("ivan_bomb"): break
		ivan._physics_process(1.0 / 60.0)
		if tick % 30 == 0: await get_tree().physics_frame
	check(hut.special.has("ivan_bomb") and not battle.path_service.is_blocked(choke), prefix + "bridge stays passable while the fuse burns")
	if BattleRequest.rules_mode == MatchRules.RA2: hut.special.erase("bridge_water") # Pre-bridge-demolition save.
	hut._process(31.0)
	check(not hut._dead and not hut.special.bridge_repaired and battle.in_water_world(choke) and battle.path_service.is_blocked(choke), prefix + "detonation breaks the crossing and preserves repair hut")
	var damaged := Snapshot.new().capture(battle)
	Snapshot.new().restore(battle, damaged)
	battle.paused = false
	get_tree().paused = false
	hut = battle.buildings.filter(func(b): return b.building_id == "CABHUT")[0]
	check(battle.path_service.is_blocked(choke) and not hut.special.bridge_repaired, prefix + "broken bridge survives reload")
	var replacement = spawn("SENGINEER", "ally", hut.position - Vector2(145, 0))
	battle.select_unit(replacement, false)
	battle._issue_order(hut.position)
	for tick in 600:
		if replacement._dead: break
		replacement._physics_process(1.0 / 60.0)
		if tick % 30 == 0: await get_tree().physics_frame
	check(replacement._dead and hut.special.bridge_repaired and not battle.path_service.is_blocked(choke), prefix + "repairing after sabotage restores land navigation", [replacement.special.get("action"), str(replacement.position), hut.special.bridge_repaired, replacement._dead])
	hut._die()
	# Classic fixture recreates the old serialized lake with the deck strip missing,
	# even after its hut has been destroyed. Extended exercises the new full lake.
	if BattleRequest.rules_mode == MatchRules.RA2:
		battle.water_rects = [Rect2(620, 700, 450, 200), Rect2(620, 1020, 450, 380)]
	Snapshot.new().restore(battle, Snapshot.new().capture(battle))
	check(battle.path_service.in_naval_water(choke) and not battle.path_service.is_blocked(choke,true) and not battle.path_service.is_blocked(choke), prefix + "old and new saves restore ship channel and surface deck")
	battle.paused = false; get_tree().paused = false
	check(battle.allied_state.repaired_bridges.has(Rect2(600, 900, 500, 120)) and not battle.in_water_world(Vector2(800, 960)), prefix + "bridge persists across hut destruction and save/load")
	var grid := PackedFloat32Array(); grid.resize(battle.path_service.cols * battle.path_service.rows); grid.fill(1.0)
	check(battle.path_service.line_walkable(Vector2(1200, 1200), Vector2(2401, 2600), grid), prefix + "clamped path endpoint cannot overrun grid")
	grid[30 * battle.path_service.cols + 31] = -1
	check(not battle.path_service.line_walkable(Vector2(1220, 1220), Vector2(1300, 1220), grid), prefix + "blocked cell still rejects direct movement")

func dog() -> void:
	var unit = spawn("DOG", "ally", AIM)
	var target = spawn("E1", "enemy", AIM + Vector2(55, 0))
	await get_tree().physics_frame
	var hp: float = target.hp
	unit.attack_target = target
	unit._fire_shot(target)
	check(target.hp == hp and unit.special.has("pounce"), prefix + "dog take-off causes no remote damage")
	for i in 15: preload("res://scripts/units/dog_pounce.gd").tick(unit, 1.0 / 30.0)
	check(target._dead and unit.position != AIM, prefix + "dog moves then culls infantry on contact")
	var far = spawn("E1", "enemy", AIM + Vector2(500, 0))
	preload("res://scripts/units/dog_pounce.gd").start(unit, far, unit._active_weapon())
	for i in 15: preload("res://scripts/units/dog_pounce.gd").tick(unit, 1.0 / 30.0)
	check(far.hp == far.max_hp and not unit.special.has("pounce"), prefix + "missed leap never damages remote target")

	for id in ["DOG", "SOV_DOG"]:
		for blocker_id in ["E2", "HTNK"]:
			var origin := Vector2(500 if id == "DOG" else 1600, 600 if blocker_id == "E2" else 1800)
			var attacker = spawn(id, "ally", origin)
			var first = spawn("E2", "enemy", origin + Vector2(45,0))
			var second = spawn("E2", "enemy", origin + Vector2(98,0))
			var blocker = spawn(blocker_id, "ally" if id == "DOG" else "enemy", origin + Vector2(64,0))
			await get_tree().physics_frame
			attacker.set_fire_stance("defend")
			preload("res://scripts/world/skirmish_operations.gd").order_attack(attacker,first)
			for frame in 65:
				attacker._physics_process(1.0/60.0)
				if not AlliedAbilities.alive(first): break
			check(not AlliedAbilities.alive(first),prefix + id + " lands first bite")
			preload("res://scripts/world/skirmish_operations.gd").order_attack(attacker,second)
			var leaps := 0
			for frame in 300:
				var jumping: bool = attacker.special.has("pounce")
				attacker._physics_process(1.0/60.0)
				if not jumping and attacker.special.has("pounce"): leaps += 1
				if not AlliedAbilities.alive(second): break
			check(not AlliedAbilities.alive(second) and leaps == 1, prefix + id + " lands second bite around " + blocker_id, [leaps,str(attacker.position)])
			check(blocker.hp == blocker.max_hp and attacker.position.distance_to(blocker.position) >= attacker.radius + blocker.radius - 0.5, prefix + "blocker remains unharmed and solid")

	var wall_point := Vector2(1200, 800)
	var wall = add("GAWALL", "enemy", wall_point)
	wall.disable_mode = CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
	var guard = spawn("DOG", "ally", wall_point - Vector2(38, 0))
	var protected = spawn("E2", "enemy", wall_point + Vector2(38, 0))
	await get_tree().physics_frame
	preload("res://scripts/world/skirmish_operations.gd").order_attack(guard, protected)
	for frame in 180: guard._physics_process(1.0 / 60.0)
	check(guard.position.x < wall_point.x and protected.hp == protected.max_hp, prefix + "a solid wall still blocks bites")

func storm(mode: String) -> void:
	var expected := {}
	for fps in [0, 15, 60]:
		arena(mode)
		var launcher = add("GAWEAT", "enemy")
		launcher._sw_charge = launcher.sw_recharge()
		var target = spawn("MTNK", "ally", AIM)
		target.max_hp = 100000; target.hp = target.max_hp
		check(launcher.fire_superweapon(AIM), prefix + "storm launched")
		var state: Dictionary = LightningStorm.storms(battle)[0]
		state.rng.seed = 27
		LightningStorm.tick(battle, state.delay)
		check(target.hp == target.max_hp and state.clouds.size() > 0, prefix + "onset makes clouds without immediate damage")
		check(LightningStorm.radar_jammed(battle, "ally") and not LightningStorm.radar_jammed(battle, "enemy"), prefix + "only hostile radar jammed")
		var count: int = state.clouds.size()
		Clouds.create_cloud(battle, state, AIM + Vector2(55, 0), state.time, true)
		check(state.clouds.size() == count, prefix + "scatter separation rejects adjacent cloud")
		var rod = add("GAPOWR", "enemy", Vector2(800, 700))
		rod.data = rod.data.duplicate(true); rod.data.lightning_rod = true
		check(Clouds.rod_point(battle, Vector2(820, 700)) == rod.position, prefix + "declared lightning rod attracts nearby scatter")
		var nearer = spawn("MTNK", "ally", Vector2(830, 700))
		check(Clouds.rod_point(battle, nearer.position) == nearer.position, prefix + "nearer non-rod prevents magnetic redirection")
		battle.units.erase(nearer); nearer.free()
		battle.buildings.erase(rod); rod.free()
		var saved := Snapshot.new().capture(battle)
		check(BattleSaves.validate(saved).is_empty(), prefix + "cloud deadlines valid for disk schema", BattleSaves.validate(saved))
		var before: float = state.time
		battle.paused = true; LightningStorm.tick(battle, 20)
		check(state.time == before, prefix + "pause freezes cloud phase")
		battle.paused = false
		if fps == 0: LightningStorm.tick(battle, 30)
		else:
			for i in 30 * fps: LightningStorm.tick(battle, 1.0 / fps)
		var outcome := {"hp": target.hp, "rng": state.rng.state, "clouds": state.cloud_serial}
		if fps == 0: expected = outcome
		check(outcome == expected and target.hp < target.max_hp, prefix + "same cloud damage across frame rates " + str(fps), outcome)
		check(LightningStorm.storms(battle).is_empty() and not LightningStorm.radar_jammed(battle, "ally"), prefix + "final clouds drain; radar restores")
		Snapshot.new().restore(battle, saved)
		battle.paused = false; get_tree().paused = false
		LightningStorm.tick(battle, 30)
		var restored = battle.units[0]
		check(restored.hp == expected.hp and LightningStorm.storms(battle).is_empty(), prefix + "save/load replays pending clouds exactly once")
		await finish()
