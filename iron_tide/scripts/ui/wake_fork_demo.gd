extends RefCounted
const LENGTH:=30.0
const LAUNCH:=.4
const HIT:=2.2
const CHILD_HIT:=3.1
const CELL:=40.0

static func sample(rank:int,time:float) -> Dictionary:
	var t:=fposmod(time,LENGTH)
	var part:=int(t/6)
	var local:=fposmod(t,6)
	var values:Dictionary=MetaProgress.talent_options("SUB").wake_fork.values
	var distance:=1.3 if part==1 else 3.0
	var traveled:=distance*clampf((local-LAUNCH)/(HIT-LAUNCH),0,1)
	var water:=minf(traveled,1.2) if part==2 else traveled
	var forked:=part in [0,4] and local>=HIT
	var lost:=part==4 and local>=2.4
	var title:String=["航满2格 · 命中后仅分叉一次","近距离直击 · 不足2格不分叉","只算水中路程 · 陆上路程不累计","无可见合法副目标 · 不分叉","副目标离距失锁 · 返回也不重锁"][part]
	var text:="水中航行 %.1f / 2格"%water
	if local>=HIT:
		text="只发一枚副鱼雷 · %.0f%%攻击基准"%(float(values.damage[rank])*100) if forked else "主弹正常命中 · 未产生副鱼雷"
	if forked and local>=CHILD_HIT:text="副弹命中 · 不再分叉／不累计普通命中" if not lost else "副弹失锁 · 不另找目标／不重新锁定"
	return {"time":t,"local":local,"part":part,"active":forked and local<CHILD_HIT,"value":float(values.damage[rank])*100,"charges":1 if forked else 0,
		"range":float(values.range[rank]),"distance":distance,"water":water,"forked":forked,"lost":lost,
		"main_flying":local>=LAUNCH and local<HIT,"child_flying":forked and local<CHILD_HIT,
		"child_hit":forked and not lost and local>=CHILD_HIT,"title":title,"text":text}

static func trace(view,from:Vector2,to:Vector2,time:float,start:float,end:float,color:Color) -> void:
	if time<start or time>=end:return
	var progress:=clampf((time-start)/(end-start),0,1)
	view.draw_line(from.lerp(to,maxf(0,progress-.12)),from.lerp(to,progress),color,3,true)

static func secondary_offset(s:Dictionary) -> Vector2:
	var offset:=Vector2(38,-25)
	if s.part==4 and s.local>=2.4:
		offset+=Vector2(s.range*CELL+16-38,-10)*(1-clampf((s.local-3.4)/.3,0,1))
	return offset

static func draw(view,origin:Vector2,s:Dictionary) -> void:
	var main:=origin+Vector2(s.distance*CELL,0)
	var second:=main+Vector2(38,-25)
	var farther:=main+Vector2(61,1)
	var moving:=main+secondary_offset(s)
	view.draw_string(ThemeDB.fallback_font,Vector2(10,18),s.title,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color.WHITE)
	view.draw_string(ThemeDB.fallback_font,Vector2(10,35),"分叉搜索 %.1f格 · 青色为水路 · 飞行时间示意"%s.range,HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color.SKY_BLUE)
	var wet_end:=origin.lerp(main,1.2/s.distance) if s.part==2 else main
	view.draw_dashed_line(origin,wet_end,Color.SKY_BLUE,1,5)
	if s.part==2:view.draw_dashed_line(wet_end,main,Color.SANDY_BROWN,1,5)
	view.draw_circle(main,8,Color.SALMON)
	view.draw_circle(moving,8,Color.DIM_GRAY if s.part==3 else Color.SALMON)
	view.draw_circle(farther,7,Color.DIM_GRAY if s.part==3 else Color.SALMON)
	view.draw_string(ThemeDB.fallback_font,main+Vector2(-14,21),"主目标",HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color.SALMON)
	view.draw_string(ThemeDB.fallback_font,Vector2(minf(moving.x-17,360),moving.y-14),"未探测" if s.part==3 else "最近副目标",HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color.DIM_GRAY if s.part==3 else Color.SALMON)
	trace(view,origin,main,s.local,LAUNCH,HIT,Color.SKY_BLUE)
	if s.local>=HIT and s.local<HIT+.2:view.draw_arc(main,15,0,TAU,24,Color.SKY_BLUE,2,true)
	if s.forked:trace(view,main,second,s.local,HIT,CHILD_HIT,Color.GOLD if not s.lost else Color.DIM_GRAY)
	if s.child_hit and s.local<CHILD_HIT+.2:view.draw_arc(second,15,0,TAU,24,Color.GOLD,2,true)
	if s.lost:view.draw_string(ThemeDB.fallback_font,Vector2(270,40),"已失锁",HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color.GOLD)
