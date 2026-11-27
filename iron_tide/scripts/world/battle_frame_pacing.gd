extends Node
## Fixed wall-clock simulation cadence. Render/input remain independent.
## Allow up to sixty-four total physics steps after a hitch; a one-step cap loses game time
## as soon as a complete frame exceeds 66.7 ms. Short weapon events stay local.
const LOGIC_HZ := 15
const CHASE_SECONDS := [0.35, 0.55, 0.8, 1.1]
const FOG_SECONDS := [0.10, 0.16, 0.24, 0.32]
var tier := 0
var _last_frame_us := 0
var _window_us := 0
var _window_frames := 0
var _healthy_windows := 0
var chase_replans := 0
var _retry_frame := -1
var _retry_waiting: Dictionary = {}
var _retry_grants: Dictionary = {}

# Stalled units can share the same retry clock after a load or a group order.
# Keep requests queued until the caller also holds its AI dispatch slot. A
# reservation on an intervening render frame must not consume a physics retry.
func allow_stuck_retry(actor_id: int, admitted := true) -> bool:
	if tier < 2:
		if not _retry_waiting.is_empty(): _retry_waiting.clear()
		if not _retry_grants.is_empty(): _retry_grants.clear()
		return admitted
	var frame := Engine.get_process_frames()
	var physics_tick := Engine.get_physics_frames()
	if frame != _retry_frame:
		_retry_frame = frame
		_retry_grants.clear()
		for id in _retry_waiting.keys():
			if physics_tick - int(_retry_waiting[id]) > 3:
				_retry_waiting.erase(id)
	var queued := _retry_waiting.has(actor_id)
	_retry_waiting[actor_id] = physics_tick
	var budget := 4 if tier == 3 else 8
	if queued and admitted and not _retry_grants.has(actor_id) and _retry_grants.size() < budget:
		for first in _retry_waiting:
			if first != actor_id: return false
			break
		_retry_waiting.erase(actor_id)
		_retry_grants[actor_id] = true
		return true
	return false

var _start_us := 0
var _work_us := 0
var _steps := 0
var _restore_hz := 0
var _restore_limit := 0
var _restore_interpolation := false
var _restore_interpolation_mode := Node.PHYSICS_INTERPOLATION_MODE_INHERIT
var _presentation_owner: BattleScreen
var _presentation_left := 0.0
var _recovery_us := 0
var _logic_hist := PackedInt64Array()
var _logic_count := 0
var _logic_sum_us := 0
var _logic_max_us := 0
var _logic_over_budget := 0
var _logic_rates: Dictionary = {}

# Use wall time so battle speed cannot promote a tier. Average short windows:
# alternating heavy/light frames matter, but one hitch cannot fill a window.
func observe_frame(duration_us: int) -> void:
	if duration_us <= 0: return
	_window_us += mini(duration_us, 100000)
	_window_frames += 1
	if _window_us < 500000: return
	var mean_us := float(_window_us) / _window_frames
	if mean_us >= 33000:
		tier = mini(tier + 1, CHASE_SECONDS.size() - 1)
		_healthy_windows = 0
	elif mean_us <= 23000 and tier > 0:
		_healthy_windows += 1
		if _healthy_windows >= 4:
			tier -= 1
			_healthy_windows = 0
	else:
		_healthy_windows = 0
	_window_frames = 0
	_window_us = 0

func _notification(what: int) -> void:
	if what == NOTIFICATION_UNPAUSED:
		_last_frame_us = 0
		_window_frames = 0
		_window_us = 0
		_healthy_windows = 0

func _ready() -> void:
	if get_parent() is BattleScreen:
		_presentation_owner = get_parent()
		_restore_interpolation = get_tree().physics_interpolation
		_restore_interpolation_mode = _presentation_owner.physics_interpolation_mode
		# Camera and UI remain immediate; Unit explicitly opts in.
		_presentation_owner.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		get_tree().physics_interpolation = true
		_presentation_owner.reset_physics_interpolation()
	_restore_hz = Engine.physics_ticks_per_second
	_restore_limit = Engine.max_physics_steps_per_frame
	Engine.physics_ticks_per_second = LOGIC_HZ
	Engine.max_physics_steps_per_frame = 64
	process_physics_priority = 1000
	_logic_hist.resize(5001)
	get_tree().physics_frame.connect(_begin_step)

func _begin_step() -> void:
	_start_us = Time.get_ticks_usec()

func _physics_process(_delta: float) -> void:
	if _start_us > 0:
		var elapsed := Time.get_ticks_usec() - _start_us
		_work_us += elapsed
		_steps += 1
		record_logic_step(elapsed, Engine.physics_ticks_per_second)

func record_logic_step(elapsed: int, hz: int) -> void:
	if _logic_hist.is_empty(): _logic_hist.resize(5001)
	_logic_count += 1
	_logic_sum_us += elapsed
	_logic_max_us = maxi(_logic_max_us, elapsed)
	_logic_hist[mini(5000, ceili(elapsed / 1000.0))] += 1
	_logic_rates[hz] = int(_logic_rates.get(hz, 0)) + 1
	if elapsed * hz > 1000000: _logic_over_budget += 1

func take_logic_stats() -> Dictionary:
	var result := {"count":_logic_count,"mean_ms":_logic_sum_us / maxf(1.0,_logic_count) / 1000.0,
		"max_ms":_logic_max_us / 1000.0,"p95_ms":0,"p99_ms":0,"over_current_hz_budget":_logic_over_budget,
		"rates":_logic_rates,"histogram_bucket_ms":1,"histogram_cap_ms":5000,
		"scope":"Physics callbacks through priority 1000; excludes later physics-server work, process and rendering. Percentiles at cap are lower bounds."}
	var seen := 0
	for i in _logic_hist.size():
		seen += _logic_hist[i]
		if seen < ceili(_logic_count * 0.95): continue
		result.p95_ms = i
		break
	seen = 0
	for i in _logic_hist.size():
		seen += _logic_hist[i]
		if seen < ceili(_logic_count * 0.99): continue
		result.p99_ms = i
		break
	_logic_hist.fill(0)
	_logic_count = 0
	_logic_sum_us = 0
	_logic_max_us = 0
	_logic_over_budget = 0
	_logic_rates = {}
	return result

func _process(_delta: float) -> void:
	_presentation_left -= BattleClock.control_delta(_delta)
	if _presentation_owner != null and _presentation_left <= 0.0:
		_presentation_left = 1.0 / 30.0
		for unit in _presentation_owner.battle.units:
			if is_instance_valid(unit) and unit.visible and unit.motion_pose.turning(unit): unit.queue_redraw()
	var now := Time.get_ticks_usec()
	if _last_frame_us > 0: observe_frame(now - _last_frame_us)
	_last_frame_us = now
	_steps = 0
	_work_us = 0

func _restore() -> void:
	if _restore_hz > 0:
		Engine.physics_ticks_per_second = _restore_hz
		Engine.max_physics_steps_per_frame = _restore_limit
		_restore_hz = 0
		_restore_limit = 0
		_recovery_us = 0

func _exit_tree() -> void:
	if _presentation_owner != null:
		get_tree().physics_interpolation = _restore_interpolation
		_presentation_owner.physics_interpolation_mode = _restore_interpolation_mode
		_presentation_owner = null
	_restore()
