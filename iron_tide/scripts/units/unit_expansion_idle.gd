extends RefCounted
## Conservative fast path for actors with bookkeeping only. Unknown state
## always falls back, so a newly attached effect is handled on the same tick.
const INERT_KEYS := {"arc_count": true, "shot_idle": true, "shot_origin": true,
	"rest": true, "scrap_idle": true, "scrap_drop": true, "volley": true, "prism_damage": true}

static func try_tick(unit: Unit, delta: float) -> bool:
	if unit.passive.get("id") == "ps_spine_scrap": return false
	if unit.side == "ally":
		# Every ordinary unit may have bookkeeping-only state. Hero/summon
		# handlers and autonomous talents must still run on the current tick.
		if unit.special.has("academy_hero") or unit.special.has("expansion_temporary"): return false
		var rules=preload("res://scripts/units/expansion_rules.gd")
		# Most types cannot equip either autonomous talent. Read the live
		# definition once; eligible types still use the full rank/ownership rules.
		var options: Dictionary = MetaProgress.talent_options(unit.unit_id)
		if (options.has("mirage_afterheat") and rules.talent_rank(unit,"mirage_afterheat")>=0) or (options.has("ground_capacitor") and rules.talent_rank(unit,"ground_capacitor")>=0):return false
	var state: Dictionary = unit.special["progression_v1"] if unit.special.has("progression_v1") else unit.special.get_or_add("progression_v1", {})
	if state.size() > INERT_KEYS.size() or float(state.get("prism_damage",0.0)) != 0.0: return false
	if not INERT_KEYS.has_all(state.keys()): return false
	# These are the only writes performed by Cards/Talents/Heroes.tick for
	# this state: no timed effects, no player talent, no autonomous scrap passive.
	state.arc_count = 0
	state.shot_idle = float(state.get("shot_idle", 0.0)) + delta
	if unit.side=="ally" and unit.unit_id in ["E1","GGI"]:preload("res://scripts/world/battle_call_counters.gd").iterations(78,1)
	return true
