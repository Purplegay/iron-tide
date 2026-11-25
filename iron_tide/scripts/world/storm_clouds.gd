extends RefCounted
## Deadlines belong to the world, not animation nodes. Save/slow-frame safe.
const CELL := 55.0
const FPS := 15.0
const EPS := 0.000001
const Rules = preload("res://scripts/world/special_rules.gd")

static func rod_point(world, point: Vector2) -> Vector2:
	var closest = null
	var distance := CELL * 1.5
	for actor in world.units + world.buildings:
		if not world.actor_alive(actor) or actor is Unit and (actor.is_air or actor.embarked_in != null): continue
		var d: float = actor.position.distance_to(point)
		if d < distance:
			distance = d
			closest = actor
	if closest is Building and GameData._ra2_flag(Rules.building(closest.building_id).get("lightningrod", closest.data.get("lightning_rod", false))):
		return closest.position
	return point

static func create_cloud(world, state: Dictionary, point: Vector2, at: float, scattered: bool) -> void:
	if point.x < 0 or point.y < 0 or point.x >= world.map_size or point.y >= world.map_size: return
	if scattered:
		point = rod_point(world, point)
		var separation := maxf(0.0, float(state.rules.get("separation", 3))) * CELL
		for cloud in state.clouds:
			var offset: Vector2 = point - cloud.point
			if cloud.expires > at + EPS and absf(offset.x) + absf(offset.y) < separation: return
	var names: Array = state.rules.get("clouds", ["WCCLOUD1", "WCCLOUD2", "WCCLOUD3"])
	if names.is_empty(): return
	var rng: RandomNumberGenerator = state.rng
	var id := str(names[rng.randi_range(0, names.size() - 1)])
	var art := RA2Art.fx(id)
	var frames := maxi(1, int(art.get("count", 59)))
	var rate := maxf(1.0, float(art.get("fps", 6.25)))
	# Independent adapter: damage at the cloud animation's middle frame, then
	# let its second half dissipate. Not a claim of recovered EXE scheduling.
	state.cloud_serial += 1
	state.clouds.append({"id": id, "serial": state.cloud_serial, "point": point,
		"born": at, "hit": at + floorf(frames / 2.0) / rate, "expires": at + frames / rate, "struck": false})

static func advance(world, state: Dictionary, delta: float) -> bool:
	if state.delay > 0:
		var wait := minf(delta, state.delay)
		state.delay -= wait
		delta -= wait
		if state.delay > EPS: return true
		state.delay = 0.0
	if not state.started:
		state.started = true
		var sound := str(state.rules.get("start_sound", ""))
		if not sound.is_empty(): Ra2Sfx.play(sound, state.target)
	var duration := maxf(0.0, float(state.rules.get("duration_frames", 180))) / FPS
	var until: float = state.time + delta
	var hit_period := float(state.rules.get("hit_delay_frames", 10)) / FPS
	var scatter_period := float(state.rules.get("scatter_delay_frames", 5)) / FPS
	if hit_period <= 0: state.next_hit = duration
	if scatter_period <= 0: state.next_scatter = duration
	while true:
		var spawn_time: float = minf(state.next_hit, state.next_scatter)
		if spawn_time >= duration - EPS: spawn_time = INF
		var strike_time := INF
		for cloud in state.clouds:
			if not cloud.struck: strike_time = minf(strike_time, cloud.hit)
		var event_time := minf(spawn_time, strike_time)
		if event_time == INF or event_time > until + EPS: break
		state.clouds = state.clouds.filter(func(c): return c.expires > event_time - EPS)
		if strike_time <= spawn_time:
			for cloud in state.clouds:
				if not cloud.struck and cloud.hit <= event_time + EPS:
					cloud.struck = true
					LightningStorm.strike(world, state, cloud.point)
		elif state.next_hit <= state.next_scatter + EPS:
			create_cloud(world, state, state.target, event_time, false)
			state.next_hit += hit_period
		else:
			# rulesmd describes an n by n square, not a +/- n-cell radius.
			var n := maxi(1, int(state.rules.get("cell_spread", 10)))
			var rng: RandomNumberGenerator = state.rng
			var offset := Vector2(rng.randi_range(0, n - 1), rng.randi_range(0, n - 1)) - Vector2.ONE * (n - 1) * 0.5
			create_cloud(world, state, state.target + offset * CELL, event_time, true)
			state.next_scatter += scatter_period
	state.time = until
	state.clouds = state.clouds.filter(func(c): return c.expires > until + EPS)
	return until < duration - EPS or not state.clouds.is_empty()
