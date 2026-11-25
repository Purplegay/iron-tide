extends RefCounted
## Bomb nests retain their saved Unit carrier, but never render its infantry body or HUD.
const LANDING_ARM := 0.3
const FALL_SECONDS := 0.6

static func handles(unit) -> bool:
	return unit.special.has("expansion_temporary") and unit.special.expansion_temporary.get("kind", "") == "nest"

static func height(unit) -> float:
	var state: Dictionary = unit.special.expansion_temporary
	var remaining := clampf((float(state.get("arm", 0.0)) - LANDING_ARM) / FALL_SECONDS, 0.0, 1.0)
	return float(state.get("drop_height", 100.0)) * remaining

static func draw(unit) -> void:
	var lift := height(unit)
	var armed := float(unit.special.expansion_temporary.get("arm", 0.0)) <= 0.0
	var center := Vector2(0, -lift)
	var projection := Transform2D(Iso.eff_angle(), Iso.up(), 0.0, Vector2.ZERO)
	unit._body_bounds = Rect2(center - Vector2(11, 15), Vector2(22, 22))
	unit.draw_set_transform_matrix(projection)
	# Flattened ground shadow and casing distinguish the landed mine from troops.
	unit.draw_set_transform_matrix(projection * Transform2D(0.0, Vector2(1.0, 0.45), 0.0, Vector2.ZERO))
	unit.draw_circle(Vector2.ZERO, 10.0, Color(0, 0, 0, 0.28))
	unit.draw_set_transform_matrix(projection * Transform2D(0.0, center))
	if lift > 0.0:
		unit.draw_colored_polygon(PackedVector2Array([Vector2(-6,-14),Vector2(6,-14),Vector2(3,-7),Vector2(-3,-7)]), Color("#9a7937"))
		unit.draw_circle(Vector2(0,-4), 7.0, Color("#242a26"))
		unit.draw_line(Vector2(-2,-8), Vector2(-2,0), Color("#a4a68a"), 2.0)
		unit.draw_line(Vector2(-5,-3), Vector2(5,-3), Color("#d9a545"), 2.0)
	else:
		unit.draw_set_transform_matrix(projection * Transform2D(0.0, Vector2(1.0, 0.55), 0.0, Vector2.ZERO))
		unit.draw_circle(Vector2.ZERO, 10.0, Color("#493f2e"))
		unit.draw_circle(Vector2(0,-2), 7.5, Color("#747355"))
		unit.draw_arc(Vector2(0,-2), 7.5, PI, TAU, 12, Color("#b7ad7b"), 1.0)
		unit.draw_set_transform_matrix(projection)
		unit.draw_rect(Rect2(-3,-4,6,3), Color("#30372d"))
		unit.draw_circle(Vector2(0,-3), 1.5, Color("#e35b36") if armed else Color("#edc15d"))
	if unit.selected or unit.hovered:
		unit.draw_arc(Vector2.ZERO, 12.0, 0, TAU, 24, Color("#dac678"), 1.0)
	unit.draw_set_transform_matrix(projection)
