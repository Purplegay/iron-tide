class_name LightningStorm
extends RefCounted
## Battle-owned effects survive their launcher. Stored in the existing snapshot state.
const STATE_KEY := "lightning_storms"
const TICKS_PER_SECOND := 15.0
const EPSILON := 0.000001

static func storms(world) -> Array:
	return world.allied_state.get(STATE_KEY, [])

static func source_of(state: Dictionary):
	var reference = state.get("source")
	return reference.get_ref() if reference is WeakRef else null

static func active_for(world, building) -> bool:
	if world == null: return false
	for state in storms(world):
		if source_of(state) == building: return true
	return false

static func start(building, target: Vector2) -> bool:
	var world = building.battle
	if world == null or world.ended or not target.is_finite() or active_for(world, building): return false
	var rules: Dictionary = building.superweapon.get("storm", {}).duplicate(true)
	rules.damage = float(rules.get("damage", 250.0)) * preload("res://scripts/rules/superweapon_damage.gd").multiplier(building.side)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var state := {"source": weakref(building), "side": building.side, "rules": rules,
		"target": target, "delay": maxf(0.0, float(rules.get("deferment_frames", 250)) / TICKS_PER_SECOND),
		"time": 0.0, "next_hit": 0.0, "next_scatter": 0.0, "started": false, "rng": rng}
	state.version = 2
	state.clouds = []
	state.cloud_serial = 0
	if not world.allied_state.has(STATE_KEY): world.allied_state[STATE_KEY] = []
	world.allied_state[STATE_KEY].append(state)
	sync_legacy(state, true)
	return true

static func sync_legacy(state: Dictionary, active: bool) -> void:
	# Retained for older saves and existing diagnostics; these fields no longer tick.
	var source = source_of(state)
	if not is_instance_valid(source): return
	source._storm_active = active
	source._storm_target = state.target
	source._storm_delay = state.delay
	source._storm_time = state.time
	source._storm_hit_timer = maxf(0.0, state.next_hit - state.time)
	source._storm_scatter_timer = maxf(0.0, state.next_scatter - state.time)

static func restore(world) -> void:
	# New saves have the authoritative list, even when it is empty. Never reimport
	# mirrored launcher fields from such a save or an expired storm would restart.
	if world.allied_state.has(STATE_KEY):
		for building in world.buildings: building._storm_active = false
		for state in storms(world): sync_legacy(state, true)
		return
	world.allied_state[STATE_KEY] = []
	for building in world.buildings:
		if not building._storm_active or building.sw_type().to_lower() != "lightningstorm": continue
		var delay: float = building._storm_delay
		var elapsed: float = building._storm_time
		var hit: float = building._storm_hit_timer
		var scatter: float = building._storm_scatter_timer
		if not start(building, building._storm_target): continue
		var state: Dictionary = storms(world).back()
		state.delay = maxf(0.0, delay)
		state.time = maxf(0.0, elapsed)
		state.next_hit = state.time + maxf(0.0, hit)
		state.next_scatter = state.time + maxf(0.0, scatter)
		state.started = delay <= 0.0
		state.version = 1 # Preserve timing for already launched legacy storms.
		sync_legacy(state, true)

static func tick(world, delta: float) -> void:
	if delta <= 0.0 or world.paused or world.ended or world.get_tree().paused: return
	var remaining := []
	for state in storms(world):
		var alive := advance(world, state, delta)
		sync_legacy(state, alive)
		if alive: remaining.append(state)
	if world.allied_state.has(STATE_KEY): world.allied_state[STATE_KEY] = remaining
	preload("res://scripts/world/storm_presentation.gd").sync(world)

static func advance(world, state: Dictionary, delta: float) -> bool:
	if int(state.get("version", 1)) < 2: return advance_legacy(world, state, delta)
	return preload("res://scripts/world/storm_clouds.gd").advance(world, state, delta)

static func advance_legacy(world, state: Dictionary, delta: float) -> bool:
	var rules: Dictionary = state.rules
	if state.delay > 0.0:
		var waited := minf(delta, state.delay)
		state.delay = maxf(0.0, state.delay - waited)
		delta -= waited
		if state.delay > EPSILON: return true
		state.delay = 0.0
	if not state.started:
		state.started = true
		var sound := str(rules.get("start_sound", ""))
		if not sound.is_empty(): Ra2Sfx.play(sound, state.target)
	var duration := maxf(0.0, float(rules.get("duration_frames", 180)) / TICKS_PER_SECOND)
	var until := minf(duration, state.time + delta)
	var hit_period := maxf(1.0, float(rules.get("hit_delay_frames", 10))) / TICKS_PER_SECOND
	var scatter_period := maxf(1.0, float(rules.get("scatter_delay_frames", 5))) / TICKS_PER_SECOND
	# Consume deadlines in order, including the first strike at storm onset. Catch
	# up after a slow frame without changing the random sequence or dropping hits.
	while true:
		var event_time := minf(state.next_hit, state.next_scatter)
		if event_time > until + EPSILON or event_time >= duration - EPSILON: break
		if state.next_hit <= state.next_scatter + EPSILON:
			strike(world, state, state.target)
			state.next_hit += hit_period
		else:
			var spread := maxf(0.0, float(rules.get("cell_spread", 10))) * 55.0
			var rng: RandomNumberGenerator = state.rng
			var point: Vector2 = state.target + Vector2(rng.randf_range(-spread, spread), rng.randf_range(-spread, spread))
			strike(world, state, point)
			state.next_scatter += scatter_period
	state.time = until
	return until < duration - EPSILON

static func strike(world, state: Dictionary, point: Vector2) -> void:
	if world.fog != null: world.fog.reveal_superweapon_impact(point,2.0*Ra2Damage.PX_PER_CELL)
	SupportSystems.storm_bolt_at(world, state.rules, point, int(state.get("version", 1)) < 2)
	var source = source_of(state)
	SupportSystems.storm_damage_at(world, state.rules, point, source if world.actor_alive(source) else null)

static func radar_jammed(world, side: String) -> bool:
	for state in storms(world):
		if state.started and str(state.side) != side and float(state.time) < float(state.rules.get("duration_frames", 180)) / TICKS_PER_SECOND: return true
	return false
