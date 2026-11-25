extends Unit
var draw_count:=0
var sprites:Array=[]
func _draw() -> void:
	draw_count+=1
	sprites=[]
	_draw_pose()
func draw_body_sprite(art:Dictionary,target:Rect2,source:Rect2,tint:=Color.WHITE,waterline:=INF)->void:
	sprites.append([art.get("key"),target,source,tint,waterline])
	super.draw_body_sprite(art,target,source,tint,waterline)
func signature()->Array:
	return [sprites.duplicate(true),_body_bounds,_art_frame,_pick_body_rect,_turret_draw_rect,_turret_draw_source,_shadow_draw_rect,art_center(),hp_bar_rect()]
