extends RefCounted
const LENGTH=18.0

static func sample(t:float) -> Dictionary:
	var part:=mini(2,int(t/6))
	var local:=t-part*6
	var left:=maxf(0,3-local) if part==0 and local>=1 else maxf(0,4-local) if part==1 else 0.0
	var maintained:=part==2 and local>=1 and local<5
	return {"part":part,"time":local,"left":left,"normal_left":maxf(0,5-local) if local>=1 else 0.0,
		"controlled":left>0 or maintained,"maintained":maintained,"new_left":1.0 if part==1 and local>=1 and local<1.5 else 0.0,
		"title":["抗扰通讯 · 新增计时控制减半","抗扰通讯 · 不缩短已经剩余的控制","抗扰通讯 · 不解除持续时空冻结"][part]}

static func draw(view,width:float) -> void:
	var s:=sample(view.elapsed)
	var t:float=s.time
	var a:=Vector2(width*.25,90)
	var b:=Vector2(width*.72,90)
	view._text(Vector2(8,22),s.title,UiKit.COL_GOLD)
	var hero_walk:bool=not s.controlled and t>=3
	if hero_walk:a.x+=minf(t-(5 if s.part==2 else 4 if s.part==1 else 3),1)*25
	view._sprite("BORIS",a,1.2,hero_walk)
	if s.controlled:view.stage.draw_arc(a+Vector2(0,-15),27,0,TAU,28,Color.CYAN,2)
	view._text(a+Vector2(-58,30),"英雄 · 剩余 %.1f 秒"%s.left if s.part<2 else "持续冻结中" if s.maintained else "尚未维持" if t<1 else "维持中断 · 已解除",Color.CYAN)
	match int(s.part):
		0:
			view._text(Vector2(8,42),"同一次 4 秒计时眩晕：英雄 2 秒，普通鲍里斯 4 秒",UiKit.COL_DIM)
			var normal_walk:bool=t>=5
			if normal_walk:b.x+=minf(t-5,1)*25
			view._sprite("BORIS",b,1.2,normal_walk,Color(.8,.8,.8))
			if s.normal_left>0:view.stage.draw_arc(b+Vector2(0,-15),27,0,TAU,28,Color.ORANGE,2)
			view._text(b+Vector2(-60,30),"普通 · 剩余 %.1f 秒"%s.normal_left,Color.ORANGE)
			view._text(Vector2(8,142),"这是计时控制示例，不是超时空兵的持续射线。",UiKit.COL_DIM)
		1:
			view._text(Vector2(8,42),"先受 8 秒计时控制 → 4 秒；第 1 秒再受 2 秒 → 1 秒",UiKit.COL_DIM)
			view._text(b+Vector2(-84,-10),"旧控制自然倒计时",UiKit.COL_OK)
			view._text(b+Vector2(-84,14),"新控制：2 秒 → 1 秒" if t>=1 else "等待下一次控制",Color.ORANGE)
			if s.new_left>0:view.stage.draw_arc(a+Vector2(0,-15),34,0,TAU,28,Color.ORANGE,2)
			view._text(Vector2(8,142),"取较长剩余时间：原有 3 秒不会被新的 1 秒覆盖。",UiKit.COL_DIM)
		2:
			view._text(Vector2(8,42),"射线保持时持续冻结；第 5 秒攻击者主动停火",UiKit.COL_DIM)
			view._sprite("CLEG",b,1.1,false,Color.WHITE,2)
			if s.maintained:view.stage.draw_line(b+Vector2(0,-18),a+Vector2(0,-18),Color.CYAN,2)
			view._text(b+Vector2(-60,30),"持续维持射线" if s.maintained else "准备攻击" if t<1 else "停止维持",UiKit.COL_OK)
			view._text(Vector2(8,142),"超过 2 秒仍然冻结；持续维持还会推进时空擦除。",UiKit.COL_DIM)
