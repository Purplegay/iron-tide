extends Unit
## Drawing-only stand-in. No setup/AI, registration, collision shapes or orders.
var model_view:SubViewport
var model_rect:Rect2

func _ready() -> void:
	collision_layer=0
	collision_mask=0
	input_pickable=false
	set_physics_process(false)
	set_process(false)

func bind(source, shared_view:SubViewport) -> void:
	data=source.data
	unit_id=source.unit_id
	radius=source.radius
	is_air=source.is_air
	is_harvester=source.is_harvester
	weapon=source.weapon
	_ra2=source._ra2
	_ra2_tur=source._ra2_tur
	_seq=source._seq
	_col=Color.WHITE
	model_view=shared_view
	if model_view!=null:
		model_rect=Rect2(Vector2.DOWN*radius*0.35-source._ra3_model.project(Vector3.ZERO),source._ra3_model.draw_rect.size)

func _visual_lift() -> float:
	return 0.0

func _draw() -> void:
	Iso.begin(self)
	if model_view!=null:
		draw_texture_rect(model_view.get_texture(),model_rect,false)
	elif not _ra2.is_empty():
		var count:=int(_ra2.get("facings",8))
		var facing:=_sprite_facing(_ra2,hull_angle)
		var frame:=facing
		var frames:=range(count)
		if _seq.has("Guard"):
			var guard:Dictionary=_seq.Guard
			facing=RA2Art.facing_index(hull_angle,int(guard.facings))
			frame=RA2Art.seq_frame(_seq,"Guard",facing,0)
			frames=range(int(guard.start),int(guard.start)+int(guard.per)*int(guard.facings))
		var rect:=RA2Art.draw_rect(_ra2,radius,frames,0.0,RA2_SPRITE_SCALE)
		draw_frame(_ra2,rect,frame)
		if not _ra2_tur.is_empty():
			var offset:Array=_ra2_tur.get("draw_offset",[0,0])
			var turret_rect:=Rect2(rect.position+Vector2(offset[0],offset[1])*RA2_SPRITE_SCALE,RA2Art.frame_size(_ra2_tur)*RA2_SPRITE_SCALE)
			draw_frame(_ra2_tur,turret_rect,_sprite_facing(_ra2_tur,turret_angle))
	else:
		_draw_procedural_body(radius)

func draw_frame(art:Dictionary,rect:Rect2,frame:int) -> void:
	var src:=RA2Art.src_rect(art,frame)
	var scale_factor:=float(art.get("detail_scale",1.0))
	draw_texture_rect_region(art.get("detail_tex",art.tex),rect,Rect2(src.position*scale_factor,src.size*scale_factor))
