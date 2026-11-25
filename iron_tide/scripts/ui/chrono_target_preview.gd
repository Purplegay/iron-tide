extends RefCounted
const Chrono = preload("res://scripts/world/chronoshift.gd")
const SOURCE_COLOR := Color(0.35,0.9,1.0,0.95)
const TARGET_COLOR := Color(0.78,0.55,1.0,0.95)

static func areas(world, point:Vector2) -> Dictionary:
	var source=world._armed_superweapon
	if world.command_mode!="superweapon" or not world.owns_superweapon(source) or not source.sw_ready() or source.sw_type().to_lower()!="chronosphere" or not point.is_finite():return {}
	var locked:bool=world._chrono_source_point.is_finite()
	var origin:Vector2=world._chrono_source_point if locked else point
	var size:=Vector2.ONE*Chrono.CELL*3.0
	return {"locked":locked,"source":Rect2(origin-size*0.5,size),
		"target":Rect2(point-size*0.5,size) if locked else Rect2(),
		"can_confirm":not locked or (Rect2(Vector2.ZERO,Vector2.ONE*world.map_size).has_point(point) and world.position_explored_by(source.side,point))}

static func draw(canvas:CanvasItem, world, point:Vector2) -> void:
	var preview:=areas(world,point)
	if preview.is_empty():return
	var source:Rect2=preview.source
	draw_area(canvas,source,SOURCE_COLOR,"已选传送区域 · 3×3" if preview.locked else "选择传送区域 · 3×3")
	if not preview.locked:return
	var target:Rect2=preview.target
	var color:=TARGET_COLOR if preview.can_confirm else Color(1.0,0.3,0.3,0.95)
	canvas.draw_dashed_line(Iso.dir(source.get_center()),Iso.dir(target.get_center()),Color(TARGET_COLOR,0.6),1.5,8.0,true)
	draw_area(canvas,target,color,"传送目的地 · 3×3" if preview.can_confirm else "目的地不可施放")

static func draw_area(canvas:CanvasItem, area:Rect2, color:Color, label:String) -> void:
	var boundary:=PackedVector2Array()
	for corner:Vector2 in [area.position,Vector2(area.end.x,area.position.y),area.end,Vector2(area.position.x,area.end.y)]:boundary.append(Iso.dir(corner))
	canvas.draw_colored_polygon(boundary,Color(color,0.1))
	for i in range(1,3):
		var offset:=Chrono.CELL*i
		canvas.draw_line(Iso.dir(area.position+Vector2(offset,0)),Iso.dir(area.position+Vector2(offset,area.size.y)),Color(color,0.45),1.0,true)
		canvas.draw_line(Iso.dir(area.position+Vector2(0,offset)),Iso.dir(area.position+Vector2(area.size.x,offset)),Color(color,0.45),1.0,true)
	Iso.outline(canvas,boundary,Color(0.03,0.04,0.1,0.9),4.0)
	Iso.outline(canvas,boundary,color,2.0)
	var center:=Iso.dir(area.get_center())
	canvas.draw_line(center-Vector2(7,0),center+Vector2(7,0),color,2.0,true)
	canvas.draw_line(center-Vector2(0,7),center+Vector2(0,7),color,2.0,true)
	var caption:=Iso.dir(area.position)+Vector2(0,-12)
	canvas.draw_string_outline(ThemeDB.fallback_font,caption,label,HORIZONTAL_ALIGNMENT_LEFT,-1,14,3,Color(0.02,0.04,0.08,0.9))
	canvas.draw_string(ThemeDB.fallback_font,caption,label,HORIZONTAL_ALIGNMENT_LEFT,-1,14,color)
