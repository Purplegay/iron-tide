extends Control
## Native Uprising gauge, preserving the complete faction housing and aspect ratio.
const ART := preload("res://assets/ra3/ui/red_alert/experience_panel.png")
var value := 0.0
var soviet := false
# Negative means inactive; only the native left dial displays assault time.
var time_fraction := -1.0
const TIME_SEGMENTS := 24

static func lit_time_segments(fraction: float) -> int:
	return clampi(ceili(clampf(fraction, 0.0, 1.0) * TIME_SEGMENTS), 0, TIME_SEGMENTS)

func _draw_time_ring(origin: Vector2) -> void:
	var center := Vector2(38, 50 if soviet else 41)
	var lit := lit_time_segments(time_fraction)
	for segment in TIME_SEGMENTS:
		var points := PackedVector2Array()
		var uv := PackedVector2Array()
		var start := -PI * 0.5 + TAU * segment / TIME_SEGMENTS + 0.025
		var end := -PI * 0.5 + TAU * (segment + 1) / TIME_SEGMENTS - 0.025
		for radius in [31.0, 20.0]:
			for step in 5:
				var angle := lerpf(start, end, float(step if radius == 31.0 else 4-step) / 4.0)
				var point:Vector2 = center + Vector2.from_angle(angle) * float(radius)
				points.append(point)
				uv.append((origin + point) / Vector2(ART.get_size()))
		var tint := Color(1.5, 1.05, 0.30) if segment < lit else Color(0.22, 0.24, 0.26)
		draw_polygon(points, PackedColorArray([tint]), uv, ART)

func _ready() -> void:
	custom_minimum_size = Vector2(218, 87 if soviet else 77)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

func _draw() -> void:
	# Soviet keeps its original green/brass housing; Allied uses blue/grey.
	# Crop each housing separately: the atlas rows do not share a 94px stride.
	var origin := Vector2(233, 96 if soviet else 186)
	var housing_size := custom_minimum_size
	draw_texture_rect_region(ART, Rect2(Vector2.ZERO, housing_size), Rect2(origin, housing_size))
	if time_fraction >= 0.0:
		_draw_time_ring(origin)
	var fraction := clampf(value / 49000.0, 0.0, 1.0)
	# Only the native glass cells change illumination; the housing stays intact.
	var glass := Rect2(76, 40 if soviet else 29, 122, 22)
	draw_texture_rect_region(ART, glass, Rect2(origin + glass.position, glass.size), Color(0.28, 0.30, 0.32))
	if fraction > 0.0:
		var lit := Rect2(glass.position, Vector2(glass.size.x * fraction, glass.size.y))
		var tint := Color(1.0, 0.85, 0.25) if fraction < 0.408 else Color(1.0, 0.48, 0.12) if fraction < 0.999 else Color(1.0, 0.22, 0.12)
		draw_texture_rect_region(ART, lit, Rect2(origin + lit.position, lit.size), tint * 1.5)
