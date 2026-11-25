extends RefCounted
## Retail SHP bridge edges over the original TMP underlay. Rebuild on damage only.
const Maps = preload("res://scripts/world/native_maps.gd")
const ROOT := "res://assets/maps/yr/"
var patches: Array = []
var map_id := ""
var ground: Image
var frames: Dictionary = {}

func prepare(id: String) -> void:
	if map_id == id: return
	map_id = id
	frames.clear()
	var metadata: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT + id + "_bridges.json"))
	ground = (load(ROOT + id + "_bridge_ground.png") as Texture2D).get_image()
	var atlas := (load(ROOT + id + "_bridge_atlas.png") as Texture2D).get_image()
	if ground.is_compressed(): ground.decompress()
	if atlas.is_compressed(): atlas.decompress()
	ground.convert(Image.FORMAT_RGBA8)
	atlas.convert(Image.FORMAT_RGBA8)
	for key: String in metadata.frames:
		var rect: Array = metadata.frames[key]
		frames[key] = atlas.get_region(Rect2i(rect[0], rect[1], rect[2], rect[3]))

static func damaged_name(name: String, before: bool, after: bool) -> String:
	var number := int(name.trim_prefix("LOBRDG"))
	# Bridge heads face opposite banks; their damaged mates are consecutive SHPs.
	if number == 19 and before or number == 21 and after or number == 23 and before or number == 25 and after:
		return "LOBRDG%02d" % (number + 1)
	if number >= 19 or before == after: return name
	var horizontal := number >= 10
	# Missing preceding piece leaves a leading edge; missing following leaves a trailing edge.
	return "LOBRDG%02d" % ((17 if before else 18) if horizontal else (8 if before else 9))

func overlay_key(tile: Array, broken_cells: Dictionary) -> String:
	var cell := Vector2i(tile[0], tile[1])
	var name: String = tile[2]
	var original := name + ":" + str(int(tile[3]))
	# OverlayData 0/2 are usually invisible footprint placeholders, not extra sprites.
	if broken_cells.has(cell) or not frames.has(original): return ""
	var horizontal := preload("res://scripts/world/bridge_sections.gd").native_horizontal(name, Rect2())
	var direction := Vector2i.RIGHT if horizontal else Vector2i.DOWN
	if name in ["BRIDGE1","BRIDGE2","BRIDGEB1","BRIDGEB2"]:
		var before:bool=broken_cells.has(cell-direction)
		var after:bool=broken_cells.has(cell+direction)
		return name+":"+str(7 if before else 8) if before!=after else original
	var replacement := damaged_name(name, broken_cells.has(cell - direction), broken_cells.has(cell + direction))
	if replacement == name: return original
	for key: String in frames:
		if key.begins_with(replacement + ":"): return key
	push_error("Missing native bridge damage art: " + replacement)
	return original

func rebuild(id: String, broken: Array) -> void:
	patches.clear()
	if broken.is_empty() or not Maps.has(id): return
	prepare(id)
	var row := Maps.data(id)
	var broken_cells := {}
	for cell: Vector2i in row.bridge_section_by_cell:
		if broken.has(row.bridge_section_by_cell[cell]): broken_cells[cell] = true
	var scale := 24.0 / Maps.CELL
	for span: Rect2 in row.bridge_decks:
		if not broken.any(func(section): return span.encloses(section)): continue
		var bounds := Rect2i((span.position * scale).floor() - Vector2.ONE * 96, (span.size * scale).ceil() + Vector2.ONE * 192)
		bounds = bounds.intersection(Rect2i(Vector2i.ZERO, ground.get_size()))
		var patch := ground.get_region(bounds)
		# Same order and projection as native_maps.py. Include nearby bridges if bounds overlap.
		for tile: Array in row.bridges:
			var key := overlay_key(tile, broken_cells)
			if key.is_empty(): continue
			var origin := Vector2i((float(tile[0]) - 3.5) * 24, (float(tile[1]) - 3.5) * 24)
			var image: Image = frames[key]
			if not bounds.intersects(Rect2i(origin, image.get_size())): continue
			patch.blend_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), origin - bounds.position)
		patches.append({"texture": ImageTexture.create_from_image(patch), "rect": Rect2(Vector2(bounds.position) / scale, Vector2(bounds.size) / scale)})
