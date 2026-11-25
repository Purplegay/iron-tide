extends RefCounted

static func duration(rank:int) -> float:
	return 14.0 if rank==1 else 21.0

static func sample(rank:int,t:float) -> Dictionary:
	var clock:=fposmod(t,duration(rank))
	if rank==1:
		var hits:=0
		for at:float in [1.,2.,3.,5.,6.,7.,9.,10.,11.]:
			if clock>=at:hits+=1
		return {"time":clock,"hits":hits,"suppressed":clock>=3 and clock<4 or clock>=11 and clock<12,
			"cooldown":maxf(0,(11 if clock<11 else 19)-clock) if clock>=3 else 0.0,
			"offset":sin(clock*.6)*20,"hp":100 if clock<3.5 else 90,
			"phase":"三次连续直击同一目标" if clock<3 else "禁火1秒：目标仍移动，既发炮弹继续飞行" if clock<4 else "同目标8秒间隔内，下一组三击不再压制" if clock<9 else "间隔结束后，第三组三击再次压制"}
	var part:=int(clock/7);var local:=clock-part*7
	var charges:=3 if local>=1 and local<5 else 0
	if part==0 and local>=2:charges=maxi(0,4-int(local)) if local<4 else 0
	return {"time":local,"part":part,"charges":charges,"marked":charges>0,
		"visible":part!=2 or local<2 or local>=5.5,"cooldown":maxf(0,13-local) if local>=1 else 0.0,
		"phase":"本人两次命中不耗次数，友兵前三击×1.15、第四击正常" if part==0 else "四秒内未用的次数到期；迟来的友兵攻击正常" if part==1 else "目标进雾不揭雾；重新看见时标记已到期"}

static func draw(view,width:float,rank:int) -> void:
	var s:=sample(rank,view.elapsed);var t:float=s.time
	var hero:=Vector2(width*.18,94);var target:=Vector2(width*.73,94)
	view._text(Vector2(8,22),"步枪压制 · 同目标三击与8秒间隔" if rank==1 else "集火口令 · 三段独立对照，间隔12秒",UiKit.COL_GOLD)
	view._text(Vector2(8,44),s.phase,UiKit.COL_DIM)
	view._sprite("BORIS",hero,1.2)
	if rank==1:
		target.x+=s.offset
		view._sprite("HTNK",target,.6,true,Color.WHITE,6)
		for at:float in [1.,2.,3.,5.,6.,7.,9.,10.,11.]:
			if t>=at-.15 and t<at:view.stage.draw_line(hero-Vector2(0,16),target-Vector2(0,12),Color.GOLD,2)
		if s.suppressed:view.stage.draw_arc(target-Vector2(0,12),30,0,TAU,28,Color.RED,2)
		if t>=2.5 and t<3.5:
			var launch:=Vector2(width*.73+sin(2.5*.6)*20,82)
			view.stage.draw_circle(launch.lerp(hero-Vector2(0,16),t-2.5),3,Color.ORANGE)
		view._text(hero+Vector2(-45,27),"示例生命 %d"%s.hp,UiKit.COL_OK)
		view._text(target+Vector2(-48,27),"禁火，可移动" if s.suppressed else "可移动／开火",Color.ORANGE if s.suppressed else UiKit.COL_OK)
		view._text(Vector2(8,142),"累计命中%d · 目标压制间隔剩余 %.1f 秒"%[s.hits,s.cooldown],Color.CYAN)
		return
	var ally:=Vector2(width*.4,100)
	view._sprite("E2",ally,1.05)
	if s.visible:view._sprite("HTNK",target,.6,false,Color.WHITE,6)
	else:
		view.stage.draw_rect(Rect2(target-Vector2(46,35),Vector2(92,52)),Color(.08,.1,.14))
		view._text(target-Vector2(28,10),"迷雾区域",UiKit.COL_DIM)
	if s.marked and s.visible:view.stage.draw_arc(target-Vector2(0,12),30,0,TAU,28,Color.ORANGE,2)
	for at:float in [1.,1.5]:
		if t>=at-.12 and t<at:view.stage.draw_line(hero-Vector2(0,16),target-Vector2(0,12),Color.GOLD,2)
	for at:float in [2.,3.,4.,4.5] if s.part==0 else [6.]:
		if t>=at-.12 and t<at and s.visible:view.stage.draw_line(ally-Vector2(0,16),target-Vector2(0,12),Color.CYAN,2)
	var shot:="等待命中"
	if s.part==0 and t>=2:shot="本次×1.15" if t<4.5 else "第四击×1.00"
	elif s.part!=0 and t>=6:shot="本次×1.00"
	view._text(ally+Vector2(-42,28),shot,Color.CYAN)
	view._text(hero+Vector2(-42,28),"本人不消耗",UiKit.COL_DIM)
	view._text(target+Vector2(-48,28),"剩余%d次"%s.charges if s.visible else "不展示敌方标记",Color.GOLD)
	view._text(Vector2(8,142),"施标冷却 %.1f 秒；进雾后不自动追踪开火"%s.cooldown,UiKit.COL_DIM)
