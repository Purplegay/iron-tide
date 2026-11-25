extends Control
const Status=preload("res://scripts/ui/unit_status.gd")
var entry:Dictionary={}

func _init() -> void:
	custom_minimum_size=Vector2(28,28)
	mouse_filter=Control.MOUSE_FILTER_STOP

func update_entry(value:Dictionary) -> void:
	entry=value
	tooltip_text=Status.tooltip(entry)
	queue_redraw()

func _draw() -> void:
	if entry.is_empty():return
	var rect:=Rect2(Vector2(1,1),Vector2(26,26))
	draw_rect(rect,Color("#101b26"))
	draw_texture_rect(Status.Icons.texture(str(entry.icon)),rect.grow(-2),false)
	draw_rect(rect,entry.get("col",Color.CYAN),false,1)
	if entry.get("kind","") in ["chrono_left","ivan_bomb"] and float(entry.get("left",0))>0:
		var seconds:="%.1f"%BattleClock.real_seconds(float(entry.left))
		draw_string_outline(ThemeDB.fallback_font,Vector2(2,25),seconds,HORIZONTAL_ALIGNMENT_LEFT,-1,9,3,Color.BLACK)
		draw_string(ThemeDB.fallback_font,Vector2(2,25),seconds,HORIZONTAL_ALIGNMENT_LEFT,-1,9,Color.WHITE)
	if int(entry.get("stacks",-1))>=0:
		var text:=str(entry.stacks)
		draw_string_outline(ThemeDB.fallback_font,Vector2(17,24),text,HORIZONTAL_ALIGNMENT_LEFT,-1,11,3,Color.BLACK)
		draw_string(ThemeDB.fallback_font,Vector2(17,24),text,HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color.WHITE)
