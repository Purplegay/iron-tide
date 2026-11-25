extends "res://tests/base_recovery_regression.gd"

var observed_delta := 0.0

func _process(delta: float) -> void:
	observed_delta += delta

func wait_real(seconds: float) -> void:
	var deadline := Time.get_ticks_usec() + int(seconds * 1000000.0)
	while Time.get_ticks_usec() < deadline:
		await get_tree().process_frame

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not ProjectSettings.get_setting("application/config/use_custom_user_dir", false):
		get_tree().quit(2)
		return
	await get_tree().process_frame
	GM.no_build_time = false
	GM.infinite_funds = false
	MetaProgress.reset_save()
	for mode in [MatchRules.RA2, MatchRules.EXTENDED]:
		start(mode)
		verify_production_pacing()
		check(Engine.time_scale == 1.0 and GM.fast_forward == 1.0, prefix + "new match uses user-selected 15-tick combat speed")
		check(is_equal_approx(GameData.ra2_build_time(GameData.get_building("GAPOWR")), 33.6), prefix + "native rule duration remains unchanged")
		check(is_equal_approx(screen.hud.production_seconds(GameData.get_building("GAPOWR")), 10.0), prefix + "power plant real duration 10.0 seconds")
		check(is_equal_approx(screen.hud.production_seconds(GameData.get_building("GAWEAP")), 21.0), prefix + "war factory real duration 21 seconds")
		# E2 is a formula reference, not an assertion that Soviet production is implemented.
		check(is_equal_approx(BattleClock.production_real_seconds(GameData.ra2_build_time({"id": "E2", "cost": 100})), 2.1), prefix + "unmapped 100-credit conscript reference duration 2.1 seconds")
		screen.hud.prod_tab = "building"
		screen.hud._refresh_production()
		screen.hud._update_production_live()
		check("10.0s" in screen.hud._prod_status_labels.GAPOWR.text, prefix + "actual idle card shows real seconds")
		for speed in [2.0, 3.0, 1.0]:
			screen.hud._cycle_speed()
			screen.hud._refresh_top()
			screen.hud._update_production_live()
			check(GM.fast_forward == speed and Engine.time_scale == 1.0 * speed, prefix + "toolbar multiplier relative to normal " + str(speed))
			check(is_equal_approx(screen.hud.production_seconds(GameData.get_building("GAPOWR")), 10.0 / speed), prefix + "card estimate follows speed " + str(speed))
			check("%.1fs" % (10.0 / speed) in screen.hud._prod_status_labels.GAPOWR.text, prefix + "existing card refreshes without rebuild " + str(speed))
		check(is_equal_approx(BattleClock.control_delta(0.2), 0.2), prefix + "camera and UI delta remain wall time")
		await wait_real(1.0)
		var begin := Time.get_ticks_usec()
		var baseline := observed_delta
		await wait_real(2.0)
		var real_elapsed := (Time.get_ticks_usec() - begin) / 1000000.0
		var ratio := (observed_delta - baseline) / real_elapsed
		check(absf(ratio - 1.0) < 0.3, prefix + "real engine advances one rule second per wall second", {"ratio": ratio, "wall": real_elapsed, "rule": observed_delta - baseline})
		var barracks = battle.buildings.filter(func(b): return b.side == "ally" and b.building_id == "GAPILE")[0]
		barracks._buildup_play = -1.0
		barracks.build_speed = 1.0
		barracks.process_mode = Node.PROCESS_MODE_PAUSABLE
		battle.funds = 10000.0
		var count: int = battle.units.size()
		check(barracks.enqueue("E1"), prefix + "real barracks accepts production")
		begin = Time.get_ticks_usec()
		while battle.units.size() == count and Time.get_ticks_usec() - begin < 7000000:
			await get_tree().process_frame
		real_elapsed = (Time.get_ticks_usec() - begin) / 1000000.0
		check(battle.units.size() == count + 1 and real_elapsed >= 4.6 and real_elapsed < 5.7, prefix + "actual GI completes around 5 wall seconds", real_elapsed)
		check(is_equal_approx(battle.funds, 9800.0), prefix + "faster production still charges exactly 200")
		check(barracks.enqueue("E1"), prefix + "second real production accepted")
		await wait_real(0.2)
		screen.hud._toggle_pause()
		var progress: float = barracks.progress
		await wait_real(0.2)
		check(barracks.progress == progress and Engine.time_scale == 1.0, prefix + "pause freezes real production without changing speed")
		screen.hud._toggle_pause()
		await wait_real(0.2)
		check(barracks.progress > progress, prefix + "resume keeps fast production on 15-tick clock")
		barracks.process_mode = Node.PROCESS_MODE_DISABLED
		var saved_progress: float = barracks.progress
		var saved := BattleSaves.save_slot(battle, "slot1")
		check(saved.ok, prefix + "save accepts unchanged rule-time schema")
		await finish()
		check(Engine.time_scale == 1.0 and GM.fast_forward == 1.0, prefix + "leaving battle restores normal menu clock")
		var loaded := BattleSaves.prepare_load("slot1")
		check(loaded.ok, prefix + "saved match can be prepared")
		screen = load("res://scenes/battle.tscn").instantiate()
		add_child(screen)
		screen.process_mode = Node.PROCESS_MODE_DISABLED
		battle = screen.battle
		check(Engine.time_scale == 1.0 and GM.fast_forward == 1.0, prefix + "loaded match starts at new normal speed")
		var found := false
		for b in battle.buildings:
			if b.building_id == "GAPILE" and not b.production.is_empty(): found = is_equal_approx(b.progress, saved_progress)
		check(found, prefix + "loaded production retains rule-time progress without rescaling")
		battle.end_battle(false)
		check(Engine.time_scale == 1.0 and is_instance_valid(screen.result_overlay), prefix + "real defeat and result screen reset clock")
		await finish()
	for mode in [MatchRules.RA2, MatchRules.EXTENDED]:
		await live_gameplay(mode)
		await measured_combat(mode)
	var file := FileAccess.open(output_dir.path_join("result.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failed": failed}, "  "))
	get_tree().quit(0 if failed == 0 else 1)

func live_gameplay(mode: String) -> void:
	start(mode)
	screen.process_mode = Node.PROCESS_MODE_INHERIT
	battle.edge_scroll_enabled = false
	GM.god_mode = false
	GM.one_shot_kill = false
	var attacker = battle.spawn_unit("MTNK", "ally", Vector2(1200, 1200))
	var target = battle.spawn_unit("E1", "enemy", Vector2(1280, 1200))
	target.hp = 1.0
	attacker.order_guard()
	battle.funds = 10000.0
	battle.request_structure("GAPOWR")
	check(battle.struct_queue.size() == 1, prefix + "live match queues a normal power plant")
	var start_usec := Time.get_ticks_usec()
	while int(battle.struct_ready.get("GAPOWR", 0)) == 0 and Time.get_ticks_usec() - start_usec < 14000000:
		await get_tree().process_frame
	var elapsed := (Time.get_ticks_usec() - start_usec) / 1000000.0
	check(int(battle.struct_ready.get("GAPOWR", 0)) == 1 and elapsed > 9.5 and elapsed < 10.9, prefix + "unfrozen match power plant completes around 10.0 wall seconds", elapsed)
	check(not is_instance_valid(target) or target._dead or target.hp <= 0.0, prefix + "live physics targeting and weapon damage defeat nearby enemy")
	var from: Vector2 = attacker.position
	attacker.order_move(from + Vector2(100, 0))
	await wait_real(0.5)
	check(attacker.position.distance_to(from) > 10.0, prefix + "live unit movement advances at new normal speed")
	if DisplayServer.get_name() != "headless":
		screen.hud._refresh_production()
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(output_dir.path_join(mode + "-15tick-clock-live.png"))
	# Deterministic final-hit fixture; the real short-game rule must perform settlement.
	for building in battle.buildings.duplicate():
		if is_instance_valid(building) and building.side == "enemy": building.receive_hit(1000000.0)
	for unit in battle.units.duplicate():
		if is_instance_valid(unit) and unit.side == "enemy": unit.receive_hit(1000000.0)
	var deadline := Time.get_ticks_usec() + 2000000
	while not battle.ended and Time.get_ticks_usec() < deadline: await get_tree().process_frame
	check(battle.ended and is_instance_valid(screen.result_overlay), prefix + "live victory rule reaches result screen")
	check(Engine.time_scale == 1.0 and GM.fast_forward == 1.0, prefix + "victory resets to menu clock")
	await finish()


# These measurements run real Godot physics against a wall clock, not a simulated delta loop.
func measured_combat(mode: String) -> void:
	start(mode)
	for building in battle.buildings: building.free()
	battle.buildings.clear()
	battle._refresh_pathing()
	await wait_real(0.2)
	for id in ["E1", "MTNK", "CMIN", "BFRT", "JUMPJET", "ORCA"]:
		var unit = battle.spawn_unit(id, "ally", Vector2(400, 1200))
		unit.process_mode = Node.PROCESS_MODE_PAUSABLE
		unit.fire_stance = "none"
		unit._think_timer = 10000.0
		unit.auto_harvest_enabled = false
		unit.hull_angle = 0.0
		unit.logistics.air_lift = 1.0
		unit.order_move(Vector2(2200, 1200))
		await wait_real(1.2)
		var origin: Vector2 = unit.position
		var start_usec := Time.get_ticks_usec()
		await wait_real(0.8)
		var elapsed := (Time.get_ticks_usec() - start_usec) / 1000000.0
		var distance: float = unit.position.distance_to(origin)
		var top: float = unit.flight.max_speed() if unit.is_air else unit.move_speed
		var expected := top * elapsed
		check(absf(distance - expected) <= maxf(8.0, expected * 0.12), prefix + id + " actual cruise follows 15-tick clock, not fast production", {"distance":distance,"wall_seconds":elapsed,"expected":expected,"rule_speed":top})
		unit.free()
		await get_tree().process_frame
	for id in ["E1", "MTNK", "GAPILL"]:
		var target = battle.spawn_unit("MTNK", "enemy", Vector2(1200, 1200))
		target.max_hp = 100000.0
		target.hp = target.max_hp
		var is_building: bool = id == "GAPILL"
		var actor = battle._place_building(id, "ally", Vector2(1000, 1200), true) if is_building else battle.spawn_unit(id, "ally", Vector2(1000, 1200))
		if is_building:
			actor._buildup_play = -1.0
			actor._think = 10000.0
		else:
			actor.order_guard()
			actor._think_timer = 10000.0
			actor.hull_angle = 0.0
			actor.turret_angle = 0.0
		actor.attack_target = target
		actor.process_mode = Node.PROCESS_MODE_PAUSABLE
		var times: Array = []
		var previous := 0.0
		var deadline := Time.get_ticks_usec() + 12000000
		while times.size() < 3 and Time.get_ticks_usec() < deadline:
			await get_tree().process_frame
			var current: float = actor._cd if is_building else actor._cd_timer
			if current > previous + 0.1: times.append(Time.get_ticks_usec() / 1000000.0)
			previous = current
		var expected := float(actor.cooldown)
		var intervals: Array = []
		for i in range(1, times.size()): intervals.append(times[i] - times[i - 1])
		check(times.size() == 3 and intervals.all(func(v): return absf(v - expected) < 0.12), prefix + id + " actual firing interval follows ROF / 15", {"intervals":intervals,"expected":expected})
		actor.free()
		target.free()
		await get_tree().process_frame
	await finish()

# Independent SDK fixture values, then the actual runtime/HUD consumers in both modes.
func verify_production_pacing() -> void:
	var refs: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/ra3_production_reference.json"))
	check(refs.size() == 23, prefix + "all 23 role references accounted for")
	for id in refs:
		var building := GameData.is_building(id)
		var data: Dictionary = GameData.get_building(id) if building else GameData.get_unit(id)
		check(not data.is_empty(), prefix + id + " reference maps to a real production entity")
		var native := GameData.ra2_build_time(data)
		var expected := maxf(native / 4.0, float(refs[id].seconds))
		check(is_equal_approx(BattleClock.production_real_seconds(native, data), expected), prefix + id + " SDK role time with previous-duration floor", {"native":native,"seconds":expected})
		check(is_equal_approx(screen.hud.production_seconds(data), expected), prefix + id + " HUD consumes new entity-specific pacing")
		for side in ["ally", "enemy"]:
			if building:
				check(is_equal_approx(native / battle.structure_work_rate(side, id), expected), prefix + side + id + " structure work consumes same pacing")
			else:
				var factory = battle.buildings.filter(func(b): return b.side == side and b.building_id == "GAPILE")[0]
				check(is_equal_approx(native / factory.production_work_rate(id), expected), prefix + side + id + " unit work consumes same pacing")
	var fallback := GameData.get_unit("SREF")
	check(is_equal_approx(screen.hud.production_seconds(fallback), GameData.ra2_build_time(fallback) / 2.0), prefix + "unmapped light tank uses slower 30-tick production equivalent")
	var soviet_dog := GameData.get_unit("DOG").duplicate(true)
	soviet_dog.faction = "soviet"
	check(BattleClock.production_scale(soviet_dog) == 2.0, prefix + "future Soviet DOG does not inherit Allied timing mapping")
	var power = battle.buildings.filter(func(b): return b.side == "ally" and b.building_id == "GAPOWR")[0]
	check(is_equal_approx(power.construction_work_rate(), 3.36), prefix + "in-place power construction uses same ten-second pacing")
	var refinery = battle.buildings.filter(func(b): return b.side == "ally" and b.building_id == "GAREFN")[0]
	check(is_equal_approx(GameData.ra2_build_time(GameData.get_unit("CMIN")) / refinery.production_work_rate("CMIN"), 20.0), prefix + "refinery miner ability follows twenty-second pacing")
