extends RefCounted
## Owner presentation for broadcast invisibility; gameplay remains field_conceals.
## SDK: GameObject opacity 0.4..0.9, UnitAISettings cycle 60 frames at 30 Hz,
## InvisibilityBroadcastUpdate refresh 0.2s. The cosine interpolation is an
## adapter, not a claim about the closed-source engine's interpolation curve.
const STATE := &"ra3_cloak_visual"
const PERIOD := 60.0 / 30.0
const UPDATE_PERIOD := 0.2

static func eligible(unit) -> bool:
	return unit is Unit and unit.side == "ally" and AlliedAbilities.alive(unit) \
		and unit.embarked_in == null and not unit.is_air_target() \
		and float(unit.special.get("reveal", 0.0)) <= 0.0 and not Ra3Mirage.field_active(unit)

static func tick(unit, delta: float) -> void:
	if not unit is Unit: return
	if not unit.get_tree().has_group(Ra3Mirage.SOURCE_GROUP) or not eligible(unit):
		if unit.has_meta(STATE):
			unit.remove_meta(STATE)
			unit.queue_redraw()
		return
	var state: Dictionary = unit.get_meta(STATE, {"check_left": 0.0, "covered": false, "phase": 0.0})
	if state.covered:
		state.phase = fposmod(float(state.phase) + delta, PERIOD)
	state.check_left -= delta
	if state.check_left <= 0.0:
		state.check_left = UPDATE_PERIOD
		var covered := Ra3Mirage.field_conceals(unit, "enemy")
		if covered != state.covered:
			state.phase = 0.0
			unit.queue_redraw()
		state.covered = covered
	if state.covered:
		unit.queue_redraw()
	unit.set_meta(STATE, state)

static func opacity(unit) -> float:
	if preload("res://scripts/units/expansion_2_infiltration.gd").hidden(unit):return 0.32
	if unit.special.has("echo_cloaked"): return 0.32
	if float(unit.special.get("progression_v1",{}).get("dive_cloak",0))>0:return 0.32
	if not unit.has_meta(STATE) or not eligible(unit): return 1.0
	var state: Dictionary = unit.get_meta(STATE, {})
	if not state.get("covered", false): return 1.0
	return 0.65 + 0.25 * cos(float(state.phase) * TAU / PERIOD)
