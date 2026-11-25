extends RefCounted
## Conservative fast path for AI actors with bookkeeping only. Unknown state
## always falls back, so a newly attached effect is handled on the same tick.
const INERT_KEYS := {"arc_count": true, "shot_idle": true, "shot_origin": true,
	"rest": true, "scrap_idle": true, "scrap_drop": true, "volley": true, "prism_damage": true}

static func try_tick(unit: Unit, delta: float) -> bool:
	# Player talent selection is live. Do not cache it or infer it from unit type.
	if unit.side == "ally" or unit.passive.get("id") == "ps_spine_scrap": return false
	var state: Dictionary = unit.special.get_or_add("progression_v1", {})
	if state.size() > INERT_KEYS.size() or float(state.get("prism_damage",0.0)) != 0.0: return false
	for key in state:
		if not INERT_KEYS.has(key): return false
	# These are the only writes performed by Cards/Talents/Heroes.tick for
	# this state: no timed effects, no player talent, no autonomous scrap passive.
	state.arc_count = 0
	state.shot_idle = float(state.get("shot_idle", 0.0)) + delta
	return true
