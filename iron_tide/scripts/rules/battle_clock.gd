extends RefCounted
class_name BattleClock
## Stored timers and normal combat use the user-selected 15-tick rules basis.
## Rendering FPS is independent; stored progress and prices keep their existing units.
const RULE_TICKS_PER_SECOND := 15.0
const NORMAL_TICKS_PER_SECOND := 15.0
## Unmatched production uses a slower 30-tick equivalent; mapped roles use SDK references.
const PRODUCTION_TICKS_PER_SECOND := 30.0
const PRODUCTION_SCALE := PRODUCTION_TICKS_PER_SECOND / NORMAL_TICKS_PER_SECOND
const NORMAL_SCALE := NORMAL_TICKS_PER_SECOND / RULE_TICKS_PER_SECOND
## User-selected 30-tick action pace; normal combat and production keep their clocks.
const PLACED_BUILDUP_SCALE := 30.0 / RULE_TICKS_PER_SECOND
const KIROV_BOMB_TICKS_PER_SECOND := 30.0

## BuildTime values from the local official RA3 SDK; role mapping is project policy.
## Never shorten an existing v0.2.5 base duration. Native YR timers/prices stay intact.
const PREVIOUS_PRODUCTION_SCALE := 4.0
const RA3_PRODUCTION_SECONDS := {
	"GAPOWR": 10.0,
	"GAPILE": 10.0,
	"GAREFN": 20.0,
	"GAWEAP": 20.0,
	"GAAIRC": 15.0,
	"GAYARD": 20.0,
	"GATECH": 30.0,
	"E1": 5.0,
	"GGI": 5.0,
	"ENGINEER": 10.0,
	"DOG": 2.0,
	"SPY": 10.0,
	"TANY": 30.0,
	"MTNK": 10.0,
	"FV": 10.0,
	"CMIN": 20.0,
	"AMCV": 60.0,
	"MGTK": 15.0,
	"ORCA": 15.0,
	"BEAG": 15.0,
	"DLPH": 10.0,
	"DEST": 20.0,
	"CARRIER": 30.0,
}

static func production_scale(data: Dictionary) -> float:
	if data.get("production_seconds_native", false): return 1.0
	var id := str(data.get("id", ""))
	# Both YR war factories share one construction pace. Keep each building's own cost and rule duration.
	if id == "NAWEAP": id = "GAWEAP"
	if id == "NAREFN": id = "GAREFN"
	# DOG is a legacy Allied ID; do not assign that mapping to a future Soviet dog.
	if not RA3_PRODUCTION_SECONDS.has(id) or (id == "DOG" and str(data.get("faction", "")) != "allied"):
		return PRODUCTION_SCALE
	var duration := GameData.ra2_build_time(data)
	var seconds := maxf(duration / PREVIOUS_PRODUCTION_SCALE, float(RA3_PRODUCTION_SECONDS[id]))
	return duration / maxf(0.001, seconds * NORMAL_SCALE)

static func set_speed(multiplier: float = 1.0) -> void:
	GM.fast_forward = clampf(multiplier, 0.25, 3.0)
	Engine.time_scale = NORMAL_SCALE * GM.fast_forward

static func leave_battle() -> void:
	GM.fast_forward = 1.0
	Engine.time_scale = 1.0

static func real_seconds(rule_seconds: float) -> float:
	return maxf(0.0, rule_seconds) / (NORMAL_SCALE * GM.fast_forward)

static func production_real_seconds(rule_seconds: float, data: Dictionary = {}) -> float:
	return real_seconds(rule_seconds) / production_scale(data)

static func control_delta(scaled_delta: float) -> float:
	return scaled_delta / maxf(0.001, Engine.time_scale)
