extends RefCounted
const LENGTH:=30.0

static func sample(time:float) -> Dictionary:
	var t:=fposmod(time,LENGTH)
	var part:=int(t/10)
	var local:=fposmod(t,10)
	var hidden:=local>=2 and local<4 or part<2 and (local>=6 and local<6.5 or local>=8.5)
	var swim:=15. if local>=4 and local<8 else 0.
	var escape:=10. if part==0 and local>=4 and local<7 else 0.
	var hp:=80. if part==0 and local>=4 else 100.
	var swim_left:=maxf(0,8-local) if swim>0 else 0.
	var escape_left:=maxf(0,7-local) if escape>0 else 0.
	var walking:=part==2 and local>=3 and local<5
	var distance:=clampf(local-3,0,2)*28 if part==2 else 0.
	var fired:=part==1 and local>=4 and local<4.15 or part<2 and local>=6.5 and local<6.65
	var title:String=["受伤破隐 · 低级天赋累积生效","主动开火破隐 · 只获得潜泳盾","离水破隐 · 只获得潜泳盾"][part]
	var phase:="水中停火 %.1f / 2秒"%local if local<2 else "已进入潜泳隐形"
	if local>=4:
		phase="先扣20生命，再得潜泳15＋脱离杀线10护盾" if part==0 else "主动开火／离水不扣血，不触发脱离杀线"
	if part<2 and local>=6:phase="再次潜泳 → 6.5秒开火破隐；间隔内不补盾／续时"
	if local>=7 and local<8:phase="脱离杀线3秒盾已到期，潜泳4秒盾仍有效" if part==0 else "潜泳盾未续时 · 剩余 %.1fs"%swim_left
	if local>=8:phase="护盾到期 · 生命不返还；两种触发间隔分别保留"
	return {"time":t,"local":local,"part":part,"hidden":hidden,"swim":swim,"escape":escape,"shield":swim+escape,"hp":hp,
		"swim_left":swim_left,"escape_left":escape_left,"walking":walking,"distance":distance,"fired":fired,"title":title,"phase":phase,
		"swim_cd":maxf(0,19-local) if local>=4 else 0.,"escape_cd":maxf(0,34-local) if part==0 and local>=4 else 0.}

static func label(view,point:Vector2,text:String,color:Color) -> void:
	view.stage.draw_string(ThemeDB.fallback_font,point,text,HORIZONTAL_ALIGNMENT_LEFT,-1,12,color)

static func draw(view,width:float) -> void:
	var s:=sample(view.elapsed)
	var origin:=Vector2(width*.25,81)
	var a:Vector2=origin+Vector2(s.distance,0)
	var b:=Vector2(width*.73,81)
	var water_width:float=origin.x+28-12 if s.part==2 else width-24
	view.stage.draw_rect(Rect2(12,58,water_width,40),Color(.15,.45,.7,.35))
	view._sprite("E2",b,1.1,false,Color.WHITE,2)
	view._sprite("TANY",a,1.25,s.walking,Color(1,1,1,.25 if s.hidden else 1))
	if s.shield>0:view.stage.draw_arc(a-Vector2(0,15),27,0,TAU,32,Color.CYAN,2)
	if s.part==0 and s.local>=4 and s.local<4.15:view.stage.draw_line(b-Vector2(0,15),a-Vector2(0,15),Color.ORANGE,2)
	if s.fired:view.stage.draw_line(a-Vector2(0,15),b-Vector2(0,15),Color.GOLD,2)
	label(view,Vector2(8,15),s.title,UiKit.COL_GOLD)
	label(view,Vector2(8,33),s.phase,UiKit.COL_DIM)
	label(view,Vector2(8,108),"谭雅：生命 %.0f / 100 · 自身护盾 %.0f"%[s.hp,s.shield],UiKit.COL_OK)
	label(view,Vector2(8,126),"潜泳 %.0f（%.1fs）＋脱离杀线 %.0f（%.1fs）"%[s.swim,s.swim_left,s.escape,s.escape_left],Color.CYAN)
	label(view,Vector2(8,144),"触发间隔：潜泳 %.1fs ／ 脱离杀线 %.1fs"%[s.swim_cd,s.escape_cd],UiKit.COL_DIM)
