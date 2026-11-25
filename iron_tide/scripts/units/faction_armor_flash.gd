extends Node2D
## Transient redraw of the actual hull and turret, independent of house remap or camera rotation.
static var steel: ShaderMaterial

func _ready() -> void:
	if steel==null:
		steel=ShaderMaterial.new()
		steel.shader=preload("res://shaders/faction_armor_flash.gdshader")
	material=steel

func _process(_dt:float) -> void:
	var unit=get_parent()
	if unit._dead or not unit.special.has("plate_flash"):
		queue_free()
	else:queue_redraw()

func _draw() -> void:
	var unit=get_parent()
	var opacity:=clampf(float(unit.special.get("plate_flash",0.0))/0.22,0,1)*0.8
	var tint:=Color(1,1,1,opacity)
	draw_set_transform_matrix(unit.body_draw_transform())
	if unit._ra3_model!=null:
		var model=unit._ra3_model
		draw_texture_rect(model.viewport.get_texture(),model.draw_rect,false,tint)
	elif unit._art_frame>=0 and not unit._ra2.is_empty():
		var dest:=RA2Art.draw_rect(unit._ra2,unit.radius,unit._art_aframes,unit._art_lift,unit._art_sc)
		draw_texture_rect_region(unit._ra2.tex,dest,RA2Art.src_rect(unit._ra2,unit._art_frame),tint)
		if unit._turret_draw_rect.has_area():
			draw_texture_rect_region(unit._ra2_tur.tex,unit._turret_draw_rect,unit._turret_draw_source,tint)
