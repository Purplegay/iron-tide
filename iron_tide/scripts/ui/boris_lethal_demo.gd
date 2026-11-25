extends RefCounted

static func duration(rank:int) -> float:
	return 18.0 if rank==1 else 24.0

static func sample(rank:int,t:float) -> Dictionary:
	var clock:=fposmod(t,duration(rank));var part:=int(clock/6);var local:=clock-part*6
	if rank==1:
		var hp:=40 if part==1 else 100
		if local>=1:hp=50 if part==0 and local<4 else 0
		return {"part":part,"time":local,"hp":hp,"dead":hp<=0,"mig":part==2,
			"phase":["普通致命爆炸100→50；第二次仍可能击杀","初始40生命：限伤至最大生命50，仍会阵亡","本人天赋不传给米格：飞机受致命伤直接被毁"][part]}
	var legal:=part==0
	return {"part":part,"time":local,"dead":local>=1,"warning":legal and local>=1 and local<2.5,"blast":legal and local>=2.5 and local<3,
		"offset":clampf(local-1.3,0,1)*80 if legal else 0.0,"victim_hp":50 if legal and local>=2.5 else 200,
		"phase":["固定落点预警1.5秒；来源可逃出，圈内敌仍受伤","最后伤害来源距离7格，超过6格：不留预警","最后伤害来源不可见：不揭雾、不留预警","最后伤害来源为空中单位：不留预警"][part]}

static func dead_mark(view,at:Vector2) -> void:
	view.stage.draw_line(at+Vector2(-12,-22),at+Vector2(12,0),Color.ORANGE,2)
	view.stage.draw_line(at+Vector2(12,-22),at+Vector2(-12,0),Color.ORANGE,2)

static func draw(view,width:float,rank:int) -> void:
	var s:=sample(rank,view.elapsed);var t:float=s.time
	var hero:=Vector2(width*.2,95)
	view._text(Vector2(8,22),"防爆内衬 · 三段独立对照" if rank==1 else "最后电令 · 四段独立对照，不复活",UiKit.COL_GOLD)
	view._text(Vector2(8,43),s.phase,UiKit.COL_DIM)
	if rank==1:
		var subject:=Vector2(width*.46,95) if s.mig else hero
		if not s.mig:
			if s.dead:dead_mark(view,subject)
			else:view._sprite("BORIS",subject,1.2)
		else:
			view._sprite("BORIS",hero,1.2)
			if s.dead:dead_mark(view,subject)
			else:view._sprite("BPLN",subject-Vector2(0,15),.4)
		view._sprite("FLAKT" if s.mig else "HTNK",Vector2(width*.8,95),.6)
		for at:float in [1.,4.] if s.part==0 else [1.]:
			if t>=at-.3 and t<at:view.stage.draw_circle(Vector2(width*.8,80).lerp(subject-Vector2(0,15),(t-at+.3)/.3),3,Color.ORANGE)
		view._text(subject+Vector2(-46,28),"%s生命 %d/100"%["米格" if s.mig else "本人",s.hp],UiKit.COL_OK)
		view._text(Vector2(8,142),"普通爆炸限伤并非保命；死亡后没有复活",UiKit.COL_DIM)
		return
	if s.dead:dead_mark(view,hero)
	else:view._sprite("BORIS",hero,1.2)
	var point:=hero+Vector2(160,0)
	var source:=hero+Vector2(280 if s.part==1 else 160,0)+Vector2(s.offset,0)
	if s.part==2:
		view.stage.draw_rect(Rect2(source-Vector2(30,35),Vector2(60,40)),Color(.08,.1,.14))
		view._text(source+Vector2(-28,25),"不可见",UiKit.COL_DIM)
	else:view._sprite("ORCA" if s.part==3 else "E2",source-Vector2(0,15 if s.part==3 else 0),.5 if s.part==3 else 1.05,s.part==0 and t>=1.3 and t<2.3,Color.WHITE,2)
	if t>=.8 and t<1:view.stage.draw_line(source-Vector2(0,16),hero-Vector2(0,16),Color.ORANGE,2)
	if s.part==0:
		var victim:=point+Vector2(20,0)
		view._sprite("E2",victim,1.05,false,Color.WHITE,2)
		if s.warning:view.stage.draw_arc(point,60,0,TAU,36,Color.ORANGE,2)
		if s.blast:view.stage.draw_arc(point,60,0,TAU,36,Color.ORANGE,4)
		view._text(victim+Vector2(-40,28),"生命 %d/200"%s.victim_hp,UiKit.COL_OK)
		view._text(Vector2(8,142),"攻击100示例→150爆破；落点不追踪，无校射加成",UiKit.COL_DIM)
	else:view._text(Vector2(8,142),"鲍里斯已阵亡，无后续轰炸" if s.dead else "等待致命攻击",UiKit.COL_DIM)
