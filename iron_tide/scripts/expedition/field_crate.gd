extends Node2D
## Yuri's Revenge ground crate, CRATE.TEM frame 0 with the ISOTEM.PAL palette.
const ART:=preload("res://assets/maps/yr/field_crate.png")
var missions
var objective:Dictionary
var pulse:=0.0

func setup(owner_missions,mission:Dictionary) -> void:
	missions=owner_missions
	objective=mission
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST

func _physics_process(_delta:float) -> void:
	if not missions.world.paused and not missions.world.ended and objective.phase=="open":
		missions.try_pick_box(objective)

func _process(delta:float) -> void:
	if objective.done or objective.failed:
		hide()
		queue_free()
		return
	if not missions.world.paused:
		pulse=fposmod(pulse+BattleClock.control_delta(delta),1.2)
	queue_redraw()

func _draw() -> void:
	if objective.done or objective.failed:return
	var carrying:bool=objective.phase=="carry"
	var holder=missions.box_holder(objective.id) if carrying else null
	var canvas:=get_global_transform_with_canvas()
	var point:Vector2=holder.position if holder!=null else objective.cargo
	var anchor:=canvas*point
	var extent:=ART.get_size()*(0.75 if holder!=null else 1.15)
	if holder!=null:anchor.y-=36
	var rect:=Rect2(anchor-Vector2(extent.x*0.5,extent.y*0.8),extent)
	draw_set_transform_matrix(canvas.affine_inverse())
	draw_texture_rect(ART,rect,false)
	var frame:=rect.grow(3)
	draw_rect(frame.grow(1),Color("#10232c"),false,3)
	var tint:=Color("#8cdfff").lerp(Color.WHITE,0.5+0.5*cos(TAU*pulse/1.2))
	tint.a=0.68+0.32*cos(TAU*pulse/1.2)
	draw_rect(frame,tint,false,2)
	var title:String=("%s · 携带黑匣子"%holder.display_name) if holder!=null else "黑匣子"
	draw_string(ThemeDB.fallback_font,Vector2(anchor.x-125,rect.position.y-8),title,HORIZONTAL_ALIGNMENT_CENTER,250,14,UiKit.COL_SIDE_MISSION)
