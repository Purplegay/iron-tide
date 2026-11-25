extends RefCounted
## Derived expiry index. Public deadline dictionaries remain authoritative.
## Native dictionary equality detects replacement and untracked external edits.
var table: Dictionary
var shadow: Dictionary = {}
var deadlines: Dictionary = {}
var mask := PackedByteArray()
var legacy_keys := false

func record(source: Dictionary, changed: Array, deadline: float) -> void:
	if not is_same(source, table) or legacy_keys: return
	var indices: Array = deadlines.get_or_add(deadline, [])
	indices.append_array(changed)
	for index in changed:
		shadow[index] = deadline
		mask[index] = 1

func rebuild(source: Dictionary, size: int) -> void:
	table = source
	shadow = source.duplicate()
	deadlines.clear()
	mask.resize(size)
	mask.fill(0)
	legacy_keys = false
	for index in source:
		# Public state can be replaced by loaders/tools. Mixed numeric and string
		# keys may denote the same cell, so retain the reference traversal there.
		if typeof(index) != TYPE_INT: legacy_keys = true
		var deadline := float(source[index])
		var indices: Array = deadlines.get_or_add(deadline, [])
		indices.append(index)
		mask[int(index)] = 1

func expire(source: Dictionary, size: int, clock: float) -> PackedByteArray:
	if not is_same(source, table) or source != shadow or mask.size() != size:
		rebuild(source, size)
	if legacy_keys:
		mask.fill(0)
		preload("res://scripts/world/battle_call_counters.gd").iterations(41, source.size())
		for index in source.keys():
			if clock >= float(source[index]): source.erase(index)
			else: mask[int(index)] = 1
		shadow = source.duplicate()
		return mask.duplicate()
	var visited := 0
	for deadline in deadlines.keys():
		if clock < float(deadline): continue
		visited += deadlines[deadline].size()
		for index in deadlines[deadline]:
			# A newer lease can supersede this pending entry without cancellation.
			if source.has(index) and float(source[index]) <= clock:
				source.erase(index)
				shadow.erase(index)
				mask[int(index)] = 0
		deadlines.erase(deadline)
	preload("res://scripts/world/battle_call_counters.gd").iterations(41, visited)
	return mask.duplicate()
