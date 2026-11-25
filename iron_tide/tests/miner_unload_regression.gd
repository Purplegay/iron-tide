extends "res://tests/refinery_traffic_regression.gd"
const Cycle = preload("res://scripts/world/economy_cycle.gd")
const Snapshot = preload("res://scripts/save/battle_snapshot.gd")

func park(miner, refinery, amount: float) -> void:
	miner._unlock_dock()
	miner.order_stop()
	miner.home_base = refinery
	miner.cargo = amount
	miner.cargo_gems = amount * 0.25
	miner.harvest_state = "to_base"
	miner._lock_dock()
	miner.position = miner._dock_pt
	miner._dock_phase = 1
	miner._back_in = true
	miner.harvest_state = "unloading"
	miner._unload_timer = miner.unload_time
	miner.hull_angle = miner._dock_out.angle()
	miner.velocity = Vector2.ZERO

func exercise(mode: String) -> void:
	for side in ["ally", "enemy"]:
		start(mode)
		if battle.fog != null: battle.fog.free(); battle.fog = null
		for b in battle.buildings: b.free()
		battle.buildings.clear(); battle._refresh_pathing()
		prefix = mode + " " + side + ": "
		var refinery = battle._place_building("GAREFN", side, Vector2(900, 900), true)
		var power = battle._place_building("GAPOWR", side, Vector2(500, 600), true)
		var purifier = battle._place_building("GAOREP", side, Vector2(1700, 1600), true)
		for b in [refinery, power, purifier]: b._buildup_play = -1.0
		power.power = 1000.0 # Keep the real purifier operational in this isolated arena.
		battle._update_power()
		check(is_equal_approx(Cycle.income_factor(battle, side), 1.25), prefix + "powered refinery bonus fixture")
		var miner = battle.spawn_unit("CMIN", side, Vector2(1200, 1200))
		activate(miner)
		park(miner, refinery, miner.cargo_cap)
		check(is_equal_approx(miner.unload_time, 1.0), prefix + "one-second whole-load adapter")
		var value: float = miner.cargo_value() * 1.25
		var money: float = battle.funds_for(side)
		var other: String = "enemy" if side == "ally" else "ally"
		var other_money: float = battle.funds_for(other)
		miner._process_harvester(0.99)
		check(miner.cargo == miner.cargo_cap and battle.funds_for(side) == money and miner._back_in,
			prefix + "no partial payout before complete unload")
		miner._process_harvester(0.01)
		check(miner.cargo == 0 and miner.cargo_gems == 0 and is_equal_approx(battle.funds_for(side) - money, value),
			prefix + "one second transfers whole mixed load with purifier once")
		check(battle.funds_for(other) == other_money and not miner._back_in and miner._harvest_exit != Vector2.INF,
			prefix + "correct treasury and immediate forward departure")
		miner._process_harvester(0.01)
		check(is_equal_approx(battle.funds_for(side) - money, value), prefix + "departure never repays cargo")
		# Partially filled trucks still spend one second parked; interruption pays nothing.
		park(miner, refinery, miner.cargo_cap * 0.25)
		money = battle.funds_for(side)
		var held: float = miner.cargo_value()
		miner._process_harvester(0.4)
		miner.order_move(Vector2(1500, 1500))
		check(battle.funds_for(side) == money and is_equal_approx(miner.cargo_value(), held) and not miner._dock_locked,
			prefix + "manual interruption retains all unpaid cargo and releases reservation")
		park(miner, refinery, miner.cargo_cap * 0.25)
		miner._process_harvester(0.99)
		check(battle.funds_for(side) == money and miner.cargo > 0, prefix + "partial load also waits full second")
		miner._process_harvester(10.0)
		check(is_equal_approx(battle.funds_for(side) - money, held * 1.25) and miner.cargo == 0,
			prefix + "large final timestep pays exact remaining load once")
		# Save a half-complete legacy timer with only its unpaid remaining cargo.
		park(miner, refinery, miner.cargo_cap * 0.5)
		miner.unload_time = 4.0; miner._unload_timer = 2.0; miner._unload_work = 0.75
		money = battle.funds_for(side); held = miner.cargo_value()
		var saved: Dictionary = BattleSaves.save_slot(battle, "quick")
		check(saved.ok, prefix + "mid-unload snapshot saves")
		# Recreate the exact previous catalog independently, including envelope checksum.
		var previous_units: Dictionary = GameData.unit_index.duplicate(true)
		var previous_buildings: Dictionary = GameData.building_index.duplicate()
		# The four-second miner predates the Soviet roster.
		for row in GameData.raw_docs["yr_soviet.json"].units: previous_units.erase(row.id)
		for row in GameData.raw_docs["yr_soviet.json"].buildings: previous_buildings.erase(row.id)
		previous_units.CMIN.harvester.unload_time = 4.0
		var old_hash := BattleSaves.digest(var_to_bytes([Snapshot.Schema.FIELDS, previous_units, previous_buildings, GameData.ra2_general, GameData.allied_capabilities]))
		check(old_hash != BattleSaves.content_hash(), prefix + "legacy fixture has distinct original catalog fingerprint")
		var path: String = BattleSaves.slot_path("quick")
		var envelope: Dictionary = bytes_to_var(FileAccess.get_file_as_bytes(path).slice(48))
		envelope.content = old_hash
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_buffer(BattleSaves.pack_file(envelope)); file.close()
		var read: Dictionary = BattleSaves.read_path(path)
		previous_units.CMIN.cost += 1.0
		envelope.content = BattleSaves.digest(var_to_bytes([Snapshot.Schema.FIELDS, previous_units, previous_buildings, GameData.ra2_general, GameData.allied_capabilities]))
		file = FileAccess.open(path, FileAccess.WRITE)
		file.store_buffer(BattleSaves.pack_file(envelope)); file.close()
		check(not BattleSaves.read_path(path).ok, prefix + "unrelated old price change remains incompatible")
		envelope.content = old_hash
		file = FileAccess.open(path, FileAccess.WRITE)
		file.store_buffer(BattleSaves.pack_file(envelope)); file.close()
		check(read.ok, prefix + "mid-unload snapshot checksum and schema load")
		if read.ok:
			Snapshot.new().restore(battle, read.snapshot)
			get_tree().paused = false; battle.paused = false
			miner = battle.units.filter(func(u): return u.unit_id == "CMIN" and u.side == side)[0]
			refinery = miner.home_base
			for actor in battle.units + battle.buildings: actor.process_mode = Node.PROCESS_MODE_DISABLED
			check(miner.harvest_state == "unloading" and miner._dock_home == refinery and miner._dock_locked, prefix + "restore preserves real dock links without new docking command")
			miner._process_harvester(0.49)
			check(is_equal_approx(miner.unload_time, 1.0) and miner.cargo > 0 and battle.funds_for(side) == money,
				prefix + "legacy timer keeps elapsed fraction without repaying prior cargo")
			miner._process_harvester(0.01)
			check(miner.cargo == 0 and is_equal_approx(battle.funds_for(side) - money, held * 1.25),
				prefix + "loaded timer completes remaining half second exactly once")
		# A larger waiting vehicle must not be admitted before the whole corridor clears.
		var next = battle.spawn_unit("CMIN", side, Vector2(1400, 1400)); activate(next)
		next.radius = miner.radius + 12.0
		next.home_base = refinery; next.cargo = next.cargo_cap; next.harvest_state = "to_base"; next._lock_dock()
		var exit_saved: Dictionary = BattleSaves.save_slot(battle, "quick")
		var exit_read: Dictionary = BattleSaves.read_slot("quick")
		check(exit_saved.ok and exit_read.ok, prefix + "departure and next FIFO save together")
		if exit_read.ok:
			Snapshot.new().restore(battle, exit_read.snapshot)
			get_tree().paused = false; battle.paused = false
			for actor in battle.units + battle.buildings: actor.process_mode = Node.PROCESS_MODE_DISABLED
			miner = battle.units.filter(func(u): return u.is_harvester and u.cargo == 0)[0]
			next = battle.units.filter(func(u): return u.is_harvester and u.cargo > 0)[0]
			refinery = next.home_base
			check(refinery.refinery_traffic.departing.get_ref() == miner and not refinery.refinery_traffic.can_enter(refinery, next),
				prefix + "restored departing vehicle still blocks next entrant")
		var dock: Vector2 = refinery.refinery_dock_point(miner.radius)
		var stage_point: Vector2 = dock + refinery.refinery_dock_direction() * miner.DOCK_STAGE_BACK
		var clear_distance: float = miner.radius + next.radius + 6.0
		miner.position = stage_point + refinery.refinery_dock_direction() * (clear_distance - 1.0)
		check(not refinery.refinery_traffic.can_enter(refinery, next), prefix + "next vehicle waits for actual combined-radius clearance")
		miner.position += refinery.refinery_dock_direction() * 2.0
		check(refinery.refinery_traffic.can_enter(refinery, next), prefix + "next FIFO entry opens immediately after lane clearance")
		await finish()
	# Existing physical four-miner FIFO test also measures actual reverse/unload/exit timing.
	await super.exercise(mode)

func finish() -> void:
	screen.free(); Ra2Sfx.stop_all(); Music.stop(); Music.player.stream = null
	await get_tree().process_frame
	OS.delay_msec(150)
