extends RefCounted

static func duration(rank:int) -> float:
	return 108.0 if rank==1 else 40.0

static func sample(rank:int,t:float) -> Dictionary:
	var clock:=fposmod(t,duration(rank))
	if rank==1:
		var part:=int(clock/36);var local:=clock-part*36
		var purge:=3.0 if part==0 else 5.0
		return {"part":part,"time":local,"parasite":local>=1 and local<purge,"flash":local>=purge and local<purge+.4,
			"controlled":part>0 and local>=1.5 and local<5,"left":maxf(0,3-local),"cooldown":maxf(0,purge+30-local) if local>=purge else 0.0,
			"hp":100-mini(int(local),int(purge)-1)*10,"dead":false,
			"text":"寄生2秒后放电；保留此前伤害" if part==0 else "冻结期间不能放电；解除后处理已就绪反制" if part==1 else "EMP期间不能放电；解除后处理已就绪反制"}
	var part:=int(clock/8);var local:=clock-part*8
	var hp:=20 if part==3 else 100
	if local>=1:hp=80 if part in [0,2,4] else 96 if part==1 else 0
	if part==0 and local>=3:hp=64
	return {"part":part,"time":local,"hp":hp,"dead":hp<=0,"shield":4 if part==0 and local>=1 and local<7 else 0,
		"text":["敌方普通电伤20→回收4；下一击旧盾先吸收","联动分流Lv.4：友军承受80，转移4不生回收盾","自身电伤20：实际扣血，但不产生回收盾","低血遭致命电伤：先阵亡，不能靠回收盾救命","追加电伤20：不是普通主攻击，不产生回收盾"][part]}

static func draw(view,width:float) -> void:
	var rank:int=view.levels.selected;var s:=sample(rank,view.elapsed);var t:float=s.time
	var a:=Vector2(width*.3,94);var b:=Vector2(width*.76,94)
	view._text(Vector2(8,22),"反寄生放电 · 三段独立对照" if rank==1 else "电能回收 · 五段独立对照",UiKit.COL_GOLD)
	view._text(Vector2(8,44),s.text,UiKit.COL_DIM)
	if not s.dead:view._sprite("TTNK",a,.8)
	else:
		view.stage.draw_line(a+Vector2(-16,-16),a+Vector2(16,16),Color.ORANGE,3)
		view.stage.draw_line(a+Vector2(16,-16),a+Vector2(-16,16),Color.ORANGE,3)
	view._text(a+Vector2(-48,48),"生命 %d/100"%s.hp,UiKit.COL_OK)
	if rank==1:
		if t<1:view._sprite("DRON",b.lerp(a,t),.7,true)
		if s.parasite:view.stage.draw_arc(a,30,0,TAU,32,Color.ORANGE,2)
		if s.controlled:
			view.stage.draw_arc(a,38,0,TAU,32,Color(.6,.6,1),3)
			view._text(b+Vector2(-55,-8),"冻结" if s.part==1 else "EMP",Color(.8,.75,1))
		if s.flash:
			var purge:=3.0 if s.part==0 else 5.0
			view.stage.draw_arc(a,35+(t-purge)*70,0,TAU,32,Color.CYAN,3)
		view._text(b+Vector2(-85,24),"准备 %.1f秒 · 等待控制解除"%s.left if s.controlled else "放电间隔 %.1f秒"%s.cooldown,Color.CYAN)
		view._text(Vector2(8,169),"仅演示反制；扣血数值／间隔为示例，不返还此前伤害",UiKit.COL_DIM)
	else:
		var via:=Vector2(width*.54,94)
		if s.part==1:
			view._sprite("HTNK",via,.6)
			view._text(via+Vector2(-35,48),"友军 %d"%(100 if t<1 else 20),UiKit.COL_OK)
		if s.part!=2:view._sprite("SHK",b,1.0)
		for at:float in [1.,3.] if s.part==0 else [1.]:
			if t>=at and t<at+.25:
				if s.part==2:view.stage.draw_arc(a,26,0,TAU,26,Color.ORANGE,3)
				else:view.stage.draw_line(b,via if s.part==1 else a,Color.CYAN,3)
				if s.part==1:view.stage.draw_line(via,a,Color.ORANGE,2)
		if s.shield>0:view.stage.draw_arc(a,36,0,TAU,36,Color(.3,1,.65),2)
		view._text(a+Vector2(-48,68),"回收盾 %d/100"%s.shield,Color.CYAN)
		view._text(Vector2(width*.57,162),"电伤为结算示例",UiKit.COL_DIM)
