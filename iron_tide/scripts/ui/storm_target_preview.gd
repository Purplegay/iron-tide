extends RefCounted
const Clouds = preload("res://scripts/world/storm_clouds.gd")
const COLOR := Color(0.55,0.75,1.0,0.95)

static func footprint(world, point: Vector2) -> Rect2:
	var source = world._armed_superweapon
	if world.command_mode!="superweapon" or not world.owns_superweapon(source) or not source.sw_ready() or source.sw_type()!="LightningStorm" or not point.is_finite(): return Rect2()
	# Cloud centres occupy an n-by-n cell square, not a circular n-cell radius.
	var cells := maxi(1,int(source.superweapon.get("storm",{}).get("cell_spread",10)))
	var size := Vector2.ONE * cells * Clouds.CELL
	return Rect2(point-size*0.5,size)

static func draw(canvas: CanvasItem, world, point: Vector2) -> void:
	var area := footprint(world,point)
	if not area.has_area(): return
	var boundary := PackedVector2Array()
	for corner: Vector2 in [area.position,Vector2(area.end.x,area.position.y),area.end,Vector2(area.position.x,area.end.y)]:
		boundary.append(Iso.dir(corner))
	canvas.draw_colored_polygon(boundary,Color(COLOR,0.12))
	Iso.outline(canvas,boundary,Color(0.04,0.07,0.16,0.85),4.0)
	Iso.outline(canvas,boundary,COLOR,2.0)
	var center := Iso.dir(point)
	canvas.draw_line(center-Vector2(9,0),center+Vector2(9,0),COLOR,2.0,true)
	canvas.draw_line(center-Vector2(0,9),center+Vector2(0,9),COLOR,2.0,true)
	canvas.draw_string_outline(ThemeDB.fallback_font,center+Vector2(14,-14),"闪电风暴 · 落雷区域",HORIZONTAL_ALIGNMENT_LEFT,-1,14,3,Color(0.02,0.04,0.08,0.9))
	canvas.draw_string(ThemeDB.fallback_font,center+Vector2(14,-14),"闪电风暴 · 落雷区域",HORIZONTAL_ALIGNMENT_LEFT,-1,14,COLOR)
