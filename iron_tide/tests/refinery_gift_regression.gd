extends "res://tests/dual_build_regression.gd"

const Snapshot = preload("res://scripts/save/battle_snapshot.gd")

func count_miners(side: String = "ally") -> int:
	return battle.units.filter(func(u): return is_instance_valid(u) and u.unit_id == "CMIN" and u.side == side and u.hp > 0.0).size()

func gift_refinery():
	for b in battle.buildings:
		if b.special.get("gift_test", false): return b
	return null

func round_trip(slot: String, label: String) -> bool:
	var saved: Dictionary = BattleSaves.save_slot(battle, slot)
	check(saved.ok, label + " save accepted", saved)
	if not saved.ok: return false
	var read: Dictionary = BattleSaves.read_slot(slot)
	check(read.ok, label + " disk checksum/schema accepted")
	if not read.ok: return false
	Snapshot.new().restore(battle, read.snapshot)
	return true

func exercise_mode(mode: String) -> void:
	BattleRequest.configure_skirmish(mode, {"map_size": 3200, "starting_funds": 50000, "enemy_base": "allied"})
	screen = load("res://scenes/battle.tscn").instantiate()
	stage.add_child(screen)
	battle = screen.battle
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	screen.hud.process_mode = Node.PROCESS_MODE_ALWAYS
	screen.hud.set_process(false)
	GM.infinite_funds = false
	GM.unlock_production_tech = false
	battle.production_technology.unlocked.clear()
	var prefix := mode + ": "
	var initial := count_miners()
	for b in battle.buildings:
		b._process(GameData.ra2_buildup_seconds())
	check(count_miners() == initial and initial == 2, prefix + "map refinery does not add to the existing opening miners")
	battle.power_low = false
	var funds: float = battle.funds
	await click_card("building", "GAREFN")
	battle._tick_structure_queue(1000.0)
	check(int(battle.struct_ready.get("GAREFN", 0)) == 1 and count_miners() == initial, prefix + "sidebar completion alone gives no miner")
	check(is_equal_approx(funds - battle.funds, float(GameData.get_building("GAREFN").cost)), prefix + "only refinery price charged")
	var at := placement("GAREFN")
	check(at != Vector2.INF, prefix + "real placement location available")
	if at == Vector2.INF:
		screen.free()
		return
	battle.armed_build = "GAREFN"
	battle._try_place_building(at)
	var refinery = battle.buildings[-1]
	refinery.special["gift_test"] = true
	check(refinery.building_id == "GAREFN" and refinery._buildup_play >= 0.0, prefix + "real placed refinery plays buildup")
	refinery._process(GameData.ra2_buildup_seconds() * 0.25)
	check(count_miners() == initial, prefix + "no gift before buildup completes")
	var terrain: PackedFloat32Array = battle.path_service.cost.duplicate()
	battle.path_service.cost.fill(-1.0)
	refinery._process(GameData.ra2_buildup_seconds())
	funds = battle.funds
	for i in 3: refinery._process(1.0)
	check(count_miners() == initial and refinery.special.get("construction_free_unit") == "CMIN", prefix + "blocked exit retains exactly one pending gift")
	check(battle.funds == funds and refinery.production.is_empty(), prefix + "gift does not charge money or consume production queue")
	battle.path_service.cost = terrain
	var slot := "slot1" if mode == MatchRules.RA2 else "slot2"
	if not round_trip(slot, prefix + "pending gift"):
		screen.free()
		return
	refinery = gift_refinery()
	check(refinery.special.get("construction_free_unit") == "CMIN", prefix + "pending gift survives disk restore")
	refinery._process(0.3)
	check(count_miners() == initial + 1 and battle.funds == funds, prefix + "cleared exit releases one free miner without technology")
	var miner = battle.units[-1]
	check(miner.unit_id == "CMIN" and miner.home_base == refinery and miner.harvest_state == "to_node", prefix + "gift belongs to the new refinery and starts auto mining")
	check(not battle.path_service.is_blocked(miner.global_position), prefix + "gift exits on traversable terrain")
	check(refinery.queue_block_reason("CMIN").contains("科技"), prefix + "paid refinery manufacturing remains technology locked")
	for i in 3:
		refinery.notify_construction_placed()
		refinery._process(1.0)
	check(count_miners() == initial + 1, prefix + "repeated completion callbacks cannot duplicate gift")
	if round_trip("quick", prefix + "consumed gift"):
		refinery = gift_refinery()
		refinery._process(1.0)
		check(count_miners() == initial + 1, prefix + "loading completed refinery does not regrant")
		refinery.hp -= 8.0
		refinery.set_repairing(true)
		refinery._process(2.0)
		check(count_miners() == initial + 1, prefix + "repairing refinery does not regrant")
	var before := count_miners("enemy")
	var enemy = battle._place_building("GAREFN", "enemy", Vector2(1700, 1700), true, true)
	enemy._process(GameData.ra2_buildup_seconds())
	check(count_miners("enemy") == before + 1, prefix + "AI placed refinery also gets its own miner")
	var legacy = battle._place_building("GAREFN", "ally", Vector2(2200, 2200), true)
	legacy._buildup_play = -1.0
	var legacy_before := count_miners()
	if round_trip("quick", prefix + "old refinery without gift marker"):
		for b in battle.buildings: b._process(1.0)
		check(count_miners() == legacy_before, prefix + "old saves and map fixtures receive no retroactive gift")
	for action in ["sell", "destroy"]:
		var doomed = battle._place_building("GAREFN", "ally", Vector2(2600, 2600), true, true)
		var n := count_miners()
		if action == "sell": doomed.retire_sold()
		else: doomed._die()
		doomed._process(10.0)
		check(count_miners() == n, prefix + action + " before completion cannot deliver gift")
		await get_tree().process_frame
	screen.free()
	await get_tree().process_frame
	if mode == MatchRules.EXTENDED:
		var output: Array = []
		var code := OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "res://tests/refinery_gift_cold.tscn"], output, true)
		check(code == 0, "fresh engine restores and delivers pending gift exactly once in both modes", output)
