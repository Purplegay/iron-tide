extends RefCounted
## Read-only battlefield preview; the garrison list remains owned by CivilianOrders.
const CivilianOrders = preload("res://scripts/units/civilian_orders.gd")
const EMPTY = preload("res://assets/ra2/pips/garrison/empty.png")
const OCCUPIED = preload("res://assets/ra2/pips/garrison/occupied.png")
const STRIDE := 8.0 # Twice the four-pixel retail spacing, matching the HUD's pixel scale.

## Returns (occupied, capacity), or zero when the player should see no pips.
static func preview(building) -> Vector2i:
	if not AlliedAbilities.alive(building) or not (building.selected or building.hovered): return Vector2i.ZERO
	if building.under_construction or not building.is_visible_in_tree(): return Vector2i.ZERO
	var capacity := CivilianOrders.slots(building)
	if capacity <= 0: return Vector2i.ZERO
	if not BattleRequest.friendly(building.side, "ally"):
		# A neutral garrison is claimable. Advertise its capacity, never its contents.
		return Vector2i(0, capacity) if building.side == "neutral" and CivilianOrders.civilian_garrison(building) else Vector2i.ZERO
	var occupied := 0
	for passenger in building.special.get("occupants", []):
		if AlliedAbilities.alive(passenger) and passenger.embarked_in == building:
			occupied += 1
	return Vector2i(mini(occupied, capacity), capacity)

static func screen_origin(building, projection: Transform2D, capacity: int) -> Vector2:
	# The building's ground footprint stays aligned with its art at every zoom and angle.
	var left := INF
	var right := -INF
	var bottom := -INF
	var footprint: PackedVector2Array = building.footprint_poly()
	for corner in footprint:
		var at := projection * (Vector2(building.global_position) + corner)
		left = minf(left, at.x)
		right = maxf(right, at.x)
		bottom = maxf(bottom, at.y)
	return Vector2((left + right - (capacity - 1) * STRIDE - EMPTY.get_width()) * 0.5, bottom + 3.0).round()

static func paint(building, canvas: Node2D, projection: Transform2D) -> void:
	var info := preview(building)
	if info.y == 0: return
	var origin := screen_origin(building, projection, info.y)
	canvas.draw_set_transform_matrix(canvas.get_global_transform_with_canvas().affine_inverse())
	for i in info.y:
		canvas.draw_texture(OCCUPIED if i < info.x else EMPTY, origin + Vector2(i * STRIDE, 0))
	Iso.begin(canvas)
