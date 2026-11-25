extends RefCounted

static func duration(rank:int) -> float:
	return 10.0 if rank==0 else 18.0 if rank==2 else 12.0

static func sample(rank:int,t:float) -> Dictionary:
	var clock:=fposmod(t,duration(rank))
	if rank==0:
		return {"time":clock,"reveal":clock>=2 and clock<5,"offset":clampf(clock-2,0,3)*32,"ammo":4 if clock<1 or clock>=9 else 3}
	if rank==2:
		var part:=int(clock/6);var local:=clock-part*6
		return {"time":local,"part":part,"ammo":[5,1,0][part],"shots":mini(4,maxi(0,int(local))),"first":part==0,"last":part<2}
	var distance:=2.8-clock*.65 if clock<2 else 1.5 if clock<6 else minf(2.8,1.5+(clock-6)*.65)
	var blocked:=clock>=4 and clock<5
	return {"time":clock,"distance":distance,"blocked":blocked,"visible":distance<=2 and not blocked,"sub_visible":false}

static func draw(view,width:float,rank:int) -> void:
	var s:=sample(rank,view.elapsed);var t:float=s.time
	var hero:=Vector2(width*.22,85)
	view._sprite("ORCA",hero,.7,false,Color.WHITE,2)
	if rank==0:
		var point:=Vector2(width*.63,97);var target:=point+Vector2(s.offset,0)
		view._text(Vector2(8,22),"航拍落点 · 视野留在命中位置，不跟随目标",UiKit.COL_GOLD)
		view._sprite("HTNK",target,.58,t>=2 and t<5)
		if t>=1 and t<2:view.stage.draw_circle(hero.lerp(point,t-1),3,Color.ORANGE)
		view.stage.draw_circle(point,2,Color.GOLD)
		if s.reveal:view.stage.draw_arc(point,32,0,TAU,32,Color.CYAN,2)
		view._text(Vector2(8,44),"命中后固定1格圈保留3秒；车辆驶离原落点",UiKit.COL_DIM)
		view._text(hero+Vector2(-42,38),"对地弹药 %d/4"%s.ammo,UiKit.COL_OK)
		view._text(Vector2(8,142),"视野剩余 %.1f秒 · 无机场，消耗后8秒补回"%(5-t if s.reveal else 0),Color.CYAN)
		return
	if rank==2:
		var target:=Vector2(width*.72,85)
		view._sprite("ORCA",target,.65,false,Color(.95,.6,.5),6,false)
		view._text(Vector2(8,22),"自卫机炮 · 满仓／剩1发／空仓三段独立对照",UiKit.COL_GOLD)
		view._text(Vector2(8,44),"1秒一次、20%主攻击；本段不触发对地首末弹",UiKit.COL_DIM)
		for at:float in [1.,2.,3.,4.]:
			if t>=at and t<at+.15:view.stage.draw_line(hero,target,Color.YELLOW,2)
		view._text(hero+Vector2(-45,35),"对地弹药 %d/5"%s.ammo,UiKit.COL_OK)
		view._text(target+Vector2(-50,35),"机炮命中 %d次"%s.shots,Color.CYAN)
		view._text(Vector2(8,142),"对地首发资格：%s · 末发资格：%s · 均未被机炮消耗"%["保留" if s.first else "已用", "保留" if s.last else "已用"],UiKit.COL_DIM)
		return
	var target:=hero+Vector2(s.distance*40,0)
	view._text(Vector2(8,22),"低空扫描 · 2格地面反隐，不反潜",UiKit.COL_GOLD)
	view._text(Vector2(8,44),"地面目标进入／遮挡／离开；潜艇始终未被侦测",UiKit.COL_DIM)
	view.stage.draw_arc(hero,80,0,TAU,40,Color.CYAN,1.5)
	view._sprite("SPY",target,1,false,Color(1,1,1,1 if s.visible else .18),6)
	if s.blocked:view.stage.draw_rect(Rect2(hero+Vector2(25,-20),Vector2(10,45)),Color.DIM_GRAY)
	var sub:=hero+Vector2(0,38)
	view._sprite("SUB",sub,.36,false,Color(1,1,1,.18))
	view._text(Vector2(width*.62,91),"地面目标："+("已发现" if s.visible else "未发现"),UiKit.COL_OK if s.visible else UiKit.COL_DIM)
	view._text(Vector2(width*.62,115),"潜艇：未发现",UiKit.COL_DIM)
	view._text(Vector2(8,142),"虚影仅作演示对照；反隐不增加武器射程",UiKit.COL_DIM)
