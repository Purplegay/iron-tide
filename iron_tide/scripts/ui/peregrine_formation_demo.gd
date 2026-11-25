extends RefCounted
const LENGTH=48.0

static func sample(t:float) -> Dictionary:
	var clock:=fposmod(t,LENGTH);var part:=int(clock/12);var local:=clock-part*12
	var wreck:=part==0 and local>=2 and local<8
	var empty:=part>0 and local>=1 and local<4
	var other:=.1 if part==3 else 0.0
	var base:=(1.0 if part==1 else 1.15)+other
	var refill:=9 if part==1 else 5
	return {"part":part,"time":local,"wreck":wreck,"empty":empty,"other":other,"speed":0.0 if wreck else base+(.2 if empty else 0),
		"ally_speed":1.0 if wreck else 1.15,"distance":20*(base*local+.2*clampf(local-1,0,3)),
		"repair":clampf(local-3,0,5) if part==0 else 0.0,"ammo":1 if local<1 else int((local-1)/(8 if part==1 else 4)),"capacity":4 if part==1 else 5,"refill":refill,
		"phase":["领航＋15%→迫降失效→工程师完成5秒维修后恢复","未学领航对照：真实打空后＋20%，持续3秒","已有移动命令：领航15%＋打空20%＝35%，持续3秒","再叠既有10%增益：合计45%，不覆盖其它增益"][part]}

static func draw(view,width:float) -> void:
	var s:=sample(view.elapsed);var t:float=s.time
	view._text(Vector2(8,22),"领航编队 · 配合生存Lv.5迫降返修" if s.part==0 else "领航编队／离场余速 · 独立增益叠加对照",UiKit.COL_GOLD)
	view._text(Vector2(8,43),s.phase,UiKit.COL_DIM)
	var hero:=Vector2(width*.18,88)
	if s.part==0:
		view._sprite("ORCA",hero+Vector2(0,18 if s.wreck else 0),.7,false,Color(.6,.6,.6) if s.wreck else Color.WHITE,2)
		if t>=3 and t<8:view._sprite("ENGINEER",hero+Vector2(42,22),1)
		for i in 2:
			var distance:=8*(1.15*t-.15*clampf(t-2,0,6))
			var at:=Vector2(width*.58+distance,76+i*37)
			view._sprite("ORCA" if i==0 else "BEAG",at,.55,false,Color.WHITE,2,false)
			view._text(at+Vector2(30,5),"+15%" if not s.wreck else "+0%",Color.CYAN)
		view._text(hero+Vector2(-43,44),"迫降机体" if s.wreck else "领航生效",UiKit.COL_OK)
		view._text(Vector2(8,142),"维修 %.1f/5秒 · 远处同方战机直接受益，无需靠近"%s.repair,UiKit.COL_DIM)
		return
	hero.x+=s.distance
	view.stage.draw_line(Vector2(width*.18,105),Vector2(width*.88,105),Color(.25,.35,.4),1)
	view._sprite("ORCA",hero,.7,false,Color.WHITE,2)
	view._text(hero+Vector2(-45,36),"对地弹药 %d/%d"%[s.ammo,s.capacity],UiKit.COL_OK)
	view._text(Vector2(8,64),"当前移速 ×%.2f · 沿原指令继续，不自动返航"%s.speed,Color.CYAN)
	view._text(Vector2(8,142),"余速剩余 %.1f秒；第%d秒补入1发，不等于补满"%[4-t if s.empty else 0,s.refill],UiKit.COL_DIM)
