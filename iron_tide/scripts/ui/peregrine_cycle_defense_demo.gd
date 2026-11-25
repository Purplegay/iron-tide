extends RefCounted

static func duration(rank:int) -> float:
	return 40.0 if rank==1 else 22.0

static func sample(rank:int,t:float) -> Dictionary:
	var clock:=fposmod(t,duration(rank))
	if rank==1:
		var part:=int(clock/8);var local:=clock-part*8
		var consumed:=local>=2 if part==0 else local>=4
		return {"part":part,"time":local,"ready":not consumed,"hp":100 if local<(5 if part==0 else 2) else 90,
			"deflect":local>=2 and local<2.35 if part==0 else local>=4 and local<4.35,
			"phase":["首枚追踪弹进入1格被引走；同周期第二枚命中","不可诱导弹道命中，资格保留给下一枚普通追踪弹","子弹直接命中，资格保留给下一枚普通追踪弹","激光直接命中，资格保留给下一枚普通追踪弹","范围爆炸照常受伤，资格保留给下一枚追踪弹"][part]}
	var steady:=clock>=1 and clock<3 or clock>=18 and clock<20
	var stunned:=clock>=4 and clock<8
	return {"time":clock,"steady":steady,"stunned":stunned,"ready":clock<1 or clock>=17 and clock<18,
		"ammo":3 if clock>=9 and clock<17 else 4,"distance":18*(clock-clampf(clock-4,0,4)),
		"left":8-clock if stunned else 0.0,
		"phase":"第一次计时EMP被抵消：稳姿2秒，能移动但禁攻" if clock<3 else "本周期第二次眩晕完整4秒：停止移动与开火" if clock<8 else "第9秒发射1发，等8秒真正补满，资格才恢复" if clock<18 else "补满后再次抵消新控制，稳姿2秒后恢复开火"}

static func draw(view,width:float,rank:int) -> void:
	var s:=sample(rank,view.elapsed);var t:float=s.time
	var hero:=Vector2(width*.22,88);var enemy:=Vector2(width*.78,98)
	view._text(Vector2(8,22),"诱饵抛投 · 五段独立来弹对照" if rank==1 else "抗扰飞控 · 首次抵消，第二次照常受控",UiKit.COL_GOLD)
	view._text(Vector2(8,43),s.phase,UiKit.COL_DIM)
	if rank==3:hero.x+=s.distance
	view._sprite("ORCA",hero,.7,false,Color.WHITE,2)
	view._sprite("FV",enemy,.6,false,Color(.9,.6,.6),6)
	if rank==1:
		view.stage.draw_arc(hero,34,0,TAU,32,Color(.5,.8,1,.5),1)
		if t>=1 and t<2:
			if s.part<3:view.stage.draw_circle(enemy.lerp(hero+Vector2(34 if s.part==0 else 0,0),t-1),3,Color.GOLD if s.part==1 else Color.ORANGE)
			elif s.part==3 and t>=1.85:view.stage.draw_line(enemy,hero,Color.RED,2)
		if s.part==4 and t>=2 and t<2.4:view.stage.draw_arc(hero,25,0,TAU,30,Color.ORANGE,3)
		var second_hit:=5.0 if s.part==0 else 4.0
		if t>=3 and t<second_hit:
			var dest:=hero if s.part==0 else hero+Vector2(34,0)
			view.stage.draw_circle(enemy.lerp(dest,(t-3)/(second_hit-3)),3,Color.ORANGE)
		if s.deflect:
			var elapsed:=t-(2 if s.part==0 else 4)
			var point:=hero+Vector2(34,-elapsed*80)
			view.stage.draw_line(hero+Vector2(34,0),point,Color.GOLD,2)
			view.stage.draw_circle(point,4,Color.YELLOW)
		view._text(hero+Vector2(-45,35),"生命 %d/100"%s.hp,UiKit.COL_OK)
		view._text(Vector2(8,142),"诱饵：%s · 弹仓始终满着也不会刷新周期"%("本周期可用" if s.ready else "本周期已用"),Color.CYAN)
		return
	if s.steady or s.stunned:view.stage.draw_arc(hero,28,0,TAU,30,Color.RED if s.stunned else Color(.8,.75,1),2)
	for at:float in [1.,4.,18.]:
		if t>=at and t<at+.2:view.stage.draw_line(enemy,hero,Color(.8,.7,1),2)
	if t>=9 and t<10:view.stage.draw_circle(hero.lerp(enemy,t-9),3,Color.ORANGE)
	view._text(hero+Vector2(-43,35),"眩晕 %.1f秒"%s.left if s.stunned else "稳姿禁攻，可移动" if s.steady else "可移动／开火",UiKit.COL_OK)
	view._text(Vector2(8,142),"抗扰：%s · 对地弹药 %d/4，指挥Lv.0，无补弹加速"%["可用" if s.ready else "等待补满",s.ammo],Color.CYAN)
