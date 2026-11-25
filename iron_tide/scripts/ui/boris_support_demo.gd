extends RefCounted

static func duration(rank:int) -> float:
	return 56.0 if rank==3 else 26.0

static func sample(rank:int,t:float) -> Dictionary:
	var clock:=fposmod(t,duration(rank))
	if rank==3:
		var part:=int(clock/14);var local:=clock-part*14
		var picked:=part==0 and local>=5
		return {"time":local,"part":part,"hp":100 if part==1 else 75 if picked else 60,
			"pickup":part<2 and local>=3 and local<13 and not picked,"left":maxf(0,13-local),
			"dropped":part!=2 and local>=1,"destroyed":part==3 and local>=2,"picked":picked,
			"phase":["实际投弹→正常离场→本人拾取；同队后机不再给","满血接触不消耗，地面补给保留满10秒","未投弹便撤退：正常离场也没有补给","投弹后被击落：没有正常离场，不留补给"][part]}
	var active:=clock>=1 and clock<5 or clock>=21 and clock<25
	var hp:=5 if clock>=4 and clock<5 else 10
	return {"time":clock,"shields":[hp if active else 0,10 if active else 0,0],
		"cooldown":maxf(0,(21 if clock<21 else 41)-clock) if clock>=1 else 0.0,
		"phase":"开始呼叫，最近两名普通步兵获得4秒盾" if clock<1.3 else "移动中断呼叫，保留已发护盾与20秒间隔" if clock<2 else "再次呼叫不刷新；第一名护盾随后承受伤害" if clock<5 else "护盾已到期，仍需等原20秒间隔" if clock<21 else "间隔结束再次呼叫，重新发放4秒盾"}

static func draw(view,width:float,rank:int) -> void:
	var s:=sample(rank,view.elapsed);var t:float=s.time
	view._text(Vector2(8,22),"接应补给 · 四段独立场景" if rank==3 else "电台掩护 · 中断不返资格",UiKit.COL_GOLD)
	view._text(Vector2(8,43),s.phase,UiKit.COL_DIM)
	var hero:=Vector2(width*.2,95)
	if rank==3:
		var pickup:=hero+Vector2(60,0)
		if s.part<2:hero.x+=clampf(t-4,0,1)*60
		view._sprite("BORIS",hero,1.2,s.part<2 and t>=4 and t<5)
		view._sprite("NAPOWR",Vector2(width*.8,93),.32)
		var jet_x:=lerpf(width*.45,width*.8,clampf(t,0,1)) if t<1 else lerpf(width*.8,-35,clampf((t-1)/2,0,1))
		if t<3 and not s.destroyed:view._sprite("BPLN",Vector2(jet_x,63),.38)
		if t>=1 and t<1.5 and s.dropped:view.stage.draw_circle(Vector2(width*.8,78+(t-1)*30),3,Color.ORANGE)
		if s.destroyed and t<2.6:view.stage.draw_arc(Vector2(lerpf(width*.8,-35,.5),63),12+(t-2)*24,0,TAU,24,Color.ORANGE,2)
		if s.part==0 and t>=5 and t<6:view._sprite("BPLN",Vector2(width*.4-(t-5)*width*.35,63),.38)
		if s.pickup:
			view.stage.draw_rect(Rect2(pickup-Vector2(8,10),Vector2(16,12)),Color(.2,.7,.4))
			view.stage.draw_line(pickup+Vector2(-5,-4),pickup+Vector2(5,-4),Color.WHITE,2)
			view._text(pickup+Vector2(-36,27),"补给 %.1f秒"%s.left,Color.CYAN)
		view._text(Vector2(8,142),"本人生命 %d/100 · %s"%[s.hp,"已拾取＋15，同编队不再给" if s.picked else "满血不消耗" if s.part==1 and t>=5 and t<13 else "补给到期消失" if s.part==1 and t>=13 else "等待本人拾取" if s.pickup else "无地面补给"],UiKit.COL_OK)
		return
	hero.x+=clampf((t-1.3)/.7,0,1)*18
	view._sprite("BORIS",hero,1.2,t>=1.3 and t<2)
	for at:float in [1.,2.,21.]:
		if t>=at and t<at+.3:view.stage.draw_arc(hero-Vector2(0,15),22+(t-at)*30,0,TAU,24,Color.GOLD,2)
	for i in 3:
		var soldier:=Vector2(width*.46+i*65,96)
		view._sprite("E2",soldier,1.05)
		if s.shields[i]>0:view.stage.draw_arc(soldier-Vector2(0,16),25,0,TAU,28,Color.CYAN,2)
		view._text(soldier+Vector2(-22,27),"盾 %d"%s.shields[i],Color.CYAN)
	if t>=3.8 and t<4:view.stage.draw_line(Vector2(width*.46,54),Vector2(width*.46,80),Color.ORANGE,2)
	view._text(Vector2(8,142),"护盾示例各最大生命100 · 再次发放间隔 %.1f 秒"%s.cooldown,UiKit.COL_DIM)
