extends "res://scripts/world/fog_of_war.gd"
func _hold_vacated_scouts(scouts: Dictionary, remaining: float) -> void:
	var _call_log_scope = preload("res://scripts/world/battle_call_counters.gd").enter(42)
	# Small encounters do not amortize creating alliance masks.
	if _scouts.size() < 64:
		for id in _scouts:
			var old: Dictionary = _scouts[id]
			var current: Dictionary = scouts.get(id,{})
			if old == current: continue
			if current.get("side") != old.side: current = {}
			_stamp_sight(old.side,old.point,old.radius,remaining,false,current)
		return
	# Union each scout's OLD minus its OWN current footprint, not union(old)
	# minus union(current): another scout's death must not erase this hold time.
	var masks := {}
	for id in _scouts:
		var old: Dictionary = _scouts[id]
		var current: Dictionary = scouts.get(id, {})
		if old == current or not visible_cells.has(old.side): continue
		if current.get("side") != old.side: current = {}
		var team = BattleRequest.house_teams.get(old.side, old.side)
		if not masks.has(team):
			var mask := Image.create(width, width, false, Image.FORMAT_L8)
			mask.fill(Color.BLACK)
			masks[team] = mask
		SightBatch.raster_vacated(masks[team], width, old, current)
	var deadline := sight_clock + remaining
	for team in masks:
		var bytes: PackedByteArray = masks[team].get_data()
		var indices := PackedInt32Array()
		# Most pixels are empty: native byte search skips those without a script
		# iteration per map cell. L8 masks contain only 0 and 255.
		var index := bytes.find(255)
		while index >= 0:
			indices.append(index)
			index = bytes.find(255, index + 1)
		for side in visible_cells:
			if BattleRequest.house_teams.get(side, side) != team: continue
			var held: Dictionary = sight_until[side]
			var cells: PackedByteArray = visible_cells[side]
			var explored: PackedByteArray = explored_cells[side]
			preload("res://scripts/world/battle_call_counters.gd").iterations(42,indices.size())
			for i in indices:
				held[i] = maxf(deadline, float(held.get(i, 0.0)))
				cells[i] = 1
				explored[i] = 1
			visible_cells[side] = cells
			explored_cells[side] = explored

