extends "res://scripts/world/hollywood_overpass.gd"
## Both orientations use the three passable TMP lanes at the wooden bridge heads.
var axes := {}
var tiles: Array
var projected_bounds: Array[Rect2] = []

func setup(source) -> void:
	art = source
	z_as_relative = false
	z_index = DepthLayers.BRIDGE_DECK
	var row := Maps.data(art.map_id)
	road = row.deck_anchors
	ends = row.deck_entries
	tiles = row.bridges
	for bounds: Rect2 in row.bridge_decks:
		var lanes := bounds.grow(Maps.CELL)
		projected_bounds.append(lanes.merge(Rect2(lanes.position+RISE,lanes.size)))
		var first := Vector2i((bounds.position/Maps.CELL).round())
		var axis := Vector2i.RIGHT if row.deck_horizontal.has(first) else Vector2i.DOWN
		var count := roundi(bounds.size.dot(Vector2(axis))/Maps.CELL)
		var start := Vector2(first).dot(Vector2(axis))
		for i in count:
			var anchor := first+axis*i
			axes[anchor] = axis
			spans[anchor] = Vector2(start,start+count)
	for key: String in art.frames:
		if key.begins_with("BRIDGEB"): textures[key] = ImageTexture.create_from_image(art.frames[key])

func refresh(broken: Array) -> void:
	gaps.clear()
	var sections: Dictionary = Maps.data(art.map_id).bridge_section_by_cell
	for tile: Array in tiles:
		var anchor := Vector2i(tile[0],tile[1])
		if sections[anchor] in broken: gaps[anchor] = true
	queue_redraw()

func _draw() -> void:
	for tile: Array in tiles:
		var key: String = art.overlay_key(tile,gaps)
		if key.is_empty(): continue
		var anchor := Vector2i(tile[0],tile[1])
		var origin := (Vector2(anchor)-Vector2.ONE*3.5)*Maps.CELL
		var axis := Vector2(axes[anchor])
		var across := Vector2(axis.y,axis.x)
		for strip in range(0,192,12):
			var end := strip+12
			var uv := PackedVector2Array()
			var points := PackedVector2Array()
			for pixel: Vector2 in [axis*strip,axis*strip+across*192,axis*end+across*192,axis*end]:
				var point := origin+pixel*SCALE
				points.append(point+RISE*fraction(point,anchor))
				uv.append(pixel/192.0)
			draw_polygon(points,PackedColorArray([Color.WHITE]),uv,textures[key])

func fraction(point: Vector2, anchor: Vector2i) -> float:
	return height_fraction(point.dot(Vector2(axes[anchor]))/Maps.CELL,spans[anchor])

func strip_clear(a: Vector2i,b: Vector2i) -> bool:
	if not road.has(a) or not road.has(b): return false
	var first: Vector2i = road[a]
	var last: Vector2i = road[b]
	var axis: Vector2i = axes[first]
	var delta := last-first
	if delta != axis*roundi(Vector2(delta).dot(Vector2(axis))): return false
	var step := delta.sign()
	for i in maxi(absi(delta.x),absi(delta.y))+1:
		var anchor := first+step*i
		if not axes.has(anchor) or gaps.has(anchor): return false
	return true

func record_move(unit,before: Vector2) -> void:
	var previous := Vector2i((before/Maps.CELL).floor())
	var cell := Vector2i((unit.position/Maps.CELL).floor())
	var riding: bool = unit.special.has("hollywood_on_deck") and road.has(previous) and not gaps.has(road[previous])
	if riding:
		var axis := Vector2(axes[road[previous]])
		var exit := ends.has(cell) and cell.distance_squared_to(previous)<=2 and absf(Vector2(cell-previous).dot(axis))==1
		if not exit and not strip_clear(previous,cell):
			unit.position = before+axis*axis.dot(unit.position-before)
			cell = Vector2i((unit.position/Maps.CELL).floor())
			if not strip_clear(previous,cell):
				unit.position = before
				cell = previous
	var entering := ends.has(previous) and road.has(cell) and previous.distance_squared_to(cell)<=2 and absf(Vector2(previous-cell).dot(Vector2(axes[road[cell]])))==1
	if unit.has_move_order and unit.special.get("hollywood_street_goal",Vector2.INF)==unit.move_target: entering = false
	if road.has(cell) and not gaps.has(road[cell]) and (riding or entering):
		unit.special.hollywood_on_deck = true
		unit.special.hollywood_deck_fraction = fraction(unit.position,road[cell])
	else:
		unit.special.erase("hollywood_on_deck")
		unit.special.erase("hollywood_deck_fraction")

func pick_deck(point: Vector2) -> Vector2:
	var grid := point/Maps.CELL
	for y in range(floori(grid.y),floori(grid.y+1.5)+1):
		for x in range(floori(grid.x-1.5),floori(grid.x)+1):
			var cell := Vector2i(x,y)
			if not road.has(cell) or gaps.has(road[cell]): continue
			var anchor: Vector2i = road[cell]
			var axis := Vector2(axes[anchor])
			var start := Vector2(cell).dot(axis)
			# Odd-length short spans crest halfway through the middle cell.
			for half: float in [0.0,0.5]:
				var h0 := height_fraction(start+half,spans[anchor])
				var h1 := height_fraction(start+half+0.5,spans[anchor])
				var rise := RISE.dot(axis)/Maps.CELL
				var t := (grid.dot(axis)-start-half-rise*h0)/(0.5+rise*(h1-h0))
				var logical := point-RISE*lerpf(h0,h1,t)
				if t>=0 and t<1 and Vector2i((logical/Maps.CELL).floor())==cell: return logical
	return Vector2.INF

func bank_paths(point: Vector2,elevated: bool) -> Array:
	if not elevated: return [PackedVector2Array([point])]
	var options := []
	var cell := Vector2i((point/Maps.CELL).floor())
	if not road.has(cell): return options
	var axis: Vector2i = axes[road[cell]]
	for bank: Vector2i in ends:
		for direction: Vector2i in [axis,-axis]:
			var entry := bank+direction
			if strip_clear(cell,entry):
				var mouth := (Vector2(bank)+Vector2.ONE*0.5)*Maps.CELL
				options.append(PackedVector2Array([point,mouth+Vector2(direction)*Maps.CELL,mouth,mouth-Vector2(direction)*Maps.CELL*2]))
	return options

func sort_unit(unit) -> bool:
	var cell := Vector2i((unit.position/Maps.CELL).floor())
	if unit.special.has("hollywood_on_deck"):
		if road.has(cell) and not gaps.has(road[cell]):
			unit.z_index = maxi(unit.z_index,z_index+1)
			return false
		unit.special.erase("hollywood_on_deck")
		unit.special.erase("hollywood_deck_fraction")
	for bounds in projected_bounds:
		if bounds.has_point(unit.position) and pick_deck(unit.position).is_finite():
			unit.z_index = z_index-1
			return true
	return false
