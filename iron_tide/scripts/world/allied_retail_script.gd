extends RefCounted
## Retail trigger slice used by campaign-specific battle adapters.
## Drive with simulation seconds. Advance returns one durable world command at a time.
## An adapter must execute the command and acknowledge its token before advancing.

const DATA = preload("res://data/ra2/allied_script_slice.json")
const SCHEMA := 1

var definition: Dictionary = {}
var rows: Dictionary = {}
var state: Dictionary = {}

func start(map_id: String, difficulty: int) -> bool:
	if not DATA.data.has(map_id) or difficulty < 0 or difficulty > 2:
		return false
	definition = DATA.data[map_id]
	rows.clear()
	var enabled := {}
	for row in definition.triggers:
		rows[row.id] = row
		if not row.disabled and row.difficulty[difficulty]:
			enabled[row.id] = 0.0
	state = {"schema": SCHEMA, "map": map_id, "hash": definition.sha256, "difficulty": difficulty,
		"time": 0.0, "enabled": enabled, "locals": definition.locals.duplicate(), "fired": {},
		"active": "", "cursor": 0, "serial": 0, "pending": {}}
	return true

func snapshot() -> Dictionary:
	return state.duplicate(true)

## Resolve only the recorded spawn commands. No generic fallback positions.
func resolve_spawn(command: Dictionary) -> Dictionary:
	if state.is_empty() or state.pending.is_empty() or command != state.pending:
		return {}
	var fields: Array = command.fields
	match int(command.opcode):
		4, 7, 80, 107:
			var team: Dictionary = definition.teams.get(fields[2].to_lower(), {})
			if team.is_empty(): return {}
			var code: String = fields[7] if int(command.opcode) in [80,107] else team.team.waypoint
			var waypoint: Dictionary = definition.waypoints.get(code, {})
			if waypoint.is_empty(): return {}
			return {"kind": "team", "team": team.duplicate(true), "chrono": int(command.opcode) == 107,
				"waypoint": waypoint.duplicate(true)}
		125:
			var waypoint: Dictionary = definition.waypoints.get(fields[7], {})
			if waypoint.is_empty(): return {}
			return {"kind": "building", "type": fields[2], "house": command.house, "waypoint": waypoint.duplicate(true)}
	return {}

func restore(saved: Dictionary) -> bool:
	var saved_difficulty: Variant = saved.get("difficulty", -1)
	if not _valid_number(saved_difficulty) or saved_difficulty > 2 or int(saved_difficulty) != saved_difficulty:
		return false
	var difficulty := int(saved_difficulty)
	var map_id := str(saved.get("map", ""))
	if saved.get("schema") != SCHEMA or not DATA.data.has(map_id):
		return false
	if saved.get("hash") != DATA.data[map_id].sha256:
		return false
	for key in ["enabled", "locals", "fired", "pending"]:
		if not saved.get(key) is Dictionary:
			return false
	for key in ["active", "cursor", "serial", "time"]:
		if not saved.has(key):
			return false
	var candidate: Dictionary = DATA.data[map_id]
	var active_row := {}
	var ids := {}
	for row in candidate.triggers:
		ids[row.id] = true
		if row.id == saved.active:
			active_row = row
	for id in saved.enabled:
		if not ids.has(id) or not _valid_number(saved.enabled[id]) or float(saved.enabled[id]) > float(saved.time):
			return false
	for id in saved.fired:
		if not ids.has(id) or saved.fired[id] != true:
			return false
	for id in saved.locals:
		if not candidate.locals.has(id) or not saved.locals[id] is bool:
			return false
	if saved.locals.size() != candidate.locals.size() or not _valid_number(saved.time) or not _valid_number(saved.serial) or int(saved.serial) != saved.serial or not _valid_number(saved.cursor) or int(saved.cursor) != saved.cursor:
		return false
	var cursor := int(saved.cursor)
	var canonical_pending := {}
	if saved.active == "":
		if cursor != 0 or not saved.pending.is_empty():
			return false
	elif active_row.is_empty() or not saved.fired.has(saved.active) or cursor > active_row.actions.size():
		return false
	elif not saved.pending.is_empty():
		if cursor == 0 or int(saved.serial) < 1:
			return false
		canonical_pending = _command(active_row, active_row.actions[cursor-1], int(saved.serial))
		var pending: Dictionary = saved.pending.duplicate()
		for key in ["token", "opcode"]:
			if not _valid_number(pending.get(key)) or int(pending[key]) != pending[key]:
				return false
			pending[key] = int(pending[key])
		if pending != canonical_pending:
			return false
	start(map_id, difficulty)
	state = saved.duplicate(true)
	state.pending = canonical_pending
	return true

func _valid_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= 0.0

func acknowledge(token: int) -> bool:
	if state.is_empty() or state.pending.is_empty() or token != int(state.pending.token):
		return false
	state.pending = {}
	return true

## Used by the future battle adapters for incoming retail trigger links, e.g. Final_Camera_Set.
func enable(id: String) -> bool:
	id = id.to_lower()
	if not rows.has(id) or not rows[id].difficulty[int(state.difficulty)]:
		return false
	if state.fired.has(id):
		# ALL01 repeatable plant-tag chains explicitly re-enable these checks after a later pair.
		var name: String = rows[id].name
		if state.map != "yr_all01umd" or state.active == id or not ("_Group_Done_" in name or name.begins_with("Check_PP")):
			return false
		state.fired.erase(id)
	if not state.enabled.has(id):
		state.enabled[id] = state.time
	return true

func set_local(id: int, value: bool) -> bool:
	var key := str(id)
	if state.is_empty() or not state.locals.has(key):
		return false
	state.locals[key] = value
	return true

## `query` receives (trigger row, raw retail event fields) for world events.
## Return true only when the retail predicate is known to hold. No adapter = blocked.
## Optional per-row delays let an adapter replace a retail cinematic timer with its own completion gate.
func advance(seconds: float, query := Callable(), row_gate := Callable(), timer_overrides := {}) -> Dictionary:
	if state.is_empty():
		return {}
	if not state.pending.is_empty():
		return state.pending.duplicate(true)
	if state.active == "" and is_finite(seconds) and seconds > 0.0:
		state.time = float(state.time) + seconds
	while true:
		if state.active == "":
			for row in definition.triggers:
				if not state.enabled.has(row.id) or state.fired.has(row.id):
					continue
				if row_gate.is_valid() and row_gate.call(row) != true: continue
				if _ready_to_fire(row, query, timer_overrides):
					state.active = row.id
					state.fired[row.id] = true
					break
			if state.active == "":
				return {}
		var row: Dictionary = rows[state.active]
		while int(state.cursor) < row.actions.size():
			var action: Array = row.actions[int(state.cursor)]
			state.cursor = int(state.cursor) + 1
			if _internal(action):
				continue
			state.serial = int(state.serial) + 1
			state.pending = _command(row, action, int(state.serial))
			return state.pending.duplicate(true)
		state.enabled.erase(state.active)
		state.active = ""
		state.cursor = 0
	return {} # Unreachable; keeps the return type explicit.

func _ready_to_fire(row: Dictionary, query: Callable, timer_overrides: Dictionary) -> bool:
	if row.events.is_empty():
		return false
	for event: Array in row.events:
		match int(event[0]):
			13:
				var delay := float(timer_overrides.get(row.id, event[2]))
				if float(state.time) - float(state.enabled[row.id]) + 0.000000001 < delay: return false
			36, 37:
				if not state.locals.has(event[2]) or state.locals[event[2]] != (int(event[0]) == 36): return false
			47:
				if float(state.time) < float(event[2]): return false
			_:
				if not query.is_valid() or query.call(row.duplicate(true), event.duplicate()) != true: return false
	return true

func _internal(action: Array) -> bool:
	var op := int(action[0])
	match op:
		0: return true
		53, 54:
			var target: String = action[2].to_lower()
			if not rows.has(target): return false
			if op == 53:
				if state.map=="yr_all07smd" and target!=state.active and target in ["0960d93c","0464c5fc","0b7ae1ec","0b2e9edc","0b829cac","09713f3c","0b8000cc","0b80c2bc","0b82737c","0b807b1c","079b37cc"]:
					state.fired.erase(target)
				enable(target)
			else: state.enabled.erase(target)
			return true
		56, 57: return set_local(int(action[2]), op == 56)
	return false

func _command(row: Dictionary, action: Array, token: int) -> Dictionary:
	return {"token": token, "trigger": row.id, "house": row.house, "opcode": int(action[0]),
		"fields": action.duplicate()}
