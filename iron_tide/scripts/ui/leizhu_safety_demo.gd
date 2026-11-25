extends RefCounted

static func duration(rank:int) -> float:
	return 24.0 if rank==4 else 18.0

static func sample(rank:int,t:float) -> Dictionary:
	var clock:=fposmod(t,duration(rank));var length:=6.0 if rank==4 else 9.0
	var part:=int(clock/length);var local:=clock-part*length
	if rank==4:
		return {"part":part,"time":local,"hero_hp":100 if local<1 or part==3 else 80 if part==1 else 96,
			"ally_hp":100 if local<1 or part==1 else 0 if part==3 else 20,"shield":0,"stopped":false,"dead":false,"active":part!=3,
			"text":["最终伤害100→友军80；转移20×20%=雷铸承受4","直接攻击雷铸20：正常扣20，不享转移的80%减免","普通电击打友军：转移4仍不产生雷铸回收盾","雷铸被冻结时分流停用：友军独自承担100"][part]}
	var dead:=local>=6 if part==0 else local>=2
	var stopped:=local>=1 and local<4 and not dead
	var active:=not dead and not stopped
	var shield:=0.0 if local<1 or dead else 40.0 if local<2 else 20.0 if local<5 else 19.6
	return {"part":part,"time":local,"hero_hp":0 if dead else 100 if local<1 else 1 if local<4 else 20,
		"ally_hp":100 if local<2.5 else 90 if local<5 else 82 if part==0 else 80,"shield":shield,"stopped":stopped,"dead":dead,"active":active,
		"power":100 if active else 0,"court":local<1,
		"text":"配合指挥Lv.5：供电、分流、电庭原先都生效" if local<1 else "保留1血与40盾；停堆3秒，电庭立即清除" if local<2 else "后续伤害击穿应急盾：停堆期间也能阵亡" if part==1 else "停堆中友军受伤不分流；供电为0" if local<4 else "恢复供电与分流；电庭不重建、W不刷新" if local<6 else "再次致命伤正常击毁，本局不再停堆"}

static func draw(view,width:float) -> void:
	var rank:int=view.levels.selected;var s:=sample(rank,view.elapsed);var t:float=s.time
	var hero:=Vector2(width*.22,90);var ally:=Vector2(width*.49,90);var enemy:=Vector2(width*.84,90)
	view._text(Vector2(8,22),"分流保护 · 四段独立伤害对照" if rank==4 else "紧急停堆 · 存活恢复／盾被击穿独立对照",UiKit.COL_GOLD)
	view._text(Vector2(8,44),s.text,UiKit.COL_DIM)
	view._sprite("SHK" if rank==4 and s.part==2 else "HTNK",enemy,.65,false,Color(.95,.6,.6))
	if not s.dead:view._sprite("TTNK",hero,.75,false,Color(.5,.6,.65) if s.stopped else Color.WHITE)
	else:
		view.stage.draw_line(hero+Vector2(-16,-16),hero+Vector2(16,16),Color.ORANGE,3)
		view.stage.draw_line(hero+Vector2(16,-16),hero+Vector2(-16,16),Color.ORANGE,3)
	if s.ally_hp>0:view._sprite("HTNK",ally,.6)
	else:
		view.stage.draw_line(ally-Vector2(12,12),ally+Vector2(12,12),Color.ORANGE,3)
		view.stage.draw_line(ally+Vector2(12,-12),ally+Vector2(-12,12),Color.ORANGE,3)
	if s.active:view.stage.draw_line(hero,ally,Color(.35,.9,.65,.7),2)
	view._text(hero+Vector2(-45,40),"雷铸生命 %d"%s.hero_hp,UiKit.COL_OK)
	view._text(ally+Vector2(-43,40),"友军生命 %d"%s.ally_hp,UiKit.COL_OK)
	if rank==4:
		if s.part==3:view.stage.draw_arc(hero,36,0,TAU,30,Color(.7,.7,1),2)
		if t>=1 and t<1.3:view.stage.draw_line(enemy,hero if s.part==1 else ally,Color.ORANGE,3)
		view._text(hero+Vector2(-45,61),"回收盾 0",Color.CYAN)
		view._text(Vector2(8,169),"无其它护盾和减伤的结算示例；80%仅减免转移份额",UiKit.COL_DIM)
		return
	if s.shield>0:view.stage.draw_arc(hero,34,0,TAU,32,Color(.4,1,.7),2)
	view._text(hero+Vector2(-45,60),"应急盾 %.1f"%s.shield,Color.CYAN)
	if s.court:
		for i in 3:view.stage.draw_arc(enemy+Vector2((i-1)*25,0),16,0,TAU,24,Color.CYAN,1.5)
	view._text(enemy+Vector2(-45,40),"电庭生效" if s.court else "电庭已清除",UiKit.COL_DIM)
	if s.stopped:view._text(ally+Vector2(-43,60),"停堆%.1f秒"%(4-t),Color.ORANGE)
	for at:float in [1.,2.,6.] if s.part==0 else [1.,2.]:
		if t>=at and t<at+.2:view.stage.draw_line(enemy,hero,Color.ORANGE,3)
	for at:float in [2.5,5.]:
		if t>=at and t<at+.2:view.stage.draw_line(enemy,ally,Color.ORANGE,3)
	view._text(Vector2(8,176),"供电+%d · 基地收支%d · 分流%s · W保持原冷却"%[s.power,s.power-60,"开启" if s.active else "停用"],Color.CYAN)
