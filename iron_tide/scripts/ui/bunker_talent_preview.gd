extends Control
var rank:=0

func _ready() -> void:
	custom_minimum_size=Vector2(520,230)
	mouse_filter=Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var center:=Vector2(260,102)
	var base:=preload("res://scripts/rules/bunker_talent.gd").base_cells()
	var cells:=preload("res://scripts/rules/bunker_talent.gd").range_cells(rank)
	var color:=Color("#68d8ff")
	draw_set_transform(center,0,Vector2(1,0.5))
	draw_circle(Vector2.ZERO,cells*21,Color(0.2,0.7,1,0.08))
	draw_arc(Vector2.ZERO,base*21,0,TAU,65,Color(0.4,0.5,0.6),1,true)
	draw_arc(Vector2.ZERO,cells*21,0,TAU,65,color,2,true)
	draw_set_transform(Vector2.ZERO)
	var art:=RA2Art.art("NABNKR")
	if art.get("tex")!=null:
		var source:=RA2Art.src_rect(art,0)
		var scale:=minf(140.0/source.size.x,105.0/source.size.y)
		draw_texture_rect_region(art.tex,Rect2(center-source.size*scale*0.5,source.size*scale),source)
	draw_string(ThemeDB.fallback_font,Vector2(18,206),"Lv.%d · 驻军射程 %.2f 格；有人值守时同步扩展视野" % [rank,cells],HORIZONTAL_ALIGNMENT_LEFT,-1,15,color)
