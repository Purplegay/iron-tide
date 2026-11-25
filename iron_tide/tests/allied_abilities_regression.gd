extends "res://tests/logistics_regression.gd"

func actor(id: String, side: String, point: Vector2):
	var unit = battle.spawn_unit(id, side, point)
	activate(unit)
	return unit

func exercise_mode(mode: String) -> void:
	setup_logistics_scene(mode, "美国")
	battle.water_rects = []
	battle.path_service.set_water([])
	var tag := mode + ": "
	check(GameData.allied_capabilities.get("source_sha256", "") == "3d341ef8a13a4b5ab24af2eef48ac94931ac2bb87d950fe3330a07e2d25672ef", tag + "local YR rules provenance")
	var ifv = actor("FV", "ally", Vector2(1600, 1600))
	check(ifv.logistics.capacity == 1, tag + "IFV actual passenger slot enabled")
	var original: Dictionary = ifv._active_weapon().duplicate(true)
	for row in [["E1", "CRM60"], ["GGI", "CRMissileLauncher"], ["ENGINEER", "RepairBullet"], ["GHOST", "CRMP5"], ["SNIPE", "AWPE"], ["CLEG", "CRNeutronRifle"]]:
		var passenger = actor(row[0], "ally", ifv.position + Vector2(28, 0))
		await get_tree().physics_frame
		check(passenger.logistics.request_board(ifv), tag + row[0] + " real boarding accepted")
		for i in 90:
			passenger._physics_process(1.0 / 60.0)
			if passenger.embarked_in == ifv: break
		check(passenger.embarked_in == ifv and ifv._active_weapon().get("ra2_weapon_id") == "YR_CAP_" + row[1], tag + row[0] + " actual passenger changes weapon")
		var extra = actor("E1", "ally", ifv.position + Vector2(0, 40))
		check(not extra.logistics.request_board(ifv), tag + "occupied IFV rejects second passenger")
		remove_actor(extra)
		if row[0] == "GGI": check(ifv.can_hit_air and ifv.min_range == 55.0, tag + "GGI IFV AA and blind spot from YR")
		if row[0] == "ENGINEER":
			var friendly = actor("MTNK", "ally", ifv.position + Vector2(85, 0))
			var hostile = actor("MTNK", "enemy", ifv.position + Vector2(85, 50))
			friendly.hp -= 80.0
			check(not ifv._weapon_domain_valid(hostile), tag + "repair IFV cannot damage enemies")
			check(AlliedAbilities.use(ifv, "allied_repair", friendly), tag + "repair order accepted")
			var hp_before: float = friendly.hp
			ifv._physics_process(0.1)
			check(friendly.hp > hp_before and friendly.hp <= friendly.max_hp, tag + "repair heals actual friendly HP")
			ifv.order_stop()
			check(not ifv.special.has("action"), tag + "stop cancels support order")
			remove_actor(friendly); remove_actor(hostile)
		check(ifv.logistics.request_unload(), tag + "unload command accepted")
		ifv.logistics.tick(0.5)
		check(passenger.embarked_in == null and ifv._active_weapon() == original, tag + "unload restores original missile weapon")
		remove_actor(passenger)
	var tank = actor("MTNK", "ally", Vector2(1700, 1600))
	check(not tank.logistics.request_board(ifv), tag + "vehicles cannot enter IFV")
	remove_actor(tank)
	await engineering(tag)
	await special_weapons(tag)
	await stealth_and_swimming(tag)
	await presentation_and_save(tag)
	screen.free()
	await get_tree().process_frame

func engineering(tag: String) -> void:
	var factory = battle._place_building("GAWEAP", "enemy", Vector2(1980, 1300), true)
	factory.process_mode = Node.PROCESS_MODE_ALWAYS
	factory.set_process(false)
	battle._refresh_pathing()
	# battle._capture_enemy_music_roster() iterates units + buildings and feeds every
	# actor to AlliedAbilities.flag(); buildings carry `building_id`, not `unit_id`.
	# Before the fix that raised "Invalid access to property or key 'unit_id' on a
	# base object of type 'StaticBody2D (Building)'" at allied_abilities.gd:17.
	check(AlliedAbilities.source(factory).size() > 0, tag + "ability source accepts buildings", AlliedAbilities.source(factory).size())
	check(not AlliedAbilities.flag(factory, "DontScore"), tag + "building DontScore resolves without error")
	var unknown_building = battle._place_building("GAPOWR", "ally", Vector2(1500, 2300), true)
	unknown_building.building_id = "NO_SUCH_BUILDING"
	check(AlliedAbilities.source(unknown_building).is_empty(), tag + "ability source tolerates an unknown building id")
	check(not AlliedAbilities.flag(unknown_building, "DontScore"), tag + "unknown building DontScore falls back to false")
	remove_actor(unknown_building)
	for direction in [Vector2.RIGHT, Vector2(1, 1).normalized(), Vector2.UP, Vector2.LEFT]:
		var sapper = actor("SENGINEER", "ally", factory.position + direction * 240.0)
		await get_tree().physics_frame
		battle.select_unit(sapper, false)
		var footprint: PackedVector2Array = factory.footprint_poly()
		var point: Vector2 = factory.position + (footprint[0] + footprint[2]) * 0.5
		check(battle.command_cursor.resolve(point) == "enter", tag + "enter cursor over factory foundation")
		var slot := UnitSkillLayout.find(sapper, "allied_engineer")
		if slot >= 0 and battle.selected_skill_unit() == sapper and direction == Vector2.UP:
			battle.cast_slot = slot
			check(battle.command_cursor.resolve(point) == "enter", tag + "engineer skill cursor matches right click")
			var motion := InputEventMouseMotion.new()
			motion.position = battle.get_global_transform_with_canvas() * point
			stage.push_input(motion, true)
			battle.confirm_cast()
		else:
			battle._issue_order(point)
		check(sapper.special.get("action") == "allied_engineer", tag + "factory capture order accepted " + str(direction))
		for tick in 540:
			if not battle.actor_alive(sapper): break
			sapper._physics_process(1.0 / 60.0)
		check(factory.side == "ally" and not battle.actor_alive(sapper), tag + "engineer walks into capture range " + str(direction), str(sapper.position - factory.position))
		if battle.actor_alive(sapper): remove_actor(sapper)
		AlliedAbilities.change_side(factory, "enemy")
	var target = battle._place_building("GAPOWR", "enemy", Vector2(2200, 2000), true)
	var engineer = actor("ENGINEER", "ally", target.position + Vector2(150, 0))
	engineer.position = AlliedAbilities.approach(engineer, target)
	check(AlliedAbilities.use(engineer, "allied_engineer", target), tag + "engineer capture accepts capturable enemy")
	engineer._physics_process(0.1)
	check(target.side == "ally" and target.is_in_group("ally_buildings") and not target.is_in_group("enemy_buildings"), tag + "capture switches actual ownership and queries")
	check(engineer._dead, tag + "successful capture consumes engineer")
	var repairer = actor("ENGINEER", "ally", target.position + Vector2(150, 0))
	target.hp = target.max_hp * 0.3
	repairer.position = AlliedAbilities.approach(repairer, target)
	check(AlliedAbilities.use(repairer, "allied_engineer", target), tag + "repair building accepts damaged friend")
	repairer._physics_process(0.1)
	check(target.hp == target.max_hp and repairer._dead, tag + "building restored and engineer consumed")
	var enemy = battle._place_building("GAPOWR", "enemy", Vector2(2450, 2000), true)
	var seal = actor("GHOST", "ally", enemy.position + Vector2(150, 0))
	seal.position = AlliedAbilities.approach(seal, enemy)
	check(AlliedAbilities.use(seal, "allied_c4", enemy), tag + "C4 order accepted")
	for tick in 180:
		seal._physics_process(1.0 / 60.0)
		if enemy.special.has("c4_left"): break
	check(enemy.special.has("c4_left") and enemy.hp > 0.0, tag + "C4 plants before delayed destruction")
	var defuser = actor("ENGINEER", "enemy", enemy.position + Vector2(150, 0))
	defuser.position = AlliedAbilities.approach(defuser, enemy)
	check(AlliedAbilities.use(defuser, "allied_engineer", enemy), tag + "engineer recognizes planted charge")
	defuser._physics_process(0.1)
	check(not enemy.special.has("c4_left") and not defuser._dead, tag + "defusing preserves building and engineer")
	AlliedAbilities.use(seal, "allied_c4", enemy)
	for tick in 180:
		seal._physics_process(1.0 / 60.0)
		if enemy.special.has("c4_left"): break
	enemy._process(10.0)
	check(enemy._dead, tag + "C4 detonates through real building death")
	var refinery = battle._place_building("GAREFN", "enemy", Vector2(2200, 2400), true)
	var spy = actor("SPY", "ally", refinery.position + Vector2(160, 0))
	spy.position = AlliedAbilities.approach(spy, refinery)
	var ally_funds: float = battle.funds
	var enemy_funds: float = battle.enemy_funds
	check(AlliedAbilities.use(spy, "allied_infiltrate", refinery), tag + "spy accepts enemy refinery")
	for tick in 180:
		spy._physics_process(1.0 / 60.0)
		if spy._dead: break
	check(is_equal_approx(battle.enemy_funds, enemy_funds * 0.5) and is_equal_approx(battle.funds, ally_funds + enemy_funds * 0.5), tag + "spy transfers original half of enemy money")
	var power = battle._place_building("GAPOWR", "enemy", Vector2(2500, 2500), true)
	var infiltrator = actor("SPY", "ally", power.position + Vector2(150, 0))
	infiltrator.position = AlliedAbilities.approach(infiltrator, power)
	AlliedAbilities.use(infiltrator, "allied_infiltrate", power)
	for tick in 180:
		infiltrator._physics_process(1.0 / 60.0)
		if infiltrator._dead: break
	check(is_equal_approx(battle.allied_state.get("blackout_enemy", 0), 1000.0 / 15.0) and battle.side_power_low("enemy"), tag + "spy power blackout consumes source duration")
	power._die()
	check(battle.side_power_low("enemy"), tag + "blackout remains a house effect after infiltrated plant is destroyed")
	var barracks = battle._place_building("GAPILE", "enemy", Vector2(2600, 2200), true)
	var trainer = actor("SPY", "ally", barracks.position + Vector2(160, 0))
	trainer.position = AlliedAbilities.approach(trainer, barracks)
	AlliedAbilities.use(trainer, "allied_infiltrate", barracks)
	for tick in 180:
		trainer._physics_process(1.0 / 60.0)
		if trainer._dead: break
	barracks._die()
	var producer = battle._place_building("GAPILE", "ally", Vector2(2700, 1800), true)
	var trained = battle.spawn_unit("E1", "ally", Vector2(2700, 1950), producer)
	check(trained.veteran_level == 1, tag + "infiltration training persists and grants newly produced infantry veteran rank")

func special_weapons(tag: String) -> void:
	var chrono = actor("CLEG", "ally", Vector2(1000, 2000))
	var target = actor("MTNK", "enemy", Vector2(1200, 2000))
	chrono.attack_target = target
	var original: float = target.hp
	chrono._fire_shot(target)
	check(target.hp == original and target.special.get("temporal_by") == chrono, tag + "temporal shot freezes without ordinary HP damage")
	target.receive_hit(20.0)
	check(target.hp == original, tag + "frozen target cannot take unrelated damage")
	chrono.order_stop()
	check(not target.special.has("temporal_by"), tag + "interrupt releases temporal freeze")
	chrono.attack_target = target
	chrono._fire_shot(target)
	for tick in 300:
		AlliedAbilities.channel(chrono, 0.1)
		if target._dead: break
	check(target._dead, tag + "continuous beam completes erasure")
	check(AlliedAbilities.use(chrono, "allied_chrono", null, Vector2(1000, 2300)), tag + "chrono skill accepts clear destination")
	check(chrono.position == Vector2(1000, 2300) and AlliedAbilities.frozen(chrono), tag + "teleport arrives with recovery delay")
	check(not AlliedAbilities.use(chrono, "allied_chrono", null, Vector2(1000, 2500)), tag + "cannot bypass recovery with another cast")
	AlliedAbilities.tick_actor(chrono, 30.0)
	check(not AlliedAbilities.frozen(chrono), tag + "chrono recovery ends")
	chrono.order_move(Vector2(800, 2400))
	check(chrono.position == Vector2(800, 2400) and AlliedAbilities.frozen(chrono), tag + "normal move uses infantry teleport locomotion")
	var miner = actor("CMIN", "ally", Vector2(800, 2600))
	miner.order_move(Vector2(800, 2800))
	check(miner.has_move_order and miner.position == Vector2(800, 2600) and not AlliedAbilities.frozen(miner), tag + "miner manual movement retains separate refinery-only teleport rules")
	var controller = actor("PTROOP", "ally", Vector2(1000, 1800))
	var victim = actor("MTNK", "enemy", Vector2(1150, 1800))
	var tanya = actor("TANY", "enemy", Vector2(1180, 1800))
	check(not controller._weapon_domain_valid(tanya), tag + "Tanya mind-control immunity applied")
	var victim_hp: float = victim.hp
	controller._fire_shot(victim)
	check(victim.side == "ally" and victim.hp == victim_hp and victim.is_in_group("allies"), tag + "mind control changes ownership without HP damage")
	var another = actor("MTNK", "enemy", Vector2(1160, 1850))
	check(not controller._weapon_domain_valid(another), tag + "one-link mind control capacity enforced")
	controller._die()
	check(victim.side == "enemy" and not victim.special.has("controller"), tag + "controller death releases ownership")
	var dog = actor("DOG", "ally", Vector2(900, 1600))
	check(not dog._weapon_domain_valid(another) and dog._weapon_domain_valid(tanya), tag + "dog only targets infantry")
	var prism = actor("SREF", "ally", Vector2(1000, 1000))
	var primary = actor("MTNK", "enemy", Vector2(1250, 1000))
	var nearby = actor("MTNK", "enemy", Vector2(1340, 1000))
	var distant = actor("MTNK", "enemy", Vector2(1500, 1000))
	var friendly = actor("MTNK", "ally", Vector2(1300, 1060))
	var before: float = nearby.hp
	var distant_hp: float = distant.hp
	var friendly_hp: float = friendly.hp
	prism._fire_shot(primary)
	check(nearby.hp < before, tag + "prism fragments deal immediate actual damage")
	check(distant.hp == distant_hp and friendly.hp == friendly_hp, tag + "prism fragment range and ownership respected")
	# Elite recursion is synchronous: a child branch can visit a later sibling candidate.
	prism._grant_veteran(2, false)
	check(str(prism._active_weapon().get("ra2_weapon_id", "")).ends_with("SuperComet"), tag + "elite promotion selects SuperComet")
	for offset in [Vector2(70, 30), Vector2(60, -35), Vector2(110, 20)]:
		actor("MTNK", "enemy", primary.position + offset)
	var holder: Node = prism._pick_projectile_parent()
	var previous := holder.get_children()
	prism._fire_shot(primary)
	var hits: Dictionary = {}
	var unique := true
	for shot in holder.get_children():
		if previous.has(shot) or not shot is Projectile: continue
		var target_id: int = shot.target.get_instance_id()
		unique = unique and not hits.has(target_id)
		hits[target_id] = true
	check(hits.size() >= 4, tag + "elite prism exercises multiple actual fragment branches", hits.size())
	check(unique, tag + "elite recursive fragments do not hit the same actor twice")

func presentation_and_save(tag: String) -> void:
	for id in ["GHOST", "TANY", "SNIPE", "JUMPJET"]:
		var shooter = actor(id, "ally", Vector2(800, 700))
		var target = actor("E1", "enemy", Vector2(900, 700))
		shooter._anim = 73.5
		shooter._fire_shot(target)
		check(shooter._fire_anim_time == 0.0, tag + id + " firing sequence begins at first frame")
		remove_actor(shooter); remove_actor(target)
	var sniper = actor("SNIPE", "ally", Vector2(700, 800))
	var tank = actor("MTNK", "enemy", Vector2(800, 800))
	check(not sniper._weapon_domain_valid(tank), tag + "sniper rejects non-infantry targets")
	var controller = actor("PTROOP", "ally", Vector2(500, 1800))
	var controlled = actor("MTNK", "enemy", Vector2(650, 1800))
	controller._fire_shot(controlled)
	var chrono = actor("CLEG", "ally", Vector2(500, 2000))
	var erased = actor("MTNK", "enemy", Vector2(650, 2000))
	chrono.attack_target = erased
	chrono._fire_shot(erased)
	AlliedAbilities.channel(chrono, 0.1)
	var work: float = chrono.special.temporal_work
	var parked = actor("MGTK", "ally", Vector2(2200, 1350))
	var tree: String = AlliedAbilities.disguise_visual(parked).art.key
	var save := BattleSaves.save_slot(battle, "slot1")
	check(save.ok, tag + "all new runtime states serialize via whitelist: " + save.get("message", ""))
	if save.ok:
		var loaded := BattleSaves.read_slot("slot1")
		check(loaded.ok, tag + "new snapshot validates")
		if loaded.ok:
			var codec = preload("res://scripts/save/battle_snapshot.gd").new()
			codec.restore(battle, loaded.snapshot)
			check(battle.units.any(func(u): return battle.actor_alive(u) and u.unit_id == "MGTK" and u.side == "ally" and u.position == Vector2(2200, 1350) and AlliedAbilities.disguise_visual(u).art.key == tree), tag + "parked mirage keeps the same tree across disk save")
			check(battle.units.any(func(u): return is_instance_valid(u) and u.unit_id == "FV" and u.logistics.capacity == 1), tag + "restored IFV retains capacity")
			var new_controller = battle.units.filter(func(u): return u.unit_id == "PTROOP" and u.position == Vector2(500, 1800))[0]
			var new_chrono = battle.units.filter(func(u): return u.unit_id == "CLEG" and u.position == Vector2(500, 2000))[0]
			check(new_controller.special.controlled.special.controller == new_controller, tag + "save restores both ends of control link")
			check(new_chrono.special.temporal_work == work and new_chrono.special.temporal_target.special.temporal_by == new_chrono, tag + "save restores erasure progress and target freeze")
			var restored_target = new_chrono.special.temporal_target
			AlliedAbilities.tick_actor(restored_target, 0.0)
			check(restored_target.material is ShaderMaterial and restored_target.material.get_shader_parameter("temporal_active"), tag + "saved temporal link reconstructs frozen presentation")
			AlliedAbilities.release_control(new_controller)
			check(not new_controller.special.has("controlled"), tag + "restored control can release")
			new_chrono.order_stop()
			check(not new_chrono.special.has("temporal_target"), tag + "restored erasure can cancel")
			# Exact prior schema with content digest; no arbitrary version bypass.
			var envelope: Dictionary = bytes_to_var(FileAccess.get_file_as_bytes(BattleSaves.slot_path("slot1")).slice(48))
			var previous: Dictionary = bytes_to_var(envelope.payload)
			for record in previous.records:
				if record.kind in ["unit", "building"]: record.fields.erase("special")
				if record.kind == "projectile": record.fields.erase("splinters")
				if record.kind == "battle": record.fields.erase("allied_state")
			envelope.payload = var_to_bytes(previous)
			envelope.hash = BattleSaves.digest(envelope.payload)
			envelope.content = BattleSaves.pre_allied_hash()
			var file := FileAccess.open(BattleSaves.slot_path("slot2"), FileAccess.WRITE)
			file.store_buffer(BattleSaves.pack_file(envelope)); file.close()
			check(BattleSaves.read_slot("slot2").ok, tag + "previous baseline schema remains readable")

func stealth_and_swimming(tag: String) -> void:
	var spy = actor("SPY", "enemy", Vector2(1900, 800))
	var disguise = actor("E1", "ally", Vector2(2050, 800))
	check(AlliedAbilities.use(spy, "allied_disguise", disguise), tag + "spy can copy enemy infantry")
	var shooter = actor("MTNK", "ally", Vector2(1800, 800))
	check(not shooter._weapon_domain_valid(spy), tag + "automatic fire ignores disguised spy")
	var dog = actor("DOG", "ally", Vector2(1850, 800))
	check(shooter._weapon_domain_valid(spy), tag + "dog detection exposes disguised spy to allies")
	var mirage = actor("MGTK", "enemy", Vector2(1900, 1000))
	remove_actor(dog)
	check(not AlliedAbilities.disguise_visual(mirage).is_empty(), tag + "stationary mirage uses real extracted tree")
	var first_tree: String = AlliedAbilities.disguise_visual(mirage).art.key
	var stable_tree := true
	for attempt in 16:
		mirage.order_move(mirage.position + Vector2.RIGHT * 80)
		AlliedAbilities.tick_actor(mirage, 0.1)
		mirage.order_stop()
		AlliedAbilities.tick_actor(mirage, 0.1)
		var visual := AlliedAbilities.disguise_visual(mirage)
		if visual.is_empty() or visual.art.key != first_tree or visual.frame != 0 or visual.art.detail.is_empty():
			stable_tree = false
			break
		AlliedAbilities.tick_actor(mirage, 0.1)
		if AlliedAbilities.disguise_visual(mirage).art.key != first_tree:
			stable_tree = false
			break
	check(stable_tree, tag + "mirage keeps the same native tree and detail after moving and stopping", first_tree)
	check(not shooter._weapon_domain_valid(mirage), tag + "stationary mirage conceals from automatic targeting")
	mirage._fire_shot(disguise)
	check(AlliedAbilities.disguise_visual(mirage).is_empty() and shooter._weapon_domain_valid(mirage), tag + "firing reveals mirage model and targeting")
	var revealed_tree: String = mirage.special.get("mirage_tree", "")
	AlliedAbilities.tick_actor(mirage, 0.1)
	check(mirage.special.get("mirage_tree", "") == revealed_tree, tag + "firing reveal does not reroll the mirage tree")
	var water := Rect2(2700, 500, 300, 400)
	battle.water_rects = [water]
	battle.path_service.set_water([water])
	for id in ["GHOST", "TANY"]:
		var swimmer = actor(id, "ally", Vector2(2680, 650))
		check(swimmer.is_amphibious and swimmer._domain_ok(Vector2(2780, 650)), tag + id + " original amphibious movement accepts water")
		swimmer.position = Vector2(2780, 650)
		check(swimmer._swimming() and swimmer._fire_sequence() == "WetAttack", tag + id + " water uses native attack animation")
		remove_actor(swimmer)
	var ifv = actor("FV", "ally", Vector2(1600, 1200))
	var engineer = actor("ENGINEER", "ally", Vector2(1630, 1200))
	engineer.logistics.request_board(ifv)
	engineer.logistics.tick(0.1)
	check(ifv._ra2_tur.get("key") == "FV_tur2", tag + "engineer loads actual repair turret")
	battle.select_unit(ifv, false)
	battle._emit_selection()
	if DisplayServer.get_name() != "headless":
		battle.camera.position = Vector2(1650, 1000)
		battle.camera.zoom = Iso.cam_zoom(1.5)
		battle.select_unit(ifv, false)
		battle._emit_selection()
		await RenderingServer.frame_post_draw
		stage.get_texture().get_image().save_png(output_dir.path_join(tag.trim_suffix(": ") + "-abilities.png"))
	check(battle.request_ability(0) == 1, tag + "IFV real skill entry unloads passenger")
	ifv.logistics.tick(0.5)
	check(ifv.logistics.passengers.is_empty() and ifv._ra2_tur.get("key") == "FV_tur", tag + "native unload restores original model")

func resolve_ra3_hits(delta: float = 0.1) -> void:
	# Advance the real serialized impact path, only in fixtures that freeze physics.
	for shot in battle.projectiles_root.get_children():
		if shot is Projectile and shot.splinters.has("ra3_hit_delay"):
			shot._physics_process(delta)
