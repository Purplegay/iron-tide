extends RefCounted

static func sample(rank:int,t:float) -> Dictionary:
	if rank==4:
		return {"fired":t>=3,"flash":t>=3 and t<3.4,"ready":t>=15,"cooldown":maxf(0,15-t) if t>=3 else 0,"text":"连续停火3秒，准备下一次主电击" if t<3 else "主目标正常受击；沿线最近两个其他目标各受30%电伤" if t<6 else "贯地间隔12秒；额外伤害不触发电荷或夺盾" if t<15 else "停火与间隔均满足，下一发可再次贯地"}
	var inside:=t>=2 and t<10
	var base:=300 if t>=8 and t<10 else 50
	var drain:=250 if t>=6 and t<10 else 120
	var extra:=100 if inside and base<drain else 0
	return {"inside":inside,"base":base,"drain":drain,"extra":extra,"total":base+extra,"low":base+extra<drain,"text":"进入己方建造场8格内，缺电时供电+100" if t<2 else "基础仍缺电，补足后持续供电，不反复断供" if t<6 else "缺口超过100，供电仍不足，用电建筑继续停机" if t<8 else "电厂恢复充足，英雄自动停止供电" if t<10 else "离开基地范围，立即撤销英雄供电"}

static func draw(view,width:float) -> void:
	var rank:int=view.levels.selected;var t:float=view.elapsed
	var state:=sample(rank,t)
	view._text(Vector2(8,22),state.text,UiKit.COL_GOLD)
	if rank==4:
		var a:=Vector2(width*.12,88);var b:=Vector2(width*.88,88)
		view._sprite("TTNK",a,.65)
		view._sprite("HTNK",b,.6,false,Color(.95,.6,.6))
		for i in 3:
			var p:=a.lerp(b,.24+i*.23)
			view._sprite("HTNK",p,.5,false,Color(.95,.6,.6))
			view._text(p+Vector2(-30,45),"30%电伤" if state.fired and i<2 else "无额外伤害" if state.fired else "沿线目标",Color.CYAN if state.fired and i<2 else UiKit.COL_DIM)
		if state.flash:
			view.stage.draw_line(a+Vector2(0,-20),b+Vector2(0,-20),Color.WHITE,2)
			view.stage.draw_line(a,a.lerp(b,.47),Color.CYAN,4)
		view._text(a+Vector2(-25,65),"已就绪" if state.ready else "准备 %.1f/3秒"%minf(t,3) if not state.fired else "贯地间隔 %.1f秒"%state.cooldown,UiKit.COL_OK)
		view._text(b+Vector2(-30,45),"主目标",UiKit.COL_DIM)
	else:
		var center:=Vector2(width*.32,88)
		view.stage.draw_arc(center,76,0,TAU,48,UiKit.COL_DIM,1)
		view._sprite("NACNST",center,.4)
		var hero:=center+Vector2(55 if state.inside else 130,32)
		view._sprite("TTNK",hero,.65,state.inside)
		var tower:=Vector2(width*.83,88)
		view._sprite("TESLA",tower,.5,false,Color(.45,.45,.45) if state.low else Color.WHITE)
		if state.extra>0:
			view.stage.draw_arc(hero,27,0,TAU,32,Color.GOLD,2)
			view.stage.draw_line(hero,center,Color.CYAN,2)
		view._text(Vector2(8,158),"基础 %d + 英雄 %d = 供电 %d / 用电 %d"%[state.base,state.extra,state.total,state.drain],Color.CYAN)
		view._text(tower+Vector2(-30,45),"缺电停机" if state.low else "正常运转",UiKit.COL_WARN if state.low else UiKit.COL_OK)
