extends RefCounted

static func sample(rank:int,t:float) -> Dictionary:
	match rank:
		1:
			return {"enemy":40 if t<1 else 20 if t<3 else 0,"shield":0 if t<1 or t>=9 else 10 if t<3 else 20,"text":"命中实际敌盾 → 50%转为自身盾" if t<5 else "命中无盾不刷新 · 六秒到期"}
		2:return {"detected":t>=2 and t<8,"text":"仅3格内敌地面载具 · 步兵与空海目标不揭示"}
		_:
			var count:=0
			for time in [1.,2.,3.,5.,6.,7.,9.,10.,11.]:
				if t>=time:count=(count+1)%3
			return {"locked":t>=3 and t<4 or t>=11 and t<12,"count":count,"text":"第三击锁移动1秒，敌人仍能开火" if t<4 else "目标8秒间隔 · 期间第三击不重复锁" if t<11 else "间隔结束，新的第三击再次闭锁"}

static func draw(view,width:float) -> void:
	var rank:int=view.levels.selected;var t:float=view.elapsed
	if rank>=4:
		preload("res://scripts/ui/leizhu_station_demo.gd").draw(view,width);return
	var a:=Vector2(width*.25,88);var b:=Vector2(width*.7,88)
	var state:=sample(rank,t)
	view._sprite("TTNK",a,.75)
	view._text(Vector2(8,22),state.text,UiKit.COL_GOLD)
	if rank==1:
		view._sprite("HTNK",b,.65,false,Color(.95,.6,.6))
		if state.enemy>0:view.stage.draw_arc(b,30,0,TAU,32,Color.CYAN,2)
		if state.shield>0:view.stage.draw_arc(a,32,0,TAU,32,Color.GOLD,2)
		for time in [1.,3.,5.]:
			if t>=time and t<time+.25:view.stage.draw_line(a,b,Color.CYAN,3)
		view._text(a+Vector2(-65,42),"自身夺取盾 %d"%state.shield,Color.GOLD)
		view._text(b+Vector2(-55,42),"敌盾 %d"%state.enemy,Color.CYAN)
	elif rank==2:
		view.stage.draw_arc(a,110,0,TAU,48,Color.CYAN,1.5)
		var travel:=smoothstep(1,2,t)*(1-smoothstep(7,8,t))
		var p:=a+Vector2(lerpf(150,80,travel),0)
		view._sprite("MGTK",p,.6,false,Color(1,1,1,1 if state.detected else .2))
		view._sprite("E1",a+Vector2(20,55),1,false,Color(1,1,1,.2))
		view._text(Vector2(8,168),"载具进入范围可见，离开恢复隐蔽；隐形步兵仍不被揭示",UiKit.COL_DIM)
	else:
		b.x+=0 if state.locked else fposmod(t,3)*8
		view._sprite("HTNK",b,.65,not state.locked,Color(.95,.6,.6))
		for time in [1.,2.,3.,5.,6.,7.,9.,10.,11.]:
			if t>=time and t<time+.2:view.stage.draw_line(a,b,Color.CYAN,3)
		if state.locked:
			view.stage.draw_line(b+Vector2(-30,10),b+Vector2(30,10),Color.CYAN,4)
			if fposmod(t,.5)<.2:view.stage.draw_line(b,a,Color.ORANGE,2)
		view._text(b+Vector2(-70,42),"闭锁中 · 仍可开火" if state.locked else "连续命中 %d/3"%state.count,Color.CYAN)
