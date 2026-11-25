extends RefCounted
const ShpDetail=preload("res://tests/next_detail_reference.gd")
static func draw_sprite(canvas: CanvasItem, art_data: Dictionary, target: Rect2, source: Rect2, tint: Color = Color.WHITE, waterline := INF) -> void:
	if ShpDetail.draw(canvas, art_data, target, source, tint, waterline): return
	var texture: Texture2D = art_data.get("detail_tex", art_data.get("tex"))
	if texture == null: return
	var density := float(art_data.get("detail_scale", 1.0))
	ShpDetail.draw_region(canvas,texture,target,Rect2(source.position*density,source.size*density),tint,waterline)
