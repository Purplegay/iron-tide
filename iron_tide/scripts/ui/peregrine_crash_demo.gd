extends RefCounted
const LENGTH=188.0
const TITLES=["自动返修","提前维修","机体被毁","179秒介入","同时完成"]

static func sample(t:float,case_id:int) -> Dictionary:
	var clock:=fposmod(t,LENGTH)
	var recovery:=7.0 if case_id==1 else 182.0
	var start:=2.0 if case_id==1 else 181.0 if case_id==3 else 177.0
	var dead:=case_id==2 and clock>=6
	var repaired:=case_id!=2 and clock>=recovery
	var wreck:=clock>=2 and not dead and not repaired
	var hp:=100.0 if clock<1 or repaired else 0.0 if dead else 800.0 if case_id==2 and clock>=1.5 else 1000.0
	return {"time":clock,"dead":dead,"repaired":repaired,"wreck":wreck,"hp":hp,"max_hp":100.0 if clock<1 or repaired else 1000.0,
		"left":maxf(0,182-clock) if wreck else 0.0,"repair":clampf(clock-start,0,5) if wreck and case_id in [1,3,4] else 0.0,
		"engineer":case_id in [1,3,4] and clock>=start,"cancelled":case_id==3 and repaired,"completions":1 if repaired else 0,
		"ammo":mini(4,int((clock-recovery)/8)) if repaired else 4 if clock<1 else 0,
		"lift":minf(25,(clock-recovery)*25) if repaired else 25 if clock<1 else maxf(0,25*(2-clock)) if clock<2 else 0.0}

static func caption(t:float) -> String:
	var clock:=fposmod(t,LENGTH)
	if clock<1:return "等待普通致命伤 · 五个独立对照"
	if clock<2:return "迫降触发即获十倍耐久 · 下降正常承伤，落地不回满"
	if clock>=181 and clock<182:return "自动返修对照：落地179秒保存／恢复，仍只剩%.1f秒，不重置180秒"%(182-clock)
	return "自动返修倒计时 %.1f秒 · 落地后开始计时"%(182-clock) if clock<182 else "自动返修已结束 · 已毁机体仍不复活，修复只执行一次"

static func draw(view,width:float) -> void:
	view._text(Vector2(8,22),"迫降返修 · 正常最大生命100，触发立即获得耐久1000",UiKit.COL_GOLD)
	for i in 5:
		var s:=sample(view.elapsed,i);var x:float=(i+.5)*width/5
		var at:=Vector2(x,94)
		view._text(Vector2(x-42,43),TITLES[i],UiKit.COL_DIM)
		if s.dead:
			view.stage.draw_line(at+Vector2(-12,-22),at+Vector2(12,0),Color.ORANGE,3)
			view.stage.draw_line(at+Vector2(12,-22),at+Vector2(-12,0),Color.ORANGE,3)
		else:view._sprite("ORCA",at-Vector2(0,s.lift),.46,false,Color(.65,.6,.55) if s.wreck else Color.WHITE,2)
		if s.engineer:
			view._sprite("ENGINEER",at+Vector2(28,0),.62)
			if s.wreck:view.stage.draw_line(at+Vector2(28,-9),at,Color.CYAN,1.5)
		if i==2 and s.time>=1.3 and s.time<1.5 or i==2 and s.time>=5.8 and s.time<6:
			view.stage.draw_circle(at-Vector2(0,(1.5-s.time)*50+s.lift if s.time<1.5 else (6-s.time)*50),3,Color.ORANGE)
		view._text(Vector2(x-40,110),"血%d/%d"%[s.hp,s.max_hp],UiKit.COL_OK if not s.dead else Color.ORANGE)
		var status:="等待迫降" if s.time<1 else "过渡可受伤" if s.time<2 else "永久被毁" if s.dead else "修复1次 弹%d"%s.ammo if s.repaired else "维修%.1f/5"%s.repair if s.engineer else "返修%.0f秒"%s.left
		view._text(Vector2(x-44,126),status,Color.CYAN)
	view._text(Vector2(8,142),"自动返修：179秒存档恢复只余1秒；其余四种对照独立" if view.elapsed>=181 and view.elapsed<182 else "工程师保留；179秒介入会被自动修复中止，不能重复修复",UiKit.COL_DIM)
