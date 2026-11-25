extends Control
var phase:=0.0
var recast_ready:=true

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_active(false)

func set_active(enabled:bool,ready:=true) -> void:
	visible=enabled
	recast_ready=ready
	set_process(enabled)
	if not enabled:phase=0.0
	queue_redraw()

func _process(delta:float) -> void:
	phase=fposmod(phase+delta*.7,1.0)
	queue_redraw()

func point(t:float) -> Vector2:
	var edge:=fposmod(t,1.0)*4.0
	var extent:=size-Vector2(3,3)
	if edge<1:return Vector2(1.5+extent.x*edge,1.5)
	if edge<2:return Vector2(size.x-1.5,1.5+extent.y*(edge-1))
	if edge<3:return Vector2(size.x-1.5-extent.x*(edge-2),size.y-1.5)
	return Vector2(1.5,size.y-1.5-extent.y*(edge-3))

func _draw() -> void:
	var pulse:=.5+.5*sin(phase*TAU)
	var color:=Color(1,.8,.3) if recast_ready else Color(.35,.75,1)
	var bounds:=Rect2(Vector2(1.5,1.5),size-Vector2(3,3))
	draw_rect(bounds,Color(color,.04+pulse*(.14 if recast_ready else .04)))
	draw_rect(bounds,Color(color,.55+pulse*.4),false,2)
	for i in 20:
		var alpha:=1.0-float(i)/20.0
		draw_line(point(phase-i*.012),point(phase-(i+1)*.012),Color(color,alpha),3,true)
	draw_circle(point(phase),2.2,Color(1,1,.8))
