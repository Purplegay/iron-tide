extends Node2D
## ALL02UMD high bridge art is flattened onto the road plane in the terrain bake.
## Keep the retail underlay and give the deck its own elevated canvas layer.
const Maps = preload("res://scripts/world/native_maps.gd")
const ID := "yr_all02umd"
const SCALE := Maps.CELL / 24.0
const RISE := Vector2(1.5,-1.5) * Maps.CELL # 45 original isometric pixels
var art
var textures := {}
var road := {}
var ends := {}
var gaps := {}
var spans := {}

func height_fraction(y: float, span: Vector2) -> float:
	return clampf(minf(y-span.x,span.y-y)/3.0,0.0,1.0)

func setup(source) -> void:
	art = source
	z_as_relative = false
	z_index = DepthLayers.BRIDGE_DECK
	var row := Maps.data(ID)
	road = row.deck_anchors
	ends = row.deck_entries
	for span: Rect2 in row.bridge_decks:
		var x := roundi(span.position.x/Maps.CELL)
		var start := roundi(span.position.y/Maps.CELL)
		var end := roundi(span.end.y/Maps.CELL)
		var banks := Vector2(start if ends.has(Vector2i(x,start-1)) else -INF,
			end if ends.has(Vector2i(x,end)) else INF)
		for y in range(start,end): spans[Vector2i(x,y)] = banks
	for key: String in art.frames:
		if key.begins_with("BRIDGE1:"): textures[key] = ImageTexture.create_from_image(art.frames[key])

func refresh(broken: Array) -> void:
	gaps.clear()
	var row := Maps.data(ID)
	for cell: Vector2i in row.bridge_section_by_cell:
		if row.bridge_section_by_cell[cell] in broken: gaps[cell] = true
	queue_redraw()

func _draw() -> void:
	for tile: Array in Maps.data(ID).bridges:
		var key: String = art.overlay_key(tile,gaps)
		if key.is_empty(): continue
		var origin := (Vector2(tile[0],tile[1])-Vector2.ONE*3.5)*Maps.CELL
		var span: Vector2 = spans[Vector2i(tile[0],tile[1])]
		# Split at cell boundaries where the ramp slope changes.
		for strip in [0,12,36,60,84,108,132,156,180]:
			var end := mini(192,12 if strip==0 else strip+24)
			var top := origin+Vector2.DOWN*float(strip)*SCALE
			var bottom := origin+Vector2.DOWN*float(end)*SCALE
			var offset := RISE-Vector2.RIGHT*Maps.CELL
			top += offset*height_fraction(top.y/Maps.CELL,span)
			bottom += offset*height_fraction(bottom.y/Maps.CELL,span)
			var width := Vector2.RIGHT*192*SCALE
			var a := float(strip)/192
			var b := float(end)/192
			draw_polygon(PackedVector2Array([top,top+width,bottom+width,bottom]),PackedColorArray([Color.WHITE]),PackedVector2Array([Vector2(0,a),Vector2(1,a),Vector2(1,b),Vector2(0,b)]),textures[key])

func record_move(unit, before: Vector2) -> void:
	var previous := Vector2i((before / Maps.CELL).floor())
	var cell := Vector2i((unit.position / Maps.CELL).floor())
	var on_deck: bool = unit.special.get("hollywood_on_deck", false)
	if on_deck and road.has(previous) and not gaps.has(road[previous]):
		var anchor: Vector2i = road[previous]
		var same_span: bool = road.has(cell) and road[cell].x == anchor.x and spans[road[cell]] == spans[anchor]
		var bank := ends.has(cell) and absi(cell.y - previous.y) == 1 and absi(cell.x - previous.x) <= 1
		if not same_span and not bank:
			# Collision recovery and crowd steering can both push a body toward the rail.
			unit.position = Vector2(before.x, unit.position.y)
			cell = Vector2i((unit.position / Maps.CELL).floor())
			if not road.has(cell) or road[cell].x != anchor.x or spans[road[cell]] != spans[anchor]:
				unit.position = before
				cell = previous
		# Steering can move across several cells before the route is refreshed.
		if not gaps.is_empty() and road.has(cell) and not strip_clear(previous,cell):
			unit.position = before
			cell = previous
	var entering := ends.has(previous) and absi(previous.y-cell.y)==1 and absi(previous.x-cell.x)<=1
	if unit.has_move_order and unit.special.get("hollywood_street_goal",Vector2.INF) == unit.move_target:
		entering = false
	if road.has(cell) and not gaps.has(road[cell]) and (on_deck or entering):
		unit.special.hollywood_on_deck = true
		unit.special.hollywood_deck_fraction = height_fraction(unit.position.y/Maps.CELL,spans[road[cell]])
	else:
		unit.special.erase("hollywood_on_deck")
		unit.special.erase("hollywood_deck_fraction")

func sort_unit(unit) -> bool:
	var cell := Vector2i((unit.position / Maps.CELL).floor())
	if unit.special.has("hollywood_on_deck"):
		if road.has(cell) and not gaps.has(road[cell]):
			unit.z_index = maxi(unit.z_index, DepthLayers.BRIDGE_DECK + 1)
			return false
		unit.special.erase("hollywood_on_deck")
		unit.special.erase("hollywood_deck_fraction")
	var projected := Vector2i(((unit.position-RISE)/Maps.CELL).floor())
	if (road.has(cell) and not gaps.has(road[cell])) or (road.has(projected) and not gaps.has(road[projected])):
		unit.z_index = DepthLayers.BRIDGE_DECK - 1
		return true
	return false

# Invert the same ramp elevation used by the vehicle contact point. The
# projection is monotone along each span, including the clipped map edge.
func pick_deck(point: Vector2) -> Vector2:
	var tiles := point / Maps.CELL
	for y in range(floori(tiles.y), floori(tiles.y + 1.5) + 1):
		for x in range(floori(tiles.x - 1.5), floori(tiles.x) + 1):
			var cell := Vector2i(x,y)
			if not road.has(cell) or gaps.has(cell): continue
			var span: Vector2 = spans[road[cell]]
			var h0 := height_fraction(y,span)
			var h1 := height_fraction(y+1,span)
			var t := (tiles.y - y + 1.5*h0) / (1.0 - 1.5*(h1-h0))
			if t < 0 or t >= 1: continue
			var logical := point - RISE*lerpf(h0,h1,t)
			if floori(logical.x / Maps.CELL) == x: return logical
	return Vector2.INF

func strip_clear(a: Vector2i, b: Vector2i) -> bool:
	if not road.has(a) or not road.has(b) or road[a].x != road[b].x: return false
	for y in range(mini(a.y,b.y),maxi(a.y,b.y)+1):
		var row := Vector2i(road[a].x,y)
		if not road.has(row) or gaps.has(row): return false
	return true

func bank_paths(point: Vector2, elevated: bool) -> Array:
	if not elevated: return [PackedVector2Array([point])]
	var options := []
	var cell := Vector2i((point/Maps.CELL).floor())
	for bank: Vector2i in ends:
		for direction in [Vector2i.UP,Vector2i.DOWN]:
			var entry: Vector2i = bank + direction
			if strip_clear(cell,entry):
				# Leave enough street beyond the portal for the whole vehicle to emerge
				# before reversing direction to climb the approach.
				var mouth := (Vector2(bank)+Vector2.ONE*0.5)*Maps.CELL
				var approach := mouth - Vector2(direction)*Maps.CELL*2.0
				options.append(PackedVector2Array([point,(Vector2(entry)+Vector2.ONE*0.5)*Maps.CELL,mouth,approach]))
	return options

func layered_route(unit, goal: Vector2, elevated: bool, service, blockers: Array) -> PackedVector2Array:
	var start: Vector2 = unit.position
	var riding: bool = unit.special.has("hollywood_on_deck")
	if riding and elevated and strip_clear(Vector2i((start/Maps.CELL).floor()),Vector2i((goal/Maps.CELL).floor())):
		return PackedVector2Array([start,goal])
	var best := PackedVector2Array()
	var cost := INF
	var grid: PackedFloat32Array = service._movement_grid(false,unit.is_amphibious,unit.unit_id=="R3APOC")
	var arrivals := bank_paths(goal,elevated)
	for departure: PackedVector2Array in bank_paths(start,riding):
		if departure.size()>1 and not service.line_walkable(departure[-2],departure[-1],grid): continue
		for arrival: PackedVector2Array in arrivals:
			if arrival.size()>1 and not service.line_walkable(arrival[-2],arrival[-1],grid): continue
			var street: PackedVector2Array = service.find_path(departure[-1],arrival[-1],false,6000,unit.is_amphibious,blockers,unit.unit_id=="R3APOC")
			if street.is_empty() or street[-1].distance_to(arrival[-1])>1.0: continue
			var route := departure.duplicate()
			route.append_array(street.slice(1))
			for i in range(arrival.size()-2,-1,-1): route.append(arrival[i])
			var length := 0.0
			for i in range(1,route.size()): length += route[i-1].distance_to(route[i])
			if length < cost:
				cost = length
				best = route
	return best
