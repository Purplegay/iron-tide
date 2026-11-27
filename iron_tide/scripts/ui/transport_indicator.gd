extends RefCounted
## Read-only cargo projection. Never clean up passengers or advance unloading here.
const AmmoIndicator = preload("res://scripts/ui/aircraft_ammo_indicator.gd")
const TEXTURES := {
	"empty": preload("res://assets/ra2/pips/cargo/empty.png"),
	"green": preload("res://assets/ra2/pips/cargo/green.png"),
	"yellow": preload("res://assets/ra2/pips/cargo/yellow.png"),
	"white": preload("res://assets/ra2/pips/cargo/white.png"),
	"red": preload("res://assets/ra2/pips/cargo/red.png"),
	"blue": preload("res://assets/ra2/pips/cargo/blue.png")}
const PIP_SIZE := Vector2(8, 8)
const STRIDE := 9
const COLUMNS := 12

static func state(unit) -> Dictionary:
	if not AlliedAbilities.alive(unit) or unit.side != "ally" or unit.embarked_in != null or not unit.is_visible_in_tree(): return {}
	var logistics: UnitLogistics = unit.logistics
	if logistics.capacity <= 0: return {}
	var slots: Array[String] = []
	var people := 0
	for passenger in logistics.passengers:
		if not AlliedAbilities.alive(passenger) or passenger.embarked_in != unit: continue
		people += 1
		var color := str(AlliedAbilities.source(passenger).get("Pip", "green")).to_lower()
		if not TEXTURES.has(color) or color == "empty": color = "green"
		for i in logistics.passenger_size(passenger):
			if slots.size() >= logistics.capacity: break
			slots.append(color if i == 0 else "white")
	var used := slots.size()
	while slots.size() < logistics.capacity: slots.append("empty")
	return {"slots": slots, "used": used, "capacity": logistics.capacity, "passengers": people}

static func visible_slots(unit) -> Array:
	if not is_instance_valid(unit) or not (unit.selected or unit.hovered): return []
	var info := state(unit)
	if info.is_empty(): return []
	return info.slots

static func screen_origin(unit, canvas: Node2D) -> Vector2:
	# Share the HP/ammo anchor, including aircraft lift, with fixed screen pixels.
	var point := AmmoIndicator.screen_origin(unit, canvas)
	if unit.logistics.ammo_max > 0: point.y += 15.0
	return point

static func paint(unit, canvas: Node2D) -> void:
	var slots := visible_slots(unit)
	if slots.is_empty(): return
	_paint_slots(canvas, screen_origin(unit, canvas), slots)

static func _paint_slots(canvas: Node2D, origin: Vector2, slots: Array) -> void:
	canvas.draw_set_transform_matrix(canvas.get_global_transform_with_canvas().affine_inverse())
	var old_filter := canvas.texture_filter
	canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for i in slots.size():
		var at := origin + Vector2((i % COLUMNS) * STRIDE, (i / COLUMNS) * STRIDE)
		canvas.draw_texture_rect(TEXTURES[slots[i]], Rect2(at, PIP_SIZE), false)
	canvas.texture_filter = old_filter
	Iso.begin(canvas)
