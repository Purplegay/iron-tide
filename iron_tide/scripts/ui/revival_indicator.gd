extends RefCounted
## Read the saved combat timer; presentation never advances or resets revival.
static func caption(left:float) -> String:
	return "复活倒计时 %.1f 秒" % (ceilf(maxf(0.0,left)*10.0)/10.0)

static func state(unit) -> Dictionary:
	if not is_instance_valid(unit) or not AlliedAbilities.alive(unit) or not unit.special.has("hero_wreck"):return {}
	var left:=maxf(0.0,float(unit.special.hero_wreck.get("left",0)))
	if unit.special.has("peregrine"):
		var wreck:Dictionary=unit.special.hero_wreck
		if float(wreck.get("descent",0))>0:return {"text":"迫降中 · 仍可受伤","left":wreck.descent,"progress":1.0-float(wreck.descent)}
		return {"text":"返修 %.1f 秒 · 工程师 %.1f/5 秒"%[ceilf(left*10)/10,float(wreck.get("repair_elapsed",0))],"left":left,"progress":clampf(1-left/180.0,0,1)}
	return {"text":caption(left),"left":left,"progress":clampf(1.0-left/Unit.TankHero.REVIVE_SECONDS,0,1)}

static func paint(unit,canvas:Node2D) -> void:
	var info:=state(unit)
	if info.is_empty() or not preload("res://scripts/ui/healing_indicator.gd").eligible(unit):return
	var center:=screen_center(unit,canvas)
	var font:=ThemeDB.fallback_font
	var text:String=info.text
	var width:=maxf(134.0,font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x+16)
	var rect:=Rect2((center-Vector2(width*0.5,13)).round(),Vector2(width,28))
	canvas.draw_set_transform_matrix(canvas.get_global_transform_with_canvas().affine_inverse())
	canvas.draw_rect(rect,Color(0.02,0.07,0.10,0.95))
	canvas.draw_rect(rect,Color(0.25,0.8,1),false,1)
	canvas.draw_string(font,rect.position+Vector2(8,18),text,HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color(0.6,0.95,1))
	canvas.draw_rect(Rect2(rect.position+Vector2(2,25),Vector2((width-4)*float(info.progress),2)),Color(0.3,0.9,1))
	Iso.begin(canvas)

static func screen_center(unit,canvas:Node2D) -> Vector2:
	var camera:Camera2D=unit.get_viewport().get_camera_2d()
	var zoom:float=camera.zoom.x if camera!=null else 1.0
	var bar:Rect2=unit.hp_bar_rect()
	# Keep the label centered over the same art-bound anchor as the health bar.
	return canvas.get_global_transform_with_canvas()*canvas.to_local(unit.global_position)+bar.get_center()*zoom-Vector2(0,26)
