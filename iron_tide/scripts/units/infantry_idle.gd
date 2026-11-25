extends RefCounted
## Cosmetic timing is independent of orders, combat RNG, and saved combat state.
const BASE_WAIT := 0.15 * 60.0 # YR [AudioVisual] IdleActionFrequency, in minutes.
const FPS := BattleClock.RULE_TICKS_PER_SECOND / 2.0
var rng := RandomNumberGenerator.new()
var wait_left := -1.0
var elapsed := 0.0
var clip := ""
var previous := ""
var appearance := ""
var frame := -1
var wet := false

func _init(seed_value: int) -> void:
	rng.seed = seed_value

func reset(unit: Unit) -> void:
	wait_left = -1.0
	_end_clip(unit)

func _end_clip(unit: Unit) -> void:
	if frame >= 0: unit.queue_redraw()
	clip = ""
	frame = -1

func tick(unit: Unit, delta: float) -> void:
	if unit._dead or unit._deployed or unit.embarked_in != null or unit.has_move_order or unit.patrolling or unit.attack_ordered \
			or unit._moving() or unit.is_air_target() or unit._stun_timer > 0 \
			or unit._fire_anim_time >= 0 or unit._muzzle > 0 or AlliedAbilities.frozen(unit) or unit.special.has("pounce") \
			or not str(unit.special.get("action", "")).is_empty() \
			or (is_instance_valid(unit.attack_target) and unit._weapon_target_valid(unit.attack_target)):
		reset(unit)
		return
	if wait_left < 0: wait_left = rng.randf_range(BASE_WAIT * 0.5, BASE_WAIT)
	wait_left = maxf(0.0, wait_left - delta)
	if clip.is_empty() and wait_left > 0: return
	var id: String = unit.unit_id
	if unit.special.has("disguise") and float(unit.special.get("reveal", 0.0)) <= 0:
		id = str(unit.special.disguise)
	var water: bool = unit._swimming()
	var table: Dictionary = unit._seq if id == unit.unit_id else RA2Art.seq(id)
	if clip.is_empty():
		var choices: Array[String] = []
		for name in (["WetIdle1","WetIdle2"] if water else ["Idle1","Idle2"]):
			if int(table.get(name, {}).get("per", 0)) > 1: choices.append(name)
		if choices.is_empty():
			reset(unit)
			return
		if choices.size() > 1: choices.erase(previous)
		clip = choices[rng.randi_range(0, choices.size()-1)]
		previous = clip
		# IdleActionFrequency measures the interval between starts.
		wait_left = rng.randf_range(BASE_WAIT * 0.5, BASE_WAIT)
		appearance = id
		wet = water
		elapsed = 0.0
	else:
		if appearance != id or wet != water:
			reset(unit)
			return
		elapsed += delta
	var phase := int(elapsed * FPS)
	if phase >= int(table[clip].per):
		_end_clip(unit)
		return
	var next := RA2Art.seq_frame(table, clip, RA2Art.facing_index(unit.hull_angle, 8), phase)
	if next != frame:
		frame = next
		unit.queue_redraw()
