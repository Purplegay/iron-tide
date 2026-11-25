extends RefCounted
const LENGTH=44.0

static func sample(t:float) -> Dictionary:
	var clock:=fposmod(t,LENGTH);var part:=int(clock/22);var local:=clock-part*22
	var ammo:=2 if part==1 else 1
	if local>=1:ammo=0 if local<4 else 1 if local<5 else 0 if local<7 else mini(5,1+int((local-7)/3))
	return {"part":part,"time":local,"ammo":ammo,"ready":local<1 or local>=19,"cycle":1 if local>=19 else 0,
		"warning":part==0 and local>=2 and local<2.5,"blast":part==0 and local>=2.5 and local<3,
		"phase":"普通末弹命中→两侧预警0.5秒→各35%爆破" if part==0 and local<4 else "W消耗2发打空，四枚追猎弹均不分束" if part==1 and local<4 else "只补1发再打空：仍是旧周期，不再分束" if local<19 else "真实补满5/5，下一周期分束资格恢复"}

static func draw(view,width:float) -> void:
	var s:=sample(view.elapsed);var t:float=s.time
	var hero:=Vector2(width*.22,86);var target:=Vector2(width*.75,91)
	view._text(Vector2(8,22),"末弹分束 · 普通末弹／W打空独立对照",UiKit.COL_GOLD)
	view._text(Vector2(8,43),s.phase,UiKit.COL_DIM)
	view._sprite("ORCA",hero,.7,false,Color.WHITE,2)
	view._sprite("HTNK",target,.58)
	for sign in [-1,1]:
		var at:=target+Vector2(0,sign*24)
		view._sprite("E2",at,.8,false,Color.WHITE,2)
		if s.warning:view.stage.draw_arc(at,18,0,TAU,28,Color.CYAN,1.5)
		if s.blast:view.stage.draw_circle(at,18,Color(1,.7,.2,.4))
	if s.part==0 and t>=1 and t<2:view.stage.draw_circle(hero.lerp(target,t-1),3,Color.WHITE)
	if s.part==1:
		for i in 4:
			var age:=t-1-i*.2
			if age>=0 and age<1:
				var at:=hero.lerp(target,age)+Vector2(0,sin(age*PI)*(12+i*5)*(1 if i%2==0 else -1))
				view.stage.draw_circle(at,3,Color.GOLD)
			if age>=1 and age<1.15:view.stage.draw_arc(target,12,0,TAU,24,Color.GOLD,2)
	if t>=5 and t<6:view.stage.draw_circle(hero.lerp(target,t-5),3,Color.WHITE)
	view._text(hero+Vector2(-45,35),"弹药 %d/5"%s.ammo,UiKit.COL_OK)
	view._text(Vector2(8,142),"分束资格：%s · 指挥Lv.5，3秒/发，无额外补弹加速"%("可用" if s.ready else "等待补满"),Color.CYAN)
