extends RefCounted
## Retail rulesmd.ini [General] CloseEnough; [AI] PathDelay / BlockagePathDelay.
## The exact native branch order is not reconstructed. Time here is scaled rule time.
const RETRY_SECONDS := 0.01 * 60.0
const DETOUR_SECONDS := 60.0 / BattleClock.RULE_TICKS_PER_SECOND
const CLOSE_DISTANCE := 2.25 * Ra2Damage.PX_PER_CELL
const EPS := 0.000001

enum Action { CLEAR, WAIT, RETRY, DETOUR, FINISH }

# One state slot per unit: repeated requests for the same step cannot add time
# or consume a second short retry. Long and short deadlines are independent.
var _since := 0.0
var _next_retry := RETRY_SECONDS
var _last_step := -1
var _goal := Vector2.INF

func clear() -> void:
	_since = 0.0
	_next_retry = RETRY_SECONDS
	_last_step = -1
	_goal = Vector2.INF

func tick(step: int, delta: float, goal: Vector2, blocked: bool, can_finish: bool, distance: float) -> int:
	if not blocked:
		if _last_step >= 0: clear()
		return Action.CLEAR
	if goal != _goal:
		clear()
		_goal = goal
	if step == _last_step: return Action.WAIT
	if _last_step >= 0: _since += delta
	_last_step = step
	if _since + EPS >= DETOUR_SECONDS: return Action.DETOUR
	if _since + EPS < _next_retry: return Action.WAIT
	_next_retry = _since + RETRY_SECONDS
	if can_finish and distance < CLOSE_DISTANCE: return Action.FINISH
	return Action.RETRY
