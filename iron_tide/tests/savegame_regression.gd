extends "res://tests/base_recovery_regression.gd"

var reports: Array = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not ProjectSettings.get_setting("application/config/use_custom_user_dir", false):
		get_tree().quit(2)
		return
	await get_tree().process_frame
	for mode in [MatchRules.RA2, MatchRules.EXTENDED]:
		await exercise(mode)
	await exercise_mission()
	var child_output: Array = []
	var code := OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "res://tests/savegame_cold.tscn"], child_output, true)
	check(code == 0, "fresh Godot process loads both modes from disk", child_output)
	var file := FileAccess.open(output_dir.path_join("result.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failed": failed, "user_dir": OS.get_user_data_dir()}, "  "))
	file.close()
	print("SAVEGAME checks=", checks.size(), " failed=", failed)
	get_tree().quit(0 if failed == 0 else 1)

func new_screen() -> void:
	screen = load("res://scenes/battle.tscn").instantiate()
	add_child(screen)
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	battle = screen.battle
	GM.infinite_funds = false
	GM.infinite_power = false
	GM.god_mode = false
	GM.one_shot_kill = false

func find_building(id: String, side := "ally"):
	for b in battle.buildings:
		if b.building_id == id and b.side == side: return b
	return null

func find_unit(id: String, side := "ally"):
	for u in battle.units:
		if u.unit_id == id and u.side == side: return u
	return null

func exercise(mode: String) -> void:
	prefix = mode + ": "
	BattleRequest.configure_skirmish(mode, {"map_size": 2400, "starting_funds": 8000, "enemy_base": "allied", "fog_of_war": true})
	new_screen()
	await get_tree().process_frame
	var refinery = find_building("GAREFN")
	var plant = find_building("GAPOWR")
	var factory = battle._place_building("GAWEAP", "ally", Vector2(1200, 1200), true)
	var lab = battle._place_building("GATECH", "ally", Vector2(1500, 1200), true)
	var airbase = battle._place_building("GAAIRC", "ally", Vector2(1800, 1200), true)
	for b in battle.buildings: b._buildup_play = -1.0
	var tank = battle.spawn_unit("MTNK", "ally", Vector2(1200, 1500))
	var enemy = battle.spawn_unit("MTNK", "enemy", Vector2(1400, 1500))
	var carrier = battle.spawn_unit("LCRF", "ally", Vector2(1000, 600))
	var passenger = battle.spawn_unit("GGI", "ally", Vector2(1200, 1520))
	var plane = battle.spawn_unit("ORCA", "ally", Vector2(1600, 1000))
	var ggi = battle.spawn_unit("GGI", "ally", Vector2(1250, 1550))
	ggi.set_deployed(true)
	ggi.hold_position = true
	check(not ggi.skills.is_empty(), prefix + "native skill fixture exists")
	if not ggi.skills.is_empty(): ggi.skills[0].cd_left = 7.25
	carrier.logistics.passengers.append(passenger)
	passenger.set_stowed(carrier)
	plane.logistics.home = airbase
	plane.logistics.ammo = 0
	plane.logistics.air_state = "reloading"
	plane.logistics.dock_slot = 1
	plane.logistics.reload_elapsed = 2.75
	plane.logistics.airport_repair_elapsed = 0.37
	tank.credit_kill(99999.0, "enemy")
	tank.hp = 123.0
	tank.attack_target = enemy
	tank.attack_ordered = true
	tank._cd_timer = 1.2
	tank._burst_left = 2
	tank._burst_timer = 0.13
	tank._burst_target = enemy
	tank.has_move_order = true
	tank.move_target = Vector2(1700, 1600)
	tank.order_queue = [{"position": Vector2(1800, 1600), "attack_move": false}]
	tank.buffs = [{"kind": "attack", "name": "save test", "left": 3.25, "dur": 5.0, "value": 1.1, "col": Color.CYAN, "col2": Color.WHITE, "debuff": false}]
	var miner = find_unit("CMIN")
	var ore = get_tree().get_nodes_in_group("resource_nodes")[0]
	ore.amount = 17.5
	ore.claim_by(miner)
	miner.resource_node = ore
	miner._ore_claim = ore
	miner.home_base = refinery
	miner.cargo = 10.0
	miner.cargo_gems = 3.0
	miner.harvest_state = "unloading"
	miner._unload_timer = 1.4
	miner._unload_work = 0.25
	miner.has_move_order = false
	miner._dock_locked = true
	miner._dock_home = refinery
	miner._dock_pt = refinery.refinery_dock_point(miner.radius)
	miner._dock_phase = 1
	miner.global_position = miner._dock_pt
	refinery.refinery_traffic.join(refinery, miner)
	factory.production = ["MTNK", "FV"]
	factory.production_paid = 123.5
	factory.progress = 2.75
	plant.hp -= 40.0
	plant.set_repairing(true)
	plant._building_repair_elapsed = 0.25
	lab.under_construction = true
	lab.build_total = 20.0
	lab.build_elapsed = 8.0
	lab.build_cost = 2000.0
	battle.struct_queue = [{"id": "GAPOWR", "cost": 800.0, "time": 33.6, "elapsed": 4.2, "paid": 100.0}]
	battle.struct_ready = {"GAPILE": 1}
	battle.struct_ready_order = ["GAPILE"]
	battle.enemy_struct_queue = [{"id": "GAPOWR", "cost": 800.0, "time": 33.6, "elapsed": 2.1, "paid": 50.0}]
	battle.funds = 4321.25
	battle.enemy_funds = 876.5
	battle.wave_timer = 12.75
	battle.ore_growth_elapsed = 8.5
	battle.kills = 7
	battle.production_technology.unlock("refinery_miner", "ally")
	battle.control_groups["1"] = [tank, factory]
	battle.rally_points[factory.get_instance_id()] = Vector2(1800, 1800)
	battle.select_unit(tank, false)
	battle._emit_selection()
	battle.skirmish_ai._army = [enemy]
	battle.skirmish_ai._attack_t = 27.5
	battle.skirmish_ai._rng.seed = 991
	battle.skirmish_ai._rng.randf()
	var rng_state: int = battle.skirmish_ai._rng.state
	battle.fog.explored_cells.ally[0] = 1
	battle.fog.reveal_attack(enemy, tank)
	var projectile := Projectile.new()
	projectile.setup(Vector2(1250, 1500), enemy, {"damage": 42.0, "projectile_speed": 60.0}, 42.0, {}, "ally", tank)
	battle.projectiles_root.add_child(projectile)
	projectile.life = 1.75
	var repair_depot = battle._place_building("GADEPT", "ally", Vector2(2100, 1800), true)
	repair_depot._buildup_play = -1.0
	var repair_vehicle = battle.spawn_unit("TNKD", "ally", Vector2(2100, 1600))
	repair_vehicle.hp -= 16
	# Keep the frozen fixture's collision bodies registered for the real repair query.
	repair_depot.disable_mode = CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
	repair_vehicle.disable_mode = CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
	await get_tree().physics_frame
	check(repair_vehicle.order_repair(repair_depot), prefix + "repair vehicle enters actual order before save")
	repair_vehicle.position = RepairDock.pad(repair_depot)
	repair_vehicle.special.repair_stage = "inside"
	repair_depot._repair_active = true
	repair_depot._anim_state = "repair_work"
	repair_depot._anim_group_t = 1.2
	var exiting_vehicle = battle.spawn_unit("SREF", "ally", Vector2(2100, 1800))
	exiting_vehicle.special.repair_exit_depot = repair_depot
	exiting_vehicle.special.repair_exit_point = repair_depot.dock_point(Vector2(2300, 1800))
	var storm_controller = battle._place_building("GAWEAT", "ally", Vector2(2100, 2100), true)
	storm_controller._buildup_play = -1.0
	storm_controller._storm_active = true
	storm_controller._storm_target = Vector2(1700, 800)
	storm_controller._storm_delay = 7.5
	var chronosphere = battle._place_building("GACSPH", "ally", Vector2(500, 1500), true)
	# Simulate the derived geometry retained by old saves before the dome was included.
	chronosphere._fp_poly = PackedVector2Array([Vector2(-10, -10), Vector2(10, -10), Vector2(10, 10), Vector2(-10, 10)])
	chronosphere._depth_anchor = Vector2(-999, -999)
	chronosphere._depth_anchor_ok = true
	var counts := [battle.units.size(), battle.buildings.size(), get_tree().get_nodes_in_group("resource_nodes").size(), get_tree().get_nodes_in_group("obstacles").size()]
	var original_match: String = battle.match_id
	var slot := "slot1" if mode == MatchRules.RA2 else "slot2"
	var saved: Dictionary = BattleSaves.save_slot(battle, slot)
	check(saved.ok, prefix + "captures complete runtime graph", saved)
	if not saved.ok:
		await finish()
		return
	var bytes := FileAccess.get_file_as_bytes(BattleSaves.slot_path(slot))
	exercise_pre_airport_save(bytes)
	check(bytes.size() > 0 and bytes.size() < 4000000, prefix + "bounded data-only save size", bytes.size())
	battle.funds = 2.0
	check(BattleSaves.save_slot(battle, "quick").ok, prefix + "quick slot writes independently")
	battle.funds = 3.0
	check(BattleSaves.save_slot(battle, "quick").ok and BattleSaves.read_path(BattleSaves.slot_path("quick") + ".bak").ok, prefix + "overwrite retains valid previous backup")
	check(FileAccess.get_file_as_bytes(BattleSaves.slot_path(slot)) == bytes, prefix + "quick save does not overwrite manual slot")
	var damaged := FileAccess.open(BattleSaves.slot_path("quick"), FileAccess.WRITE)
	damaged.store_string("interrupted write")
	damaged.close()
	var recovered: Dictionary = BattleSaves.read_slot("quick")
	check(recovered.ok and recovered.get("from_backup", false) and recovered.info.funds == 2.0, prefix + "damaged primary falls back to labeled previous backup")
	var invalid := BattleSaves.read_slot("../../escape")
	check(not invalid.ok, prefix + "slot traversal rejected")
	await finish()
	var ready: Dictionary = BattleSaves.prepare_load(slot)
	check(ready.ok, prefix + "validated load stages before scene creation")
	new_screen()
	check(BattleSaves.pending.is_empty() and battle.paused and get_tree().paused, prefix + "scene entry consumes pending save and pauses")
	check(battle.match_id == original_match and battle.funds == 4321.25 and battle.enemy_funds == 876.5, prefix + "identity and both economies restored")
	chronosphere = find_building("GACSPH")
	check(chronosphere.footprint_poly() == Building.placement_poly(chronosphere.data), prefix + "old Chronosphere footprint rebuilt from complete structure")
	check(chronosphere.depth_anchor().distance_to(chronosphere.position) < 200, prefix + "old Chronosphere depth anchor recalculated")
	for child in chronosphere.get_children():
		if child is CollisionPolygon2D:
			check(child.polygon == chronosphere.footprint_poly(), prefix + "restored Chronosphere collision agrees with expanded footprint")
	check([battle.units.size(), battle.buildings.size(), get_tree().get_nodes_in_group("resource_nodes").size(), get_tree().get_nodes_in_group("obstacles").size()] == counts, prefix + "no duplicate initial actors or regenerated ore")
	tank = find_unit("MTNK")
	enemy = find_unit("MTNK", "enemy")
	factory = find_building("GAWEAP")
	refinery = find_building("GAREFN")
	plant = find_building("GAPOWR")
	miner = find_unit("CMIN")
	carrier = find_unit("LCRF")
	plane = find_unit("ORCA")
	var deployed = null
	for u in battle.units:
		if u.unit_id == "GGI" and u.embarked_in == null: deployed = u
	check(tank.hp == 123.0 and tank.veteran_level == 2 and tank._cd_timer == 1.2, prefix + "health rank experience and weapon cooldown survive")
	check(tank.attack_target == enemy and tank._burst_target == enemy and tank._burst_left == 2 and tank._burst_timer == 0.13, prefix + "attack and burst targets reconnect")
	check(tank.has_move_order and tank.move_target == Vector2(1700, 1600) and tank.order_queue.size() == 1 and tank.buffs[0].left == 3.25, prefix + "orders and timed buffs survive")
	check(factory.production == ["MTNK", "FV"] and factory.production_paid == 123.5 and factory.progress == 2.75, prefix + "factory queue paid amount and progress survive")
	check(battle.struct_queue[0].paid == 100.0 and battle.struct_ready.GAPILE == 1 and battle.enemy_struct_queue[0].paid == 50.0, prefix + "both structure queues and ready placement survive")
	check(find_building("GATECH").under_construction and find_building("GATECH").build_elapsed == 8.0, prefix + "placed construction progress survives")
	check(plant.repairing and plant._building_repair_elapsed == 0.25, prefix + "building repair resumes exact interval")
	check(miner.home_base == refinery and miner._dock_home == refinery and miner._dock_locked and miner.harvest_state == "unloading", prefix + "harvester refinery/dock links survive")
	check(miner.cargo == 10.0 and miner.cargo_gems == 3.0 and miner._unload_timer == 1.4 and miner._unload_work == 0.25, prefix + "ore cargo and partial unloading preserved")
	check(miner.resource_node.amount == 17.5 and miner.resource_node.claim_owner() == miner and refinery.refinery_traffic.waiting[0].get_ref() == miner, prefix + "ore claims and FIFO weak references reconnect")
	check(carrier.logistics.passengers.size() == 1 and carrier.logistics.passengers[0].embarked_in == carrier and not carrier.logistics.passengers[0].visible and carrier.logistics.passengers[0].collision_layer == 0, prefix + "transport passengers stay hidden and noncolliding")
	check(deployed != null and deployed.is_deployed() and deployed.hold_position and deployed.skills[0].cd_left == 7.25, prefix + "deployed stance and native skill cooldown survive")
	check(plane.logistics.home == find_building("GAAIRC") and plane.logistics.ammo == 0 and plane.logistics.dock_slot == 1 and plane.logistics.reload_elapsed == 2.75, prefix + "aircraft dock and ammo reload survive")
	check(plane.logistics.airport_repair_elapsed == 0.37, prefix + "current save preserves partial airport repair timer")
	repair_depot = find_building("GADEPT")
	check(repair_depot._anim_state == "repair_work" and is_equal_approx(repair_depot._anim_group_t, 1.2), prefix + "repair arm phase and elapsed time survive disk save")
	check(repair_depot._ra2_anim.filter(func(layer): return repair_depot._layer_visible(layer.kind)).size() == 1 and repair_depot._layer_visible("specialanimtwo"), prefix + "loaded repair arm never overlays idle and working poses")
	repair_vehicle = find_unit("TNKD")
	exiting_vehicle = find_unit("SREF")
	check(repair_vehicle.repairing and repair_vehicle.repair_depot == repair_depot and repair_vehicle.special.repair_stage == "inside", prefix + "pad service stage and depot reference survive disk save")
	check(exiting_vehicle.special.repair_exit_depot == repair_depot and exiting_vehicle.special.repair_exit_point.is_finite(), prefix + "exit traversal remaps depot reference")
	check(repair_vehicle.get_collision_exceptions().is_empty() and exiting_vehicle.get_collision_exceptions().is_empty(), prefix + "save never persists collision exceptions")
	storm_controller = find_building("GAWEAT")
	check(storm_controller._storm_active and storm_controller._storm_delay == 7.5 and storm_controller._storm_target == Vector2(1700, 800), prefix + "lightning superweapon resumes saved target and delay")

	check(battle.skirmish_ai._army == [enemy] and battle.skirmish_ai._attack_t == 27.5 and battle.skirmish_ai._rng.state == rng_state, prefix + "AI army timers and RNG resume")
	check(battle.fog.explored_cells.ally[0] == 1 and battle.fog.firing_positions.has(enemy.get_instance_id()), prefix + "exploration and shot reveal survive with remapped IDs")
	check(battle.control_groups["1"] == [tank, factory] and battle.rally_points[factory.get_instance_id()] == Vector2(1800, 1800), prefix + "control group and rally instance IDs remap")
	tank.set_hovered(true)
	check(battle.control_group_badge(tank)=="1",prefix+"group badge restored on remapped tank")
	tank.set_hovered(false)
	check(battle.projectiles_root.get_child_count() == 1, prefix + "in-flight projectile restored once")
	projectile = battle.projectiles_root.get_child(0)
	check(projectile.target == enemy and projectile._credit_source.get_ref() == tank and projectile.life == 1.75, prefix + "projectile target and kill-credit source restored")
	check(battle.wave_timer == 12.75 and battle.ore_growth_elapsed == 8.5 and battle.kills == 7, prefix + "wave economy timers and statistics survive")
	var hp_before: float = enemy.hp
	get_tree().paused = false
	battle.paused = false
	projectile._explode()
	check(enemy.hp < hp_before, prefix + "restored in-flight shot can still apply damage")
	var money_before: float = battle.funds
	plant._process_building_repair(0.71)
	check(battle.funds < money_before, prefix + "restored repair continues charging through real runtime")
	var units_before: int = battle.units.size()
	factory.production_paid = float(GameData.get_unit("MTNK").cost)
	factory.progress = GameData.ra2_build_time(GameData.get_unit("MTNK"))
	factory._process(0.001)
	check(battle.units.size() == units_before + 1, prefix + "restored factory completes and emits one unit")
	await check_ui(mode)
	await check_bad_files(slot)
	if mode == MatchRules.EXTENDED:
		var result := {"match_id": original_match, "win": true, "kills": 7, "waves": 1}
		var first: Dictionary = MetaProgress.apply_battle_result(result)
		var money := MetaProgress.currency.duplicate(true)
		var second: Dictionary = MetaProgress.apply_battle_result(result)
		check(first.credits > 0.0 and second.get("already_settled", false) and MetaProgress.currency == money, prefix + "same saved match grants extension rewards only once")
		MetaProgress.load_save()
		check(MetaProgress.settled_matches.has(original_match), prefix + "settlement receipt persists on disk")
	get_tree().paused = false
	await finish()

func check_ui(mode: String) -> void:
	screen.hud.process_mode = Node.PROCESS_MODE_ALWAYS
	screen.hud.set_process(false)
	var key := InputEventKey.new()
	key.keycode = KEY_F5
	key.pressed = true
	get_viewport().push_input(key, true)
	check(BattleSaves.read_slot("quick").ok and is_equal_approx(BattleSaves.read_slot("quick").info.funds, battle.funds), prefix + "F5 reaches actual quick-save input handler")
	key = InputEventKey.new()
	key.keycode = KEY_F9
	key.pressed = true
	get_viewport().push_input(key, true)
	var panel = screen.hud.save_panel
	check(panel.root.visible and battle.paused and get_tree().paused and panel.slot_buttons.size() == BattleSaves.SLOTS.size() and panel.slot_buttons.has_all(BattleSaves.SLOTS), prefix + "slot browser pauses battle and exposes every configured slot")
	check(panel.slot_buttons.has("auto") and panel.slot_buttons.auto.save.disabled, prefix + "automatic slot is visible and cannot be manually overwritten")
	check(not panel.slot_buttons.slot1.load.disabled and not panel.slot_buttons.slot1.save.disabled, prefix + "populated slot exposes real save/load actions")
	var other_caption = panel.slot_buttons.slot1.caption
	panel.request_action("save", "quick")
	panel.confirmation.hide()
	panel._confirm()
	var row = panel.slot_buttons.quick
	check(is_instance_valid(other_caption) and other_caption == panel.slot_buttons.slot1.caption and row.caption.text == panel.slot_caption("quick", BattleSaves.read_slot("quick")) and not row.load.disabled, prefix + "overwrite updates only the saved row with verified slot details")
	panel.request_action("load", "slot1")
	check(panel.confirmation.visible, prefix + "in-battle load asks before discarding current progress")
	panel.confirmation.hide()
	var money_before: float = battle.funds
	key = InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = true
	get_viewport().push_input(key, true)
	check(get_tree().paused and battle.paused and battle.funds == money_before, prefix + "modal blocks gameplay pause hotkey")
	if DisplayServer.get_name() != "headless":
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(output_dir.path_join(mode + "-save-menu.png"))
	key = InputEventKey.new()
	key.keycode = KEY_ESCAPE
	key.pressed = true
	get_viewport().push_input(key, true)
	check(not get_tree().paused and not battle.paused, prefix + "closing browser restores running state")
	get_tree().paused = true
	battle.paused = true
	panel.open()
	panel.close()
	check(get_tree().paused and battle.paused, prefix + "opening over paused game preserves pause")
	get_tree().paused = false
	battle.paused = false

func check_bad_files(slot: String) -> void:
	var original := FileAccess.get_file_as_bytes(BattleSaves.slot_path(slot))
	var path := BattleSaves.slot_path("slot3")
	var envelope: Dictionary = bytes_to_var(original.slice(48))
	for kind in ["checksum", "version", "missing_field", "reference", "type", "truncated"]:
		var changed := envelope.duplicate(true)
		if kind == "checksum": changed.hash = "bad"
		elif kind == "version": changed.version = -1
		elif kind != "truncated":
			var snapshot: Dictionary = bytes_to_var(changed.payload)
			if kind == "missing_field": snapshot.records[0].fields.erase("funds")
			elif kind == "type": snapshot.records[0].fields.funds = "bad"
			else: snapshot.records[0].fields.selected_building = {"@ref": 999999}
			changed.payload = var_to_bytes(snapshot)
			changed.hash = BattleSaves.digest(changed.payload)
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_buffer(original.slice(0, 12) if kind == "truncated" else BattleSaves.pack_file(changed))
		file.close()
		var before: float = battle.funds
		var result: Dictionary = BattleSaves.prepare_load("slot3")
		check(not result.ok and battle.funds == before and BattleSaves.pending.is_empty(), prefix + kind + " invalid save rejected before mutating current battle")
	DirAccess.remove_absolute(path)

func exercise_pre_airport_save(serialized:PackedByteArray) -> void:
	var envelope:Dictionary=bytes_to_var(serialized.slice(48))
	var snapshot:Dictionary=bytes_to_var(envelope.payload)
	var fields:Dictionary=BattleSaves.Schema.FIELDS.duplicate(true)
	fields.logistics.erase("airport_repair_elapsed")
	envelope.content=BattleSaves.digest(var_to_bytes([fields,GameData.unit_index,GameData.building_index,GameData.ra2_general,GameData.allied_capabilities]))
	for record in snapshot.records:
		if record.kind=="logistics":record.fields.erase("airport_repair_elapsed")
	var path:="user://pre-airport.itsave"
	write_envelope(path,envelope,snapshot)
	var original:=FileAccess.get_file_as_bytes(path)
	var result:Dictionary=BattleSaves.read_path(path)
	check(result.ok,prefix+"exact pre-airport schema loads through normal disk validator")
	if result.ok:
		var timers:Array=result.snapshot.records.filter(func(r):return r.kind=="logistics")
		check(not timers.is_empty() and timers.all(func(r):return r.fields.airport_repair_elapsed==0.0),prefix+"only missing repair timers default to zero")
	check(FileAccess.get_file_as_bytes(path)==original,prefix+"loading previous schema never rewrites source save")
	var missing:Dictionary=snapshot.duplicate(true)
	missing.records[0].fields.erase(missing.records[0].fields.keys()[0])
	write_envelope(path,envelope,missing)
	check(not BattleSaves.read_path(path).ok,prefix+"pre-airport migration still rejects unrelated missing fields")
	var extra:Dictionary=snapshot.duplicate(true)
	extra.records[0].fields["unknown_field"]=0
	write_envelope(path,envelope,extra)
	check(not BattleSaves.read_path(path).ok,prefix+"pre-airport migration still rejects unknown fields")
	var changed:Dictionary=envelope.duplicate(true)
	changed.content="different-rules"
	write_envelope(path,changed,snapshot)
	check(not BattleSaves.read_path(path).ok,prefix+"unrecognized rule fingerprint remains rejected")
	write_envelope(path,envelope,snapshot)
	var broken:Dictionary=bytes_to_var(FileAccess.get_file_as_bytes(path).slice(48))
	broken.hash="corrupt-payload"
	FileAccess.open(path,FileAccess.WRITE).store_buffer(BattleSaves.pack_file(broken))
	check(not BattleSaves.read_path(path).ok,prefix+"historical schema retains payload checksum validation")
	DirAccess.remove_absolute(path)

func write_envelope(path:String,envelope:Dictionary,snapshot:Dictionary) -> void:
	var copy:=envelope.duplicate(true)
	copy.payload=var_to_bytes(snapshot);copy.hash=BattleSaves.digest(copy.payload)
	FileAccess.open(path,FileAccess.WRITE).store_buffer(BattleSaves.pack_file(copy))

func exercise_mission() -> void:
	BattleRequest.configure_mission("m01", {})
	new_screen()
	await get_tree().process_frame
	battle.prepared = true
	battle.wave_index = 1
	battle.wave_timer = 9.5
	var result: Dictionary = BattleSaves.save_slot(battle, "slot3")
	check(result.ok, "campaign snapshot saves without skirmish AI", result)
	await finish()
	if result.ok:
		check(BattleSaves.prepare_load("slot3").ok, "campaign load stages")
		new_screen()
		check(not battle.skirmish and battle.skirmish_ai == null and battle.fog == null and battle.wave_index == 1 and battle.wave_timer == 9.5, "campaign wave scheduler resumes")
		get_tree().paused = false
		await finish()
