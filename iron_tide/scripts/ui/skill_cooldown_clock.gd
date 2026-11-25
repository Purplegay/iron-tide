extends Control
## Presentation only: noon -> right -> bottom -> left, using the live cooldown.
var progress:=0.0

static func attach(button:BaseButton,icon_only:bool=false) -> Control:
	var clock=load("res://scripts/ui/skill_cooldown_clock.gd").new()
	clock.name="CooldownClock"
	clock.mouse_filter=Control.MOUSE_FILTER_IGNORE
	button.add_child(clock)
	if icon_only:
		clock.anchor_top=0.5;clock.anchor_bottom=0.5
		clock.offset_left=8;clock.offset_right=40
		clock.offset_top=-16;clock.offset_bottom=16
	else:clock.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	clock.hide()
	return clock

func update_timer(left:float,total:float) -> void:
	var cooling:=left>0.0 and total>0.0
	visible=cooling
	if not cooling:return
	var next:=clampf(1.0-left/total,0.0,1.0)
	if not is_equal_approx(next,progress):
		progress=next
		queue_redraw()

func sweep_angle() -> float:
	return -PI/2.0+TAU*progress

func _draw() -> void:
	var center:=size*0.5
	var radius:=maxf(1.0,minf(size.x,size.y)*0.5-3.0)
	var start:=sweep_angle()
	var remaining:=PackedVector2Array([center])
	for i in 65:
		remaining.append(center+Vector2.from_angle(lerpf(start,PI*1.5,float(i)/64.0))*radius)
	draw_colored_polygon(remaining,Color(0.015,0.025,0.04,0.64))
	draw_arc(center,radius,-PI/2,PI*1.5,65,Color(0.12,0.23,0.29,0.9),2.5,true)
	if progress>0.0:
		draw_arc(center,radius,-PI/2,start,maxi(2,ceili(progress*64)+1),Color(0.35,0.9,1.0),2.5,true)
	draw_circle(center+Vector2.from_angle(start)*radius,1.8,Color(0.85,1.0,1.0))
