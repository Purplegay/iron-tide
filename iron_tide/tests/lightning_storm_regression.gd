extends "res://tests/base_recovery_regression.gd"

const Snapshot = preload("res://scripts/save/battle_snapshot.gd")
const AIM := Vector2(1200, 1200)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not ProjectSettings.get_setting("application/config/use_custom_user_dir", false):
		get_tree().quit(2)
		return
	await get_tree().process_frame
	if "--cold-storm" in OS.get_cmdline_user_args():
		await cold_load()
		write_result("storm-cold-result.json")
		return
	for mode in [MatchRules.RA2, MatchRules.EXTENDED]:
		await enemy_launch_alert(mode)
		for side in ["ally", "enemy"]:
			for removal in ["destroy_waiting", "destroy_active", "sell_waiting", "sell_active"]:
				await lifecycle(mode, side, removal)
		await timing(mode)
		await world_entry(mode)
		await persistence(mode)
		await legacy(mode, false)
		await legacy(mode, true)
	var child_output: Array = []
	var code := OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "res://tests/lightning_storm_regression.tscn", "--", "--cold-storm"], child_output, true)
	check(code == 0, "separate engine loads source-free storm saves in both modes", child_output)
	write_result("result.json")

func write_result(name: String) -> void:
	var file := FileAccess.open(output_dir.path_join(name), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failed": failed}, "  "))
	file.close()
	print("LIGHTNING_STORM checks=", checks.size(), " failed=", failed)
	get_tree().quit(0 if failed == 0 else 1)

func arena(mode: String) -> void:
	start(mode)
	for building in battle.buildings: building.free()
	battle.buildings.clear()
	battle.power_low = false
	battle.enemy_power.low = false
	GM.god_mode = false
	GM.one_shot_kill = false
	GM.infinite_power = false
	battle.paused = false
	get_tree().paused = false

func controller(side := "ally"):
	var result = battle._place_building("GAWEAT", side, Vector2(300, 300), true)
	result._buildup_play = -1.0
	result._sw_charge = result.sw_recharge()
	return result

func target():
	var result = battle.spawn_unit("MTNK", "enemy", AIM)
	result.max_hp = 100000.0
	result.hp = result.max_hp
	return result

func enemy_launch_alert(mode: String) -> void:
	arena(mode)
	if battle.fog != null:
		battle.fog.free()
		battle.fog = null
	var enemy = controller("enemy")
	battle._place_building("GAWEAP", "ally", AIM, true)
	var notices := []
	var pings := []
	var on_notice := func(msg: String, _color: Color):
		if "闪电风暴" in msg: notices.append(msg)
	var on_ping := func(pos: Vector2, kind: String):
		if kind == "alert": pings.append(pos)
	Events.battle_message.connect(on_notice)
	Events.radar_ping.connect(on_ping)
	Ra2Sfx.stop_eva()
	var voice_count := Ra2Sfx.a_eva_plays
	var ops = preload("res://scripts/world/skirmish_operations.gd")
	ops.tick(battle.skirmish_ai)
	check(enemy._storm_active and enemy._storm_delay > 0 and notices.size() == 1 and pings == [AIM, enemy.position], prefix + "AI launch warns and marks target before first strike", [notices, pings])
	check(Ra2Sfx.a_eva_plays == voice_count + 1 and Ra2Sfx._eva_last.has("EVA_LIGHTNINGSTORMCREATED") and Ra2Sfx._eva_cur_pri == 3, prefix + "enemy launch plays critical global EVA")
	ops.tick(battle.skirmish_ai)
	var friendly = controller()
	check(friendly.fire_superweapon(AIM), prefix + "player can launch while enemy storm pending")
	var plays_before_restore := Ra2Sfx.a_eva_plays
	check(notices == ["警告：敌方已发动闪电风暴！","我方已发动闪电风暴"] and pings == [AIM, enemy.position],prefix+" player confirmation is distinct from enemy launch and source pings")
	resume(Snapshot.new().capture(battle))
	check(notices.size() == 2 and pings.size() == 2 and Ra2Sfx.a_eva_plays == plays_before_restore, prefix + "restore does not replay either launch notice")
	Events.battle_message.disconnect(on_notice)
	Events.radar_ping.disconnect(on_ping)
	await finish()

func lifecycle(mode: String, side: String, removal: String) -> void:
	arena(mode)
	prefix += side + "/" + removal + ": "
	var source = controller(side)
	var victim = target()
	check(source.fire_superweapon(AIM), prefix + "launch consumes one ready charge")
	check(source._sw_charge == 0.0 and not source.fire_superweapon(AIM) and LightningStorm.storms(battle).size() == 1, prefix + "cannot double launch")
	var state: Dictionary = LightningStorm.storms(battle)[0]
	var expected_damage := 300.0 if mode == MatchRules.EXTENDED and side == "enemy" else 250.0
	check(is_equal_approx(state.delay, 250.0 / 15.0) and state.rules.duration_frames == 180 and state.rules.damage == expected_damage, prefix + "native delay and duration retained with owner damage multiplier")
	source._tick_superweapon(2.0)
	check(source._sw_charge == 0.0 and is_equal_approx(state.delay, 250.0 / 15.0), prefix + "launcher neither double ticks nor recharges during storm")
	battle.paused = true
	LightningStorm.tick(battle, 100.0)
	check(is_equal_approx(state.delay, 250.0 / 15.0) and victim.hp == victim.max_hp, prefix + "paused battle freezes pending storm")
	battle.paused = false
	battle.power_low = true
	battle.enemy_power.low = true
	LightningStorm.tick(battle, 1.0)
	check(is_equal_approx(state.delay, 235.0 / 15.0), prefix + "power loss does not stop launched storm")
	if removal.ends_with("active"): LightningStorm.tick(battle, state.delay + 5.0)
	var before: float = victim.hp
	if removal.begins_with("sell"): source.retire_sold()
	else: source.receive_hit(source.hp * 100.0)
	await get_tree().process_frame
	check(not is_instance_valid(source) and LightningStorm.storms(battle).size() == 1, prefix + "source actually freed while world effect remains")
	LightningStorm.tick(battle, state.delay + 5.0)
	check(victim.hp < before and state.side == side, prefix + "source-free storm continues damage with saved owner")
	battle.ended = true
	var elapsed: float = state.time
	LightningStorm.tick(battle, 20.0)
	check(state.time == elapsed, prefix + "ended battle cannot keep applying damage")
	battle.ended = false
	LightningStorm.tick(battle, 20.0)
	check(LightningStorm.storms(battle).is_empty(), prefix + "finite storm expires without a launcher")
	before = victim.hp
	LightningStorm.tick(battle, 20.0)
	check(victim.hp == before, prefix + "expired storm never damages again")
	await finish()

func timing(mode: String) -> void:
	var reference := {}
	for fps in [0, 15, 60]:
		arena(mode)
		var source = controller()
		var victim = target()
		source.fire_superweapon(AIM)
		var state: Dictionary = LightningStorm.storms(battle)[0]
		state.rng.seed = 90125
		var total := 250.0 / 15.0 + 22.0
		if fps == 0: LightningStorm.tick(battle, total)
		else:
			for frame in int(round(total * fps)): LightningStorm.tick(battle, 1.0 / fps)
		var result := {"hp": victim.hp, "rng": state.rng.state, "effects": battle.effects_root.get_child_count()}
		if fps == 0: reference = result
		check(result == reference, prefix + "same damage random stream and effect count for time partition " + str(fps), result)
		check(is_equal_approx(state.next_hit, 12.0) and is_equal_approx(state.next_scatter, 12.0), prefix + "eighteen center and thirty-six scatter attempts before separation")
		check(not source._storm_active and LightningStorm.storms(battle).is_empty(), prefix + "duration boundary clears launcher mirror")
		source._tick_superweapon(1.0)
		check(source._sw_charge == 1.0, prefix + "source can recharge after storm ends")
		await finish()

func resume(snapshot: Dictionary) -> void:
	Snapshot.new().restore(battle, snapshot)
	check(battle.paused and get_tree().paused, prefix + "restore opens paused")
	battle.paused = false
	get_tree().paused = false

func world_entry(mode: String) -> void:
	arena(mode)
	var source = controller()
	var other = controller("enemy")
	other.position = Vector2(2100, 300)
	for side in ["ally", "enemy"]:
		for y in [100, 500]:
			battle._place_building("GAPOWR", side, Vector2(500 if side == "ally" else 1900, y), true)
	var victim = target()
	source.fire_superweapon(AIM)
	var first: Dictionary = LightningStorm.storms(battle)[0]
	battle._process(1.0)
	check(is_equal_approx(first.delay, 235.0 / 15.0), prefix + "actual Battle process advances world storm once")
	check(other.fire_superweapon(AIM), prefix + "second powered controller launches after actual world tick")
	if LightningStorm.storms(battle).size() < 2:
		await finish()
		return
	var second: Dictionary = LightningStorm.storms(battle)[1]
	first.rng.seed = 90125; second.rng.seed = 90125
	check(LightningStorm.storms(battle).size() == 2 and first.side != second.side, prefix + "opposing simultaneous storms keep separate ownership")
	LightningStorm.tick(battle, first.delay + 12.0)
	var last := 12.0
	for cloud in first.clouds: last = maxf(last, cloud.expires)
	LightningStorm.tick(battle, last - first.time + 0.001)
	check(LightningStorm.storms(battle).size() == 1 and not source._storm_active and other._storm_active, prefix + "first expiry cannot cancel later opposing storm")
	var before: float = victim.hp
	LightningStorm.tick(battle, 2.0)
	check(victim.hp == before and before < victim.max_hp and LightningStorm.storms(battle).is_empty(), prefix + "second storm drains its cloud tail without extra damage")
	await finish()

func persistence(mode: String) -> void:
	arena(mode)
	var source = controller()
	var victim = target()
	source.fire_superweapon(AIM)
	var state: Dictionary = LightningStorm.storms(battle)[0]
	state.rng.seed = 527
	LightningStorm.tick(battle, state.delay + 1.25)
	var codec := Snapshot.new()
	var snapshot := codec.capture(battle)
	check(codec.error.is_empty() and BattleSaves.validate(snapshot).is_empty(), prefix + "live source and world storm snapshot accepted")
	LightningStorm.tick(battle, 2.0)
	var expected_hp: float = victim.hp
	var expected_rng: int = state.rng.state
	resume(snapshot)
	state = LightningStorm.storms(battle)[0]
	check(LightningStorm.source_of(state) == battle.buildings[0] and battle.buildings[0]._storm_active, prefix + "live source weak reference remaps to restored building")
	LightningStorm.tick(battle, 2.0)
	check(battle.units[0].hp == expected_hp and state.rng.state == expected_rng, prefix + "mid-storm reload produces identical damage and random continuation")
	LightningStorm.restore(battle)
	check(LightningStorm.storms(battle).size() == 1, prefix + "repeated restore cannot duplicate world storm")
	# Write a source-free waiting save and an active save for a fresh engine process.
	battle.buildings[0].retire_sold()
	await get_tree().process_frame
	battle.buildings.clear()
	if mode == MatchRules.RA2:
		state.delay = 3.0
		state.time = 0.0
		state.started = false
		state.next_hit = 0.0
		state.next_scatter = 0.0
	var slot := "slot1" if mode == MatchRules.RA2 else "slot2"
	check(BattleSaves.save_slot(battle, slot).ok, prefix + "source-free storm saved to disk")
	var stored: Dictionary = BattleSaves.read_slot(slot)
	check(stored.ok, prefix + "source-free disk save validates")
	if stored.ok:
		resume(stored.snapshot)
		check(LightningStorm.storms(battle).size() == 1 and LightningStorm.source_of(LightningStorm.storms(battle)[0]) == null, prefix + "missing launcher does not erase disk-restored storm")
	await finish()

func legacy(mode: String, active: bool) -> void:
	arena(mode)
	var source = controller()
	source._storm_active = true
	source._storm_target = AIM
	source._storm_delay = 0.0 if active else 7.5
	source._storm_time = 2.5 if active else 0.0
	source._storm_hit_timer = 0.25
	source._storm_scatter_timer = 0.125
	source._sw_charge = 0.0
	var snapshot := Snapshot.new().capture(battle)
	resume(snapshot)
	check(LightningStorm.storms(battle).size() == 1, prefix + "legacy building-owned storm migrates once")
	var state: Dictionary = LightningStorm.storms(battle)[0]
	check(state.delay == (0.0 if active else 7.5) and state.time == (2.5 if active else 0.0) and state.started == active, prefix + "legacy phase and elapsed delay survive")
	check(state.next_hit - state.time == 0.25 and state.next_scatter - state.time == 0.125, prefix + "legacy partial hit intervals are preserved")
	LightningStorm.tick(battle, 30.0)
	# An authoritative empty list must win over any stale old mirror.
	battle.buildings[0]._storm_active = true
	resume(Snapshot.new().capture(battle))
	check(LightningStorm.storms(battle).is_empty() and not battle.buildings[0]._storm_active, prefix + "expired world state cannot resurrect stale legacy mirror")
	await finish()

func cold_load() -> void:
	get_tree().current_scene = null
	for slot in ["slot1", "slot2"]:
		var loaded: Dictionary = BattleSaves.load_into_scene(slot)
		check(loaded.ok, slot + " cold load through actual scene route")
		if not loaded.ok: continue
		await get_tree().process_frame
		await get_tree().process_frame
		screen = get_tree().current_scene
		battle = screen.battle
		screen.process_mode = Node.PROCESS_MODE_DISABLED
		check(battle.paused and get_tree().paused and LightningStorm.storms(battle).size() == 1, slot + " cold storm starts paused")
		var state: Dictionary = LightningStorm.storms(battle)[0]
		check(LightningStorm.source_of(state) == null and state.rng is RandomNumberGenerator, slot + "cold restore needs no dead source and reconstructs RNG")
		var before: float = battle.units[0].hp
		var delay: float = state.delay
		LightningStorm.tick(battle, 60.0)
		check(state.delay == delay and battle.units[0].hp == before, slot + "paused cold restore does not advance")
		get_tree().paused = false
		battle.paused = false
		LightningStorm.tick(battle, delay + 5.0)
		check(battle.units[0].hp < before, slot + "cold restored source-free storm resumes damage")
		LightningStorm.tick(battle, 30.0)
		check(LightningStorm.storms(battle).is_empty(), slot + "cold restored storm finishes")
		get_tree().current_scene = null
		await finish()
