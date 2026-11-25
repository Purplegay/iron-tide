extends RefCounted

static func duration(rank:int) -> float:
	return 6.0 if rank==3 else 16.0

static func sample(rank:int,t:float) -> Dictionary:
	var clock:=fposmod(t,duration(rank))
	if rank==3:return {"time":clock,"destroyed":clock>=1,"infantry_hp":100 if clock<1 else 40,"neighbor_hp":100,"outside_hp":100}
	var part:=int(clock/8);var local:=clock-part*8
	var firing:=false
	var slow_time:=0.0
	if part==0:
		for shot:float in [1.,2.,3.]:
			slow_time+=clampf(local-shot,0,.5)
			if local>=shot and local<shot+.5:firing=true
	var installing:=part==1 and local>=2 and local<5
	var distance:=local*40-slow_time*12 if part==0 else minf(local,2)*40+maxf(0,local-5)*40
	return {"time":local,"part":part,"firing":firing,"installing":installing,"distance":distance,"reference":local*40,
		"speed":0 if installing else 70 if firing else 100,"rounds":mini(3,int(local)) if part==0 else 0}

static func draw(view,width:float,rank:int) -> void:
	var s:=sample(rank,view.elapsed)
	if rank==3:draw_shock(view,width,s);return
	var origin:=Vector2(width*.12,100)
	var scale:=width/540
	var a:=origin+Vector2(s.distance*scale,0)
	view._text(Vector2(8,22),"行进双枪 · 沿原路线射击，不偏航追敌" if s.part==0 else "行进双枪 · 安装C4仍需停步",UiKit.COL_GOLD)
	view._text(Vector2(8,42),"动作时长为示意；射击70%移速，其余100%，不加快射速。",UiKit.COL_DIM)
	view.stage.draw_line(origin+Vector2(0,9),origin+Vector2(330*scale,9),UiKit.COL_DIM,1)
	view._sprite("TANY",a,1.2,s.speed>0)
	if s.part==0:
		var target:=Vector2(width*.69,72)
		view._sprite("E2",target,1.1,false,Color.WHITE,2)
		var reference:=origin+Vector2(s.reference*scale,-16)
		view.stage.draw_circle(reference,3,Color.GRAY)
		view._text(Vector2(width*.66,126),"灰点：100%速度参考",UiKit.COL_DIM)
		for shot:float in [1.,2.,3.]:
			if s.time>=shot and s.time<shot+.15:
				for offset in [-2,2]:view.stage.draw_line(a+Vector2(0,-16+offset),target+Vector2(0,-16+offset),Color.GOLD,1.5)
		view._text(Vector2(8,142),"当前速度 %d%%　普通双枪第%d轮"%[s.speed,s.rounds],Color.CYAN)
	else:
		var building:=origin+Vector2(115*scale,-4)
		view._sprite("NAPOWR",building,.38)
		if s.installing:view.stage.draw_line(a,building,Color.ORANGE,2)
		view._text(Vector2(8,142),"停步安装 · 速度0 · 不开双枪" if s.installing else "接近建筑 · 速度100%" if s.time<2 else "离开建筑 · 恢复100%移速",Color.CYAN)

static func draw_shock(view,width:float,s:Dictionary) -> void:
	var hero:=Vector2(width*.14,100)
	var main:=Vector2(width*.46,82)
	var near:=main+Vector2(30,30)
	var building:=main+Vector2(60,0)
	var far:=Vector2(width*.9,112)
	view._text(Vector2(8,22),"破拆震波 · 附近单位受伤，邻楼不受伤",UiKit.COL_GOLD)
	view._text(Vector2(8,42),"示例攻击力100、无增减伤：邻近步兵承受60爆破伤害。",UiKit.COL_DIM)
	view._sprite("TANY",hero,1.2)
	if not s.destroyed:view._sprite("NAPOWR",main,.34)
	else:preload("res://scripts/ui/tanya_chain_demo.gd").ruin(view,main)
	view._sprite("NAPOWR",building,.34)
	view._sprite("E2",near,1.0,false,Color.WHITE,2)
	view._sprite("E2",far,1.0,false,Color.WHITE,2)
	if s.time>=1 and s.time<1.6:view.stage.draw_arc(main,30+(s.time-1)*60,0,TAU,40,Color.ORANGE,2)
	view._text(building+Vector2(-25,-31),"邻楼 %d"%s.neighbor_hp,UiKit.COL_OK)
	view._text(near+Vector2(-30,25),"步兵 %d"%s.infantry_hp,Color.CYAN)
	view._text(far+Vector2(-28,25),"圈外 %d"%s.outside_hp,UiKit.COL_OK)
	view._text(Vector2(8,142),"地基外1.5格；不伤其他建筑，不递归产生震波。",UiKit.COL_DIM)
