extends "res://tests/ground_control_regression.gd"

const Traffic = preload("res://scripts/units/local_traffic.gd")
const Steering = preload("res://scripts/units/vehicle_steering.gd")
const Snapshot = preload("res://scripts/save/battle_snapshot.gd")

class CountingTraffic extends "res://scripts/units/local_traffic.gd":
	var rebuilds: int = 0
	func _rebuild_candidates(unit: Unit, world: Battle, radius: float, mask: int) -> void:
		rebuilds += 1
		super._rebuild_candidates(unit, world, radius, mask)

class StepObserver extends Node:
	var world: Battle
	var actor: Unit
	var probe: CountingTraffic
	var observed: Array[int] = []
	var counts: Array[int] = []
	func _physics_process(_delta: float) -> void:
		observed.append(Engine.get_physics_frames())
		probe.ensure_candidates(actor)
		counts.append(probe.rebuilds)

var mover: Unit
var probe: CountingTraffic
var fillers: Array[Unit] = []

func spawn_actor(point: Vector2) -> Unit:
	var actor: Unit = battle.spawn_unit("MTNK", "ally", point)
	activate(actor)
	return actor

func rebuild_from_here() -> void:
	probe.invalidate_query()
	probe.ensure_candidates(mover)

func exercise(mode: String) -> void:
	start(mode)
	process_mode = Node.PROCESS_MODE_ALWAYS
	battle.set_physics_process(false)
	battle.paused = false
	battle.ended = false
	get_tree().paused = false
	for building in battle.buildings: building.free()
	battle.buildings.clear()
	battle._refresh_pathing()
	fillers.clear()
	for i in 96:
		fillers.append(spawn_actor(Vector2(1850 + (i % 8) * 35, 1800 + (i / 8) * 35)))
	mover = spawn_actor(Vector2(1000, 1000))
	mover.has_move_order = true
	mover.move_target = Vector2(1600, 1000)
	probe = CountingTraffic.new()
	mover._local_traffic = probe
	await get_tree().physics_frame
	check(battle.units.size() >= 96, prefix + "dense branch fixture is active")
	check_dense_lifetime()
	await check_real_ticks()
	check_query_guard_boundaries()
	check_live_consumption()
	check_early_invalidation()
	await check_sparse()
	await check_save_restore()
	await finish()

func check_dense_lifetime() -> void:
	probe.ensure_candidates(mover)
	var initial: int = probe.rebuilds
	check(initial == 1, prefix + "first query builds once")
	for speed in [1.0, 3.0]:
		BattleClock.set_speed(speed)
		for i in 4096:
			mover.velocity = Vector2.ZERO
			probe.apply(mover, speed / 15.0)
		check(probe.rebuilds == initial, prefix + str(speed) + "x 4096 logic calls preserve unchanged membership")
	Steering.open_corridor(mover, 0.0)
	check(probe.rebuilds == initial, prefix + "turning shares persistent candidates")
	battle.paused = true
	get_tree().paused = true
	for i in 4: probe.apply(mover, 10000.0)
	check(probe.rebuilds == initial, prefix + "pause and large deltas never expire membership")
	battle.paused = false
	get_tree().paused = false
	BattleClock.set_speed(1.0)

func check_real_ticks() -> void:
	rebuild_from_here()
	var initial: int = probe.rebuilds
	var observer := StepObserver.new()
	observer.world = battle
	observer.actor = mover
	observer.probe = probe
	observer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(observer)
	for i in 2048: await get_tree().physics_frame
	await get_tree().process_frame
	observer.set_physics_process(false)
	check(observer.observed.size() >= 2047, prefix + "real engine physics advanced beyond old two-frame lifetime")
	var stable := true
	for count in observer.counts:
		if count != initial: stable = false
	check(stable, prefix + "unchanged cache survives every observed physics frame")
	observer.free()

func query_cell_bounds(point: Vector2, reach: float) -> Array[Vector2i]:
	var cell: float = preload("res://scripts/world/battle_neighborhood.gd").CELL
	return [Vector2i(((point - Vector2.ONE * reach) / cell).floor()),
		Vector2i(((point + Vector2.ONE * reach) / cell).floor())]

func check_query_guard_boundaries() -> void:
	var origin: Vector2 = mover.global_position
	var cell: float = preload("res://scripts/world/battle_neighborhood.gd").CELL
	var radius: float = mover.radius + 60.0 + maxf(60.0, mover.move_speed * 0.8) + 64.0
	var reach: float = radius + battle.neighborhood.max_unit_radius
	var stable_start := Vector2.INF
	var crossing_start := Vector2.INF
	var crossing_end := Vector2.INF
	# Find premises independently of the cache's stored region. Both moves keep
	# the actor in one bucket, so membership revisions cannot explain a refresh.
	for x in range(768, 1024):
		var point := Vector2(x, 800)
		var end := point + Vector2(24, 0)
		if Vector2i((point / cell).floor()) == Vector2i((end / cell).floor()) and query_cell_bounds(point, reach) == query_cell_bounds(end, reach):
			stable_start = point
			break
	check(stable_start.is_finite(), prefix + "24-pixel fixture retains actor bucket and complete query rectangle")
	if stable_start.is_finite():
		mover.global_position = stable_start
		battle.neighborhood.relocate(mover)
		rebuild_from_here()
		var count: int = probe.rebuilds
		mover.global_position = stable_start + Vector2(24, 0)
		battle.neighborhood.relocate(mover)
		probe.ensure_candidates(mover)
		check(probe.rebuilds == count and probe.query_origin == stable_start, prefix + "exactly 24 pixels with unchanged query rectangle reuses membership")
	for x in range(768, 1024):
		if crossing_start.is_finite(): break
		var point := Vector2(x, 800)
		var previous: Array[Vector2i] = query_cell_bounds(point, reach)
		for offset in [1.0, -1.0, 8.0, -8.0, 24.0, -24.0]:
			var end := point + Vector2(offset, 0)
			if Vector2i((point / cell).floor()) != Vector2i((end / cell).floor()): continue
			var next: Array[Vector2i] = query_cell_bounds(end, reach)
			if next[0].x < previous[0].x or next[1].x > previous[1].x:
				crossing_start = point
				crossing_end = end
				break
	check(crossing_start.is_finite() and crossing_start.distance_to(crossing_end) <= 24.0, prefix + "query-rectangle expansion fixture stays within 24 pixels and one actor bucket")
	if crossing_start.is_finite():
		mover.global_position = crossing_start
		battle.neighborhood.relocate(mover)
		rebuild_from_here()
		var count: int = probe.rebuilds
		mover.global_position = crossing_end
		battle.neighborhood.relocate(mover)
		probe.ensure_candidates(mover)
		check(probe.rebuilds == count + 1 and probe.query_origin == crossing_end, prefix + "query rectangle entering a new cell refreshes before displacement expiry")
	mover.global_position = origin
	battle.neighborhood.relocate(mover)
	rebuild_from_here()
	var count: int = probe.rebuilds
	var original_speed: float = mover.move_speed
	mover.move_speed = maxf(original_speed * 1.5, 90.0)
	probe.ensure_candidates(mover)
	check(probe.rebuilds == count + 1, prefix + "larger speed-dependent query radius refreshes in the same step")
	mover.move_speed = original_speed
	rebuild_from_here()
	count = probe.rebuilds
	var original_air: bool = mover.is_air
	mover.is_air = not original_air
	probe.ensure_candidates(mover)
	check(probe.rebuilds == count + 1, prefix + "query collision mask switch refreshes in the same step")
	mover.is_air = original_air
	var replacement_point := Vector2(1030, 1000)
	var replacement_cell := Vector2i((replacement_point / cell).floor())
	check(not battle.neighborhood.unit_buckets.has(replacement_cell), prefix + "ABA fixture begins in an empty covered bucket")
	var removed: Unit = spawn_actor(replacement_point)
	rebuild_from_here()
	count = probe.rebuilds
	check(probe.nearby.has(removed), prefix + "ABA cache contains the original bucket occupant")
	battle.units.erase(removed)
	removed.free()
	check(not battle.neighborhood.unit_buckets.has(replacement_cell), prefix + "removing the last occupant really removes the bucket")
	# No cache consumption between removal and replacement: stale stamps must
	# distinguish the new bucket generation even though its cell/count match.
	var replacement: Unit = spawn_actor(replacement_point)
	probe.ensure_candidates(mover)
	check(probe.rebuilds == count + 1 and probe.nearby.has(replacement), prefix + "remove-empty-add ABA refreshes and returns the replacement actor")
	check(probe.nearby.all(func(actor): return is_instance_valid(actor)), prefix + "ABA refresh leaves no freed prior occupant in membership")
	battle.units.erase(replacement)
	replacement.free()

func check_live_consumption() -> void:
	var origin: Vector2 = mover.global_position
	var peer: Unit = spawn_actor(origin + Vector2(20, 0))
	rebuild_from_here()
	var count: int = probe.rebuilds
	check(probe.nearby.has(peer), prefix + "live-state fixture is a retained member")
	peer.global_position = origin + Vector2(10, 0)
	battle.neighborhood.relocate(peer)
	mover.velocity = Vector2.ZERO
	probe.apply(mover, 0.2)
	check(probe.rebuilds == count and mover.velocity.x < 0.0, prefix + "retained member position is consumed live without refreshing")
	peer.collision_layer = 0
	mover.velocity = Vector2.ZERO
	probe.apply(mover, 0.2)
	check(probe.rebuilds == count and mover.velocity == Vector2.ZERO, prefix + "retained member changing to layer zero immediately stops separation")
	peer.collision_layer = 1
	peer.hp = 0.0
	mover.velocity = Vector2.ZERO
	probe.apply(mover, 0.2)
	check(mover.velocity == Vector2.ZERO, prefix + "cached dead peer does not push the mover")
	peer.hp = peer.max_hp
	peer.embarked_in = mover
	mover.velocity = Vector2.ZERO
	probe.apply(mover, 0.2)
	check(mover.velocity == Vector2.ZERO, prefix + "cached boarded peer does not push the mover")
	peer.embarked_in = null
	peer.side = "enemy"
	mover.velocity = Vector2.ZERO
	probe.apply(mover, 0.2)
	check(mover.velocity == Vector2.ZERO, prefix + "cached hostile ownership is consumed live")
	battle.units.erase(peer)
	peer.free()

func check_early_invalidation() -> void:
	var origin: Vector2 = mover.global_position
	rebuild_from_here()
	var count: int = probe.rebuilds
	mover.global_position = origin + Vector2(24.01, 0)
	battle.neighborhood.relocate(mover)
	probe.ensure_candidates(mover)
	check(probe.rebuilds == count + 1 and probe.query_origin == mover.global_position, prefix + "more than 24 pixels invalidates in the same step")
	mover.global_position = origin
	battle.neighborhood.relocate(mover)
	rebuild_from_here()
	count = probe.rebuilds
	var birth_point := Vector2(1030, 1000)
	var birth_cell := Vector2i((birth_point / 256.0).floor())
	check(not battle.neighborhood.unit_buckets.has(birth_cell), prefix + "birth fixture starts in an empty covered bucket")
	var born: Unit = spawn_actor(birth_point)
	probe.ensure_candidates(mover)
	check(probe.rebuilds == count + 1 and probe.nearby.has(born), prefix + "new neighbor in formerly empty bucket invalidates immediately")
	var radius: float = mover.radius + 60.0 + maxf(60.0, mover.move_speed * 0.8) + 64.0
	var watch: Unit = spawn_actor(Vector2(1600, 1000))
	var reach: float = radius + watch.radius
	var outside := Vector2.INF
	var inside := Vector2.INF
	for angle in [0.0, 0.6, 1.2, 2.0, 2.7]:
		var direction := Vector2.from_angle(angle)
		var a: Vector2 = origin + direction * (reach + 2.0)
		var b: Vector2 = origin + direction * (reach - 2.0)
		if Vector2i((a / 256.0).floor()) == Vector2i((b / 256.0).floor()):
			outside = a
			inside = b
			break
	check(outside.is_finite(), prefix + "same-cell boundary crossing fixture exists")
	if outside.is_finite():
		watch.global_position = outside
		battle.neighborhood.relocate(watch)
		rebuild_from_here()
		check(not probe.nearby.has(watch), prefix + "outside-circle neighbor is initially excluded")
		count = probe.rebuilds
		watch.global_position = inside
		battle.neighborhood.relocate(watch)
		probe.ensure_candidates(mover)
		check(probe.rebuilds == count + 1 and probe.nearby.has(watch), prefix + "same-cell excluded neighbor entering circle refreshes immediately")
	var layer_peer: Unit = spawn_actor(origin + Vector2(0, 70))
	layer_peer.collision_layer = 0
	rebuild_from_here()
	check(not probe.nearby.has(layer_peer), prefix + "layer-zero peer is excluded")
	count = probe.rebuilds
	layer_peer.collision_layer = 1
	probe.ensure_candidates(mover)
	check(probe.rebuilds == count + 1 and probe.nearby.has(layer_peer), prefix + "layer 0 to 1 enters candidates without waiting for expiry")
	rebuild_from_here()
	count = probe.rebuilds
	var distant: Unit = fillers[0]
	distant.global_position += Vector2(256, 0)
	battle.neighborhood.relocate(distant)
	probe.ensure_candidates(mover)
	check(probe.rebuilds == count, prefix + "unrelated distant bucket crossing keeps local cache valid")
	distant.global_position = origin + Vector2(0, -40)
	battle.neighborhood.relocate(distant)
	probe.ensure_candidates(mover)
	check(probe.rebuilds == count + 1 and probe.nearby.has(distant), prefix + "neighbor teleport into region invalidates immediately")
	count = probe.rebuilds
	probe.stalled_blockers(mover, mover.move_target)
	check(probe.rebuilds == count + 1, prefix + "detour blocker consumer explicitly forces fresh membership")
	probe.reset()
	check(probe.nearby.is_empty() and not probe.query_origin.is_finite(), prefix + "reset clears members and invalidates origin")
	count = probe.rebuilds
	probe.ensure_candidates(mover)
	check(probe.rebuilds == count + 1, prefix + "first consumer after reset rebuilds")
	mover.order_move(origin + Vector2(0, 500))
	check(probe.nearby.is_empty() and not probe.query_origin.is_finite(), prefix + "new move command invalidates cached neighbors")
	probe.ensure_candidates(mover)
	battle.units.erase(watch)
	watch.free()
	mover.velocity = Vector2.ZERO
	probe.apply(mover, 0.2)
	check(not is_instance_valid(watch), prefix + "removed candidate is safely consumed")

func check_sparse() -> void:
	for actor in fillers:
		if is_instance_valid(actor):
			battle.units.erase(actor)
			actor.free()
	fillers.clear()
	await get_tree().physics_frame
	check(battle.units.size() < 96, prefix + "sparse branch fixture is active")
	rebuild_from_here()
	var count: int = probe.rebuilds
	probe.ensure_candidates(mover)
	probe.ensure_candidates(mover)
	check(probe.rebuilds == count + 2, prefix + "sparse physics query conservatively refreshes every call")

func check_save_restore() -> void:
	# The test subclass is intentionally not part of the production save allowlist.
	mover._local_traffic = Traffic.new()
	mover._local_traffic.ensure_candidates(mover)
	mover._local_traffic.yield_target = mover.position + Vector2(20, 0)
	mover._local_traffic.yield_origin = mover.position
	mover._local_traffic.yield_left = 0.75
	mover.special["traffic_frame_fixture"] = true
	var codec := Snapshot.new()
	var captured: Dictionary = codec.capture(battle)
	check(codec.error.is_empty(), prefix + "production traffic state is serializable", codec.error)
	var traffic_records := 0
	for record in captured.records:
		if record.kind != "traffic": continue
		traffic_records += 1
		check(not record.fields.has("query_expires_step") and not record.fields.has("query_origin") and not record.fields.has("nearby"), prefix + "save record excludes candidate membership and expiry")
	check(traffic_records > 0, prefix + "snapshot actually contains production traffic records")
	var saved: Dictionary = BattleSaves.save_slot(battle, "slot1")
	check(saved.ok, prefix + "save through isolated real slot entry", saved)
	if not saved.ok: return
	var loaded: Dictionary = BattleSaves.prepare_load("slot1")
	check(loaded.ok, prefix + "read saved slot through production entry", loaded)
	if not loaded.ok: return
	BattleSaves.restore_pending(battle)
	battle.set_physics_process(false)
	battle.process_mode = Node.PROCESS_MODE_DISABLED
	var restored: Unit
	for actor: Unit in battle.units:
		actor.set_process(false)
		actor.set_physics_process(false)
		if actor.special.has("traffic_frame_fixture"): restored = actor
	check(is_instance_valid(restored), prefix + "saved mover restores")
	if not is_instance_valid(restored): return
	check(restored._local_traffic.nearby.is_empty() and not restored._local_traffic.query_origin.is_finite(), prefix + "load rebuilds query state instead of retaining stale actors")
	check(is_equal_approx(restored._local_traffic.yield_left, 0.75) and restored._local_traffic.yield_target.is_finite(), prefix + "load preserves durable yielding behavior")
	restored._local_traffic.ensure_candidates(restored)
	check(restored._local_traffic.query_origin == restored.global_position, prefix + "first post-load consumer obtains a current query")
