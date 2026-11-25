extends RefCounted
# Frozen pre-optimization ore marker query.
var battle: Battle
var _ore_signature := PackedInt64Array()
var _ore_projection := Transform2D.IDENTITY
var _ore_marks: Array = []
func _refresh_ore_marks(projection: Transform2D) -> void:
	# Fog changes anywhere used to recluster every ore cell. First compare only
	# the inputs that affect radar marks; harvesting a nonempty cell is unchanged.
	var signature := PackedInt64Array()
	var sources: Array = []
	var seen_states: Array[bool] = []
	var fog = battle.fog
	var explored: PackedByteArray = fog.explored_cells.get("ally",PackedByteArray()) if fog!=null else PackedByteArray()
	var visible_cells: PackedByteArray = fog.visible_cells.get("ally",PackedByteArray()) if fog!=null else PackedByteArray()
	for rn in battle.get_tree().get_nodes_in_group("resource_nodes"):
		if not is_instance_valid(rn): continue
		var seen := true
		if fog!=null:
			var index: int=fog._index(rn.global_position)
			if index<0 or index>=explored.size() or explored[index]==0:continue
			seen=index<visible_cells.size() and visible_cells[index]!=0
		if seen and rn.is_empty(): continue
		signature.append(rn.get_instance_id())
		signature.append(1 if seen else 0)
		sources.append(rn)
		seen_states.append(seen)
	if signature == _ore_signature and projection.is_equal_approx(_ore_projection): return
	_ore_signature = signature
	_ore_projection = projection
	_ore_marks.clear()
	var bins := {}
	for source_index in sources.size():
		var rn = sources[source_index]
		var seen: bool = seen_states[source_index]
		var p: Vector2 = projection * rn.global_position
		var cell := Vector2i((p / 5.0).floor())
		var match_index := -1
		# Preserve the original first matching mark, including cross-bin edges.
		# Avoid comparing each ore cell with every distant cluster on the map.
		for y in range(cell.y-1,cell.y+2):
			for x in range(cell.x-1,cell.x+2):
				for i:int in bins.get(Vector2i(x,y),[]):
					if (match_index < 0 or i < match_index) and p.distance_squared_to(_ore_marks[i]["p"]) < 25.0:
						match_index = i
		if match_index >= 0:
			_ore_marks[match_index]["n"] = int(_ore_marks[match_index]["n"]) + 1
			_ore_marks[match_index]["seen"] = _ore_marks[match_index]["seen"] or seen
		else:
			if not bins.has(cell): bins[cell] = []
			bins[cell].append(_ore_marks.size())
			_ore_marks.append({ "p": p, "n": 1, "seen": seen })
