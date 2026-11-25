extends RefCounted

static func duration(rank:int) -> float:
	return 12.0 if rank==1 else 16.0

static func sample(rank:int,t:float) -> Dictionary:
	var clock:=fposmod(t,duration(rank))
	if rank==1:
		var distance:=2.8-clampf(clock,0,2)*.65+clampf(clock-6,0,2)*.65
		var blocked:=clock>=4 and clock<5
		return {"time":clock,"distance":distance,"blocked":blocked,"visible":distance<=2 and not blocked,"sub_visible":false}
	var part:=int(clock/8);var local:=clock-part*8
	var rounds:=clampi(int(local),0,6)
	var extra:=floori(rounds/3.0) if part==0 else 0
	return {"time":local,"part":part,"rounds":rounds,"extra":int(extra),"secondary":part==0,
		"firing":local>=1 and local<6.25 and fmod(local,1)<.25,"split":part==0 and (local>=3 and local<3.25 or local>=6 and local<6.25)}

static func draw(view,width:float,rank:int) -> void:
	var s:=sample(rank,view.elapsed)
	if rank==1:draw_detection(view,width,s);return
	var a:=Vector2(width*.24,96);var b:=Vector2(width*.65,96);var other:=b+Vector2(62,-20)
	view._text(Vector2(8,22),"双枪分击 · 每第三轮追加一枪" if s.secondary else "双枪分击 · 只有主目标时不追加",UiKit.COL_GOLD)
	view._text(Vector2(8,42),"按轮次展示，动作时间为示意；追加枪不是新一轮双枪。",UiKit.COL_DIM)
	view._sprite("TANY",a,1.2)
	view._sprite("E2",b,1.1,false,Color.WHITE,2)
	if s.secondary:view._sprite("E2",other,1.1,false,Color.WHITE,2)
	if s.firing:
		for offset in [-2,2]:view.stage.draw_line(a+Vector2(0,-16+offset),b+Vector2(0,-16+offset),Color.GOLD,1.5)
	if s.split:view.stage.draw_line(a+Vector2(0,-16),other+Vector2(0,-16),Color.CYAN,2)
	view._text(a+Vector2(-52,30),"普通开火第%d轮"%s.rounds,UiKit.COL_OK)
	view._text(b+Vector2(-36,30),"主目标",UiKit.COL_DIM)
	if s.secondary:view._text(other+Vector2(-35,-33),"1格内副目标",UiKit.COL_DIM)
	view._text(Vector2(8,144),"已追加%d枪 · 每枪40%%攻击力 · 不递归"%s.extra if s.secondary else "已追加0枪 · 不向主目标补发额外伤害",Color.CYAN)

static func draw_detection(view,width:float,s:Dictionary) -> void:
	var a:=Vector2(width*.35,80)
	var target:=a+Vector2(s.distance*22.5,0)
	view._text(Vector2(8,22),"近距识破 · 两格内地面反隐，受实体遮挡限制",UiKit.COL_GOLD)
	view._text(Vector2(8,42),"进入范围 → 遮挡 → 遮挡移除 → 离开范围",UiKit.COL_DIM)
	view.stage.draw_arc(a,45,0,TAU,40,Color.CYAN,1.2)
	view._sprite("TANY",a,1.2)
	view._sprite("SPY",target,1.0,false,Color(1,1,1,1 if s.visible else .2))
	if s.blocked:view.stage.draw_rect(Rect2(a+Vector2(14,-19),Vector2(7,37)),Color.GRAY)
	view._text(target+Vector2(25,2),"已识破" if s.visible else "被遮挡" if s.blocked else "范围外",UiKit.COL_OK if s.visible else UiKit.COL_DIM)
	view._text(target+Vector2(25,21),"距离 %.1f格"%s.distance,UiKit.COL_DIM)
	var sub:=a+Vector2(-25,25)
	view._sprite("SUB",sub,.35,false,Color(1,1,1,.2))
	view._text(Vector2(8,144),"潜艇在范围内仍隐蔽：没有获得反潜能力。",UiKit.COL_DIM)
