extends RefCounted
const LENGTH:=44.0
const OWNER:=Vector2(80,78)
const SECOND:=Vector2(128,90)
const THIRD:=Vector2(137,57)

static func sample(rank:int,time:float) -> Dictionary:
	var t:=fposmod(time,LENGTH)
	var fatal:=t>=36
	var local:=t-36 if fatal else t
	var speed:float=GameData.get_skill("ps_evacuation_escort").values.speed[rank]*100
	var hp:=500
	if fatal:
		if local>=1:hp=0
	else:
		if t>=1:hp=400
		if t>=2:hp=399
		if t>=3:hp=398
		if t>=27:hp=397
		if t>=28:hp=400
		if t>=29:hp=399
	var triggers:=0 if fatal or t<2 else 1 if t<29 else 2
	var initial:=not fatal and t>=2 and t<4
	var later:=not fatal and t>=29 and t<31
	var selected:Array[bool]=[initial,initial or later,later]
	var distance:=0.0 if fatal else clampf(t-2,0,5)*20+clampf(t-2,0,2)*20*speed*.01
	var first:=Vector2(115+distance,65)
	var left:=4-t if initial else 31-t if later else 0.
	var cooldown:=maxf(0,(54 if triggers==2 else 27)-t) if triggers>0 else 0.
	var title:="生命跨过40%且存活 · 最近两名同方步兵"
	var text:="生命500/1000 · 本人不获加速，友军命令不变"
	if t>=1:text="恰好40%：不触发"
	if t>=2:text="低于40%%且存活：两名友军加速%.0f%%"%speed
	if t>=4:text="两秒加速到期 · 持续低血不会重复触发"
	if t>=27:text="25秒间隔已结束 · 仍低血，不再次触发"
	if t>=28:text="治疗回到40%：可以等待下次跨越"
	if t>=29:text="再次降到40%以下 · 重选现在最近两名"
	if t>=31:text="第二次加速到期 · 继续等待25秒间隔"
	if fatal:
		title="独立示例 · 致命受击不触发护送"
		text="等待致命受击" if hp>0 else "生命归零 · 无友军加速、无触发冷却"
	return {"time":t,"local":local,"fatal":fatal,"title":title,"text":text,"active":initial or later,"value":speed,"charges":0,
		"hp":hp,"triggers":triggers,"selected":selected,"first":first,"left":left,"cooldown":cooldown,"self_buff":false,
		"first_moving":not fatal and t>=2 and t<7}

static func draw(stage,s:Dictionary) -> void:
	stage.draw_string(ThemeDB.fallback_font,Vector2(8,14),s.title,HORIZONTAL_ALIGNMENT_LEFT,-1,10,stage.BONUS)
	stage.draw_string(ThemeDB.fallback_font,Vector2(8,29),"2格内 · 英雄排除 · 加速只保留2秒",HORIZONTAL_ALIGNMENT_LEFT,-1,10,stage.MUTED)
	stage.draw_arc(OWNER,70,0,TAU,40,Color(stage.MUTED,.5),1,true)
	stage.actor(OWNER,stage.ALLY)
	var incoming:Array[float]=[]
	incoming.assign([1.] if s.fatal else [1.,2.,3.,27.,29.])
	for impact:float in incoming:
		if s.local>=impact-.4 and s.local<impact:
			var p:Vector2=Vector2(290,130).lerp(OWNER,(s.local-impact+.4)/.4)
			stage.draw_line(p,p+Vector2(8,2),stage.FOE,2,true)
	if not s.fatal and s.time>=28 and s.time<28.4:stage.ring(OWNER,20,Color.GREEN)
	var points:Array[Vector2]=[s.first,SECOND,THIRD]
	for i in 3:
		stage.actor(points[i],stage.ALLY,0,false)
		if s.selected[i]:stage.ring(points[i],15,stage.BONUS)
		stage.draw_string(ThemeDB.fallback_font,points[i]+Vector2(8,-8),str(i+1),HORIZONTAL_ALIGNMENT_LEFT,-1,10,stage.ALLY)
	stage.actor(Vector2(90,112),stage.MUTED,0,false)
	stage.draw_string(ThemeDB.fallback_font,Vector2(104,118),"英雄不选",HORIZONTAL_ALIGNMENT_LEFT,-1,10,stage.MUTED)
	stage.draw_rect(Rect2(48,99,60,4),stage.MUTED)
	stage.draw_rect(Rect2(48,99,60*s.hp/1000.,4),stage.FOE)
	stage.draw_line(Vector2(72,97),Vector2(72,105),stage.BONUS,1)
	stage.draw_string(ThemeDB.fallback_font,Vector2(225,53),"本人生命%d/1000"%s.hp,HORIZONTAL_ALIGNMENT_LEFT,-1,10,stage.FOE)
	stage.draw_string(ThemeDB.fallback_font,Vector2(225,71),"护送触发 %d次"%s.triggers,HORIZONTAL_ALIGNMENT_LEFT,-1,10,stage.BONUS)
	stage.draw_string(ThemeDB.fallback_font,Vector2(225,89),"间隔剩余 %.1fs"%s.cooldown,HORIZONTAL_ALIGNMENT_LEFT,-1,10,stage.MUTED)
	stage.draw_string(ThemeDB.fallback_font,Vector2(225,107),"加速剩余 %.1fs"%s.left,HORIZONTAL_ALIGNMENT_LEFT,-1,10,stage.ALLY)
	if s.hp==0:
		stage.draw_line(OWNER-Vector2(10,10),OWNER+Vector2(10,10),stage.FOE,2)
		stage.draw_line(OWNER+Vector2(-10,10),OWNER+Vector2(10,-10),stage.FOE,2)
