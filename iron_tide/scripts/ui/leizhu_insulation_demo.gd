extends RefCounted

static func sample(t:float) -> Dictionary:
	return {"frozen":t>=1 and t<7,"moving":t>=2 and t<10,"distance":0.0 if t<2 else (t-2)*12 if t<7 else 60+minf(t-7,3)*24,"text":"时空光束维持冻结，擦除进度仍增长" if t<2 else "保持冻结，以50%速度移出维持范围；不能开火／施法" if t<7 else "离开合法维持范围，原生光束解除；恢复正常速度"}

static func draw(view,width:float) -> void:
	var t:float=view.elapsed;var s:=sample(t)
	var caster:=Vector2(width*.18,90);var hero:=Vector2(width*.48+s.distance,90)
	view._text(Vector2(8,22),s.text,UiKit.COL_GOLD)
	view._sprite("CLEG",caster,1.1)
	view._sprite("TTNK",hero,.75,s.moving,Color(.55,.85,1) if s.frozen else Color.WHITE)
	view.stage.draw_line(Vector2(width*.48+60,45),Vector2(width*.48+60,132),UiKit.COL_DIM,1)
	if s.frozen:
		view.stage.draw_line(caster+Vector2(0,-15),hero+Vector2(0,-15),Color.CYAN,2)
		view.stage.draw_arc(hero,34,0,TAU,36,Color.CYAN,2)
		view._text(hero+Vector2(-55,50),"冻结中 · 50%移速",Color.CYAN)
		view._text(Vector2(8,170),"没有移动逃出时，仍会被完整擦除",UiKit.COL_WARN)
	else:view._text(hero+Vector2(-45,50),"正常速度",UiKit.COL_OK)
